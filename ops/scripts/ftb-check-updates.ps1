#Requires -Version 5.1
# Check for updates from feed-the-beast repo (Windows)
# Compares local manifest.json against remote, then shows what changed

$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/derek-larson14/feed-the-beast/archive/main.zip"
$ManifestUrl = "https://raw.githubusercontent.com/derek-larson14/feed-the-beast/main/manifest.json"
$TmpZip = Join-Path $env:TEMP "ftb-update.zip"
$TmpDir = Join-Path $env:TEMP "ftb-update"
$Extracted = Join-Path $TmpDir "feed-the-beast-main"

# Clean up any previous run
if (Test-Path $TmpZip) { Remove-Item $TmpZip -Force }
if (Test-Path $TmpDir) { Remove-Item $TmpDir -Recurse -Force }

# Check local manifest
$LocalManifest = "manifest.json"
if (Test-Path $LocalManifest) {
    $manifest = Get-Content $LocalManifest -Raw | ConvertFrom-Json
    $LocalVersion = $manifest.version
    $LocalCmdVer = $manifest.commands_version
    $LocalScriptVer = $manifest.scripts_version
    Write-Host "Local version: $LocalVersion (commands: $LocalCmdVer, scripts: $LocalScriptVer)"
} else {
    Write-Host "No local manifest.json found - first update will create one."
    $LocalVersion = "none"
    $LocalCmdVer = 0
    $LocalScriptVer = 0
}

# Fetch remote manifest first (quick check)
Write-Host ""
Write-Host "Checking latest version..."

try {
    $remoteContent = Invoke-WebRequest -Uri $ManifestUrl -UseBasicParsing -ErrorAction Stop
    $remote = $remoteContent.Content | ConvertFrom-Json
    $RemoteVersion = $remote.version
    $RemoteCmdVer = $remote.commands_version
    $RemoteScriptVer = $remote.scripts_version
    Write-Host "Latest version: $RemoteVersion (commands: $RemoteCmdVer, scripts: $RemoteScriptVer)"

    if ($LocalCmdVer -eq $RemoteCmdVer -and $LocalScriptVer -eq $RemoteScriptVer) {
        Write-Host ""
        Write-Host "Everything is up to date."
        exit 0
    }
    Write-Host ""
    Write-Host "Updates available. Downloading..."
} catch {
    Write-Host "Could not fetch remote manifest. Falling back to full check."
}

# Download and extract
try {
    Invoke-WebRequest -Uri $RepoUrl -OutFile $TmpZip -UseBasicParsing
} catch {
    Write-Host "ERROR: Failed to download. Check your connection." -ForegroundColor Red
    exit 1
}

try {
    Expand-Archive -Path $TmpZip -DestinationPath $TmpDir -Force
} catch {
    Write-Host "ERROR: Failed to extract zip." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $Extracted)) {
    Write-Host "ERROR: Expected directory not found after extraction." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== COMMANDS ==="

# Check upstream commands
$upstreamCmds = Join-Path $Extracted ".claude\commands"
if (Test-Path $upstreamCmds) {
    Get-ChildItem (Join-Path $upstreamCmds "*.md") | ForEach-Object {
        $name = $_.Name
        if ($name -eq "update.md") { return }

        $existing = Join-Path ".claude\commands" $name
        if (Test-Path $existing) {
            $diff = Compare-Object (Get-Content $_.FullName) (Get-Content $existing)
            if ($diff) {
                Write-Host "CHANGED: $name"
            }
        } else {
            Write-Host "NEW: $name"
        }
    }
}

# Check for local-only commands
$localCmds = Join-Path "." ".claude\commands"
if (Test-Path $localCmds) {
    Get-ChildItem (Join-Path $localCmds "*.md") | ForEach-Object {
        $name = $_.Name
        if ($name -eq "update.md") { return }

        $upstream = Join-Path $upstreamCmds $name
        if (-not (Test-Path $upstream)) {
            Write-Host "LOCAL ONLY: $name"
        }
    }
}

Write-Host ""
Write-Host "=== SETUP FILES ==="

# Check for SETUP.command and SETUP.ps1
foreach ($setupFile in @("SETUP.command", "SETUP.ps1")) {
    $upstreamSetup = Join-Path $Extracted $setupFile
    if (Test-Path $upstreamSetup) {
        if (Test-Path $setupFile) {
            $diff = Compare-Object (Get-Content $upstreamSetup) (Get-Content $setupFile)
            if ($diff) {
                Write-Host "CHANGED: $setupFile"
            }
        } else {
            Write-Host "NEW: $setupFile"
        }
    }
}

Write-Host ""
Write-Host "=== SCRIPTS ==="

# Check upstream scripts (both .sh and .ps1)
$upstreamScripts = Join-Path $Extracted "ops\scripts"
if (Test-Path $upstreamScripts) {
    Get-ChildItem $upstreamScripts -File -Include "*.sh","*.ps1" | ForEach-Object {
        $name = $_.Name
        $existing = Join-Path "ops\scripts" $name
        if (Test-Path $existing) {
            $diff = Compare-Object (Get-Content $_.FullName) (Get-Content $existing)
            if ($diff) {
                Write-Host "CHANGED: $name"
            }
        } else {
            Write-Host "NEW: $name"
        }
    }

    # Check scheduled scripts
    $upstreamScheduled = Join-Path $upstreamScripts "scheduled"
    if (Test-Path $upstreamScheduled) {
        Get-ChildItem $upstreamScheduled -File -Include "*.sh","*.ps1" | ForEach-Object {
            $name = $_.Name
            $existing = Join-Path "ops\scripts\scheduled" $name
            if (Test-Path $existing) {
                $diff = Compare-Object (Get-Content $_.FullName) (Get-Content $existing)
                if ($diff) {
                    Write-Host "CHANGED: scheduled/$name"
                }
            } else {
                Write-Host "NEW: scheduled/$name"
            }
        }
    }
} else {
    Write-Host "(no scripts in repo)"
}

# Check for local-only scripts
if (Test-Path "ops\scripts") {
    Get-ChildItem "ops\scripts" -File -Include "*.sh","*.ps1" | ForEach-Object {
        $name = $_.Name
        if ($name -eq "ftb-check-updates.sh" -or $name -eq "ftb-check-updates.ps1") { return }

        $upstream = Join-Path $upstreamScripts $name
        if (-not (Test-Path $upstream)) {
            Write-Host "LOCAL ONLY: $name"
        }
    }
}

Write-Host ""
Write-Host "Source files extracted to: $Extracted"
Write-Host "Run cleanup when done: Remove-Item '$TmpDir','$TmpZip' -Recurse -Force"
