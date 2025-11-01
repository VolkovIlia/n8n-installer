# Troubleshooting Guide - VPN Integration

## Overview

This guide provides solutions to common issues encountered with the VPN integration. Each issue includes symptoms, diagnosis steps, and resolution procedures.

---

## Quick Diagnostic Commands

```bash
# Check all services status
docker-compose ps

# Check wg-easy health
curl -f http://localhost:51821/ && echo "Healthy" || echo "Unhealthy"

# Check bot logs
docker logs --tail 50 vpn-telegram-bot

# Check wg-easy logs
docker logs --tail 50 wg-easy

# Check WireGuard kernel module
lsmod | grep wireguard

# Check network connectivity
docker exec vpn-telegram-bot ping -c 3 wg-easy

# View environment variables
docker exec wg-easy env | grep WG_
docker exec vpn-telegram-bot env | grep BOT_
```

---

## Service Issues

### Issue: wg-easy Container Unhealthy (Dependency Failed to Start)

**Symptoms**:
- `docker compose up` shows "dependency failed to start: container wg-easy is unhealthy"
- Other services (vpn-telegram-bot, n8n) fail to start with dependency errors
- `docker ps` shows wg-easy status as "unhealthy"

**Quick Diagnostic**:
```bash
# Run automated troubleshooting script
bash scripts/troubleshoot_vpn.sh

# This script will check:
# - VPN profile status
# - Required environment variables (BOT_TOKEN, WG_HOST, WG_PASSWORD)
# - WireGuard kernel support
# - Container status and health
# - Network configuration
```

**Common Causes & Solutions**:

**1. Missing Required Environment Variables**:

This is the **most common cause**. The installer should have prompted for these values, but they might be missing if setup was interrupted.

```bash
# Check if variables are set
grep -E "^(BOT_TOKEN|WG_HOST|WG_PASSWORD)=" .env

# If missing, run configuration script
bash scripts/05_configure_services.sh

# Or manually add to .env:
BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"  # From @BotFather
WG_HOST="your-server-ip-or-domain.com"           # Server's external IP
WG_PASSWORD="auto-generated-password"            # Should be auto-generated

# Restart services
docker compose --profile vpn restart wg-easy
```

**2. WireGuard Kernel Module Not Available**:

```bash
# Check if module is loaded
lsmod | grep wireguard

# If not available, install WireGuard tools
# Fedora/RHEL:
sudo dnf install wireguard-tools

# Debian/Ubuntu:
sudo apt install wireguard-tools

# Load module
sudo modprobe wireguard

# Verify
lsmod | grep wireguard

# Restart container
docker compose --profile vpn restart wg-easy
```

**3. Health Check Timeout**:

wg-easy's health check (`curl -f http://localhost:51821`) might be timing out if the container is slow to start.

```bash
# Check container logs for startup errors
docker logs wg-easy --tail 50

# Check if web UI is accessible manually
docker exec wg-easy curl -f http://localhost:51821

# If returns "Connection refused", container failed to start
# Check logs for specific error message
docker logs wg-easy
```

**4. Permission Issues (CAP_NET_ADMIN)**:

```bash
# Verify container has required capabilities
docker inspect wg-easy | jq '.[0].HostConfig.CapAdd'

# Should contain: ["NET_ADMIN", "SYS_MODULE"]

# If missing, verify docker-compose.yml (should be correct by default):
# services:
#   wg-easy:
#     cap_add:
#       - NET_ADMIN
#       - SYS_MODULE

# Recreate container
docker compose --profile vpn down
docker compose --profile vpn up -d
```

**Prevention**:

The installer now includes **pre-flight checks** in `scripts/06_run_services.sh`:
- Validates BOT_TOKEN, WG_HOST, WG_PASSWORD are set before starting
- Checks WireGuard kernel module availability
- Provides clear error messages with remediation steps

If you encounter this error during installation:
1. Run `bash scripts/troubleshoot_vpn.sh` for automated diagnosis
2. Follow the recommendations in the output
3. Restart services with `bash scripts/06_run_services.sh`

---

### Issue: wg-easy Container Not Starting

**Symptoms**:
- `docker-compose ps` shows wg-easy as "Restarting"
- `docker logs wg-easy` shows "modprobe: can't load module wireguard"
- `curl http://localhost:51821` returns connection refused

**Diagnosis**:
```bash
# Check container status
docker inspect wg-easy | jq '.[0].State'

# Check WireGuard kernel module
lsmod | grep wireguard

# Check container logs
docker logs wg-easy
```

**Common Causes & Solutions**:

**1. WireGuard kernel module missing**:

```bash
# Check module availability
lsmod | grep wireguard

# Solution A: Load kernel module (if available)
sudo modprobe wireguard

# Solution B: Install wireguard-dkms (if module missing)
# Ubuntu/Debian:
sudo apt-get update
sudo apt-get install wireguard-dkms

# RHEL/Fedora:
sudo dnf install wireguard-tools

# After installation, restart container
docker-compose restart wg-easy
```

**2. Kernel too old (< 5.6)**:

```bash
# Check kernel version
uname -r

# If < 5.6, switch to wireguard-go
# Update docker-compose.yml:
services:
  wg-easy:
    environment:
      - WG_FORCE_USERSPACE=1  # Forces wireguard-go instead of kernel module

# Restart
docker-compose restart wg-easy
```

**3. Insufficient permissions (NET_ADMIN)**:

```bash
# Check capabilities
docker inspect wg-easy | jq '.[0].HostConfig.CapAdd'

# Should contain: ["NET_ADMIN"]

# If missing, verify docker-compose.yml:
services:
  wg-easy:
    cap_add:
      - NET_ADMIN

# Re-create container
docker-compose down && docker-compose up -d
```

---

### Issue: wg-easy UI Not Accessible

**Symptoms**:
- `curl http://localhost:51821` returns connection refused
- Browser shows "This site can't be reached"
- Container is running but health check fails

**Diagnosis**:
```bash
# Check port binding
sudo netstat -tulpn | grep 51821

# Check container port mapping
docker port wg-easy

# Check firewall rules
sudo iptables -L -n | grep 51821  # Linux
sudo firewall-cmd --list-ports      # Fedora/RHEL
```

**Solutions**:

**1. Port already in use**:

```bash
# Find process using port
sudo lsof -i :51821

# Kill process (if safe)
sudo kill -9 <PID>

# Or change WG_UI_PORT in .env
WG_UI_PORT=51822  # Use different port

# Update docker-compose.yml
services:
  wg-easy:
    ports:
      - "${WG_UI_PORT:-51821}:51821/tcp"

# Restart
docker-compose restart wg-easy
```

**2. Firewall blocking port**:

```bash
# Allow port (Ubuntu/Debian with ufw)
sudo ufw allow 51821/tcp

# Allow port (RHEL/Fedora)
sudo firewall-cmd --add-port=51821/tcp --permanent
sudo firewall-cmd --reload

# Allow port (iptables)
sudo iptables -A INPUT -p tcp --dport 51821 -j ACCEPT
```

**3. Listening on wrong interface**:

```bash
# Check if wg-easy listens on 0.0.0.0 (all interfaces)
docker exec wg-easy netstat -tlnp

# Should show: tcp        0      0 0.0.0.0:51821  0.0.0.0:*  LISTEN

# If listening on 127.0.0.1 only, update docker-compose.yml:
services:
  wg-easy:
    environment:
      - WG_HOST=0.0.0.0  # Listen on all interfaces
```

---

### Issue: Bot Not Responding to Commands

**Symptoms**:
- User sends `/start` to bot, no response
- Bot shows "Online" in Telegram but doesn't reply
- `docker ps` shows vpn-telegram-bot as running

**Diagnosis**:
```bash
# Check bot logs for errors
docker logs --tail 100 vpn-telegram-bot

# Check bot process
docker exec vpn-telegram-bot ps aux | grep python

# Check Telegram API connectivity
docker exec vpn-telegram-bot curl https://api.telegram.org/bot${BOT_TOKEN}/getMe

# Check wg-easy connectivity from bot
docker exec vpn-telegram-bot curl http://wg-easy:51821/
```

**Solutions**:

**1. Invalid BOT_TOKEN**:

```bash
# Verify token format
echo $BOT_TOKEN  # Should be: 123456789:ABCdefGHI...

# Test token with Telegram API
curl https://api.telegram.org/bot${BOT_TOKEN}/getMe

# If invalid, get new token from @BotFather:
# 1. Message @BotFather in Telegram
# 2. Send /mybots → Select bot → API Token
# 3. Update .env file
BOT_TOKEN=your-new-token-here

# Restart bot
docker-compose restart vpnTelegram
```

**2. Network connectivity issues**:

```bash
# Test Telegram API from bot container
docker exec vpn-telegram-bot curl -v https://api.telegram.org

# If fails, check DNS
docker exec vpn-telegram-bot nslookup api.telegram.org

# If DNS fails, add DNS servers to docker-compose.yml:
services:
  vpnTelegram:
    dns:
      - 8.8.8.8
      - 1.1.1.1

# Restart
docker-compose restart vpnTelegram
```

**3. Bot not started (crashed)**:

```bash
# Check logs for crash reason
docker logs vpn-telegram-bot | grep -i error

# Common errors:
# - "ModuleNotFoundError" → Rebuild image (pip install failed)
# - "BOT_TOKEN not set" → Missing environment variable
# - "Connection refused" → wg-easy not reachable

# Rebuild and restart
docker-compose build vpnTelegram
docker-compose restart vpnTelegram
```

---

## VPN Configuration Issues

### Issue: VPN Config Generation Fails

**Symptoms**:
- User sends `/request`, bot replies "VPN service temporarily unavailable"
- Bot logs show "ERROR: wg-easy API timeout"
- wg-easy container is running

**Diagnosis**:
```bash
# Check wg-easy health
curl -f http://localhost:51821/

# Test API manually
curl -X POST http://localhost:51821/api/session \
  -H "Content-Type: application/json" \
  -d "{\"password\": \"$WG_PASSWORD\"}"

# Check bot→wg-easy connectivity
docker exec vpn-telegram-bot curl http://wg-easy:51821/
```

**Solutions**:

**1. Wrong WG_PASSWORD**:

```bash
# Verify password in .env
cat .env | grep WG_PASSWORD

# Test password
curl -X POST http://localhost:51821/api/session \
  -H "Content-Type: application/json" \
  -d "{\"password\": \"$(grep WG_PASSWORD .env | cut -d= -f2)\"}"

# If returns 401, reset password:
# 1. Stop wg-easy
docker-compose stop wg-easy

# 2. Remove wg_data volume (WARNING: deletes all clients)
docker volume rm wg_data

# 3. Generate new password
openssl rand -base64 32

# 4. Update .env
WG_PASSWORD=<new-password>

# 5. Restart
docker-compose up -d wg-easy
```

**2. wg-easy session expired**:

```bash
# Bot should auto-retry, but check logs
docker logs vpn-telegram-bot | grep "session"

# If stuck, restart bot to clear session
docker-compose restart vpnTelegram
```

**3. Network timeout**:

```bash
# Check if bot can reach wg-easy
docker exec vpn-telegram-bot ping -c 3 wg-easy

# If fails, check Docker network
docker network inspect vpn_network

# Recreate network
docker-compose down
docker network rm vpn_network
docker-compose up -d
```

---

### Issue: User Reports "Not Authorized"

**Symptoms**:
- User sends `/request`, bot replies "❌ Access denied"
- User's Telegram ID not in whitelist
- Bot logs show "User 123456 denied access"

**Diagnosis**:
```bash
# Check whitelist configuration
cat .env | grep BOT_WHITELIST

# Check bot logs for user ID
docker logs vpn-telegram-bot | grep "User ID"
```

**Solutions**:

**1. User not in whitelist**:

```bash
# Get user's Telegram ID from bot logs
docker logs vpn-telegram-bot | grep "User" | tail -1
# Example output: User ID: 123456789

# Add to whitelist in .env
BOT_WHITELIST=existing_ids,123456789

# Restart bot
docker-compose restart vpnTelegram
```

**2. Whitelist format error**:

```bash
# Correct format: Comma-separated, no spaces
BOT_WHITELIST=123456,789012,555666

# Incorrect formats:
BOT_WHITELIST=123456, 789012  # Has space
BOT_WHITELIST="123456 789012" # No commas

# Fix and restart
docker-compose restart vpnTelegram
```

**3. Disable whitelist (allow all)**:

```bash
# Remove or comment out BOT_WHITELIST in .env
# BOT_WHITELIST=

# Restart bot
docker-compose restart vpnTelegram

# WARNING: This allows any Telegram user to request VPN configs
```

---

## VPN Connection Issues

### Issue: Client Can't Connect to VPN

**Symptoms**:
- WireGuard app shows "Connecting..." then times out
- `/status` command shows "Never connected"
- No handshake timestamp

**Diagnosis**:
```bash
# Check WireGuard server status
docker exec wg-easy wg show

# Check firewall allows UDP 51820
sudo netstat -ulpn | grep 51820

# Check client config
docker exec wg-easy cat /etc/wireguard/wg0.conf
```

**Solutions**:

**1. Port 51820/udp blocked**:

```bash
# Allow port (Ubuntu/Debian with ufw)
sudo ufw allow 51820/udp

# Allow port (RHEL/Fedora)
sudo firewall-cmd --add-port=51820/udp --permanent
sudo firewall-cmd --reload

# Allow port (iptables)
sudo iptables -A INPUT -p udp --dport 51820 -j ACCEPT
```

**2. Wrong WG_HOST (external IP)**:

```bash
# Check configured WG_HOST
cat .env | grep WG_HOST

# Check actual external IP
curl ifconfig.me

# If mismatch, update .env
WG_HOST=$(curl -s ifconfig.me)

# Recreate all client configs (old configs have wrong endpoint)
# Users must request new configs with /revoke + /request
```

**3. NAT/router not forwarding port**:

```bash
# If server is behind NAT, configure port forwarding:
# Router → Port Forwarding → 51820/udp → Server IP

# Test if port is reachable from outside
# From external network:
nc -vuz <your-external-ip> 51820

# If timeout, check router port forwarding settings
```

**4. ISP blocking WireGuard**:

```bash
# Some ISPs block UDP 51820
# Solution: Change WireGuard port

# Update .env
WG_PORT=12345  # Use random port

# Update docker-compose.yml
services:
  wg-easy:
    ports:
      - "${WG_PORT:-51820}:51820/udp"

# Restart and recreate configs
docker-compose restart wg-easy
# Users must request new configs
```

---

### Issue: VPN Connected But No Internet

**Symptoms**:
- WireGuard shows "Connected"
- `/status` shows recent handshake
- But cannot access websites

**Diagnosis**:
```bash
# Check AllowedIPs in client config
# Should be: AllowedIPs = 0.0.0.0/0, ::/0

# Check DNS in client config
# Should be: DNS = 1.1.1.1, 8.8.8.8

# Check server forwarding
docker exec wg-easy sysctl net.ipv4.ip_forward
```

**Solutions**:

**1. IP forwarding disabled**:

```bash
# Enable IP forwarding in wg-easy container
docker exec wg-easy sysctl -w net.ipv4.ip_forward=1

# Should be enabled by wg-easy automatically, but verify
docker exec wg-easy cat /proc/sys/net/ipv4/ip_forward
# Should output: 1
```

**2. DNS not working**:

```bash
# Update WG_DEFAULT_DNS in .env
WG_DEFAULT_DNS=1.1.1.1,8.8.8.8,208.67.222.222

# Restart wg-easy
docker-compose restart wg-easy

# User must request new config to get new DNS settings
```

**3. Server firewall blocking forwarding**:

```bash
# Check FORWARD chain
sudo iptables -L FORWARD -n

# Allow forwarding from wg0
sudo iptables -A FORWARD -i wg0 -j ACCEPT
sudo iptables -A FORWARD -o wg0 -j ACCEPT

# Enable NAT (masquerade)
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
# Replace eth0 with your external interface (ip link show)
```

---

## Resource Issues

### Issue: wg-easy Consuming Too Much Memory

**Symptoms**:
- `docker stats` shows wg-easy using >512MB RAM
- System shows high memory usage
- wg-easy becomes slow or unresponsive

**Diagnosis**:
```bash
# Check memory usage
docker stats wg-easy --no-stream

# Check client count
docker exec wg-easy wg show wg0 | grep peer | wc -l

# Check logs for memory errors
docker logs wg-easy | grep -i memory
```

**Solutions**:

**1. Too many clients**:

```bash
# List all clients
curl -X GET http://localhost:51821/api/wireguard/client \
  -H "Authorization: Bearer ${SESSION_TOKEN}" | jq length

# If >100 clients, consider:
# - Deleting inactive clients
# - Increasing memory limit

# Delete inactive clients (no handshake in 30 days)
# Manual cleanup via wg-easy UI
```

**2. Increase memory limit**:

```bash
# Update docker-compose.yml
services:
  wg-easy:
    mem_limit: 1g  # Increase from 512m to 1g

# Restart
docker-compose up -d wg-easy
```

---

### Issue: Bot Consuming CPU

**Symptoms**:
- `docker stats` shows vpnTelegram using >50% CPU
- Bot responses slow
- High CPU usage on server

**Diagnosis**:
```bash
# Check CPU usage
docker stats vpnTelegram --no-stream

# Check for infinite loops in logs
docker logs vpn-telegram-bot | grep -i loop

# Check number of concurrent requests
docker logs vpn-telegram-bot | grep "User" | tail -50
```

**Solutions**:

**1. Bot stuck in loop**:

```bash
# Restart bot
docker-compose restart vpnTelegram

# If persists, check logs for specific error
docker logs vpn-telegram-bot | tail -100
```

**2. High request rate**:

```bash
# Check if users spamming commands
docker logs vpn-telegram-bot | grep "User" | cut -d: -f3 | sort | uniq -c | sort -rn

# If abuse detected, add rate limiting or update whitelist
```

---

## Configuration Issues

### Issue: .env File Not Loaded

**Symptoms**:
- Environment variables not set in containers
- `docker exec wg-easy env | grep WG_PASSWORD` returns empty
- Bot logs show "BOT_TOKEN not set"

**Diagnosis**:
```bash
# Check .env file exists
ls -la .env

# Check .env file permissions
stat .env

# Check docker-compose.yml references .env
grep env_file docker-compose.yml
```

**Solutions**:

**1. .env file missing or wrong location**:

```bash
# .env must be in same directory as docker-compose.yml
cd /home/volk/vibeprojects/n8n-installer

# Create .env if missing
touch .env
chmod 600 .env

# Add required variables
cat >> .env <<EOF
BOT_TOKEN=your-token-here
WG_PASSWORD=your-password-here
WG_HOST=your-external-ip
EOF

# Restart services
docker-compose up -d
```

**2. Wrong permissions**:

```bash
# Set correct permissions
chmod 600 .env
chown $(whoami):$(whoami) .env

# Restart
docker-compose restart
```

---

## Network Issues

### Issue: vpn_network Conflicts with Existing Network

**Symptoms**:
- `docker-compose up` fails with "network overlap" error
- Existing network uses 172.21.0.0/16 subnet

**Diagnosis**:
```bash
# Check existing networks
docker network ls
docker network inspect <network-name>

# Check for subnet conflicts
ip route | grep 172.21
```

**Solutions**:

```bash
# Update docker-compose.yml with different subnet
services:
  # ...

networks:
  vpn_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.22.0.0/16  # Changed from 172.21.0.0/16

# Recreate network
docker-compose down
docker network rm vpn_network
docker-compose up -d
```

---

## Getting Help

### Collect Diagnostic Information

Before reporting issues, collect:

```bash
# Create diagnostic report
cat > vpn_diagnostic.txt <<EOF
=== System Info ===
$(uname -a)
$(docker --version)
$(docker-compose --version)

=== Service Status ===
$(docker-compose ps)

=== wg-easy Logs (Last 50 Lines) ===
$(docker logs --tail 50 wg-easy 2>&1)

=== Bot Logs (Last 50 Lines) ===
$(docker logs --tail 50 vpn-telegram-bot 2>&1)

=== WireGuard Status ===
$(docker exec wg-easy wg show 2>&1)

=== Network Config ===
$(docker network inspect vpn_network 2>&1)

=== Environment (Secrets Redacted) ===
$(cat .env | sed 's/\(TOKEN\|PASSWORD\)=.*/\1=<REDACTED>/')
EOF

# View report
cat vpn_diagnostic.txt
```

### Support Channels

1. **Check documentation**:
   - `.dev-docs/` - Architecture and implementation details
   - `docs/` - API reference and guides

2. **Review code**:
   - `.dev-docs/CODE_REVIEW_REPORT.md` - Known issues
   - `.dev-docs/QA_TEST_REPORT.md` - Test coverage

3. **Community resources**:
   - wg-easy: https://github.com/wg-easy/wg-easy/issues
   - WireGuard: https://lists.zx2c4.com/mailman/listinfo/wireguard

---

## Prevention

### Regular Maintenance

```bash
# Weekly checks
docker-compose ps              # Verify all services running
docker logs --tail 10 wg-easy  # Check for errors
docker stats --no-stream       # Monitor resource usage

# Monthly cleanup
# Delete inactive clients (no handshake in 30 days)
# Review whitelist (remove departed users)
# Update Docker images
docker-compose pull
docker-compose up -d

# Backup
tar czf wg_backup_$(date +%Y%m%d).tar.gz \
  .env \
  $(docker volume inspect wg_data --format '{{.Mountpoint}}')
```

### Monitoring Recommendations

- Set up Docker health check alerts
- Monitor disk usage (wg_data volume)
- Track client count growth
- Review bot command logs for abuse patterns
