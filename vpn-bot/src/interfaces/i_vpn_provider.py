"""VPN provider interface (adapter pattern)."""

from dataclasses import dataclass
from typing import Protocol


@dataclass
class Client:
    """WireGuard client data."""
    id: str
    name: str
    address: str
    public_key: str
    configuration: str
    enabled: bool = True


class IVPNProvider(Protocol):
    """Interface for VPN client management."""

    def create_client(self, name: str) -> Client:
        """Create new VPN client, return config."""
        ...

    def delete_client(self, client_id: str) -> bool:
        """Delete VPN client by ID."""
        ...

    def get_client(self, client_id: str) -> Client:
        """Get client details including stats."""
        ...

    def list_clients(self) -> list[Client]:
        """List all clients."""
        ...
