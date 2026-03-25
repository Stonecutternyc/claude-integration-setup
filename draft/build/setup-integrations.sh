#!/bin/bash
# Stonecutter Master Integration Setup — macOS
# Gets a team member fully connected to all Stonecutter tools via Claude Code.
#
# Usage: bash setup-integrations.sh
# Safe to re-run — checks before installing, merges instead of overwrites.

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }
print_ok()     { echo -e "  ${GREEN}✓${NC} $1"; }
print_warn()   { echo -e "  ${YELLOW}⚠${NC} $1"; }
print_fail()   { echo -e "  ${RED}✗${NC} $1"; }
print_info()   { echo -e "  $1"; }

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Stonecutter Claude Integration Setup (Mac)     ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================
# PHASE 0: Homebrew (needed for gh and other tools)
# ============================================================
print_header "Phase 0: Homebrew"

if command -v brew &> /dev/null; then
  print_ok "Homebrew already installed"
else
  print_info "Installing Homebrew (will ask for your Mac password)..."
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o /tmp/brew-install.sh
  bash /tmp/brew-install.sh
  rm -f /tmp/brew-install.sh

  # Add Homebrew to PATH for this session (Apple Silicon and Intel)
  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    echo >> "$HOME/.zprofile"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
  elif [ -f /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  if command -v brew &> /dev/null; then
    print_ok "Homebrew installed"
  else
    print_fail "Homebrew installation failed — install manually and re-run this script"
    exit 1
  fi
fi

# ============================================================
# PHASE 1: Prerequisites
# ============================================================
print_header "Phase 1: Checking Prerequisites"

# Check Claude Code
if command -v claude &> /dev/null; then
  print_ok "Claude Code CLI found"
else
  print_fail "Claude Code CLI not found"
  echo "    Install it first: https://docs.anthropic.com/en/docs/claude-code/overview"
  exit 1
fi

# Check Node.js
if command -v node &> /dev/null; then
  NODE_VERSION=$(node --version)
  print_ok "Node.js found ($NODE_VERSION)"
else
  print_fail "Node.js not found"
  echo ""
  echo "    Install Node.js first:"
  echo "    1. Go to https://nodejs.org"
  echo "    2. Download the LTS version"
  echo "    3. Run the installer"
  echo "    4. Close and reopen your terminal"
  echo "    5. Run this script again"
  exit 1
fi

# Check npm
if command -v npm &> /dev/null; then
  print_ok "npm found"
else
  print_fail "npm not found (should come with Node.js)"
  exit 1
fi

# ============================================================
# PHASE 2: Set up ~/.env
# ============================================================
print_header "Phase 2: Setting Up ~/.env"

ENV_FILE="$HOME/.env"
TEMPLATE_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$ENV_FILE" ]; then
  print_warn "~/.env already exists — will add missing keys only"
  EXISTING_ENV=true
else
  print_info "Creating ~/.env from template..."
  EXISTING_ENV=false
fi

echo ""
echo "Open Bitwarden and find the 'Dev Keys' vault."
echo "You'll paste each key when prompted. Press Enter to skip any you don't have yet."
echo ""

# Function to set a key in ~/.env (only if not already set)
set_env_key() {
  local KEY="$1"
  local PROMPT="$2"
  local DEFAULT="$3"

  # Check if key already has a non-empty value
  if [ "$EXISTING_ENV" = true ] && grep -q "^${KEY}=.\+" "$ENV_FILE" 2>/dev/null; then
    print_ok "$KEY already set"
    return
  fi

  if [ -n "$DEFAULT" ]; then
    read -p "  $PROMPT [$DEFAULT]: " VALUE
    VALUE=${VALUE:-$DEFAULT}
  else
    read -p "  $PROMPT: " VALUE
  fi

  if [ -n "$VALUE" ]; then
    # Remove any existing empty/placeholder line for this key
    if [ -f "$ENV_FILE" ]; then
      grep -v "^${KEY}=" "$ENV_FILE" > "$ENV_FILE.tmp" 2>/dev/null || true
      mv "$ENV_FILE.tmp" "$ENV_FILE"
    fi
    echo "${KEY}=${VALUE}" >> "$ENV_FILE"
    print_ok "$KEY saved"
  else
    # Write empty placeholder if not already present
    if ! grep -q "^${KEY}=" "$ENV_FILE" 2>/dev/null; then
      echo "${KEY}=" >> "$ENV_FILE"
    fi
    print_warn "$KEY skipped (you can fill it in later)"
  fi
}

# Create file if it doesn't exist
touch "$ENV_FILE"

echo -e "${YELLOW}── Shared Keys (from Bitwarden 'Dev Keys' vault) ──${NC}"
set_env_key "SLACK_BOT_TOKEN" "Slack Bot Token (nanoclaw)"
set_env_key "SLACK_TEAM_ID" "Slack Team ID"
set_env_key "RAINFOREST_API_KEY" "Rainforest API Key"
set_env_key "KEEPA_API_KEY" "Keepa API Key"
set_env_key "BRAVE_API_KEY" "Brave Search API Key"
set_env_key "APIFY_API_KEY" "Apify API Key"
set_env_key "PERPLEXITY_API_KEY" "Perplexity API Key"
set_env_key "GOOGLE_WORKSPACE_CLI_CLIENT_ID" "Google Workspace CLI Client ID"
set_env_key "GOOGLE_WORKSPACE_CLI_CLIENT_SECRET" "Google Workspace CLI Client Secret"
set_env_key "CLICKUP_API_KEY" "ClickUp API Key"
set_env_key "CLICKUP_TEAM_ID" "ClickUp Team ID"

echo ""
echo -e "${YELLOW}── Personal Keys ──${NC}"
set_env_key "ANTHROPIC_API_KEY" "Anthropic API Key (from console.anthropic.com)"
set_env_key "SQL_SERVER" "SQL Server address" "152.53.146.201"
set_env_key "SQL_DATABASE" "SQL Database name" "stonecutter"
set_env_key "SQL_USERNAME" "SQL Username (e.g. yourname@stonecutter.nyc)"
set_env_key "SQL_PASSWORD" "SQL Password"

# Set permissions
chmod 600 "$ENV_FILE"
print_ok "~/.env permissions set to 600 (owner-only)"

# Ensure ~/.env is sourced in shell profile
SHELL_RC="$HOME/.zshrc"
if [ -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.bashrc"
fi

if ! grep -q "source.*\.env" "$SHELL_RC" 2>/dev/null; then
  echo "" >> "$SHELL_RC"
  echo "# Stonecutter environment variables" >> "$SHELL_RC"
  echo '[ -f "$HOME/.env" ] && source "$HOME/.env"' >> "$SHELL_RC"
  print_ok "Added ~/.env sourcing to $SHELL_RC"
else
  print_ok "~/.env already sourced in $SHELL_RC"
fi

# Source it now for the rest of this script
source "$ENV_FILE" 2>/dev/null || true

# ============================================================
# PHASE 3: Install CLIs
# ============================================================
print_header "Phase 3: Installing CLIs"

# GitHub CLI (Homebrew is guaranteed by Phase 0)
if command -v gh &> /dev/null; then
  print_ok "GitHub CLI (gh) already installed"
else
  print_info "Installing GitHub CLI..."
  brew install gh 2>&1 | tail -1
  print_ok "GitHub CLI installed via Homebrew"
fi

# Authenticate gh if not already
if command -v gh &> /dev/null; then
  if gh auth status &> /dev/null; then
    print_ok "GitHub CLI already authenticated"
  else
    print_info "Opening browser for GitHub authentication..."
    echo "    Sign in with your GitHub account that has access to stonecutternyc org."
    gh auth login --web --git-protocol https 2>&1 || print_warn "GitHub auth skipped — run 'gh auth login' later"
  fi
fi

# Clone claude-integration-setup repo if not present
REPO_DIR="$HOME/Projects/stonecutter/claude-integration-setup"
if [ -d "$REPO_DIR/.git" ]; then
  print_ok "claude-integration-setup repo already cloned"
else
  if command -v gh &> /dev/null && gh auth status &> /dev/null 2>&1; then
    print_info "Cloning claude-integration-setup repo..."
    mkdir -p "$HOME/Projects/stonecutter"
    gh repo clone stonecutternyc/claude-integration-setup "$REPO_DIR" 2>&1 | tail -1
    print_ok "Repo cloned to $REPO_DIR"
  else
    print_warn "Could not clone repo — gh not authenticated. Clone manually later:"
    echo "    mkdir -p ~/Projects/stonecutter"
    echo "    gh repo clone stonecutternyc/claude-integration-setup"
  fi
fi

# Google Workspace CLI
if command -v gws &> /dev/null; then
  print_ok "Google Workspace CLI (gws) already installed"
else
  print_info "Installing Google Workspace CLI..."
  sudo npm install -g @googleworkspace/cli@latest 2>&1 | tail -1
  print_ok "gws installed"
fi

# Set up gws credentials
GWS_CONFIG_DIR="$HOME/.config/gws"
if [ -f "$GWS_CONFIG_DIR/client_secret.json" ]; then
  print_ok "gws credentials already configured"
else
  if [ -n "$GOOGLE_WORKSPACE_CLI_CLIENT_ID" ] && [ -n "$GOOGLE_WORKSPACE_CLI_CLIENT_SECRET" ]; then
    mkdir -p "$GWS_CONFIG_DIR"
    cat > "$GWS_CONFIG_DIR/client_secret.json" << GWSEOF
{"installed":{"client_id":"${GOOGLE_WORKSPACE_CLI_CLIENT_ID}","project_id":"stonecutter-gws-cli","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_secret":"${GOOGLE_WORKSPACE_CLI_CLIENT_SECRET}","redirect_uris":["http://localhost"]}}
GWSEOF
    print_ok "gws credentials written"
  else
    print_warn "Skipping gws credentials — GOOGLE_WORKSPACE_CLI_CLIENT_ID/SECRET not set in ~/.env"
  fi
fi

# Authenticate gws if not already
if command -v gws &> /dev/null; then
  if gws drive files list 2>/dev/null | head -1 | grep -q "{" &> /dev/null; then
    print_ok "gws already authenticated"
  else
    print_info "Opening browser for Google Workspace authentication..."
    echo "    Sign in with your @stonecutter.nyc Google account."
    gws auth login 2>&1 || print_warn "gws auth skipped — run 'gws auth login' later"
  fi
fi

# ============================================================
# PHASE 4: Configure MCP Servers
# ============================================================
print_header "Phase 4: Configuring MCP Servers"

SETTINGS_FILE="$HOME/.claude/settings.json"
MCP_BASE="$HOME/.claude/mcp-servers"

# Back up existing settings
if [ -f "$SETTINGS_FILE" ]; then
  cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.$(date +%Y%m%d%H%M%S)"
  print_ok "Backed up settings.json"
fi

# --- sc-sql MCP ---
print_info "Setting up sc-sql MCP server..."
SC_SQL_DIR="$MCP_BASE/sc-sql"
mkdir -p "$SC_SQL_DIR"

if [ ! -f "$SC_SQL_DIR/package.json" ]; then
  cat > "$SC_SQL_DIR/package.json" << 'PKGJSON'
{
  "name": "sc-sql",
  "version": "1.0.0",
  "type": "module",
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "mssql": "^11.0.0"
  }
}
PKGJSON
fi

cat > "$SC_SQL_DIR/server.js" << 'SERVERJS'
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import sql from "mssql";

const config = {
  server: process.env.DB_SERVER,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  port: 1433,
  options: {
    encrypt: false,
    trustServerCertificate: true,
    requestTimeout: 60000
  }
};

const server = new Server(
  { name: "sc-sql", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "run_sql_query",
      description: "Run a SQL query against the Stonecutter database (SQL Server). Returns results as JSON. Use for analytics, reporting, and data exploration across the stonecutter schema.",
      inputSchema: {
        type: "object",
        properties: {
          query: {
            type: "string",
            description: "The SQL query to execute"
          }
        },
        required: ["query"]
      }
    },
    {
      name: "list_tables",
      description: "List all tables in the Stonecutter database, optionally filtered by schema.",
      inputSchema: {
        type: "object",
        properties: {
          schema: {
            type: "string",
            description: "Schema name to filter by (e.g. 'analytics', 'dbo'). Omit to list all."
          }
        }
      }
    }
  ]
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const pool = await sql.connect(config);

  try {
    if (request.params.name === "run_sql_query") {
      const { query } = request.params.arguments;
      const result = await pool.request().query(query);
      return {
        content: [{ type: "text", text: JSON.stringify(result.recordset, null, 2) }]
      };
    }

    if (request.params.name === "list_tables") {
      const { schema } = request.params.arguments ?? {};
      const schemaFilter = schema ? `AND TABLE_SCHEMA = '${schema}'` : "";
      const result = await pool.request().query(`
        SELECT TABLE_SCHEMA, TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_TYPE = 'BASE TABLE'
        ${schemaFilter}
        ORDER BY TABLE_SCHEMA, TABLE_NAME
      `);
      return {
        content: [{ type: "text", text: JSON.stringify(result.recordset, null, 2) }]
      };
    }

    throw new Error(`Unknown tool: ${request.params.name}`);
  } finally {
    await pool.close();
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
SERVERJS

# Install sc-sql dependencies
cd "$SC_SQL_DIR"
npm install --silent 2>&1
print_ok "sc-sql server files and dependencies ready"

# --- Merge MCP configs into settings.json ---
print_info "Merging MCP server configs into settings.json..."

# Re-source env vars (may have been written fresh in Phase 2)
set -a
source "$ENV_FILE" 2>/dev/null || true
set +a

node -e "
const fs = require('fs');
const path = require('path');
const home = require('os').homedir();
const settingsPath = path.join(home, '.claude', 'settings.json');

// Read existing settings
let settings = {};
try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8')); } catch {}
if (!settings.mcpServers) settings.mcpServers = {};

// sc-sql — uses env vars from ~/.env
const sqlUser = process.env.SQL_USERNAME || '';
const sqlPass = process.env.SQL_PASSWORD || '';
const sqlServer = process.env.SQL_SERVER || '152.53.146.201';
const sqlDb = process.env.SQL_DATABASE || 'stonecutter';

if (sqlUser && sqlPass) {
  settings.mcpServers['sc-sql'] = {
    command: 'node',
    args: [path.join(home, '.claude', 'mcp-servers', 'sc-sql', 'server.js')],
    env: {
      DB_SERVER: sqlServer,
      DB_NAME: sqlDb,
      DB_USER: sqlUser,
      DB_PASSWORD: sqlPass
    }
  };
  console.log('  sc-sql: configured');
} else {
  console.log('  sc-sql: SKIPPED (no SQL credentials in ~/.env)');
}

// Remove demoted MCPs (Slack + Rainforest are now curl-only in Claude Code)
if (settings.mcpServers['slack']) {
  delete settings.mcpServers['slack'];
  console.log('  slack MCP: REMOVED (demoted to curl — saves ~1,500 tokens/message)');
}
if (settings.mcpServers['rainforest']) {
  delete settings.mcpServers['rainforest'];
  console.log('  rainforest MCP: REMOVED (demoted to curl — single endpoint)');
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
console.log('  settings.json updated');
"

# Set permissions on settings.json
chmod 600 "$SETTINGS_FILE"
print_ok "settings.json permissions set to 600"

# --- ClickUp MCP (Anthropic proxy) ---
print_info "ClickUp MCP uses the Anthropic proxy (OAuth-based)."
print_info "If not already configured, run this in Claude Code:"
echo ""
echo "    claude mcp add --transport http -s user clickup https://mcp.clickup.com/mcp"
echo ""
print_info "It will open your browser for ClickUp OAuth — sign in with your Stonecutter account."

# ============================================================
# PHASE 5: Demote Slack + Rainforest
# ============================================================
print_header "Phase 5: Slack & Rainforest (Now curl-only)"

print_info "Slack and Rainforest MCPs have been removed from settings.json (if present)."
print_info "They now work via curl — no MCP overhead, saves tokens."
echo ""
print_info "Slack usage in Claude Code:"
echo '    curl -s -X POST https://slack.com/api/chat.postMessage \'
echo '      -H "Authorization: Bearer $SLACK_BOT_TOKEN" \'
echo '      -H "Content-Type: application/json" \'
echo '      -d '"'"'{"channel":"CHANNEL_ID","text":"Your message"}'"'"
echo ""
print_info "Rainforest usage in Claude Code:"
echo '    curl -s "https://api.rainforestapi.com/request?api_key=$RAINFOREST_API_KEY&type=product&asin=YOUR_ASIN"'

# ============================================================
# PHASE 6: Verification
# ============================================================
print_header "Phase 6: Quick Verification"

PASS=0
FAIL=0

# Source env for verification
source "$ENV_FILE" 2>/dev/null || true

# Check gh
if command -v gh &> /dev/null && gh auth status &> /dev/null 2>&1; then
  print_ok "GitHub CLI — authenticated"
  ((PASS++))
else
  print_fail "GitHub CLI — not authenticated"
  ((FAIL++))
fi

# Check gws
if command -v gws &> /dev/null && gws drive files list 2>/dev/null | head -1 | grep -q "{" &> /dev/null 2>&1; then
  print_ok "Google Workspace CLI — authenticated"
  ((PASS++))
else
  print_fail "Google Workspace CLI — not authenticated or not installed"
  ((FAIL++))
fi

# Check SQL credentials exist
if [ -n "$SQL_USERNAME" ] && [ -n "$SQL_PASSWORD" ]; then
  print_ok "SQL credentials — present in ~/.env"
  ((PASS++))
else
  print_fail "SQL credentials — missing from ~/.env"
  ((FAIL++))
fi

# Check Slack token
if [ -n "$SLACK_BOT_TOKEN" ]; then
  SLACK_TEST=$(curl -s -H "Authorization: Bearer $SLACK_BOT_TOKEN" https://slack.com/api/auth.test 2>/dev/null)
  if echo "$SLACK_TEST" | grep -q '"ok":true'; then
    print_ok "Slack bot token — valid"
    ((PASS++))
  else
    print_fail "Slack bot token — invalid"
    ((FAIL++))
  fi
else
  print_fail "Slack bot token — missing from ~/.env"
  ((FAIL++))
fi

# Check settings.json has sc-sql
if grep -q '"sc-sql"' "$SETTINGS_FILE" 2>/dev/null; then
  print_ok "sc-sql MCP — configured in settings.json"
  ((PASS++))
else
  print_warn "sc-sql MCP — not in settings.json (SQL credentials may be missing)"
  ((FAIL++))
fi

echo ""
echo -e "${CYAN}━━━ Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC} ━━━"
echo ""

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}All checks passed! Open a new Claude Code session to start using your integrations.${NC}"
else
  echo -e "${YELLOW}Some checks failed — see above. You can re-run this script after fixing issues.${NC}"
fi

echo ""
echo "For detailed verification, run: bash verify-integrations.sh"
echo ""
