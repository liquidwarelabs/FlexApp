# File: WPF\Functions\Connect-WPFProfileUnityServer.ps1
# ================================

function Connect-WPFProfileUnityServer {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Connecting to ProfileUnity server..." -Level Info
        
        # Get server settings from Settings tab
        $serverTextBox = $script:WPFMainWindow.FindName("SettingsServerTextBox")
        $adminUserTextBox = $script:WPFMainWindow.FindName("SettingsAdminUserTextBox")
        $passwordFileTextBox = $script:WPFMainWindow.FindName("SettingsPasswordFileTextBox")
        $aesKeyFileTextBox = $script:WPFMainWindow.FindName("SettingsAESKeyFileTextBox")
        
        if (-not $serverTextBox -or -not $adminUserTextBox -or -not $passwordFileTextBox -or -not $aesKeyFileTextBox) {
            throw "Could not find required settings controls"
        }
        
        $server = $serverTextBox.Text
        $adminUser = $adminUserTextBox.Text
        $passwordFile = $passwordFileTextBox.Text
        $aesKeyFile = $aesKeyFileTextBox.Text
        
        # Validate settings
        if ([string]::IsNullOrWhiteSpace($server)) {
            throw "Server name not configured. Please configure the Server Name in the Settings tab."
        }
        if ([string]::IsNullOrWhiteSpace($adminUser)) {
            throw "Admin user not configured. Please configure the Admin User in the Settings tab."
        }
        if ([string]::IsNullOrWhiteSpace($passwordFile) -or -not (Test-Path $passwordFile)) {
            throw "Password file not found or not configured: $passwordFile`n`nPlease configure the Password File in the Settings tab."
        }
        if ([string]::IsNullOrWhiteSpace($aesKeyFile) -or -not (Test-Path $aesKeyFile)) {
            throw "AES key file not found or not configured: $aesKeyFile`n`nPlease configure the AES Key File in the Settings tab."
        }
        
        # Get connection controls
        $connectButton = $script:WPFMainWindow.FindName("PUConnectButton")
        $disconnectButton = $script:WPFMainWindow.FindName("PUDisconnectButton")
        $configComboBox = $script:WPFMainWindow.FindName("PUConfigComboBox")
        $loadConfigsButton = $script:WPFMainWindow.FindName("PULoadConfigsButton")
        $scanButton = $script:WPFMainWindow.FindName("PUScanButton")
        $statusLabel = $script:WPFMainWindow.FindName("PUStatusLabel")
        
        if (-not $connectButton -or -not $disconnectButton -or -not $configComboBox -or -not $loadConfigsButton -or -not $scanButton -or -not $statusLabel) {
            throw "Could not find required connection controls"
        }
        
        # Disable buttons during connection
        $script:WPFMainWindow.Dispatcher.Invoke([Action]{
            $connectButton.IsEnabled = $false
            $disconnectButton.IsEnabled = $false
            $loadConfigsButton.IsEnabled = $false
            $scanButton.IsEnabled = $false
            $statusLabel.Content = "Connecting to ProfileUnity server..."
        })
        
        # Get password and AES key
        $password = Get-Content $passwordFile -Raw
        $aesKey = Get-Content $aesKeyFile -Raw
        
        # Update config with connection settings
        $script:Config.ServerName = $server
        $script:Config.AdminUser = $adminUser
        
        # Connect to server
        $result = Connect-ProfileUnityServer
        
        if ($result) {
            $script:WPFMainWindow.Dispatcher.Invoke([Action]{
                $connectButton.IsEnabled = $false
                $disconnectButton.IsEnabled = $true
                $loadConfigsButton.IsEnabled = $true
                $scanButton.IsEnabled = $false
                $statusLabel.Content = "Connected to $server"
            })
            
            Write-LogMessage "Successfully connected to ProfileUnity server: $server" -Level Success
            
            [System.Windows.MessageBox]::Show(
                "Successfully connected to ProfileUnity server: $server", 
                "Connection Success", 
                [System.Windows.MessageBoxButton]::OK, 
                [System.Windows.MessageBoxImage]::Information
            )
            
            return $true
        }
        else {
            throw "Failed to connect to ProfileUnity server"
        }
    }
    catch {
        Write-LogMessage "Connection failed: $($_.Exception.Message)" -Level Error
        
        try {
            $script:WPFMainWindow.Dispatcher.Invoke([Action]{
                $connectButton = $script:WPFMainWindow.FindName("PUConnectButton")
                $disconnectButton = $script:WPFMainWindow.FindName("PUDisconnectButton")
                $loadConfigsButton = $script:WPFMainWindow.FindName("PULoadConfigsButton")
                $scanButton = $script:WPFMainWindow.FindName("PUScanButton")
                $statusLabel = $script:WPFMainWindow.FindName("PUStatusLabel")
                
                if ($connectButton) { $connectButton.IsEnabled = $true }
                if ($disconnectButton) { $disconnectButton.IsEnabled = $false }
                if ($loadConfigsButton) { $loadConfigsButton.IsEnabled = $false }
                if ($scanButton) { $scanButton.IsEnabled = $false }
                if ($statusLabel) { $statusLabel.Content = "Connection failed: $($_.Exception.Message)" }
            })
        }
        catch { }
        
        [System.Windows.MessageBox]::Show(
            "Connection failed: $($_.Exception.Message)", 
            "Connection Error", 
            [System.Windows.MessageBoxButton]::OK, 
            [System.Windows.MessageBoxImage]::Error
        )
        
        return $false
    }
}