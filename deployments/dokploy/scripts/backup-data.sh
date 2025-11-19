#!/bin/bash

################################################################################
# Plane Automated Backup Script (Dokploy Compatible)
################################################################################
# This script creates backups of PostgreSQL database and MinIO storage
# Can be run manually or scheduled via cron
#
# Usage:
#   ./backup-data.sh [--database-only|--storage-only]
#
# Cron example (daily at 2 AM):
#   0 2 * * * /path/to/backup-data.sh >> /var/log/plane-backup.log 2>&1
#
# Prerequisites:
#   - Docker installed and running
#   - Sufficient disk space for backups
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_BASE_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE_ONLY=$(date +%Y%m%d)
RETENTION_DAYS=30

# Container names (Updated for Dokploy)
POSTGRES_CONTAINER="plane-db"
MINIO_CONTAINER="plane-minio"

# Network name (Updated for Dokploy)
DOCKER_NETWORK="plane-backend-network"

# Database configuration
POSTGRES_USER="${POSTGRES_USER:-plane}"
POSTGRES_DB="${POSTGRES_DB:-plane}"

# MinIO configuration
MINIO_BUCKET="${MINIO_BUCKET:-uploads}"

# Backup paths
DB_BACKUP_DIR="${BACKUP_BASE_DIR}/database"
STORAGE_BACKUP_DIR="${BACKUP_BASE_DIR}/storage"

# Parse command line arguments
BACKUP_DATABASE=true
BACKUP_STORAGE=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --database-only)
            BACKUP_STORAGE=false
            shift
            ;;
        --storage-only)
            BACKUP_DATABASE=false
            shift
            ;;
        --help)
            echo "Usage: $0 [--database-only|--storage-only]"
            echo ""
            echo "Options:"
            echo "  --database-only   Backup only the PostgreSQL database"
            echo "  --storage-only    Backup only the MinIO storage"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

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

check_container() {
    local container=$1
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        print_warning "Container '${container}' is not running"
        return 1
    fi
    return 0
}

get_size() {
    local path=$1
    if [ -f "${path}" ]; then
        du -h "${path}" | cut -f1
    elif [ -d "${path}" ]; then
        du -sh "${path}" | cut -f1
    else
        echo "N/A"
    fi
}

################################################################################
# Create Backup Directories
################################################################################

mkdir -p "${DB_BACKUP_DIR}"
mkdir -p "${STORAGE_BACKUP_DIR}"

################################################################################
# Backup PostgreSQL Database
################################################################################

if [ "${BACKUP_DATABASE}" = true ]; then
    print_header "Backing Up PostgreSQL Database"

    if check_container "${POSTGRES_CONTAINER}"; then
        DB_BACKUP_FILE="${DB_BACKUP_DIR}/plane_db_${TIMESTAMP}.sql"
        DB_BACKUP_COMPRESSED="${DB_BACKUP_FILE}.gz"

        print_info "Creating database backup..."

        # Dump database
        if docker exec ${POSTGRES_CONTAINER} pg_dump \
            -U ${POSTGRES_USER} \
            -d ${POSTGRES_DB} \
            --clean --if-exists \
            --no-owner --no-privileges > "${DB_BACKUP_FILE}"; then

            print_success "Database dumped successfully"

            # Compress backup
            print_info "Compressing backup..."
            gzip "${DB_BACKUP_FILE}"

            BACKUP_SIZE=$(get_size "${DB_BACKUP_COMPRESSED}")
            print_success "Database backup created: ${DB_BACKUP_COMPRESSED}"
            print_info "Backup size: ${BACKUP_SIZE}"

            # Create latest symlink
            ln -sf "$(basename ${DB_BACKUP_COMPRESSED})" "${DB_BACKUP_DIR}/latest.sql.gz"

        else
            print_error "Failed to backup database"
            exit 1
        fi
    else
        print_error "Cannot backup database: container not running"
        exit 1
    fi
fi

################################################################################
# Backup MinIO Storage
################################################################################

if [ "${BACKUP_STORAGE}" = true ]; then
    print_header "Backing Up MinIO Storage"

    if check_container "${MINIO_CONTAINER}"; then
        STORAGE_BACKUP_DIR_DATED="${STORAGE_BACKUP_DIR}/${DATE_ONLY}"
        mkdir -p "${STORAGE_BACKUP_DIR_DATED}"

        print_info "Creating storage backup..."
        print_info "This may take a while depending on storage size..."

        # Use MinIO client to backup
        if docker run --rm \
            --network ${DOCKER_NETWORK} \
            -v "${STORAGE_BACKUP_DIR_DATED}:/backup" \
            minio/mc \
            cp --recursive \
            minio/${MINIO_BUCKET}/ /backup/ \
            --config-dir /tmp/.mc \
            --quiet; then

            BACKUP_SIZE=$(get_size "${STORAGE_BACKUP_DIR_DATED}")
            print_success "Storage backup created: ${STORAGE_BACKUP_DIR_DATED}"
            print_info "Backup size: ${BACKUP_SIZE}"

            # Create latest symlink
            ln -sfn "$(basename ${STORAGE_BACKUP_DIR_DATED})" "${STORAGE_BACKUP_DIR}/latest"

            # Create tarball for easier storage
            print_info "Creating compressed archive..."
            STORAGE_TARBALL="${STORAGE_BACKUP_DIR}/plane_storage_${DATE_ONLY}.tar.gz"

            tar -czf "${STORAGE_TARBALL}" -C "${STORAGE_BACKUP_DIR_DATED}" .

            TARBALL_SIZE=$(get_size "${STORAGE_TARBALL}")
            print_success "Compressed archive created: ${STORAGE_TARBALL}"
            print_info "Archive size: ${TARBALL_SIZE}"

        else
            print_error "Failed to backup storage"
            exit 1
        fi
    else
        print_warning "Cannot backup storage: MinIO container not running"
    fi
fi

################################################################################
# Cleanup Old Backups
################################################################################

print_header "Cleaning Up Old Backups"

print_info "Removing backups older than ${RETENTION_DAYS} days..."

# Clean old database backups
if [ "${BACKUP_DATABASE}" = true ]; then
    DELETED_DB=$(find "${DB_BACKUP_DIR}" -name "*.sql.gz" -type f -mtime +${RETENTION_DAYS} -delete -print | wc -l)
    print_info "Deleted ${DELETED_DB} old database backups"
fi

# Clean old storage backups
if [ "${BACKUP_STORAGE}" = true ]; then
    DELETED_STORAGE=$(find "${STORAGE_BACKUP_DIR}" -maxdepth 1 -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} \; -print | wc -l)
    print_info "Deleted ${DELETED_STORAGE} old storage backup directories"

    DELETED_TARBALLS=$(find "${STORAGE_BACKUP_DIR}" -name "*.tar.gz" -type f -mtime +${RETENTION_DAYS} -delete -print | wc -l)
    print_info "Deleted ${DELETED_TARBALLS} old storage tarballs"
fi

################################################################################
# Backup Summary
################################################################################

print_header "Backup Summary"

echo "Backup completed at: $(date)"
echo "Backup location: ${BACKUP_BASE_DIR}"
echo

if [ "${BACKUP_DATABASE}" = true ]; then
    echo "Database Backups:"
    DB_COUNT=$(find "${DB_BACKUP_DIR}" -name "*.sql.gz" -type f | wc -l)
    DB_SIZE=$(du -sh "${DB_BACKUP_DIR}" | cut -f1)
    echo "  - Total backups: ${DB_COUNT}"
    echo "  - Total size: ${DB_SIZE}"
    echo "  - Latest: ${DB_BACKUP_DIR}/latest.sql.gz"
    echo
fi

if [ "${BACKUP_STORAGE}" = true ]; then
    echo "Storage Backups:"
    STORAGE_COUNT=$(find "${STORAGE_BACKUP_DIR}" -maxdepth 1 -type d ! -path "${STORAGE_BACKUP_DIR}" | wc -l)
    STORAGE_SIZE=$(du -sh "${STORAGE_BACKUP_DIR}" | cut -f1)
    echo "  - Total backups: ${STORAGE_COUNT}"
    echo "  - Total size: ${STORAGE_SIZE}"
    echo "  - Latest: ${STORAGE_BACKUP_DIR}/latest"
    echo
fi

print_success "Backup completed successfully!"
