# Security Model & Access Control

## Overview

This document defines the authentication, authorization, and audit mechanisms for the VPN integration. Current implementation (MVP v1.0) uses environment variables and Telegram user IDs. Future v2.0 will implement JWT-based capability tokens.

**Reference**: See `.dev-docs/capabilities/security-model.md` for detailed security model.

---

## Authentication Layers

### Layer 1: User Authentication (Telegram)

**Mechanism**: Telegram Bot API automatic user verification

**How It Works**:
```
User sends message to bot
    ↓
Telegram API verifies user identity (server-side)
    ↓
Bot receives update.message.from.id (integer, cannot be spoofed)
    ↓
Bot uses user_id for authorization checks
```

**Trust Model**:
- User ID cryptographically verified by Telegram
- Cannot be forged or guessed
- Persistent across sessions
- Same ID across all Telegram apps

**Code**:
```python
# Automatic user ID extraction
user_id = update.effective_user.id  # Verified by Telegram
user_name = update.effective_user.username  # Optional, can be None
```

---

### Layer 2: Whitelist Authorization (Bot)

**Mechanism**: Environment variable whitelist (BOT_WHITELIST)

**Configuration**:
```bash
# .env file
BOT_WHITELIST=123456789,987654321,555666777  # Comma-separated user IDs
```

**Behavior**:
- **If empty**: All users allowed (open access mode)
- **If set**: Only listed user IDs can use commands (except `/start`)

**Authorization Check**:
```python
def _is_authorized(self, user_id: int) -> bool:
    """Check if user is in whitelist."""
    whitelist_str = os.getenv("BOT_WHITELIST", "")

    if not whitelist_str:
        return True  # No whitelist = allow all

    whitelist = [
        int(uid.strip())
        for uid in whitelist_str.split(",")
        if uid.strip()
    ]

    return user_id in whitelist
```

**Early Return Pattern**:
```python
async def handle(self, update, context):
    user_id = update.effective_user.id

    # Fail fast
    if not self._is_authorized(user_id):
        await send_message(chat_id, "❌ Access denied")
        return  # No further processing

    # Authorized path
    await process_command()
```

---

### Layer 3: Bot → wg-easy API Authentication

**Mechanism**: Session token (24-hour TTL)

**Flow**:
```
Bot → wg-easy: POST /api/session {password: WG_PASSWORD}
    ↓
wg-easy: Verify password (bcrypt comparison)
    ↓
wg-easy → Bot: {sessionToken: "eyJhbGc..."}
    ↓
Bot stores token in memory (expires 24h)
    ↓
Bot → wg-easy: All API calls include Authorization: Bearer {token}
```

**Session Management**:

```python
class WireGuardAPIAdapter:
    def __init__(self, base_url: str, password: str):
        self.base_url = base_url
        self.password = password
        self.session_token: Optional[str] = None  # In-memory

    def _ensure_session(self) -> None:
        """Lazy session creation (on first API call)."""
        if self.session_token:
            return  # Session exists

        # Create session
        resp = requests.post(
            f"{self.base_url}/api/session",
            json={"password": self.password},
            timeout=10
        )

        self.session_token = resp.json()["sessionToken"]

    def create_client(self, name: str):
        self._ensure_session()

        # API call with token
        resp = requests.post(
            f"{self.base_url}/api/wireguard/client",
            headers={"Authorization": f"Bearer {self.session_token}"},
            json={"name": name},
            timeout=10
        )

        # Auto-retry on session expiration
        if resp.status_code == 401:
            self.session_token = None  # Clear expired token
            self._ensure_session()  # Re-authenticate
            resp = requests.post(...)  # Retry request

        return resp.json()
```

**Security Properties**:
- Session token stored in memory only (not persisted to disk)
- Token expires after 24 hours (automatic rotation)
- Auto-refresh on 401 (transparent to user)
- One retry only (prevents infinite loop)

---

### Layer 4: Admin → wg-easy UI Authentication

**Mechanism**: Password-based web UI login

**Flow**:
```
Admin → Browser: https://{WG_HOST}:51821
    ↓
wg-easy UI: Prompt for password
    ↓
Admin enters WG_PASSWORD
    ↓
wg-easy: Verify password (bcrypt hash)
    ↓
wg-easy → Admin: Set session cookie (24h TTL)
    ↓
Admin can access UI
```

**Security Controls**:
- Password stored as bcrypt hash (not plaintext)
- Session cookie HTTP-only (XSS protection)
- 24-hour session expiration (forced re-auth)
- Rate limiting: 5 attempts per minute

---

## Authorization Matrix

| Operation | Required Capability | Verification Point | Failure Mode |
|-----------|-------------------|-------------------|--------------|
| **Send /start command** | None (public) | None | N/A |
| **Send /request command** | BOT_WHITELIST (if configured) | Bot handler | "Access denied" message |
| **Send /revoke command** | BOT_WHITELIST + ownership | Bot handler | "Access denied" or "Not your client" |
| **Send /status command** | BOT_WHITELIST (if configured) | Bot handler | "Access denied" message |
| **Create VPN client** | Session token (wg-easy API) | wg-easy API endpoint | HTTP 401 |
| **Delete VPN client** | Session token + client ownership | Bot + wg-easy API | HTTP 401 or "Not found" |
| **Access wg-easy UI** | WG_PASSWORD | wg-easy web UI | HTTP 401 |
| **View all clients** | WG_PASSWORD (UI) or session token (API) | wg-easy | HTTP 401 |
| **Restart containers** | Docker host access (root/sudo) | Docker Engine | Permission denied |

---

## Secret Management

### Environment Variables

**Critical Secrets** (.env file):
```bash
# Telegram Bot (from @BotFather)
BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz1234567890

# wg-easy Admin (auto-generated 32 chars)
WG_PASSWORD=auto-generated-32-character-password-here

# Server External IP (auto-detected or manual)
WG_HOST=192.168.1.100

# Optional: User whitelist (comma-separated Telegram user IDs)
BOT_WHITELIST=123456789,987654321
```

**File Permissions**:
```bash
# Set restrictive permissions
chmod 600 .env  # Read/write owner only
chown $(whoami):$(whoami) .env

# Verify
ls -la .env
# Expected: -rw------- 1 volk volk 256 Nov 01 12:00 .env
```

**Git Protection**:
```bash
# .gitignore (MUST include)
.env
*.env
.env.*
!.env.example
```

**Docker Environment**:
```yaml
# docker-compose.yml
services:
  wg-easy:
    env_file: .env  # Load secrets from .env
    environment:
      - WG_PASSWORD=${WG_PASSWORD}  # Override if needed

  vpnTelegram:
    env_file: .env
    environment:
      - BOT_TOKEN=${BOT_TOKEN}
```

---

### Secret Generation

**BOT_TOKEN**:
```bash
# Get from @BotFather in Telegram:
# 1. Message @BotFather
# 2. Send /newbot
# 3. Follow prompts
# 4. Copy token: 123456789:ABCdefGHI...
```

**WG_PASSWORD**:
```bash
# Auto-generated during installation (32 chars, high entropy)
WG_PASSWORD=$(openssl rand -base64 32)

# Example output: 3K9j2Hd8fL1mN5pQ7rS9tU0vW2xY4zA6B8
```

**Validation**:
```bash
# Verify BOT_TOKEN format
echo $BOT_TOKEN | grep -E '^[0-9]+:[A-Za-z0-9_-]{35}$'

# Verify WG_PASSWORD length
echo $WG_PASSWORD | wc -c  # Should be 44 (32 base64 + newline)
```

---

## Audit Logging

### Bot Command Logs

**Format**:
```
[timestamp] LEVEL: Message {context}
```

**Examples**:
```
[2025-11-01 12:00:00] INFO: User 123456 executed /request
[2025-11-01 12:00:01] INFO: Client created: user_123456_1730000000 (ID: a1b2c3d4-...)
[2025-11-01 12:00:02] INFO: QR code sent to user 123456
[2025-11-01 12:05:00] WARN: User 999999 denied access (not in whitelist)
[2025-11-01 12:10:00] ERROR: wg-easy API timeout for user 123456
```

**Viewing Logs**:
```bash
# Real-time logs
docker logs -f vpn-telegram-bot

# Last 100 lines
docker logs --tail 100 vpn-telegram-bot

# Filter by level
docker logs vpn-telegram-bot 2>&1 | grep ERROR

# Filter by user
docker logs vpn-telegram-bot 2>&1 | grep "User 123456"
```

**Log Retention**: 30 days (Docker log rotation)

---

### wg-easy Access Logs

**Logged Events**:
- API calls: Timestamp, endpoint, HTTP status
- UI logins: Timestamp, IP address, success/failure
- Client operations: Create, delete, connect, disconnect

**Viewing Logs**:
```bash
docker logs wg-easy | grep "POST /api/session"
docker logs wg-easy | grep "POST /api/wireguard/client"
docker logs wg-easy | grep "DELETE /api/wireguard/client"
```

---

## Security Threats & Mitigations

### T-001: Unauthorized VPN Access

**Threat**: Attacker obtains VPN config without authorization.

**Attack Vectors**:
1. Steal BOT_TOKEN → Can impersonate bot but still needs Telegram user ID
2. Steal WG_PASSWORD → Can access wg-easy UI and create clients
3. Brute force wg-easy UI password → Mitigated by rate limiting

**Mitigations**:
- ✅ BOT_TOKEN in .env with 600 permissions
- ✅ WG_PASSWORD auto-generated (32 chars, high entropy: 2^256 keyspace)
- ✅ Rate limiting on wg-easy UI (5 attempts/minute)
- ✅ Whitelist enforcement (BOT_WHITELIST if configured)
- ✅ Audit logging (all auth attempts logged)

**Risk Level**: MEDIUM (depends on .env file protection)

---

### T-002: VPN Config Leakage

**Threat**: VPN config (.conf file or QR code) intercepted or shared.

**Attack Vectors**:
1. Telegram message interception → Mitigated by Telegram encryption
2. User shares config with unauthorized party → Out of scope (user responsibility)
3. Config stolen from user device → Out of scope (device security)

**Mitigations**:
- ✅ Telegram transport encryption (TLS 1.2+)
- ⚠️ User education: "Do not share config files"
- 🔄 Future: Config expiration (STRETCH feature v2.0)

**Risk Level**: LOW (primary mitigation is Telegram encryption)

---

### T-003: Denial of Service (Bot Flooding)

**Threat**: Attacker floods bot with requests, exhausting resources.

**Attack Vectors**:
1. Massive /request spam → Mitigated by rate limiting
2. Large number of Telegram accounts → Mitigated by whitelist

**Mitigations**:
- ✅ Per-user rate limits (5 /request per hour recommended)
- ✅ Global rate limit (60 requests/minute at wg-easy level)
- ✅ BOT_WHITELIST (if enabled, limits to known users)
- ✅ Docker resource limits (wg-easy: 512MB, bot: 256MB)
- ✅ Telegram API rate limiting (30 msg/sec, 20 msg/min per chat)

**Risk Level**: LOW (multiple defense layers)

---

### T-004: Privilege Escalation

**Threat**: Regular user gains admin access to wg-easy UI.

**Attack Vectors**:
1. Exploit bot to leak WG_PASSWORD → Bot never logs password
2. Exploit wg-easy vulnerability → Use latest official image

**Mitigations**:
- ✅ Bot never logs WG_PASSWORD (stored in memory only)
- ✅ Use official wg-easy image (ghcr.io/wg-easy/wg-easy:latest)
- ✅ Network isolation (bot on vpn_network, no direct n8n access)
- ✅ Regular updates (docker-compose pull weekly)

**Risk Level**: LOW (defense in depth)

---

### T-005: Container Breakout

**Threat**: Attacker escapes container and gains host access.

**Attack Vectors**:
1. Exploit Docker vulnerability → Use latest Docker version
2. Exploit wg-easy with NET_ADMIN capability → Required for WireGuard

**Mitigations**:
- ✅ Drop unnecessary capabilities (bot uses default, wg-easy requires NET_ADMIN only)
- ✅ Network isolation (separate Docker networks)
- ⚠️ NET_ADMIN required for WireGuard (cannot remove, inherent risk)
- ✅ Read-only mounts where possible (/lib/modules:ro)
- ✅ Resource limits (prevent resource exhaustion)

**Risk Level**: MEDIUM (NET_ADMIN is powerful capability, but required)

---

## Security Checklist

### Deployment Security

- [ ] `.env` file permissions set to 600
- [ ] `.env` added to .gitignore (never committed)
- [ ] BOT_TOKEN obtained from @BotFather (not reused)
- [ ] WG_PASSWORD auto-generated (32+ chars)
- [ ] BOT_WHITELIST configured (if access control needed)
- [ ] Docker images from official sources only
- [ ] wg-easy UI accessible only from trusted IPs (firewall rules)

### Operational Security

- [ ] Regular Docker image updates (weekly `docker-compose pull`)
- [ ] Monitor failed auth attempts (review logs weekly)
- [ ] Audit whitelist periodically (remove departed users)
- [ ] Backup .env file securely (encrypted, off-site)
- [ ] Test rollback procedure (verify backups work)

### Code Security

- [ ] No secrets in source code (all from environment)
- [ ] No secrets in logs (bot never logs BOT_TOKEN or WG_PASSWORD)
- [ ] Input validation on all user input (client names, user IDs)
- [ ] Error messages don't leak secrets (generic "Service unavailable")
- [ ] HTTPS for external APIs (Telegram API, future webhooks)

---

## Future: JWT-Based Capability System (v2.0)

### Token Structure

**JWT Claims**:
```json
{
  "iss": "n8n-installer-vpn",       // Issuer
  "sub": "user_123456",              // Subject (user identifier)
  "aud": ["vpn-api", "mcp-server"],  // Audience
  "exp": 1730003600,                 // Expiration (Unix timestamp)
  "iat": 1730000000,                 // Issued at
  "scope": ["vpn:create", "vpn:revoke", "vpn:status"],  // Capabilities
  "user_id": 123456,                 // Telegram user ID
  "role": "client"                   // Role (client/admin)
}
```

### Scope Definitions

| Scope | Description | Operations | Token Type |
|-------|-------------|------------|------------|
| `vpn:create` | Create VPN clients | POST /api/wireguard/client | Client, Admin |
| `vpn:revoke` | Delete VPN clients | DELETE /api/wireguard/client/{id} | Client (own), Admin (any) |
| `vpn:status` | Check VPN status | GET /api/wireguard/client/{id} | Client (own), Admin (any) |
| `vpn:list` | List all clients | GET /api/wireguard/client | Admin only |
| `admin:ui` | Access wg-easy UI | Web UI login | Admin only |

**Migration Timeline**: v2.0 (planned for Q2 2025)

---

## References

- **Detailed Security Model**: `.dev-docs/capabilities/security-model.md`
- **Telegram Bot Security**: https://core.telegram.org/bots/faq#security
- **WireGuard Cryptography**: https://www.wireguard.com/papers/wireguard.pdf
- **Docker Security**: https://docs.docker.com/engine/security/
