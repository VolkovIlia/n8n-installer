# Testing Strategy & Guidelines

## Overview

This document outlines the testing strategy for VPN integration, including unit tests, integration tests, and end-to-end validation.

**Current Coverage**: 8/8 unit tests passed (RequestHandler, StartHandler)

**Reference**: See `.dev-docs/QA_TEST_REPORT.md` for complete test results.

---

## Test Pyramid

```
       /\
      /E2E\      End-to-End Tests (1-2 scenarios)
     /------\
    /  Integ \   Integration Tests (5-10 scenarios)
   /----------\
  /   Unit     \ Unit Tests (20-30 tests)
 /--------------\
```

**Distribution**:
- 70% Unit tests (fast, isolated)
- 20% Integration tests (real wg-easy API)
- 10% E2E tests (full user workflows)

---

## Unit Testing

### Setup

**Dependencies**:
```bash
# Install test dependencies
pip install pytest pytest-asyncio pytest-cov

# Or from requirements-dev.txt
pip install -r vpn-bot/requirements-dev.txt
```

**Directory Structure**:
```
vpn-bot/
├── src/
│   ├── handlers/
│   ├── adapters/
│   └── interfaces/
├── tests/
│   ├── test_request_handler.py
│   ├── test_revoke_handler.py
│   ├── test_wireguard_api_adapter.py
│   └── conftest.py  # Shared fixtures
└── pytest.ini
```

---

### Unit Test Examples

**Test Handler with Mocked Dependencies**:

```python
# tests/test_request_handler.py

import pytest
from unittest.mock import Mock, AsyncMock

from src.handlers.request_handler import RequestHandler


@pytest.fixture
def mock_vpn_adapter():
    """Mock VPN adapter."""
    adapter = Mock()
    adapter.create_client = Mock(return_value={
        "id": "test-id-123",
        "name": "test-client",
        "address": "10.8.0.2",
        "configuration": "[Interface]\n...",
        "qrcodeDataURL": "data:image/png;base64,..."
    })
    return adapter


@pytest.fixture
def mock_msg_adapter():
    """Mock messaging adapter."""
    adapter = Mock()
    adapter.send_message = AsyncMock()
    adapter.send_document = AsyncMock()
    adapter.send_photo = AsyncMock()
    return adapter


@pytest.fixture
def handler(mock_vpn_adapter, mock_msg_adapter):
    """Create handler with mocked dependencies."""
    return RequestHandler(mock_vpn_adapter, mock_msg_adapter)


@pytest.mark.asyncio
async def test_request_authorized_user(handler, mock_vpn_adapter, mock_msg_adapter):
    """Test /request for authorized user."""
    # Arrange
    update = Mock()
    update.effective_chat.id = 123456
    update.effective_user.id = 123456

    context = Mock()

    # Mock authorization
    handler._is_authorized = Mock(return_value=True)

    # Act
    await handler.handle(update, context)

    # Assert
    mock_vpn_adapter.create_client.assert_called_once()
    assert mock_msg_adapter.send_document.call_count == 1
    assert mock_msg_adapter.send_photo.call_count == 1
    assert mock_msg_adapter.send_message.call_count == 1


@pytest.mark.asyncio
async def test_request_unauthorized_user(handler, mock_msg_adapter):
    """Test /request for unauthorized user."""
    # Arrange
    update = Mock()
    update.effective_chat.id = 999999
    update.effective_user.id = 999999

    context = Mock()

    handler._is_authorized = Mock(return_value=False)

    # Act
    await handler.handle(update, context)

    # Assert
    mock_msg_adapter.send_message.assert_called_once_with(
        999999,
        "❌ Access denied"
    )


@pytest.mark.asyncio
async def test_request_vpn_service_failure(handler, mock_vpn_adapter, mock_msg_adapter):
    """Test /request when wg-easy API fails."""
    # Arrange
    update = Mock()
    update.effective_chat.id = 123456
    update.effective_user.id = 123456

    context = Mock()

    handler._is_authorized = Mock(return_value=True)
    mock_vpn_adapter.create_client.return_value = None  # Simulate failure

    # Act
    await handler.handle(update, context)

    # Assert
    mock_msg_adapter.send_message.assert_called_once()
    args = mock_msg_adapter.send_message.call_args[0]
    assert "❌" in args[1]  # Error message
```

**Test Adapter with Mock HTTP Responses**:

```python
# tests/test_wireguard_api_adapter.py

import pytest
from unittest.mock import Mock, patch

from src.adapters.wireguard_api_adapter import WireGuardAPIAdapter


@pytest.fixture
def adapter():
    """Create adapter with test credentials."""
    return WireGuardAPIAdapter("http://test:51821", "test-password")


def test_create_client_success(adapter):
    """Test successful client creation."""
    with patch('requests.post') as mock_post:
        # Mock session creation
        mock_post.return_value = Mock(
            status_code=200,
            json=lambda: {"sessionToken": "test-token"}
        )

        adapter._ensure_session()

        # Mock client creation
        mock_post.return_value = Mock(
            status_code=201,
            json=lambda: {
                "id": "test-id",
                "name": "test-client",
                "address": "10.8.0.2"
            }
        )

        result = adapter.create_client("test-client")

        assert result["id"] == "test-id"
        assert result["address"] == "10.8.0.2"


def test_session_expiration_retry(adapter):
    """Test auto-retry on 401 session expiration."""
    with patch('requests.post') as mock_post:
        # First call: successful session
        # Second call: 401 (session expired)
        # Third call: new session
        # Fourth call: success with new session
        mock_post.side_effect = [
            Mock(status_code=200, json=lambda: {"sessionToken": "old-token"}),
            Mock(status_code=401),  # Expired
            Mock(status_code=200, json=lambda: {"sessionToken": "new-token"}),
            Mock(status_code=201, json=lambda: {"id": "test-id"})
        ]

        adapter._ensure_session()
        result = adapter.create_client("test-client")

        assert result["id"] == "test-id"
        assert mock_post.call_count == 4  # Session + failed + re-auth + retry


def test_list_clients_empty(adapter):
    """Test listing clients when none exist."""
    with patch('requests.get') as mock_get, \
         patch('requests.post') as mock_post:

        # Mock session
        mock_post.return_value = Mock(
            status_code=200,
            json=lambda: {"sessionToken": "test-token"}
        )

        # Mock empty list
        mock_get.return_value = Mock(
            status_code=200,
            json=lambda: []
        )

        clients = adapter.list_clients()

        assert clients == []
```

---

### Running Unit Tests

```bash
# Run all tests
pytest vpn-bot/tests/ -v

# Run specific test file
pytest vpn-bot/tests/test_request_handler.py -v

# Run specific test
pytest vpn-bot/tests/test_request_handler.py::test_request_authorized_user -v

# Run with coverage
pytest vpn-bot/tests/ --cov=src --cov-report=html

# View coverage report
open htmlcov/index.html
```

**Expected Output**:
```
tests/test_request_handler.py::test_request_authorized_user PASSED
tests/test_request_handler.py::test_request_unauthorized_user PASSED
tests/test_wireguard_api_adapter.py::test_create_client_success PASSED
...

========== 8 passed in 0.34s ==========
```

---

## Integration Testing

### Setup Test Environment

**Start Test wg-easy Container**:

```bash
# docker-compose.test.yml
version: '3.8'

services:
  wg-easy-test:
    image: ghcr.io/wg-easy/wg-easy:latest
    container_name: wg-easy-test
    environment:
      - WG_PASSWORD=test-password
      - WG_HOST=127.0.0.1
      - WG_DEFAULT_DNS=1.1.1.1
    ports:
      - "51821:51821/tcp"
    cap_add:
      - NET_ADMIN
    sysctls:
      - net.ipv4.ip_forward=1
    volumes:
      - /lib/modules:/lib/modules:ro

# Start test environment
docker-compose -f docker-compose.test.yml up -d

# Verify
curl http://localhost:51821/
```

---

### Integration Test Examples

**Test Real API Calls**:

```python
# tests/integration/test_wireguard_integration.py

import pytest
from src.adapters.wireguard_api_adapter import WireGuardAPIAdapter


@pytest.fixture(scope="module")
def real_adapter():
    """Create adapter connected to real test wg-easy."""
    return WireGuardAPIAdapter("http://localhost:51821", "test-password")


@pytest.mark.integration
def test_create_and_delete_client(real_adapter):
    """Test full client lifecycle with real API."""
    # Create client
    client = real_adapter.create_client("integration-test-client")

    assert client is not None
    assert client["name"] == "integration-test-client"
    assert "10.8.0." in client["address"]
    assert len(client["configuration"]) > 0

    client_id = client["id"]

    # List clients (verify it exists)
    clients = real_adapter.list_clients()
    assert any(c["id"] == client_id for c in clients)

    # Delete client
    success = real_adapter.delete_client(client_id)
    assert success is True

    # Verify deleted
    clients_after = real_adapter.list_clients()
    assert not any(c["id"] == client_id for c in clients_after)


@pytest.mark.integration
def test_session_management(real_adapter):
    """Test session creation and reuse."""
    # First call: creates session
    real_adapter.session_token = None  # Clear token
    client1 = real_adapter.create_client("test1")

    # Second call: reuses session
    first_token = real_adapter.session_token
    client2 = real_adapter.create_client("test2")
    second_token = real_adapter.session_token

    assert first_token == second_token  # Same session

    # Cleanup
    real_adapter.delete_client(client1["id"])
    real_adapter.delete_client(client2["id"])
```

**Running Integration Tests**:

```bash
# Start test environment first
docker-compose -f docker-compose.test.yml up -d

# Run integration tests
pytest vpn-bot/tests/integration/ -v -m integration

# Cleanup
docker-compose -f docker-compose.test.yml down
```

---

## End-to-End Testing

### Manual E2E Test Scenarios

**Scenario 1: User Requests VPN Config**

1. **Setup**:
   ```bash
   # Deploy to test environment
   bash install.sh
   # Select "3. Install VPN + Telegram bot"
   # Provide test BOT_TOKEN
   ```

2. **Test Steps**:
   - Open Telegram app
   - Search for bot (use @BotFather /mybots to get username)
   - Send `/start` → Expect welcome message
   - Send `/request` → Expect .conf file + QR code + instructions
   - Import .conf file in WireGuard app
   - Tap "Connect" → Verify VPN connected

3. **Verification**:
   ```bash
   # Check client created
   curl http://localhost:51821/api/session \
     -H "Content-Type: application/json" \
     -d '{"password": "'"$WG_PASSWORD"'"}' | jq -r '.sessionToken'

   export TOKEN="<token-from-above>"

   curl http://localhost:51821/api/wireguard/client \
     -H "Authorization: Bearer $TOKEN" | jq '.'

   # Should show client with name pattern: user_{telegram_id}_{timestamp}
   ```

4. **Cleanup**:
   - Send `/revoke` in Telegram
   - Verify config deleted
   - WireGuard connection terminated

---

**Scenario 2: Admin Uses Web UI**

1. **Setup**: Same as above

2. **Test Steps**:
   - Open browser: https://{WG_HOST}:51821
   - Enter WG_PASSWORD (from .env or install.sh output)
   - View clients list
   - Create manual client via UI
   - Download config
   - Delete client

3. **Verification**:
   - Client appears in list
   - Config file downloads correctly
   - QR code displays
   - Deletion removes client

---

### Automated E2E Tests (Future)

**Playwright Bot Testing**:

```python
# tests/e2e/test_telegram_bot.py

import pytest
from playwright.sync_api import sync_playwright


@pytest.mark.e2e
def test_bot_request_flow():
    """Test /request command via Telegram Web."""
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()

        # Login to Telegram Web
        page.goto("https://web.telegram.org")
        # ... authentication steps

        # Search for bot
        page.fill('input[placeholder="Search"]', f"@{BOT_USERNAME}")
        page.click(f'text=@{BOT_USERNAME}')

        # Send /request
        page.fill('input[placeholder="Message"]', '/request')
        page.press('input[placeholder="Message"]', 'Enter')

        # Wait for file attachment
        page.wait_for_selector('text=.conf')

        # Verify QR code received
        assert page.locator('img[alt="QR code"]').count() > 0

        browser.close()
```

**Note**: Requires Telegram test account and Playwright MCP integration.

---

## Test Data Management

### Test Fixtures

```python
# tests/conftest.py

import pytest
from src.adapters.wireguard_api_adapter import WireGuardAPIAdapter


@pytest.fixture(scope="session")
def test_wg_easy_url():
    """wg-easy test instance URL."""
    return "http://localhost:51821"


@pytest.fixture(scope="session")
def test_wg_password():
    """wg-easy test password."""
    return "test-password"


@pytest.fixture
def vpn_adapter(test_wg_easy_url, test_wg_password):
    """VPN adapter connected to test instance."""
    return WireGuardAPIAdapter(test_wg_easy_url, test_wg_password)


@pytest.fixture(autouse=True)
def cleanup_test_clients(vpn_adapter):
    """Auto-cleanup test clients after each test."""
    yield

    # Cleanup: Delete all test clients
    clients = vpn_adapter.list_clients()
    for client in clients:
        if client["name"].startswith("test-") or client["name"].startswith("integration-"):
            vpn_adapter.delete_client(client["id"])
```

---

## Continuous Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/test.yml

name: VPN Bot Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v2

      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install -r vpn-bot/requirements.txt
          pip install -r vpn-bot/requirements-dev.txt

      - name: Run unit tests
        run: |
          pytest vpn-bot/tests/ --cov=src --cov-report=xml

      - name: Upload coverage
        uses: codecov/codecov-action@v2
        with:
          file: ./coverage.xml

      - name: Start test wg-easy
        run: |
          docker-compose -f docker-compose.test.yml up -d
          sleep 5  # Wait for wg-easy to start

      - name: Run integration tests
        run: |
          pytest vpn-bot/tests/integration/ -m integration

      - name: Cleanup
        if: always()
        run: |
          docker-compose -f docker-compose.test.yml down
```

---

## Test Metrics

**Target Coverage**:
- Unit tests: ≥80% line coverage
- Integration tests: ≥60% API endpoint coverage
- E2E tests: ≥90% user workflow coverage

**Current Status** (as of code review):
- Unit tests: 8/8 passed (100%)
- Integration tests: Not implemented (TODO)
- E2E tests: Not implemented (TODO)

**Gaps**:
- Missing unit tests for `/revoke` and `/status` handlers
- Missing integration tests for wg-easy API adapter
- No automated E2E tests (manual testing only)

---

## References

- **QA Test Report**: `.dev-docs/QA_TEST_REPORT.md`
- **Code Review**: `.dev-docs/CODE_REVIEW_REPORT.md`
- **pytest Documentation**: https://docs.pytest.org/
- **pytest-asyncio**: https://pytest-asyncio.readthedocs.io/
