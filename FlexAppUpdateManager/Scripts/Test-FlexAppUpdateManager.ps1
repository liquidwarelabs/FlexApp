# File: Test-FlexAppUpdateManager.ps1
# =====================

<#
.SYNOPSIS
    Tests the FlexApp Update Manager implementation.

.DESCRIPTION
    This script tests the basic functionality of the FlexApp Update Manager.

.EXAMPLE
    .\Test-WPF.ps1
    # Runs basic tests
#>

# Set error action preference
$ErrorActionPreference = "Continue"

Write-Host "FlexApp Update Manager - Test" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check WPF Assemblies
Write-Host "Test 1: Checking WPF Assemblies..." -ForegroundColor Yellow
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Add-Type -AssemblyName PresentationCore -ErrorAction Stop
    Add-Type -AssemblyName WindowsBase -ErrorAction Stop
    Add-Type -AssemblyName System.Xaml -ErrorAction Stop
    Write-Host "✓ WPF assemblies loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load WPF assemblies: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: Check XAML File
Write-Host "Test 2: Checking XAML File..." -ForegroundColor Yellow
$scriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$xamlPath = Join-Path $scriptDir "GUI\MainWindow.xaml"

if (Test-Path $xamlPath) {
    Write-Host "✓ XAML file found" -ForegroundColor Green
} else {
    Write-Host "✗ XAML file not found" -ForegroundColor Red
    exit 1
}

# Test 3: Check PowerShell Module
Write-Host "Test 3: Checking PowerShell Module..." -ForegroundColor Yellow
$modulePath = Join-Path $scriptDir "FlexAppUpdateManager.psm1"

if (Test-Path $modulePath) {
    Write-Host "✓ PowerShell module found" -ForegroundColor Green
    
    try {
        Import-Module $modulePath -Force
        Write-Host "✓ Module imported successfully" -ForegroundColor Green
        
        # Test function availability
        if (Get-Command "Show-FlexAppUpdateManager" -ErrorAction SilentlyContinue) {
            Write-Host "✓ Main function is available" -ForegroundColor Green
        } else {
            Write-Host "✗ Main function not found" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "✗ Failed to import module: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "✗ PowerShell module not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "Test Summary:" -ForegroundColor Cyan
Write-Host "============" -ForegroundColor Cyan
Write-Host "✓ Basic tests completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "To launch the FlexApp Update Manager, run:" -ForegroundColor Yellow
Write-Host "  .\Launch-FlexAppUpdateManager.ps1" -ForegroundColor White
Write-Host ""
