"""Handler for /revoke command."""

import os
from telegram import Update
from telegram.ext import ContextTypes
from ..interfaces import IVPNProvider, IMessagingProvider, ILogSink


class RevokeHandler:
    """Handler for /revoke command."""

    def __init__(
        self,
        vpn: IVPNProvider,
        messaging: IMessagingProvider,
        logger: ILogSink
    ):
        self.vpn = vpn
        self.messaging = messaging
        self.logger = logger

    def _is_admin(self, user_id: int) -> bool:
        """Check if user is admin."""
        admin_list_str = os.getenv("BOT_ADMINS", "")
        if not admin_list_str:
            return False

        admins = [
            int(uid.strip())
            for uid in admin_list_str.split(",")
            if uid.strip()
        ]
        return user_id in admins

    def _validate_args(self, context) -> str:
        """Validate and extract client_id from args."""
        if not context.args or len(context.args) == 0:
            return ""
        return context.args[0]

    async def handle(
        self, update: Update, context: ContextTypes.DEFAULT_TYPE
    ) -> None:
        """Handle /revoke command."""
        chat_id = update.effective_chat.id
        user_id = update.effective_user.id

        # Early validation
        if not self._is_admin(user_id):
            self.logger.log("warn", f"Non-admin {user_id} tried /revoke")
            await self.messaging.send_message(
                chat_id,
                "❌ Только администраторы могут отзывать доступ."
            )
            return

        client_id = self._validate_args(context)
        if not client_id:
            await self.messaging.send_message(
                chat_id,
                "❌ Использование: /revoke <client_id>\n\n"
                "Используй /status для списка клиентов."
            )
            return

        try:
            success = self.vpn.delete_client(client_id)

            if success:
                self.logger.log(
                    "info",
                    f"Admin {user_id} revoked client {client_id}"
                )
                await self.messaging.send_message(
                    chat_id,
                    f"✅ Клиент {client_id} удален"
                )
            else:
                await self.messaging.send_message(
                    chat_id,
                    f"❌ Не удалось удалить клиента {client_id}"
                )

        except Exception as e:
            self.logger.log("error", f"Revoke failed: {e}")
            await self.messaging.send_message(chat_id, f"❌ Ошибка: {e}")
