function Disconnect-WPFConfigurationManager {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Disconnecting from Configuration Manager..." -Level Info -Tab "Configuration Manager"
        
        # Get UI controls
        $connectButton = Find-Control "CMConnectButton"
        $disconnectButton = Find-Control "CMDisconnectButton"
        $statusLabel = Find-Control "CMConnectionStatusLabel"
        $grid = Find-Control "CMApplicationsGrid"
        # $exportButton = Find-Control "CMExportButton"  # Moved to Package Update Edit screen
        $processButton = Find-Control "CMProcessButton"
        $siteCodeTextBox = Find-Control "CMSiteCodeTextBox"
        
        if (-not $connectButton -or -not $disconnectButton -or -not $statusLabel -or -not $grid) {
            throw "Required UI controls not found"
        }
        
        # Get current site code
        $siteCode = $siteCodeTextBox.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($siteCode)) {
            Write-LogMessage "No site code found, skipping PSDrive removal" -Level Warning -Tab "Configuration Manager"
        } else {
            # Remove PSDrive if it exists
            $existingDrive = Get-PSDrive -Name $siteCode -PSProvider CMSite -ErrorAction SilentlyContinue
            if ($existingDrive) {
                Write-LogMessage "Removing CM PSDrive: $siteCode" -Level Info -Tab "Configuration Manager"
                Remove-PSDrive -Name $siteCode -Force -ErrorAction SilentlyContinue
                Write-LogMessage "CM PSDrive removed successfully" -Level Success -Tab "Configuration Manager"
            } else {
                Write-LogMessage "CM PSDrive not found: $siteCode" -Level Info -Tab "Configuration Manager"
            }
        }
        
        # Change location back to system drive
        try {
            Set-Location $env:SystemDrive
            Write-LogMessage "Changed location back to: $((Get-Location).Path)" -Level Info -Tab "Configuration Manager"
        }
        catch {
            Write-LogMessage "Could not change location back to system drive: $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
        }
        
        # Update UI on dispatcher thread
        $script:WPFMainWindow.Dispatcher.Invoke([Action]{
            # Update button states
            $connectButton.IsEnabled = $true
            $disconnectButton.IsEnabled = $false
            
            # Update status
            $statusLabel.Content = "Not Connected"
            $statusLabel.Foreground = "Red"
            
            # Clear grid
            $grid.ItemsSource = $null
            
            # Disable action buttons
            # $exportButton.IsEnabled = $false  # Moved to Package Update Edit screen
            $processButton.IsEnabled = $false
        })
        
        Write-LogMessage "Successfully disconnected from Configuration Manager" -Level Success -Tab "Configuration Manager"
    }
    catch {
        Write-LogMessage "Error disconnecting from Configuration Manager: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
        [System.Windows.MessageBox]::Show("Error disconnecting: $($_.Exception.Message)", "Disconnect Error", "OK", "Error") | Out-Null
    }
}







