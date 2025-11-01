# ADR-0002: wg-easy over Raw WireGuard CLI

**Status**: Accepted
**Date**: 2025-11-01
**Decision Maker**: AI Solutions Architect

## Decision
Use wg-easy Docker image for WireGuard management instead of raw `wg` CLI commands.

## Rationale
wg-easy provides HTTP API (enables Telegram bot integration), web UI (admin convenience), automatic QR code generation, and client lifecycle management. Raw `wg` CLI requires custom scripting for client creation, manual QR generation, and no built-in UI. wg-easy is production-ready (15k+ GitHub stars), actively maintained, and includes session management for security.

## Trade-offs
**Gain**: Faster development (no custom scripts), built-in UI, HTTP API for bot, QR code generation included, active community support
**Cost**: Additional container (256MB RAM), dependency on third-party project (mitigated by adapter pattern), slightly slower than direct CLI (negligible for <100 clients)

## Alternatives Considered
- **Raw wg CLI + custom scripts**: Rejected due to 3+ weeks additional development time
- **WireGuard UI (other projects)**: Evaluated but wg-easy has best API documentation

## Replaceability
Bot uses `IVPNProvider` interface → Can swap to `WireGuardCLIAdapter` if wg-easy fails (2 days effort, see adapters/registry.md).
