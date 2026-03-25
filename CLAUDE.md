# Claude Integration Setup

> Standardizing how every Stonecutter team member connects to external services (SQL, Slack, ClickUp, Google, GitHub, etc.) via Claude Code and Claude Desktop.

## Project Purpose
Create a repeatable, secure onboarding process so any team member can get fully connected to all Stonecutter tools in under 20 minutes.

## Status
**Phase: Build** — Setup scripts built. Ready for dry-run on Lee's machine, then rollout to team.

## Key Decisions
- See `~/Projects/stonecutter/docs/decisions/2026-03-23-team-connector-strategy.md` for the full strategy
- **3 connector types:** MCP (for complex, conversational tools), CLI (for tools with good command-line interfaces), curl/API (for simple lookups)
- **Claude Code vs Desktop:** Desktop requires MCPs for everything. Code can use MCPs, CLIs, and curl — so we optimize Code for lower token cost.
- **Security:** Bitwarden Teams for shared credential distribution. Personal OAuth for Google/GitHub.
- **Access:** Everyone gets everything by default. Lee restricts per-person as needed.

## Connector Summary

### MCPs (Claude Code — kept)
| Service | Why MCP |
|---------|---------|
| SQL Server (sc-sql) | No REST API — database needs a driver |
| ClickUp (Anthropic proxy) | Complex API, conversational task management |

### Demoted to curl/API (Claude Code)
| Service | Why demoted |
|---------|-------------|
| Slack | 80% of use is simple posts/reads. Saves ~1,500 tokens/message |
| Rainforest | Single endpoint (product lookup by ASIN) |

### CLIs (zero token cost)
| Service | CLI |
|---------|-----|
| GitHub | `gh` |
| Google Workspace | `gws` |

### Claude Desktop
All services need MCPs in Desktop (it can't run CLIs or curl).

## Setup Scripts

### For Mac users (Alyssa, Lillian):
```bash
curl -fsSL https://raw.githubusercontent.com/stonecutternyc/claude-integration-setup/main/draft/build/setup-integrations.sh -o /tmp/setup-integrations.sh && bash /tmp/setup-integrations.sh
```
Or if the repo is already cloned:
```bash
bash ~/Projects/stonecutter/claude-integration-setup/draft/build/setup-integrations.sh
```

### For Windows users (Mike, Dom, Sebastian, Bekah):
```powershell
powershell -ExecutionPolicy Bypass -File draft/build/setup-integrations.ps1
```

### Verification (after setup):
```bash
# Mac
bash draft/build/verify-integrations.sh

# Windows
powershell -ExecutionPolicy Bypass -File draft/build/verify-integrations.ps1
```

### What the scripts do:
1. Check prerequisites (Node.js, Claude Code)
2. Set up `~/.env` — prompts user to paste each key from Bitwarden "Dev Keys" vault
3. Install CLIs — `gh` and `gws` if missing, runs browser auth flows
4. Configure MCP servers — sc-sql, ClickUp (Anthropic proxy)
5. Remove demoted MCPs — Slack and Rainforest (curl-only now)
6. Open Brain is Lee-only — team accesses it via Slack, not installed on their machines
6. Verify — tests each connection and reports pass/fail

### What they do NOT do:
- Install Python (not needed for integrations)
- Set up Claude Desktop (separate effort)
- Configure Bitwarden itself (Lee does this beforehand)

## Key Files
- `docs/strategy.md` — Full strategy reference document
- `docs/team-audit-catalog.md` — Structured audit of all 6 team members' current setups
- `docs/slack-audit-message.md` — Message sent to team for integration audit
- `draft/build/setup-integrations.sh` — Mac setup script
- `draft/build/setup-integrations.ps1` — Windows setup script
- `draft/build/verify-integrations.sh` — Mac verification script
- `draft/build/verify-integrations.ps1` — Windows verification script
- `draft/build/.env.template` — Template for ~/.env with all keys documented
- `~/Projects/stonecutter/docs/decisions/2026-03-23-team-connector-strategy.md` — Decision record

## Related
- Existing setup guides: `~/Projects/stonecutter/docs/setup-slack-mcp.md`, `~/Projects/stonecutter/docs/setup-gws-cli.md`
- Tech stack registry: `~/.claude/tech_stack.md`
