# Team Integration Audit Catalog

> Responses from 6 team members, collected March 2026.
> Used to build the master setup script.

---

## Summary Matrix

| Person | OS | ~/.env | gh CLI | gws CLI | Node/npm | SQL MCP | Slack MCP | Python |
|--------|-----|--------|--------|---------|----------|---------|-----------|--------|
| Mike Farrell | Windows | None | No | No | No | Yes | Yes | No |
| Alyssa | Mac | None (CLAUDE.local.md) | No | Yes | Yes | No | Yes | No data |
| Dominique Hernandez | Windows | Partial (empty keys) | No | Yes | Yes | Yes | Yes | No |
| Lillian | Mac | None (CLAUDE.local.md) | No | Yes | Yes | No | Yes | No data |
| Sebastian Moncayo | Windows | Per-project only | Yes | Yes | Yes | Yes | Yes | No |
| Bekah Baker | Windows | None (in MCP configs) | No | Yes | Yes | Yes | Yes | No data |

---

## Individual Responses

### Mike Farrell (Windows)
- **Role:** CMO / Head of PPC
- **OS:** Windows
- **~/.env:** Does not exist
- **gh CLI:** Not installed
- **gws CLI:** Not installed
- **Node/npm:** Not installed
- **SQL MCP:** Configured (credentials in MCP config directly)
- **Slack MCP:** Configured
- **Key gaps:** Missing Node (prerequisite for everything), no gh, no gws, no ~/.env
- **Priority:** High — needs Node before anything else works

### Alyssa (Mac)
- **Role:** Operations
- **OS:** Mac
- **~/.env:** Does not exist. Credentials stored in CLAUDE.local.md files
- **gh CLI:** Not installed
- **gws CLI:** Installed and working
- **Node/npm:** Installed
- **SQL MCP:** Not configured (needs SQL credentials from Pedro)
- **Slack MCP:** Configured
- **Key gaps:** No SQL access, no gh, credentials scattered in CLAUDE.local.md instead of ~/.env
- **Priority:** Medium — needs SQL account created, then ~/.env consolidation

### Dominique Hernandez (Windows)
- **Role:** Integrator / Account Director
- **OS:** Windows
- **~/.env:** Exists but has empty key values (placeholders only)
- **gh CLI:** Not installed
- **gws CLI:** Installed and working
- **Node/npm:** Installed
- **SQL MCP:** Configured
- **Slack MCP:** Configured
- **Python:** Not installed
- **Key gaps:** Empty ~/.env keys need filling, no gh, no Python
- **Priority:** Low-medium — mostly working, just needs key values and gh

### Lillian (Mac)
- **Role:** Operations
- **OS:** Mac
- **~/.env:** Does not exist. Credentials in CLAUDE.local.md files
- **gh CLI:** Not installed
- **gws CLI:** Installed and working
- **Node/npm:** Installed
- **SQL MCP:** Not configured (needs SQL credentials from Pedro)
- **Slack MCP:** Configured
- **Key gaps:** No SQL access, no gh, no ~/.env
- **Priority:** Medium — same as Alyssa, needs SQL account + ~/.env

### Sebastian Moncayo (Windows)
- **Role:** Operations
- **OS:** Windows
- **~/.env:** Exists but only in per-project directories, not global
- **gh CLI:** Installed and working (only person with gh!)
- **gws CLI:** Installed and working
- **Node/npm:** Installed
- **SQL MCP:** Configured
- **Slack MCP:** Configured
- **Python:** Not installed
- **Key gaps:** Per-project .env files need consolidating to global ~/.env
- **Priority:** Low — most complete setup, just needs ~/.env consolidation

### Bekah Baker (Windows)
- **Role:** COO
- **OS:** Windows
- **~/.env:** Does not exist. Credentials hardcoded in MCP config files
- **gh CLI:** Not installed
- **gws CLI:** Installed and working
- **Node/npm:** Installed
- **SQL MCP:** Configured (credentials in MCP config)
- **Slack MCP:** Configured
- **Key gaps:** No gh, credentials need moving from MCP configs to ~/.env
- **Priority:** Low-medium — working setup but credentials are scattered

---

## Common Gaps (by frequency)

| Gap | Affected | Count |
|-----|----------|-------|
| gh CLI missing | Mike, Alyssa, Dom, Lillian, Bekah | 5/6 |
| ~/.env missing or incomplete | All 6 | 6/6 |
| SQL not connected | Alyssa, Lillian | 2/6 |
| Node/npm missing | Mike | 1/6 |
| Python missing | Mike, Sebastian, Dom | 3/6 (not critical) |

---

## Pre-requisites for Setup Script

Before running the setup script on each person's machine:

1. **Pedro needs to create SQL read-only accounts** for Alyssa and Lillian
2. **All shared API keys** need to be in the Bitwarden "Dev Keys" vault
3. **Team members** need to be invited to Bitwarden
4. **Mike** needs Node.js installed first (script will detect and prompt)
