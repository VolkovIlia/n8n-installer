# User Stories - VPN Integration

## Epic: VPN Installation and Management via n8n-installer

**Epic Goal**: Enable administrator to install and manage WireGuard VPN with Telegram bot for bypassing geographical restrictions in Russian Federation

**Success Metrics**:
- Installation time <10 minutes
- Client receives working config in <5 minutes via bot
- VPN connection success rate >95%
- n8n services remain 100% operational

---

## CORE Stories (v0.1)

### Story 1: Install VPN via Menu
**ID**: VPN-001
**Priority**: P0 (CORE)
**RICE Score**: 200
**Estimate**: 5 story points (1 week)

**As a** system administrator
**I want** to see "Install VPN + Telegram bot" option in n8n-installer menu
**So that** I can add VPN capability to my n8n installation without manual Docker configuration

**Acceptance Criteria**:
1. ✅ Menu displays option after successful n8n installation
2. ✅ Option shows clear description: "WireGuard VPN with Telegram management"
3. ✅ Selection prompts for Telegram bot token
4. ✅ Selection prompts for optional custom ports
5. ✅ Installation completes in <10 minutes
6. ✅ Confirmation message displays:
   - wg-easy UI URL (https://{server-ip}:51821)
   - Telegram bot username
   - Auto-generated wg-easy password
   - Next steps for testing

**Technical Notes**:
- Modify `install.sh` to add menu option after n8n setup
- Call new script `install-vpn.sh` on selection
- Validate bot token format before proceeding
- Update docker-compose.yml via script (not manual edit)

**INVEST Checklist**:
- ✅ **Independent**: Can be developed separately from bot features
- ✅ **Negotiable**: Port numbers, prompts can be adjusted
- ✅ **Valuable**: Core installation capability
- ✅ **Estimable**: Similar to existing install scripts
- ✅ **Small**: Fits in one sprint
- ✅ **Testable**: Manual installation can be tested

**Edge Cases**:
- User cancels during bot token prompt → Exit cleanly
- Installation fails mid-process → Rollback docker-compose changes
- Server has no internet → Fail fast with error message

---

### Story 2: Docker Compose Integration
**ID**: VPN-002
**Priority**: P0 (CORE)
**RICE Score**: 300
**Estimate**: 3 story points (3 days)

**As a** system administrator
**I want** VPN services to be defined in docker-compose.yml
**So that** they start/stop with other services and persist across reboots

**Acceptance Criteria**:
1. ✅ docker-compose.yml contains `wg-easy` service:
   - Image: `ghcr.io/wg-easy/wg-easy:latest`
   - Ports: `51820:51820/udp`, `51821:51821/tcp`
   - Volumes: `wg_data:/etc/wireguard`
   - Environment: `WG_HOST`, `WG_PASSWORD`, `WG_DEFAULT_DNS`
   - Capabilities: `NET_ADMIN`, `SYS_MODULE`
   - Restart: `unless-stopped`

2. ✅ docker-compose.yml contains `vpnTelegram` service:
   - Image: `vpn-telegram-bot:latest`
   - Environment: `BOT_TOKEN`, `WG_HOST`, `WG_PASSWORD`
   - Depends_on: `wg-easy`
   - Restart: `unless-stopped`

3. ✅ docker-compose.yml contains `vpn_network`:
   - Driver: `bridge`
   - Isolated from `n8n_network`

4. ✅ `docker-compose up -d` starts all services successfully
5. ✅ `docker ps` shows both containers running (healthy)

**Technical Notes**:
- Append services to existing docker-compose.yml (don't replace)
- Use named volumes for persistence
- Set sysctls for WireGuard: `net.ipv4.conf.all.src_valid_mark=1`
- Mount `/lib/modules` for kernel module access

**INVEST Checklist**:
- ✅ **Independent**: Docker config is isolated
- ✅ **Negotiable**: Image versions, network names flexible
- ✅ **Valuable**: Foundation for all VPN features
- ✅ **Estimable**: Standard Docker Compose patterns
- ✅ **Small**: Fits in 3 days
- ✅ **Testable**: `docker-compose config` validates syntax

**Dependencies**:
- None (first story in implementation order)

---

### Story 3: wg-easy Container Setup
**ID**: VPN-003
**Priority**: P0 (CORE)
**RICE Score**: 135
**Estimate**: 8 story points (1 week)

**As a** system administrator
**I want** wg-easy container to run with proper configuration
**So that** I can manage WireGuard clients via web UI

**Acceptance Criteria**:
1. ✅ Container starts successfully on first install
2. ✅ UI accessible at https://{server-ip}:51821
3. ✅ Login requires password (auto-generated 32-char)
4. ✅ Can create new client via UI:
   - Client name input
   - QR code displayed immediately
   - Config file downloadable
5. ✅ Can delete client via UI:
   - Confirmation dialog shown
   - Client removed from list
   - Tunnel disconnected if active
6. ✅ WireGuard kernel module loads successfully
7. ✅ Health check passes every 30 seconds

**Technical Notes**:
- Generate `WG_PASSWORD` via `openssl rand -base64 32`
- Store password in .env file (permissions 600)
- Auto-detect `WG_HOST` via `curl ifconfig.me` or user input
- Set `WG_DEFAULT_DNS=1.1.1.1,8.8.8.8`
- Mount `/lib/modules` read-only

**INVEST Checklist**:
- ✅ **Independent**: wg-easy doesn't require bot
- ✅ **Negotiable**: DNS servers, password length adjustable
- ✅ **Valuable**: Core VPN management capability
- ✅ **Estimable**: Known Docker image, clear docs
- ✅ **Small**: Fits in one sprint
- ✅ **Testable**: UI functional tests

**Acceptance Tests**:
```gherkin
Scenario: Create client via UI
  Given I am logged into wg-easy UI
  When I create client "test_client"
  Then QR code is displayed
  And config file is downloadable
  And client appears in list

Scenario: Delete client via UI
  Given client "test_client" exists
  When I delete the client
  Then confirmation dialog appears
  And client is removed after confirmation
```

---

### Story 4: Telegram Bot Container Setup
**ID**: VPN-004
**Priority**: P0 (CORE)
**RICE Score**: 80
**Estimate**: 13 story points (2 weeks)

**As a** system administrator
**I want** Telegram bot to run in a container
**So that** clients can request VPN configs without manual intervention

**Acceptance Criteria**:
1. ✅ Container starts successfully with valid `BOT_TOKEN`
2. ✅ Bot responds to `/start` command:
   - Welcome message displayed
   - Available commands listed
   - Response time <2 seconds
3. ✅ Bot connects to wg-easy API:
   - Can list existing clients
   - Can create new clients
   - Can delete clients
4. ✅ Container restarts automatically on crash
5. ✅ Logs show successful Telegram API connection

**Technical Notes**:
- Use Python 3.11+ with `python-telegram-bot` library
- Store `BOT_TOKEN` in environment variable (from .env)
- Use `WG_HOST` and `WG_PASSWORD` to connect to wg-easy
- Implement retry logic for wg-easy API calls (3 retries, exponential backoff)
- Log all commands to stdout (Docker captures)

**INVEST Checklist**:
- ✅ **Independent**: Bot can be developed separately from wg-easy
- ✅ **Negotiable**: Bot library, response messages flexible
- ✅ **Valuable**: Automation for client management
- ✅ **Estimable**: Standard bot development patterns
- ✅ **Small**: Fits in two sprints (with VPN-005)
- ✅ **Testable**: Bot commands can be manually tested

**Dependencies**:
- VPN-003 (wg-easy) must be running for bot to function

---

### Story 5: Basic Bot Commands
**ID**: VPN-005
**Priority**: P0 (CORE)
**RICE Score**: 135
**Estimate**: Included in VPN-004 (13 points total)

**As a** VPN client
**I want** to interact with bot via commands
**So that** I can request and manage my VPN configuration

**Acceptance Criteria**:
1. ✅ `/start` command:
   - Returns welcome message
   - Lists available commands
   - Explains purpose of bot

2. ✅ `/request` command:
   - Creates new WireGuard client
   - Generates unique client name (user_id_timestamp)
   - Sends QR code as image
   - Sends config file as document
   - Response time <2 seconds

3. ✅ `/help` command:
   - Lists all commands with descriptions
   - Links to documentation

**Technical Notes**:
- Use Telegram user ID for client naming: `user_{user_id}_{timestamp}`
- Generate QR code via `qrcode` Python library
- Send QR as PNG image (Telegram sendPhoto)
- Send config as .conf file (Telegram sendDocument)
- Log all commands: user_id, command, timestamp, result

**INVEST Checklist**:
- ✅ **Independent**: Commands are isolated features
- ✅ **Negotiable**: Command names, response format flexible
- ✅ **Valuable**: Core user interaction
- ✅ **Estimable**: Standard bot command patterns
- ✅ **Small**: 3 commands fit in one sprint
- ✅ **Testable**: Each command can be tested independently

**Acceptance Tests**:
```gherkin
Scenario: User requests VPN config
  Given bot is running
  When user sends "/request"
  Then bot creates WireGuard client
  And bot sends QR code image
  And bot sends .conf file
  And response arrives in <2 seconds

Scenario: Bot handles concurrent requests
  Given 10 users send "/request" simultaneously
  When bot processes all requests
  Then all 10 users receive unique configs
  And no duplicate client names exist
```

---

### Story 6: QR Code Generation
**ID**: VPN-006
**Priority**: P0 (CORE)
**RICE Score**: 300
**Estimate**: Included in VPN-005 (13 points total)

**As a** VPN client
**I want** to receive QR code for my config
**So that** I can quickly set up VPN on mobile devices

**Acceptance Criteria**:
1. ✅ QR code generated for each new client
2. ✅ QR code contains complete WireGuard config:
   - [Interface] section (PrivateKey, Address, DNS)
   - [Peer] section (PublicKey, Endpoint, AllowedIPs)
3. ✅ QR code is scannable by WireGuard mobile apps:
   - Tested on WireGuard Android
   - Tested on WireGuard iOS
4. ✅ QR code sent as PNG image (not ASCII art)
5. ✅ Image size <500 KB

**Technical Notes**:
- Use `qrcode` library: `qrcode.make(config_text).save('qr.png')`
- Config format must match WireGuard INI style
- Endpoint format: `{WG_HOST}:51820`
- AllowedIPs: `0.0.0.0/0, ::/0` (route all traffic through VPN)
- DNS: `1.1.1.1, 8.8.8.8`

**INVEST Checklist**:
- ✅ **Independent**: QR generation is isolated logic
- ✅ **Negotiable**: Image format, size adjustable
- ✅ **Valuable**: Critical for mobile users
- ✅ **Estimable**: Standard library, clear requirements
- ✅ **Small**: <1 day implementation
- ✅ **Testable**: QR code can be scanned with real app

**Dependencies**:
- VPN-005 (/request command) must call QR generation

---

### Story 7: Network Isolation
**ID**: VPN-007
**Priority**: P0 (CORE)
**RICE Score**: 160
**Estimate**: 3 story points (3 days)

**As a** system administrator
**I want** VPN services on isolated Docker network
**So that** they don't interfere with n8n services

**Acceptance Criteria**:
1. ✅ `vpn_network` exists as separate bridge network
2. ✅ `wg-easy` and `vpnTelegram` are on `vpn_network`
3. ✅ n8n services remain on `n8n_network`
4. ✅ Networks don't share subnets (no IP overlap)
5. ✅ VPN services can access internet (outbound)
6. ✅ n8n services remain accessible (no downtime)

**Technical Notes**:
- Define `vpn_network` in docker-compose.yml:
  ```yaml
  networks:
    vpn_network:
      driver: bridge
      ipam:
        config:
          - subnet: 172.20.0.0/16
  ```
- Ensure `n8n_network` uses different subnet (e.g., 172.18.0.0/16)
- No cross-network dependencies (services are independent)

**INVEST Checklist**:
- ✅ **Independent**: Network config is isolated
- ✅ **Negotiable**: Subnet ranges adjustable
- ✅ **Valuable**: Prevents conflicts and security issues
- ✅ **Estimable**: Standard Docker networking
- ✅ **Small**: 1 day implementation
- ✅ **Testable**: `docker network inspect` shows separation

**Acceptance Tests**:
```gherkin
Scenario: Networks are isolated
  Given VPN and n8n services are running
  When I inspect Docker networks
  Then vpn_network subnet is 172.20.0.0/16
  And n8n_network subnet is 172.18.0.0/16
  And subnets do not overlap

Scenario: n8n remains accessible
  Given VPN installation completed
  When I access n8n UI at {server-ip}:5678
  Then n8n loads successfully
  And no connection errors occur
```

---

### Story 8: Environment Configuration
**ID**: VPN-008
**Priority**: P0 (CORE)
**RICE Score**: 400
**Estimate**: 2 story points (2 days)

**As a** system administrator
**I want** VPN configuration stored in environment variables
**So that** I can easily customize settings without editing code

**Acceptance Criteria**:
1. ✅ .env file contains required variables:
   - `BOT_TOKEN` (user-provided during install)
   - `WG_HOST` (auto-detected or user-provided)
   - `WG_PASSWORD` (auto-generated 32-char)
   - `WG_DEFAULT_DNS=1.1.1.1,8.8.8.8`
   - `WG_PORT=51820`
   - `WG_UI_PORT=51821`

2. ✅ .env file has secure permissions:
   - Ownership: root:root
   - Permissions: 600 (read/write owner only)

3. ✅ .env is in .gitignore (not committed to git)

4. ✅ Installation script generates/updates .env automatically

**Technical Notes**:
- Generate password: `openssl rand -base64 32`
- Detect external IP: `curl -s ifconfig.me`
- Append to existing .env (don't overwrite n8n vars)
- Validate BOT_TOKEN format: `^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$`

**INVEST Checklist**:
- ✅ **Independent**: Environment setup is isolated
- ✅ **Negotiable**: Variable names, defaults adjustable
- ✅ **Valuable**: Security and ease of configuration
- ✅ **Estimable**: Standard environment variable patterns
- ✅ **Small**: 2 days implementation
- ✅ **Testable**: File permissions can be verified

**Security Requirements**:
- Never log BOT_TOKEN or WG_PASSWORD
- Never include .env in git commits
- Display WG_PASSWORD to user once during install (copy to clipboard if possible)

---

## MVP Stories (v1.0)

### Story 9: Bot User Whitelist
**ID**: VPN-009
**Priority**: P1 (MVP)
**RICE Score**: 80
**Estimate**: 5 story points (1 week)

**As a** system administrator
**I want** to restrict bot access to approved users
**So that** unauthorized users cannot request VPN configs

**Acceptance Criteria**:
1. ✅ .env file supports `BOT_WHITELIST` variable:
   - Format: Comma-separated Telegram user IDs
   - Example: `BOT_WHITELIST=123456789,987654321`
   - Optional: Empty = allow all users

2. ✅ Bot checks user ID before processing commands:
   - If whitelist is empty: Allow all
   - If user ID in whitelist: Allow
   - If user ID not in whitelist: Deny with message

3. ✅ Denied users receive helpful message:
   - "Access denied. Contact administrator for access."
   - Includes administrator Telegram username (if configured)

**Technical Notes**:
- Parse `BOT_WHITELIST` on bot startup
- Store as Python set for O(1) lookup
- Log denied access attempts: user_id, username, timestamp

**INVEST Checklist**:
- ✅ **Independent**: Whitelist check is isolated feature
- ✅ **Negotiable**: Whitelist format, error messages flexible
- ✅ **Valuable**: Security control for administrators
- ✅ **Estimable**: Standard authorization pattern
- ✅ **Small**: 1 week with testing
- ✅ **Testable**: Can test with whitelisted/non-whitelisted users

---

### Story 10: Config Revocation
**ID**: VPN-010
**Priority**: P1 (MVP)
**RICE Score**: 90
**Estimate**: 5 story points (1 week)

**As a** system administrator
**I want** to revoke VPN access via bot command
**So that** I can remove compromised or unused clients

**Acceptance Criteria**:
1. ✅ `/revoke` command available to administrators:
   - Lists all active clients for current user
   - Prompts for client selection (inline keyboard)
   - Confirms deletion with warning message

2. ✅ Revocation deletes client from wg-easy:
   - Client removed from UI
   - VPN tunnel disconnected immediately
   - User receives notification

3. ✅ Revoked users can request new config:
   - `/request` command works again
   - New client created with new keys

**Technical Notes**:
- Identify clients by user ID prefix: `user_{user_id}_*`
- Call wg-easy API DELETE endpoint: `/api/wireguard/client/{id}`
- Send notification to user: "Your VPN access has been revoked. Use /request to get new config."

**INVEST Checklist**:
- ✅ **Independent**: Revocation is isolated feature
- ✅ **Negotiable**: Confirmation flow, messages flexible
- ✅ **Valuable**: Security and client lifecycle management
- ✅ **Estimable**: Similar to create client flow
- ✅ **Small**: 1 week with testing
- ✅ **Testable**: Can revoke test client and verify deletion

**Acceptance Tests**:
```gherkin
Scenario: Administrator revokes client
  Given user has active VPN config
  When administrator sends "/revoke"
  And selects user's client from list
  And confirms deletion
  Then client is removed from wg-easy
  And user receives revocation notification
  And VPN connection is terminated
```

---

### Story 11: Status Check Command
**ID**: VPN-011
**Priority**: P1 (MVP)
**RICE Score**: 90
**Estimate**: 3 story points (3 days)

**As a** VPN client
**I want** to check my VPN connection status
**So that** I can troubleshoot connection issues

**Acceptance Criteria**:
1. ✅ `/status` command shows:
   - Client name
   - Connection status (connected/disconnected)
   - Last handshake time (if connected)
   - Data transferred (if available)

2. ✅ Response format is user-friendly:
   ```
   📊 VPN Status
   Client: user_123_1234567890
   Status: ✅ Connected
   Last handshake: 30 seconds ago
   Data: 1.2 GB received, 850 MB sent
   ```

3. ✅ If no config exists:
   - "No VPN config found. Use /request to get started."

**Technical Notes**:
- Query wg-easy API: `/api/wireguard/client/{id}`
- Parse WireGuard status: `wg show wg0`
- Convert bytes to human-readable (KB, MB, GB)
- Handle API errors gracefully

**INVEST Checklist**:
- ✅ **Independent**: Status check is isolated feature
- ✅ **Negotiable**: Status format, emojis flexible
- ✅ **Valuable**: User troubleshooting and transparency
- ✅ **Estimable**: Standard API query pattern
- ✅ **Small**: 3 days with testing
- ✅ **Testable**: Can verify status for connected/disconnected clients

---

### Story 12: Documentation
**ID**: VPN-012
**Priority**: P1 (MVP)
**RICE Score**: 50
**Estimate**: 8 story points (1 week)

**As a** user (administrator or client)
**I want** comprehensive documentation
**So that** I can install, configure, and use VPN without support

**Acceptance Criteria**:
1. ✅ `docs/VPN_INSTALL.md` exists with:
   - Prerequisites (Ubuntu version, Docker, Telegram bot setup)
   - Step-by-step installation instructions
   - Troubleshooting section (common errors)
   - Port forwarding guide (for NAT)

2. ✅ `docs/VPN_USER_GUIDE.md` exists with:
   - How to request VPN via bot
   - WireGuard client installation (Windows, macOS, Linux, iOS, Android)
   - QR code scanning instructions
   - Connection troubleshooting

3. ✅ `docs/BOT_COMMANDS.md` exists with:
   - Complete command reference
   - Examples for each command
   - Permission requirements

4. ✅ README.md updated with VPN section:
   - Link to VPN_INSTALL.md
   - Quick start guide (TL;DR)

**Technical Notes**:
- Use Markdown format
- Include screenshots (QR code scanning, UI, bot)
- Link to official WireGuard documentation
- Document environment variables

**INVEST Checklist**:
- ✅ **Independent**: Documentation can be written separately
- ✅ **Negotiable**: Structure, depth adjustable
- ✅ **Valuable**: Reduces support burden, improves UX
- ✅ **Estimable**: Standard documentation patterns
- ✅ **Small**: 1 week for all docs
- ✅ **Testable**: Can verify docs by following steps

**Deliverables**:
- 3 Markdown files (install, user guide, bot commands)
- Updated README.md
- Optional: Video tutorial (screencast)

---

## STRETCH Stories (v2.0+)

### Story 13: Client Naming/Tagging
**ID**: VPN-013
**Priority**: P3 (STRETCH)
**RICE Score**: 22.5
**Estimate**: 5 story points (1 week)

**As a** system administrator
**I want** to assign friendly names to clients
**So that** I can identify users easily in wg-easy UI

**Acceptance Criteria**:
1. ✅ `/request <name>` command accepts optional name:
   - Example: `/request laptop` creates `user_123_laptop`
   - Name must be alphanumeric (no spaces)
   - Max length: 20 characters

2. ✅ `/list` command shows all user's clients:
   - Lists all clients with friendly names
   - Shows connection status for each

3. ✅ wg-easy UI displays friendly names

**INVEST Checklist**:
- ✅ **Independent**: Naming is isolated feature
- ✅ **Negotiable**: Naming format, validation flexible
- ✅ **Valuable**: Improves UX for multi-device users
- ✅ **Estimable**: Extends existing /request command
- ✅ **Small**: 1 week with validation logic
- ✅ **Testable**: Can create clients with custom names

---

### Story 14: Traffic Statistics Dashboard
**ID**: VPN-014
**Priority**: P3 (STRETCH)
**RICE Score**: 7.5
**Estimate**: 21 story points (1 month)

**As a** system administrator
**I want** to view traffic statistics dashboard
**So that** I can monitor VPN usage and detect anomalies

**Acceptance Criteria**:
1. ✅ Dashboard shows:
   - Active clients count
   - Total data transferred (today, week, month)
   - Per-client bandwidth usage
   - Connection history (last 7 days)

2. ✅ Dashboard accessible at `https://{server-ip}:51822`
3. ✅ Authentication required (same as wg-easy)
4. ✅ Real-time updates (refresh every 10 seconds)

**Technical Notes**:
- Use Grafana or custom web app
- Query WireGuard stats: `wg show wg0 transfer`
- Store historical data in SQLite
- Visualize with Chart.js or similar

**INVEST Checklist**:
- ✅ **Independent**: Dashboard is separate component
- ✅ **Negotiable**: Dashboard tech stack, metrics flexible
- ✅ **Valuable**: Monitoring and insights for admins
- ✅ **Estimable**: Standard dashboard implementation
- ✅ **Small**: 1 month (large but single epic)
- ✅ **Testable**: Dashboard can be manually tested

**Dependencies**:
- Requires historical data collection (new feature)

---

## Story Template (for future stories)

### Story X: [Feature Name]
**ID**: VPN-XXX
**Priority**: PX (CORE/MVP/STRETCH)
**RICE Score**: XXX
**Estimate**: X story points (X days/weeks)

**As a** [persona]
**I want** [capability]
**So that** [outcome]

**Acceptance Criteria**:
1. ✅ [Criterion 1]
2. ✅ [Criterion 2]
3. ✅ [Criterion 3]

**Technical Notes**:
- [Implementation details]
- [Libraries/tools needed]
- [Security considerations]

**INVEST Checklist**:
- ✅ **Independent**: [Explanation]
- ✅ **Negotiable**: [Explanation]
- ✅ **Valuable**: [Explanation]
- ✅ **Estimable**: [Explanation]
- ✅ **Small**: [Explanation]
- ✅ **Testable**: [Explanation]

**Dependencies**:
- [List of dependent stories]

**Acceptance Tests**:
```gherkin
Scenario: [Test scenario]
  Given [precondition]
  When [action]
  Then [expected result]
```
