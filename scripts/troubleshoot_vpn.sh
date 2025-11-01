#!/bin/bash

# VPN Troubleshooting Script for n8n-installer
# Diagnoses common issues with wg-easy and vpn-telegram-bot containers

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

log_info "========================================="
log_info "VPN Troubleshooting Diagnostic Tool"
log_info "========================================="
echo

# ----------------------------------------------------------------
# Step 1: Check if VPN profile is active
# ----------------------------------------------------------------
log_info "[1/6] Checking VPN profile status..."

if [ ! -f "$ENV_FILE" ]; then
    log_error ".env file not found at $ENV_FILE"
    log_error "Run scripts/install.sh first to generate .env file"
    exit 1
fi

COMPOSE_PROFILES=$(grep "^COMPOSE_PROFILES=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/"//g')

if [[ "$COMPOSE_PROFILES" != *"vpn"* ]]; then
    log_warning "VPN profile is NOT enabled in COMPOSE_PROFILES"
    log_info "To enable VPN, run: bash scripts/04_wizard.sh and select VPN option"
    exit 0
fi

log_success "VPN profile is enabled"
echo

# ----------------------------------------------------------------
# Step 2: Check required environment variables
# ----------------------------------------------------------------
log_info "[2/6] Checking required environment variables..."

MISSING_VARS=()

# Helper to check variable
check_env_var() {
    local var_name="$1"
    local var_value=$(grep "^${var_name}=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/"//g')

    if [ -z "$var_value" ]; then
        MISSING_VARS+=("$var_name")
        log_error "Missing: $var_name"
        return 1
    else
        log_success "Found: $var_name"
        return 0
    fi
}

check_env_var "BOT_TOKEN"
check_env_var "WG_HOST"
check_env_var "WG_PASSWORD"

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo
    log_error "Missing required environment variables: ${MISSING_VARS[*]}"
    log_info "Run: bash scripts/05_configure_services.sh to set these variables"
    log_info "Or manually edit $ENV_FILE and add:"
    for var in "${MISSING_VARS[@]}"; do
        case "$var" in
            BOT_TOKEN)
                echo "  BOT_TOKEN=\"<token from @BotFather>\""
                ;;
            WG_HOST)
                echo "  WG_HOST=\"<your server IP or domain>\""
                ;;
            WG_PASSWORD)
                echo "  WG_PASSWORD=\"<secure password>\""
                ;;
        esac
    done
    exit 1
fi

echo

# ----------------------------------------------------------------
# Step 3: Check WireGuard kernel support
# ----------------------------------------------------------------
log_info "[3/6] Checking WireGuard kernel support..."

KERNEL_VERSION=$(uname -r)
log_info "Kernel version: $KERNEL_VERSION"

# Check if wireguard module is loaded or available
if lsmod | grep -q wireguard; then
    log_success "WireGuard kernel module is loaded"
elif modprobe -n wireguard &>/dev/null; then
    log_warning "WireGuard module available but not loaded"
    log_info "Loading WireGuard module..."

    if sudo modprobe wireguard 2>/dev/null; then
        log_success "WireGuard module loaded successfully"
    else
        log_error "Failed to load WireGuard module"
        log_info "Install WireGuard tools:"
        log_info "  Fedora/RHEL: sudo dnf install wireguard-tools"
        log_info "  Debian/Ubuntu: sudo apt install wireguard-tools"
        exit 1
    fi
else
    log_error "WireGuard kernel module not available"
    log_info "WireGuard requires Linux kernel >= 5.6 or wireguard-dkms package"
    log_info "Install WireGuard:"
    log_info "  Fedora/RHEL: sudo dnf install wireguard-tools"
    log_info "  Debian/Ubuntu: sudo apt install wireguard-tools"
    exit 1
fi

echo

# ----------------------------------------------------------------
# Step 4: Check Docker container status
# ----------------------------------------------------------------
log_info "[4/6] Checking Docker container status..."

cd "$PROJECT_ROOT"

if ! docker ps -a --format '{{.Names}}' | grep -q "wg-easy"; then
    log_warning "wg-easy container not found"
    log_info "Container may not have been created yet"
    log_info "Run: docker compose --profile vpn up -d"
    exit 0
fi

CONTAINER_STATUS=$(docker inspect wg-easy --format '{{.State.Status}}' 2>/dev/null || echo "not found")
CONTAINER_HEALTH=$(docker inspect wg-easy --format '{{.State.Health.Status}}' 2>/dev/null || echo "no health check")

log_info "Container status: $CONTAINER_STATUS"
log_info "Health status: $CONTAINER_HEALTH"

if [ "$CONTAINER_STATUS" != "running" ]; then
    log_error "wg-easy container is not running"
    log_info "Showing last 30 lines of logs..."
    echo
    docker logs wg-easy --tail 30
    echo
    log_info "To restart container: docker compose --profile vpn restart wg-easy"
    exit 1
fi

if [ "$CONTAINER_HEALTH" = "unhealthy" ]; then
    log_error "wg-easy container is unhealthy"
    log_info "Showing last 30 lines of logs..."
    echo
    docker logs wg-easy --tail 30
    echo
fi

echo

# ----------------------------------------------------------------
# Step 5: Check health check endpoint manually
# ----------------------------------------------------------------
log_info "[5/6] Testing health check endpoint..."

if docker exec wg-easy curl -f -s http://localhost:51821 >/dev/null 2>&1; then
    log_success "Health check endpoint responds correctly"
else
    log_error "Health check endpoint (http://localhost:51821) is not responding"
    log_info "Checking if wg-easy process is running inside container..."

    if docker exec wg-easy ps aux | grep -q "wg-easy"; then
        log_info "wg-easy process is running, but web UI not responding"
        log_info "Check logs for startup errors"
    else
        log_error "wg-easy process is NOT running inside container"
        log_info "Container may have crashed during startup"
    fi

    echo
    log_info "Full container logs:"
    docker logs wg-easy
    exit 1
fi

echo

# ----------------------------------------------------------------
# Step 6: Check network configuration
# ----------------------------------------------------------------
log_info "[6/6] Checking network configuration..."

# Check IP forwarding
IP_FORWARD=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
if [ "$IP_FORWARD" = "1" ]; then
    log_success "IP forwarding is enabled"
else
    log_warning "IP forwarding is DISABLED"
    log_info "WireGuard requires IP forwarding to route traffic"
    log_info "To enable temporarily: sudo sysctl -w net.ipv4.ip_forward=1"
    log_info "To enable permanently: echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf"
fi

# Check if port 51821 (wg-easy UI) is listening
if sudo netstat -tuln 2>/dev/null | grep -q ":51821" || sudo ss -tuln 2>/dev/null | grep -q ":51821"; then
    log_success "Port 51821 (wg-easy UI) is listening"
else
    log_warning "Port 51821 is NOT listening"
    log_info "wg-easy web UI should listen on this port"
fi

# Check if port 51820 (WireGuard VPN) is listening
if sudo netstat -uln 2>/dev/null | grep -q ":51820" || sudo ss -uln 2>/dev/null | grep -q ":51820"; then
    log_success "Port 51820 (WireGuard VPN) is listening"
else
    log_warning "Port 51820 is NOT listening"
    log_info "WireGuard VPN server should listen on UDP port 51820"
fi

echo
log_info "========================================="
log_success "VPN Diagnostics Complete"
log_info "========================================="
echo

# Final recommendations
if [ "$CONTAINER_HEALTH" = "healthy" ]; then
    log_success "All checks passed! VPN is working correctly."
    echo
    log_info "Next steps:"
    log_info "  1. Access wg-easy UI: http://${WG_HOST:-your-server}:51821"
    log_info "  2. Send /start to your Telegram bot to get VPN config"
    log_info "  3. Check final report: bash scripts/07_final_report.sh"
else
    log_warning "Some issues were detected. Review the output above."
    echo
    log_info "Common fixes:"
    log_info "  1. Restart container: docker compose --profile vpn restart wg-easy"
    log_info "  2. Check full logs: docker logs wg-easy"
    log_info "  3. Rebuild container: docker compose --profile vpn up -d --force-recreate wg-easy"
fi

exit 0
