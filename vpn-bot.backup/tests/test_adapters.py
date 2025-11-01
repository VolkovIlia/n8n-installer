"""Unit tests for adapters."""

import pytest
from unittest.mock import Mock, patch
from src.adapters import QRCodeAdapter, WireGuardAPIAdapter


def test_qr_code_adapter_generates_bytes():
    """QR adapter returns PNG bytes."""
    adapter = QRCodeAdapter()
    result = adapter.generate("test data")

    assert isinstance(result, bytes)
    assert len(result) > 0
    # PNG signature
    assert result[:8] == b'\x89PNG\r\n\x1a\n'


def test_qr_code_adapter_different_inputs():
    """QR adapter handles different inputs."""
    adapter = QRCodeAdapter()

    qr1 = adapter.generate("short")
    qr2 = adapter.generate("long data" * 100)

    assert len(qr1) > 0
    assert len(qr2) > 0
    assert qr1 != qr2  # Different data = different QR


@patch('src.adapters.wireguard_api_adapter.requests.post')
def test_wireguard_adapter_session_creation(mock_post):
    """WireGuard adapter creates session."""
    mock_post.return_value = Mock(
        status_code=200,
        json=lambda: {"sessionToken": "test_token"}
    )

    adapter = WireGuardAPIAdapter("http://test:51821", "password")
    adapter._ensure_session()

    assert adapter.session_token == "test_token"
    mock_post.assert_called_once()


@patch('src.adapters.wireguard_api_adapter.requests.post')
def test_wireguard_adapter_create_client(mock_post):
    """WireGuard adapter creates client."""
    # Mock session creation
    mock_post.return_value = Mock(
        status_code=200,
        json=lambda: {"sessionToken": "test_token"}
    )

    adapter = WireGuardAPIAdapter("http://test:51821", "password")

    # Mock client creation
    with patch('src.adapters.wireguard_api_adapter.requests.get') as mock_get:
        mock_post.return_value = Mock(
            status_code=201,
            json=lambda: {
                "id": "client-123",
                "name": "test_client",
                "address": "10.8.0.2",
                "publicKey": "test_key",
                "enabled": True
            }
        )
        mock_get.return_value = Mock(
            status_code=200,
            text="[Interface]\nPrivateKey=..."
        )

        client = adapter.create_client("test_client")

        assert client.name == "test_client"
        assert client.address == "10.8.0.2"
        assert client.configuration != ""


@patch('src.adapters.wireguard_api_adapter.requests.post')
@patch('src.adapters.wireguard_api_adapter.requests.delete')
def test_wireguard_adapter_delete_client(mock_delete, mock_post):
    """WireGuard adapter deletes client."""
    # Mock session
    mock_post.return_value = Mock(
        status_code=200,
        json=lambda: {"sessionToken": "test_token"}
    )

    adapter = WireGuardAPIAdapter("http://test:51821", "password")

    # Mock delete
    mock_delete.return_value = Mock(status_code=204)

    result = adapter.delete_client("client-123")

    assert result is True
    mock_delete.assert_called_once()
