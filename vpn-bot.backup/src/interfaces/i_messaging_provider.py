"""Messaging provider interface (adapter pattern)."""

from typing import Protocol


class IMessagingProvider(Protocol):
    """Interface for messaging operations."""

    async def send_message(self, chat_id: int, text: str) -> None:
        """Send text message."""
        ...

    async def send_photo(self, chat_id: int, photo: bytes) -> None:
        """Send image."""
        ...

    async def send_document(
        self, chat_id: int, file_data: bytes, filename: str
    ) -> None:
        """Send file."""
        ...
