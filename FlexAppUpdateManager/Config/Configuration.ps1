# File: Config\Configuration.ps1
# ================================
# Configuration with compatibility for existing code

# Configuration will be loaded from file or created with defaults
$script:Config = $null

# Global variables (keeping existing structure for compatibility)
$script:MainForm = $null
$script:TabControl = $null

# Chocolatey tab variables
$script:ChocoUpdateCandidates = @()
$script:ChocoSession = $null
$script:ChocoBackgroundJob = $null
$script:ChocoJobTimer = $null
$script:ChocoCancelInProgress = $false
$script:ChocoScanCancelled = $false

# Winget tab variables
$script:WingetUpdateCandidates = @()  # Initialize as empty array
$script:WingetBackgroundJob = $null
$script:WingetJobTimer = $null
$script:WingetCancelInProgress = $false

# Configuration Manager tab variables
$global:CMConnected = $false
$global:CMAppList = @()
$global:CMProcessedApps = @()
$global:CMCheckedItems = @{}
$script:CMBackgroundJob = $null

# Disable progress bars for performance
$ProgressPreference = 'SilentlyContinue'

# Load additional configuration modules
. "$PSScriptRoot\Initialize-Module.ps1"
. "$PSScriptRoot\Settings-Persistence.ps1"
. "$PSScriptRoot\Settings-Management.ps1"
. "$PSScriptRoot\Process-Management.ps1"