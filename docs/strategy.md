# Stonecutter Claude Integration Strategy

> Full reference document for how the team connects to external services via Claude Code and Claude Desktop.

## The Three Connector Types

| Type | How it works | Token cost | Claude Desktop? | Claude Code? |
|------|-------------|-----------|-----------------|-------------|
| **MCP** | Claude sees the tool natively | High — descriptions sent every message | Yes (only option) | Yes |
| **CLI** | Claude runs terminal commands | Near-zero | No | Yes |
| **curl/API** | Claude makes direct web requests | Zero | No | Yes |

## Service-by-Service Breakdown

### SQL Server (sc-sql)
- **Claude Code:** MCP (keep)
- **Claude Desktop:** MCP (required)
- **Why MCP:** SQL Server has no REST API. It's a database that speaks TCP — you need a driver to connect. The MCP wraps that driver.
- **Credentials:** Per-user read-only accounts (Pedro creates these). Stored in `~/.env` as `SQL_SERVER`, `SQL_DATABASE`, `SQL_USERNAME`, `SQL_PASSWORD`.
- **MCP config location:** `~/.claude/settings.json` → `mcpServers.sc-sql`

### ClickUp
- **Claude Code:** MCP (Anthropic proxy — no local server needed)
- **Claude Desktop:** MCP (Anthropic proxy)
- **Why MCP:** ClickUp has 50+ API endpoints. Building curl commands for each would be slow and error-prone. The Anthropic proxy also handles per-user OAuth automatically.
- **Credentials:** Managed by Anthropic proxy (OAuth). Also `CLICKUP_API_KEY` and `CLICKUP_TEAM_ID` in `~/.env` for direct API access if needed.

### Slack
- **Claude Code:** curl/API (demoted from MCP to save tokens)
- **Claude Desktop:** MCP (required)
- **Why demoted in Code:** 80% of Slack use is simple — "post this to #channel" or "read recent messages." One curl call each. Saves ~1,500 tokens per message by not loading MCP tool descriptions.
- **Credentials:** Shared bot token `SLACK_BOT_TOKEN` in `~/.env`. Bot name: `nanoclaw`.
- **Common curl patterns:**
  ```bash
  # Post a message
  curl -s -X POST https://slack.com/api/chat.postMessage \
    -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"channel":"CHANNEL_ID","text":"Your message here"}'

  # Read recent channel messages
  curl -s "https://slack.com/api/conversations.history?channel=CHANNEL_ID&limit=10" \
    -H "Authorization: Bearer $SLACK_BOT_TOKEN"

  # List channels
  curl -s "https://slack.com/api/conversations.list?limit=100" \
    -H "Authorization: Bearer $SLACK_BOT_TOKEN"
  ```

### Open Brain
- **Claude Code:** MCP (keep)
- **Claude Desktop:** MCP (required)
- **Why MCP:** Custom knowledge base with semantic search. Conversational access is valuable.
- **Credentials:** Supabase edge function URL with embedded key (configured in MCP server settings).
- **Note:** Contains Lee's private brain (personal notes, employee assessments) — Lee-only access. Team brain is shared.

### Google Workspace (Gmail, Drive, Sheets, Calendar)
- **Claude Code:** CLI (`gws` — Google Workspace CLI)
- **Claude Desktop:** MCP (if available)
- **Why CLI in Code:** Zero token cost. `gws` handles OAuth per-user — each person authorizes with their own Google account.
- **Setup:** `npm install -g @googleworkspace/cli` then `gws auth login` (opens browser).
- **Credentials:** OAuth token stored locally by gws. `GOOGLE_WORKSPACE_CLI_CLIENT_ID` and `GOOGLE_WORKSPACE_CLI_CLIENT_SECRET` in `~/.env` for the Stonecutter GCP project.

### GitHub
- **Claude Code:** CLI (`gh` — GitHub CLI)
- **Claude Desktop:** Not typically needed
- **Why CLI:** Zero token cost. `gh` is best-in-class. Each person authenticates with their own GitHub account.
- **Setup:** `brew install gh` (Mac) or `winget install GitHub.cli` (Windows), then `gh auth login`.
- **Credentials:** OAuth token stored locally by gh.

### Rainforest API
- **Claude Code:** curl/API (demoted from MCP)
- **Claude Desktop:** MCP (if available)
- **Why demoted in Code:** Single endpoint — product lookup by ASIN. Not worth MCP overhead.
- **Credentials:** Shared `RAINFOREST_API_KEY` in `~/.env`.
- **curl pattern:**
  ```bash
  curl -s "https://api.rainforestapi.com/request?api_key=$RAINFOREST_API_KEY&type=product&asin=YOUR_ASIN" | jq .
  ```

### Other APIs (Keepa, Brave, Apify, Perplexity)
- **Claude Code:** curl/API (env vars only)
- **Credentials:** Shared API keys in `~/.env`
- **curl patterns:** Documented per-service as needed.

---

## Credential Categories

### Shared (same for everyone — stored in Bitwarden)
| Key | Service |
|-----|---------|
| `SLACK_BOT_TOKEN` | Slack (nanoclaw bot) |
| `SLACK_TEAM_ID` | Slack workspace ID |
| `RAINFOREST_API_KEY` | Amazon product data |
| `KEEPA_API_KEY` | Amazon price history |
| `BRAVE_API_KEY` | Web search |
| `APIFY_API_KEY` | Web scraping |
| `PERPLEXITY_API_KEY` | AI-powered search |
| `GOOGLE_SHEETS_KEY_PATH` | Service account for automated sheet access |
| `GOOGLE_WORKSPACE_CLI_CLIENT_ID` | GCP project for gws CLI |
| `GOOGLE_WORKSPACE_CLI_CLIENT_SECRET` | GCP project for gws CLI |

### Personal (unique per person)
| Key | Service | How to get |
|-----|---------|-----------|
| `ANTHROPIC_API_KEY` | Claude Code billing | Anthropic console |
| Google OAuth | Gmail, Drive, Calendar | `gws auth login` (browser) |
| GitHub OAuth | Repos, PRs, issues | `gh auth login` (browser) |
| `SQL_USERNAME` / `SQL_PASSWORD` | Database | Pedro creates per-user |
| ClickUp OAuth | Task management | Anthropic proxy handles it |

---

## Security

### Current approach
- Credentials stored in `~/.env` (sourced by shell) and `~/.claude/settings.json` (MCP configs)
- Both files are local-only, never committed to git
- `chmod 600 ~/.claude/settings.json` recommended

### Target approach
- **Bitwarden Teams** ($4/user/month) for shared credential distribution
- Shared vault called "Dev Keys" with all company API keys
- Team members copy keys from Bitwarden during setup script
- Rotation: update in Bitwarden, tell team to re-run setup script
- **Future:** Secrets manager (Doppler/Infisical) after AI engineer hire

---

## Onboarding Checklist

### IT/Lee does before day 1:
- [ ] Create Google Workspace account
- [ ] Add to GitHub org (stonecutternyc)
- [ ] Ask Pedro for SQL read-only credentials
- [ ] Invite to Bitwarden "Dev Keys" vault
- [ ] Ensure Claude Code is installed

### New team member runs:
- [ ] Run the master setup script (handles everything below automatically):
  - **Mac:** `bash setup-integrations.sh`
  - **Windows:** `powershell -ExecutionPolicy Bypass -File setup-integrations.ps1`
- [ ] Have Bitwarden open to paste API keys when prompted
- [ ] Authenticate GitHub (browser opens automatically)
- [ ] Authenticate Google Workspace (browser opens automatically)
- [ ] Add ClickUp MCP: `claude mcp add --transport http -s user clickup https://mcp.clickup.com/mcp`
- [ ] Verify: `bash verify-integrations.sh` (Mac) / `powershell verify-integrations.ps1` (Windows)
