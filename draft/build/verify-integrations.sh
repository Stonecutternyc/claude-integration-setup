#!/bin/bash
# Stonecutter Integration Verification — macOS
# Tests each connection independently and reports pass/fail.
#
# Usage: bash verify-integrations.sh

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_ok()   { echo -e "  ${GREEN}PASS${NC}  $1"; }
print_fail() { echo -e "  ${RED}FAIL${NC}  $1"; }
print_warn() { echo -e "  ${YELLOW}SKIP${NC}  $1"; }

echo ""
echo -e "${CYAN}Stonecutter Integration Verification${NC}"
echo -e "${CYAN}=====================================${NC}"
echo ""

# Source env
source "$HOME/.env" 2>/dev/null || true

PASS=0
FAIL=0
SKIP=0

# ── 1. ~/.env exists and has content ──
echo -e "${CYAN}Environment${NC}"
if [ -f "$HOME/.env" ]; then
  KEY_COUNT=$(grep -c "^[A-Z].*=.\+" "$HOME/.env" 2>/dev/null || echo 0)
  print_ok "~/.env exists ($KEY_COUNT keys with values)"
  ((PASS++))
else
  print_fail "~/.env does not exist"
  ((FAIL++))
fi

# ── 2. GitHub CLI ──
echo -e "\n${CYAN}GitHub CLI (gh)${NC}"
if command -v gh &> /dev/null; then
  print_ok "gh installed ($(gh --version | head -1))"
  ((PASS++))

  if gh auth status &> /dev/null 2>&1; then
    GH_USER=$(gh api user --jq '.login' 2>/dev/null)
    print_ok "gh authenticated as $GH_USER"
    ((PASS++))

    # Check org access
    if gh api orgs/stonecutternyc &> /dev/null 2>&1; then
      print_ok "gh has access to stonecutternyc org"
      ((PASS++))
    else
      print_fail "gh cannot access stonecutternyc org"
      ((FAIL++))
    fi
  else
    print_fail "gh not authenticated — run: gh auth login"
    ((FAIL++))
    ((SKIP++))
  fi
else
  print_fail "gh not installed — run: brew install gh"
  ((FAIL++))
  ((SKIP++))
fi

# ── 3. Google Workspace CLI ──
echo -e "\n${CYAN}Google Workspace CLI (gws)${NC}"
if command -v gws &> /dev/null; then
  print_ok "gws installed"
  ((PASS++))

  GWS_TEST=$(gws drive files list 2>/dev/null | head -1 | grep -q "{" 2>&1)
  if [ $? -eq 0 ]; then
    print_ok "gws authenticated (Drive access confirmed)"
    ((PASS++))
  else
    print_fail "gws not authenticated — run: gws auth login"
    ((FAIL++))
  fi
else
  print_fail "gws not installed — run: sudo npm install -g @googleworkspace/cli@latest"
  ((FAIL++))
fi

# ── 4. SQL Server ──
echo -e "\n${CYAN}SQL Server (sc-sql MCP)${NC}"
SETTINGS_FILE="$HOME/.claude/settings.json"

if [ -n "$SQL_USERNAME" ] && [ -n "$SQL_PASSWORD" ]; then
  print_ok "SQL credentials present (user: $SQL_USERNAME)"
  ((PASS++))
else
  print_fail "SQL credentials missing from ~/.env (SQL_USERNAME / SQL_PASSWORD)"
  ((FAIL++))
fi

if grep -q '"sc-sql"' "$SETTINGS_FILE" 2>/dev/null; then
  print_ok "sc-sql MCP configured in settings.json"
  ((PASS++))
else
  print_fail "sc-sql MCP not in settings.json"
  ((FAIL++))
fi

# Test actual SQL connection via node
if [ -n "$SQL_USERNAME" ] && [ -n "$SQL_PASSWORD" ] && [ -f "$HOME/.claude/mcp-servers/sc-sql/server.js" ]; then
  SQL_RESULT=$(node -e "
    const sql = require('$HOME/.claude/mcp-servers/sc-sql/node_modules/mssql');
    sql.connect({
      server: '${SQL_SERVER:-152.53.146.201}',
      database: '${SQL_DATABASE:-stonecutter}',
      user: '$SQL_USERNAME',
      password: '$SQL_PASSWORD',
      port: 1433,
      options: { encrypt: false, trustServerCertificate: true, requestTimeout: 10000 }
    }).then(pool => pool.request().query('SELECT 1 AS ok'))
      .then(r => { console.log('OK'); process.exit(0); })
      .catch(e => { console.log('ERROR: ' + e.message); process.exit(1); });
  " 2>&1)
  if echo "$SQL_RESULT" | grep -q "OK"; then
    print_ok "SQL connection test — successful"
    ((PASS++))
  else
    print_fail "SQL connection test — $SQL_RESULT"
    ((FAIL++))
  fi
else
  print_warn "SQL connection test — skipped (missing credentials or server.js)"
  ((SKIP++))
fi

# ── 5. Slack (curl) ──
echo -e "\n${CYAN}Slack (curl)${NC}"
if [ -n "$SLACK_BOT_TOKEN" ]; then
  SLACK_RESULT=$(curl -s -H "Authorization: Bearer $SLACK_BOT_TOKEN" https://slack.com/api/auth.test 2>/dev/null)
  if echo "$SLACK_RESULT" | grep -q '"ok":true'; then
    BOT_NAME=$(echo "$SLACK_RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('user','unknown'))" 2>/dev/null)
    print_ok "Slack bot token valid (bot: $BOT_NAME)"
    ((PASS++))
  else
    print_fail "Slack bot token invalid"
    ((FAIL++))
  fi
else
  print_fail "SLACK_BOT_TOKEN missing from ~/.env"
  ((FAIL++))
fi

# ── 6. Rainforest (curl) ──
echo -e "\n${CYAN}Rainforest API (curl)${NC}"
if [ -n "$RAINFOREST_API_KEY" ]; then
  RF_RESULT=$(curl -s "https://api.rainforestapi.com/request?api_key=$RAINFOREST_API_KEY&type=product&asin=B08N5WRWNW" 2>/dev/null | head -c 200)
  if echo "$RF_RESULT" | grep -q '"product"'; then
    print_ok "Rainforest API key valid"
    ((PASS++))
  elif echo "$RF_RESULT" | grep -q '"request_info"'; then
    print_ok "Rainforest API key accepted (response received)"
    ((PASS++))
  else
    print_fail "Rainforest API key — unexpected response"
    ((FAIL++))
  fi
else
  print_warn "RAINFOREST_API_KEY missing from ~/.env"
  ((SKIP++))
fi

# ── 7. ClickUp ──
echo -e "\n${CYAN}ClickUp${NC}"
if [ -n "$CLICKUP_API_KEY" ]; then
  CU_RESULT=$(curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/team" 2>/dev/null)
  if echo "$CU_RESULT" | grep -q '"teams"'; then
    print_ok "ClickUp API key valid"
    ((PASS++))
  else
    print_fail "ClickUp API key invalid"
    ((FAIL++))
  fi
else
  print_warn "CLICKUP_API_KEY missing (ClickUp MCP uses Anthropic proxy — may still work)"
  ((SKIP++))
fi

# ── 8. Demoted MCPs removed ──
echo -e "\n${CYAN}Cleanup${NC}"
if grep -q '"slack"' "$SETTINGS_FILE" 2>/dev/null; then
  print_warn "Slack MCP still in settings.json (should be removed — it's curl-only now)"
  ((FAIL++))
else
  print_ok "Slack MCP correctly absent from settings.json"
  ((PASS++))
fi

if grep -q '"rainforest"' "$SETTINGS_FILE" 2>/dev/null; then
  print_warn "Rainforest MCP still in settings.json (should be removed)"
  ((FAIL++))
else
  print_ok "Rainforest MCP correctly absent from settings.json"
  ((PASS++))
fi

# ── Summary ──
echo ""
echo -e "${CYAN}=====================================${NC}"
echo -e "  ${GREEN}PASS: $PASS${NC}  |  ${RED}FAIL: $FAIL${NC}  |  ${YELLOW}SKIP: $SKIP${NC}"
echo -e "${CYAN}=====================================${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}All tests passed! Your integrations are fully configured.${NC}"
elif [ $FAIL -le 2 ]; then
  echo -e "${YELLOW}Almost there — fix the failures above and re-run.${NC}"
else
  echo -e "${RED}Several failures — re-run the setup script or check ~/.env.${NC}"
fi
echo ""
