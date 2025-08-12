# File: Functions\ConfigurationManager\Connect-ConfigurationManager.ps1
# ================================

function Connect-ConfigurationManager {
    param(
        [string]$SiteServer,
        [string]$SiteCode
    )
    
    try {
        Write-LogMessage "Connecting to Configuration Manager..." -Level Info -Tab "Configuration Manager"
        
        # Check if running as administrator
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This application must be run as Administrator to connect to Configuration Manager."
        }
        
        # Try multiple possible CM console paths
        $CMPaths = @(
            "${env:ProgramFiles(x86)}\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1",
            "${env:ProgramFiles}\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1",
            "${env:ProgramFiles(x86)}\Microsoft Endpoint Manager\AdminConsole\bin\ConfigurationManager.psd1",
            "${env:ProgramFiles}\Microsoft Endpoint Manager\AdminConsole\bin\ConfigurationManager.psd1"
        )
        
        $CMPath = $null
        foreach ($path in $CMPaths) {
            if (Test-Path $path) {
                $CMPath = $path
                Write-LogMessage "Found Configuration Manager module at: $CMPath" -Level Info -Tab "Configuration Manager"
                break
            }
        }
        
        if (-not $CMPath) {
            throw "Configuration Manager console not found. Please install the Configuration Manager console. Searched paths: $($CMPaths -join ', ')"
        }
        
        # Check if module is already loaded
        $existingModule = Get-Module ConfigurationManager -ErrorAction SilentlyContinue
        if ($existingModule) {
            Write-LogMessage "Configuration Manager module already loaded (Version: $($existingModule.Version))" -Level Info -Tab "Configuration Manager"
        } else {
            Write-LogMessage "Importing Configuration Manager module..." -Level Info -Tab "Configuration Manager"
            Import-Module $CMPath -ErrorAction Stop -Force
            Write-LogMessage "Configuration Manager module imported successfully" -Level Success -Tab "Configuration Manager"
        }
        
        # Skip connectivity test - removed ping check
        Write-LogMessage "Skipping connectivity test to site server: $SiteServer" -Level Info -Tab "Configuration Manager"
        
        # Check for existing drive
        $existingDrive = Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue
        if ($existingDrive) {
            Write-LogMessage "Using existing CM drive: $SiteCode (Root: $($existingDrive.Root))" -Level Info -Tab "Configuration Manager"
        } else {
            Write-LogMessage "Creating new CM drive connection..." -Level Info -Tab "Configuration Manager"
            New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer -ErrorAction Stop
            Write-LogMessage "CM drive created successfully" -Level Success -Tab "Configuration Manager"
        }
        
        # Set location and verify connection
        $currentLocation = Get-Location
        Write-LogMessage "Current location before CM connection: $currentLocation" -Level Info -Tab "Configuration Manager"
        
        Set-Location "$($SiteCode):\" -ErrorAction Stop
        $newLocation = Get-Location
        Write-LogMessage "Changed location to: $newLocation" -Level Info -Tab "Configuration Manager"
        
        # Test the connection by trying to get site information
        Write-LogMessage "Verifying connection by retrieving site information..." -Level Info -Tab "Configuration Manager"
        $siteInfo = Get-CMSite -SiteCode $SiteCode -ErrorAction Stop
        Write-LogMessage "Connection verified. Site Name: $($siteInfo.SiteName), Version: $($siteInfo.Version)" -Level Success -Tab "Configuration Manager"
        
        # Save the connection settings after successful connection
        Update-CMConnectionUI
        
        return $true
    }
    catch {
        $errorMessage = $_.Exception.Message
        $fullError = $_.Exception.ToString()
        
        Write-LogMessage "Failed to connect to Configuration Manager: $errorMessage" -Level Error -Tab "Configuration Manager"
        Write-LogMessage "Full error details: $fullError" -Level Error -Tab "Configuration Manager"
        
        # Try to return to original location
        try {
            Set-Location $env:SystemDrive
        }
        catch {
            Write-LogMessage "Could not return to system drive: $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
        }
        
        return $false
    }
}