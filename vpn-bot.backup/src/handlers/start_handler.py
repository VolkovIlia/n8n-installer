"""Handler for /start command."""

from telegram import Update
from telegram.ext import ContextTypes
from ..interfaces import IMessagingProvider, ILogSink


class StartHandler:
    """Handler for /start command."""

    def __init__(self, messaging: IMessagingProvider, logger: ILogSink):
        self.messaging = messaging
        self.logger = logger

    async def handle(
        self, update: Update, context: ContextTypes.DEFAULT_TYPE
    ) -> None:
        """Handle /start command."""
        chat_id = update.effective_chat.id
        user_id = update.effective_user.id

        self.logger.log("info", f"User {user_id} started bot")

        welcome_msg = (
            "🔐 VPN Bot для обхода гео-блокировок\n\n"
            "Доступные команды:\n"
            "/request - Получить VPN конфигурацию\n"
            "/status - Проверить статус VPN\n"
            "/revoke - Отозвать доступ\n\n"
            "Отправь /request для получения конфига."
        )

        await self.messaging.send_message(chat_id, welcome_msg)
