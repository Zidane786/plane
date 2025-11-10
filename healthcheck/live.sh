#!/bin/bash

################################################################################
# Plane Live Server Health Check Script
################################################################################
# This script checks if the Plane Live Server (WebSocket) is healthy
#
# Usage:
#   ./live.sh [LIVE_URL]
#
# Example:
#   ./live.sh https://plane.mohdop.com/live
#
# Exit codes:
#   0 - Live server is healthy
#   1 - Live server is unhealthy or unreachable
################################################################################

# Configuration
LIVE_URL="${1:-http://localhost:3000}"
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

# Perform health check on HTTP endpoint
print_info "Checking Live Server HTTP health at: ${LIVE_URL}${HEALTH_ENDPOINT}"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time ${TIMEOUT} \
    "${LIVE_URL}${HEALTH_ENDPOINT}")

if [ "$HTTP_CODE" = "200" ]; then
    print_success "Live Server HTTP endpoint is healthy (HTTP ${HTTP_CODE})"

    # Get detailed response
    RESPONSE=$(curl -s --max-time ${TIMEOUT} "${LIVE_URL}${HEALTH_ENDPOINT}")
    echo "Response: ${RESPONSE}"

    # Try WebSocket connection if wscat is available
    if command -v wscat &> /dev/null; then
        print_info "Testing WebSocket connection..."

        # Convert http(s) to ws(s)
        WS_URL=$(echo "${LIVE_URL}" | sed 's/^http/ws/')

        # Try to connect (timeout after 5 seconds)
        timeout 5 wscat -c "${WS_URL}" --execute "ping" 2>/dev/null && \
            print_success "WebSocket connection successful" || \
            print_info "WebSocket test completed (wscat may not support this protocol)"
    else
        print_info "wscat not installed, skipping WebSocket test"
        print_info "Install with: npm install -g wscat"
    fi

    exit 0
else
    print_error "Live Server health check failed (HTTP ${HTTP_CODE})"

    # Try to get error details
    if [ "$HTTP_CODE" != "000" ]; then
        ERROR=$(curl -s --max-time ${TIMEOUT} "${LIVE_URL}${HEALTH_ENDPOINT}")
        echo "Error: ${ERROR}"
    else
        print_error "Could not connect to Live Server (timeout or connection refused)"
    fi

    exit 1
fi
