# File: FlexAppUpdateManager.psm1
# ================================
# Main module file for FlexApp Update Manager v1.2.3
# Imports all functions and initializes the module

#Requires -Version 5.1

# Module script-level variables
$script:ModuleRoot = $PSScriptRoot
$script:ModuleVersion = "1.5.0"

# Import configuration files first
Write-Verbose "Loading configuration files..."
$configFiles = @(
    "$PSScriptRoot\Config\Configuration.ps1",
    "$PSScriptRoot\Config\Initialize-Module.ps1",
    "$PSScriptRoot\Config\Settings-Persistence.ps1",
    "$PSScriptRoot\Config\Process-Management.ps1"
)

foreach ($configFile in $configFiles) {
    if (Test-Path $configFile) {
        Write-Verbose "Loading config: $configFile"
        . $configFile
    } else {
        Write-Warning "Config file not found: $configFile"
    }
}

# Import function files in specific order
Write-Verbose "Loading function files..."

# 1. Shared functions first (they're used by other functions)
$sharedFiles = Get-ChildItem -Path "$PSScriptRoot\Functions\Shared" -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $sharedFiles) {
    Write-Verbose "Loading shared function: $($file.Name)"
    . $file.FullName
}

# 2. Load ProfileUnity functions (used by multiple tabs)
$profileUnityFiles = Get-ChildItem -Path "$PSScriptRoot\Functions\ProfileUnity" -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $profileUnityFiles) {
    Write-Verbose "Loading ProfileUnity function: $($file.Name)"
    . $file.FullName
}

# 3. Load Chocolatey functions
$chocoFiles = Get-ChildItem -Path "$PSScriptRoot\Functions\Chocolatey" -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $chocoFiles) {
    Write-Verbose "Loading Chocolatey function: $($file.Name)"
    . $file.FullName
}

# 4. Load Winget functions
$wingetFiles = Get-ChildItem -Path "$PSScriptRoot\Functions\Winget" -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $wingetFiles) {
    Write-Verbose "Loading Winget function: $($file.Name)"
    . $file.FullName
}

# 5. Load Configuration Manager functions
$cmFiles = Get-ChildItem -Path "$PSScriptRoot\Functions\ConfigurationManager" -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $cmFiles) {
    Write-Verbose "Loading Configuration Manager function: $($file.Name)"
    . $file.FullName
}

# 6. Load Intune functions
$intuneFiles = Get-ChildItem -Path "$PSScriptRoot\Functions\Intune" -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $intuneFiles) {
    Write-Verbose "Loading Intune function: $($file.Name)"
    . $file.FullName
}

# 7. Load WPF functions (they depend on other functions)
$wpfFiles = Get-ChildItem -Path "$PSScriptRoot\Functions\WPF" -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $wpfFiles) {
    Write-Verbose "Loading WPF function: $($file.Name)"
    . $file.FullName
}

# 8. Load GUI files (main Show-FlexAppUpdateManager function)
$guiFiles = Get-ChildItem -Path "$PSScriptRoot\GUI" -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $guiFiles) {
    Write-Verbose "Loading GUI file: $($file.Name)"
    . $file.FullName
}

# Initialize module after all functions are loaded
Write-Verbose "Initializing FlexApp Update Manager module..."
Initialize-FlexAppModule

# Export main functions and WPF event handlers
Export-ModuleMember -Function @(
    'Show-FlexAppUpdateManager',
    'Write-LogMessage',
    'Initialize-SSLPolicy',
    'Get-SecureCredentials',
    'Set-WPFProfileUnityEventHandlers',
    'Set-WPFCMEventHandlers',
    'Set-WPFWingetEventHandlers',
    'Set-WPFChocoEventHandlers',
    'Update-WPFProfileUnityButtonStates',
    'Update-WPFCMButtonStates',
    'Update-WPFWingetButtonStates',
    'Update-WPFChocoButtonStates',
    'Start-WPFProfileUnityCommit',
    'Start-WPFProfileUnityScan',
    'Start-WPFProfileUnitySave',
    'Import-WPFProfileUnityConfigurations',
    'Connect-WPFProfileUnityServer',
    'Disconnect-WPFProfileUnityServer',
    'Show-WPFPreviewDialog',
    'Save-WPFGlobalSettings',
    'Find-Control',
    'Get-ProfileUnityConfiguration',
    'Get-ProfileUnityConfigurations',
    'Get-ProfileUnityFlexApps',
    'Connect-ProfileUnityServer',
    'Test-ProfileUnityConnection',
    'Initialize-ProfileUnityGlobals',
    'Get-ProfileUnityFilters',
    'Get-ProfileUnityFilterNameById',
    'Start-ChocoJobMonitoring',
    'Start-WingetJobMonitoring',
    'Complete-ChocoJobMonitoring',
    'Complete-WingetJobMonitoring',
    'Start-WPFPackageUpdate',
    'Update-WPFChocoStatus',
    'Update-WPFWingetStatus',
    'Start-IntuneUpload',
    'Connect-IntuneGraph',
    'Organize-FlexAppPackages',
    'New-IntunePackage',
    'Add-IntuneApplicationMSEndpointMgr',
    'Start-WPFIntuneUpload',
    'Stop-WPFIntuneUpload',
    'Test-WPFIntuneConnection',
    'Save-WPFIntuneSettings',
    'Load-WPFIntuneSettings',
    'Test-IntuneSettingsLoad',
    'Test-IntuneUIControls',
    'ConvertTo-EncryptedString',
    'ConvertFrom-EncryptedString'
)

# Module initialization message
Write-Host @"

FlexApp Update Manager Module v$script:ModuleVersion Loaded
========================================================
Main Features:
- Chocolatey package updates
- Winget package updates  
- Configuration Manager integration
- ProfileUnity configuration management
- Microsoft Intune package upload
- Centralized settings management

To start the GUI, run: Show-FlexAppUpdateManager

For verbose loading information, use:
Import-Module FlexAppUpdateManager -Verbose

"@ -ForegroundColor Cyan

# Optional: Auto-start the UI after module import (comment out if not desired)
# Show-FlexAppUpdateManager