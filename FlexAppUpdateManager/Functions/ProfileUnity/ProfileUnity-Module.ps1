# File: Functions\ProfileUnity\ProfileUnity-Module.ps1
# ================================
# Main module file that loads all ProfileUnity components

# Load all ProfileUnity function files in the correct order

# 1. Global variables and initialization
. "$PSScriptRoot\ProfileUnity-Globals.ps1"

# 2. Connection and authentication
. "$PSScriptRoot\ProfileUnity-Connection.ps1"

# 3. Configuration management functions
. "$PSScriptRoot\Get-ProfileUnityConfigurations.ps1"
. "$PSScriptRoot\Get-ProfileUnityConfiguration.ps1"
. "$PSScriptRoot\Get-ProfileUnityFilters.ps1"
. "$PSScriptRoot\Get-ProfileUnityFilterNameById.ps1"

# 4. Filter management (WPF versions used instead)
# Old WinForms functions removed - using WPF versions in Functions/WPF/

# Initialize globals when module loads
Initialize-ProfileUnityGlobals

Write-LogMessage "ProfileUnity module loaded successfully" -Level Success -Tab "ProfileUnity"