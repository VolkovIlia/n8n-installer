# wg-easy API Documentation

## Overview

The wg-easy service exposes an HTTP API for WireGuard client management. This API is used by the Telegram bot to create, delete, and query VPN configurations.

**Base URL**: `http://wg-easy:51821/api` (internal Docker network)
**External URL**: `http://{WG_HOST}:51821/api` (if exposed)
**Authentication**: Session-based (password authentication required)

## Authentication

### Create Session

**POST** `/api/session`

Creates a new session for API access.

**Request Body**:
```json
{
  "password": "your-wg-password-here"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "sessionToken": "eyJhbGc..."
}
```

**Error Responses**:
- `401 Unauthorized`: Invalid password
- `429 Too Many Requests`: Rate limit exceeded (5 attempts/minute)

**Example** (curl):
```bash
curl -X POST http://localhost:51821/api/session \
  -H "Content-Type: application/json" \
  -d '{"password": "your-password"}'
```

**Example** (Python):
```python
import requests

resp = requests.post(
    "http://wg-easy:51821/api/session",
    json={"password": "your-password"},
    timeout=10
)

if resp.status_code == 200:
    session_token = resp.json()["sessionToken"]
    print(f"Authenticated: {session_token}")
else:
    print(f"Auth failed: {resp.status_code}")
```

**Session Details**:
- **TTL**: 24 hours
- **Storage**: HTTP-only cookie + response body
- **Refresh**: Re-authenticate after expiration (no refresh endpoint)
- **Concurrency**: Multiple sessions allowed per password

---

## Client Management

### Create Client

**POST** `/api/wireguard/client`

Creates a new WireGuard client configuration.

**Request Headers**:
```
Authorization: Bearer {sessionToken}
Content-Type: application/json
```

**Request Body**:
```json
{
  "name": "user_123456_1730000000"
}
```

**Field Validation**:
- `name`: Required, alphanumeric + underscore/hyphen, 1-50 characters
- Pattern: `^[a-zA-Z0-9_-]+$`
- Uniqueness: Must be unique across all clients

**Response** (201 Created):
```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "name": "user_123456_1730000000",
  "address": "10.8.0.2",
  "publicKey": "YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY=",
  "createdAt": "2025-11-01T12:00:00Z",
  "enabled": true,
  "configuration": "[Interface]\nPrivateKey = ...\n[Peer]\n...",
  "qrcodeDataURL": "data:image/png;base64,iVBORw0KGgoAAAANS..."
}
```

**Response Fields**:
- `id`: UUID (auto-generated, used for delete/get operations)
- `name`: Client name (as provided in request)
- `address`: VPN IP address (auto-assigned from 10.8.0.0/24 subnet)
- `publicKey`: Client public key (base64-encoded)
- `createdAt`: ISO 8601 timestamp
- `enabled`: Always `true` on creation
- `configuration`: Complete WireGuard .conf file content
- `qrcodeDataURL`: Base64-encoded PNG QR code (data URL format)

**Error Responses**:
- `400 Bad Request`: Invalid client name or name already exists
- `401 Unauthorized`: Session expired or invalid
- `500 Internal Server Error`: WireGuard service error

**Example** (curl):
```bash
curl -X POST http://localhost:51821/api/wireguard/client \
  -H "Authorization: Bearer ${SESSION_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"name": "alice"}'
```

**Example** (Python):
```python
resp = requests.post(
    "http://wg-easy:51821/api/wireguard/client",
    headers={"Authorization": f"Bearer {session_token}"},
    json={"name": "user_123456_1730000000"},
    timeout=10
)

if resp.status_code == 201:
    client = resp.json()
    print(f"Client created: {client['id']}")
    print(f"VPN IP: {client['address']}")
    print(f"Config length: {len(client['configuration'])} chars")
else:
    print(f"Failed: {resp.status_code} - {resp.text}")
```

---

### List Clients

**GET** `/api/wireguard/client`

Returns list of all WireGuard clients.

**Request Headers**:
```
Authorization: Bearer {sessionToken}
```

**Response** (200 OK):
```json
[
  {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "name": "user_123456_1730000000",
    "address": "10.8.0.2",
    "publicKey": "YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY=",
    "createdAt": "2025-11-01T12:00:00Z",
    "enabled": true
  },
  {
    "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
    "name": "user_789012_1730003600",
    "address": "10.8.0.3",
    "publicKey": "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ=",
    "createdAt": "2025-11-01T13:00:00Z",
    "enabled": true
  }
]
```

**Notes**:
- Returns empty array `[]` if no clients exist
- Does NOT include `configuration` or `qrcodeDataURL` fields (use GET by ID for full details)
- Ordered by creation date (oldest first)

**Example** (Python):
```python
resp = requests.get(
    "http://wg-easy:51821/api/wireguard/client",
    headers={"Authorization": f"Bearer {session_token}"},
    timeout=10
)

clients = resp.json()
for client in clients:
    print(f"{client['name']}: {client['address']}")
```

---

### Get Client Details

**GET** `/api/wireguard/client/{clientId}`

Returns detailed client information including usage statistics.

**Request Headers**:
```
Authorization: Bearer {sessionToken}
```

**Path Parameters**:
- `clientId`: UUID (from create or list response)

**Response** (200 OK):
```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "name": "user_123456_1730000000",
  "address": "10.8.0.2",
  "publicKey": "YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY=",
  "createdAt": "2025-11-01T12:00:00Z",
  "enabled": true,
  "transferRx": 1234567890,
  "transferTx": 987654321,
  "latestHandshakeAt": "2025-11-01T12:30:00Z"
}
```

**Response Fields (Additional)**:
- `transferRx`: Bytes received (integer)
- `transferTx`: Bytes transmitted (integer)
- `latestHandshakeAt`: Last handshake timestamp (null if never connected)

**Error Responses**:
- `404 Not Found`: Client ID does not exist
- `401 Unauthorized`: Session expired

**Example** (Python):
```python
client_id = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
resp = requests.get(
    f"http://wg-easy:51821/api/wireguard/client/{client_id}",
    headers={"Authorization": f"Bearer {session_token}"},
    timeout=10
)

if resp.status_code == 200:
    client = resp.json()
    rx_gb = client['transferRx'] / (1024**3)
    tx_gb = client['transferTx'] / (1024**3)
    print(f"Usage: {rx_gb:.2f} GB down, {tx_gb:.2f} GB up")
```

---

### Delete Client

**DELETE** `/api/wireguard/client/{clientId}`

Deletes a WireGuard client and revokes access.

**Request Headers**:
```
Authorization: Bearer {sessionToken}
```

**Path Parameters**:
- `clientId`: UUID (from create or list response)

**Response** (204 No Content):
```
(Empty body)
```

**Error Responses**:
- `404 Not Found`: Client ID does not exist
- `401 Unauthorized`: Session expired

**Example** (curl):
```bash
curl -X DELETE http://localhost:51821/api/wireguard/client/${CLIENT_ID} \
  -H "Authorization: Bearer ${SESSION_TOKEN}"
```

**Example** (Python):
```python
resp = requests.delete(
    f"http://wg-easy:51821/api/wireguard/client/{client_id}",
    headers={"Authorization": f"Bearer {session_token}"},
    timeout=10
)

if resp.status_code == 204:
    print("Client deleted successfully")
elif resp.status_code == 404:
    print("Client not found (already deleted?)")
```

**Note**: Deletion is immediate. Active VPN connections are terminated within seconds.

---

## Rate Limits

wg-easy enforces rate limits to prevent abuse:

| Endpoint | Limit | Window | Scope |
|----------|-------|--------|-------|
| POST /api/session | 5 requests | 1 minute | Per IP |
| POST /api/wireguard/client | 10 requests | 1 minute | Global |
| GET /api/wireguard/client | 60 requests | 1 minute | Per session |
| DELETE /api/wireguard/client | 10 requests | 1 minute | Global |

**Rate Limit Headers** (returned in response):
```
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 7
X-RateLimit-Reset: 1730000060
```

**429 Response**:
```json
{
  "error": "Rate limit exceeded",
  "retryAfter": 42
}
```

---

## Error Handling

All error responses follow this format:

```json
{
  "error": "Human-readable error message",
  "code": "ERROR_CODE"
}
```

**Error Codes**:
- `INVALID_REQUEST`: Malformed request body or invalid parameters
- `UNAUTHORIZED`: Invalid session token or expired
- `NOT_FOUND`: Resource (client) does not exist
- `CONFLICT`: Client name already exists
- `INTERNAL_ERROR`: WireGuard service error

**HTTP Status Codes**:
- `200 OK`: Success (GET requests)
- `201 Created`: Success (POST create)
- `204 No Content`: Success (DELETE)
- `400 Bad Request`: Invalid input
- `401 Unauthorized`: Auth failure
- `404 Not Found`: Resource not found
- `409 Conflict`: Duplicate name
- `429 Too Many Requests`: Rate limit
- `500 Internal Server Error`: Server error

---

## Session Management Best Practices

### Lazy Session Creation

```python
class WireGuardAPIAdapter:
    def __init__(self, base_url: str, password: str):
        self.base_url = base_url
        self.password = password
        self.session_token: Optional[str] = None

    def _ensure_session(self) -> None:
        """Create session on first API call (lazy init)."""
        if self.session_token:
            return  # Session already exists

        resp = requests.post(
            f"{self.base_url}/api/session",
            json={"password": self.password},
            timeout=10
        )

        if resp.status_code == 200:
            self.session_token = resp.json()["sessionToken"]
        else:
            raise Exception(f"Auth failed: {resp.status_code}")
```

### Auto-Retry on 401

```python
def create_client(self, name: str) -> dict:
    self._ensure_session()

    resp = requests.post(
        f"{self.base_url}/api/wireguard/client",
        headers={"Authorization": f"Bearer {self.session_token}"},
        json={"name": name},
        timeout=10
    )

    if resp.status_code == 401:
        # Session expired, retry once
        self.session_token = None
        self._ensure_session()

        resp = requests.post(
            f"{self.base_url}/api/wireguard/client",
            headers={"Authorization": f"Bearer {self.session_token}"},
            json={"name": name},
            timeout=10
        )

    return resp.json() if resp.status_code == 201 else None
```

---

## Configuration Variables

wg-easy API behavior is controlled by environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `WG_PASSWORD` | (required) | Admin password for UI and API |
| `WG_HOST` | (auto) | Server external IP (for client configs) |
| `WG_PORT` | 51820 | WireGuard protocol port (UDP) |
| `WG_DEFAULT_DNS` | 1.1.1.1 | DNS servers for VPN clients |
| `WG_ALLOWED_IPS` | 0.0.0.0/0, ::/0 | Routes through VPN |
| `WG_PERSISTENT_KEEPALIVE` | 0 | Keepalive interval (0=disabled) |

**Example .env**:
```bash
WG_PASSWORD=auto-generated-32-char-password
WG_HOST=192.168.1.100
WG_DEFAULT_DNS=1.1.1.1,8.8.8.8
```

---

## Complete Example

```python
import requests
from typing import Optional

class WgEasyClient:
    def __init__(self, base_url: str, password: str):
        self.base_url = base_url
        self.password = password
        self.session_token: Optional[str] = None

    def _ensure_session(self) -> None:
        if self.session_token:
            return

        resp = requests.post(
            f"{self.base_url}/api/session",
            json={"password": self.password},
            timeout=10
        )
        resp.raise_for_status()
        self.session_token = resp.json()["sessionToken"]

    def create_client(self, name: str) -> dict:
        self._ensure_session()

        resp = requests.post(
            f"{self.base_url}/api/wireguard/client",
            headers={"Authorization": f"Bearer {self.session_token}"},
            json={"name": name},
            timeout=10
        )

        if resp.status_code == 401:
            # Retry once on session expiration
            self.session_token = None
            self._ensure_session()
            resp = requests.post(
                f"{self.base_url}/api/wireguard/client",
                headers={"Authorization": f"Bearer {self.session_token}"},
                json={"name": name},
                timeout=10
            )

        resp.raise_for_status()
        return resp.json()

    def list_clients(self) -> list:
        self._ensure_session()
        resp = requests.get(
            f"{self.base_url}/api/wireguard/client",
            headers={"Authorization": f"Bearer {self.session_token}"},
            timeout=10
        )
        resp.raise_for_status()
        return resp.json()

    def delete_client(self, client_id: str) -> bool:
        self._ensure_session()
        resp = requests.delete(
            f"{self.base_url}/api/wireguard/client/{client_id}",
            headers={"Authorization": f"Bearer {self.session_token}"},
            timeout=10
        )
        return resp.status_code == 204

# Usage
client = WgEasyClient("http://wg-easy:51821", "your-password")

# Create client
new_client = client.create_client("alice")
print(f"Created: {new_client['id']}")

# List all clients
clients = client.list_clients()
print(f"Total clients: {len(clients)}")

# Delete client
success = client.delete_client(new_client['id'])
print(f"Deleted: {success}")
```

---

## References

- **Official Repository**: https://github.com/wg-easy/wg-easy
- **WireGuard**: https://www.wireguard.com/
- **Docker Image**: ghcr.io/wg-easy/wg-easy:latest
