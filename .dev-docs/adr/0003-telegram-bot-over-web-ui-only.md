# ADR-0003: Telegram Bot over Web UI Only

**Status**: Accepted
**Date**: 2025-11-01
**Decision Maker**: AI Solutions Architect

## Decision
Provide Telegram bot for client VPN config distribution alongside wg-easy web UI, instead of web UI alone.

## Rationale
Target users (Russian clients) prefer Telegram for quick access without navigating to web URLs. Bot enables self-service (no admin intervention), instant config delivery (QR code + .conf file in 2 seconds), and mobile-first workflow (scan QR directly). Web UI still available for administrators (full control, view all clients). Bot reduces support burden (users request configs independently) and improves UX (no password sharing needed).

## Trade-offs
**Gain**: Better user experience, faster onboarding (<5 min), reduced admin workload, mobile-optimized workflow
**Cost**: Additional container (256MB RAM), Telegram API dependency (risk if blocked - see A2), bot development effort (2 weeks vs 0 for UI-only), requires BOT_TOKEN management

## Alternatives Considered
- **Web UI only**: Rejected due to poor mobile UX and admin bottleneck
- **Discord bot**: Considered but Telegram more popular in Russia
- **Email-based**: Rejected due to complexity and spam risk

## Mitigation
If Telegram blocked (Hypothesis A2): Fallback to wg-easy UI + manual QR code export + email/file sharing (documented in runbook).
