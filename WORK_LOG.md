# Work Log — Claude Integration Setup

## 2026-03-24 — Master Setup Scripts Built

**What was done:**
- Created team audit catalog (`docs/team-audit-catalog.md`) — structured summary of all 6 responses (Mike, Alyssa, Dom, Lillian, Sebastian, Bekah)
- Built Mac setup script (`draft/build/setup-integrations.sh`) — interactive bash script, idempotent, merges settings
- Built Windows setup script (`draft/build/setup-integrations.ps1`) — PowerShell mirror of the Mac script
- Created `.env.template` (`draft/build/.env.template`) — all keys documented with comments
- Built verification scripts (`draft/build/verify-integrations.sh` + `.ps1`) — tests each connection, reports pass/fail table
- Updated CLAUDE.md with script usage instructions and full file inventory
- Updated strategy.md onboarding checklist with actual script commands
- Team-only open-brain server.js — excluded Lee's personal brain tools (search_brain, capture_thought) from team version
- Scripts handle: prerequisites check, ~/.env setup from Bitwarden, gh + gws install + auth, sc-sql + open-brain MCP config, Slack/Rainforest MCP removal, verification

**Key design decisions:**
- Open Brain NOT installed on team machines — Lee-only. Team accesses it via Slack instead.
- ClickUp MCP handled via `claude mcp add` (Anthropic proxy) — not embedded in settings.json merge
- Scripts prompt for keys interactively (from Bitwarden) — never hardcode credentials
- Idempotent: safe to re-run (checks before installing, merges instead of overwrites)

**Completed since initial build:**
- Dry run on Lee's Mac: 14/14 verification checks passed
- Fixed gws `--pageSize` bug in all 4 scripts (flag doesn't exist)
- Removed Open Brain from all setup/verification scripts (Lee's decision: team accesses via Slack only)
- Bitwarden Dev Keys collection created with all 11 shared keys
- Mike Farrell (Windows) given "View items" access to Dev Keys
- Detailed step-by-step instructions sent to Mike via Slack with the .ps1 file
- Pedro already gave SQL credentials to Alyssa + Lillian

**What remains:**
- Get Mike's test results (Windows) — he needs to install Node.js first
- Test on one Mac person (Alyssa or Lillian)
- Give remaining team members Bitwarden access (Dom, Sebastian, Bekah, Alyssa, Lillian)
- Roll out to remaining team after Mike's test passes
- Move scripts from `draft/build/` to `scripts/build/` after verification

## 2026-03-23 — Initial Strategy & Audit Kickoff

**What was done:**
- Audited Lee's current setup: 4 MCP servers (sc-sql, rainforest, slack, open-brain), 19 env keys, 2 CLIs (gh, gws)
- Designed full connector strategy: which services use MCP vs CLI vs curl, for both Claude Code and Desktop
- Decided on Bitwarden Teams for credential distribution
- Everyone gets full access by default; Lee controls restrictions
- Created project folder with CLAUDE.md
- Wrote full strategy reference doc at `docs/strategy.md`
- Drafted Slack audit message at `docs/slack-audit-message.md`
- Created decision record at `~/Projects/stonecutter/docs/decisions/2026-03-23-team-connector-strategy.md`
- Updated `~/.claude/tech_stack.md` with missing entries (ClickUp, Open Brain, gws, Bitwarden)
- Updated `~/.claude/CLAUDE.md` env key list (was 8 keys, now 19)

**What remains:**
- Lee sends Slack audit message to team
- Wait for team responses (need at least 3 people)
- Catalog everyone's current setup
- Build master setup script (Mac .sh + Windows .ps1)
- Test on Lee's machine, then one other team member
- Roll out to full team
- Set up Bitwarden Teams org
