# VPN Integration - Security Model & Capability System

## Overview

This document defines the capability-based security model for VPN integration. Current MVP uses environment variables and Telegram user IDs. Future v2.0 will implement JWT-based capability tokens.

---

## Current Security Model (MVP v1.0)

### Identity Primitives

**Telegram User ID as Identity**:
- **Source**: Telegram Bot API (update.message.from.id)
- **Format**: Integer (e.g., 123456789)
- **Verification**: Telegram platform handles authentication
- **Trust**: User ID cannot be spoofed (Telegram API enforces)

**Administrator Identity**:
- **Source**: Server environment (user running install.sh)
- **Access**: wg-easy UI via password, Telegram bot via whitelist
- **Privileges**: Can revoke any user, access UI, view logs

### Capability Tokens (Current)

| Resource | Token Type | Storage | Scope | TTL | Revocation |
|----------|-----------|---------|-------|-----|------------|
| **Telegram Bot API** | BOT_TOKEN | .env file | bot:sendMessage, bot:sendPhoto, bot:sendDocument | Permanent | Via @BotFather |
| **wg-easy UI** | WG_PASSWORD | .env file | admin:* | Permanent | Change in .env + restart |
| **wg-easy API** | Session token | Bot memory | client:create, client:delete, client:read | 24 hours | Logout or timeout |
| **Telegram user access** | User ID whitelist | BOT_WHITELIST env var | vpn:request, vpn:revoke, vpn:status | Permanent | Remove from whitelist |

### Secret Management

**Environment Variables** (.env file):
```bash
# Telegram Bot (from @BotFather)
BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz1234567890

# wg-easy Admin (auto-generated on install)
WG_PASSWORD=auto-generated-32-character-password-here

# Server External IP (auto-detected or manual)
WG_HOST=192.168.1.100

# Optional: User whitelist (comma-separated Telegram user IDs)
BOT_WHITELIST=123456789,987654321
```

**File Permissions**:
- **Ownership**: root:root (or user running Docker)
- **Permissions**: 600 (read/write owner only)
- **Location**: /home/volk/vibeprojects/n8n-installer/.env
- **Git**: Listed in .gitignore (never committed)

### Authentication Flow

#### 1. User → Bot Authentication

```
User sends /request
    ↓
Telegram API verifies user identity (automatic)
    ↓
Bot receives update.message.from.id
    ↓
IF BOT_WHITELIST is empty:
    ✅ Allow (open access mode)
ELSE IF user_id in BOT_WHITELIST:
    ✅ Allow
ELSE:
    ❌ Deny with message "Access denied. Contact administrator."
```

#### 2. Bot → wg-easy API Authentication

```
Bot needs to call wg-easy API
    ↓
IF session token exists and not expired:
    ✅ Use existing token
ELSE:
    POST /api/session {password: WG_PASSWORD}
        ↓
    Receive {sessionToken}
        ↓
    Store in memory (expires in 24h)
        ↓
    Use for subsequent API calls
```

#### 3. Administrator → wg-easy UI Authentication

```
Admin navigates to https://{WG_HOST}:51821
    ↓
UI prompts for password
    ↓
Admin enters WG_PASSWORD (from install.sh output or .env)
    ↓
wg-easy verifies password (bcrypt hash comparison)
    ↓
IF correct:
    ✅ Create session cookie (24h TTL)
    ✅ Grant access to UI
ELSE:
    ❌ Show "Invalid credentials"
    ❌ Log failed attempt
```

### Authorization Matrix (Current)

| Operation | Required Capability | Verification Point | Failure Mode |
|-----------|-------------------|-------------------|--------------|
| Send bot command | Telegram user ID + whitelist | Bot message handler | Deny with message |
| Create VPN client | Session token (wg-easy API) | wg-easy API endpoint | HTTP 401 |
| Delete VPN client | Session token + client ownership | Bot verifies user_id prefix | Deny if not owner |
| Access wg-easy UI | WG_PASSWORD | wg-easy web UI | HTTP 401 |
| View all clients | WG_PASSWORD (via UI) or Session token (via API) | wg-easy endpoints | HTTP 401 |
| Restart containers | Docker host access (root/sudo) | Docker Engine | Permission denied |

### Audit Logging

**Bot Command Logs** (stdout → Docker logs):
```
[2025-11-01 12:00:00] INFO: User 123456 executed /request
[2025-11-01 12:00:01] INFO: Client created: user_123456_1730000000
[2025-11-01 12:00:02] INFO: QR code sent to user 123456
[2025-11-01 12:05:00] WARN: User 999999 denied access (not in whitelist)
```

**wg-easy Access Logs** (internal):
- API calls: Timestamp, endpoint, result
- UI logins: Timestamp, IP address, success/failure
- Client operations: Create, delete, connect, disconnect

**Retention**: 30 days (Docker log rotation)

---

## Capability Checks (Per Operation)

### Operation: /request (Create VPN Config)

**Check Sequence**:
1. ✅ User authenticated by Telegram? → YES (automatic)
2. ✅ User ID in whitelist (or whitelist empty)? → Check BOT_WHITELIST
3. ✅ Bot has valid wg-easy session token? → POST /api/session if needed
4. ✅ Client name unique? → Check existing clients via API
5. ✅ Server resources available? → Check Docker stats (future)
6. ✅ Rate limit not exceeded? → Check user request history

**Early Return Points**:
- Step 2 fails → Return "Access denied"
- Step 3 fails → Return "Service unavailable"
- Step 4 fails → Return "Config already exists"
- Step 6 fails → Return "Too many requests"

### Operation: /revoke (Delete VPN Config)

**Check Sequence**:
1. ✅ User authenticated by Telegram? → YES (automatic)
2. ✅ User ID in whitelist (or whitelist empty)? → Check BOT_WHITELIST
3. ✅ Bot has valid wg-easy session token? → POST /api/session if needed
4. ✅ Client exists for this user? → GET /api/wireguard/client
5. ✅ User owns this client? → Verify user_id prefix in client name

**Early Return Points**:
- Step 2 fails → Return "Access denied"
- Step 4 fails → Return "No active config"
- Step 5 fails → Return "Not your client" (should not happen in MVP)

### Operation: /status (Check VPN Status)

**Check Sequence**:
1. ✅ User authenticated by Telegram? → YES (automatic)
2. ✅ User ID in whitelist (or whitelist empty)? → Check BOT_WHITELIST
3. ✅ Bot has valid wg-easy session token? → POST /api/session if needed
4. ✅ Client exists for this user? → GET /api/wireguard/client/{clientId}

**Early Return Points**:
- Step 2 fails → Return "Access denied"
- Step 4 fails → Return "No active config"

---

## Security Threats & Mitigations

### T-001: Unauthorized VPN Access

**Threat**: Attacker obtains VPN config without authorization

**Attack Vectors**:
- Steal BOT_TOKEN → Attacker can impersonate bot but still needs Telegram user ID
- Steal WG_PASSWORD → Attacker can access wg-easy UI and create clients
- Brute force wg-easy UI password → Mitigated by rate limiting

**Mitigations**:
- ✅ BOT_TOKEN in .env with 600 permissions
- ✅ WG_PASSWORD auto-generated (32 chars, high entropy)
- ✅ Rate limiting on wg-easy UI (5 attempts/minute)
- ✅ Whitelist enforcement (BOT_WHITELIST)
- ✅ Audit logging (failed auth attempts)

**Risk Level**: MEDIUM (depends on .env file protection)

### T-002: VPN Config Leakage

**Threat**: VPN config (.conf file or QR code) intercepted or shared

**Attack Vectors**:
- Telegram message interception → Mitigated by Telegram E2E encryption
- User shares config with unauthorized party → Out of scope (user responsibility)
- Config stolen from user device → Out of scope (device security)

**Mitigations**:
- ✅ Telegram E2E encryption (Secret Chats not required for bots)
- ⚠️ User education: "Do not share config files"
- 🔄 Future: Config expiration (STRETCH feature)

**Risk Level**: LOW (primary mitigation is Telegram encryption)

### T-003: Denial of Service (Bot Flooding)

**Threat**: Attacker floods bot with requests, exhausting resources

**Attack Vectors**:
- Massive /request spam → Mitigated by rate limiting
- Large number of Telegram accounts → Mitigated by whitelist

**Mitigations**:
- ✅ Per-user rate limits (5 /request per hour)
- ✅ Global rate limit (60 requests/minute)
- ✅ BOT_WHITELIST (if enabled)
- ✅ Docker resource limits (wg-easy: 512MB, bot: 256MB)

**Risk Level**: LOW (multiple layers of defense)

### T-004: Privilege Escalation

**Threat**: Regular user gains admin access to wg-easy UI

**Attack Vectors**:
- Exploit bot to leak WG_PASSWORD → Bot never logs password
- Exploit wg-easy vulnerability → Use latest wg-easy image

**Mitigations**:
- ✅ Bot never logs WG_PASSWORD (stored in memory only)
- ✅ Use official wg-easy image (ghcr.io/wg-easy/wg-easy:latest)
- ✅ Network isolation (bot on vpn_network, no direct access from n8n)
- ✅ Regular updates (docker-compose pull)

**Risk Level**: LOW (defense in depth)

### T-005: Container Breakout

**Threat**: Attacker escapes container and gains host access

**Attack Vectors**:
- Exploit Docker vulnerability → Use latest Docker version
- Exploit wg-easy with NET_ADMIN capability → Required for WireGuard

**Mitigations**:
- ✅ Drop unnecessary capabilities (bot uses default, wg-easy requires NET_ADMIN)
- ✅ Network isolation (separate Docker networks)
- ⚠️ NET_ADMIN required for WireGuard (cannot remove)
- ✅ Read-only mounts where possible (/lib/modules:ro)

**Risk Level**: MEDIUM (NET_ADMIN is powerful capability)

---

## Future: JWT-Based Capability System (v2.0)

### Token Structure

**JWT Claims**:
```json
{
  "iss": "n8n-installer-vpn",
  "sub": "user_123456",
  "aud": ["vpn-api", "mcp-server"],
  "exp": 1730003600,
  "iat": 1730000000,
  "scope": ["vpn:create", "vpn:revoke", "vpn:status"],
  "user_id": 123456,
  "role": "client"
}
```

**Token Types**:

1. **Client Token** (issued to users via bot):
   - **Scope**: `vpn:create`, `vpn:revoke`, `vpn:status`
   - **TTL**: 1 hour
   - **Refresh**: Via /refresh command
   - **Issuer**: Bot (signed with JWT_SECRET)

2. **Admin Token** (issued to administrators):
   - **Scope**: `vpn:*`, `admin:*`, `control:*`
   - **TTL**: 24 hours
   - **Refresh**: Via wg-easy UI login
   - **Issuer**: wg-easy (or separate auth service)

3. **MCP Token** (issued to agents):
   - **Scope**: `health:read`, `contracts:read`, `control:reload`
   - **TTL**: 5 minutes (short-lived)
   - **Refresh**: Agent requests escalation
   - **Issuer**: MCP server

### Scope Definitions

| Scope | Description | Operations Allowed | Token Type |
|-------|-------------|-------------------|------------|
| `vpn:create` | Create VPN clients | POST /api/wireguard/client | Client, Admin |
| `vpn:revoke` | Delete VPN clients | DELETE /api/wireguard/client/{id} | Client (own), Admin (any) |
| `vpn:status` | Check VPN status | GET /api/wireguard/client/{id} | Client (own), Admin (any) |
| `vpn:list` | List all clients | GET /api/wireguard/client | Admin only |
| `admin:ui` | Access wg-easy UI | Web UI login | Admin only |
| `control:start` | Start VPN service | POST /control/start | MCP, Admin |
| `control:stop` | Stop VPN service | POST /control/stop | MCP, Admin |
| `control:reload` | Reload config | POST /control/reload | MCP, Admin |

### Token Issuance Flow

```
User sends /request
    ↓
Bot checks whitelist (unchanged)
    ↓
IF authorized:
    Bot generates JWT token {scope: [vpn:create, vpn:revoke, vpn:status]}
        ↓
    Bot includes token in config file (future)
        ↓
    User can use token for direct API access (future web UI)
```

### Token Verification (Capability Check)

```
Request arrives at API endpoint
    ↓
Extract JWT from Authorization header (Bearer token)
    ↓
Verify signature (JWT_SECRET)
    ↓
Check expiration (exp claim)
    ↓
Check audience (aud claim)
    ↓
Extract scope claim
    ↓
IF required_scope in token_scope:
    ✅ Allow operation
ELSE:
    ❌ HTTP 403 Forbidden {error: "insufficient_scope"}
```

### Revocation Mechanism

**Short-Lived Tokens** (preferred):
- TTL: 1 hour for client tokens, 5 minutes for MCP tokens
- No revocation list needed (tokens expire quickly)
- User requests new token via /refresh

**Revocation List** (if needed):
- Store revoked token JTI (JWT ID) in Redis
- Check revocation list on every request
- Expire entries after token TTL

---

## MCP Server Authentication (STRETCH v2.0)

### MCP Client Profile

**Default Permissions** (safe operations):
- `health.get` - ✅ No token required (public endpoint)
- `logs.tail` - ✅ Requires basic token (scope: `logs:read`)
- `contracts.list` - ✅ No token required (public)
- `contracts.describe` - ✅ No token required (public)
- `metrics.snapshot` - ✅ Requires basic token (scope: `metrics:read`)

**Escalated Permissions** (requires strong token):
- `control.start` - ⚠️ Requires admin token (scope: `control:start:vpn`)
- `control.stop` - ⚠️ Requires admin token (scope: `control:stop:vpn`)
- `control.reload` - ⚠️ Requires admin token (scope: `control:reload:vpn`)
- `test.run` - ⚠️ Requires test token (scope: `test:execute`)

**Token Issuance**:
- **Anchor** issues tokens to agents via Task tool context
- **Agent** includes token in Authorization header
- **MCP server** verifies token + scope before execution

**Example**:
```bash
# Agent requests control operation
curl -X POST http://mcp-server:8080/control/reload \
  -H "Authorization: Bearer eyJhbGc..." \
  -H "Content-Type: application/json"

# MCP server checks:
# 1. Token signature valid?
# 2. Token not expired?
# 3. Token scope includes "control:reload:vpn"?
# 4. If all YES → Execute reload
```

---

## Compliance & Privacy

### Data Privacy

**Personal Data Collected**:
- Telegram user ID (integer, not PII)
- Telegram username (optional, not required)
- IP address (in WireGuard handshake logs)
- VPN usage timestamps (connection times)

**Data Storage**:
- **Local only**: All data stored on server (no cloud sync)
- **Retention**: 30 days for logs, indefinite for configs (until deleted)
- **Deletion**: User can request deletion via /revoke

**GDPR Considerations**:
- IP addresses are personal data (GDPR Article 4)
- User has right to access data (implement /data_export command)
- User has right to deletion (implement /delete_account command)

### Russian Federation Specifics

**VPN Legality**:
- ✅ VPN usage is legal for individuals in Russia
- ⚠️ VPN providers must register with Roskomnadzor (not applicable for personal VPN)
- ⚠️ Using VPN to access blocked content is technically illegal but rarely enforced

**Disclaimer** (include in bot /start message):
```
⚠️ Legal Notice:
This VPN is provided as-is for bypassing geographical restrictions.
User is responsible for legal compliance in their jurisdiction.
No warranties or guarantees of anonymity, security, or availability.
```

---

## Security Audit Checklist

✅ **Secrets Management**:
- [ ] BOT_TOKEN in .env (not hardcoded)
- [ ] WG_PASSWORD in .env (not hardcoded)
- [ ] .env file permissions 600
- [ ] .env in .gitignore

✅ **Authentication**:
- [ ] Telegram user ID verified automatically
- [ ] BOT_WHITELIST enforced (if configured)
- [ ] wg-easy session token expires in 24h

✅ **Authorization**:
- [ ] Every bot command checks whitelist
- [ ] Every wg-easy API call includes session token
- [ ] User can only delete own clients

✅ **Audit Logging**:
- [ ] All bot commands logged to stdout
- [ ] Failed auth attempts logged
- [ ] Logs retained for 30 days

✅ **Network Security**:
- [ ] VPN services on isolated Docker network
- [ ] Only required ports exposed (51820/udp, 51821/tcp)
- [ ] No direct access from n8n_network

✅ **Container Security**:
- [ ] Docker resource limits enforced
- [ ] wg-easy uses latest official image
- [ ] Bot uses minimal Python base image

---

## References

- **JWT RFC 7519**: https://tools.ietf.org/html/rfc7519
- **OAuth 2.0 Scopes**: https://tools.ietf.org/html/rfc6749#section-3.3
- **Telegram Bot Security**: https://core.telegram.org/bots/faq#security
- **WireGuard Cryptography**: https://www.wireguard.com/papers/wireguard.pdf
- **Docker Security**: https://docs.docker.com/engine/security/
