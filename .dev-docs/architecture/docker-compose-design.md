# Docker Compose Architecture - VPN Integration

## Overview

This document defines the Docker Compose service structure for VPN integration. Design follows **network isolation**, **resource limits**, and **minimalism** principles.

**Critical Constraint**: MUST NOT break existing n8n services. VPN services completely isolated on separate Docker network.

---

## Service Architecture

### New Services (2 containers)

1. **wg-easy**: WireGuard management UI + API
2. **vpnTelegram**: Telegram bot for client management

### Network Topology

```
┌─────────────────────────────────────────────────────────┐
│ Docker Host (Server: 8GB RAM, 8 CPU cores)             │
│                                                           │
│  ┌────────────────────────┐  ┌─────────────────────────┐│
│  │ n8n_network            │  │ vpn_network             ││
│  │ (172.20.0.0/16)        │  │ (172.21.0.0/16)         ││
│  │                        │  │                         ││
│  │  ┌────────┐            │  │  ┌────────┐            ││
│  │  │  n8n   │            │  │  │wg-easy │            ││
│  │  └────────┘            │  │  └────────┘            ││
│  │                        │  │      ↕                  ││
│  │  ┌──────────┐          │  │  ┌──────────┐          ││
│  │  │PostgreSQL│          │  │  │vpnTelegram│         ││
│  │  └──────────┘          │  │  └──────────┘          ││
│  │                        │  │                         ││
│  │  ┌─────┐               │  │                         ││
│  │  │Redis│               │  │                         ││
│  │  └─────┘               │  │                         ││
│  └────────────────────────┘  └─────────────────────────┘│
│            ↕                                              │
│       ┌─────────┐                ↕                       │
│       │  Caddy  │           ┌─────────┐                 │
│       │(Reverse │           │Internet │                 │
│       │ Proxy)  │           │         │                 │
│       └─────────┘           └─────────┘                 │
│            ↕                     ↕                       │
│        Port 80/443          Port 51820/51821            │
└─────────────────────────────────────────────────────────┘
```

**Key Points**:
- ✅ **Complete isolation**: No bridge between n8n_network and vpn_network
- ✅ **Minimal exposure**: Only 51820/udp (WireGuard) and 51821/tcp (wg-easy UI) exposed
- ✅ **Independent**: VPN failure does not affect n8n

---

## Docker Compose YAML

**File**: `/home/volk/vibeprojects/n8n-installer/docker-compose.yml`

**Modification Strategy**: APPEND to existing file (do not replace)

### New Networks Definition

```yaml
networks:
  # Existing network (DO NOT MODIFY)
  n8n_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

  # NEW: VPN network (isolated)
  vpn_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.21.0.0/16
```

### New Volumes Definition

```yaml
volumes:
  # Existing volumes (DO NOT MODIFY)
  # ... n8n_storage, postgres_data, etc.

  # NEW: VPN data volume
  wg_data:
    driver: local
```

### New Services Definition

```yaml
services:
  # ... existing services (n8n, postgres, redis, etc.) ...

  # NEW: wg-easy service
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:latest
    container_name: wg-easy
    profiles: ["vpn"]  # Only start when 'vpn' profile active
    restart: unless-stopped

    # WireGuard requires elevated capabilities
    cap_add:
      - NET_ADMIN
      - SYS_MODULE

    # WireGuard kernel parameters
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1

    # Persistent storage + kernel modules
    volumes:
      - wg_data:/etc/wireguard
      - /lib/modules:/lib/modules:ro

    # Port exposure
    ports:
      - "51820:51820/udp"  # WireGuard protocol
      - "51821:51821/tcp"  # wg-easy UI

    # Environment variables (from .env)
    environment:
      - WG_HOST=${WG_HOST}
      - WG_PASSWORD=${WG_PASSWORD}
      - WG_DEFAULT_DNS=1.1.1.1,8.8.8.8
      - WG_ALLOWED_IPS=0.0.0.0/0,::/0
      - WG_PORT=51820

    # Network isolation
    networks:
      - vpn_network

    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:51821"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

    # Resource limits
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.0'
        reservations:
          memory: 256M
          cpus: '0.5'

    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # NEW: vpnTelegram bot service
  vpnTelegram:
    build:
      context: ./vpn-bot
      dockerfile: Dockerfile
    container_name: vpnTelegram
    profiles: ["vpn"]  # Only start when 'vpn' profile active
    restart: unless-stopped

    # Environment variables (from .env)
    environment:
      - BOT_TOKEN=${BOT_TOKEN}
      - WG_EASY_HOST=wg-easy
      - WG_EASY_PORT=51821
      - WG_PASSWORD=${WG_PASSWORD}
      - BOT_WHITELIST=${BOT_WHITELIST:-}  # Optional whitelist

    # Network isolation
    networks:
      - vpn_network

    # Wait for wg-easy to be healthy
    depends_on:
      wg-easy:
        condition: service_healthy

    # Health check (process alive)
    healthcheck:
      test: ["CMD", "pgrep", "-f", "python"]
      interval: 60s
      timeout: 5s
      retries: 3
      start_period: 10s

    # Resource limits
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.5'
        reservations:
          memory: 128M
          cpus: '0.25'

    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

---

## Profile-Based Activation

**Why Profiles?**: VPN services only start when explicitly requested via `--profile vpn` flag.

**Activation**:
```bash
# Start VPN services
docker-compose --profile vpn up -d

# Start only n8n services (existing behavior)
docker-compose up -d

# Stop VPN services
docker-compose --profile vpn stop
```

**Installation Script** (install.sh):
```bash
# After VPN installation
docker-compose --profile vpn up -d wg-easy vpnTelegram
```

---

## Resource Allocation

### Per-Service Limits

| Service | RAM Limit | RAM Reservation | CPU Limit | CPU Reservation |
|---------|-----------|----------------|-----------|-----------------|
| **wg-easy** | 512 MB | 256 MB | 1.0 cores | 0.5 cores |
| **vpnTelegram** | 256 MB | 128 MB | 0.5 cores | 0.25 cores |
| **Total VPN** | 768 MB | 384 MB | 1.5 cores | 0.75 cores |

### Remaining Resources (for n8n + system)

**Server**: 8 GB RAM, 8 CPU cores

**Allocation**:
- **VPN services**: 768 MB RAM, 1.5 CPU cores
- **n8n + Postgres + Redis**: ~5 GB RAM, ~5 CPU cores (estimated)
- **OS + overhead**: ~2 GB RAM, ~1.5 CPU cores

**Safety Margin**: ~200 MB RAM, 0 CPU cores (tight but acceptable)

### Resource Monitoring

**Check current usage**:
```bash
docker stats wg-easy vpnTelegram
```

**Expected output**:
```
CONTAINER       CPU %  MEM USAGE / LIMIT   MEM %
wg-easy         15%    256MB / 512MB       50%
vpnTelegram     5%     128MB / 256MB       50%
```

**Alert Thresholds**:
- RAM usage > 80% of limit → Warning
- RAM usage > 95% of limit → Critical
- CPU usage > 80% sustained → Warning

---

## Network Isolation Design

### Subnet Allocation

| Network | Subnet | Gateway | Purpose |
|---------|--------|---------|---------|
| **n8n_network** | 172.20.0.0/16 | 172.20.0.1 | n8n services |
| **vpn_network** | 172.21.0.0/16 | 172.21.0.1 | VPN services |

**No Overlap**: Subnets do not conflict (172.20.x.x vs 172.21.x.x)

### Inter-Service Communication

**Within vpn_network**:
- ✅ vpnTelegram → wg-easy (HTTP API): Allowed
- ✅ wg-easy → Internet (Telegram API): Allowed

**Between networks**:
- ❌ vpnTelegram → n8n: Blocked (no route)
- ❌ n8n → wg-easy: Blocked (no route)

**External Access**:
- ✅ Internet → wg-easy:51820 (WireGuard protocol): Allowed
- ✅ LAN → wg-easy:51821 (wg-easy UI): Allowed (via firewall)
- ⚠️ Internet → wg-easy:51821 (wg-easy UI): Should be restricted via firewall

### Firewall Rules (Optional, Recommended)

**iptables** (host firewall):
```bash
# Allow WireGuard protocol (public)
iptables -A INPUT -p udp --dport 51820 -j ACCEPT

# Allow wg-easy UI from LAN only (restrict to local subnet)
iptables -A INPUT -p tcp --dport 51821 -s 192.168.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp --dport 51821 -j DROP

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
```

**ufw** (Ubuntu Firewall):
```bash
# Allow WireGuard
ufw allow 51820/udp

# Allow wg-easy UI from LAN only
ufw allow from 192.168.0.0/16 to any port 51821 proto tcp
ufw deny 51821/tcp
```

---

## Health Checks

### wg-easy Health Check

**Method**: HTTP GET to internal UI

**Command**: `curl -f http://localhost:51821`

**Success**: HTTP 200 (UI responsive)

**Failure**: Timeout or HTTP 5xx

**Action on Failure**:
- 1st failure: Log warning
- 3rd consecutive failure: Restart container
- 5+ restarts in 5 minutes: Mark unhealthy, send alert

### vpnTelegram Health Check

**Method**: Process check

**Command**: `pgrep -f python`

**Success**: Process found (exit code 0)

**Failure**: Process not found (exit code 1)

**Action on Failure**:
- 1st failure: Log warning
- 3rd consecutive failure: Restart container

### Restart Policy

**Policy**: `restart: unless-stopped`

**Behavior**:
- Container crash → Auto-restart immediately
- Docker daemon restart → Auto-restart containers
- Manual stop → Do not auto-restart

**Backoff**: Exponential backoff (10s, 20s, 40s, 60s max)

---

## Volume Persistence

### wg_data Volume

**Mount**: `/etc/wireguard` (inside wg-easy container)

**Contents**:
- `wg0.conf` - WireGuard interface config
- `wg0.json` - wg-easy metadata (clients)
- `privatekey`, `publickey` - Server keys

**Persistence**: Named volume (survives container recreation)

**Backup Strategy**:
```bash
# Backup volume
docker run --rm -v wg_data:/data -v $(pwd):/backup alpine tar czf /backup/wg_data.tar.gz /data

# Restore volume
docker run --rm -v wg_data:/data -v $(pwd):/backup alpine tar xzf /backup/wg_data.tar.gz -C /
```

**Security**: Volume permissions managed by Docker (root:root)

---

## Logging Configuration

### Log Driver

**Driver**: `json-file` (Docker default)

**Retention**:
- **Max size**: 10 MB per log file
- **Max files**: 3 rotated files
- **Total**: 30 MB per container max

**Location**: `/var/lib/docker/containers/{container_id}/{container_id}-json.log`

### Log Viewing

**Real-time**:
```bash
docker-compose logs -f wg-easy vpnTelegram
```

**Filtered**:
```bash
# Errors only
docker-compose logs --tail=100 wg-easy | grep ERROR

# Specific time range
docker-compose logs --since "2025-11-01T12:00:00" vpnTelegram
```

### Log Aggregation (Future)

**STRETCH**: Integrate with Loki or ELK stack

**docker-compose.yml extension**:
```yaml
services:
  loki:
    image: grafana/loki:latest
    ...

  wg-easy:
    logging:
      driver: loki
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-labels: "service=wg-easy"
```

---

## Environment Variables

**File**: `.env` (project root)

**New Variables**:
```bash
# VPN Configuration
WG_HOST=192.168.1.100  # Auto-detected or manual
WG_PASSWORD=auto-generated-32-char-password  # Auto-generated
WG_DEFAULT_DNS=1.1.1.1,8.8.8.8  # Default

# Telegram Bot
BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz  # From @BotFather

# Optional: User whitelist (comma-separated Telegram user IDs)
BOT_WHITELIST=123456789,987654321  # Optional
```

**Security**:
- File permissions: 600 (owner read/write only)
- Never commit to git (.env in .gitignore)
- Rotate BOT_TOKEN periodically via @BotFather

---

## Port Exposure

| Port | Protocol | Service | Exposed To | Purpose |
|------|----------|---------|------------|---------|
| **51820** | UDP | wg-easy | Internet | WireGuard VPN protocol |
| **51821** | TCP | wg-easy | LAN (recommended) | wg-easy Web UI |

**Security Notes**:
- 51820/udp MUST be open for VPN to work
- 51821/tcp SHOULD be restricted to LAN only (use firewall)
- DO NOT expose vpnTelegram ports (bot connects outbound to Telegram API)

---

## Startup Order

**Dependency Chain**:
```
Docker Engine
    ↓
wg-easy (health check passes)
    ↓
vpnTelegram (depends_on wg-easy healthy)
```

**Timeline** (first install):
1. `docker-compose --profile vpn up -d` (0s)
2. Pull wg-easy image (~30-60s)
3. Pull/build vpnTelegram image (~30-60s)
4. Start wg-easy (10s)
5. wg-easy health check passes (10-30s)
6. Start vpnTelegram (5s)
7. vpnTelegram connects to Telegram API (5s)
8. **Total**: ~90-180 seconds (1.5-3 minutes)

**Optimization** (for fast installs):
- Pre-pull images: `docker-compose --profile vpn pull`
- Use local image registry (future)

---

## Update Strategy

### Service Updates

**Method**: Pull new images + restart

```bash
# Pull latest images
docker-compose --profile vpn pull

# Restart with new images (minimal downtime)
docker-compose --profile vpn up -d
```

**Downtime**: ~5-10 seconds per service (graceful restart)

**Rollback** (if update fails):
```bash
# List previous images
docker images | grep wg-easy

# Tag old image
docker tag wg-easy:old wg-easy:latest

# Restart with old image
docker-compose --profile vpn up -d
```

---

## Uninstallation

**Script**: `uninstall-vpn.sh` (future)

**Steps**:
1. Stop VPN containers: `docker-compose --profile vpn stop`
2. Remove containers: `docker-compose --profile vpn rm -f`
3. Remove volume (optional): `docker volume rm wg_data`
4. Remove from docker-compose.yml: `sed -i '/# VPN START/,/# VPN END/d' docker-compose.yml`
5. Remove from .env: `sed -i '/# VPN CONFIG/,/# VPN END/d' .env`

**Verify**:
```bash
# Check containers removed
docker ps -a | grep -E "wg-easy|vpnTelegram"  # Should be empty

# Check volume removed (if deleted)
docker volume ls | grep wg_data  # Should be empty
```

---

## Troubleshooting

### Container Won't Start

**Symptom**: `docker-compose up` fails

**Diagnosis**:
```bash
# Check logs
docker-compose logs wg-easy

# Common issues:
# - Port 51820 already in use → Change port in .env
# - /lib/modules not found → Install kernel headers
# - NET_ADMIN capability denied → Run with --privileged (not recommended)
```

### Health Check Failing

**Symptom**: Container restart loop

**Diagnosis**:
```bash
# Check health status
docker inspect wg-easy | grep -A5 Health

# Manual health check
docker exec wg-easy curl -f http://localhost:51821

# Common issues:
# - UI not responding → Check wg-easy logs for errors
# - Timeout → Increase health check timeout in docker-compose.yml
```

### Network Connectivity Issues

**Symptom**: Bot can't reach wg-easy

**Diagnosis**:
```bash
# Check network membership
docker network inspect vpn_network

# Both wg-easy and vpnTelegram should be listed

# Test connectivity from bot container
docker exec vpnTelegram curl -f http://wg-easy:51821

# Common issues:
# - DNS resolution failure → Check Docker DNS settings
# - Firewall blocking → Check iptables rules
```

---

## References

- **Docker Compose Docs**: https://docs.docker.com/compose/
- **Docker Networking**: https://docs.docker.com/network/
- **Docker Resource Constraints**: https://docs.docker.com/config/containers/resource_constraints/
- **wg-easy Docker Image**: https://github.com/wg-easy/wg-easy
- **WireGuard Documentation**: https://www.wireguard.com/
