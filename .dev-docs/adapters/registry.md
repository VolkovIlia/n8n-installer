# VPN Integration - Adapter Registry (Hurd Translator Pattern)

## Overview

This document defines all adapters (translators in Hurd terminology) that connect external resources to the VPN system. Each adapter is **replaceable** without changing core services, following the Hurd `settrans` mount point concept.

**Philosophy**: External systems attach via narrow adapters conceptually like Hurd translators. Adapters are replaceable (mount/unmount) without changing core services.

---

## Adapter Pattern

```
Resource (external) ← Adapter (translator) → Interface (standard)
                            ↕
                      settrans (mount point)
                            ↕
                   Core Service (uses standard interface)
```

**Example**: Bot doesn't call `wg` CLI directly. Bot uses `IVPNProvider` interface → `WireGuardAPIAdapter` translates to wg-easy HTTP API → wg-easy calls `wg` CLI.

---

## Adapter Registry

| Resource | Adapter | Interface | Implementation | Replaceability |
|----------|---------|-----------|----------------|----------------|
| **wg-easy HTTP API** | WireGuardAPIAdapter | IVPNProvider | Bot (Python) | Can swap to native `wg` CLI adapter |
| **Telegram Bot API** | TelegramBotAdapter | IMessagingProvider | Bot (Python) | Can swap to Discord/Slack adapter |
| **Docker Containers** | DockerComposeAdapter | IContainerOrchestrator | install.sh | Can swap to Kubernetes adapter |
| **QR Code Generation** | QRCodeAdapter | IQRGenerator | Bot (Python qrcode lib) | Can swap to online QR service |
| **Environment Variables** | EnvFileAdapter | IConfigProvider | Bot + wg-easy | Can swap to Consul/etcd |
| **Logging** | StdoutAdapter | ILogSink | Bot + wg-easy | Can swap to Syslog/Loki |

---

## Adapter Details

### 1. WireGuardAPIAdapter

**Purpose**: Translate VPN operations to wg-easy HTTP API

**Resource**: wg-easy HTTP API (http://wg-easy:51821/api/)

**Interface**: `IVPNProvider`
```python
class IVPNProvider:
    def create_client(name: str) -> Client:
        """Create new VPN client, return config + QR code"""
        pass

    def delete_client(client_id: str) -> None:
        """Delete VPN client by ID"""
        pass

    def get_client(client_id: str) -> Client:
        """Get client details including stats"""
        pass

    def list_clients() -> List[Client]:
        """List all clients"""
        pass
```

**Implementation** (Bot: `adapters/wireguard_api.py`):
```python
class WireGuardAPIAdapter(IVPNProvider):
    def __init__(self, host: str, password: str):
        self.host = host  # wg-easy:51821
        self.password = password
        self.session_token = None

    def _ensure_session(self):
        """Lazy session creation"""
        if not self.session_token or self._is_expired():
            resp = requests.post(
                f"{self.host}/api/session",
                json={"password": self.password}
            )
            self.session_token = resp.json()["sessionToken"]

    def create_client(self, name: str) -> Client:
        self._ensure_session()
        resp = requests.post(
            f"{self.host}/api/wireguard/client",
            headers={"Authorization": f"Bearer {self.session_token}"},
            json={"name": name}
        )
        return Client.from_json(resp.json())

    # ... other methods
```

**Replaceability**: Swap to `WireGuardCLIAdapter` (direct `wg` commands):
```python
class WireGuardCLIAdapter(IVPNProvider):
    def create_client(self, name: str) -> Client:
        # Call: wg set wg0 peer {pubkey} ...
        # Parse output, return Client
        pass
```

**Mount Point**: Bot constructor (`bot.py`):
```python
# Current:
vpn_provider = WireGuardAPIAdapter(host="wg-easy:51821", password=os.getenv("WG_PASSWORD"))

# Alternative (if wg-easy removed):
vpn_provider = WireGuardCLIAdapter(interface="wg0")
```

---

### 2. TelegramBotAdapter

**Purpose**: Translate messaging operations to Telegram Bot API

**Resource**: Telegram Bot API (https://api.telegram.org/bot{token}/)

**Interface**: `IMessagingProvider`
```python
class IMessagingProvider:
    def send_text(user_id: int, text: str) -> None:
        """Send text message"""
        pass

    def send_photo(user_id: int, photo_data: bytes) -> None:
        """Send image"""
        pass

    def send_document(user_id: int, file_data: bytes, filename: str) -> None:
        """Send file"""
        pass

    def get_updates() -> List[Update]:
        """Poll for new messages"""
        pass
```

**Implementation** (Bot: `adapters/telegram_bot.py`):
```python
class TelegramBotAdapter(IMessagingProvider):
    def __init__(self, bot_token: str):
        self.bot = telegram.Bot(token=bot_token)

    def send_text(self, user_id: int, text: str) -> None:
        self.bot.send_message(chat_id=user_id, text=text)

    def send_photo(self, user_id: int, photo_data: bytes) -> None:
        self.bot.send_photo(chat_id=user_id, photo=photo_data)

    # ... other methods
```

**Replaceability**: Swap to `DiscordBotAdapter`:
```python
class DiscordBotAdapter(IMessagingProvider):
    def __init__(self, bot_token: str):
        self.bot = discord.Client(token=bot_token)

    def send_text(self, user_id: int, text: str) -> None:
        channel = self.bot.get_channel(user_id)
        channel.send(text)

    # ... other methods (same interface)
```

**Mount Point**: Bot constructor (`bot.py`):
```python
# Current:
messaging = TelegramBotAdapter(bot_token=os.getenv("BOT_TOKEN"))

# Alternative (if Telegram blocked):
messaging = DiscordBotAdapter(bot_token=os.getenv("DISCORD_BOT_TOKEN"))
```

---

### 3. DockerComposeAdapter

**Purpose**: Translate container operations to Docker Compose commands

**Resource**: Docker Compose CLI (`docker-compose` or `docker compose`)

**Interface**: `IContainerOrchestrator`
```bash
# Conceptual interface (shell script)
create_service(service_name, image, ports, volumes, env)
start_service(service_name)
stop_service(service_name)
remove_service(service_name)
```

**Implementation** (install.sh):
```bash
create_vpn_services() {
    # Append to docker-compose.yml
    cat >> docker-compose.yml <<EOF
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:latest
    ...
  vpnTelegram:
    image: vpn-telegram-bot:latest
    ...
EOF
}

start_vpn_services() {
    docker-compose up -d wg-easy vpnTelegram
}
```

**Replaceability**: Swap to `KubernetesAdapter`:
```bash
create_vpn_services() {
    # Generate Kubernetes YAML
    kubectl apply -f vpn-deployment.yaml
}

start_vpn_services() {
    kubectl rollout status deployment/wg-easy
    kubectl rollout status deployment/vpn-telegram
}
```

**Mount Point**: install.sh chooses adapter based on ENV var:
```bash
if [ "$ORCHESTRATOR" = "kubernetes" ]; then
    source adapters/kubernetes.sh
else
    source adapters/docker-compose.sh
fi

create_vpn_services  # Calls chosen adapter
```

---

### 4. QRCodeAdapter

**Purpose**: Translate WireGuard config to QR code image

**Resource**: Python `qrcode` library

**Interface**: `IQRGenerator`
```python
class IQRGenerator:
    def generate(config_text: str) -> bytes:
        """Generate QR code PNG from text"""
        pass
```

**Implementation** (Bot: `adapters/qr_code.py`):
```python
class QRCodeAdapter(IQRGenerator):
    def generate(self, config_text: str) -> bytes:
        import qrcode
        img = qrcode.make(config_text)
        buf = io.BytesIO()
        img.save(buf, format='PNG')
        return buf.getvalue()
```

**Replaceability**: Swap to `OnlineQRServiceAdapter`:
```python
class OnlineQRServiceAdapter(IQRGenerator):
    def generate(self, config_text: str) -> bytes:
        # Call external API: https://api.qrserver.com/v1/create-qr-code/
        resp = requests.get(
            "https://api.qrserver.com/v1/create-qr-code/",
            params={"data": config_text, "size": "500x500"}
        )
        return resp.content
```

**Mount Point**: Bot constructor (`bot.py`):
```python
# Current:
qr_generator = QRCodeAdapter()

# Alternative (if qrcode lib removed):
qr_generator = OnlineQRServiceAdapter(api_key=os.getenv("QR_API_KEY"))
```

---

### 5. EnvFileAdapter

**Purpose**: Translate configuration reads to .env file access

**Resource**: .env file (`/path/to/.env`)

**Interface**: `IConfigProvider`
```python
class IConfigProvider:
    def get(key: str, default: str = None) -> str:
        """Get config value by key"""
        pass

    def set(key: str, value: str) -> None:
        """Set config value (write to storage)"""
        pass
```

**Implementation** (Bot: `adapters/env_file.py`):
```python
class EnvFileAdapter(IConfigProvider):
    def __init__(self, env_path: str = ".env"):
        self.env_path = env_path
        self._load_env()

    def _load_env(self):
        from dotenv import load_dotenv
        load_dotenv(self.env_path)

    def get(self, key: str, default: str = None) -> str:
        return os.getenv(key, default)

    def set(self, key: str, value: str) -> None:
        # Append to .env file
        with open(self.env_path, "a") as f:
            f.write(f"{key}={value}\n")
```

**Replaceability**: Swap to `ConsulAdapter` (distributed config):
```python
class ConsulAdapter(IConfigProvider):
    def __init__(self, consul_host: str):
        self.consul = consul.Consul(host=consul_host)

    def get(self, key: str, default: str = None) -> str:
        _, data = self.consul.kv.get(key)
        return data['Value'].decode() if data else default

    def set(self, key: str, value: str) -> None:
        self.consul.kv.put(key, value)
```

**Mount Point**: Bot constructor (`bot.py`):
```python
# Current:
config = EnvFileAdapter(env_path=".env")

# Alternative (if using Consul):
config = ConsulAdapter(consul_host="consul:8500")

# Usage (same interface):
bot_token = config.get("BOT_TOKEN")
```

---

### 6. StdoutAdapter

**Purpose**: Translate log writes to stdout (Docker captures)

**Resource**: stdout stream

**Interface**: `ILogSink`
```python
class ILogSink:
    def log(level: str, message: str) -> None:
        """Write log entry"""
        pass
```

**Implementation** (Bot: `adapters/stdout_logger.py`):
```python
class StdoutAdapter(ILogSink):
    def log(self, level: str, message: str) -> None:
        timestamp = datetime.now().isoformat()
        print(f"[{timestamp}] {level.upper()}: {message}")
```

**Replaceability**: Swap to `LokiAdapter` (centralized logging):
```python
class LokiAdapter(ILogSink):
    def __init__(self, loki_url: str):
        self.loki_url = loki_url

    def log(self, level: str, message: str) -> None:
        requests.post(
            f"{self.loki_url}/loki/api/v1/push",
            json={
                "streams": [{
                    "stream": {"level": level, "app": "vpn-bot"},
                    "values": [[str(int(time.time() * 1e9)), message]]
                }]
            }
        )
```

**Mount Point**: Bot constructor (`bot.py`):
```python
# Current:
logger = StdoutAdapter()

# Alternative (if using Loki):
logger = LokiAdapter(loki_url="http://loki:3100")

# Usage (same interface):
logger.log("info", "User 123456 requested VPN config")
```

---

## Adapter Replaceability Matrix

| Adapter | Current Resource | Alternative 1 | Alternative 2 | Effort to Swap |
|---------|------------------|---------------|---------------|----------------|
| **WireGuardAPIAdapter** | wg-easy HTTP API | Native `wg` CLI | Custom Python wrapper | 2 days |
| **TelegramBotAdapter** | Telegram Bot API | Discord bot | Slack bot | 1 day |
| **DockerComposeAdapter** | Docker Compose CLI | Kubernetes YAML | Nomad HCL | 3 days |
| **QRCodeAdapter** | Python qrcode lib | Online QR service | Rust qr-code lib | 0.5 days |
| **EnvFileAdapter** | .env file | Consul KV | etcd | 1 day |
| **StdoutAdapter** | stdout | Loki | Syslog | 0.5 days |

---

## Adapter Lifecycle (Hurd `settrans` Analogy)

### 1. Mount Adapter (Initialization)

```python
# Bot startup (bot.py)
def main():
    # Mount adapters (like settrans in Hurd)
    config = EnvFileAdapter(env_path=".env")
    vpn_provider = WireGuardAPIAdapter(
        host=config.get("WG_HOST"),
        password=config.get("WG_PASSWORD")
    )
    messaging = TelegramBotAdapter(bot_token=config.get("BOT_TOKEN"))
    qr_generator = QRCodeAdapter()
    logger = StdoutAdapter()

    # Core service uses adapters via interfaces
    bot_service = VPNBotService(
        vpn=vpn_provider,
        messaging=messaging,
        qr=qr_generator,
        log=logger
    )

    bot_service.start()
```

### 2. Use Adapter (Runtime)

```python
# Bot command handler (handlers/request.py)
def handle_request(bot_service, user_id, device_name=None):
    # Core logic doesn't know about Telegram or wg-easy specifics
    # It only uses interfaces

    # Log via ILogSink (could be stdout, Loki, or anything)
    bot_service.log.log("info", f"User {user_id} requested config")

    # Create client via IVPNProvider (could be wg-easy API or wg CLI)
    client = bot_service.vpn.create_client(name=f"user_{user_id}_{int(time.time())}")

    # Generate QR via IQRGenerator (could be qrcode lib or online service)
    qr_image = bot_service.qr.generate(client.configuration)

    # Send via IMessagingProvider (could be Telegram or Discord)
    bot_service.messaging.send_photo(user_id, qr_image)
    bot_service.messaging.send_document(user_id, client.configuration, f"{client.name}.conf")
```

### 3. Unmount Adapter (Cleanup)

```python
# Bot shutdown (bot.py)
def shutdown(bot_service):
    # Cleanup adapters if needed
    bot_service.vpn.close()  # Close wg-easy API session
    bot_service.messaging.close()  # Close Telegram connection
    # No cleanup needed for qr_generator or logger (stateless)
```

### 4. Swap Adapter (Hot Swap)

```python
# Swap at runtime (e.g., if Telegram blocked)
def switch_to_discord(bot_service, discord_token):
    # Unmount old adapter
    bot_service.messaging.close()

    # Mount new adapter (same interface)
    bot_service.messaging = DiscordBotAdapter(bot_token=discord_token)

    # Bot continues working (handlers use IMessagingProvider interface)
```

---

## Adapter Integration with Existing n8n-installer

### Tool Mapping (Existing Platform Adapters)

n8n-installer already has `config/tool-mapping.yaml` (if using deadlion-studio). This is the Hurd translator registry!

**Example Extension**:
```yaml
# config/tool-mapping.yaml (conceptual - n8n-installer doesn't have this yet)
platform_adapters:
  vpn:
    provider:
      interface: IVPNProvider
      implementations:
        wireguard_api:
          adapter: WireGuardAPIAdapter
          resource: wg-easy HTTP API
          status: active
        wireguard_cli:
          adapter: WireGuardCLIAdapter
          resource: Native wg command
          status: alternative

  messaging:
    provider:
      interface: IMessagingProvider
      implementations:
        telegram:
          adapter: TelegramBotAdapter
          resource: Telegram Bot API
          status: active
        discord:
          adapter: DiscordBotAdapter
          resource: Discord API
          status: alternative
```

---

## Adapter Testing Strategy

### 1. Mock Adapters (for unit tests)

```python
class MockVPNProvider(IVPNProvider):
    """Mock adapter for testing bot logic without wg-easy"""
    def __init__(self):
        self.clients = {}

    def create_client(self, name: str) -> Client:
        client = Client(id=uuid.uuid4(), name=name, address="10.8.0.2")
        self.clients[client.id] = client
        return client

    # ... other methods return mock data
```

### 2. Adapter Contract Tests

```python
# tests/adapters/test_wireguard_api.py
def test_adapter_contract():
    """Verify adapter implements IVPNProvider interface"""
    adapter = WireGuardAPIAdapter(host="test", password="test")

    # Test interface methods exist
    assert callable(adapter.create_client)
    assert callable(adapter.delete_client)
    assert callable(adapter.get_client)
    assert callable(adapter.list_clients)

    # Test return types match interface
    client = adapter.create_client("test_client")
    assert isinstance(client, Client)
```

### 3. Integration Tests (with real wg-easy)

```python
# tests/integration/test_wireguard_integration.py
def test_real_wg_easy_api():
    """Test against real wg-easy container"""
    adapter = WireGuardAPIAdapter(
        host="localhost:51821",
        password=os.getenv("TEST_WG_PASSWORD")
    )

    # Create client via adapter
    client = adapter.create_client("integration_test")
    assert client.name == "integration_test"
    assert client.address.startswith("10.8.0.")

    # Cleanup
    adapter.delete_client(client.id)
```

---

## Adapter Documentation (for Engineers)

**When implementing new adapter**:

1. **Define interface** (if new resource type):
   ```python
   # interfaces/i_vpn_provider.py
   class IVPNProvider:
       def create_client(name: str) -> Client:
           """Create new VPN client, return config + QR code"""
           raise NotImplementedError
   ```

2. **Implement adapter**:
   ```python
   # adapters/wireguard_api.py
   class WireGuardAPIAdapter(IVPNProvider):
       def create_client(self, name: str) -> Client:
           # Implementation here
   ```

3. **Add to registry** (this document):
   - Update Adapter Registry table
   - Add Adapter Details section
   - Document replaceability

4. **Write tests**:
   - Contract test (interface compliance)
   - Unit test (with mocks)
   - Integration test (optional)

5. **Update mount point** (bot.py or install.sh):
   - Document where adapter is instantiated
   - Show how to swap to alternative

---

## References

- **GNU Hurd Translators**: https://www.gnu.org/software/hurd/hurd/translator.html
- **Adapter Pattern**: https://refactoring.guru/design-patterns/adapter
- **Dependency Injection**: https://en.wikipedia.org/wiki/Dependency_injection
- **Interface Segregation Principle**: https://en.wikipedia.org/wiki/Interface_segregation_principle
