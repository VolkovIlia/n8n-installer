# ADR-0004: Docker Compose over Kubernetes

**Status**: Accepted
**Date**: 2025-11-01
**Decision Maker**: AI Solutions Architect

## Decision
Use Docker Compose for VPN service orchestration instead of Kubernetes.

## Rationale
Target deployment is single-server personal infrastructure (not multi-node cluster). Docker Compose provides single-command deployment (`docker compose up -d`), zero learning curve for n8n-installer users (already using Compose), minimal resource overhead (no control plane), and simple troubleshooting (`docker logs`). Kubernetes would add 2GB+ RAM for control plane, steep learning curve, and over-engineering for 1-2 containers. MVP requires simplicity over scalability.

## Trade-offs
**Gain**: Simplicity, fast deployment (<10 min), low resource usage, familiar tooling, easy rollback
**Cost**: No horizontal scaling (not needed for personal VPN), no advanced scheduling (not needed), manual multi-server coordination (out of scope), no built-in service mesh (not needed)

## Alternatives Considered
- **Kubernetes**: Rejected due to complexity and resource overhead for single-server deployment
- **Docker Swarm**: Rejected due to declining community support
- **Nomad**: Rejected due to unfamiliar tooling for target users

## Migration Path
If scaling needed (>1 server): Can convert to Kubernetes via adapter pattern (see adapters/registry.md `DockerComposeAdapter` → `KubernetesAdapter`, estimated 3 days effort).
