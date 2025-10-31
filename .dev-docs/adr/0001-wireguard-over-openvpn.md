# ADR-0001: WireGuard over OpenVPN

**Status**: Accepted
**Date**: 2025-11-01
**Decision Maker**: AI Solutions Architect

## Decision
Use WireGuard protocol instead of OpenVPN for VPN implementation.

## Rationale
WireGuard offers superior performance (4x faster), simpler configuration (200 lines vs 4000), native kernel support in Linux ≥5.6, and modern cryptography (ChaCha20-Poly1305). OpenVPN requires userspace daemon, complex certificate management, and larger resource footprint (512MB vs 256MB). WireGuard's stateless protocol reduces attack surface and simplifies debugging.

## Trade-offs
**Gain**: Better performance, minimal configuration, lower resource usage, easier troubleshooting
**Cost**: Less mature ecosystem (fewer GUI clients for older platforms), requires kernel ≥5.6 (fallback to wireguard-go available), not yet proven at scale in Russia geo-block bypass (requires pilot testing)

## Alternatives Considered
- **OpenVPN**: Rejected due to complexity and resource overhead
- **Shadowsocks**: Rejected due to lack of standard client apps
- **V2Ray**: Rejected due to configuration complexity

## Validation
Pilot test from Russian IP required to confirm bypass effectiveness (Hypothesis A1).
