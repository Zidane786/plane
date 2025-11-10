#!/bin/bash

################################################################################
# Plane API Health Check Script
################################################################################
# This script checks if the Plane API is healthy and responding correctly
#
# Usage:
#   ./api.sh [API_URL]
#
# Example:
#   ./api.sh https://plane-api.mohdop.com
#
# Exit codes:
#   0 - API is healthy
#   1 - API is unhealthy or unreachable
################################################################################

# Configuration
API_URL="${1:-http://localhost:8000}"
HEALTH_ENDPOINT="/api/health/"
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
print_info "Checking API health at: ${API_URL}${HEALTH_ENDPOINT}"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time ${TIMEOUT} \
    "${API_URL}${HEALTH_ENDPOINT}")

if [ "$HTTP_CODE" = "200" ]; then
    print_success "API is healthy (HTTP ${HTTP_CODE})"

    # Get detailed response
    RESPONSE=$(curl -s --max-time ${TIMEOUT} "${API_URL}${HEALTH_ENDPOINT}")
    echo "Response: ${RESPONSE}"

    exit 0
else
    print_error "API health check failed (HTTP ${HTTP_CODE})"

    # Try to get error details
    if [ "$HTTP_CODE" != "000" ]; then
        ERROR=$(curl -s --max-time ${TIMEOUT} "${API_URL}${HEALTH_ENDPOINT}")
        echo "Error: ${ERROR}"
    else
        print_error "Could not connect to API (timeout or connection refused)"
    fi

    exit 1
fi
