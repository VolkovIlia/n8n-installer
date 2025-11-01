"""Unit tests for command handlers."""

import pytest
from unittest.mock import Mock, AsyncMock
from src.handlers import StartHandler, RequestHandler
from src.interfaces import Client


@pytest.mark.asyncio
async def test_start_handler_sends_welcome():
    """Start handler sends welcome message."""
    messaging = Mock()
    messaging.send_message = AsyncMock()
    logger = Mock()

    handler = StartHandler(messaging, logger)

    update = Mock()
    update.effective_chat.id = 12345
    update.effective_user.id = 67890

    await handler.handle(update, None)

    messaging.send_message.assert_called_once()
    call_args = messaging.send_message.call_args
    assert call_args[0][0] == 12345  # chat_id
    assert "VPN Bot" in call_args[0][1]  # message text


@pytest.mark.asyncio
async def test_request_handler_creates_vpn_config():
    """Request handler creates VPN config."""
    vpn = Mock()
    vpn.create_client.return_value = Client(
        id="client-123",
        name="test_user_1234567890",
        address="10.8.0.2",
        public_key="test_key",
        configuration="[Interface]\nPrivateKey=...",
        enabled=True
    )

    messaging = Mock()
    messaging.send_document = AsyncMock()
    messaging.send_photo = AsyncMock()
    messaging.send_message = AsyncMock()

    qr = Mock()
    qr.generate.return_value = b"fake_qr_png_data"

    logger = Mock()

    handler = RequestHandler(vpn, messaging, qr, logger)

    update = Mock()
    update.effective_chat.id = 12345
    update.effective_user.id = 67890
    update.effective_user.username = "test_user"

    await handler.handle(update, None)

    # Verify VPN client created
    vpn.create_client.assert_called_once()

    # Verify QR generated
    qr.generate.assert_called_once()

    # Verify messages sent
    messaging.send_document.assert_called_once()
    messaging.send_photo.assert_called_once()
    messaging.send_message.assert_called_once()


@pytest.mark.asyncio
async def test_request_handler_unauthorized_user():
    """Request handler rejects unauthorized user."""
    vpn = Mock()
    messaging = Mock()
    messaging.send_message = AsyncMock()
    qr = Mock()
    logger = Mock()

    handler = RequestHandler(vpn, messaging, qr, logger)

    # Mock whitelist check
    with pytest.MonkeyPatch.context() as m:
        m.setenv("BOT_WHITELIST", "11111,22222")

        update = Mock()
        update.effective_chat.id = 12345
        update.effective_user.id = 99999  # Not in whitelist

        await handler.handle(update, None)

        # Should not create client
        vpn.create_client.assert_not_called()

        # Should send error message
        messaging.send_message.assert_called_once()
        call_args = messaging.send_message.call_args
        assert "нет доступа" in call_args[0][1].lower()
