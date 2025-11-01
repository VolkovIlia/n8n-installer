"""Handler for /status command."""

from telegram import Update
from telegram.ext import ContextTypes
from ..interfaces import IVPNProvider, IMessagingProvider, ILogSink


class StatusHandler:
    """Handler for /status command."""

    def __init__(
        self,
        vpn: IVPNProvider,
        messaging: IMessagingProvider,
        logger: ILogSink
    ):
        self.vpn = vpn
        self.messaging = messaging
        self.logger = logger

    async def handle(
        self, update: Update, context: ContextTypes.DEFAULT_TYPE
    ) -> None:
        """Handle /status command."""
        chat_id = update.effective_chat.id
        user_id = update.effective_user.id

        self.logger.log("info", f"User {user_id} requested status")

        try:
            clients = self.vpn.list_clients()

            if not clients:
                await self.messaging.send_message(
                    chat_id,
                    "📊 Нет активных VPN клиентов"
                )
                return

            # Format client list
            status_msg = "📊 Активные VPN клиенты:\n\n"
            for idx, client in enumerate(clients, 1):
                status_icon = "✅" if client.enabled else "❌"
                status_msg += (
                    f"{idx}. {status_icon} {client.name}\n"
                    f"   ID: {client.id[:8]}...\n"
                    f"   IP: {client.address}\n\n"
                )

            await self.messaging.send_message(chat_id, status_msg)

        except Exception as e:
            self.logger.log("error", f"Status check failed: {e}")
            await self.messaging.send_message(
                chat_id,
                f"❌ Ошибка получения статуса: {e}"
            )
