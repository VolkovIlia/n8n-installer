"""Adapter implementations for VPN bot."""

from .wireguard_api_adapter import WireGuardAPIAdapter
from .telegram_bot_adapter import TelegramBotAdapter
from .qr_code_adapter import QRCodeAdapter
from .stdout_adapter import StdoutAdapter

__all__ = [
    'WireGuardAPIAdapter',
    'TelegramBotAdapter',
    'QRCodeAdapter',
    'StdoutAdapter',
]
