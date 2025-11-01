"""Stdout logging adapter."""

from datetime import datetime
from ..interfaces import ILogSink


class StdoutAdapter:
    """Adapter for stdout logging."""

    def log(self, level: str, message: str) -> None:
        """Write log entry to stdout."""
        timestamp = datetime.now().isoformat()
        print(f"[{timestamp}] {level.upper()}: {message}")
