#Requires -Version 5.1
# Automated voice note processing (Windows)
# Routes transcribed voice notes to the right places in the workspace
# Runs on schedule via Task Scheduler — no human input required

$ErrorActionPreference = "Stop"

# Find workspace root (parent of ops\scripts\scheduled\)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Workspace = Resolve-Path (Join-Path $ScriptDir "..\..\..") | Select-Object -ExpandProperty Path
Set-Location $Workspace

$LastRun = Join-Path $Workspace ".voice\last-auto-run"

# Check if voice.md has any content
$voiceMd = Join-Path $Workspace "voice.md"
if (-not (Test-Path $voiceMd) -or (Get-Item $voiceMd).Length -eq 0) {
    Write-Host "No voice entries to process"
    exit 0
}

# Skip if voice.md hasn't been modified since last successful run
if (Test-Path $LastRun) {
    $voiceModified = (Get-Item $voiceMd).LastWriteTime
    $lastRunTime = (Get-Item $LastRun).LastWriteTime
    if ($voiceModified -le $lastRunTime) {
        Write-Host "voice.md unchanged since last run"
        exit 0
    }
}

# Find claude binary
$Claude = $null

# Check PATH first
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeCmd) {
    $Claude = $claudeCmd.Source
}

# Check common install paths
if (-not $Claude) {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\claude\claude.exe"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages" "Anthropic.Claude*\claude.exe"),
        (Join-Path $env:APPDATA "npm\claude.cmd")
    )
    foreach ($c in $candidates) {
        # Handle wildcard paths
        $resolved = Resolve-Path $c -ErrorAction SilentlyContinue
        if ($resolved) {
            $Claude = $resolved.Path
            break
        }
    }
}

if (-not $Claude) {
    Write-Host "Claude CLI not found. Install it from https://claude.ai/download or via npm: npm install -g @anthropic-ai/claude-code"
    exit 1
}

$output = & $Claude -p "/voice" --dangerously-skip-permissions 2>&1
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Host "Voice processing failed (exit code $exitCode)"
    exit 1
}

# Mark successful run
$voiceDir = Join-Path $Workspace ".voice"
New-Item -ItemType Directory -Path $voiceDir -Force | Out-Null
New-Item -ItemType File -Path $LastRun -Force | Out-Null

Write-Host "Voice routing complete"
