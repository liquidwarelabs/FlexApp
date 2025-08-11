# File: Launch-FlexAppUpdateManager.ps1
# ========================

<#
.SYNOPSIS
    Launches the FlexApp Update Manager.

.DESCRIPTION
    This script launches the FlexApp Update Manager using the modern WPF interface.
    It includes error handling and WPF availability checking.

.PARAMETER ForceWPF
    Forces the use of WPF interface (will fail if WPF is not available).

.EXAMPLE
    .\Launch-FlexAppUpdateManager.ps1
    # Launches the WPF interface

.EXAMPLE
    .\Launch-FlexAppUpdateManager.ps1 -ForceWPF
    # Forces WPF interface
#>

param(
    [switch]$ForceWPF
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Get the script directory
$scriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$modulePath = Join-Path $scriptDir "FlexAppUpdateManager.psm1"

Write-Host "FlexApp Update Manager - Launcher" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Check if the main module exists
if (-not (Test-Path $modulePath)) {
    Write-Error "Main module not found at: $modulePath"
    exit 1
}

try {
    # Import the main module
    Write-Host "Importing main module..." -ForegroundColor Yellow
    Import-Module $modulePath -Force
    
    Write-Host "Module imported successfully." -ForegroundColor Green
    
    # Test WPF availability
    if (Test-WPFAvailable) {
        Write-Host "WPF is available on this system." -ForegroundColor Green
    } else {
        Write-Host "WPF is not available on this system." -ForegroundColor Yellow
    }
    
    Write-Host ""
    
    # Launch the interface
    if ($ForceWPF) {
        Write-Host "Launching WPF interface (forced)..." -ForegroundColor Yellow
        Show-FlexAppUpdateManager
    } else {
        Write-Host "Launching FlexApp Update Manager..." -ForegroundColor Yellow
        Show-FlexAppUpdateManager
    }
    
} catch {
    Write-Error "Failed to launch FlexApp Update Manager: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "1. Ensure PowerShell is running as Administrator" -ForegroundColor White
    Write-Host "2. Check that .NET Framework is installed" -ForegroundColor White
    Write-Host "3. Verify the main FlexAppUpdateManager module is available" -ForegroundColor White
    Write-Host "4. Check that WPF assemblies are available" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "Application closed." -ForegroundColor Green
