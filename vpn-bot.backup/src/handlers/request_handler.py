"""Handler for /request command."""

import os
import sys
import time
from telegram import Update
from telegram.ext import ContextTypes
from ..interfaces import (
    IVPNProvider,
    IMessagingProvider,
    IQRGenerator,
    ILogSink
)


class RequestHandler:
    """Handler for /request command - generates VPN config."""

    def __init__(
        self,
        vpn: IVPNProvider,
        messaging: IMessagingProvider,
        qr: IQRGenerator,
        logger: ILogSink
    ):
        self.vpn = vpn
        self.messaging = messaging
        self.qr = qr
        self.logger = logger

    def _is_authorized(self, user_id: int) -> bool:
        """Check if user is authorized (whitelist)."""
        whitelist_str = os.getenv("BOT_WHITELIST", "")
        if not whitelist_str:
            return True  # No whitelist = allow all

        whitelist = [
            int(uid.strip())
            for uid in whitelist_str.split(",")
            if uid.strip()
        ]
        return user_id in whitelist

    async def _send_success_messages(
        self, chat_id: int, client_name: str, config: str, qr_bytes: bytes
    ) -> None:
        """Send VPN config to user."""
        await self.messaging.send_document(
            chat_id, config.encode('utf-8'), f"{client_name}.conf"
        )
        await self.messaging.send_photo(chat_id, qr_bytes)
        await self.messaging.send_message(
            chat_id,
            "✅ VPN конфигурация создана!\n\n"
            "1. Скачай .conf файл ИЛИ отсканируй QR код\n"
            "2. Импортируй в WireGuard приложение\n"
            "3. Подключись к VPN\n\n"
            f"Имя клиента: {client_name}"
        )

    async def handle(
        self, update: Update, context: ContextTypes.DEFAULT_TYPE
    ) -> None:
        """Handle /request command."""
        chat_id = update.effective_chat.id
        user_id = update.effective_user.id
        username = update.effective_user.username or f"user_{user_id}"

        # Early validation (suckless pattern)
        if not self._is_authorized(user_id):
            self.logger.log("warn", f"Unauthorized user {user_id}")
            await self.messaging.send_message(
                chat_id,
                "❌ У вас нет доступа. Обратитесь к администратору."
            )
            return

        self.logger.log("info", f"User {user_id} requested VPN config")

        try:
            client_name = f"{username}_{int(time.time())}"
            client = self.vpn.create_client(name=client_name)
            qr_bytes = self.qr.generate(client.configuration)

            await self._send_success_messages(
                chat_id, client.name, client.configuration, qr_bytes
            )
            self.logger.log("info", f"Client {client.name} created")

        except Exception as e:
            self.logger.log("error", f"Failed to create VPN client: {e}")
            print(f"ERROR: VPN client creation failed: {e}", file=sys.stderr)
            await self.messaging.send_message(
                chat_id,
                f"❌ Ошибка создания VPN: {e}\n\n"
                "Попробуй позже или обратись к администратору."
            )
