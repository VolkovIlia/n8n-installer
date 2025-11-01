# VPN Integration - Architecture Summary

**Project**: n8n-installer VPN integration (wg-easy + vpnTelegram bot)
**Date**: 2025-11-01
**Architect**: AI Solutions Architect
**Status**: ✅ Architecture Complete - Ready for Implementation

---

## Executive Summary

Designed message-passing VPN integration for n8n-installer to bypass Russian geo-blocking. System follows **minimalist**, **contract-first**, **capability-based** architecture with complete network isolation from existing n8n services.

**Key Metrics**:
- **Resource Footprint**: 768MB RAM max, 0.75 CPU cores max, 500MB disk
- **Container Count**: 2 (wg-easy, vpnTelegram)
- **Networks**: 1 new isolated network (vpn_network 172.21.0.0/16)
- **Exposed Ports**: 2 (51820/udp WireGuard, 51821/tcp wg-easy UI)
- **Installation Time**: <10 minutes (single menu option)
- **Dependencies**: <10 per service (suckless compliant)

---

## Architecture Principles

### 1. ✅ Interfaces First (MIG-like)
- **IDL Contracts**: OpenAPI YAML for wg-easy API, JSON schema for Telegram commands
- **Location**: `.dev-docs/contracts/`
- **Codegen**: Not required (HTTP APIs, no stubs needed)
- **Validation**: API contracts serve as implementation reference

### 2. ✅ Message-Passing Topology
- **Diagram**: `.dev-docs/diagrams/message-flows.md` (6 Mermaid diagrams)
- **Message Types**: Delegation (User→Bot), Request/Response (Bot→API), Report (Bot→User), Control (Docker→Containers)
- **No Hidden Coupling**: All interactions via HTTP/Telegram API (explicit, documented)
- **Network Isolation**: vpn_network (172.21.0.0/16) separate from n8n_network (172.20.0.0/16)

### 3. ✅ Capabilities/Security
- **Current (MVP)**: Environment variables (BOT_TOKEN, WG_PASSWORD) + Telegram user ID whitelist
- **Token Structure**: BOT_TOKEN (permanent), WG_PASSWORD (permanent), wg-easy session (24h TTL)
- **Auth Flow**: Telegram automatic user verification → Whitelist check → wg-easy API session
- **Future (v2.0)**: JWT-based capability tokens with scopes (vpn:create, control:reload, etc.)
- **Documentation**: `.dev-docs/capabilities/security-model.md`

### 4. ✅ Translators/Adapters (Hurd-like)
- **Registry**: `.dev-docs/adapters/registry.md`
- **Adapters**:
  - `WireGuardAPIAdapter` (wg-easy HTTP → IVPNProvider)
  - `TelegramBotAdapter` (Telegram API → IMessagingProvider)
  - `DockerComposeAdapter` (docker-compose → IContainerOrchestrator)
  - `QRCodeAdapter` (qrcode lib → IQRGenerator)
  - `EnvFileAdapter` (.env → IConfigProvider)
  - `StdoutAdapter` (stdout → ILogSink)
- **Replaceability**: All adapters swappable via dependency injection (1-3 days effort)

### 5. ✅ One Build/Run Path
- **Installation**: `bash install.sh` → Select menu option 3 ("Install VPN + Telegram bot")
- **Build**: Docker images pulled (wg-easy official, bot custom Dockerfile)
- **Run**: `docker compose up -d wg-easy vpnTelegram`
- **Configuration**: All via .env file (BOT_TOKEN, WG_HOST, WG_PASSWORD)
- **Documentation**: `.dev-docs/build-run.md`

### 6. ✅ Suckless Constraints
- **ADRs**: 6 decisions, ≤1 paragraph each (`.dev-docs/adr/`)
- **Container Size**: wg-easy 65MB, bot 50MB (total 115MB)
- **Dependencies**: wg-easy (Node.js), bot (Python 3.11-slim + 4 libs)
- **Deletion Backlog**: `.dev-docs/deletion-backlog.md` (tracks removal candidates)
- **Code Structure**: Functions ≤50 lines, files ≤500 lines (enforced in review)

---

## Deliverables Checklist

### ✅ 1. Contracts (`.dev-docs/contracts/`)
- [x] `wg-easy-api.yaml` - OpenAPI 3.0 spec (327 lines, complete)
- [x] `telegram-bot-commands.json` - JSON schema (existing)
- [x] Codegen command: Not required (HTTP APIs consumed directly)

### ✅ 2. Message Flows (`.dev-docs/diagrams/message-flows.md`)
- [x] Diagram 1: User requests VPN config (Telegram → Bot → wg-easy)
- [x] Diagram 2: Installation flow (Admin → install.sh → Docker)
- [x] Diagram 3: Revoke access flow (Admin/User → Bot → wg-easy)
- [x] Diagram 4: Status check flow (User → Bot → wg-easy API)
- [x] Diagram 5: Health check and monitoring (Docker → Containers)
- [x] Diagram 6: Network isolation architecture (n8n vs vpn networks)
- [x] No hidden coupling verified (all interactions explicit HTTP/Telegram)

### ✅ 3. Capability Model (`.dev-docs/capabilities/security-model.md`)
- [x] Current security model (MVP v1.0): Password + Telegram user ID
- [x] Token structure: BOT_TOKEN, WG_PASSWORD, session tokens
- [x] Authentication flows: User→Bot, Bot→API, Admin→UI
- [x] Authorization matrix: Operation → Capability → Verification
- [x] Audit logging: Command logs, access logs, retention 30 days
- [x] Capability checks per operation: /request, /revoke, /status
- [x] Security threats & mitigations: 5 threats analyzed
- [x] Future JWT model (v2.0): Token structure, scopes, issuance, verification

### ✅ 4. Adapter Registry (`.dev-docs/adapters/registry.md`)
- [x] Adapter pattern documentation (Hurd translator concept)
- [x] 6 adapters defined with interfaces
- [x] Replaceability matrix (effort to swap: 0.5-3 days)
- [x] Adapter lifecycle (mount, use, unmount, hot swap)
- [x] Integration with n8n-installer (tool-mapping.yaml concept)
- [x] Testing strategy (mock adapters, contract tests, integration tests)

### ✅ 5. Docker Compose Design (`.dev-docs/architecture/docker-compose-design.md`)
- [x] Service architecture (2 containers: wg-easy, vpnTelegram)
- [x] Network topology diagram (n8n_network vs vpn_network isolation)
- [x] YAML configuration (networks, volumes, services)
- [x] wg-easy service definition (ports, capabilities, environment, volumes)
- [x] vpnTelegram service definition (dependencies, environment, build context)
- [x] Health checks (wg-easy HTTP, bot process check)
- [x] Resource limits (wg-easy 512MB RAM/1 CPU, bot 256MB RAM/0.5 CPU)
- [x] Security configuration (NET_ADMIN capability, read-only mounts)

### ✅ 6. Build/Run Path (`.dev-docs/build-run.md`)
- [x] Prerequisites (OS, Docker, kernel, hardware)
- [x] Installation method (interactive menu)
- [x] Menu flow (step-by-step user prompts)
- [x] Build commands (Docker image pull)
- [x] Run commands (docker compose up -d)
- [x] Configuration (environment variables)
- [x] Verification (health checks, port checks)
- [x] Troubleshooting (common errors, solutions)
- [x] Uninstallation (rollback script)

### ✅ 7. ADRs (`.dev-docs/adr/`) - ≤1 paragraph each
- [x] 0001-wireguard-over-openvpn.md
- [x] 0002-wg-easy-over-raw-wg.md
- [x] 0003-telegram-bot-over-web-ui-only.md
- [x] 0004-docker-compose-over-kubernetes.md
- [x] 0005-network-isolation-over-shared-network.md
- [x] 0006-password-auth-over-jwt.md

### ✅ 8. MCP Server Design (`.dev-docs/mcp/server-design.md`) - STRETCH v2.0
- [x] Endpoint categories: health, contracts, control, test (4 categories)
- [x] Health & logs: health.get, logs.tail
- [x] Contract discovery: contracts.list, contracts.describe
- [x] Control operations: control.start/stop/reload (with capability checks)
- [x] Testing & metrics: test.run, metrics.snapshot
- [x] Client profile: Default permissions vs escalated permissions
- [x] Auth model: Capability tokens, TTL, scope enforcement
- [x] Rate limits: Per-client, per-endpoint limits

### ✅ 9. Deletion Backlog (`.dev-docs/deletion-backlog.md`)
- [x] Deletion candidates prioritized (HIGH → LOW)
- [x] Dependency audit (bot 10MB, wg-easy 65MB)
- [x] Non-essential features prevented (traffic dashboard, multi-admin)
- [x] Removal guidelines (verification, testing, documentation)
- [x] Success metrics (current 115MB → target 100MB → stretch 80MB)
- [x] Continuous improvement process (monthly review)

---

## Key Architectural Decisions

### ADR Summary

| ID | Decision | Rationale | Trade-off |
|----|----------|-----------|-----------|
| 0001 | WireGuard over OpenVPN | 4x faster, simpler config (200 vs 4000 LOC), native kernel | Less mature ecosystem, requires kernel ≥5.6 |
| 0002 | wg-easy over raw wg CLI | HTTP API for bot, web UI, QR generation, 15k+ stars | +256MB RAM, dependency on third-party |
| 0003 | Telegram bot over web UI only | Mobile-first UX, instant delivery, self-service | +256MB RAM, Telegram API dependency risk |
| 0004 | Docker Compose over Kubernetes | Single-server simplicity, <10 min install, familiar | No horizontal scaling (not needed) |
| 0005 | Network isolation over shared | Fault isolation, security, clear boundaries | +1 network definition, subnet planning |
| 0006 | Password auth (MVP) over JWT | Faster MVP (0 vs 2 weeks), simpler codebase | No fine-grained permissions (defer to v2.0) |

---

## System Boundaries

### In Scope (MVP v1.0)
- ✅ VPN installation via n8n-installer menu
- ✅ wg-easy container with web UI + HTTP API
- ✅ Telegram bot for client config distribution (/start, /request, /revoke, /status)
- ✅ QR code generation (via wg-easy API)
- ✅ Network isolation (vpn_network separate from n8n_network)
- ✅ Environment variable configuration (BOT_TOKEN, WG_HOST, WG_PASSWORD)
- ✅ Health checks and automatic restart
- ✅ Documentation (installation guide, user guide, bot commands)

### Out of Scope (Deferred to v2.0+)
- ❌ JWT-based capability tokens (use password auth for MVP)
- ❌ MCP server endpoints (design complete, implementation STRETCH)
- ❌ Traffic statistics dashboard (use wg-easy built-in stats)
- ❌ Multi-user admin roles (single admin via WG_PASSWORD)
- ❌ Config expiration (manual revocation only)
- ❌ Bandwidth limits per client (WireGuard default: unlimited)
- ❌ Email notifications (Telegram only)
- ❌ Webhook mode for bot (use polling for MVP)

---

## Risk Mitigation

### Critical Risks (from hypothesis.v1.json)

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **A1**: WireGuard blocked by Russian DPI | LOW | CRITICAL | Pilot test from Russian IP (REQUIRED before v1.0) |
| **A2**: Telegram bot blocked in Russia | MEDIUM | HIGH | Fallback: wg-easy UI + manual QR export + email |
| **A6**: VPN install breaks n8n services | MEDIUM | CRITICAL | Network isolation + regression testing + rollback script |

**Validation Required Before Production**:
1. Test WireGuard connection from Russian IP (Hypothesis A1)
2. Test Telegram bot accessibility from Russian IP (Hypothesis A2)
3. Regression test n8n services after VPN installation (Hypothesis A6)

---

## Handoff to Agentic Engineer

### Implementation Order

**Phase 1: Foundation (Days 1-3)**
1. Read all architecture documents in `.dev-docs/`
2. Review existing docker-compose.yml structure
3. Create bot Dockerfile (Python 3.11-slim base)
4. Create bot project structure:
   ```
   vpn-telegram-bot/
   ├── bot.py (main entry point)
   ├── handlers/ (command handlers)
   ├── adapters/ (WireGuardAPIAdapter, TelegramBotAdapter, etc.)
   ├── interfaces/ (IVPNProvider, IMessagingProvider, etc.)
   ├── requirements.txt (python-telegram-bot, requests, qrcode, python-dotenv)
   └── Dockerfile
   ```

**Phase 2: Core Implementation (Days 4-8)**
1. Implement adapters following registry.md specifications
2. Implement bot command handlers (/start, /request, /revoke, /status)
3. Implement wg-easy API client (session management, client CRUD)
4. Implement QR code generation (use wg-easy QR endpoint)
5. Implement whitelist checking (BOT_WHITELIST environment variable)

**Phase 3: Docker Integration (Days 9-10)**
1. Update docker-compose.yml (append wg-easy + vpnTelegram services)
2. Create vpn_network definition (172.21.0.0/16)
3. Add wg_data volume definition
4. Configure health checks (wg-easy HTTP, bot process)
5. Set resource limits (memory, CPU)

**Phase 4: Installation Script (Days 11-12)**
1. Modify install.sh to add "Install VPN" menu option
2. Implement BOT_TOKEN prompt with validation
3. Implement external IP detection (curl ifconfig.me)
4. Implement WG_PASSWORD generation (openssl rand -base64 32)
5. Implement .env file update (append VPN variables)
6. Implement docker-compose service start
7. Implement success message (display UI URL, password, bot username)

**Phase 5: Testing & Documentation (Days 13-15)**
1. Unit tests for adapters (use mock IVPNProvider)
2. Integration tests with real wg-easy container
3. End-to-end tests (install → request config → connect)
4. Documentation updates (README, INSTALL, USER_GUIDE)
5. Rollback/uninstall script

### Critical Implementation Notes

1. **Never access WireGuard directly**: Bot uses wg-easy HTTP API only (adapter pattern)
2. **All secrets in .env**: No hardcoded BOT_TOKEN or WG_PASSWORD
3. **Session management**: Lazy session creation, 24h TTL, auto-refresh on 401
4. **Error handling**: Retry logic (3 attempts, exponential backoff), clear user messages
5. **Rate limiting**: 5 /request per hour, 10 /status per minute (per user)
6. **Whitelist enforcement**: Check BOT_WHITELIST on EVERY command (if configured)
7. **Logging**: All commands to stdout (Docker captures), format: `[timestamp] LEVEL: message`
8. **Resource cleanup**: Close wg-easy session on shutdown

### Acceptance Criteria (from acceptance-criteria.md)

**AC-001**: Menu option appears and installs successfully in <10 minutes
**AC-002**: wg-easy UI accessible at https://{WG_HOST}:51821
**AC-003**: Bot responds to /start in <2 seconds
**AC-004**: docker-compose.yml includes both services
**AC-005**: WG_PASSWORD auto-generated (32 chars), BOT_TOKEN from user input

**Gate 1 (Installation)**: All AC-001 scenarios pass
**Gate 2 (Functionality)**: All AC-002, AC-003, AC-004 scenarios pass
**Gate 3 (Security)**: All AC-005 scenarios pass, no hardcoded secrets
**Gate 4 (Integration)**: Existing n8n services remain healthy

---

## Technical Specifications Reference

### API Contracts
- **wg-easy API**: `.dev-docs/contracts/wg-easy-api.yaml` (OpenAPI 3.0, 327 lines)
- **Bot Commands**: `.dev-docs/contracts/telegram-bot-commands.json` (JSON schema)

### Network Configuration
- **vpn_network**: 172.21.0.0/16 (bridge driver)
- **n8n_network**: 172.20.0.0/16 (existing, do not modify)
- **No bridge** between networks (complete isolation)

### Ports
- **51820/udp**: WireGuard protocol (public)
- **51821/tcp**: wg-easy UI (password-protected)
- **No bot ports**: Outbound to Telegram API only

### Resource Limits
- **wg-easy**: 512MB RAM max, 1.0 CPU max
- **vpnTelegram**: 256MB RAM max, 0.5 CPU max
- **Total**: 768MB RAM, 1.5 CPU (leaves 7.2GB/6.5 cores for n8n + system)

### Environment Variables (.env)
```bash
# Telegram Bot (from @BotFather)
BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz

# wg-easy Admin (auto-generated 32 chars)
WG_PASSWORD=auto-generated-password-here

# Server External IP (auto-detected or manual)
WG_HOST=192.168.1.100

# Default DNS for VPN clients
WG_DEFAULT_DNS=1.1.1.1,8.8.8.8

# Optional: User whitelist (comma-separated Telegram user IDs)
BOT_WHITELIST=123456,789012
```

---

## Suckless Compliance Checklist

### Architecture Phase ✅
- [x] ADRs ≤1 paragraph each (6 ADRs created)
- [x] Message flow diagrams explicit (6 diagrams, no hidden coupling)
- [x] Adapter registry complete (6 adapters, all replaceable)
- [x] Single build path documented (1 command: bash install.sh)
- [x] Deletion backlog created (9 candidates tracked)
- [x] Dependencies audited (bot: 10MB, wg-easy: 65MB)

### Implementation Phase (Engineer's Responsibility)
- [ ] Functions ≤50 lines (enforce in code review)
- [ ] Files ≤500 lines (enforce in code review)
- [ ] Dependencies <10 per service (current: bot 4, wg-easy 0 extra)
- [ ] No secondary build systems (use native Docker + Python)
- [ ] Errors as values (no exceptions for control flow)
- [ ] Table-driven dispatch (map commands to handlers)
- [ ] Early returns (validate → acquire → operate → release → return)

---

## Next Steps for Engineer

1. **Read Product Requirements** (`.dev-docs/product/`):
   - acceptance-criteria.md (5 core AC with Gherkin scenarios)
   - technical-constraints.md (performance, reliability, security requirements)
   - mvp-scope.md (RICE prioritization, CORE vs MVP vs STRETCH)
   - user-stories.md (12 stories with INVEST validation)

2. **Read Architecture Documents** (`.dev-docs/`):
   - contracts/ (API specifications)
   - diagrams/message-flows.md (understand all interactions)
   - capabilities/security-model.md (understand auth flow)
   - adapters/registry.md (understand abstraction layer)
   - architecture/docker-compose-design.md (container configuration)

3. **Setup Development Environment**:
   ```bash
   cd /home/volk/vibeprojects/n8n-installer
   git checkout -b feature/vpn-integration
   mkdir -p vpn-telegram-bot/{handlers,adapters,interfaces}
   ```

4. **Start Implementation**:
   - Phase 1: Foundation (bot project structure)
   - Phase 2: Core (adapters + handlers)
   - Phase 3: Docker integration
   - Phase 4: Installation script
   - Phase 5: Testing + docs

---

## Success Criteria

### Definition of Done

- [x] ✅ Architecture documentation complete (all 9 deliverables)
- [ ] ⏳ Implementation complete (all CORE stories from MVP scope)
- [ ] ⏳ All acceptance criteria pass (AC-001 through AC-005)
- [ ] ⏳ Integration tests pass (n8n services remain healthy)
- [ ] ⏳ Resource usage within limits (768MB RAM, 1.5 CPU)
- [ ] ⏳ Installation time <10 minutes (timed test)
- [ ] ⏳ Documentation complete (INSTALL.md, USER_GUIDE.md, BOT_COMMANDS.md)
- [ ] ⏳ Rollback tested successfully (uninstall script works)
- [ ] ⏳ Pilot test from Russian IP (validates Hypothesis A1, A2)

---

## Contact & Questions

**Architect**: AI Solutions Architect
**Documentation**: `/home/volk/vibeprojects/n8n-installer/.dev-docs/`
**Questions**: Refer to specific document (contracts, diagrams, capabilities, adapters)

**For unclear specifications**:
1. Check relevant `.dev-docs/` document first
2. Check ADRs for decision rationale
3. Check message-flows.md for interaction details
4. Ask Anchor to delegate back to AI Solutions Architect if major gap found

---

**Architecture Status**: ✅ COMPLETE - Ready for Implementation
**Next Agent**: Agentic Engineer (implementation phase)
**Timeline**: 15 days estimated (3 weeks)
