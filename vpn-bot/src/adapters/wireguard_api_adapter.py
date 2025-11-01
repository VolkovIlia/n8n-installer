"""WireGuard API adapter (wg-easy HTTP API)."""

import sys
import requests
from typing import Optional
from ..interfaces import IVPNProvider, Client


class WireGuardAPIAdapter:
    """Adapter for wg-easy HTTP API."""

    def __init__(self, base_url: str, password: str):
        self.base_url = base_url.rstrip('/')
        self.password = password
        self.session_token: Optional[str] = None

    def _ensure_session(self) -> None:
        """Lazy session creation (early return pattern)."""
        if self.session_token:
            return

        # Create session
        try:
            resp = requests.post(
                f"{self.base_url}/api/session",
                json={"password": self.password},
                timeout=10
            )
            if resp.status_code != 200:
                print(
                    f"ERROR: auth failed: {resp.status_code}",
                    file=sys.stderr
                )
                return

            data = resp.json()
            self.session_token = data.get("sessionToken")

        except Exception as e:
            print(f"ERROR: session create failed: {e}", file=sys.stderr)

    def _headers(self) -> dict:
        """Get auth headers."""
        self._ensure_session()
        return {"Authorization": f"Bearer {self.session_token}"}

    def _get_client_config(self, client_id: str) -> str:
        """Fetch client configuration."""
        resp = requests.get(
            f"{self.base_url}/api/wireguard/client/{client_id}/configuration",
            headers=self._headers(),
            timeout=10
        )
        return resp.text if resp.status_code == 200 else ""

    def _client_from_data(self, data: dict, config: str = "") -> Client:
        """Build Client object from API response."""
        return Client(
            id=data["id"],
            name=data["name"],
            address=data["address"],
            public_key=data["publicKey"],
            configuration=config,
            enabled=data.get("enabled", True)
        )

    def create_client(self, name: str) -> Client:
        """Create new VPN client."""
        # Validate input (early return)
        if not name:
            print("ERROR: client name empty", file=sys.stderr)
            raise ValueError("name required")

        try:
            resp = requests.post(
                f"{self.base_url}/api/wireguard/client",
                headers=self._headers(),
                json={"name": name},
                timeout=10
            )

            if resp.status_code == 401:
                # Session expired, retry once
                self.session_token = None
                self._ensure_session()
                resp = requests.post(
                    f"{self.base_url}/api/wireguard/client",
                    headers=self._headers(),
                    json={"name": name},
                    timeout=10
                )

            if resp.status_code != 201:
                print(
                    f"ERROR: client create failed: {resp.status_code}",
                    file=sys.stderr
                )
                raise ValueError(f"create failed: {resp.status_code}")

            data = resp.json()
            config = self._get_client_config(data["id"])
            return self._client_from_data(data, config)

        except Exception as e:
            print(f"ERROR: create client failed: {e}", file=sys.stderr)
            raise

    def delete_client(self, client_id: str) -> bool:
        """Delete VPN client."""
        if not client_id:
            print("ERROR: client_id empty", file=sys.stderr)
            return False

        try:
            resp = requests.delete(
                f"{self.base_url}/api/wireguard/client/{client_id}",
                headers=self._headers(),
                timeout=10
            )

            if resp.status_code == 401:
                # Retry with fresh session
                self.session_token = None
                self._ensure_session()
                resp = requests.delete(
                    f"{self.base_url}/api/wireguard/client/{client_id}",
                    headers=self._headers(),
                    timeout=10
                )

            if resp.status_code not in (204, 200):
                print(
                    f"ERROR: delete failed: {resp.status_code}",
                    file=sys.stderr
                )
                return False

            return True

        except Exception as e:
            print(f"ERROR: delete client failed: {e}", file=sys.stderr)
            return False

    def get_client(self, client_id: str) -> Client:
        """Get client details."""
        if not client_id:
            print("ERROR: client_id empty", file=sys.stderr)
            raise ValueError("client_id required")

        try:
            resp = requests.get(
                f"{self.base_url}/api/wireguard/client/{client_id}",
                headers=self._headers(),
                timeout=10
            )

            if resp.status_code == 401:
                self.session_token = None
                self._ensure_session()
                resp = requests.get(
                    f"{self.base_url}/api/wireguard/client/{client_id}",
                    headers=self._headers(),
                    timeout=10
                )

            if resp.status_code != 200:
                print(
                    f"ERROR: get client failed: {resp.status_code}",
                    file=sys.stderr
                )
                raise ValueError(f"get failed: {resp.status_code}")

            data = resp.json()
            config = self._get_client_config(client_id)
            return self._client_from_data(data, config)

        except Exception as e:
            print(f"ERROR: get client failed: {e}", file=sys.stderr)
            raise

    def list_clients(self) -> list[Client]:
        """List all clients."""
        try:
            resp = requests.get(
                f"{self.base_url}/api/wireguard/client",
                headers=self._headers(),
                timeout=10
            )

            if resp.status_code == 401:
                self.session_token = None
                self._ensure_session()
                resp = requests.get(
                    f"{self.base_url}/api/wireguard/client",
                    headers=self._headers(),
                    timeout=10
                )

            if resp.status_code != 200:
                print(
                    f"ERROR: list failed: {resp.status_code}",
                    file=sys.stderr
                )
                return []

            data = resp.json()
            return [
                Client(
                    id=c["id"],
                    name=c["name"],
                    address=c["address"],
                    public_key=c["publicKey"],
                    configuration="",  # Not included in list
                    enabled=c.get("enabled", True)
                )
                for c in data
            ]

        except Exception as e:
            print(f"ERROR: list clients failed: {e}", file=sys.stderr)
            return []
