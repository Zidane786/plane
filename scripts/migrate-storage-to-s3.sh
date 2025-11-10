#!/bin/bash

################################################################################
# Plane Storage Migration Script
################################################################################
# This script migrates your files from MinIO (Docker) to external S3-compatible
# storage (AWS S3, DigitalOcean Spaces, etc.)
#
# Usage:
#   ./migrate-storage-to-s3.sh
#
# Prerequisites:
#   - Docker installed and running
#   - AWS CLI or rclone installed
#   - Access to both source (MinIO) and destination (S3) storage
#   - Sufficient disk space for temporary storage (optional)
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
MIGRATION_METHOD="rclone"  # or "awscli"
CONTAINER_NAME="plane-minio"
SOURCE_BUCKET="uploads"
LOG_FILE="storage_migration_$(date +%Y%m%d_%H%M%S).log"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        return 1
    fi
    return 0
}

################################################################################
# Pre-flight Checks
################################################################################

print_header "Pre-flight Checks"

# Check if either rclone or aws cli is available
if check_command rclone; then
    MIGRATION_METHOD="rclone"
    print_success "Using rclone for migration"
elif check_command aws; then
    MIGRATION_METHOD="awscli"
    print_success "Using AWS CLI for migration"
else
    print_error "Neither rclone nor AWS CLI is installed."
    echo
    echo "Please install one of them:"
    echo "  - rclone: https://rclone.org/install/"
    echo "  - AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if docker is running
if ! check_command docker; then
    print_error "Docker is not installed or not running"
    exit 1
fi

# Check if MinIO container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_warning "Container '${CONTAINER_NAME}' is not running."
    read -p "Do you want to start it? (yes/no): " start_container
    if [ "${start_container}" == "yes" ]; then
        docker-compose -f docker-compose.infra.yml up -d minio
        sleep 5
    else
        exit 1
    fi
fi

print_success "All prerequisites met"

################################################################################
# Gather Configuration
################################################################################

print_header "Configuration"

# Source MinIO Configuration
echo "Source Storage (MinIO):"
read -p "MinIO endpoint [http://localhost:9000]: " MINIO_ENDPOINT
MINIO_ENDPOINT=${MINIO_ENDPOINT:-http://localhost:9000}

read -p "MinIO access key [minioadmin]: " MINIO_ACCESS_KEY
MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY:-minioadmin}

read -sp "MinIO secret key: " MINIO_SECRET_KEY
echo
MINIO_SECRET_KEY=${MINIO_SECRET_KEY:-minioadmin}

read -p "Source bucket name [uploads]: " SOURCE_BUCKET
SOURCE_BUCKET=${SOURCE_BUCKET:-uploads}

# Destination S3 Configuration
echo -e "\nDestination Storage (S3/Spaces):"

echo "Select provider:"
echo "1) AWS S3"
echo "2) DigitalOcean Spaces"
echo "3) Other S3-compatible"
read -p "Choice [1]: " PROVIDER_CHOICE
PROVIDER_CHOICE=${PROVIDER_CHOICE:-1}

case ${PROVIDER_CHOICE} in
    1)
        PROVIDER="AWS S3"
        read -p "AWS Region [us-east-1]: " DEST_REGION
        DEST_REGION=${DEST_REGION:-us-east-1}
        DEST_ENDPOINT=""
        ;;
    2)
        PROVIDER="DigitalOcean Spaces"
        read -p "Region (e.g., nyc3, sfo3) [nyc3]: " DEST_REGION
        DEST_REGION=${DEST_REGION:-nyc3}
        DEST_ENDPOINT="https://${DEST_REGION}.digitaloceanspaces.com"
        ;;
    3)
        PROVIDER="S3-compatible"
        read -p "S3 endpoint URL: " DEST_ENDPOINT
        read -p "Region [us-east-1]: " DEST_REGION
        DEST_REGION=${DEST_REGION:-us-east-1}
        ;;
esac

read -p "Destination bucket name: " DEST_BUCKET
read -p "Access key: " DEST_ACCESS_KEY
read -sp "Secret key: " DEST_SECRET_KEY
echo

################################################################################
# Setup Migration Tool
################################################################################

print_header "Setting Up Migration"

if [ "${MIGRATION_METHOD}" == "rclone" ]; then
    # Configure rclone
    RCLONE_CONFIG="$HOME/.config/rclone/rclone.conf"
    mkdir -p "$(dirname ${RCLONE_CONFIG})"

    print_info "Configuring rclone..."

    # Source (MinIO)
    cat >> ${RCLONE_CONFIG} <<EOF

[plane-minio-source]
type = s3
provider = Minio
access_key_id = ${MINIO_ACCESS_KEY}
secret_access_key = ${MINIO_SECRET_KEY}
endpoint = ${MINIO_ENDPOINT}
region = us-east-1

EOF

    # Destination
    if [ "${PROVIDER_CHOICE}" == "1" ]; then
        # AWS S3
        cat >> ${RCLONE_CONFIG} <<EOF
[plane-s3-dest]
type = s3
provider = AWS
access_key_id = ${DEST_ACCESS_KEY}
secret_access_key = ${DEST_SECRET_KEY}
region = ${DEST_REGION}

EOF
    else
        # S3-compatible (DigitalOcean Spaces, etc.)
        cat >> ${RCLONE_CONFIG} <<EOF
[plane-s3-dest]
type = s3
provider = Other
access_key_id = ${DEST_ACCESS_KEY}
secret_access_key = ${DEST_SECRET_KEY}
endpoint = ${DEST_ENDPOINT}
region = ${DEST_REGION}

EOF
    fi

    print_success "rclone configured"

elif [ "${MIGRATION_METHOD}" == "awscli" ]; then
    # Configure AWS CLI
    print_info "Configuring AWS CLI..."

    export AWS_ACCESS_KEY_ID=${DEST_ACCESS_KEY}
    export AWS_SECRET_ACCESS_KEY=${DEST_SECRET_KEY}
    export AWS_DEFAULT_REGION=${DEST_REGION}

    if [ -n "${DEST_ENDPOINT}" ]; then
        export AWS_ENDPOINT_URL=${DEST_ENDPOINT}
    fi

    print_success "AWS CLI configured"
fi

################################################################################
# Check Bucket Access
################################################################################

print_header "Validating Access"

# Check source bucket
print_info "Checking source bucket..."
if [ "${MIGRATION_METHOD}" == "rclone" ]; then
    if rclone lsd plane-minio-source: | grep -q ${SOURCE_BUCKET}; then
        print_success "Source bucket accessible"
    else
        print_error "Cannot access source bucket: ${SOURCE_BUCKET}"
        exit 1
    fi
fi

# Check/create destination bucket
print_info "Checking destination bucket..."
if [ "${MIGRATION_METHOD}" == "rclone" ]; then
    if ! rclone lsd plane-s3-dest: | grep -q ${DEST_BUCKET}; then
        print_info "Creating destination bucket..."
        rclone mkdir plane-s3-dest:${DEST_BUCKET}
    fi
    print_success "Destination bucket ready"
elif [ "${MIGRATION_METHOD}" == "awscli" ]; then
    if [ -n "${AWS_ENDPOINT_URL}" ]; then
        aws s3 mb s3://${DEST_BUCKET} --endpoint-url ${AWS_ENDPOINT_URL} 2>/dev/null || true
    else
        aws s3 mb s3://${DEST_BUCKET} 2>/dev/null || true
    fi
    print_success "Destination bucket ready"
fi

################################################################################
# Count Files
################################################################################

print_header "Analyzing Files"

if [ "${MIGRATION_METHOD}" == "rclone" ]; then
    print_info "Counting files in source bucket..."
    FILE_COUNT=$(rclone size plane-minio-source:${SOURCE_BUCKET} --json | grep -o '"count":[0-9]*' | cut -d: -f2)
    FILE_SIZE=$(rclone size plane-minio-source:${SOURCE_BUCKET} --json | grep -o '"bytes":[0-9]*' | cut -d: -f2)

    # Convert bytes to human readable
    FILE_SIZE_HR=$(echo ${FILE_SIZE} | awk '{ split( "B KB MB GB TB" , v ); s=1; while( $1>1024 ){ $1/=1024; s++ } printf "%.2f %s", $1, v[s] }')

    print_info "Files to migrate: ${FILE_COUNT}"
    print_info "Total size: ${FILE_SIZE_HR}"
fi

read -p "Do you want to proceed with migration? (yes/no): " confirm
if [ "${confirm}" != "yes" ]; then
    print_info "Migration cancelled"
    exit 0
fi

################################################################################
# Migrate Files
################################################################################

print_header "Migrating Files"

print_info "Starting file migration..."
print_info "This may take a while depending on the number and size of files"
print_info "Logging to: ${LOG_FILE}"

if [ "${MIGRATION_METHOD}" == "rclone" ]; then
    # Use rclone to sync files
    if rclone sync \
        plane-minio-source:${SOURCE_BUCKET} \
        plane-s3-dest:${DEST_BUCKET} \
        --progress \
        --log-file=${LOG_FILE} \
        --log-level=INFO \
        --transfers=4 \
        --checkers=8; then

        print_success "Files migrated successfully"
    else
        print_error "Migration failed. Check ${LOG_FILE} for details"
        exit 1
    fi

elif [ "${MIGRATION_METHOD}" == "awscli" ]; then
    # Use AWS CLI to sync files
    # First, sync from MinIO using mc
    print_info "Downloading from MinIO..."
    docker run --rm -v $(pwd)/temp_migration:/data minio/mc cp \
        --recursive \
        minio/${SOURCE_BUCKET}/ /data/ \
        --config-dir /tmp/.mc

    print_info "Uploading to S3..."
    if [ -n "${AWS_ENDPOINT_URL}" ]; then
        aws s3 sync ./temp_migration/ s3://${DEST_BUCKET}/ --endpoint-url ${AWS_ENDPOINT_URL}
    else
        aws s3 sync ./temp_migration/ s3://${DEST_BUCKET}/
    fi

    print_info "Cleaning up temporary files..."
    rm -rf ./temp_migration

    print_success "Files migrated successfully"
fi

################################################################################
# Validation
################################################################################

print_header "Validating Migration"

if [ "${MIGRATION_METHOD}" == "rclone" ]; then
    print_info "Checking file counts..."

    DEST_FILE_COUNT=$(rclone size plane-s3-dest:${DEST_BUCKET} --json | grep -o '"count":[0-9]*' | cut -d: -f2)

    print_info "Source files: ${FILE_COUNT}"
    print_info "Destination files: ${DEST_FILE_COUNT}"

    if [ "${FILE_COUNT}" == "${DEST_FILE_COUNT}" ]; then
        print_success "File count matches!"
    else
        print_warning "File count mismatch. Some files may not have been migrated."
        print_info "Check ${LOG_FILE} for details"
    fi
fi

################################################################################
# Generate New Configuration
################################################################################

print_header "Migration Complete!"

print_success "Storage migration completed successfully!"
echo
print_info "Next Steps:"
echo
echo "1. Update your .env.api with the new storage configuration:"
echo

if [ "${PROVIDER_CHOICE}" == "1" ]; then
    # AWS S3
    cat <<EOF
   USE_MINIO=0
   AWS_REGION=${DEST_REGION}
   AWS_ACCESS_KEY_ID=${DEST_ACCESS_KEY}
   AWS_SECRET_ACCESS_KEY=${DEST_SECRET_KEY}
   AWS_S3_BUCKET_NAME=${DEST_BUCKET}
   # Remove or comment out AWS_S3_ENDPOINT_URL for AWS S3

EOF
else
    # S3-compatible
    cat <<EOF
   USE_MINIO=0
   AWS_REGION=${DEST_REGION}
   AWS_ACCESS_KEY_ID=${DEST_ACCESS_KEY}
   AWS_SECRET_ACCESS_KEY=${DEST_SECRET_KEY}
   AWS_S3_ENDPOINT_URL=${DEST_ENDPOINT}
   AWS_S3_BUCKET_NAME=${DEST_BUCKET}
   FILE_SIZE_LIMIT=52428800
   MINIO_ENDPOINT_SSL=1

EOF
fi

echo "2. Restart your Plane API application in Dokploy"
echo
echo "3. Test file uploads and downloads to verify the new storage works"
echo
echo "4. Once verified, you can stop the MinIO container:"
echo "   docker-compose stop minio"
echo
echo "5. Keep the MinIO data volume as backup for a few days:"
echo "   docker volume ls | grep minio"
echo

print_warning "IMPORTANT: Do not remove the MinIO container and volumes until"
print_warning "you have verified the migration is successful and all files are accessible!"

# Cleanup rclone config (remove sensitive data)
if [ "${MIGRATION_METHOD}" == "rclone" ]; then
    print_info "Cleaning up rclone configuration..."
    sed -i '/\[plane-minio-source\]/,/^$/d' ${RCLONE_CONFIG}
    sed -i '/\[plane-s3-dest\]/,/^$/d' ${RCLONE_CONFIG}
fi

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_ENDPOINT_URL

print_success "Migration log saved at: ${LOG_FILE}"
