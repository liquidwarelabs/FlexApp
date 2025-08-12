function Disconnect-WPFProfileUnityServer {
    [CmdletBinding()]
    param()
    try {
        Write-LogMessage "Disconnecting from ProfileUnity server..." -Level Info
        
        # Get UI controls
        $connectButton = Find-Control "PUConnectButton"
        $disconnectButton = Find-Control "PUDisconnectButton"
        $configComboBox = Find-Control "PUConfigComboBox"
        $loadButton = Find-Control "PULoadConfigsButton"
        $scanButton = Find-Control "PUScanButton"
        $statusLabel = Find-Control "PUStatusLabel"
        
        if (-not $connectButton -or -not $disconnectButton -or -not $configComboBox -or -not $loadButton -or -not $scanButton -or -not $statusLabel) {
            throw "Required UI controls not found"
        }
        
        # Clear session
        $script:ChocoSession = $null
        
        # Update UI
        $connectButton.IsEnabled = $true
        $disconnectButton.IsEnabled = $false
        $configComboBox.Items.Clear()
        $configComboBox.IsEnabled = $false
        $loadButton.IsEnabled = $false
        $scanButton.IsEnabled = $false
        $statusLabel.Content = "Disconnected"
        
        Write-LogMessage "Successfully disconnected from ProfileUnity server" -Level Success
    }
    catch {
        Write-LogMessage "Failed to disconnect: $($_.Exception.Message)" -Level Error
        throw
    }
}
