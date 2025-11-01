"""Command handlers for VPN bot."""

from .start_handler import StartHandler
from .request_handler import RequestHandler
from .revoke_handler import RevokeHandler
from .status_handler import StatusHandler

# Table-driven dispatch (suckless pattern)
COMMAND_HANDLERS = {
    'start': StartHandler,
    'request': RequestHandler,
    'revoke': RevokeHandler,
    'status': StatusHandler,
}

__all__ = [
    'COMMAND_HANDLERS',
    'StartHandler',
    'RequestHandler',
    'RevokeHandler',
    'StatusHandler',
]
