"""Telegram Bot API adapter."""

import io
from telegram import Bot
from ..interfaces import IMessagingProvider


class TelegramBotAdapter:
    """Adapter for Telegram Bot API."""

    def __init__(self, bot_token: str):
        self.bot = Bot(token=bot_token)

    async def send_message(self, chat_id: int, text: str) -> None:
        """Send text message."""
        await self.bot.send_message(chat_id=chat_id, text=text)

    async def send_photo(self, chat_id: int, photo: bytes) -> None:
        """Send image."""
        photo_file = io.BytesIO(photo)
        await self.bot.send_photo(chat_id=chat_id, photo=photo_file)

    async def send_document(
        self, chat_id: int, file_data: bytes, filename: str
    ) -> None:
        """Send file."""
        document = io.BytesIO(file_data)
        document.name = filename
        await self.bot.send_document(
            chat_id=chat_id,
            document=document,
            filename=filename
        )
