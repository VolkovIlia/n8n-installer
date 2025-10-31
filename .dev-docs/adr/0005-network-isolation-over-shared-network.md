# ADR-0005: Network Isolation over Shared Network

**Status**: Accepted
**Date**: 2025-11-01
**Decision Maker**: AI Solutions Architect

## Decision
Create separate `vpn_network` (172.21.0.0/16) for VPN services instead of sharing `n8n_network`.

## Rationale
Complete network isolation prevents VPN service failures from affecting n8n (critical availability requirement). Separate networks enable independent firewall rules (only 51820/51821 exposed for VPN), reduce blast radius of container breakout attacks, and allow independent resource monitoring. Shared network would risk port conflicts (wg-easy port 51821 vs potential n8n services) and complicate security audits (unclear trust boundaries).

## Trade-offs
**Gain**: Fault isolation (VPN crash doesn't affect n8n), security isolation (separate attack surface), clear network boundaries (easier firewall rules), independent monitoring
**Cost**: Slightly more complex docker-compose.yml (1 extra network definition), minimal performance overhead (<1ms latency for inter-network communication if needed), requires subnet planning (avoid IP overlap)

## Alternatives Considered
- **Shared n8n_network**: Rejected due to tight coupling and security risks
- **Host networking**: Rejected due to lack of isolation and port conflict risk
- **Overlay network**: Rejected due to unnecessary complexity for single host

## Implementation
Subnet allocation: n8n_network uses 172.20.0.0/16 (existing), vpn_network uses 172.21.0.0/16 (new), no overlap with common private ranges (192.168.x.x used by home routers).
