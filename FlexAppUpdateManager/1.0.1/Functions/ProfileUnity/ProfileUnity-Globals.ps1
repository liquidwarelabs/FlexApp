# File: Functions\ProfileUnity\ProfileUnity-Globals.ps1
# ================================
# Global variables for ProfileUnity configuration management

# Configuration data
$script:PUConfigurations = @()          # All configurations from server
$script:PUCurrentConfig = $null         # Currently loaded configuration
$script:PUUpdateCandidates = @()        # FlexApps with updates available
$script:PUFlexAppInventory = @()        # All FlexApps from inventory
$script:PUAvailableFilters = @()        # All filters from server
$script:PUConfigModified = $false       # Track if configuration has been modified

# Initialize function to ensure all globals are set
function Initialize-ProfileUnityGlobals {
    [CmdletBinding()]
    param()
    
    if ($null -eq $script:PUConfigurations) {
        $script:PUConfigurations = @()
    }
    if ($null -eq $script:PUUpdateCandidates) {
        $script:PUUpdateCandidates = @()
    }
    if ($null -eq $script:PUFlexAppInventory) {
        $script:PUFlexAppInventory = @()
    }
    if ($null -eq $script:PUAvailableFilters) {
        $script:PUAvailableFilters = @()
    }
    
    Write-LogMessage "ProfileUnity globals initialized" -Level Info -Tab "ProfileUnity"
}