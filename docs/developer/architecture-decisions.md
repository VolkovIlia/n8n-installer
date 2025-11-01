# Architecture Decision Records

## Overview

This document explains key architectural decisions made during VPN integration development, including rationale, trade-offs, and consequences.

**Reference**: See `.dev-docs/adr/` for original ADR files.

---

## ADR-0001: WireGuard over OpenVPN

**Status**: Accepted

**Context**:

We need a VPN protocol to bypass Russian geo-restrictions for n8n access. Two main options:
1. **WireGuard**: Modern, kernel-integrated VPN (Linux ≥5.6)
2. **OpenVPN**: Established, userspace VPN (mature ecosystem)

**Decision**: Use WireGuard protocol instead of OpenVPN.

**Rationale**:

**Performance**:
- WireGuard: ~4x faster throughput (kernel-level implementation)
- WireGuard: ~50% lower latency (fewer packet processing layers)
- WireGuard: Minimal CPU usage (ChaCha20 optimized for mobile CPUs)

**Security**:
- WireGuard: Modern cryptography (ChaCha20-Poly1305, Curve25519)
- WireGuard: Smaller attack surface (~4,000 LOC vs ~400,000 LOC)
- WireGuard: Formally verified protocol (Noise framework)

**Simplicity**:
- WireGuard: No PKI/certificates required (just public keys)
- WireGuard: 200 lines of config vs 4,000 lines (OpenVPN)
- WireGuard: One-command setup (`wg-quick up wg0`)

**Trade-offs**:

✅ **Advantages**:
- Faster connections (crucial for n8n real-time workflows)
- Simpler configuration (easier for non-technical users)
- Lower resource usage (important for 8GB server)
- Built into Linux kernel 5.6+ (no extra packages)

⚠️ **Disadvantages**:
- Requires kernel ≥5.6 (fallback to wireguard-go userspace)
- Less mature ecosystem than OpenVPN (fewer tools)
- Not ideal for censorship circumvention (DPI can detect WireGuard)

**Consequences**:

✅ **Positive**:
- Users get faster VPN connections (4x throughput improvement)
- Simpler bot implementation (no certificate management)
- Lower server resource usage (512MB RAM vs 1GB for OpenVPN)

⚠️ **Risks**:
- May not work on older kernels (mitigation: wireguard-go fallback)
- Russian DPI might block WireGuard protocol (mitigation: pilot test required)

**Validation**:
- Pilot test from Russian IP required before production (Hypothesis A1)
- Fallback plan: obfsproxy wrapper if WireGuard blocked

---

## ADR-0002: wg-easy over Raw WireGuard CLI

**Status**: Accepted

**Context**:

WireGuard protocol chosen, now need management interface. Options:
1. **Raw `wg` CLI**: Direct WireGuard commands via shell
2. **wg-easy**: Docker container with Web UI + HTTP API

**Decision**: Use wg-easy container instead of raw WireGuard CLI.

**Rationale**:

**HTTP API**:
- wg-easy provides RESTful API (no shell scripting needed)
- Telegram bot can use standard HTTP client (requests library)
- No security risks from shell command injection

**Pre-Built UI**:
- Admin can troubleshoot via Web UI (no SSH required)
- QR code generation built-in (no qrencode dependency)
- Client management UI (list, delete, view stats)

**Maturity**:
- 15k+ GitHub stars, active maintenance
- Official Docker image, weekly releases
- Well-documented API (OpenAPI spec available)

**Trade-offs**:

✅ **Advantages**:
- Faster development (no custom API needed)
- Web UI for troubleshooting (admin-friendly)
- Built-in QR generation (one less dependency)
- Session management (24h TTL tokens)

⚠️ **Disadvantages**:
- +256MB RAM overhead (wg-easy container)
- Dependency on third-party project (vendor lock-in risk)
- Extra network hop (bot → wg-easy API → WireGuard)

**Consequences**:

✅ **Positive**:
- Bot implementation simpler (standard HTTP adapter pattern)
- Admin can manage clients without CLI access
- No shell injection vulnerabilities (API uses validated inputs)

⚠️ **Risks**:
- If wg-easy project abandoned, must fork or migrate to raw CLI
- Resource overhead acceptable for 8GB server (768MB total budget)

**Mitigation**:
- Adapter pattern allows swapping wg-easy for raw CLI (1-2 days effort)
- Docker image pinned to specific tag (prevents breaking changes)

---

## ADR-0003: Telegram Bot over Web UI Only

**Status**: Accepted

**Context**:

Users need to request VPN configs. Options:
1. **Web UI only**: Admin creates configs manually, shares via email/messenger
2. **Telegram bot**: Automated config distribution via bot commands

**Decision**: Implement Telegram bot in addition to wg-easy Web UI.

**Rationale**:

**Mobile-First UX**:
- Target users (Russian freelancers) primarily use mobile devices
- Telegram native app better than mobile web UI
- QR code scan workflow optimized for mobile

**Instant Delivery**:
- Bot sends config immediately (no waiting for admin)
- Self-service reduces admin workload
- 24/7 availability (no human bottleneck)

**Security**:
- Telegram E2E encryption (Secret Chats not required for bots)
- No email attachments (avoid email security issues)
- Whitelist enforcement (BOT_WHITELIST prevents abuse)

**Trade-offs**:

✅ **Advantages**:
- Better UX for mobile users (native Telegram app)
- Instant config delivery (no admin intervention)
- Self-service workflow (scales to many users)
- Whitelist control (authorized users only)

⚠️ **Disadvantages**:
- +256MB RAM (bot container)
- Telegram API dependency (risk of blocking in Russia)
- Bot development effort (2 weeks)

**Consequences**:

✅ **Positive**:
- Users get VPN configs in <10 seconds (vs hours with manual process)
- Admin workload reduced (no manual config creation)
- Scales to 100+ users (bot handles concurrency)

⚠️ **Risks**:
- Telegram API might be blocked in Russia (mitigation: pilot test)
- Fallback: wg-easy UI + manual email distribution

**Validation**:
- Pilot test Telegram bot accessibility from Russian IP (Hypothesis A2)

---

## ADR-0004: Docker Compose over Kubernetes

**Status**: Accepted

**Context**:

Need container orchestration for VPN services. Options:
1. **Docker Compose**: Simple YAML, single-server
2. **Kubernetes**: Complex orchestration, multi-server

**Decision**: Use Docker Compose instead of Kubernetes.

**Rationale**:

**Simplicity**:
- Docker Compose: 50-line YAML file
- Kubernetes: 200+ lines (Deployment, Service, ConfigMap, Secret)
- Docker Compose: One-command installation (`docker-compose up -d`)
- Kubernetes: Requires cluster setup (control plane, worker nodes)

**Single-Server Deployment**:
- MVP targets single server (8GB RAM, 8 CPU)
- No need for horizontal scaling (100 clients max)
- No need for high availability (planned downtime acceptable)

**Familiar Tooling**:
- n8n-installer already uses Docker Compose
- Target users (system admins) familiar with Docker
- No Kubernetes learning curve

**Trade-offs**:

✅ **Advantages**:
- Faster installation (<10 minutes vs 1+ hours for K8s)
- Simpler troubleshooting (docker logs vs kubectl)
- Lower resource overhead (no K8s control plane)
- Familiar to existing n8n-installer users

⚠️ **Disadvantages**:
- No horizontal scaling (stuck at 100 clients)
- No automatic failover (manual restart required)
- Single point of failure (server down = VPN down)

**Consequences**:

✅ **Positive**:
- Users can install VPN in <10 minutes (vs 1+ hours)
- Lower complexity (fits suckless philosophy)
- Lower resource usage (768MB vs 2GB for K8s)

⚠️ **Limitations**:
- Max 100 concurrent clients (sufficient for MVP)
- Planned downtime required for updates
- No multi-datacenter deployment

**Future Migration**:
- If >100 clients needed, migrate to Kubernetes (message contracts remain same)
- Estimated migration effort: 3-5 days

---

## ADR-0005: Network Isolation over Shared Network

**Status**: Accepted

**Context**:

VPN services need Docker network. Options:
1. **Shared network**: Use existing n8n_network
2. **Isolated network**: Create separate vpn_network

**Decision**: Create separate Docker network (vpn_network) for VPN services.

**Rationale**:

**Fault Isolation**:
- VPN issues don't affect n8n services
- WireGuard crash doesn't bring down n8n
- Network debugging easier (isolated traffic)

**Security Boundary**:
- Clear separation of concerns
- No accidental cross-service communication
- Firewall rules easier to reason about

**Resource Monitoring**:
- Separate network metrics (bandwidth, packet loss)
- Easier to identify VPN-specific traffic
- Clearer logs (no n8n noise in VPN logs)

**Trade-offs**:

✅ **Advantages**:
- Better reliability (n8n unaffected by VPN failures)
- Clearer architecture (explicit boundaries)
- Easier debugging (isolated network traffic)
- Better security (no accidental exposure)

⚠️ **Disadvantages**:
- +1 network definition in docker-compose.yml
- Subnet planning required (avoid IP conflicts)
- Cannot directly access n8n from VPN (by design)

**Consequences**:

✅ **Positive**:
- n8n services remain healthy if VPN crashes
- Clear architecture (vpn_network vs n8n_network)
- Regression testing easier (verify n8n still works after VPN install)

⚠️ **Operational**:
- Admins must plan subnets (172.21.0.0/16 vs 172.20.0.0/16)
- No direct n8n access from VPN users (requires separate auth)

**Verification**:
```bash
# Verify isolation (should fail)
docker exec vpn-telegram-bot ping -c 1 n8n
# Expected: "ping: n8n: Name or service not known"
```

---

## ADR-0006: Password Auth (MVP) over JWT

**Status**: Accepted (MVP), JWT planned for v2.0

**Context**:

Need authentication for VPN bot and wg-easy API. Options:
1. **Password-based**: BOT_TOKEN, WG_PASSWORD (environment variables)
2. **JWT-based**: Capability tokens with scopes, TTL, revocation

**Decision**: Use password authentication for MVP, defer JWT to v2.0.

**Rationale**:

**Faster MVP**:
- Password auth: 0 days implementation (already available)
- JWT auth: 2 weeks implementation (token generation, verification, revocation)
- MVP goal: Ship in 3 weeks (no time for JWT)

**Simpler Codebase**:
- Password: 0 additional dependencies
- JWT: +1 dependency (PyJWT), +200 LOC
- Suckless principle: Avoid complexity until needed

**Adequate Security**:
- BOT_TOKEN: 45-character random string (unguessable)
- WG_PASSWORD: 32-character random string (high entropy)
- Whitelist: Telegram user IDs (cannot be spoofed)

**Trade-offs**:

✅ **Advantages (MVP)**:
- Faster shipping (0 vs 2 weeks)
- Simpler code (0 vs 200 LOC)
- Fewer dependencies (4 vs 5)
- Adequate security (high-entropy passwords + whitelist)

⚠️ **Disadvantages (MVP)**:
- No fine-grained permissions (all or nothing)
- No audit trail (who did what when)
- No token revocation (must change password)
- No time-based expiration (passwords permanent)

**Consequences**:

✅ **Positive**:
- MVP shipped 2 weeks faster
- Simpler architecture (easier to maintain)
- Lower resource usage (no JWT verification overhead)

⚠️ **Limitations**:
- Cannot revoke individual users without changing password
- Cannot grant temporary access (e.g., 24-hour trial)
- Cannot audit specific operations (only command-level logs)

**Future (v2.0)**:
- Migrate to JWT-based capability tokens
- Scopes: `vpn:create`, `vpn:revoke`, `admin:ui`
- TTL: 1 hour (client), 24 hours (admin)
- Audit: Who created which client, when

**Migration Path**:
```python
# v1.0 (current)
if not self._is_authorized(user_id):
    return

# v2.0 (future)
if not self._has_capability(token, "vpn:create"):
    return
```

---

## Design Principles Summary

All ADRs follow these principles:

### 1. Minimalism (Suckless)
- Prefer simple solutions (Docker Compose over K8s)
- Avoid premature optimization (password over JWT for MVP)
- Small dependencies (WireGuard 4k LOC vs OpenVPN 400k LOC)

### 2. Message-Passing
- Explicit communication (HTTP API, not shared memory)
- Network isolation (separate Docker networks)
- No hidden coupling (all interactions documented)

### 3. Replaceable Components
- Adapters swappable (wg-easy → raw CLI: 1-2 days)
- Network swappable (Docker Compose → K8s: 3-5 days)
- Auth swappable (password → JWT: 2 weeks)

### 4. Fail-Safe Defaults
- Network isolation by default (explicit bridge required)
- Whitelist enforcement (deny by default if configured)
- Session expiration (24h TTL, not permanent)

---

## References

- **Original ADRs**: `.dev-docs/adr/0001-*.md`
- **Architecture Summary**: `.dev-docs/ARCHITECTURE_SUMMARY.md`
- **Suckless Philosophy**: https://suckless.org/philosophy
- **WireGuard**: https://www.wireguard.com/papers/wireguard.pdf
