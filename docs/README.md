# VPN Integration Documentation

## Overview

This directory contains technical documentation for the VPN integration feature in n8n-installer. The VPN integration provides WireGuard-based VPN capabilities through a Telegram bot interface.

## Documentation Structure

### API Documentation (`api/`)
- **[wg-easy-api.md](api/wg-easy-api.md)** - wg-easy HTTP API reference
- **[telegram-bot-api.md](api/telegram-bot-api.md)** - Telegram bot command reference

### Architecture Documentation (`architecture/`)
- **[system-overview.md](architecture/system-overview.md)** - High-level system architecture
- **[message-flows.md](architecture/message-flows.md)** - Message flow diagrams with annotations
- **[security-model.md](architecture/security-model.md)** - Authentication and authorization model

### Developer Guides (`developer/`)
- **[contributing.md](developer/contributing.md)** - How to extend the bot
- **[architecture-decisions.md](developer/architecture-decisions.md)** - ADRs with rationale
- **[testing.md](developer/testing.md)** - Test strategy and guidelines

### Troubleshooting
- **[troubleshooting.md](troubleshooting.md)** - Common issues and solutions

## Quick Links

### For Developers
- Start with [system-overview.md](architecture/system-overview.md) to understand the architecture
- Read [contributing.md](developer/contributing.md) to learn how to extend the bot
- Check [architecture-decisions.md](developer/architecture-decisions.md) for design rationale

### For Operations
- See [troubleshooting.md](troubleshooting.md) for common issues
- Review [security-model.md](architecture/security-model.md) for security controls

### For API Integration
- Use [wg-easy-api.md](api/wg-easy-api.md) for HTTP API reference
- Use [telegram-bot-api.md](api/telegram-bot-api.md) for bot commands

## Target Audience

This documentation is written for developers who will maintain, extend, or integrate with the VPN system. For end-user documentation, see `.dev-docs/user-guide/`.

## Related Documentation

- **Product Requirements**: `.dev-docs/product/` - Acceptance criteria, user stories, MVP scope
- **Architecture Specs**: `.dev-docs/` - Contracts, diagrams, capabilities
- **Code Review**: `.dev-docs/CODE_REVIEW_REPORT.md` - Code quality and suckless compliance
- **QA Report**: `.dev-docs/QA_TEST_REPORT.md` - Test results and validation

## Documentation Standards

- All code examples are tested and working
- All diagrams use Mermaid format
- All API endpoints include request/response examples
- All troubleshooting steps include verification commands
