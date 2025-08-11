# File: Functions\ProfileUnity\ProfileUnity-Module.ps1
# ================================
# Main module file that loads all ProfileUnity components

# Load all ProfileUnity function files in the correct order

# 1. Global variables and initialization
. "$PSScriptRoot\ProfileUnity-Globals.ps1"

# 2. Connection and authentication
. "$PSScriptRoot\ProfileUnity-Connection.ps1"

# 3. Configuration management
. "$PSScriptRoot\ProfileUnity-ConfigLoader.ps1"
. "$PSScriptRoot\ProfileUnity-ConfigScanner.ps1"
. "$PSScriptRoot\ProfileUnity-ConfigUpdater.ps1"

# 4. Filter management
. "$PSScriptRoot\ProfileUnity-FilterManager.ps1"
. "$PSScriptRoot\ProfileUnity-FilterDialog.ps1"

# Initialize globals when module loads
Initialize-ProfileUnityGlobals

Write-LogMessage "ProfileUnity module loaded successfully" -Level Success -Tab "ProfileUnity"