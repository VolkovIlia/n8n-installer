# VPN Integration - Acceptance Criteria

## Core Acceptance Criteria

### AC-001: Install VPN via Installer Menu
**Story**: As a system administrator, I want to install VPN with Telegram bot via installation menu, so that I can provide secure access bypassing geographical restrictions

**INVEST Checklist**:
- ✅ Independent: Can be developed separately from other n8n features
- ✅ Negotiable: Implementation details (port numbers, container names) can be discussed
- ✅ Valuable: Provides critical access bypass for Russian users
- ✅ Estimable: 3-5 days estimated
- ✅ Small: Fits in one sprint
- ✅ Testable: Clear acceptance criteria below

**Acceptance Criteria (Gherkin)**:

**Scenario 1: Menu Option Appears**
```gherkin
Given n8n-installer is running
When user navigates to installation menu
Then "Install VPN + Telegram bot" option is visible
And option shows description "WireGuard VPN with Telegram management"
```

**Scenario 2: Successful Installation**
```gherkin
Given user selected "Install VPN + Telegram bot"
When installation completes
Then docker-compose.yml contains wg-easy service definition
And docker-compose.yml contains vpnTelegram service definition
And both containers are running (docker ps shows healthy status)
And confirmation message displays wg-easy UI URL (https://{server-ip}:51821)
And confirmation message displays Telegram bot username
```

**Scenario 3: No Conflict with Existing Services**
```gherkin
Given n8n services are already running
When VPN installation completes
Then n8n container remains healthy
And postgres container remains healthy
And all existing services continue responding
And no port conflicts reported
```

**Negative Cases**:
```gherkin
Given port 51821 is already in use
When VPN installation is attempted
Then installation fails with error message
And error suggests alternative port configuration
And rollback occurs (no partial installation)
```

---

### AC-002: wg-easy Web UI Access
**Story**: As an administrator, I want to access wg-easy web UI, so that I can manage WireGuard configurations visually

**Acceptance Criteria (Gherkin)**:

**Scenario 1: UI Accessible**
```gherkin
Given wg-easy container is running
When I navigate to https://{server-ip}:51821
Then wg-easy login page is displayed
And page loads within 3 seconds
```

**Scenario 2: Client Creation**
```gherkin
Given I am logged into wg-easy UI
When I create new client "test_client"
Then QR code is generated
And configuration file is downloadable
And client appears in active clients list
```

**Scenario 3: Client Deletion**
```gherkin
Given client "test_client" exists
When I delete the client
Then client is removed from list
And VPN tunnel disconnects if active
```

**Negative Cases**:
```gherkin
Given wg-easy UI password is incorrect
When I attempt to login
Then error 401 is returned
And login form shows "Invalid credentials"
```

---

### AC-003: Telegram Bot Integration
**Story**: As a client, I want to request VPN access via Telegram bot, so that I can receive configuration without manual coordination

**Acceptance Criteria (Gherkin)**:

**Scenario 1: Bot Responds to /start**
```gherkin
Given vpnTelegram bot is running
When user sends /start command
Then bot responds with welcome message
And bot displays available commands
And response time is <2 seconds
```

**Scenario 2: VPN Config Request**
```gherkin
Given user is authenticated via Telegram
When user requests VPN configuration
Then bot generates new WireGuard client
And bot sends QR code image
And bot sends configuration file (.conf)
And configuration works on WireGuard client
```

**Scenario 3: Access Revocation**
```gherkin
Given user has active VPN configuration
When administrator revokes access
Then bot notifies user of revocation
And VPN connection is terminated
And user receives instructions for re-requesting access
```

**Negative Cases**:
```gherkin
Given bot token is invalid
When bot starts
Then container logs show authentication error
And bot does not respond to messages
And health check fails
```

---

### AC-004: Docker Compose Integration
**Story**: As a system administrator, I want VPN services integrated into docker-compose.yml, so that they start/stop with other services

**Acceptance Criteria (Gherkin)**:

**Scenario 1: Services Defined**
```gherkin
Given VPN installation completed
When I inspect docker-compose.yml
Then wg-easy service is defined with:
  - image: ghcr.io/wg-easy/wg-easy
  - ports: 51820:51820/udp, 51821:51821/tcp
  - volumes: wg_data
  - capabilities: NET_ADMIN, SYS_MODULE
And vpnTelegram service is defined with:
  - image: vpn-telegram-bot
  - environment: BOT_TOKEN, WG_HOST
  - depends_on: wg-easy
```

**Scenario 2: Network Isolation**
```gherkin
Given VPN services are running
When I inspect Docker networks
Then wg-easy is on dedicated vpn_network
And vpn_network does not overlap with n8n_network
And inter-service communication works via bridge
```

**Scenario 3: Persistence**
```gherkin
Given VPN services are stopped
When I run docker-compose up -d
Then wg-easy volume preserves client configurations
And Telegram bot reconnects to Telegram API
And all previous clients remain configured
```

---

### AC-005: Security Requirements
**Story**: As a security-conscious administrator, I want VPN services to follow security best practices, so that I minimize attack surface

**Acceptance Criteria (Gherkin)**:

**Scenario 1: Environment Variables**
```gherkin
Given installation script runs
When VPN services are configured
Then WG_PASSWORD is generated randomly (32 characters)
And BOT_TOKEN is read from user input (not hardcoded)
And sensitive values are stored in .env file
And .env file is in .gitignore
```

**Scenario 2: Telegram Authentication**
```gherkin
Given bot receives VPN request
When user is not authenticated
Then bot requests Telegram username verification
And bot checks against whitelist (if configured)
And unauthenticated users receive error message
```

**Scenario 3: wg-easy UI Protection**
```gherkin
Given wg-easy UI is exposed
When attacker attempts brute force
Then rate limiting is enforced (max 5 attempts/minute)
And failed attempts are logged
And UI requires HTTPS (no HTTP fallback)
```

---

## Non-Functional Acceptance Criteria

### Performance
- VPN installation completes in <10 minutes
- VPN throughput: >100 Mbps per client
- Bot response time: <2 seconds for config generation
- wg-easy UI loads in <3 seconds

### Reliability
- VPN uptime: >95% over 30 days
- Container restarts automatically on failure
- Health checks pass every 30 seconds
- No data loss on container restart

### Resource Constraints
- wg-easy max RAM: 512 MB
- vpnTelegram max RAM: 256 MB
- Combined CPU usage: <25% on 8-core server
- Disk space: <500 MB for VPN services

### Compatibility
- Works with n8n-installer versions ≥1.0
- Compatible with Ubuntu 20.04+ / Debian 11+
- Docker version ≥20.10
- Docker Compose version ≥2.0

---

## Edge Cases and Error Handling

### Edge Case 1: Server Behind NAT
```gherkin
Given server is behind NAT
When VPN is installed
Then installation detects external IP via STUN
And wg-easy is configured with external IP
And warning is displayed about port forwarding requirement
```

### Edge Case 2: Telegram Bot Rate Limiting
```gherkin
Given bot receives 100+ requests simultaneously
When Telegram API rate limit is reached
Then bot queues requests
And users receive "Processing, please wait" message
And requests are processed within 5 minutes
```

### Edge Case 3: Disk Space Exhausted
```gherkin
Given disk space drops below 1GB
When new client is created
Then creation fails gracefully
And administrator receives disk space alert
And existing clients continue working
```

---

## Acceptance Gates

**Gate 1: Installation**
- [ ] All AC-001 scenarios pass
- [ ] Installation completes in <10 minutes
- [ ] No errors in docker logs

**Gate 2: Functionality**
- [ ] All AC-002, AC-003, AC-004 scenarios pass
- [ ] VPN connection works from test client
- [ ] Telegram bot responds to all commands

**Gate 3: Security**
- [ ] All AC-005 scenarios pass
- [ ] No hardcoded secrets in code
- [ ] wg-easy UI requires authentication

**Gate 4: Integration**
- [ ] Existing n8n services remain healthy
- [ ] No port conflicts
- [ ] Resource usage within limits

**Final Gate: Production Readiness**
- [ ] All gates 1-4 passed
- [ ] Documentation complete
- [ ] Rollback tested successfully
