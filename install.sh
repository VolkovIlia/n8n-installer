#!/bin/bash
# n8n-installer installation script with VPN support

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

show_menu() {
    echo ""
    echo "================================"
    echo "  n8n Installer Menu"
    echo "================================"
    echo "1. Install n8n"
    echo "2. Update n8n"
    echo "3. Install VPN + Telegram bot"
    echo "4. Remove n8n"
    echo "5. Remove VPN"
    echo "6. Exit"
    echo "================================"
    echo -n "Enter your choice [1-6]: "
}

check_prerequisites() {
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker first."
        echo "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi

    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose not found or too old."
        echo "Visit: https://docs.docker.com/compose/install/"
        exit 1
    fi

    print_success "Prerequisites check passed"
}

install_vpn() {
    echo ""
    echo "================================"
    echo "  VPN Installation"
    echo "================================"
    echo ""

    check_prerequisites

    # VPN-specific prerequisite checks
    echo "🔍 Checking VPN prerequisites..."

    # Check kernel version for WireGuard support
    KERNEL_VERSION=$(uname -r | cut -d'.' -f1-2)
    KERNEL_MAJOR=$(echo $KERNEL_VERSION | cut -d'.' -f1)
    KERNEL_MINOR=$(echo $KERNEL_VERSION | cut -d'.' -f2)

    if [ "$KERNEL_MAJOR" -lt 5 ] || ([ "$KERNEL_MAJOR" -eq 5 ] && [ "$KERNEL_MINOR" -lt 6 ]); then
        print_warning "Kernel $KERNEL_VERSION detected. WireGuard kernel module requires ≥5.6"
        print_warning "Will fallback to wireguard-go if needed"
    else
        print_success "Kernel $KERNEL_VERSION supports WireGuard module"
    fi

    # Check if ports are available
    if command -v ss &> /dev/null; then
        if ss -tulpn 2>/dev/null | grep -q ":51820 "; then
            print_error "Port 51820 (WireGuard) is already in use"
            print_error "Please free the port or change WG_PORT in docker-compose.yml"
            exit 1
        fi
        if ss -tulpn 2>/dev/null | grep -q ":51821 "; then
            print_error "Port 51821 (wg-easy UI) is already in use"
            print_error "Please free the port or change WG_UI_PORT in docker-compose.yml"
            exit 1
        fi
        print_success "Ports 51820 and 51821 are available"
    fi

    # Check if .env exists
    if [ ! -f .env ]; then
        print_warning ".env file not found. Creating..."
        touch .env
    fi

    # Prompt for BOT_TOKEN with validation
    echo ""
    echo "📱 Telegram Bot Setup"
    echo "-------------------"
    echo "To create a bot:"
    echo "1. Open Telegram and find @BotFather"
    echo "2. Send /newbot command"
    echo "3. Follow instructions and copy token"
    echo ""

    while true; do
        read -p "Enter Telegram Bot Token: " BOT_TOKEN

        if [ -z "$BOT_TOKEN" ]; then
            print_error "Bot token is required"
            read -p "Try again? (y/n): " retry
            [ "$retry" != "y" ] && exit 1
            continue
        fi

        # Validate BOT_TOKEN format: digits:alphanumeric_-{35}
        if [[ "$BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]{35}$ ]]; then
            print_success "Bot token format is valid"
            break
        else
            print_error "Invalid bot token format"
            echo "Expected format: 1234567890:ABCdefGHIjklMNOpqrsTUVwxyz"
            echo "Your token: $BOT_TOKEN"
            read -p "Try again? (y/n): " retry
            [ "$retry" != "y" ] && exit 1
        fi
    done

    # Auto-detect external IP
    echo ""
    echo "🌐 Detecting external IP..."
    WG_HOST=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "")

    if [ -z "$WG_HOST" ]; then
        print_warning "Could not auto-detect IP"
        read -p "Enter WireGuard host IP or domain: " WG_HOST
    else
        print_success "Detected IP: $WG_HOST"
        read -p "Use this IP? (y/n): " confirm
        if [ "$confirm" != "y" ]; then
            read -p "Enter WireGuard host IP or domain: " WG_HOST
        fi
    fi

    if [ -z "$WG_HOST" ]; then
        print_error "WireGuard host is required"
        exit 1
    fi

    # Generate WG_PASSWORD
    WG_PASSWORD=$(openssl rand -base64 32)
    print_success "Generated wg-easy admin password"

    # Optional: User whitelist
    echo ""
    echo "🔐 Security: Access Control (Recommended)"
    echo "-------------------------------------------"
    echo "BOT_WHITELIST restricts who can request VPN configs"
    echo ""
    read -p "Enable user whitelist? (y/n): " enable_whitelist
    if [ "$enable_whitelist" = "y" ]; then
        echo ""
        echo "How to get your Telegram user ID:"
        echo "  Method 1: Open Telegram → search @userinfobot → send any message"
        echo "  Method 2: Send /start to your bot → check logs later"
        echo ""
        echo "Enter Telegram user IDs (comma-separated)"
        echo "Example: 123456789,987654321"
        read -p "User IDs: " BOT_WHITELIST

        if [ -n "$BOT_WHITELIST" ]; then
            print_success "Whitelist configured: $BOT_WHITELIST"
        else
            print_warning "Whitelist empty - public access mode (less secure)"
        fi
    else
        BOT_WHITELIST=""
        print_warning "Skipping whitelist - bot will accept requests from ALL users"
    fi

    # Optional: Admin list
    echo ""
    read -p "Set bot admins? (y/n): " enable_admins
    if [ "$enable_admins" = "y" ]; then
        echo "Enter Telegram user IDs for admins (comma-separated):"
        read -p "Admin IDs: " BOT_ADMINS
    else
        BOT_ADMINS=""
    fi

    # Append to .env
    echo "" >> .env
    echo "# VPN Configuration" >> .env
    echo "BOT_TOKEN=$BOT_TOKEN" >> .env
    echo "WG_HOST=$WG_HOST" >> .env
    echo "WG_PASSWORD=$WG_PASSWORD" >> .env

    if [ -n "$BOT_WHITELIST" ]; then
        echo "BOT_WHITELIST=$BOT_WHITELIST" >> .env
    fi

    if [ -n "$BOT_ADMINS" ]; then
        echo "BOT_ADMINS=$BOT_ADMINS" >> .env
    fi

    # Set secure permissions
    chmod 600 .env
    print_success ".env file updated with VPN config"

    # Start VPN services
    echo ""
    echo "🚀 Starting VPN services..."
    docker compose --profile vpn up -d

    # Wait for health checks
    echo "⏳ Waiting for services to start..."
    sleep 10

    # Check service status
    if docker ps | grep -q wg-easy; then
        print_success "wg-easy container running"
    else
        print_error "wg-easy failed to start"
        docker compose logs wg-easy
        exit 1
    fi

    if docker ps | grep -q vpn-telegram-bot; then
        print_success "vpn-telegram-bot container running"
    else
        print_error "vpn-telegram-bot failed to start"
        docker compose logs vpn-telegram-bot
        exit 1
    fi

    # Show success message
    echo ""
    echo "================================"
    print_success "VPN installation complete!"
    echo "================================"
    echo ""
    echo "📊 Access Information:"
    echo "-------------------"
    echo "wg-easy UI: http://$WG_HOST:51821"
    echo "Password: $WG_PASSWORD"
    echo ""
    echo "🤖 Telegram Bot:"
    echo "-------------------"
    echo "1. Find your bot in Telegram"
    echo "2. Send /start to begin"
    echo "3. Use /request to get VPN config"
    echo ""
    echo "💾 Password saved in .env file"
    echo "================================"
}

remove_vpn() {
    echo ""
    echo "================================"
    echo "  VPN Removal"
    echo "================================"
    echo ""

    read -p "Are you sure you want to remove VPN? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "Cancelled"
        return
    fi

    echo "🗑️  Stopping VPN services..."
    docker compose --profile vpn down

    echo "🗑️  Removing VPN volumes..."
    docker volume rm n8n-installer_wg_data 2>/dev/null || true

    print_success "VPN services removed"
    echo ""
    print_warning "VPN config still in .env file (manual removal required)"
}

install_n8n() {
    echo "TODO: Implement n8n installation"
    print_warning "Not implemented yet"
}

update_n8n() {
    echo "TODO: Implement n8n update"
    print_warning "Not implemented yet"
}

remove_n8n() {
    echo "TODO: Implement n8n removal"
    print_warning "Not implemented yet"
}

# Main loop
while true; do
    show_menu
    read choice

    case $choice in
        1)
            install_n8n
            ;;
        2)
            update_n8n
            ;;
        3)
            install_vpn
            ;;
        4)
            remove_n8n
            ;;
        5)
            remove_vpn
            ;;
        6)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid option. Please choose 1-6"
            ;;
    esac

    echo ""
    read -p "Press Enter to continue..."
done
