#!/bin/bash

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

# Ensure .env exists
if [ ! -f "$ENV_FILE" ]; then
  touch "$ENV_FILE"
fi

# Helper: read value from .env (without surrounding quotes)
read_env_var() {
  local var_name="$1"
  if grep -q "^${var_name}=" "$ENV_FILE"; then
    grep "^${var_name}=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/^"//' | sed 's/"$//'
  else
    echo ""
  fi
}

# Helper: upsert value into .env (quote the value)
write_env_var() {
  local var_name="$1"
  local var_value="$2"
  if grep -q "^${var_name}=" "$ENV_FILE"; then
    # use different delimiter to be safe
    sed -i.bak "\|^${var_name}=|d" "$ENV_FILE"
  fi
  echo "${var_name}=\"${var_value}\"" >> "$ENV_FILE"
}

log_info "Configuring service options in .env..."


# ----------------------------------------------------------------
# Prompt for OpenAI API key (optional) using .env value as source of truth
# ----------------------------------------------------------------
EXISTING_OPENAI_API_KEY="$(read_env_var OPENAI_API_KEY)"
OPENAI_API_KEY=""
if [[ -z "$EXISTING_OPENAI_API_KEY" ]]; then
    require_whiptail
    OPENAI_API_KEY=$(wt_input "OpenAI API Key" "Optional: Used by Supabase AI (SQL assistance) and Crawl4AI. Leave empty to skip." "") || true
    if [[ -n "$OPENAI_API_KEY" ]]; then
        write_env_var "OPENAI_API_KEY" "$OPENAI_API_KEY"
    fi
else
    # Reuse existing value without prompting
    OPENAI_API_KEY="$EXISTING_OPENAI_API_KEY"
fi


# ----------------------------------------------------------------
# Logic for n8n workflow import (RUN_N8N_IMPORT)
# ----------------------------------------------------------------
final_run_n8n_import_decision="false"
require_whiptail
if wt_yesno "Import n8n Workflows" "Import ~300 ready-made n8n workflows now? This can take ~30 minutes." "no"; then
    final_run_n8n_import_decision="true"
else
    final_run_n8n_import_decision="false"
fi

# Persist RUN_N8N_IMPORT to .env
write_env_var "RUN_N8N_IMPORT" "$final_run_n8n_import_decision"


# ----------------------------------------------------------------
# Prompt for number of n8n workers
# ----------------------------------------------------------------
echo "" # Add a newline for better formatting
log_info "Configuring n8n worker count..."
EXISTING_N8N_WORKER_COUNT="$(read_env_var N8N_WORKER_COUNT)"
require_whiptail
if [[ -n "$EXISTING_N8N_WORKER_COUNT" ]]; then
    N8N_WORKER_COUNT_CURRENT="$EXISTING_N8N_WORKER_COUNT"
    N8N_WORKER_COUNT_INPUT_RAW=$(wt_input "n8n Workers (instances)" "Enter new number of n8n workers, or leave as current ($N8N_WORKER_COUNT_CURRENT)." "") || true
    if [[ -z "$N8N_WORKER_COUNT_INPUT_RAW" ]]; then
        N8N_WORKER_COUNT="$N8N_WORKER_COUNT_CURRENT"
    else
        if [[ "$N8N_WORKER_COUNT_INPUT_RAW" =~ ^0*[1-9][0-9]*$ ]]; then
            N8N_WORKER_COUNT_TEMP="$((10#$N8N_WORKER_COUNT_INPUT_RAW))"
            if [[ "$N8N_WORKER_COUNT_TEMP" -ge 1 ]]; then
                if wt_yesno "Confirm Workers" "Update n8n workers to $N8N_WORKER_COUNT_TEMP?" "no"; then
                    N8N_WORKER_COUNT="$N8N_WORKER_COUNT_TEMP"
                else
                    N8N_WORKER_COUNT="$N8N_WORKER_COUNT_CURRENT"
                    log_info "Change declined. Keeping N8N_WORKER_COUNT at $N8N_WORKER_COUNT."
                fi
            else
                log_warning "Invalid input '$N8N_WORKER_COUNT_INPUT_RAW'. Number must be positive. Keeping $N8N_WORKER_COUNT_CURRENT."
                N8N_WORKER_COUNT="$N8N_WORKER_COUNT_CURRENT"
            fi
        else
            log_warning "Invalid input '$N8N_WORKER_COUNT_INPUT_RAW'. Please enter a positive integer. Keeping $N8N_WORKER_COUNT_CURRENT."
            N8N_WORKER_COUNT="$N8N_WORKER_COUNT_CURRENT"
        fi
    fi
else
    while true; do
        N8N_WORKER_COUNT_INPUT_RAW=$(wt_input "n8n Workers" "Enter number of n8n workers to run (default 1)." "1") || true
        N8N_WORKER_COUNT_CANDIDATE="${N8N_WORKER_COUNT_INPUT_RAW:-1}"
        if [[ "$N8N_WORKER_COUNT_CANDIDATE" =~ ^0*[1-9][0-9]*$ ]]; then
            N8N_WORKER_COUNT_VALIDATED="$((10#$N8N_WORKER_COUNT_CANDIDATE))"
            if [[ "$N8N_WORKER_COUNT_VALIDATED" -ge 1 ]]; then
                if wt_yesno "Confirm Workers" "Run $N8N_WORKER_COUNT_VALIDATED n8n worker(s)?" "no"; then
                    N8N_WORKER_COUNT="$N8N_WORKER_COUNT_VALIDATED"
                    break
                fi
            else
                log_error "Number of workers must be a positive integer." >&2
            fi
        else
            log_error "Invalid input '$N8N_WORKER_COUNT_CANDIDATE'. Please enter a positive integer (e.g., 1, 2)." >&2
        fi
    done
fi
# Ensure N8N_WORKER_COUNT is definitely set (should be by logic above)
N8N_WORKER_COUNT="${N8N_WORKER_COUNT:-1}"

# Persist N8N_WORKER_COUNT to .env
write_env_var "N8N_WORKER_COUNT" "$N8N_WORKER_COUNT"


# ----------------------------------------------------------------
# Cloudflare Tunnel Token (if cloudflare-tunnel profile is active)
# ----------------------------------------------------------------
# If Cloudflare Tunnel is selected (based on COMPOSE_PROFILES), prompt for the token and write to .env
COMPOSE_PROFILES_VALUE="$(read_env_var COMPOSE_PROFILES)"
cloudflare_selected=0
if [[ "$COMPOSE_PROFILES_VALUE" == *"cloudflare-tunnel"* ]]; then
    cloudflare_selected=1
fi

if [ $cloudflare_selected -eq 1 ]; then
    existing_cf_token=""
    if grep -q "^CLOUDFLARE_TUNNEL_TOKEN=" "$ENV_FILE"; then
        existing_cf_token=$(grep "^CLOUDFLARE_TUNNEL_TOKEN=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/^\"//' | sed 's/\"$//')
    fi

    if [ -n "$existing_cf_token" ]; then
        log_info "Cloudflare Tunnel token found in .env; reusing it."
        # Do not prompt; keep existing token as-is
    else
        require_whiptail
        input_cf_token=$(wt_input "Cloudflare Tunnel Token" "Enter your Cloudflare Tunnel token (leave empty to skip)." "") || true
        token_to_write="$input_cf_token"

        # Update the .env with the token (may be empty if user skipped)
        if grep -q "^CLOUDFLARE_TUNNEL_TOKEN=" "$ENV_FILE"; then
            sed -i.bak "/^CLOUDFLARE_TUNNEL_TOKEN=/d" "$ENV_FILE"
        fi
        echo "CLOUDFLARE_TUNNEL_TOKEN=\"$token_to_write\"" >> "$ENV_FILE"

        if [ -n "$token_to_write" ]; then
            log_success "Cloudflare Tunnel token saved to .env."
            echo ""
            echo "🔒 After confirming the tunnel works, consider closing ports 80, 443, and 7687 in your firewall."
        else
            log_warning "Cloudflare Tunnel token was left empty. You can set it later in .env."
        fi
    fi
fi


# ----------------------------------------------------------------
# VPN Configuration (if vpn profile is active)
# ----------------------------------------------------------------
vpn_selected=0
if [[ "$COMPOSE_PROFILES_VALUE" == *"vpn"* ]]; then
    vpn_selected=1
fi

if [ $vpn_selected -eq 1 ]; then
    log_info "VPN profile selected. Configuring WireGuard + Telegram bot..."

    # Check for existing BOT_TOKEN
    EXISTING_BOT_TOKEN="$(read_env_var BOT_TOKEN)"

    if [ -n "$EXISTING_BOT_TOKEN" ]; then
        log_info "Telegram Bot token found in .env; reusing it."
    else
        # Prompt for BOT_TOKEN
        require_whiptail
        BOT_TOKEN_INPUT=$(wt_input "Telegram Bot Token" "Enter your Telegram Bot token from @BotFather (required):" "") || true

        # Validate BOT_TOKEN format (basic regex: digits:alphanumeric_-{35})
        if [[ -n "$BOT_TOKEN_INPUT" && "$BOT_TOKEN_INPUT" =~ ^[0-9]+:[A-Za-z0-9_-]{35}$ ]]; then
            write_env_var "BOT_TOKEN" "$BOT_TOKEN_INPUT"
            log_success "Telegram Bot token saved to .env."
        elif [ -n "$BOT_TOKEN_INPUT" ]; then
            log_warning "Invalid bot token format. Expected format: 1234567890:ABCdefGHIjklMNOpqrsTUVwxyz"
            log_warning "You can set BOT_TOKEN manually in .env later."
        else
            log_warning "Telegram Bot token was left empty. You must set BOT_TOKEN in .env before starting VPN services."
        fi
    fi

    # Check for existing WG_HOST
    EXISTING_WG_HOST="$(read_env_var WG_HOST)"

    if [ -n "$EXISTING_WG_HOST" ]; then
        log_info "WireGuard host found in .env; reusing it: $EXISTING_WG_HOST"
    else
        # Auto-detect external IP
        DETECTED_IP=$(curl -s ifconfig.me || curl -s api.ipify.org || curl -s icanhazip.com || echo "")

        if [ -n "$DETECTED_IP" ]; then
            log_info "Detected external IP: $DETECTED_IP"
            require_whiptail
            WG_HOST_INPUT=$(wt_input "WireGuard Host" "Enter WireGuard host (IP or domain). Detected IP: $DETECTED_IP" "$DETECTED_IP") || true
        else
            log_warning "Failed to auto-detect external IP."
            require_whiptail
            WG_HOST_INPUT=$(wt_input "WireGuard Host" "Enter your server's external IP address or domain name:" "") || true
        fi

        if [ -n "$WG_HOST_INPUT" ]; then
            write_env_var "WG_HOST" "$WG_HOST_INPUT"
            log_success "WireGuard host saved to .env: $WG_HOST_INPUT"
        else
            log_warning "WireGuard host was left empty. You must set WG_HOST in .env before starting VPN services."
        fi
    fi

    # Optional: BOT_WHITELIST (comma-separated Telegram user IDs)
    EXISTING_BOT_WHITELIST="$(read_env_var BOT_WHITELIST)"

    if [ -z "$EXISTING_BOT_WHITELIST" ]; then
        require_whiptail
        if wt_yesno "Restrict Bot Access" "Do you want to restrict bot access to specific Telegram users? (Recommended for security)" "yes"; then

            # Show instructions for getting user ID
            whiptail --title "How to Get Your Telegram User ID" --msgbox \
"To find your Telegram user ID, use ONE of these methods:

METHOD 1 (Easiest): @userinfobot
1. Open Telegram
2. Search for @userinfobot
3. Start chat and send any message
4. Bot will reply with your user ID

METHOD 2: Via bot logs (after first message)
1. Send /start to your VPN bot
2. Run: docker logs vpn-telegram-bot | grep 'User ID'
3. Copy the displayed user ID

Your user ID is a number like: 123456789

Press OK to continue..." 20 70

            BOT_WHITELIST_INPUT=$(wt_input "Authorized Users" "Enter comma-separated Telegram user IDs (e.g., 123456789,987654321):\n\nTip: Use @userinfobot to get your user ID" "") || true

            if [ -n "$BOT_WHITELIST_INPUT" ]; then
                write_env_var "BOT_WHITELIST" "$BOT_WHITELIST_INPUT"
                log_success "Bot whitelist saved to .env."
                log_info "Only users with IDs: $BOT_WHITELIST_INPUT can access the bot"
            else
                log_info "Bot whitelist left empty - bot will accept requests from all users."
                log_warning "WARNING: Without whitelist, anyone can request VPN configs!"
            fi
        else
            log_info "Bot access restriction skipped - bot will accept requests from all users."
            log_warning "WARNING: Public access mode - consider adding whitelist for security"
        fi
    else
        log_info "Bot whitelist found in .env; reusing it: $EXISTING_BOT_WHITELIST"
    fi

    # Optional: BOT_ADMINS (comma-separated Telegram user IDs for admin commands)
    EXISTING_BOT_ADMINS="$(read_env_var BOT_ADMINS)"

    if [ -z "$EXISTING_BOT_ADMINS" ]; then
        require_whiptail
        BOT_ADMINS_INPUT=$(wt_input "Admin Users" "Enter comma-separated Telegram user IDs for admin commands (optional, /revoke access):" "") || true

        if [ -n "$BOT_ADMINS_INPUT" ]; then
            write_env_var "BOT_ADMINS" "$BOT_ADMINS_INPUT"
            log_success "Bot admins saved to .env."
        else
            log_info "Bot admins left empty - no admin access configured."
        fi
    else
        log_info "Bot admins found in .env; reusing it."
    fi

    # Optional: WG_EASY_HOSTNAME (for Caddy reverse proxy with HTTPS)
    EXISTING_WG_EASY_HOSTNAME="$(read_env_var WG_EASY_HOSTNAME)"

    # Get USER_DOMAIN_NAME to suggest subdomain
    USER_DOMAIN="$(read_env_var USER_DOMAIN_NAME)"
    DEFAULT_WG_HOSTNAME=""
    if [ -n "$USER_DOMAIN" ]; then
        DEFAULT_WG_HOSTNAME="vpn.${USER_DOMAIN}"
    fi

    if [ -z "$EXISTING_WG_EASY_HOSTNAME" ]; then
        require_whiptail
        if wt_yesno "Enable HTTPS Access" "Do you want to enable HTTPS access to wg-easy via Caddy reverse proxy? (Requires domain name)

Without Caddy: http://${WG_HOST:-your-ip}:51821 (direct HTTP)
With Caddy: https://vpn.yourdomain.com (automatic HTTPS)" "no"; then

            # Loop until valid subdomain is entered
            while true; do
                WG_EASY_HOSTNAME_INPUT=$(wt_input "WG-Easy Domain" "Enter domain for wg-easy:

Suggested: ${DEFAULT_WG_HOSTNAME:-vpn.yourdomain.com}
Leave empty to skip Caddy integration and use direct HTTP access only." "$DEFAULT_WG_HOSTNAME") || true

                # If empty, skip Caddy integration
                if [ -z "$WG_EASY_HOSTNAME_INPUT" ]; then
                    log_info "Caddy integration skipped - wg-easy will be accessible via direct HTTP only."
                    break
                fi

                # Validate that WG_EASY_HOSTNAME is NOT the same as USER_DOMAIN_NAME
                if [ -n "$USER_DOMAIN" ] && [ "$WG_EASY_HOSTNAME_INPUT" = "$USER_DOMAIN" ]; then
                    log_error "WG_EASY_HOSTNAME cannot be the same as USER_DOMAIN_NAME ($USER_DOMAIN)" >&2
                    log_error "Please use a subdomain like: vpn.$USER_DOMAIN or wg.$USER_DOMAIN" >&2
                    echo >&2
                    # Loop continues - prompt again
                    continue
                fi

                # Valid subdomain entered
                write_env_var "WG_EASY_HOSTNAME" "$WG_EASY_HOSTNAME_INPUT"
                log_success "WG-Easy domain saved: $WG_EASY_HOSTNAME_INPUT (Caddy will handle HTTPS)"
                log_info "WG_EASY_USERNAME and WG_EASY_PASSWORD will be auto-generated in next step."
                break
            done
        else
            log_info "Caddy integration skipped - wg-easy will be accessible via direct HTTP only."
        fi
    else
        log_info "WG-Easy domain found in .env; reusing it: $EXISTING_WG_EASY_HOSTNAME"
    fi

    echo ""
    log_info "VPN configuration complete. Credentials will be auto-generated in next step."
fi


# ----------------------------------------------------------------
# Safety: If Supabase is present, remove Dify from COMPOSE_PROFILES (no prompts)
# ----------------------------------------------------------------
if [[ -n "$COMPOSE_PROFILES_VALUE" && "$COMPOSE_PROFILES_VALUE" == *"supabase"* ]]; then
  IFS=',' read -r -a profiles_array <<< "$COMPOSE_PROFILES_VALUE"
  new_profiles=()
  for p in "${profiles_array[@]}"; do
    if [[ "$p" != "dify" ]]; then
      new_profiles+=("$p")
    fi
  done
  COMPOSE_PROFILES_VALUE_UPDATED=$(IFS=','; echo "${new_profiles[*]}")
  if [[ "$COMPOSE_PROFILES_VALUE_UPDATED" != "$COMPOSE_PROFILES_VALUE" ]]; then
    write_env_var "COMPOSE_PROFILES" "$COMPOSE_PROFILES_VALUE_UPDATED"
    log_info "Supabase present: removed 'dify' from COMPOSE_PROFILES due to conflict with Supabase."
    COMPOSE_PROFILES_VALUE="$COMPOSE_PROFILES_VALUE_UPDATED"
  fi
fi

# ----------------------------------------------------------------
# Ensure Supabase Analytics targets the correct Postgres service name used by Supabase docker compose
# ----------------------------------------------------------------
write_env_var "POSTGRES_HOST" "db"
# ----------------------------------------------------------------

log_success "Service configuration complete. .env updated at $ENV_FILE"

exit 0