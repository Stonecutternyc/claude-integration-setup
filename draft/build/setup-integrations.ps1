# Stonecutter Master Integration Setup — Windows (PowerShell)
# Gets a team member fully connected to all Stonecutter tools via Claude Code.
#
# Usage: powershell -ExecutionPolicy Bypass -File setup-integrations.ps1
# Safe to re-run — checks before installing, merges instead of overwrites.

$ErrorActionPreference = "Stop"

function Write-Header($text) { Write-Host "`n--- $text ---`n" -ForegroundColor Cyan }
function Write-Ok($text)     { Write-Host "  [OK] $text" -ForegroundColor Green }
function Write-Warn($text)   { Write-Host "  [!!] $text" -ForegroundColor Yellow }
function Write-Fail($text)   { Write-Host "  [X]  $text" -ForegroundColor Red }
function Write-Info($text)   { Write-Host "  $text" }

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  Stonecutter Claude Integration Setup (Windows)  " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# PHASE 1: Prerequisites
# ============================================================
Write-Header "Phase 1: Checking Prerequisites"

# Check Claude Code
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Ok "Claude Code CLI found"
} else {
    Write-Fail "Claude Code CLI not found"
    Write-Host "    Install it first: https://docs.anthropic.com/en/docs/claude-code/overview"
    exit 1
}

# Check Node.js
if (Get-Command node -ErrorAction SilentlyContinue) {
    $nodeVersion = node --version
    Write-Ok "Node.js found ($nodeVersion)"
} else {
    Write-Fail "Node.js not found"
    Write-Host ""
    Write-Host "    Install Node.js first:" -ForegroundColor Yellow
    Write-Host "    1. Go to https://nodejs.org"
    Write-Host "    2. Download the LTS version"
    Write-Host "    3. Run the installer"
    Write-Host "    4. Close and reopen PowerShell"
    Write-Host "    5. Run this script again"
    exit 1
}

# Check npm
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Ok "npm found"
} else {
    Write-Fail "npm not found (should come with Node.js)"
    exit 1
}

# ============================================================
# PHASE 2: Set up ~/.env
# ============================================================
Write-Header "Phase 2: Setting Up ~/.env"

$envFile = "$env:USERPROFILE\.env"
$existingEnv = Test-Path $envFile

if ($existingEnv) {
    Write-Warn "~/.env already exists - will add missing keys only"
    $envContent = Get-Content $envFile -Raw -ErrorAction SilentlyContinue
} else {
    Write-Info "Creating ~/.env..."
    $envContent = ""
}

Write-Host ""
Write-Host "Open Bitwarden and find the 'Dev Keys' vault."
Write-Host "You'll paste each key when prompted. Press Enter to skip any you don't have yet."
Write-Host ""

function Set-EnvKey {
    param(
        [string]$Key,
        [string]$Prompt,
        [string]$Default = ""
    )

    # Check if key already has a non-empty value
    if ($envContent -match "(?m)^${Key}=.+") {
        Write-Ok "$Key already set"
        return
    }

    if ($Default) {
        $value = Read-Host "  $Prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($value)) { $value = $Default }
    } else {
        $value = Read-Host "  $Prompt"
    }

    # Remove existing empty line for this key
    $script:envContent = ($script:envContent -split "`n" | Where-Object { $_ -notmatch "^${Key}=" }) -join "`n"

    if (-not [string]::IsNullOrWhiteSpace($value)) {
        $script:envContent += "`n${Key}=${value}"
        Write-Ok "$Key saved"
    } else {
        $script:envContent += "`n${Key}="
        Write-Warn "$Key skipped (you can fill it in later)"
    }
}

Write-Host "-- Shared Keys (from Bitwarden 'Dev Keys' vault) --" -ForegroundColor Yellow
Set-EnvKey "SLACK_BOT_TOKEN" "Slack Bot Token (nanoclaw)"
Set-EnvKey "SLACK_TEAM_ID" "Slack Team ID"
Set-EnvKey "RAINFOREST_API_KEY" "Rainforest API Key"
Set-EnvKey "KEEPA_API_KEY" "Keepa API Key"
Set-EnvKey "BRAVE_API_KEY" "Brave Search API Key"
Set-EnvKey "APIFY_API_KEY" "Apify API Key"
Set-EnvKey "PERPLEXITY_API_KEY" "Perplexity API Key"
Set-EnvKey "GOOGLE_WORKSPACE_CLI_CLIENT_ID" "Google Workspace CLI Client ID"
Set-EnvKey "GOOGLE_WORKSPACE_CLI_CLIENT_SECRET" "Google Workspace CLI Client Secret"
Set-EnvKey "CLICKUP_API_KEY" "ClickUp API Key"
Set-EnvKey "CLICKUP_TEAM_ID" "ClickUp Team ID"

Write-Host ""
Write-Host "-- Personal Keys --" -ForegroundColor Yellow
Set-EnvKey "ANTHROPIC_API_KEY" "Anthropic API Key (from console.anthropic.com)"
Set-EnvKey "SQL_SERVER" "SQL Server address" "152.53.146.201"
Set-EnvKey "SQL_DATABASE" "SQL Database name" "stonecutter"
Set-EnvKey "SQL_USERNAME" "SQL Username (e.g. yourname@stonecutter.nyc)"
Set-EnvKey "SQL_PASSWORD" "SQL Password"

# Write the env file
$envContent.Trim() | Set-Content $envFile -Encoding UTF8
Write-Ok "~/.env written"

# Source env vars for rest of script
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $val = $matches[2].Trim()
        if ($val) { [Environment]::SetEnvironmentVariable($key, $val, "Process") }
    }
}

# Add env sourcing to PowerShell profile
$profilePath = $PROFILE.CurrentUserCurrentHost
$profileDir = Split-Path $profilePath -Parent
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Force -Path $profileDir | Out-Null }
if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Force -Path $profilePath | Out-Null }

$profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
if ($profileContent -notmatch '\.env') {
    Add-Content $profilePath "`n# Stonecutter environment variables`nif (Test-Path `"`$env:USERPROFILE\.env`") { Get-Content `"`$env:USERPROFILE\.env`" | ForEach-Object { if (`$_ -match '^([^#=]+)=(.*)$') { [Environment]::SetEnvironmentVariable(`$matches[1].Trim(), `$matches[2].Trim(), 'Process') } } }"
    Write-Ok "Added ~/.env sourcing to PowerShell profile"
} else {
    Write-Ok "~/.env already sourced in PowerShell profile"
}

# ============================================================
# PHASE 3: Install CLIs
# ============================================================
Write-Header "Phase 3: Installing CLIs"

# GitHub CLI
if (Get-Command gh -ErrorAction SilentlyContinue) {
    Write-Ok "GitHub CLI (gh) already installed"
} else {
    Write-Info "Installing GitHub CLI..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install GitHub.cli --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
        Write-Ok "GitHub CLI installed via winget"
        Write-Warn "Close and reopen PowerShell for 'gh' to be available, then re-run this script"
    } else {
        Write-Warn "winget not found. Install gh manually from: https://cli.github.com"
    }
}

# Authenticate gh
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $ghStatus = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "GitHub CLI already authenticated"
    } else {
        Write-Info "Opening browser for GitHub authentication..."
        Write-Host "    Sign in with your GitHub account that has access to stonecutternyc org."
        try { gh auth login --web --git-protocol https 2>&1 } catch { Write-Warn "GitHub auth skipped - run 'gh auth login' later" }
    }
}

# Google Workspace CLI
if (Get-Command gws -ErrorAction SilentlyContinue) {
    Write-Ok "Google Workspace CLI (gws) already installed"
} else {
    Write-Info "Installing Google Workspace CLI..."
    npm install -g @googleworkspace/cli@latest 2>&1 | Out-Null
    Write-Ok "gws installed"
}

# Set up gws credentials
$gwsConfigDir = "$env:USERPROFILE\.config\gws"
$gwsAppDataDir = "$env:APPDATA\gws"

if (Test-Path "$gwsConfigDir\client_secret.json") {
    Write-Ok "gws credentials already configured"
} else {
    $gwsClientId = [Environment]::GetEnvironmentVariable("GOOGLE_WORKSPACE_CLI_CLIENT_ID", "Process")
    $gwsClientSecret = [Environment]::GetEnvironmentVariable("GOOGLE_WORKSPACE_CLI_CLIENT_SECRET", "Process")

    if ($gwsClientId -and $gwsClientSecret) {
        New-Item -ItemType Directory -Force -Path $gwsConfigDir | Out-Null
        $gwsJson = @"
{"installed":{"client_id":"$gwsClientId","project_id":"stonecutter-gws-cli","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_secret":"$gwsClientSecret","redirect_uris":["http://localhost"]}}
"@
        $gwsJson | Set-Content "$gwsConfigDir\client_secret.json" -Encoding UTF8
        # Also copy to AppData location (Windows sometimes looks there)
        New-Item -ItemType Directory -Force -Path $gwsAppDataDir | Out-Null
        Copy-Item "$gwsConfigDir\client_secret.json" "$gwsAppDataDir\client_secret.json" -Force
        Write-Ok "gws credentials written (both locations)"
    } else {
        Write-Warn "Skipping gws credentials - GOOGLE_WORKSPACE_CLI_CLIENT_ID/SECRET not set"
    }
}

# Authenticate gws
if (Get-Command gws -ErrorAction SilentlyContinue) {
    $gwsTest = gws drive files list 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "gws already authenticated"
    } else {
        Write-Info "Opening browser for Google Workspace authentication..."
        Write-Host "    Sign in with your @stonecutter.nyc Google account."
        try { gws auth login 2>&1 } catch { Write-Warn "gws auth skipped - run 'gws auth login' later" }
    }
}

# ============================================================
# PHASE 4: Configure MCP Servers
# ============================================================
Write-Header "Phase 4: Configuring MCP Servers"

$settingsPath = "$env:USERPROFILE\.claude\settings.json"
$mcpBase = "$env:USERPROFILE\.claude\mcp-servers"

# Back up existing settings
if (Test-Path $settingsPath) {
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    Copy-Item $settingsPath "$settingsPath.backup.$timestamp"
    Write-Ok "Backed up settings.json"
}

# --- sc-sql MCP ---
Write-Info "Setting up sc-sql MCP server..."
$scSqlDir = "$mcpBase\sc-sql"
New-Item -ItemType Directory -Force -Path $scSqlDir | Out-Null

if (-not (Test-Path "$scSqlDir\package.json")) {
    @'
{
  "name": "sc-sql",
  "version": "1.0.0",
  "type": "module",
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "mssql": "^11.0.0"
  }
}
'@ | Set-Content "$scSqlDir\package.json" -Encoding UTF8
}

# Write server.js (same as Mac version)
@'
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
      description: "Run a SQL query against the Stonecutter database (SQL Server). Returns results as JSON.",
      inputSchema: {
        type: "object",
        properties: {
          query: { type: "string", description: "The SQL query to execute" }
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
          schema: { type: "string", description: "Schema name to filter by (e.g. 'analytics', 'dbo'). Omit to list all." }
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
      return { content: [{ type: "text", text: JSON.stringify(result.recordset, null, 2) }] };
    }
    if (request.params.name === "list_tables") {
      const { schema } = request.params.arguments ?? {};
      const schemaFilter = schema ? `AND TABLE_SCHEMA = '${schema}'` : "";
      const result = await pool.request().query(`
        SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_TYPE = 'BASE TABLE' ${schemaFilter}
        ORDER BY TABLE_SCHEMA, TABLE_NAME
      `);
      return { content: [{ type: "text", text: JSON.stringify(result.recordset, null, 2) }] };
    }
    throw new Error(`Unknown tool: ${request.params.name}`);
  } finally {
    await pool.close();
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
'@ | Set-Content "$scSqlDir\server.js" -Encoding UTF8

# Install dependencies
Push-Location $scSqlDir
npm install --silent 2>&1 | Out-Null
Pop-Location
Write-Ok "sc-sql server files and dependencies ready"

# --- Merge MCP configs into settings.json ---
Write-Info "Merging MCP server configs into settings.json..."

$sqlUser = [Environment]::GetEnvironmentVariable("SQL_USERNAME", "Process")
$sqlPass = [Environment]::GetEnvironmentVariable("SQL_PASSWORD", "Process")
$sqlServer = [Environment]::GetEnvironmentVariable("SQL_SERVER", "Process")
$sqlDb = [Environment]::GetEnvironmentVariable("SQL_DATABASE", "Process")

if (-not $sqlServer) { $sqlServer = "152.53.146.201" }
if (-not $sqlDb) { $sqlDb = "stonecutter" }

# Read existing settings
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
} else {
    $settings = [PSCustomObject]@{}
}

if (-not $settings.PSObject.Properties["mcpServers"]) {
    $settings | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([PSCustomObject]@{})
}

# sc-sql
if ($sqlUser -and $sqlPass) {
    $scSqlConfig = [PSCustomObject]@{
        command = "node"
        args = @("$env:USERPROFILE\.claude\mcp-servers\sc-sql\server.js")
        env = [PSCustomObject]@{
            DB_SERVER = $sqlServer
            DB_NAME = $sqlDb
            DB_USER = $sqlUser
            DB_PASSWORD = $sqlPass
        }
    }
    $settings.mcpServers | Add-Member -NotePropertyName "sc-sql" -NotePropertyValue $scSqlConfig -Force
    Write-Info "  sc-sql: configured"
} else {
    Write-Info "  sc-sql: SKIPPED (no SQL credentials in ~/.env)"
}

# Remove demoted MCPs
if ($settings.mcpServers.PSObject.Properties["slack"]) {
    $settings.mcpServers.PSObject.Properties.Remove("slack")
    Write-Info "  slack MCP: REMOVED (demoted to curl)"
}
if ($settings.mcpServers.PSObject.Properties["rainforest"]) {
    $settings.mcpServers.PSObject.Properties.Remove("rainforest")
    Write-Info "  rainforest MCP: REMOVED (demoted to curl)"
}

$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
Write-Ok "settings.json updated"

# ClickUp
Write-Info "ClickUp MCP uses the Anthropic proxy (OAuth-based)."
Write-Info "If not already configured, run this in Claude Code:"
Write-Host ""
Write-Host "    claude mcp add --transport http -s user clickup https://mcp.clickup.com/mcp" -ForegroundColor Yellow
Write-Host ""
Write-Info "It will open your browser for ClickUp OAuth."

# ============================================================
# PHASE 5: Demote Slack + Rainforest
# ============================================================
Write-Header "Phase 5: Slack & Rainforest (Now curl-only)"

Write-Info "Slack and Rainforest MCPs removed from settings.json (if present)."
Write-Info "They now work via curl in Claude Code — saves tokens."
Write-Host ""
Write-Info "Slack: curl -H 'Authorization: Bearer %SLACK_BOT_TOKEN%' https://slack.com/api/chat.postMessage ..."
Write-Info "Rainforest: curl 'https://api.rainforestapi.com/request?api_key=%RAINFOREST_API_KEY%&type=product&asin=ASIN'"

# ============================================================
# PHASE 6: Quick Verification
# ============================================================
Write-Header "Phase 6: Quick Verification"

$pass = 0
$fail = 0

# gh
if ((Get-Command gh -ErrorAction SilentlyContinue) -and ((gh auth status 2>&1) -match "Logged in")) {
    Write-Ok "GitHub CLI - authenticated"
    $pass++
} else {
    Write-Fail "GitHub CLI - not authenticated"
    $fail++
}

# gws
if (Get-Command gws -ErrorAction SilentlyContinue) {
    $gwsTest = gws drive files list 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Ok "Google Workspace CLI - authenticated"; $pass++ }
    else { Write-Fail "Google Workspace CLI - not authenticated"; $fail++ }
} else {
    Write-Fail "Google Workspace CLI - not installed"
    $fail++
}

# SQL credentials
$sqlUser = [Environment]::GetEnvironmentVariable("SQL_USERNAME", "Process")
$sqlPass = [Environment]::GetEnvironmentVariable("SQL_PASSWORD", "Process")
if ($sqlUser -and $sqlPass) { Write-Ok "SQL credentials - present"; $pass++ }
else { Write-Fail "SQL credentials - missing"; $fail++ }

# Slack token
$slackToken = [Environment]::GetEnvironmentVariable("SLACK_BOT_TOKEN", "Process")
if ($slackToken) {
    try {
        $slackTest = Invoke-RestMethod -Uri "https://slack.com/api/auth.test" -Headers @{ Authorization = "Bearer $slackToken" } -ErrorAction Stop
        if ($slackTest.ok) { Write-Ok "Slack bot token - valid"; $pass++ }
        else { Write-Fail "Slack bot token - invalid"; $fail++ }
    } catch { Write-Fail "Slack bot token - connection error"; $fail++ }
} else {
    Write-Fail "Slack bot token - missing"
    $fail++
}

# sc-sql in settings
$settingsContent = Get-Content $settingsPath -Raw -ErrorAction SilentlyContinue
if ($settingsContent -match "sc-sql") { Write-Ok "sc-sql MCP - configured"; $pass++ }
else { Write-Warn "sc-sql MCP - not configured"; $fail++ }

Write-Host ""
Write-Host "--- Results: $pass passed, $fail failed ---" -ForegroundColor Cyan
Write-Host ""

if ($fail -eq 0) {
    Write-Host "All checks passed! Open a new Claude Code session to use your integrations." -ForegroundColor Green
} else {
    Write-Host "Some checks failed - see above. Re-run this script after fixing issues." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "For detailed verification, run: powershell verify-integrations.ps1"
Write-Host ""
