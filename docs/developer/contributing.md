# Developer Guide - Contributing to VPN Integration

## Overview

This guide explains how to extend the VPN bot with new commands, adapters, or features while maintaining suckless principles and architecture contracts.

---

## Adding New Bot Commands

### Step 1: Create Handler

Create `vpn-bot/src/handlers/mycommand_handler.py`:

```python
"""Handler for /mycommand - <brief description>"""

import sys
from telegram import Update
from telegram.ext import ContextTypes

from ..interfaces import IVPNProvider, IMessagingProvider


class MyCommandHandler:
    """Handles /mycommand - <detailed description>."""

    def __init__(self, vpn_adapter: IVPNProvider, msg_adapter: IMessagingProvider):
        """
        Initialize handler with dependencies.

        Args:
            vpn_adapter: VPN provider (wg-easy API client)
            msg_adapter: Messaging provider (Telegram API client)
        """
        self.vpn = vpn_adapter
        self.msg = msg_adapter

    async def handle(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """
        Handle /mycommand command.

        Args:
            update: Telegram update object
            context: Bot context

        Flow:
            1. Validate authorization
            2. Perform operation
            3. Send result to user
        """
        chat_id = update.effective_chat.id
        user_id = update.effective_user.id

        # Early validation (fail fast pattern)
        if not self._is_authorized(user_id):
            await self.msg.send_message(chat_id, "❌ Not authorized")
            return

        # Business logic here
        try:
            result = self.vpn.some_operation()
            await self.msg.send_message(chat_id, f"✅ {result}")
        except Exception as e:
            print(f"ERROR: Command failed for user {user_id}: {e}", file=sys.stderr)
            await self.msg.send_message(chat_id, f"❌ Error: {e}")

    def _is_authorized(self, user_id: int) -> bool:
        """
        Check if user is authorized.

        Args:
            user_id: Telegram user ID

        Returns:
            True if authorized, False otherwise
        """
        import os

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

**Handler Requirements**:
- ✅ Constructor: `__init__(self, vpn_adapter, msg_adapter)`
- ✅ Async handler: `async def handle(self, update, context)`
- ✅ Authorization check (except for informational commands)
- ✅ Error handling with try/except
- ✅ Errors logged to stderr (`print(..., file=sys.stderr)`)
- ✅ User-facing messages in Russian or English (consistent with existing commands)

---

### Step 2: Register Handler

Update `vpn-bot/src/handlers/__init__.py`:

```python
"""Command handler registry (table-driven dispatch)."""

from .start_handler import StartHandler
from .request_handler import RequestHandler
from .revoke_handler import RevokeHandler
from .status_handler import StatusHandler
from .mycommand_handler import MyCommandHandler  # ADD THIS

# Command handlers table (key = command name without /)
COMMAND_HANDLERS = {
    'start': StartHandler,
    'request': RequestHandler,
    'revoke': RevokeHandler,
    'status': StatusHandler,
    'mycommand': MyCommandHandler,  # ADD THIS
}

__all__ = ['COMMAND_HANDLERS']
```

**Registration Rules**:
- ✅ Command name must be lowercase, alphanumeric
- ✅ No `/` prefix in key (added automatically by framework)
- ✅ Handler class must have `__init__(vpn_adapter, msg_adapter)` signature
- ✅ Handler must implement `async def handle(update, context)`

---

### Step 3: Update Tests

Create `vpn-bot/tests/test_mycommand_handler.py`:

```python
"""Tests for MyCommandHandler."""

import pytest
from unittest.mock import Mock, AsyncMock

from src.handlers.mycommand_handler import MyCommandHandler


@pytest.fixture
def mock_vpn_adapter():
    """Mock VPN adapter."""
    adapter = Mock()
    adapter.some_operation = Mock(return_value="success")
    return adapter


@pytest.fixture
def mock_msg_adapter():
    """Mock messaging adapter."""
    adapter = Mock()
    adapter.send_message = AsyncMock()
    return adapter


@pytest.fixture
def handler(mock_vpn_adapter, mock_msg_adapter):
    """Create handler with mocked dependencies."""
    return MyCommandHandler(mock_vpn_adapter, mock_msg_adapter)


@pytest.mark.asyncio
async def test_mycommand_authorized(handler, mock_msg_adapter):
    """Test command execution for authorized user."""
    update = Mock()
    update.effective_chat.id = 123456
    update.effective_user.id = 123456

    context = Mock()

    # Mock authorization
    handler._is_authorized = Mock(return_value=True)

    await handler.handle(update, context)

    # Verify success message sent
    mock_msg_adapter.send_message.assert_called_once()
    args = mock_msg_adapter.send_message.call_args[0]
    assert "✅" in args[1]  # Success emoji in message


@pytest.mark.asyncio
async def test_mycommand_unauthorized(handler, mock_msg_adapter):
    """Test command rejection for unauthorized user."""
    update = Mock()
    update.effective_chat.id = 999999
    update.effective_user.id = 999999

    context = Mock()

    # Mock authorization
    handler._is_authorized = Mock(return_value=False)

    await handler.handle(update, context)

    # Verify denial message sent
    mock_msg_adapter.send_message.assert_called_once_with(123456, "❌ Not authorized")
```

**Test Requirements**:
- ✅ Test authorized user case
- ✅ Test unauthorized user case
- ✅ Test error handling (VPN adapter failure)
- ✅ Test edge cases (empty input, invalid params)
- ✅ Use mocks for dependencies (IVPNProvider, IMessagingProvider)
- ✅ Tests pass with `pytest vpn-bot/tests/`

---

### Step 4: Update Documentation

Add command to `docs/api/telegram-bot-api.md`:

```markdown
### /mycommand

<Brief description of what command does>

**Usage**: `/mycommand [optional_param]`

**Access**: Whitelist members only (if `BOT_WHITELIST` is configured)

**Response** (Success):
```
✅ Operation successful

<Details about result>
```

**Response** (Error):
```
❌ Operation failed

<Error details>
```

**Example Interaction**:
```
User: /mycommand

Bot: ✅ Operation successful
     <Result details>
```

**Implementation Details**:
- <Technical notes about implementation>
- <API calls made>
- <Side effects>
```

---

## Extending Adapters

### Adding Methods to Existing Adapter

Example: Add `list_clients_by_prefix()` to WireGuardAPIAdapter:

```python
# vpn-bot/src/adapters/wireguard_api_adapter.py

def list_clients_by_prefix(self, prefix: str) -> list:
    """
    List clients matching name prefix.

    Args:
        prefix: Client name prefix (e.g., "user_123456")

    Returns:
        List of client dicts matching prefix

    Raises:
        Exception: If API call fails
    """
    self._ensure_session()

    resp = requests.get(
        f"{self.base_url}/api/wireguard/client",
        headers={"Authorization": f"Bearer {self.session_token}"},
        timeout=10
    )

    if resp.status_code == 401:
        # Session expired, retry once
        self.session_token = None
        self._ensure_session()
        resp = requests.get(
            f"{self.base_url}/api/wireguard/client",
            headers={"Authorization": f"Bearer {self.session_token}"},
            timeout=10
        )

    if resp.status_code != 200:
        print(f"ERROR: list clients failed: {resp.status_code}", file=sys.stderr)
        return []

    all_clients = resp.json()
    return [c for c in all_clients if c['name'].startswith(prefix)]
```

**Adapter Method Requirements**:
- ✅ Docstring with Args, Returns, Raises
- ✅ Call `_ensure_session()` before API requests
- ✅ Handle 401 with retry (session expiration)
- ✅ Log errors to stderr
- ✅ Return None or [] on error (don't raise exceptions for control flow)
- ✅ Timeout on all HTTP requests (10 seconds)

---

### Creating New Adapter

Example: Add email notification adapter.

**Step 1: Define Interface**

`vpn-bot/src/interfaces/i_notification_provider.py`:
```python
"""Notification provider interface."""

from typing import Protocol


class INotificationProvider(Protocol):
    """Notification provider contract."""

    def send_notification(self, recipient: str, subject: str, body: str) -> bool:
        """
        Send notification.

        Args:
            recipient: Recipient address (email/phone/user_id)
            subject: Notification subject
            body: Notification body (text)

        Returns:
            True if sent successfully, False otherwise
        """
        ...
```

**Step 2: Implement Adapter**

`vpn-bot/src/adapters/email_adapter.py`:
```python
"""Email notification adapter."""

import sys
import smtplib
from email.mime.text import MIMEText

from ..interfaces import INotificationProvider


class EmailAdapter:
    """SMTP email adapter (implements INotificationProvider)."""

    def __init__(self, smtp_host: str, smtp_port: int, username: str, password: str):
        """
        Initialize email adapter.

        Args:
            smtp_host: SMTP server hostname
            smtp_port: SMTP server port
            username: SMTP username
            password: SMTP password
        """
        self.smtp_host = smtp_host
        self.smtp_port = smtp_port
        self.username = username
        self.password = password

    def send_notification(self, recipient: str, subject: str, body: str) -> bool:
        """Send email notification."""
        try:
            msg = MIMEText(body)
            msg['Subject'] = subject
            msg['From'] = self.username
            msg['To'] = recipient

            with smtplib.SMTP(self.smtp_host, self.smtp_port, timeout=10) as server:
                server.starttls()
                server.login(self.username, self.password)
                server.send_message(msg)

            return True
        except Exception as e:
            print(f"ERROR: email send failed: {e}", file=sys.stderr)
            return False
```

**Step 3: Mount Adapter** (Hurd `settrans` pattern)

`vpn-bot/src/main.py`:
```python
# Mount adapters (Hurd translator pattern)
vpn_adapter = WireGuardAPIAdapter(WG_EASY_URL, WG_PASSWORD)
msg_adapter = TelegramBotAdapter(application)
qr_adapter = QRCodeAdapter()
log_adapter = StdoutAdapter()
email_adapter = EmailAdapter(  # ADD THIS
    smtp_host=SMTP_HOST,
    smtp_port=SMTP_PORT,
    username=SMTP_USER,
    password=SMTP_PASS
)

# Pass adapters to handlers
for command, handler_class in COMMAND_HANDLERS.items():
    handler = handler_class(vpn_adapter, msg_adapter, email_adapter)  # ADD email_adapter
    application.add_handler(CommandHandler(command, handler.handle))
```

---

## Suckless Compliance Checklist

Before submitting changes, verify:

### 1. Minimalism

- [ ] Functions ≤50 lines
- [ ] Files ≤500 lines
- [ ] Dependencies <10 (check `requirements.txt`)
- [ ] No unnecessary abstraction

### 2. Clarity

- [ ] Variable names self-documenting
- [ ] Function names describe action (verb_noun pattern)
- [ ] No clever tricks (no metaclasses, complex comprehensions)
- [ ] Comments explain "why" not "what"

### 3. Simplicity

- [ ] Straightforward control flow
- [ ] Minimal nesting depth (≤3 levels)
- [ ] Early returns used appropriately
- [ ] No complex lambda chains

### 4. Composition

- [ ] Small, reusable functions
- [ ] Clear separation of concerns (handlers ≠ adapters ≠ interfaces)
- [ ] Adapters follow interfaces
- [ ] No tight coupling

### 5. Errors as Values

- [ ] No exceptions for control flow
- [ ] Errors logged to stderr
- [ ] Error messages actionable
- [ ] Graceful degradation (return None/[] on error)

### 6. Table-Driven Code

- [ ] COMMAND_HANDLERS dict used
- [ ] No deep if/else chains
- [ ] Configuration in data structures (not code)

---

## Code Review Process

### Pre-Review Checklist

```bash
# 1. Run tests
pytest vpn-bot/tests/ -v

# 2. Check code style (PEP 8)
flake8 vpn-bot/src/ --max-line-length=100 --ignore=E402

# 3. Type check (optional but recommended)
mypy vpn-bot/src/ --ignore-missing-imports

# 4. Check function length
find vpn-bot/src/ -name '*.py' -exec wc -l {} \; | sort -rn | head

# 5. Check file length
find vpn-bot/src/ -name '*.py' -exec wc -l {} \; | awk '$1 > 500'

# 6. Check dependencies count
wc -l < vpn-bot/requirements.txt
```

### Self-Review Questions

1. **Does this change maintain suckless principles?**
   - Are functions small and focused?
   - Is the code simple and readable?

2. **Does this change follow architecture contracts?**
   - Do adapters implement interfaces?
   - Are message flows documented?

3. **Does this change have tests?**
   - Unit tests for new handlers?
   - Integration tests for API changes?

4. **Does this change update documentation?**
   - API docs for new commands?
   - Architecture docs for new adapters?

---

## Testing Guidelines

### Unit Tests

**Scope**: Individual functions, isolated from external dependencies

**Example**:
```python
def test_create_client_success(mock_vpn_adapter):
    """Test successful client creation."""
    mock_vpn_adapter.create_client.return_value = {
        "id": "test-id",
        "name": "test-client",
        "address": "10.8.0.2"
    }

    handler = RequestHandler(mock_vpn_adapter, Mock())
    result = handler.vpn.create_client("test-client")

    assert result["id"] == "test-id"
    assert result["address"] == "10.8.0.2"
```

### Integration Tests

**Scope**: Multiple components, real wg-easy API (test environment)

**Example**:
```python
@pytest.mark.integration
def test_full_request_flow():
    """Test complete /request command flow."""
    # Setup: Start test wg-easy container
    vpn_adapter = WireGuardAPIAdapter("http://localhost:51821", "test-password")
    msg_adapter = Mock()

    handler = RequestHandler(vpn_adapter, msg_adapter)

    # Execute: Simulate user command
    update = create_test_update(user_id=123456, command="/request")
    await handler.handle(update, Mock())

    # Verify: Client created in wg-easy
    clients = vpn_adapter.list_clients()
    assert any(c['name'].startswith("user_123456") for c in clients)

    # Cleanup: Delete test client
    test_client = next(c for c in clients if c['name'].startswith("user_123456"))
    vpn_adapter.delete_client(test_client['id'])
```

**Running Integration Tests**:
```bash
# Start test wg-easy instance
docker run -d --name wg-easy-test \
  -e WG_PASSWORD=test-password \
  -p 51821:51821 \
  ghcr.io/wg-easy/wg-easy:latest

# Run integration tests
pytest vpn-bot/tests/ -m integration

# Cleanup
docker stop wg-easy-test && docker rm wg-easy-test
```

---

## Debugging Tips

### View Bot Logs

```bash
# Real-time logs
docker logs -f vpn-telegram-bot

# Filter by level
docker logs vpn-telegram-bot 2>&1 | grep ERROR

# Last 100 lines
docker logs --tail 100 vpn-telegram-bot
```

### Test wg-easy API Manually

```bash
# Authenticate
curl -X POST http://localhost:51821/api/session \
  -H "Content-Type: application/json" \
  -d '{"password": "your-password"}' \
  | jq '.sessionToken'

# Create client
export SESSION_TOKEN="<token-from-above>"
curl -X POST http://localhost:51821/api/wireguard/client \
  -H "Authorization: Bearer $SESSION_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "debug-test"}' \
  | jq '.'

# List clients
curl -X GET http://localhost:51821/api/wireguard/client \
  -H "Authorization: Bearer $SESSION_TOKEN" \
  | jq '.'
```

### Interactive Python Shell

```bash
# Enter bot container
docker exec -it vpn-telegram-bot python

# Test adapter
>>> from src.adapters.wireguard_api_adapter import WireGuardAPIAdapter
>>> adapter = WireGuardAPIAdapter("http://wg-easy:51821", "your-password")
>>> clients = adapter.list_clients()
>>> print(clients)
```

---

## Common Patterns

### Early Return Pattern

```python
def handle(self, update, context):
    # Validate early, return early
    if not authorized:
        await send_error("Not authorized")
        return

    if not valid_input:
        await send_error("Invalid input")
        return

    # Main logic (positive case) at end
    result = do_operation()
    await send_success(result)
```

### Errors as Values Pattern

```python
def create_client(self, name: str) -> Optional[dict]:
    """
    Create client.

    Returns:
        Client dict if successful, None if failed
    """
    try:
        resp = api_call(name)
        return resp.json() if resp.status_code == 201 else None
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return None  # Return None, don't raise
```

### Table-Driven Dispatch Pattern

```python
# Bad: Deep if/else chain
if command == "start":
    handle_start()
elif command == "request":
    handle_request()
elif command == "status":
    handle_status()
# ...

# Good: Table-driven
HANDLERS = {
    "start": handle_start,
    "request": handle_request,
    "status": handle_status,
}

handler = HANDLERS.get(command)
if handler:
    handler()
```

---

## References

- **Code Review Report**: `.dev-docs/CODE_REVIEW_REPORT.md`
- **Architecture Summary**: `.dev-docs/ARCHITECTURE_SUMMARY.md`
- **Suckless Philosophy**: https://suckless.org/philosophy
- **Python Style Guide**: https://pep8.org/
