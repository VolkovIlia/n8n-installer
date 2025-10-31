# Build & Run - VPN Integration

## Single Command Deployment

**Principle**: Exactly ONE command to build, ONE command to run each service.

---

## Prerequisites

### System Requirements

**Operating System**:
- Ubuntu 20.04+ / Debian 11+ (primary)
- Kernel ≥5.6 (for native WireGuard support)

**Software**:
- Docker ≥20.10
- Docker Compose ≥2.0
- Git (for initial clone)
- curl (for external IP detection)

**Hardware**:
- RAM: 8 GB minimum (768 MB reserved for VPN services)
- CPU: 4 cores minimum (1.5 cores reserved for VPN services)
- Disk: 10 GB free (500 MB for VPN services)
- Network: Public IP or port forwarding

**Check Prerequisites**:
```bash
# Kernel version
uname -r  # Should be ≥5.6

# Docker version
docker --version  # Should be ≥20.10

# Docker Compose version
docker compose version  # Should be ≥2.0 (note: 'compose' not 'docker-compose')

# Check WireGuard kernel module
sudo modprobe wireguard && echo "WireGuard available" || echo "WireGuard missing"

# Check available RAM
free -h  # Should show ≥8GB total

# Check CPU cores
nproc  # Should show ≥4 cores
```

---

## Installation (User-Facing)

### Method 1: Interactive Menu (Recommended)

**Command**: Run n8n-installer and select VPN option

```bash
# Navigate to project
cd /home/volk/vibeprojects/n8n-installer

# Run installer
bash install.sh
```

**Menu Flow**:
```
n8n-installer v1.0
==================

Select operation:
1. Install n8n
2. Update n8n
3. Install VPN + Telegram bot  ← SELECT THIS
4. Remove n8n
5. Exit

Your choice: 3

Installing VPN + Telegram bot...

Step 1: Telegram Bot Token
---------------------------
Create a Telegram bot via @BotFather and paste the token here.
Bot token format: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz

Enter BOT_TOKEN: [user inputs token]

Step 2: Server IP Detection
----------------------------
Detecting external IP...
Detected: 192.168.1.100

Is this correct? (y/n): y

Step 3: Generating Secrets
---------------------------
Generating wg-easy password (32 characters)...
Generated: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6

Step 4: Docker Compose Configuration
-------------------------------------
Appending VPN services to docker-compose.yml...
Creating .env entries...
Creating vpn-bot directory...

Step 5: Starting Services
--------------------------
Pulling images...
  wg-easy: ✓ (30s)
  vpnTelegram: ✓ (25s)

Starting containers...
  wg-easy: ✓ (healthy)
  vpnTelegram: ✓ (healthy)

Installation Complete!
======================

wg-easy UI: https://192.168.1.100:51821
wg-easy password: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
Telegram bot: @YourVPNBot (username detected)

Next steps:
1. Access wg-easy UI with the password above
2. Send /start to your Telegram bot
3. Request VPN config with /request

Installation log: /var/log/n8n-installer-vpn.log
```

**Time**: 5-10 minutes (including image pull)

---

### Method 2: Direct Docker Compose (For Developers)

**Prerequisites**: .env file already configured

**Command**:
```bash
docker-compose --profile vpn up -d
```

**What it does**:
1. Reads docker-compose.yml (with VPN services)
2. Reads .env (WG_PASSWORD, BOT_TOKEN, WG_HOST)
3. Creates vpn_network (if not exists)
4. Pulls wg-easy image (if not cached)
5. Builds vpnTelegram image (from ./vpn-bot/Dockerfile)
6. Starts wg-easy container
7. Waits for wg-easy health check (30s max)
8. Starts vpnTelegram container
9. Returns when both containers healthy

**Output**:
```
[+] Running 4/4
 ⠿ Network vpn_network           Created  0.1s
 ⠿ Volume wg_data                Created  0.0s
 ⠿ Container wg-easy             Started  5.2s
 ⠿ Container vpnTelegram         Started  8.1s
```

**Time**: 1-2 minutes (images cached) or 5-10 minutes (first run)

---

## Build Process (For Engineers)

### wg-easy (No Build Required)

**Image**: ghcr.io/wg-easy/wg-easy:latest

**Pre-built**: Official image from GitHub Container Registry

**No local build needed**: Docker pulls image automatically

**Update**:
```bash
docker pull ghcr.io/wg-easy/wg-easy:latest
docker-compose --profile vpn up -d wg-easy
```

---

### vpnTelegram Bot (Local Build Required)

**Build Context**: `./vpn-bot/`

**Dockerfile**: `./vpn-bot/Dockerfile`

**Build Command** (automatic via docker-compose):
```bash
docker-compose --profile vpn build vpnTelegram
```

**Manual Build** (for development):
```bash
cd vpn-bot
docker build -t vpn-telegram-bot:latest .
```

**Dockerfile**:
```dockerfile
# ./vpn-bot/Dockerfile
FROM python:3.11-slim

# Install dependencies
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy bot code
COPY . .

# Run bot
CMD ["python", "bot.py"]
```

**Dependencies** (requirements.txt):
```
python-telegram-bot==20.7
requests==2.31.0
qrcode==7.4.2
Pillow==10.1.0
python-dotenv==1.0.0
```

**Build Time**: 30-60 seconds

**Image Size Target**: <200 MB

---

## Run Process

### Start Services

**Command**:
```bash
docker-compose --profile vpn up -d
```

**Verify Running**:
```bash
docker ps | grep -E "wg-easy|vpnTelegram"
```

**Expected Output**:
```
CONTAINER ID   IMAGE                              STATUS                    PORTS
abc123def456   ghcr.io/wg-easy/wg-easy:latest    Up 2 minutes (healthy)    0.0.0.0:51820->51820/udp, 0.0.0.0:51821->51821/tcp
ghi789jkl012   vpn-telegram-bot:latest           Up 2 minutes (healthy)
```

---

### Stop Services

**Command**:
```bash
docker-compose --profile vpn stop
```

**Graceful Shutdown**:
- Sends SIGTERM to containers
- Waits 10 seconds for graceful shutdown
- Sends SIGKILL if not stopped

**Verify Stopped**:
```bash
docker ps -a | grep -E "wg-easy|vpnTelegram"
```

**Expected Output**:
```
CONTAINER ID   STATUS
abc123def456   Exited (0) 5 seconds ago
ghi789jkl012   Exited (0) 5 seconds ago
```

---

### Restart Services

**Command**:
```bash
docker-compose --profile vpn restart
```

**Downtime**: ~5-10 seconds per container

**Use Case**: Apply configuration changes (.env updates)

---

### View Logs

**Real-time (all services)**:
```bash
docker-compose logs -f wg-easy vpnTelegram
```

**Last 100 lines**:
```bash
docker-compose logs --tail=100 wg-easy vpnTelegram
```

**Specific service**:
```bash
docker-compose logs -f vpnTelegram
```

**Errors only**:
```bash
docker-compose logs wg-easy | grep ERROR
```

---

## Configuration Updates

### Update .env and Reload

**Scenario**: Change BOT_WHITELIST without downtime

**Steps**:
```bash
# 1. Edit .env
nano .env

# 2. Update BOT_WHITELIST value
BOT_WHITELIST=123456,789012,345678

# 3. Reload bot (graceful, no restart)
docker exec vpnTelegram kill -HUP 1

# OR restart container (5s downtime)
docker-compose --profile vpn restart vpnTelegram
```

**No Restart Needed For**:
- BOT_WHITELIST (if bot implements SIGHUP handler)

**Restart Required For**:
- BOT_TOKEN (Telegram API connection)
- WG_PASSWORD (wg-easy API auth)
- WG_HOST (WireGuard endpoint)

---

## Health Checks

### Manual Health Check

**wg-easy**:
```bash
curl -f http://localhost:51821
# Expected: HTTP 200 (HTML response)
```

**vpnTelegram** (process check):
```bash
docker exec vpnTelegram pgrep -f python
# Expected: Process ID (e.g., 1)
```

**Both services**:
```bash
docker ps --filter "health=healthy" | grep -E "wg-easy|vpnTelegram"
# Expected: Both containers listed
```

---

### Automated Health Monitoring

**Docker built-in** (every 30s):
```bash
# Check health status
docker inspect wg-easy | grep -A 10 Health

# Expected output:
"Health": {
    "Status": "healthy",
    "FailingStreak": 0,
    "Log": [...]
}
```

**If unhealthy**:
- Docker auto-restarts container (restart: unless-stopped)
- After 3 consecutive failures within 5 minutes

---

## Resource Monitoring

### Check Current Usage

```bash
docker stats wg-easy vpnTelegram --no-stream
```

**Expected Output**:
```
CONTAINER       CPU %  MEM USAGE / LIMIT   MEM %   NET I/O
wg-easy         15%    256MB / 512MB       50%     1.2GB / 850MB
vpnTelegram     5%     128MB / 256MB       50%     10MB / 5MB
```

**Alert Thresholds**:
- RAM > 80% of limit → Warning (log alert)
- RAM > 95% of limit → Critical (notify admin)
- CPU > 80% sustained (5+ minutes) → Warning

---

### Resource Alerts (Future)

**STRETCH**: Prometheus + Alertmanager

**Alert Rules**:
```yaml
groups:
  - name: vpn_alerts
    rules:
      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes{name="wg-easy"} / container_spec_memory_limit_bytes{name="wg-easy"} > 0.8
        for: 5m
        annotations:
          summary: "wg-easy memory usage >80%"

      - alert: ContainerDown
        expr: up{job="docker"} == 0
        for: 1m
        annotations:
          summary: "VPN container down"
```

---

## Update Process

### Update to Latest Version

**Command**:
```bash
# Pull latest images
docker-compose --profile vpn pull

# Restart with new images
docker-compose --profile vpn up -d
```

**Downtime**: ~10-30 seconds (rolling restart)

**Rollback** (if update fails):
```bash
# List previous images
docker images | grep wg-easy

# Example output:
# ghcr.io/wg-easy/wg-easy  latest   abc123  2 days ago   150MB
# ghcr.io/wg-easy/wg-easy  <none>   def456  1 week ago   145MB  ← Old version

# Tag old version as latest
docker tag def456 ghcr.io/wg-easy/wg-easy:latest

# Restart with old version
docker-compose --profile vpn up -d
```

---

## Environment Variables Reference

**File**: `.env` (project root)

**Format**:
```bash
# VPN Configuration
WG_HOST=192.168.1.100  # Server external IP (auto-detected or manual)
WG_PASSWORD=a1b2c3d4...  # wg-easy UI password (auto-generated 32 chars)
WG_DEFAULT_DNS=1.1.1.1,8.8.8.8  # DNS servers for VPN clients

# Telegram Bot
BOT_TOKEN=123456789:ABC...  # From @BotFather (mandatory)

# Optional: User whitelist (empty = allow all)
BOT_WHITELIST=123456,789012  # Comma-separated Telegram user IDs
```

**Validation** (install.sh checks):
- BOT_TOKEN matches regex: `^\d{8,10}:[A-Za-z0-9_-]{35}$`
- WG_HOST is valid IPv4 or domain
- WG_PASSWORD is ≥12 characters (preferably 32)

---

## Troubleshooting

### Container Won't Start

**Symptom**:
```
Error response from daemon: driver failed programming external connectivity on endpoint wg-easy: Error starting userland proxy: listen udp4 0.0.0.0:51820: bind: address already in use
```

**Solution**: Port 51820 already in use
```bash
# Find process using port
sudo lsof -i :51820

# Kill process or change port in .env
WG_PORT=51821  # Change in .env
docker-compose --profile vpn up -d
```

---

### Health Check Failing

**Symptom**: Container keeps restarting

**Diagnosis**:
```bash
# Check logs for errors
docker logs wg-easy --tail 50

# Common issues:
# - WireGuard module not loaded
# - /lib/modules not mounted
# - Kernel version <5.6
```

**Solution**:
```bash
# Load WireGuard module
sudo modprobe wireguard

# Install kernel headers (if missing)
sudo apt install linux-headers-$(uname -r)

# Restart Docker
sudo systemctl restart docker
```

---

### Bot Not Responding

**Symptom**: Telegram bot doesn't reply to /start

**Diagnosis**:
```bash
# Check bot logs
docker logs vpnTelegram --tail 100

# Look for:
# - "Invalid BOT_TOKEN" → Check .env
# - "Connection refused to wg-easy" → Check wg-easy running
# - "Telegram API timeout" → Check internet connectivity
```

**Solution**:
```bash
# Verify BOT_TOKEN
docker exec vpnTelegram env | grep BOT_TOKEN

# Test Telegram API
curl -X GET "https://api.telegram.org/bot${BOT_TOKEN}/getMe"

# Restart bot
docker-compose --profile vpn restart vpnTelegram
```

---

## Performance Tuning

### Optimize Image Pull Speed

**Use Docker registry cache**:
```bash
# Configure Docker registry mirror (optional)
sudo nano /etc/docker/daemon.json

{
  "registry-mirrors": ["https://mirror.gcr.io"]
}

sudo systemctl restart docker
```

---

### Reduce Build Time

**Cache Python dependencies**:
```dockerfile
# In Dockerfile, separate dependency install from code copy
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Code changes won't invalidate dependency cache
COPY . .
```

---

### Reduce Container Size

**Use multi-stage build** (future):
```dockerfile
# Build stage
FROM python:3.11 AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Runtime stage (smaller base image)
FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY . .
ENV PATH=/root/.local/bin:$PATH
CMD ["python", "bot.py"]
```

**Size reduction**: ~50 MB savings

---

## References

- **Docker Compose CLI**: https://docs.docker.com/compose/reference/
- **Docker Run Reference**: https://docs.docker.com/engine/reference/run/
- **wg-easy Installation**: https://github.com/wg-easy/wg-easy#installation
- **Telegram Bot API**: https://core.telegram.org/bots/api
