# Deletion Backlog - VPN Integration

**Purpose**: Track features, dependencies, and code candidates for removal to preserve minimalism.

**Philosophy**: "Removing code beats adding it" (suckless principle)

---

## Principle: Aggressive Minimalism

- **Target**: <10 dependencies per service
- **Target**: <500 LOC per file
- **Target**: <50 LOC per function
- **Target**: <1MB per container image (base + layers)

---

## Deletion Candidates (Priority: HIGH → LOW)

### 1. Heavy Python Dependencies (Bot Container)

**Current**: python-telegram-bot library (3.5MB + dependencies)

**Alternative**: Use Telegram Bot API directly via `requests` library

**Rationale**: python-telegram-bot adds 3.5MB + transient dependencies (certifi, urllib3, etc.). Raw API calls with `requests` sufficient for MVP commands (send_message, send_photo, send_document). Webhook support not needed (polling adequate for personal bot).

**Estimated Savings**: 3MB container size, 2 fewer dependencies

**Effort**: 1 day (rewrite bot handlers)

**Status**: DEFERRED to v2.0 (risk vs reward - library provides retry logic, rate limiting)

---

### 2. QR Code Generation Library (Bot Container)

**Current**: `qrcode` library (500KB + pillow dependency 5MB)

**Alternative**: Call external QR generation service or use wg-easy's built-in QR code

**Rationale**: `qrcode` requires Pillow (5MB image processing library) for PNG generation. wg-easy already generates QR codes as SVG (available via API). Can convert SVG to PNG via lightweight tool or send SVG directly (Telegram supports SVG in documents).

**Estimated Savings**: 5.5MB container size, 2 fewer dependencies

**Effort**: 0.5 days (switch to wg-easy QR endpoint)

**Status**: CONSIDER for v1.1 (significant size reduction)

---

### 3. Unused wg-easy Features (wg-easy Container)

**Current**: wg-easy web UI with full feature set

**Alternative**: Custom minimal Docker image with API-only mode

**Rationale**: Bot uses HTTP API only (not web UI). If admin access not needed, can strip UI assets (JavaScript, CSS, fonts) and serve API-only mode. Reduces attack surface and image size.

**Estimated Savings**: 10MB container size, faster startup

**Effort**: 3 days (fork wg-easy, create API-only variant)

**Status**: DEFER to v2.0 (admin UI useful for troubleshooting)

---

### 4. Docker Compose Profiles (n8n-installer)

**Current**: docker-compose.yml includes 20+ service profiles (flowise, open-webui, langfuse, etc.)

**Opportunity**: Split VPN services into separate compose file

**Rationale**: VPN services independent of n8n services. Separate `docker-compose.vpn.yml` simplifies maintenance, reduces coupling, enables independent updates. Main compose file already large (809 lines).

**Estimated Savings**: Better separation of concerns, easier troubleshooting

**Effort**: 1 day (extract VPN services to separate file, update install.sh)

**Status**: CONSIDER for v1.1 (architectural improvement)

---

### 5. Telegram Bot Polling (Bot Container)

**Current**: Long-polling (bot fetches updates every 1 second)

**Alternative**: Webhook mode (Telegram pushes updates to bot)

**Rationale**: Polling wastes CPU cycles (1 request/sec even when idle). Webhook eliminates polling overhead, reduces latency (instant message delivery), and saves resources. Requires HTTPS endpoint (can use Caddy reverse proxy or Cloudflare Tunnel).

**Estimated Savings**: 10% CPU usage reduction, lower network traffic

**Effort**: 1 day (implement webhook endpoint, configure Caddy)

**Status**: CONSIDER for v1.1 (worthwhile optimization)

---

### 6. Auto-Generated Passwords (install.sh)

**Current**: `openssl rand -base64 32` (requires openssl CLI)

**Alternative**: Pure bash random password generation

**Rationale**: openssl is 3MB dependency. Can use `/dev/urandom` + bash for password generation (equally secure for 32-char alphanumeric).

**Estimated Savings**: Eliminate openssl dependency (3MB)

**Effort**: 0.5 days (replace openssl with bash script)

**Status**: LOW PRIORITY (openssl already present on most systems)

---

### 7. JSON Schema Validation (Bot Container)

**Current**: No validation library (manual checks in code)

**Opportunity**: Avoid adding validation libraries (jsonschema, pydantic)

**Rationale**: wg-easy API responses are well-formed (trusted source). Manual validation with `isinstance()` and `hasattr()` sufficient for MVP. Adding validation library (1MB+) unnecessary complexity.

**Estimated Savings**: Prevent 1MB dependency creep

**Effort**: 0 (already avoided)

**Status**: ✅ PREVENTED (good discipline)

---

### 8. Logging Framework (Bot Container)

**Current**: Stdlib `logging` module

**Opportunity**: Avoid heavy logging frameworks (loguru, structlog)

**Rationale**: Stdlib `logging` sufficient for MVP (stdout logs captured by Docker). Advanced features (structured logs, log aggregation) deferred to monitoring solution (Loki in STRETCH). Keep logging simple.

**Estimated Savings**: Prevent 2MB dependency creep

**Effort**: 0 (already avoided)

**Status**: ✅ PREVENTED (good discipline)

---

## Non-Essential Features (Future Removal Candidates)

### 1. Client Naming Feature (STRETCH)

**Current**: Not implemented (users get auto-generated names like `user_123_1730000000`)

**Future Risk**: If implemented, will add UI complexity (name validation, uniqueness checks, renaming logic)

**Prevention**: Keep names auto-generated (user_id + timestamp). No custom naming in MVP.

**Status**: ✅ PREVENTED

---

### 2. Traffic Statistics Dashboard (STRETCH)

**Current**: Not implemented

**Future Risk**: If implemented, will require timeseries DB (InfluxDB 50MB+), Grafana (200MB+), data collection agent

**Prevention**: Use wg-easy's built-in stats (available via API). No separate dashboard in MVP.

**Status**: ✅ PREVENTED (defer to v2.0+)

---

### 3. Multi-User Admin Roles (STRETCH)

**Current**: Single admin (WG_PASSWORD holder)

**Future Risk**: If implemented, will require user management DB, role-based access control, permission checks

**Prevention**: Keep single-admin model. Use OS-level access control (who can access .env file) for delegation.

**Status**: ✅ PREVENTED (defer to v2.0+)

---

## Dependencies Audit

### Bot Container (Current)

```
python:3.11-slim (base image)
├── python-telegram-bot (~3.5MB) ← CANDIDATE for removal
├── requests (~1MB)
├── qrcode (~500KB) ← CANDIDATE for removal
│   └── pillow (~5MB) ← HEAVY DEPENDENCY
├── python-dotenv (~50KB)
└── Total: ~10MB dependencies
```

**Target**: <5MB dependencies (remove pillow + qrcode, use wg-easy QR endpoint)

---

### wg-easy Container (Current)

```
ghcr.io/wg-easy/wg-easy:latest
├── Node.js runtime (~50MB)
├── Web UI assets (~10MB) ← CANDIDATE for removal (if API-only mode)
├── WireGuard tools (~5MB)
└── Total: ~65MB (official image, minimal)
```

**Target**: Accept current size (official image well-optimized)

---

### Install Script (install.sh)

**Dependencies**:
- `curl` (for external IP detection) ← ESSENTIAL
- `openssl` (for password generation) ← CANDIDATE for removal
- `docker` CLI ← ESSENTIAL
- `docker compose` CLI ← ESSENTIAL

**Target**: Keep essential tools only

---

## Deletion Review Process

**Monthly Review** (starting v1.1):

1. **Measure footprint**: Run `docker images` and `docker stats`
2. **Identify bloat**: Compare against targets (<1GB total for VPN services)
3. **Prioritize deletions**: HIGH priority candidates first
4. **Implement**: 1 deletion per sprint (avoid breaking changes)
5. **Test**: Ensure all acceptance criteria still pass
6. **Document**: Update this file with results

---

## Success Metrics

**Current State (MVP v1.0 estimated)**:
- wg-easy container: 65MB
- vpnTelegram container: 50MB (python:3.11-slim + deps)
- Total: 115MB

**Target State (v1.1 after optimizations)**:
- wg-easy container: 65MB (no change)
- vpnTelegram container: 35MB (remove qrcode+pillow)
- Total: 100MB

**Stretch Goal (v2.0)**:
- Total: <80MB (API-only wg-easy variant + minimal bot)

---

## Removal Guidelines

**Before removing any code/dependency**:

1. ✅ **Verify unused**: Check references via `rg` or IDE search
2. ✅ **Test removal**: Run full test suite on branch
3. ✅ **Document rationale**: Update this file
4. ✅ **Commit separately**: One deletion per commit
5. ✅ **Monitor metrics**: Confirm footprint reduction

**If removal breaks something**:

- Revert immediately
- Document why it was needed
- Move to "Attempted Deletions (Failed)" section

---

## Attempted Deletions (Failed) - Track Mistakes

*Empty for now - will populate as we learn what's truly essential*

---

## References

- **Suckless Philosophy**: https://suckless.org/philosophy/
- **Docker Best Practices**: https://docs.docker.com/develop/dev-best-practices/
- **Alpine Linux** (minimal base images): https://alpinelinux.org/
- **Python Slim Images**: https://hub.docker.com/_/python (3.11-slim is 45MB vs 3.11-alpine 17MB)

---

## Continuous Improvement

**Every feature addition requires**:

1. **Justify existence**: What problem does this solve?
2. **Measure footprint**: How much does this add? (MB, LOC, dependencies)
3. **Explore alternatives**: Can we do this with existing tools?
4. **Plan deletion**: When can this be removed? (version N+1, N+2)

**Philosophy**: Every line of code is a liability. Minimize liabilities.
