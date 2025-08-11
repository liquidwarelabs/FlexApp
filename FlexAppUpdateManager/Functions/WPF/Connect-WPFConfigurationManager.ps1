function Connect-WPFConfigurationManager {
    [CmdletBinding()]
    param()
    try {
        Write-LogMessage "Connecting to Configuration Manager..." -Level Info
        
        # Check if running as admin
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            throw "This application must be run as Administrator to connect to Configuration Manager."
        }
        
        # Get UI controls
        $serverTextBox = Find-Control "CMServerTextBox"
        $siteCodeTextBox = Find-Control "CMSiteCodeTextBox"
        $connectButton = Find-Control "CMConnectButton"
        $disconnectButton = Find-Control "CMDisconnectButton"
        $statusLabel = Find-Control "CMConnectionStatusLabel"
        $grid = Find-Control "CMApplicationsGrid"
        
        if (-not $serverTextBox -or -not $siteCodeTextBox -or -not $connectButton -or -not $disconnectButton -or -not $statusLabel -or -not $grid) {
            throw "Required UI controls not found"
        }
        
        # Get values from UI
        $server = $serverTextBox.Text.Trim()
        $siteCode = $siteCodeTextBox.Text.Trim()
        
        if ([string]::IsNullOrWhiteSpace($server) -or [string]::IsNullOrWhiteSpace($siteCode)) {
            throw "Server and Site Code are required"
        }
        
        # Update config and save settings
        $script:Config.CMSettings.SiteServer = $server
        $script:Config.CMSettings.SiteCode = $siteCode
        
        # Save settings to file
        Save-AllSettings -CMSiteServer $server -CMSiteCode $siteCode
        
        # Connect to CM
        Write-LogMessage "Connecting to Configuration Manager..." -Level Info -Tab "Configuration Manager"
        
        # Import CM module
        $cmModule = Get-Module -Name ConfigurationManager -ErrorAction SilentlyContinue
        if (-not $cmModule) {
            $cmModulePath = Join-Path $env:SMS_ADMIN_UI_PATH "..\ConfigurationManager.psd1"
            if (Test-Path $cmModulePath) {
                Write-LogMessage "Found Configuration Manager module at: $cmModulePath" -Level Info -Tab "Configuration Manager"
                Write-LogMessage "Importing Configuration Manager module..." -Level Info -Tab "Configuration Manager"
                Import-Module $cmModulePath -ErrorAction Stop
                Write-LogMessage "Configuration Manager module imported successfully" -Level Success -Tab "Configuration Manager"
            }
            else {
                throw "Configuration Manager module not found"
            }
        }
        
        # Test server connectivity
        if (-not [string]::IsNullOrWhiteSpace($server)) {
            Write-LogMessage "Testing connectivity to site server: $server" -Level Info -Tab "Configuration Manager"
            if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
                throw "Cannot connect to site server: $server"
            }
        }
        else {
            Write-LogMessage "Skipping connectivity test to site server: $server" -Level Info -Tab "Configuration Manager"
        }
        
        # Create CM drive
        Write-LogMessage "Creating new CM drive connection..." -Level Info -Tab "Configuration Manager"
        $driveName = $siteCode + ":"
        $existingDrive = Get-PSDrive -Name $siteCode -ErrorAction SilentlyContinue
        if ($existingDrive) {
            Write-LogMessage "Using existing CM drive: $siteCode (Root: $($existingDrive.Root))" -Level Info -Tab "Configuration Manager"
        }
        else {
            New-PSDrive -Name $siteCode -PSProvider CMSite -Root $server -Description "CM Site Connection" -ErrorAction Stop | Out-Null
            Write-LogMessage "CM drive created successfully" -Level Success -Tab "Configuration Manager"
        }
        
        # Change location to CM drive
        Write-LogMessage "Current location before CM connection: $((Get-Location).Path)" -Level Info -Tab "Configuration Manager"
        Set-Location $driveName -ErrorAction Stop
        Write-LogMessage "Changed location to: $((Get-Location).Path)" -Level Info -Tab "Configuration Manager"
        
        # Verify connection by getting site info
        Write-LogMessage "Verifying connection by retrieving site information..." -Level Info -Tab "Configuration Manager"
        $siteInfo = Get-CMSite -ErrorAction Stop
        Write-LogMessage "Connection verified. Site Name: $($siteInfo.SiteName), Version: $($siteInfo.Version)" -Level Success -Tab "Configuration Manager"
        
        # Get applications
        Write-LogMessage "Retrieving Configuration Manager applications..." -Level Info
        $applications = Get-CMApplication | Select-Object @{N='Selected';E={$false}}, @{N='Name';E={$_.LocalizedDisplayName}}, @{N='Version';E={$_.SoftwareVersion}}, @{N='Publisher';E={$_.Manufacturer}}, @{N='Status';E={$_.IsEnabled}}
        
        Write-LogMessage "Found $($applications.Count) applications" -Level Info
        
        # Update grid on UI thread
        $script:WPFMainWindow.Dispatcher.Invoke([Action]{
            # Create observable collection
            $collection = New-Object System.Collections.ObjectModel.ObservableCollection[object]
            foreach ($app in $applications) {
                $collection.Add($app)
            }
            
            # Update grid
            $grid.ItemsSource = $collection
            
            # Get export and process buttons
            $exportButton = Find-Control "CMExportButton"
            $processButton = Find-Control "CMProcessButton"
            
            # Update UI - enable all buttons when connected
            $connectButton.IsEnabled = $false
            $disconnectButton.IsEnabled = $true
            $statusLabel.Content = "Connected to $server ($siteCode) - $($applications.Count) applications loaded"
            $statusLabel.Foreground = "Green"
            
            # Enable export button when successfully connected
            if ($exportButton) { 
                $exportButton.IsEnabled = $true 
                Write-LogMessage "CM Export button enabled" -Level Info -Tab "Configuration Manager"
            }
            
            # Process button should only be enabled when applications are selected
            # It will be enabled by selection change events
            if ($processButton) { 
                $processButton.IsEnabled = $false  # Start disabled until selections are made
                Write-LogMessage "CM Process button will be enabled when applications are selected" -Level Info -Tab "Configuration Manager"
            }
        })
        
        Write-LogMessage "Successfully connected to Configuration Manager: $server ($siteCode)" -Level Success
    }
    catch {
        Write-LogMessage "Connection failed: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
        Write-LogMessage "Full error details: $($_.Exception)" -Level Error -Tab "Configuration Manager"
        
        # Ensure buttons are in correct state on connection failure
        try {
            $script:WPFMainWindow.Dispatcher.Invoke([Action]{
                $connectButton = Find-Control "CMConnectButton"
                $disconnectButton = Find-Control "CMDisconnectButton"
                $exportButton = Find-Control "CMExportButton"
                $processButton = Find-Control "CMProcessButton"
                $statusLabel = Find-Control "CMConnectionStatusLabel"
                
                if ($connectButton) { $connectButton.IsEnabled = $true }
                if ($disconnectButton) { $disconnectButton.IsEnabled = $false }
                if ($exportButton) { $exportButton.IsEnabled = $false }
                if ($processButton) { $processButton.IsEnabled = $false }
                if ($statusLabel) { 
                    $statusLabel.Content = "Connection Failed"
                    $statusLabel.Foreground = "Red"
                }
                
                Write-LogMessage "CM buttons reset to disconnected state due to connection failure" -Level Info -Tab "Configuration Manager"
            })
        }
        catch {
            Write-LogMessage "Could not reset button states after connection failure: $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
        }
        
        throw "Failed to connect to Configuration Manager"
    }
}