# ADR-0006: Password Authentication (MVP) over JWT Tokens

**Status**: Accepted (MVP), Deferred (JWT for v2.0)
**Date**: 2025-11-01
**Decision Maker**: AI Solutions Architect

## Decision
Use simple password authentication (WG_PASSWORD + BOT_WHITELIST) for MVP v1.0. Defer JWT-based capability tokens to v2.0.

## Rationale
MVP timeline (5 weeks) requires shipping working solution fast. Password auth leverages existing wg-easy session management (no custom implementation needed), Telegram Bot API automatic user ID verification (no additional auth code), and simple .env file secrets management (operators already familiar). JWT implementation would add 2 weeks (token generation, verification, refresh logic, revocation list, scope enforcement) for minimal MVP value. Security sufficient for personal VPN (not enterprise multi-tenant).

## Trade-offs
**Gain**: Faster MVP delivery (0 weeks vs 2 weeks for JWT), simpler codebase (no token management), leverage existing wg-easy auth, adequate security for personal use
**Cost**: No fine-grained permissions (admin has full access), no token expiration (password rotation manual), no audit trail for individual operations (only command-level logs), harder to integrate with MCP in future (but v2.0 planned)

## Alternatives Considered
- **JWT from start**: Rejected due to timeline constraints and over-engineering for personal VPN
- **API keys**: Rejected due to similar complexity to JWT without standard tooling
- **OAuth2**: Rejected due to massive complexity for single-user scenario

## Migration Plan
v2.0 implements JWT capability system (see capabilities/security-model.md Future section). Migration path: Keep password auth for backward compatibility, add JWT as opt-in, gradual migration (estimated 1 week effort).
