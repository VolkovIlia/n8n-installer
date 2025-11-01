# Technical Constraints - VPN Integration

## Non-Functional Requirements

### Performance

#### Throughput
- **VPN bandwidth**: Minimum 100 Mbps per client
  - **Measurement**: iperf3 test through VPN tunnel
  - **Target**: 95% of baseline connection speed
  - **Acceptable**: 80% of baseline (hard minimum)

#### Latency
- **Added latency**: <50ms overhead
  - **Measurement**: ping time difference (direct vs VPN)
  - **Target**: <30ms additional latency
  - **Acceptable**: 50ms (hard limit)

#### Response Times
- **Bot response**: <2 seconds for config generation
  - **Measurement**: Time from user command to bot reply
  - **Target**: <1 second for cached responses
  - **Acceptable**: 2 seconds (hard limit)

- **wg-easy UI load**: <3 seconds initial page load
  - **Measurement**: Browser DevTools Network tab
  - **Target**: <2 seconds on LAN
  - **Acceptable**: 3 seconds (hard limit)

#### Resource Limits
- **wg-easy container**:
  - RAM: 512 MB max (target: 256 MB)
  - CPU: 0.5 cores max (target: 0.2 cores)
  - Disk: 200 MB max

- **vpnTelegram container**:
  - RAM: 256 MB max (target: 128 MB)
  - CPU: 0.25 cores max (target: 0.1 cores)
  - Disk: 100 MB max

- **Combined footprint**:
  - RAM: 768 MB max (leaving 7.2 GB for n8n + system)
  - CPU: 0.75 cores max (leaving 7.25 cores for n8n + system)
  - Disk: 500 MB max (including logs, configs, volumes)

#### Scalability
- **Concurrent clients**: 1-20 VPN tunnels simultaneously
  - **Test**: 20 clients connected, measure throughput per client
  - **Target**: >50 Mbps per client at max load

- **Bot request rate**: 100 requests/hour
  - **Test**: Simulate 100 bot commands in 1 hour
  - **Target**: All requests processed within 2 seconds

---

### Reliability

#### Uptime
- **VPN service availability**: >95% uptime over 30 days
  - **Measurement**: Docker health checks every 30 seconds
  - **Target**: 99% uptime (7.2 hours downtime/month max)
  - **Acceptable**: 95% uptime (36 hours downtime/month)

#### Fault Tolerance
- **Container restart**: Automatic restart on failure
  - **Policy**: `restart: unless-stopped` in docker-compose.yml
  - **Max restarts**: 3 attempts in 5 minutes, then alert

- **Data persistence**: Zero configuration loss on restart
  - **Requirement**: Named volumes for wg-easy data
  - **Backup**: Configuration backed up every 24 hours

#### Error Recovery
- **Graceful degradation**: If bot fails, VPN continues working
  - **Isolation**: Bot failure does not affect wg-easy
  - **Manual fallback**: Administrators can access wg-easy UI directly

- **Rollback capability**: Ability to uninstall cleanly
  - **Requirement**: Uninstall script removes VPN services
  - **Preservation**: n8n services remain untouched

---

### Security

#### Encryption
- **WireGuard protocol**: ChaCha20-Poly1305 cipher
  - **Key size**: 256-bit keys
  - **Key rotation**: Manual (not automatic in MVP)

#### Authentication
- **wg-easy UI**:
  - **Method**: Password authentication
  - **Strength**: Minimum 12 characters, auto-generated
  - **Storage**: Hashed in environment variable
  - **HTTPS**: Required (no HTTP access)

- **Telegram bot**:
  - **Method**: Telegram username verification
  - **Token storage**: Environment variable (BOT_TOKEN)
  - **Whitelist**: Optional user ID whitelist

#### Access Control
- **Port exposure**:
  - **51820/udp**: WireGuard protocol (public, encrypted)
  - **51821/tcp**: wg-easy UI (password-protected)
  - **Bot**: No exposed ports (outbound to Telegram API only)

- **Network isolation**:
  - **VPN network**: Separate Docker network (vpn_network)
  - **Bridge**: Minimal communication with n8n_network
  - **Firewall**: iptables rules for VPN traffic only

#### Secrets Management
- **Environment variables**: All secrets in .env file
  - **Required**: WG_PASSWORD, BOT_TOKEN
  - **Generated**: WG_PASSWORD (32-char random on install)
  - **User-provided**: BOT_TOKEN (from @BotFather)

- **.env protection**:
  - **Permissions**: 600 (owner read/write only)
  - **Location**: Project root (not in version control)
  - **.gitignore**: .env file listed

#### Audit & Logging
- **Access logs**: All bot commands logged
  - **Format**: Timestamp, User ID, Command, Result
  - **Retention**: 30 days
  - **Location**: Docker volume (vpn_logs)

- **Security events**: Failed auth attempts logged
  - **Trigger**: 3+ failed logins to wg-easy UI
  - **Action**: Rate limiting + log entry

---

### Compatibility

#### Operating System
- **Primary**: Ubuntu 20.04, 22.04, 24.04
- **Secondary**: Debian 11, 12
- **Kernel**: >=5.6 (for native WireGuard support)
- **Not supported**: CentOS, Alpine (without testing)

#### Docker
- **Docker Engine**: >=20.10
- **Docker Compose**: >=2.0 (Compose v2 with `docker compose`)
- **Compose file format**: version 3.8

#### Existing n8n-installer
- **Version compatibility**: n8n-installer >=1.0
- **Preservation requirements**:
  - Existing docker-compose.yml structure
  - Existing networks (n8n_network)
  - Existing volumes (n8n_data, postgres_data)
  - Existing environment variables

#### Port Requirements
- **Required ports**:
  - 51820/udp: WireGuard (public)
  - 51821/tcp: wg-easy UI (LAN/VPN only)

- **Conflict detection**:
  - Check ports before installation
  - Offer alternative ports if occupied
  - Document port customization

#### Network Requirements
- **External connectivity**: Required for VPN
  - Internet access for Telegram API
  - Public IP or port forwarding for WireGuard
  - STUN/TURN for NAT detection (optional)

---

### Deployment

#### Installation
- **Method**: Interactive menu option in n8n-installer
- **Time**: <10 minutes for complete setup
- **Prerequisites**:
  - n8n-installer already installed
  - Docker and Docker Compose available
  - Telegram bot token (from @BotFather)

#### Configuration
- **Required inputs**:
  - Telegram bot token (mandatory)
  - wg-easy UI password (auto-generated or custom)
  - Server external IP (auto-detected or manual)

- **Optional inputs**:
  - Custom ports (if defaults unavailable)
  - User whitelist for bot access
  - VPN subnet (default: 10.8.0.0/24)

#### Updates
- **Strategy**: Pull new container images
- **Command**: `docker-compose pull && docker-compose up -d`
- **Downtime**: <30 seconds during update
- **Rollback**: Previous image tagged for quick revert

#### Uninstallation
- **Clean removal**: Script removes VPN services only
- **Preservation**: n8n services continue running
- **Data cleanup**: Optional (preserve configs or delete)

---

### Monitoring

#### Health Checks
- **wg-easy**:
  - **Endpoint**: HTTP GET http://localhost:51821
  - **Interval**: 30 seconds
  - **Timeout**: 5 seconds
  - **Retries**: 3

- **vpnTelegram**:
  - **Method**: Process check (bot daemon alive)
  - **Interval**: 60 seconds
  - **Fallback**: Container restart if unhealthy

#### Metrics
- **Resource usage**:
  - CPU, RAM, Disk tracked via `docker stats`
  - Alerts if thresholds exceeded (80% of limits)

- **VPN statistics**:
  - Active clients count
  - Data transfer per client
  - Connection uptime

#### Logging
- **Container logs**:
  - **Retention**: 7 days (rotated)
  - **Max size**: 100 MB per container
  - **Driver**: json-file with rotation

- **Application logs**:
  - **Bot**: Commands, errors, auth failures
  - **wg-easy**: Client connections, config changes
  - **WireGuard**: Kernel module logs (via dmesg)

---

### Compliance

#### Data Privacy
- **User data**: Telegram usernames, IP addresses, timestamps
- **Storage**: Local only (not shared with third parties)
- **Retention**: 30 days for logs, indefinite for configs
- **Deletion**: Manual via wg-easy UI or bot command

#### Legal
- **VPN usage**: User responsibility for legal compliance
- **Disclaimer**: Tool provided as-is for bypassing geo-blocks
- **No warranty**: No guarantees of anonymity or security

#### Russian Federation Specifics
- **Telegram access**: Assumes Telegram is accessible
- **WireGuard legality**: VPN usage is legal for individuals
- **Server location**: Recommend non-Russian jurisdiction

---

### Documentation

#### Installation Guide
- **Format**: Markdown in docs/VPN_INSTALL.md
- **Contents**:
  - Prerequisites checklist
  - Step-by-step installation
  - Troubleshooting common issues
  - Port forwarding setup (for NAT)

#### User Guide
- **Format**: Markdown in docs/VPN_USER_GUIDE.md
- **Contents**:
  - How to request VPN via bot
  - WireGuard client installation (Windows, macOS, Linux, iOS, Android)
  - QR code scanning instructions
  - Connection troubleshooting

#### API/Bot Commands
- **Format**: Markdown in docs/BOT_COMMANDS.md
- **Contents**:
  - /start - Welcome message
  - /request - Request new VPN config
  - /revoke - Revoke existing config
  - /status - Check VPN status
  - /help - Command reference

---

### Constraints Summary

| Category | Constraint | Target | Hard Limit |
|----------|-----------|---------|-----------|
| **Performance** | VPN throughput | 100 Mbps | 80 Mbps |
| | Latency overhead | <30ms | <50ms |
| | Bot response time | <1s | <2s |
| **Resources** | RAM (total) | 384 MB | 768 MB |
| | CPU (total) | 0.3 cores | 0.75 cores |
| | Disk | 300 MB | 500 MB |
| **Reliability** | Uptime | 99% | 95% |
| | Container restarts | Auto | 3/5min |
| **Security** | Encryption | ChaCha20 | N/A |
| | Auth | Password + Telegram | N/A |
| **Compatibility** | Ubuntu | 20.04+ | 20.04+ |
| | Docker | 20.10+ | 20.10+ |
| | Kernel | 5.6+ | 5.6+ |

---

### Risk Mitigation

**R-001: Port conflicts**
- **Mitigation**: Pre-installation port check
- **Fallback**: Offer alternative ports

**R-002: Telegram blocked in Russia**
- **Mitigation**: Document QR code export from wg-easy UI
- **Fallback**: Manual config distribution via email/file share

**R-003: Resource exhaustion**
- **Mitigation**: Resource limits in docker-compose.yml
- **Monitoring**: Alerts at 80% threshold

**R-004: WireGuard kernel module missing**
- **Mitigation**: Pre-installation kernel check
- **Fallback**: Use wireguard-go (userspace implementation)

---

### Evidence Level: D (Assumptions)

**Critical assumptions requiring validation:**
1. WireGuard effectively bypasses Russian geo-blocks (need pilot test)
2. Telegram API remains accessible in Russia (need monitoring)
3. 8GB RAM / 8 CPU sufficient for n8n + VPN + bot (need resource profiling)
4. wg-easy + vpnTelegram bot integration works as expected (need integration test)

**Validation priority**: A1, A2 (HIGH RISK) → Test immediately in production-like environment
