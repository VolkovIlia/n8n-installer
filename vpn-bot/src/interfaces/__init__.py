"""Interface definitions for VPN bot adapters."""

from .i_vpn_provider import IVPNProvider, Client
from .i_messaging_provider import IMessagingProvider
from .i_qr_generator import IQRGenerator
from .i_log_sink import ILogSink

__all__ = [
    'IVPNProvider',
    'Client',
    'IMessagingProvider',
    'IQRGenerator',
    'ILogSink',
]
