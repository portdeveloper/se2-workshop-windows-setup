#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Bootstraps Windows for the Scaffold-ETH 2 workshop by installing WSL2 + Ubuntu.

.DESCRIPTION
  Run from an elevated PowerShell. After the script completes, reboot and continue
  with Step 2 (wsl-bootstrap.sh inside Ubuntu) from the README.
#>

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "==> Scaffold-ETH 2 Workshop: Windows bootstrap" -ForegroundColor Cyan
Write-Host ""

# --- Check Windows version ---
$build = [int][System.Environment]::OSVersion.Version.Build
if ($build -lt 19041) {
    Write-Host "ERROR: Windows 10 build 19041 (version 2004) or newer is required." -ForegroundColor Red
    Write-Host "Your build: $build"
    exit 1
}

# --- Check virtualization ---
$cpu = Get-CimInstance Win32_Processor
if (-not $cpu.VirtualizationFirmwareEnabled) {
    Write-Host "WARNING: hardware virtualization appears disabled in BIOS." -ForegroundColor Yellow
    Write-Host "WSL2 needs Intel VT-x or AMD-V. Enable it in BIOS/UEFI if installation fails."
    Write-Host ""
}

# --- Install WSL2 + Ubuntu ---
$wslOk = $false
try {
    $null = wsl --status 2>$null
    if ($LASTEXITCODE -eq 0) { $wslOk = $true }
} catch {
    $wslOk = $false
}

# wsl --list --quiet emits UTF-16 LE; strip stray null bytes before matching
# so the test works on every Windows build.
function Test-UbuntuInstalled {
    try {
        $list = (wsl --list --quiet 2>$null | Out-String) -replace "`0", ""
        return ($list -match "(?im)^Ubuntu")
    } catch {
        return $false
    }
}

$ubuntuInstalled = Test-UbuntuInstalled

if ($ubuntuInstalled) {
    Write-Host "Ubuntu is already registered under WSL. Skipping install." -ForegroundColor Yellow
} elseif ($wslOk) {
    Write-Host "WSL is already present. Installing Ubuntu..." -ForegroundColor Yellow
    wsl --install -d Ubuntu --no-launch
} else {
    Write-Host "Installing WSL2 + Ubuntu (this can take several minutes)..." -ForegroundColor Green
    wsl --install -d Ubuntu
}

# The "distribution already exists" path of wsl --install returns non-zero on
# some Windows builds. If the distro is registered after we tried, the end
# state is what we wanted regardless of exit code — don't bail.
if ($LASTEXITCODE -ne 0 -and -not $ubuntuInstalled) {
    if (Test-UbuntuInstalled) {
        Write-Host "Ubuntu is already registered — treating non-zero exit as a no-op." -ForegroundColor Yellow
        $global:LASTEXITCODE = 0
    } else {
        Write-Host ""
        Write-Host "ERROR: wsl --install failed (exit code $LASTEXITCODE)." -ForegroundColor Red
        Write-Host "Try running 'wsl --install -d Ubuntu' manually, or see"
        Write-Host "https://learn.microsoft.com/windows/wsl/install for troubleshooting."
        Write-Host ""
        Read-Host -Prompt "Press Enter to close this window" | Out-Null
        exit $LASTEXITCODE
    }
}

# --- Make sure WSL2 is the default ---
wsl --set-default-version 2 2>$null | Out-Null

Write-Host ""
Write-Host "==> Done." -ForegroundColor Green
Write-Host ""
Write-Host "Reboot your machine, then head back to https://setup.devnads.com to continue." -ForegroundColor Cyan
Write-Host ""
