"""Logging interface (adapter pattern)."""

from typing import Protocol


class ILogSink(Protocol):
    """Interface for log output."""

    def log(self, level: str, message: str) -> None:
        """Write log entry."""
        ...
