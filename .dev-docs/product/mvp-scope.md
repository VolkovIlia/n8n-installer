# MVP Scope - VPN Integration

## RICE Prioritization Framework

**RICE Formula**: (Reach × Impact × Confidence) / Effort

### Scoring Definitions

**Reach**: How many users affected per time period
- 100 = All users (administrator + all clients)
- 50 = Half of users (administrator or clients only)
- 10 = Small subset (power users, specific use case)

**Impact**: Value delivered to users
- 3 = Massive impact (core functionality, critical blocker)
- 2 = High impact (major improvement, significant time saved)
- 1 = Medium impact (nice to have, moderate improvement)
- 0.5 = Low impact (minor convenience, edge case)
- 0.25 = Minimal impact (cosmetic, rarely used)

**Confidence**: Certainty of estimates (0-100%)
- 100% = High confidence (proven technology, clear requirements)
- 80% = Medium confidence (some unknowns, research done)
- 50% = Low confidence (experimental, needs validation)

**Effort**: Person-months to implement
- 0.5 = 1-2 days
- 1 = 1 week
- 2 = 2 weeks
- 4 = 1 month

---

## CORE (Must Have - v0.1)

**Goal**: Working VPN installation with basic Telegram bot management through n8n-installer menu

| ID | Feature | Reach | Impact | Confidence | Effort | RICE Score | Priority |
|----|---------|-------|--------|------------|--------|------------|----------|
| C-001 | Docker Compose integration | 100 | 3 | 100% | 1 | **300** | P0 |
| C-002 | wg-easy container setup | 100 | 3 | 90% | 2 | **135** | P0 |
| C-003 | vpnTelegram bot container | 100 | 3 | 80% | 3 | **80** | P0 |
| C-004 | Installation menu option | 100 | 2 | 100% | 1 | **200** | P0 |
| C-005 | Basic bot commands (/start, /request) | 100 | 3 | 90% | 2 | **135** | P0 |
| C-006 | QR code generation | 100 | 3 | 100% | 1 | **300** | P0 |
| C-007 | wg-easy UI access | 50 | 2 | 100% | 0.5 | **200** | P0 |
| C-008 | Environment variable config | 100 | 2 | 100% | 0.5 | **400** | P0 |
| C-009 | Network isolation (vpn_network) | 100 | 2 | 80% | 1 | **160** | P0 |
| C-010 | Health checks for containers | 100 | 1 | 100% | 0.5 | **200** | P0 |

**Total Effort**: 12.5 person-days (~2.5 weeks)

**Critical Path**: C-001 → C-002 → C-003 → C-005 → C-006

**Success Criteria**:
- ✅ Administrator can install VPN via menu in <10 minutes
- ✅ Client can receive VPN config via Telegram bot
- ✅ VPN connection works from test client
- ✅ n8n services remain healthy after VPN installation

---

## MVP (Should Have - v1.0)

**Goal**: Production-ready VPN with enhanced security, monitoring, and user management

| ID | Feature | Reach | Impact | Confidence | Effort | RICE Score | Priority |
|----|---------|-------|--------|------------|--------|------------|----------|
| M-001 | Bot user whitelist | 50 | 2 | 80% | 1 | **80** | P1 |
| M-002 | Config revocation command (/revoke) | 50 | 2 | 90% | 1 | **90** | P1 |
| M-003 | Status check command (/status) | 50 | 1 | 90% | 0.5 | **90** | P1 |
| M-004 | Auto-generated strong passwords | 100 | 1 | 100% | 0.5 | **200** | P1 |
| M-005 | Port conflict detection | 100 | 2 | 80% | 1 | **160** | P1 |
| M-006 | External IP auto-detection | 100 | 2 | 70% | 1 | **140** | P1 |
| M-007 | Installation logs | 100 | 1 | 100% | 0.5 | **200** | P1 |
| M-008 | Uninstall script | 50 | 1 | 100% | 1 | **50** | P1 |
| M-009 | Basic monitoring dashboard | 50 | 1 | 70% | 2 | **17.5** | P2 |
| M-010 | Resource usage alerts | 50 | 1 | 80% | 1 | **40** | P2 |
| M-011 | Client connection logs | 50 | 0.5 | 90% | 1 | **22.5** | P2 |
| M-012 | Documentation (install + user guide) | 100 | 1 | 100% | 2 | **50** | P1 |

**Total Effort**: 12 person-days (~2.5 weeks)

**Success Criteria**:
- ✅ Administrator can revoke client access via bot
- ✅ Installation detects and handles port conflicts
- ✅ Auto-generated passwords meet security standards
- ✅ Documentation covers installation and usage

---

## STRETCH (Could Have - v2.0+)

**Goal**: Advanced features for power users and large deployments

| ID | Feature | Reach | Impact | Confidence | Effort | RICE Score | Priority |
|----|---------|-------|--------|------------|--------|------------|----------|
| S-001 | Multi-user admin (role-based access) | 10 | 2 | 60% | 4 | **3** | P3 |
| S-002 | Bandwidth limits per client | 10 | 1 | 70% | 2 | **3.5** | P3 |
| S-003 | Traffic statistics dashboard | 50 | 1 | 60% | 4 | **7.5** | P3 |
| S-004 | Automatic config expiration | 50 | 0.5 | 80% | 2 | **10** | P3 |
| S-005 | Client naming/tagging | 50 | 0.5 | 90% | 1 | **22.5** | P3 |
| S-006 | Backup/restore configs | 50 | 1 | 70% | 2 | **17.5** | P3 |
| S-007 | Email notifications | 10 | 0.5 | 50% | 2 | **1.25** | P4 |
| S-008 | Web-based bot interface | 10 | 1 | 50% | 4 | **1.25** | P4 |
| S-009 | Multiple VPN servers | 10 | 2 | 40% | 8 | **1** | P4 |
| S-010 | Advanced firewall rules | 10 | 1 | 50% | 3 | **1.67** | P4 |
| S-011 | Integration with n8n workflows | 50 | 2 | 40% | 6 | **6.67** | P3 |
| S-012 | Automatic client onboarding flow | 50 | 1 | 50% | 4 | **6.25** | P3 |

**Total Effort**: 38 person-days (~7.5 weeks)

**Success Criteria**:
- ✅ Power users can manage multiple clients efficiently
- ✅ Traffic monitoring provides insights
- ✅ System scales to 50+ clients

---

## MoSCoW Analysis (Sanity Check)

### Must Have (CORE)
- Docker Compose integration ✅
- wg-easy + vpnTelegram containers ✅
- Installation menu option ✅
- Basic bot commands (/start, /request) ✅
- QR code generation ✅
- Network isolation ✅

### Should Have (MVP)
- User whitelist 🟡
- Config revocation 🟡
- Port conflict detection 🟡
- Documentation 🟡
- Uninstall script 🟡

### Could Have (STRETCH)
- Traffic statistics 🟢
- Bandwidth limits 🟢
- Multi-user admin 🟢
- n8n workflow integration 🟢

### Won't Have (Out of Scope)
- ❌ Multi-protocol support (only WireGuard)
- ❌ GUI installer (CLI/menu only)
- ❌ Mobile admin app
- ❌ Integration with external auth providers (LDAP, OAuth)
- ❌ Commercial support
- ❌ SaaS offering

---

## Kano Model Analysis

### Basic Needs (Must be present, expected by users)
- VPN installation works ✅
- Telegram bot responds ✅
- Configs are generated ✅
- Connection is secure ✅
- n8n doesn't break ✅

**Status**: All covered in CORE

### Performance Needs (More is better, linear satisfaction)
- Installation speed (faster = better) 🟡 CORE
- Bot response time (faster = better) 🟡 CORE
- VPN throughput (higher = better) 🟡 CORE
- Number of supported clients (more = better) 🟢 MVP

### Excitement Needs (Unexpected features that delight)
- Auto-generated strong passwords 🎉 MVP
- External IP auto-detection 🎉 MVP
- n8n workflow integration 🎉 STRETCH
- Traffic visualization dashboard 🎉 STRETCH

**Insight**: Focus on Basic + Performance for CORE/MVP. Add Excitement features in STRETCH for differentiation.

---

## Release Plan

### Sprint 1 (Week 1-2): CORE Implementation
**Goal**: Working VPN installation via menu

**Tasks**:
- C-001: Docker Compose integration (2 days)
- C-002: wg-easy setup (3 days)
- C-003: vpnTelegram bot setup (4 days)
- C-004: Installation menu (1 day)

**Deliverables**:
- docker-compose.yml with VPN services
- Installation script modifications
- Basic bot functionality

**Gate**: Manual installation works end-to-end

---

### Sprint 2 (Week 3-4): CORE + MVP Essentials
**Goal**: Production-ready with security + monitoring

**Tasks**:
- C-005-C-010: Remaining CORE features (3 days)
- M-001-M-008: Critical MVP features (7 days)

**Deliverables**:
- Bot commands: /request, /revoke, /status
- Port conflict detection
- Auto-generated passwords
- Uninstall script

**Gate**: All CORE acceptance criteria pass

---

### Sprint 3 (Week 5-6): MVP Polish + Documentation
**Goal**: User-ready with complete docs

**Tasks**:
- M-009-M-011: Monitoring features (4 days)
- M-012: Documentation (2 days)
- Testing + bug fixes (4 days)

**Deliverables**:
- Installation guide
- User guide
- Bot command reference
- Production-tested build

**Gate**: Documentation complete, no critical bugs

---

### Post-MVP: STRETCH Features (Backlog)
**Prioritization**: Based on user feedback

**High-value STRETCH** (consider for v1.1):
- S-005: Client naming/tagging (RICE: 22.5)
- S-006: Backup/restore (RICE: 17.5)
- S-011: n8n integration (RICE: 6.67)

**Low-value STRETCH** (defer to v2.0+):
- S-009: Multiple VPN servers (RICE: 1)
- S-007: Email notifications (RICE: 1.25)
- S-008: Web interface (RICE: 1.25)

---

## Scope Control Rules

### Add Feature Criteria
Feature must meet ALL of:
1. **RICE score > 50** for MVP
2. **Effort < 2 weeks** for single sprint
3. **No new dependencies** (use existing Docker + Telegram)
4. **Aligns with goal** (bypass geo-blocks, not enterprise VPN)

### Remove Feature Criteria
Feature can be removed if:
1. **RICE score < 10** (low value)
2. **Technical blocker** (library not available, security risk)
3. **Scope creep** (adds >1 week to timeline)

### Scope Change Process
1. Calculate RICE score for new feature
2. Compare against backlog (lowest-priority MVP item)
3. If new_RICE > backlog_RICE: Swap
4. If new_RICE < backlog_RICE: Defer to STRETCH

---

## Dependencies & Risks

### Dependencies
- **External**: Telegram API, wg-easy image, WireGuard kernel module
- **Internal**: n8n-installer structure, docker-compose.yml format

### Risks
- **R-001**: Telegram blocked in Russia (Probability: MEDIUM, Impact: HIGH)
  - **Mitigation**: Document manual QR code export from wg-easy UI
  - **RICE adjustment**: If blocked, bot features drop to P2

- **R-002**: Port conflicts on target servers (Probability: LOW, Impact: MEDIUM)
  - **Mitigation**: Port conflict detection (M-005)
  - **Covered in**: MVP scope

- **R-003**: Resource exhaustion on small servers (Probability: LOW, Impact: HIGH)
  - **Mitigation**: Resource limits in docker-compose.yml
  - **Covered in**: CORE scope (C-002, C-003)

---

## RICE Score Summary

**CORE Average**: 213 (High Priority)
**MVP Average**: 93 (Medium Priority)
**STRETCH Average**: 6.6 (Low Priority)

**Confidence**: CORE = 92%, MVP = 84%, STRETCH = 57%

**Recommendation**: Focus on CORE + high-RICE MVP features (M-001 to M-008). Defer monitoring (M-009 to M-011) to post-MVP if timeline is tight.

---

## Final Scope Definition

### v0.1 CORE (Must Ship)
- Docker integration ✅
- wg-easy + bot containers ✅
- Menu installation ✅
- Basic bot (/start, /request) ✅
- QR code generation ✅
- Network isolation ✅
- Health checks ✅
- Environment config ✅

**Timeline**: 2.5 weeks
**Team**: 1 engineer

---

### v1.0 MVP (Production Release)
- All CORE features ✅
- Bot user whitelist ✅
- Config revocation ✅
- Status checks ✅
- Security hardening ✅
- Port conflict detection ✅
- IP auto-detection ✅
- Documentation ✅
- Uninstall script ✅

**Timeline**: +2.5 weeks (5 weeks total)
**Team**: 1 engineer + 1 technical writer (docs)

---

### v2.0+ STRETCH (Future Enhancements)
- Traffic monitoring
- Bandwidth controls
- n8n integration
- Advanced admin features

**Timeline**: TBD based on user feedback
**Team**: TBD
