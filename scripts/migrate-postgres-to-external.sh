#!/bin/bash

################################################################################
# Plane PostgreSQL Migration Script
################################################################################
# This script migrates your PostgreSQL database from Docker container
# to an external managed database service (AWS RDS, DigitalOcean, etc.)
#
# Usage:
#   ./migrate-postgres-to-external.sh
#
# Prerequisites:
#   - Docker installed and running
#   - PostgreSQL client tools (psql, pg_dump, pg_restore)
#   - Access to both source and destination databases
#   - Sufficient disk space for database backup
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="plane_db_backup_${TIMESTAMP}.sql"
CONTAINER_NAME="plane-postgres"

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
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

################################################################################
# Pre-flight Checks
################################################################################

print_header "Pre-flight Checks"

# Check required commands
check_command docker
check_command pg_dump
check_command psql

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_error "Container '${CONTAINER_NAME}' is not running."
    echo "Please start the container with: docker-compose up -d"
    exit 1
fi

print_success "All prerequisites met"

################################################################################
# Gather Configuration
################################################################################

print_header "Configuration"

# Source database (Docker container)
echo "Source Database (Docker Container):"
read -p "Container name [${CONTAINER_NAME}]: " input_container
CONTAINER_NAME=${input_container:-$CONTAINER_NAME}

read -p "Database name [plane]: " SOURCE_DB
SOURCE_DB=${SOURCE_DB:-plane}

read -p "Database user [plane]: " SOURCE_USER
SOURCE_USER=${SOURCE_USER:-plane}

read -sp "Database password: " SOURCE_PASS
echo

# Destination database (External)
echo -e "\nDestination Database (External Managed Service):"
read -p "Database host (e.g., db.example.com): " DEST_HOST
read -p "Database port [5432]: " DEST_PORT
DEST_PORT=${DEST_PORT:-5432}

read -p "Database name [plane]: " DEST_DB
DEST_DB=${DEST_DB:-plane}

read -p "Database user: " DEST_USER
read -sp "Database password: " DEST_PASS
echo

################################################################################
# Validation
################################################################################

print_header "Validating Connections"

# Test source database connection
print_info "Testing source database connection..."
if docker exec ${CONTAINER_NAME} psql -U ${SOURCE_USER} -d ${SOURCE_DB} -c "SELECT version();" > /dev/null 2>&1; then
    print_success "Source database connection successful"
else
    print_error "Failed to connect to source database"
    exit 1
fi

# Test destination database connection
print_info "Testing destination database connection..."
export PGPASSWORD=${DEST_PASS}
if psql -h ${DEST_HOST} -p ${DEST_PORT} -U ${DEST_USER} -d ${DEST_DB} -c "SELECT version();" > /dev/null 2>&1; then
    print_success "Destination database connection successful"
else
    print_error "Failed to connect to destination database"
    print_warning "Please ensure the database exists and credentials are correct"
    exit 1
fi

################################################################################
# Backup Source Database
################################################################################

print_header "Backing Up Source Database"

# Create backup directory
mkdir -p ${BACKUP_DIR}
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

print_info "Creating backup: ${BACKUP_PATH}"

# Dump database from Docker container
if docker exec ${CONTAINER_NAME} pg_dump -U ${SOURCE_USER} -d ${SOURCE_DB} \
    --clean --if-exists --no-owner --no-privileges > ${BACKUP_PATH}; then
    print_success "Backup created successfully"
    BACKUP_SIZE=$(du -h ${BACKUP_PATH} | cut -f1)
    print_info "Backup size: ${BACKUP_SIZE}"
else
    print_error "Failed to create backup"
    exit 1
fi

################################################################################
# Check Destination Database
################################################################################

print_header "Checking Destination Database"

# Check if destination database is empty
TABLE_COUNT=$(psql -h ${DEST_HOST} -p ${DEST_PORT} -U ${DEST_USER} -d ${DEST_DB} -t -c \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")

if [ ${TABLE_COUNT} -gt 0 ]; then
    print_warning "Destination database is not empty (${TABLE_COUNT} tables found)"
    read -p "Do you want to continue? This will DROP existing tables. (yes/no): " confirm
    if [ "${confirm}" != "yes" ]; then
        print_info "Migration cancelled"
        exit 0
    fi
fi

################################################################################
# Restore to Destination
################################################################################

print_header "Restoring to Destination Database"

print_info "Starting database restore..."

if psql -h ${DEST_HOST} -p ${DEST_PORT} -U ${DEST_USER} -d ${DEST_DB} < ${BACKUP_PATH}; then
    print_success "Database restored successfully"
else
    print_error "Failed to restore database"
    print_warning "Your backup is saved at: ${BACKUP_PATH}"
    exit 1
fi

################################################################################
# Validation
################################################################################

print_header "Validating Migration"

# Count tables in source
SOURCE_TABLE_COUNT=$(docker exec ${CONTAINER_NAME} psql -U ${SOURCE_USER} -d ${SOURCE_DB} -t -c \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)

# Count tables in destination
DEST_TABLE_COUNT=$(psql -h ${DEST_HOST} -p ${DEST_PORT} -U ${DEST_USER} -d ${DEST_DB} -t -c \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)

print_info "Source tables: ${SOURCE_TABLE_COUNT}"
print_info "Destination tables: ${DEST_TABLE_COUNT}"

if [ "${SOURCE_TABLE_COUNT}" == "${DEST_TABLE_COUNT}" ]; then
    print_success "Table count matches"
else
    print_warning "Table count mismatch. Please verify manually."
fi

# Check row counts for key tables
print_info "Checking sample table row counts..."
for table in users projects issues; do
    if docker exec ${CONTAINER_NAME} psql -U ${SOURCE_USER} -d ${SOURCE_DB} -t -c \
        "SELECT 1 FROM information_schema.tables WHERE table_name = '${table}';" | grep -q 1; then

        SOURCE_ROWS=$(docker exec ${CONTAINER_NAME} psql -U ${SOURCE_USER} -d ${SOURCE_DB} -t -c \
            "SELECT COUNT(*) FROM ${table};" 2>/dev/null | xargs || echo "N/A")

        DEST_ROWS=$(psql -h ${DEST_HOST} -p ${DEST_PORT} -U ${DEST_USER} -d ${DEST_DB} -t -c \
            "SELECT COUNT(*) FROM ${table};" 2>/dev/null | xargs || echo "N/A")

        if [ "${SOURCE_ROWS}" == "${DEST_ROWS}" ]; then
            print_success "Table '${table}': ${SOURCE_ROWS} rows (matched)"
        else
            print_warning "Table '${table}': Source=${SOURCE_ROWS}, Dest=${DEST_ROWS}"
        fi
    fi
done

################################################################################
# Generate Connection String
################################################################################

print_header "Migration Complete!"

NEW_DATABASE_URL="postgresql://${DEST_USER}:${DEST_PASS}@${DEST_HOST}:${DEST_PORT}/${DEST_DB}"

print_success "Database migration completed successfully!"
echo
print_info "Next Steps:"
echo "1. Update your .env.api with the new database connection:"
echo
echo "   DATABASE_URL=${NEW_DATABASE_URL}"
echo "   PGHOST=${DEST_HOST}"
echo "   PGPORT=${DEST_PORT}"
echo "   PGUSER=${DEST_USER}"
echo "   PGPASSWORD=${DEST_PASS}"
echo "   PGDATABASE=${DEST_DB}"
echo
echo "2. Restart your Plane API application in Dokploy"
echo
echo "3. Verify the application works correctly with the new database"
echo
echo "4. Once verified, you can stop the Docker PostgreSQL container:"
echo "   docker-compose stop postgres"
echo
echo "5. Your backup is saved at: ${BACKUP_PATH}"
echo

print_warning "IMPORTANT: Do not remove the Docker PostgreSQL container until"
print_warning "you have verified the migration is successful!"

################################################################################
# Rollback Instructions
################################################################################

cat > ${BACKUP_DIR}/rollback_${TIMESTAMP}.sh <<EOF
#!/bin/bash
# Rollback script for migration ${TIMESTAMP}
# Generated on: $(date)

# Restore from backup
docker exec -i ${CONTAINER_NAME} psql -U ${SOURCE_USER} -d ${SOURCE_DB} < ${BACKUP_PATH}

# Update environment variables back to Docker database
echo "Restore the following environment variables in Dokploy:"
echo "DATABASE_URL=postgresql://${SOURCE_USER}:${SOURCE_PASS}@${CONTAINER_NAME}:5432/${SOURCE_DB}"
echo "PGHOST=${CONTAINER_NAME}"
echo "PGPORT=5432"
echo "PGUSER=${SOURCE_USER}"
echo "PGDATABASE=${SOURCE_DB}"
EOF

chmod +x ${BACKUP_DIR}/rollback_${TIMESTAMP}.sh

print_info "Rollback script saved at: ${BACKUP_DIR}/rollback_${TIMESTAMP}.sh"

unset PGPASSWORD
