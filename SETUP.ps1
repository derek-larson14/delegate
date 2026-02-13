#Requires -Version 5.1
# =============================================================================
# Claude Workspace Setup (Windows)
# =============================================================================
# Run this once after downloading the workspace.
# Right-click this file -> Run with PowerShell
#
# This installs CLI tools needed by slash commands:
#   - rclone (for /drive)
#   - jq (for /messages)
#
# Note: /calendar and /mail are Mac-only.
# /messages needs Beeper Desktop (beeper.com/download/windows).
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host ([char]0x2501) * 76 -ForegroundColor Cyan
Write-Host "  Claude Workspace Setup (Windows)" -ForegroundColor Cyan
Write-Host ([char]0x2501) * 76 -ForegroundColor Cyan
Write-Host ""

# Check execution policy
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq "Restricted" -or $policy -eq "Undefined") {
    Write-Host "[!] PowerShell execution policy is '$policy'." -ForegroundColor Yellow
    Write-Host "    Run this command first, then re-run SETUP.ps1:" -ForegroundColor Yellow
    Write-Host "    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
    Write-Host ""
    exit 1
}

$Installed = @()
$Skipped = @()
$Failed = @()

# -----------------------------------------------------------------------------
# Helper: Install via winget with direct-download fallback
# -----------------------------------------------------------------------------
function Install-Tool {
    param(
        [string]$Name,
        [string]$Command,
        [string]$WingetId,
        [string]$FallbackUrl,
        [string]$FallbackExtractPath
    )

    Write-Host "      Installing $Name..."

    # Try winget first
    $wingetAvailable = $null
    try { $wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue } catch {}

    if ($wingetAvailable) {
        Write-Host "      Using winget..."
        $result = & winget install $WingetId --accept-source-agreements --accept-package-agreements 2>&1
        # Check if command is now available (may need new terminal)
        $found = Get-Command $Command -ErrorAction SilentlyContinue
        if ($found) { return $true }
        # winget may succeed but PATH not updated in this session
        Write-Host "      Installed via winget. You may need to restart your terminal for '$Command' to be available." -ForegroundColor Yellow
        return $true
    }

    # Fallback: direct download
    if ($FallbackUrl) {
        Write-Host "      winget not available. Downloading directly..."

        $tmpFile = Join-Path $env:TEMP "$Name-download.zip"
        try {
            Invoke-WebRequest -Uri $FallbackUrl -OutFile $tmpFile -UseBasicParsing
            $extractDir = Join-Path $env:LOCALAPPDATA "Programs\$Name"
            New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
            Expand-Archive -Path $tmpFile -DestinationPath $extractDir -Force

            # If there's a nested folder (like rclone-vX.X.X-windows-amd64), move contents up
            if ($FallbackExtractPath) {
                $nested = Get-ChildItem $extractDir -Directory | Select-Object -First 1
                if ($nested) {
                    Get-ChildItem $nested.FullName | Move-Item -Destination $extractDir -Force
                    Remove-Item $nested.FullName -Force -Recurse -ErrorAction SilentlyContinue
                }
            }

            # Add to user PATH if not already there
            $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
            if ($userPath -notlike "*$extractDir*") {
                [Environment]::SetEnvironmentVariable("Path", "$userPath;$extractDir", "User")
                $env:Path = "$env:Path;$extractDir"
                Write-Host "      Added $extractDir to PATH." -ForegroundColor Yellow
                Write-Host "      NOTE: Open a new terminal for PATH changes to take effect." -ForegroundColor Yellow
            }

            Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
            return $true
        } catch {
            Write-Host "      Download failed: $_" -ForegroundColor Red
            Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
            return $false
        }
    }

    Write-Host "      No installation method available." -ForegroundColor Red
    return $false
}

# -----------------------------------------------------------------------------
# rclone (for /drive)
# -----------------------------------------------------------------------------
Write-Host "[1/2] Checking rclone (for /drive)..."

if (Get-Command rclone -ErrorAction SilentlyContinue) {
    $Skipped += "rclone"
    Write-Host "      OK Already installed" -ForegroundColor Green
} else {
    $success = Install-Tool `
        -Name "rclone" `
        -Command "rclone" `
        -WingetId "Rclone.Rclone" `
        -FallbackUrl "https://downloads.rclone.org/rclone-current-windows-amd64.zip" `
        -FallbackExtractPath "nested"

    if ($success) {
        $Installed += "rclone"
        Write-Host "      OK rclone installed" -ForegroundColor Green
    } else {
        $Failed += "rclone"
        Write-Host "      FAIL Install manually: https://rclone.org/install/" -ForegroundColor Red
    }
}

# -----------------------------------------------------------------------------
# jq (for /messages)
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "[2/2] Checking jq (for /messages)..."

if (Get-Command jq -ErrorAction SilentlyContinue) {
    $Skipped += "jq"
    Write-Host "      OK Already installed" -ForegroundColor Green
} else {
    $success = Install-Tool `
        -Name "jq" `
        -Command "jq" `
        -WingetId "jqlang.jq" `
        -FallbackUrl "https://github.com/jqlang/jq/releases/latest/download/jq-windows-amd64.exe" `
        -FallbackExtractPath $null

    if ($success) {
        $Installed += "jq"
        Write-Host "      OK jq installed" -ForegroundColor Green
    } else {
        $Failed += "jq"
        Write-Host "      FAIL Install manually: https://jqlang.github.io/jq/download/" -ForegroundColor Red
    }
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
Write-Host ""

if ($Installed.Count -gt 0) {
    Write-Host "Installed: $($Installed -join ', ')"
}
if ($Skipped.Count -gt 0) {
    Write-Host "Already installed: $($Skipped -join ', ')"
}
if ($Failed.Count -gt 0) {
    Write-Host "Failed: $($Failed -join ', ')" -ForegroundColor Red
}

Write-Host ""
Write-Host "OK Ready! Run 'claude' to start." -ForegroundColor Green
Write-Host ""
Write-Host "/calendar and /mail are Mac-only."
Write-Host "/messages needs Beeper Desktop (beeper.com/download/windows)"
Write-Host ""
