#Requires -Version 5.1
# Simple Google Drive setup for rclone (Windows)
# Usage: .\setup-drive.ps1 [--full]
#   --full: Grant full access (upload/delete). Default is read-only.

param(
    [switch]$Full
)

$ErrorActionPreference = "Stop"

$Scope = "drive.readonly"
$ScopeDesc = "read-only"
if ($Full) {
    $Scope = "drive"
    $ScopeDesc = "full"
}

Write-Host "=== Google Drive Setup ($ScopeDesc access) ===" -ForegroundColor Cyan
Write-Host ""

# Check/install rclone
$rclone = Get-Command rclone -ErrorAction SilentlyContinue
if (-not $rclone) {
    Write-Host "rclone not found. Installing..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        & winget install Rclone.Rclone --accept-source-agreements --accept-package-agreements
    } else {
        Write-Host "Error: Please run SETUP.ps1 first to install rclone, or install manually:" -ForegroundColor Red
        Write-Host "  https://rclone.org/install/" -ForegroundColor Red
        exit 1
    }
    # Re-check
    $rclone = Get-Command rclone -ErrorAction SilentlyContinue
    if (-not $rclone) {
        Write-Host "rclone still not found after install. Restart your terminal and try again." -ForegroundColor Red
        exit 1
    }
}

# Check if already configured
$remotes = & rclone listremotes 2>$null
if ($remotes -match "^gdrive:") {
    Write-Host "Google Drive is already configured."
    Write-Host "Testing connection..."
    $test = & rclone lsd gdrive: --max-depth 1 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Connection works." -ForegroundColor Green
        $test | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "Connection failed. Run: rclone config reconnect gdrive:" -ForegroundColor Red
    }
    exit 0
}

Write-Host "Opening browser for Google authentication..."
Write-Host "Sign in and click 'Allow', then come back here."
Write-Host ""

# Get token via browser
$tokenOutput = & rclone authorize "drive" --drive-scope $Scope 2>&1 | Out-String

# Extract the token JSON from output
$tokenMatch = [regex]::Match($tokenOutput, '\{[^{}]*"access_token"[^{}]*\}')
$token = ""
if ($tokenMatch.Success) {
    $token = $tokenMatch.Value
}

if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host ""
    Write-Host "Couldn't auto-capture the token."
    Write-Host "Copy the token JSON from above (looks like {`"access_token`":`"...`"})"
    Write-Host ""
    $token = Read-Host "Paste here"
}

# Create the remote
Write-Host ""
Write-Host "Configuring..."
& rclone config create gdrive drive token $token scope $Scope --non-interactive

# Test
Write-Host ""
$test = & rclone lsd gdrive: --max-depth 1 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Success! Google Drive connected ($ScopeDesc access)." -ForegroundColor Green
    Write-Host ""
    $test | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "Something went wrong. Try: rclone config" -ForegroundColor Red
}
