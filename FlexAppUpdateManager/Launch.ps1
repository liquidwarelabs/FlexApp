# File: Launch.ps1
# ===============
# Simple launcher for FlexApp Update Manager
# This script provides easy access to the module from the root directory

<#
.SYNOPSIS
    Launches the FlexApp Update Manager.

.DESCRIPTION
    This script launches the FlexApp Update Manager using the modern WPF interface.
    It's a simple wrapper that calls the main launcher script.

.EXAMPLE
    .\Launch.ps1
    # Launches the FlexApp Update Manager
#>

# Get the script directory (root of the module)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcherPath = Join-Path $scriptDir "Scripts\Launch-FlexAppUpdateManager.ps1"

Write-Host "FlexApp Update Manager" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host ""

if (Test-Path $launcherPath) {
    Write-Host "Launching FlexApp Update Manager..." -ForegroundColor Yellow
    & $launcherPath @PSBoundParameters
} else {
    Write-Error "Launcher script not found at: $launcherPath"
    Write-Host ""
    Write-Host "Alternative usage:" -ForegroundColor Yellow
    Write-Host "  Import-Module '.\FlexAppUpdateManager.psm1'" -ForegroundColor White
    Write-Host "  Show-FlexAppUpdateManager" -ForegroundColor White
    exit 1
}
