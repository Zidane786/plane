#!/bin/bash

################################################################################
# Plane Frontend Health Check Script
################################################################################
# This script checks if the Plane Frontend is healthy and responding correctly
#
# Usage:
#   ./frontend.sh [FRONTEND_URL]
#
# Example:
#   ./frontend.sh https://plane.mohdop.com
#
# Exit codes:
#   0 - Frontend is healthy
#   1 - Frontend is unhealthy or unreachable
################################################################################

# Configuration
FRONTEND_URL="${1:-http://localhost:3000}"
HEALTH_ENDPOINT="/health"
TIMEOUT=10

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if curl is available
if ! command -v curl &> /dev/null; then
    print_error "curl is not installed"
    exit 1
fi

# Perform health check
print_info "Checking Frontend health at: ${FRONTEND_URL}${HEALTH_ENDPOINT}"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time ${TIMEOUT} \
    "${FRONTEND_URL}${HEALTH_ENDPOINT}")

if [ "$HTTP_CODE" = "200" ]; then
    print_success "Frontend is healthy (HTTP ${HTTP_CODE})"
    exit 0
fi

# If /health doesn't exist, try homepage
print_info "Trying root endpoint..."

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time ${TIMEOUT} \
    "${FRONTEND_URL}/")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    print_success "Frontend is reachable (HTTP ${HTTP_CODE})"

    # Check if we can get HTML content
    CONTENT=$(curl -s --max-time ${TIMEOUT} "${FRONTEND_URL}/" | head -n 10)
    if echo "$CONTENT" | grep -qi "html"; then
        print_success "Frontend is serving HTML content"
        exit 0
    fi
fi

print_error "Frontend health check failed (HTTP ${HTTP_CODE})"

if [ "$HTTP_CODE" = "000" ]; then
    print_error "Could not connect to frontend (timeout or connection refused)"
fi

exit 1
