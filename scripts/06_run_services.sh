#!/bin/bash

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# 1. Check for .env file
if [ ! -f ".env" ]; then
  log_error ".env file not found in project root." >&2
  exit 1
fi

# 2. Check for docker-compose.yml file
if [ ! -f "docker-compose.yml" ]; then
  log_error "docker-compose.yml file not found in project root." >&2
  exit 1
fi

# 3. Check for Caddyfile (optional but recommended for reverse proxy)
if [ ! -f "Caddyfile" ]; then
  log_warning "Caddyfile not found in project root. Reverse proxy might not work as expected." >&2
  exit 1
fi

# 4. Check if Docker daemon is running
if ! docker info > /dev/null 2>&1; then
  log_error "Docker daemon is not running. Please start Docker and try again." >&2
  exit 1
fi

# 5. Check if start_services.py exists and is executable
if [ ! -f "start_services.py" ]; then
  log_error "start_services.py file not found in project root." >&2
  exit 1
fi

if [ ! -x "start_services.py" ]; then
  log_warning "start_services.py is not executable. Making it executable..."
  chmod +x "start_services.py"
fi

# ----------------------------------------------------------------
# VPN Pre-flight Checks (if VPN profile is enabled)
# ----------------------------------------------------------------
COMPOSE_PROFILES=$(grep "^COMPOSE_PROFILES=" ".env" | cut -d'=' -f2- | sed 's/"//g' || echo "")

if [[ "$COMPOSE_PROFILES" == *"vpn"* ]]; then
  log_info "VPN profile detected. Running pre-flight checks..."

  # Check required environment variables
  MISSING_VPN_VARS=()

  BOT_TOKEN=$(grep "^BOT_TOKEN=" ".env" | cut -d'=' -f2- | sed 's/"//g' || echo "")
  WG_HOST=$(grep "^WG_HOST=" ".env" | cut -d'=' -f2- | sed 's/"//g' || echo "")
  WG_PASSWORD=$(grep "^WG_PASSWORD=" ".env" | cut -d'=' -f2- | sed 's/"//g' || echo "")

  [ -z "$BOT_TOKEN" ] && MISSING_VPN_VARS+=("BOT_TOKEN")
  [ -z "$WG_HOST" ] && MISSING_VPN_VARS+=("WG_HOST")
  [ -z "$WG_PASSWORD" ] && MISSING_VPN_VARS+=("WG_PASSWORD")

  if [ ${#MISSING_VPN_VARS[@]} -gt 0 ]; then
    log_error "VPN profile is enabled but required environment variables are missing:" >&2
    for var in "${MISSING_VPN_VARS[@]}"; do
      echo "  - $var" >&2
    done
    echo >&2
    log_error "Run: bash scripts/05_configure_services.sh to configure VPN" >&2
    log_error "Or run: bash scripts/troubleshoot_vpn.sh for detailed diagnostics" >&2
    exit 1
  fi

  # Check WireGuard kernel support
  if ! lsmod | grep -q wireguard && ! modprobe -n wireguard &>/dev/null; then
    log_warning "WireGuard kernel module not found. Attempting to load..."

    if command -v modprobe &>/dev/null && sudo modprobe wireguard 2>/dev/null; then
      log_success "WireGuard module loaded successfully"
    else
      log_error "WireGuard kernel module is not available" >&2
      log_error "Install WireGuard tools:" >&2
      log_error "  Fedora/RHEL: sudo dnf install wireguard-tools" >&2
      log_error "  Debian/Ubuntu: sudo apt install wireguard-tools" >&2
      echo >&2
      log_error "For detailed diagnostics, run: bash scripts/troubleshoot_vpn.sh" >&2
      exit 1
    fi
  else
    log_success "WireGuard kernel support verified"
  fi

  log_success "VPN pre-flight checks passed"
fi

log_info "Launching services using start_services.py..."
# Execute start_services.py
./start_services.py

exit 0 