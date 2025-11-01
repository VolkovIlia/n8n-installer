# MCP Server Design - VPN Integration (STRETCH v2.0)

## Overview

**Status**: STRETCH feature for v2.0+

This document defines the Model Context Protocol (MCP) server design for VPN integration. MCP enables agents to introspect, control, and test the VPN system programmatically.

**Goal**: Allow Claude Code agents and other MCP clients to monitor health, discover contracts, control services, and run tests without manual intervention.

---

## MCP Server Architecture

**Server Location**: New container `vpn-mcp-server`

**Implementation**: Python FastAPI (lightweight, OpenAPI auto-generated)

**Base URL**: `http://vpn-mcp-server:8080`

**Authentication**: JWT capability tokens (see `.dev-docs/capabilities/security-model.md`)

---

## 1. Health & Logs Endpoints

### GET /health

**Description**: Check liveness and readiness of VPN services

**Authentication**: None (public endpoint)

**Request**: None

**Response**:
```json
{
  "status": "healthy",
  "timestamp": "2025-11-01T12:00:00Z",
  "services": [
    {
      "name": "wg-easy",
      "status": "healthy",
      "uptime_seconds": 86400,
      "last_check": "2025-11-01T11:59:30Z"
    },
    {
      "name": "vpnTelegram",
      "status": "healthy",
      "uptime_seconds": 86400,
      "last_check": "2025-11-01T11:59:45Z"
    }
  ],
  "overall_health": "healthy"
}
```

**Status Values**:
- `healthy` - All services running, health checks passing
- `degraded` - One service unhealthy, others functional
- `down` - All services unhealthy or unreachable

**Implementation**:
```python
@app.get("/health")
async def health_check():
    services = []

    # Check wg-easy
    try:
        resp = requests.get("http://wg-easy:51821/", timeout=5)
        wg_status = "healthy" if resp.status_code == 200 else "unhealthy"
    except:
        wg_status = "down"

    services.append({
        "name": "wg-easy",
        "status": wg_status,
        "uptime_seconds": get_container_uptime("wg-easy"),
        "last_check": datetime.now().isoformat()
    })

    # Check bot (process alive via Docker API)
    bot_status = "healthy" if is_container_running("vpnTelegram") else "down"
    services.append({
        "name": "vpnTelegram",
        "status": bot_status,
        "uptime_seconds": get_container_uptime("vpnTelegram"),
        "last_check": datetime.now().isoformat()
    })

    # Overall health
    overall = "healthy"
    if any(s["status"] == "down" for s in services):
        overall = "down"
    elif any(s["status"] == "unhealthy" for s in services):
        overall = "degraded"

    return {
        "status": overall,
        "timestamp": datetime.now().isoformat(),
        "services": services,
        "overall_health": overall
    }
```

---

### GET /logs/tail

**Description**: Stream recent logs from VPN services

**Authentication**: Requires token with scope `logs:read`

**Query Parameters**:
- `lines` (optional, default=100): Number of lines to return
- `level` (optional, default=all): Filter by log level (error, warn, info, debug)
- `service` (optional, default=all): Filter by service (wg-easy, vpnTelegram)
- `redact` (optional, default=true): Redact sensitive data (tokens, passwords)

**Request**:
```
GET /logs/tail?lines=50&level=error&service=vpnTelegram&redact=true
Authorization: Bearer eyJhbGc...
```

**Response**:
```json
{
  "logs": [
    {
      "timestamp": "2025-11-01T12:00:00Z",
      "level": "error",
      "service": "vpnTelegram",
      "message": "Failed to connect to wg-easy API: Connection refused",
      "metadata": {
        "user_id": 123456,
        "command": "/request"
      }
    }
  ],
  "total_lines": 50,
  "redacted": true
}
```

**Implementation**:
```python
@app.get("/logs/tail")
async def tail_logs(
    lines: int = 100,
    level: str = "all",
    service: str = "all",
    redact: bool = True,
    token: str = Depends(verify_token)
):
    # Verify token scope
    if "logs:read" not in token["scope"]:
        raise HTTPException(403, "Insufficient scope")

    # Get logs from Docker containers
    logs = []
    services_to_check = ["wg-easy", "vpnTelegram"] if service == "all" else [service]

    for svc in services_to_check:
        container_logs = docker_client.containers.get(svc).logs(
            tail=lines,
            timestamps=True
        ).decode().split("\n")

        for log_line in container_logs:
            parsed = parse_log_line(log_line)
            if level != "all" and parsed["level"] != level:
                continue

            if redact:
                parsed["message"] = redact_secrets(parsed["message"])

            logs.append(parsed)

    return {
        "logs": logs[:lines],
        "total_lines": len(logs),
        "redacted": redact
    }

def redact_secrets(message: str) -> str:
    """Redact BOT_TOKEN, WG_PASSWORD, session tokens"""
    message = re.sub(r'\d{8,10}:[A-Za-z0-9_-]{35}', '[BOT_TOKEN]', message)
    message = re.sub(r'password["\s:=]+[^\s"]+', 'password=[REDACTED]', message, flags=re.IGNORECASE)
    return message
```

---

## 2. Contract Discovery Endpoints

### GET /contracts

**Description**: List all available API contracts (IDL schemas)

**Authentication**: None (public endpoint)

**Request**: None

**Response**:
```json
{
  "contracts": [
    {
      "name": "wg-easy-api",
      "type": "OpenAPI",
      "version": "1.0.0",
      "path": ".dev-docs/contracts/wg-easy-api.yaml",
      "url": "http://vpn-mcp-server:8080/contracts/wg-easy-api"
    },
    {
      "name": "telegram-bot-commands",
      "type": "JSON Schema",
      "version": "1.0.0",
      "path": ".dev-docs/contracts/telegram-bot-commands.json",
      "url": "http://vpn-mcp-server:8080/contracts/telegram-bot-commands"
    }
  ]
}
```

---

### GET /contracts/{name}

**Description**: Retrieve specific contract schema

**Authentication**: None (public endpoint)

**Path Parameters**:
- `name`: Contract name (e.g., `wg-easy-api`, `telegram-bot-commands`)

**Request**:
```
GET /contracts/wg-easy-api
```

**Response** (Content-Type: application/yaml):
```yaml
openapi: 3.0.3
info:
  title: wg-easy API
  version: 1.0.0
paths:
  /api/wireguard/client:
    get: ...
    post: ...
...
```

**Implementation**:
```python
@app.get("/contracts/{name}")
async def get_contract(name: str):
    contract_path = f".dev-docs/contracts/{name}.yaml"
    if not os.path.exists(contract_path):
        contract_path = f".dev-docs/contracts/{name}.json"

    if not os.path.exists(contract_path):
        raise HTTPException(404, f"Contract '{name}' not found")

    with open(contract_path) as f:
        content = f.read()

    content_type = "application/yaml" if contract_path.endswith(".yaml") else "application/json"
    return Response(content=content, media_type=content_type)
```

---

## 3. Control Operations (with Capability Checks)

### POST /control/start

**Description**: Start VPN services (if stopped)

**Authentication**: Requires token with scope `control:start:vpn`

**Request**:
```json
{
  "service": "all"  // or "wg-easy", "vpnTelegram"
}
```

**Headers**:
```
Authorization: Bearer eyJhbGc...
Content-Type: application/json
```

**Response**:
```json
{
  "success": true,
  "services_started": ["wg-easy", "vpnTelegram"],
  "errors": []
}
```

**Implementation**:
```python
@app.post("/control/start")
async def start_services(
    request: StartRequest,
    token: dict = Depends(verify_token_with_scope("control:start:vpn"))
):
    """
    Verify token has 'control:start:vpn' scope before execution
    """
    services = ["wg-easy", "vpnTelegram"] if request.service == "all" else [request.service]
    started = []
    errors = []

    for svc in services:
        try:
            container = docker_client.containers.get(svc)
            if container.status != "running":
                container.start()
                started.append(svc)
            else:
                errors.append(f"{svc} already running")
        except Exception as e:
            errors.append(f"Failed to start {svc}: {str(e)}")

    return {
        "success": len(errors) == 0,
        "services_started": started,
        "errors": errors
    }
```

---

### POST /control/stop

**Description**: Stop VPN services (graceful shutdown)

**Authentication**: Requires token with scope `control:stop:vpn`

**Request**:
```json
{
  "service": "all",  // or "wg-easy", "vpnTelegram"
  "timeout_seconds": 30  // graceful shutdown timeout
}
```

**Response**:
```json
{
  "success": true,
  "services_stopped": ["wg-easy", "vpnTelegram"],
  "errors": []
}
```

---

### POST /control/reload

**Description**: Reload configuration without downtime

**Authentication**: Requires token with scope `control:reload:vpn`

**Request**:
```json
{
  "service": "vpnTelegram",  // only bot supports reload
  "config_path": ".env"  // optional, default .env
}
```

**Response**:
```json
{
  "success": true,
  "service": "vpnTelegram",
  "reloaded_keys": ["BOT_WHITELIST", "WG_HOST"],
  "errors": []
}
```

**Implementation**:
```python
@app.post("/control/reload")
async def reload_config(
    request: ReloadRequest,
    token: dict = Depends(verify_token_with_scope("control:reload:vpn"))
):
    """
    Send SIGHUP to bot container to reload .env without restart
    """
    if request.service != "vpnTelegram":
        raise HTTPException(400, "Only vpnTelegram supports reload")

    try:
        container = docker_client.containers.get("vpnTelegram")
        container.kill(signal="SIGHUP")  # Graceful reload signal

        return {
            "success": True,
            "service": "vpnTelegram",
            "reloaded_keys": ["BOT_WHITELIST", "WG_HOST"],  # from .env
            "errors": []
        }
    except Exception as e:
        return {
            "success": False,
            "service": "vpnTelegram",
            "reloaded_keys": [],
            "errors": [str(e)]
        }
```

---

## 4. Testing & Metrics Endpoints

### POST /test/run

**Description**: Run test suite for VPN integration

**Authentication**: Requires token with scope `test:execute`

**Request**:
```json
{
  "suite": "smoke",  // or "integration", "e2e"
  "filter": "test_create_client",  // optional, run specific test
  "timeout_seconds": 300
}
```

**Response**:
```json
{
  "success": true,
  "suite": "smoke",
  "tests_run": 5,
  "tests_passed": 5,
  "tests_failed": 0,
  "duration_seconds": 12.5,
  "results": [
    {
      "name": "test_wg_easy_health",
      "status": "passed",
      "duration_seconds": 0.5
    },
    {
      "name": "test_bot_responds_to_start",
      "status": "passed",
      "duration_seconds": 2.1
    }
  ]
}
```

**Implementation**:
```python
@app.post("/test/run")
async def run_tests(
    request: TestRequest,
    token: dict = Depends(verify_token_with_scope("test:execute"))
):
    """
    Run pytest suite and return results
    """
    pytest_args = ["-v", "--tb=short"]

    if request.suite == "smoke":
        pytest_args.append("tests/smoke/")
    elif request.suite == "integration":
        pytest_args.append("tests/integration/")
    elif request.suite == "e2e":
        pytest_args.append("tests/e2e/")

    if request.filter:
        pytest_args.extend(["-k", request.filter])

    # Run pytest programmatically
    result = pytest.main(pytest_args)

    return {
        "success": result == 0,
        "suite": request.suite,
        "tests_run": get_test_count(),
        "tests_passed": get_passed_count(),
        "tests_failed": get_failed_count(),
        "duration_seconds": get_test_duration(),
        "results": parse_test_results()
    }
```

---

### GET /metrics

**Description**: Get current VPN metrics snapshot

**Authentication**: Requires token with scope `metrics:read`

**Request**:
```
GET /metrics?format=json
Authorization: Bearer eyJhbGc...
```

**Response**:
```json
{
  "timestamp": "2025-11-01T12:00:00Z",
  "counters": {
    "vpn_clients_total": 15,
    "vpn_clients_active": 12,
    "bot_commands_total": 250,
    "bot_commands_failed": 3
  },
  "gauges": {
    "vpn_bandwidth_rx_bytes": 123456789,
    "vpn_bandwidth_tx_bytes": 98765432,
    "container_memory_usage_bytes": {
      "wg-easy": 256000000,
      "vpnTelegram": 128000000
    },
    "container_cpu_usage_percent": {
      "wg-easy": 15.5,
      "vpnTelegram": 5.2
    }
  },
  "histograms": {
    "bot_response_time_seconds": {
      "p50": 0.5,
      "p95": 1.2,
      "p99": 2.0
    }
  }
}
```

**Prometheus Export** (optional):
```
GET /metrics?format=prometheus
```

**Response**:
```
# HELP vpn_clients_total Total VPN clients created
# TYPE vpn_clients_total counter
vpn_clients_total 15

# HELP vpn_clients_active Currently active VPN clients
# TYPE vpn_clients_active gauge
vpn_clients_active 12

# HELP bot_response_time_seconds Bot command response time
# TYPE bot_response_time_seconds histogram
bot_response_time_seconds_bucket{le="0.5"} 120
bot_response_time_seconds_bucket{le="1.0"} 230
bot_response_time_seconds_bucket{le="2.0"} 250
bot_response_time_seconds_count 250
bot_response_time_seconds_sum 125.5
```

---

## MCP Client Profile

### Default Permissions (Safe Operations)

**No token required** (public):
- `GET /health`
- `GET /contracts`
- `GET /contracts/{name}`

**Basic token required** (scope: `logs:read`, `metrics:read`):
- `GET /logs/tail`
- `GET /metrics`

**Token Issuance**: Anchor issues basic tokens to all agents (TTL: 1 hour)

---

### Escalated Permissions (Requires Stronger Token)

**Scope**: `control:start:vpn`, `control:stop:vpn`, `control:reload:vpn`
**TTL**: 5 minutes (short-lived)
**Audit**: All control operations logged to `.telemetry/mcp-audit.log`

**Token Issuance**:
1. Agent requests escalation from Anchor
2. Anchor evaluates request (justify need for control)
3. If approved, Anchor generates short-lived token with control scope
4. Agent uses token for control operation
5. Token expires after 5 minutes (cannot be refreshed)

**Example Escalation Request**:
```
Agent: "Need to reload VPN bot config after whitelist update"
Anchor: Evaluates → APPROVED (valid reason)
Anchor: Issues token {scope: ["control:reload:vpn"], exp: +5min}
Agent: POST /control/reload with token
```

---

## Authentication Model

### JWT Token Structure

```json
{
  "iss": "vpn-mcp-server",
  "sub": "agent_id_12345",
  "aud": ["vpn-api", "mcp-server"],
  "exp": 1730003600,
  "iat": 1730000000,
  "scope": ["logs:read", "metrics:read", "control:reload:vpn"],
  "agent_type": "agentic-engineer",
  "session_id": "session_abc123"
}
```

### Token Verification Middleware

```python
async def verify_token(token: str = Depends(oauth2_scheme)) -> dict:
    """
    Verify JWT signature and expiration
    """
    try:
        payload = jwt.decode(
            token,
            key=JWT_SECRET,
            algorithms=["HS256"],
            audience=["vpn-api", "mcp-server"]
        )

        # Check expiration
        if payload["exp"] < time.time():
            raise HTTPException(401, "Token expired")

        return payload
    except jwt.InvalidTokenError as e:
        raise HTTPException(401, f"Invalid token: {str(e)}")

async def verify_token_with_scope(required_scope: str):
    """
    Verify token has required scope
    """
    def verifier(token: dict = Depends(verify_token)):
        if required_scope not in token.get("scope", []):
            raise HTTPException(403, f"Insufficient scope: requires '{required_scope}'")
        return token
    return verifier
```

---

## Rate Limiting

**Per Client** (by token subject):
- `/health`: 60 requests/minute
- `/logs/tail`: 10 requests/minute
- `/contracts`: 30 requests/minute
- `/control/*`: 5 requests/minute
- `/test/run`: 2 requests/minute
- `/metrics`: 20 requests/minute

**Global**:
- 300 requests/minute across all endpoints

**Implementation**: Use `slowapi` library:
```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@app.get("/logs/tail")
@limiter.limit("10/minute")
async def tail_logs(...):
    ...
```

---

## Error Responses

**Standard Error Format**:
```json
{
  "error": {
    "code": "INSUFFICIENT_SCOPE",
    "message": "Token does not have required scope: control:reload:vpn",
    "details": {
      "required_scope": "control:reload:vpn",
      "provided_scopes": ["logs:read", "metrics:read"]
    }
  },
  "timestamp": "2025-11-01T12:00:00Z"
}
```

**HTTP Status Codes**:
- 400: Invalid request (missing parameters)
- 401: Authentication failed (invalid/expired token)
- 403: Authorization failed (insufficient scope)
- 404: Resource not found (contract, service)
- 429: Rate limit exceeded
- 500: Internal server error
- 503: Service unavailable (wg-easy down)

---

## MCP Server Deployment (Docker Compose)

**Service Definition**:
```yaml
services:
  vpn-mcp-server:
    build:
      context: ./vpn-mcp
      dockerfile: Dockerfile
    container_name: vpn-mcp-server
    restart: unless-stopped
    environment:
      - JWT_SECRET=${JWT_SECRET}
      - DOCKER_HOST=unix:///var/run/docker.sock
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro  # Docker API access
      - ./.dev-docs:/app/.dev-docs:ro  # Contract access
    networks:
      - vpn_network
    ports:
      - "8080:8080"  # Expose MCP API
    depends_on:
      - wg-easy
      - vpnTelegram
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.5'
```

---

## References

- **Model Context Protocol**: https://modelcontextprotocol.io
- **OpenAPI Specification**: https://swagger.io/specification/
- **JWT RFC 7519**: https://tools.ietf.org/html/rfc7519
- **FastAPI Documentation**: https://fastapi.tiangolo.com/
- **Docker API**: https://docs.docker.com/engine/api/
