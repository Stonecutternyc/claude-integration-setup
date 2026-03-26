# Stonecutter Integration Verification — Windows (PowerShell)
# Tests each connection independently and reports pass/fail.
#
# Usage: powershell -ExecutionPolicy Bypass -File verify-integrations.ps1

function Write-Ok($text)   { Write-Host "  PASS  $text" -ForegroundColor Green }
function Write-Fail($text) { Write-Host "  FAIL  $text" -ForegroundColor Red }
function Write-Skip($text) { Write-Host "  SKIP  $text" -ForegroundColor Yellow }

Write-Host ""
Write-Host "Stonecutter Integration Verification" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Source env
$envFile = "$env:USERPROFILE\.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^#=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $val = $matches[2].Trim()
            if ($val) { [Environment]::SetEnvironmentVariable($key, $val, "Process") }
        }
    }
}

$pass = 0; $fail = 0; $skip = 0

# -- 1. ~/.env --
Write-Host "Environment" -ForegroundColor Cyan
if (Test-Path $envFile) {
    $keyCount = (Get-Content $envFile | Where-Object { $_ -match '^[A-Z].*=.+' }).Count
    Write-Ok "~/.env exists ($keyCount keys with values)"
    $pass++
} else {
    Write-Fail "~/.env does not exist"
    $fail++
}

# -- 2. GitHub CLI --
Write-Host "`nGitHub CLI (gh)" -ForegroundColor Cyan
if (Get-Command gh -ErrorAction SilentlyContinue) {
    Write-Ok "gh installed"
    $pass++

    $ghStatus = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) {
        $ghUser = gh api user --jq '.login' 2>&1
        Write-Ok "gh authenticated as $ghUser"
        $pass++

        $orgCheck = gh api orgs/stonecutternyc 2>&1
        if ($LASTEXITCODE -eq 0) { Write-Ok "gh has access to stonecutternyc org"; $pass++ }
        else { Write-Fail "gh cannot access stonecutternyc org"; $fail++ }
    } else {
        Write-Fail "gh not authenticated - run: gh auth login"
        $fail++; $skip++
    }
} else {
    Write-Fail "gh not installed - run: winget install GitHub.cli"
    $fail++; $skip++
}

# -- 3. Google Workspace CLI --
Write-Host "`nGoogle Workspace CLI (gws)" -ForegroundColor Cyan
if (Get-Command gws -ErrorAction SilentlyContinue) {
    Write-Ok "gws installed"
    $pass++

    $gwsOk = $false
    try {
        $gwsTest = gws drive files list 2>&1
        if ($LASTEXITCODE -eq 0) { $gwsOk = $true }
    } catch { }
    if ($gwsOk) { Write-Ok "gws authenticated (Drive access confirmed)"; $pass++ }
    else { Write-Fail "gws not authenticated - run: gws auth login"; $fail++ }
} else {
    Write-Fail "gws not installed - run: npm install -g @googleworkspace/cli@latest"
    $fail++
}

# -- 4. SQL Server --
Write-Host "`nSQL Server (sc-sql MCP)" -ForegroundColor Cyan
$settingsPath = "$env:USERPROFILE\.claude\settings.json"

$sqlUser = [Environment]::GetEnvironmentVariable("SQL_USERNAME", "Process")
$sqlPass = [Environment]::GetEnvironmentVariable("SQL_PASSWORD", "Process")

if ($sqlUser -and $sqlPass) { Write-Ok "SQL credentials present (user: $sqlUser)"; $pass++ }
else { Write-Fail "SQL credentials missing from ~/.env"; $fail++ }

$settingsContent = Get-Content $settingsPath -Raw -ErrorAction SilentlyContinue
if ($settingsContent -match '"sc-sql"') { Write-Ok "sc-sql MCP configured in settings.json"; $pass++ }
else { Write-Fail "sc-sql MCP not in settings.json"; $fail++ }

# -- 5. Slack --
Write-Host "`nSlack (curl)" -ForegroundColor Cyan
$slackToken = [Environment]::GetEnvironmentVariable("SLACK_BOT_TOKEN", "Process")
if ($slackToken) {
    try {
        $slackResult = Invoke-RestMethod -Uri "https://slack.com/api/auth.test" -Headers @{ Authorization = "Bearer $slackToken" } -ErrorAction Stop
        if ($slackResult.ok) { Write-Ok "Slack bot token valid (bot: $($slackResult.user))"; $pass++ }
        else { Write-Fail "Slack bot token invalid"; $fail++ }
    } catch { Write-Fail "Slack connection error"; $fail++ }
} else {
    Write-Fail "SLACK_BOT_TOKEN missing from ~/.env"
    $fail++
}

# -- 6. Rainforest --
Write-Host "`nRainforest API (curl)" -ForegroundColor Cyan
$rfKey = [Environment]::GetEnvironmentVariable("RAINFOREST_API_KEY", "Process")
if ($rfKey) {
    try {
        $rfResult = Invoke-RestMethod -Uri "https://api.rainforestapi.com/request?api_key=$rfKey&type=product&asin=B08N5WRWNW" -ErrorAction Stop
        if ($rfResult.product -or $rfResult.request_info) { Write-Ok "Rainforest API key valid"; $pass++ }
        else { Write-Fail "Rainforest API key - unexpected response"; $fail++ }
    } catch { Write-Fail "Rainforest API connection error"; $fail++ }
} else {
    Write-Skip "RAINFOREST_API_KEY missing"
    $skip++
}

# -- 7. ClickUp --
Write-Host "`nClickUp" -ForegroundColor Cyan
$cuKey = [Environment]::GetEnvironmentVariable("CLICKUP_API_KEY", "Process")
if ($cuKey) {
    try {
        $cuResult = Invoke-RestMethod -Uri "https://api.clickup.com/api/v2/team" -Headers @{ Authorization = $cuKey } -ErrorAction Stop
        if ($cuResult.teams) { Write-Ok "ClickUp API key valid"; $pass++ }
        else { Write-Fail "ClickUp API key invalid"; $fail++ }
    } catch { Write-Fail "ClickUp connection error"; $fail++ }
} else {
    Write-Skip "CLICKUP_API_KEY missing (proxy may still work)"
    $skip++
}

# -- 8. Cleanup --
Write-Host "`nCleanup" -ForegroundColor Cyan
if ($settingsContent -match '"slack"') { Write-Fail "Slack MCP still in settings.json (should be removed)"; $fail++ }
else { Write-Ok "Slack MCP correctly absent"; $pass++ }

if ($settingsContent -match '"rainforest"') { Write-Fail "Rainforest MCP still in settings.json (should be removed)"; $fail++ }
else { Write-Ok "Rainforest MCP correctly absent"; $pass++ }

# -- Summary --
Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  PASS: $pass  |  FAIL: $fail  |  SKIP: $skip" -ForegroundColor White
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

if ($fail -eq 0) { Write-Host "All tests passed! Integrations fully configured." -ForegroundColor Green }
elseif ($fail -le 2) { Write-Host "Almost there - fix the failures above and re-run." -ForegroundColor Yellow }
else { Write-Host "Several failures - re-run the setup script or check ~/.env." -ForegroundColor Red }
Write-Host ""
