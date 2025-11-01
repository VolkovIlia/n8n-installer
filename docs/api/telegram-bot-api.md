# Telegram Bot API Documentation

## Overview

The VPN Telegram bot provides a user-friendly interface for managing WireGuard VPN configurations. Users interact with the bot via commands, and the bot handles VPN configuration generation, distribution, and management.

**Bot Commands**: `/start`, `/request`, `/status`, `/revoke`
**Access Control**: Whitelist-based (optional)
**Response Time**: <2 seconds for all commands

---

## Command Reference

### /start

Initialize bot session and display welcome message.

**Usage**: `/start`

**Access**: Public (all Telegram users)

**Response**:
```
Welcome to VPN Manager Bot!

This bot helps you generate WireGuard VPN configurations.

Available commands:
/request - Get your VPN configuration
/status - Check your VPN connection status
/revoke - Revoke your VPN access

Questions? Contact @your_admin_username
```

**Implementation Details**:
- No side effects (doesn't create VPN configs)
- Doesn't check whitelist (informational only)
- Response time: <500ms

**Example Interaction**:
```
User: /start

Bot: Welcome to VPN Manager Bot!
     ...
     Available commands:
     /request - Get your VPN configuration
     ...
```

---

### /request

Generate and send VPN configuration file + QR code.

**Usage**: `/request`

**Access**: Whitelist members only (if `BOT_WHITELIST` is configured)

**Prerequisites**:
- User must be in `BOT_WHITELIST` (if configured)
- wg-easy service must be healthy
- User doesn't already have an active config

**Response Flow**:

1. **Authorization Check** (if whitelist enabled):
   ```
   Bot: Checking authorization...
   ```

2. **Success** (3 messages):

   a. **Document Message**:
   ```
   📄 user_123456_1730000000.conf
   [File attachment: WireGuard configuration]
   ```

   b. **Photo Message**:
   ```
   📱 [QR Code Image]
   ```

   c. **Instructions**:
   ```
   ✅ VPN configuration created!

   To connect:
   1. Install WireGuard app (iOS/Android/Windows/macOS/Linux)
   2. Import .conf file OR scan QR code
   3. Tap "Connect"

   Your VPN IP: 10.8.0.2
   Server: {WG_HOST}:51820
   ```

**Error Responses**:

- **Not Authorized**:
  ```
  ❌ Access denied

  Your Telegram user ID (123456) is not in the whitelist.
  Contact administrator to request access.
  ```

- **Config Already Exists**:
  ```
  ⚠️ You already have a VPN configuration.

  Use /status to view details or /revoke to delete and create new.
  ```

- **Service Unavailable**:
  ```
  ❌ VPN service temporarily unavailable

  Please try again in a few minutes.
  Error: wg-easy API connection timeout
  ```

**Implementation Flow**:

```
User sends /request
    ↓
Bot validates whitelist (if configured)
    ↓
Bot creates client via wg-easy API:
  - Client name: user_{telegram_id}_{timestamp}
  - Receives: config text, QR code data URL
    ↓
Bot generates QR code PNG from config
    ↓
Bot sends 3 messages:
  1. sendDocument (user_123456_1730000000.conf)
  2. sendPhoto (QR code PNG)
  3. sendMessage (instructions)
    ↓
User imports config in WireGuard app
```

**Rate Limits**:
- 5 requests per hour per user (recommended)
- 60-second cooldown between consecutive requests

**Example Interaction**:
```
User: /request

Bot: 📄 user_123456_1730000000.conf
     [.conf file attachment]

Bot: 📱 [QR code image]

Bot: ✅ VPN configuration created!
     To connect:
     1. Install WireGuard app...
```

---

### /status

Display VPN connection status and usage statistics.

**Usage**: `/status`

**Access**: Whitelist members only (if `BOT_WHITELIST` is configured)

**Response** (Config Exists):
```
📊 VPN Status

Name: user_123456_1730000000
VPN IP: 10.8.0.2
Status: ✅ Connected

Last handshake: 2 minutes ago
Data usage:
  ⬇️ Downloaded: 1.23 GB
  ⬆️ Uploaded: 0.87 GB

Server: {WG_HOST}:51820
Created: 2025-11-01 12:00:00 UTC
```

**Response** (Never Connected):
```
📊 VPN Status

Name: user_123456_1730000000
VPN IP: 10.8.0.2
Status: ⚠️ Never connected

Last handshake: Never
Data usage:
  ⬇️ Downloaded: 0 B
  ⬆️ Uploaded: 0 B

Server: {WG_HOST}:51820
Created: 2025-11-01 12:00:00 UTC

Tip: Make sure you imported the config and tapped "Connect" in WireGuard app.
```

**Response** (No Config):
```
❌ No VPN configuration found

Use /request to create a new configuration.
```

**Implementation Details**:
- Queries wg-easy API: `GET /api/wireguard/client/{clientId}`
- Extracts: `transferRx`, `transferTx`, `latestHandshakeAt`
- Formats bytes to human-readable (GB/MB/KB)
- Calculates handshake age (e.g., "2 minutes ago")

**Example Interaction**:
```
User: /status

Bot: 📊 VPN Status
     Name: user_123456_1730000000
     VPN IP: 10.8.0.2
     Status: ✅ Connected
     ...
```

---

### /revoke

Revoke VPN access and delete configuration.

**Usage**: `/revoke`

**Access**: Whitelist members only (if `BOT_WHITELIST` is configured)

**Confirmation** (optional for v1.0):
```
⚠️ Revoke VPN Access?

This will:
- Delete your VPN configuration
- Terminate active connections
- You'll need to use /request to create new config

Type /revoke_confirm to proceed or /cancel to abort.
```

**Response** (Success):
```
✅ VPN access revoked

Your configuration has been deleted.
Active connections terminated.

Use /request to create a new configuration if needed.
```

**Response** (No Config):
```
❌ No active configuration found

Nothing to revoke.
```

**Response** (Error):
```
❌ Failed to revoke access

Error: wg-easy API returned 500
Please contact administrator.
```

**Implementation Flow**:
```
User sends /revoke
    ↓
Bot finds client by user_id prefix
    ↓
Bot calls wg-easy API:
  DELETE /api/wireguard/client/{clientId}
    ↓
wg-easy removes WireGuard peer
    ↓
Active VPN connections terminated
    ↓
Bot confirms deletion to user
```

**Security Note**: Users can only revoke their own configurations. Client name includes user ID, preventing cross-user deletion.

**Example Interaction**:
```
User: /revoke

Bot: ✅ VPN access revoked
     Your configuration has been deleted.
     Active connections terminated.
     ...
```

---

## Admin Commands (Future)

### /revoke_user (Admin Only)

Revoke any user's VPN access.

**Usage**: `/revoke_user <telegram_user_id>`

**Access**: Admins only (check `BOT_ADMINS` env var)

**Example**:
```
Admin: /revoke_user 123456

Bot: ✅ Revoked VPN access for user 123456

     User has been notified.
```

**Implementation**: Check `os.getenv("BOT_ADMINS")` for comma-separated admin user IDs.

---

## Access Control

### Whitelist Configuration

**Environment Variable**: `BOT_WHITELIST`

**Format**: Comma-separated Telegram user IDs
```bash
BOT_WHITELIST=123456789,987654321,555666777
```

**Behavior**:
- **If empty**: All users allowed (open access mode)
- **If set**: Only listed user IDs can use commands (except `/start`)

**Getting User ID**:

1. **Via bot logs**:
   ```bash
   docker logs vpn-telegram-bot | grep "User ID"
   # Output: User ID: 123456789
   ```

2. **Via Telegram bot**:
   User sends any command → Bot logs user ID → Admin checks logs

3. **Via @userinfobot**:
   User forwards message to @userinfobot → Receives user ID

**Example Whitelist Check** (Python):
```python
import os

def _is_authorized(user_id: int) -> bool:
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

---

## Error Handling

All bot commands handle errors gracefully:

### Network Timeout

```
❌ VPN service timeout

The VPN service is not responding.
Please try again in a few minutes.
```

### wg-easy API Error

```
❌ VPN service error

Error: HTTP 500 Internal Server Error
Please contact administrator.
```

### Invalid Input

```
❌ Invalid command

Available commands:
/request - Get VPN configuration
/status - Check status
/revoke - Delete configuration
```

### Bot Restart Recovery

Bot automatically recovers from restarts:
- Session tokens stored in memory (recreated on restart)
- No state persisted (stateless bot)
- All commands work immediately after restart

---

## Response Times

| Command | Expected | Maximum | Notes |
|---------|----------|---------|-------|
| /start | <500ms | 2s | Informational only |
| /request | <3s | 10s | Includes wg-easy API call + QR generation |
| /status | <2s | 5s | Single wg-easy API call |
| /revoke | <2s | 5s | Single wg-easy API call |

**Timeout Handling**:
- All wg-easy API calls have 10-second timeout
- Telegram API calls have default timeout (30s)
- If timeout exceeded → User receives error message

---

## Logging

All bot commands are logged to stdout (captured by Docker):

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

**Log Levels**:
- `INFO`: Normal operations (command execution, client creation)
- `WARN`: Authorization failures, rate limits
- `ERROR`: API failures, timeouts, exceptions

**Viewing Logs**:
```bash
# Real-time logs
docker logs -f vpn-telegram-bot

# Last 100 lines
docker logs --tail 100 vpn-telegram-bot

# Filter by level
docker logs vpn-telegram-bot 2>&1 | grep ERROR
```

---

## Rate Limiting

Bot implements per-user rate limits:

| Command | Limit | Window | Action on Exceed |
|---------|-------|--------|------------------|
| /request | 5 | 1 hour | Send "Too many requests" message |
| /status | 10 | 1 minute | Ignore silently |
| /revoke | 3 | 1 hour | Send "Too many requests" message |

**Implementation** (simplified):
```python
from collections import defaultdict
import time

class RateLimiter:
    def __init__(self):
        self.requests = defaultdict(list)  # user_id -> [timestamps]

    def is_allowed(self, user_id: int, limit: int, window: int) -> bool:
        now = time.time()

        # Remove old timestamps
        self.requests[user_id] = [
            ts for ts in self.requests[user_id]
            if now - ts < window
        ]

        # Check limit
        if len(self.requests[user_id]) >= limit:
            return False

        # Record new request
        self.requests[user_id].append(now)
        return True
```

---

## Security Considerations

### User Input Validation

All user input is validated:
- Client names: Alphanumeric + underscore/hyphen only
- Telegram user IDs: Verified by Telegram API (cannot be spoofed)
- No SQL injection risk (no database)
- No command injection risk (no shell calls with user input)

### Secret Protection

Bot never logs sensitive data:
- ✅ `BOT_TOKEN`: Never logged
- ✅ `WG_PASSWORD`: Never logged
- ✅ VPN private keys: Never logged
- ✅ Session tokens: Never logged
- ✅ User IDs: Logged (safe, used for identification)

### Authorization Checks

All commands (except `/start`) check whitelist:
```python
if not self._is_authorized(user_id):
    await self.msg.send_message(chat_id, "❌ Access denied")
    return  # Early return, no further processing
```

---

## Integration Example

Complete bot command handler:

```python
from telegram import Update
from telegram.ext import ContextTypes

class RequestHandler:
    def __init__(self, vpn_adapter, msg_adapter):
        self.vpn = vpn_adapter
        self.msg = msg_adapter

    async def handle(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        chat_id = update.effective_chat.id
        user_id = update.effective_user.id

        # Early authorization check
        if not self._is_authorized(user_id):
            await self.msg.send_message(chat_id, "❌ Access denied")
            return

        try:
            # Create VPN client
            client_name = f"user_{user_id}_{int(time.time())}"
            client = self.vpn.create_client(client_name)

            if not client:
                await self.msg.send_message(
                    chat_id,
                    "❌ Failed to create VPN configuration"
                )
                return

            # Send config file
            await self.msg.send_document(
                chat_id,
                document=client['configuration'].encode('utf-8'),
                filename=f"{client_name}.conf"
            )

            # Send QR code
            qr_bytes = self._generate_qr(client['configuration'])
            await self.msg.send_photo(chat_id, photo=qr_bytes)

            # Send instructions
            instructions = (
                f"✅ VPN configuration created!\n\n"
                f"To connect:\n"
                f"1. Install WireGuard app\n"
                f"2. Import .conf file OR scan QR code\n"
                f"3. Tap 'Connect'\n\n"
                f"Your VPN IP: {client['address']}"
            )
            await self.msg.send_message(chat_id, instructions)

        except Exception as e:
            logger.error(f"Request failed for user {user_id}: {e}")
            await self.msg.send_message(
                chat_id,
                "❌ VPN service temporarily unavailable"
            )
```

---

## References

- **Telegram Bot API**: https://core.telegram.org/bots/api
- **python-telegram-bot**: https://python-telegram-bot.org/
- **Bot Setup Guide**: https://core.telegram.org/bots#how-do-i-create-a-bot
