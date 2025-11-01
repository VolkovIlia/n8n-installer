"""QR code generator interface (adapter pattern)."""

from typing import Protocol


class IQRGenerator(Protocol):
    """Interface for QR code generation."""

    def generate(self, data: str) -> bytes:
        """Generate QR code PNG from text."""
        ...
