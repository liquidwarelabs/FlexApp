function Test-WPFGlobalSettings {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Testing WPF global settings..." -Level Info
        
        # Get UI controls to read current values
        $serverTextBox = Find-Control "SettingsServerTextBox"
        $serverPortTextBox = Find-Control "SettingsServerPortTextBox"
        $flexAppClientTextBox = Find-Control "SettingsFlexAppClientTextBox"
        $passwordFileTextBox = Find-Control "SettingsPasswordFileTextBox"
        $aesKeyFileTextBox = Find-Control "SettingsAESKeyFileTextBox"
        $tempPathTextBox = Find-Control "SettingsTempPathTextBox"
        
        if (-not $script:Config) {
            Load-AllSettings
        }
        
        # Test ProfileUnity Server connection
        $serverName = if ($serverTextBox) { $serverTextBox.Text.Trim() } else { $script:Config.ServerName }
        $serverPort = if ($serverPortTextBox) { $serverPortTextBox.Text.Trim() } else { $script:Config.ServerPort }
        
        if ([string]::IsNullOrWhiteSpace($serverName)) {
            throw "ProfileUnity Server is not configured"
        }
        
        Write-LogMessage "Testing connection to ProfileUnity Server: $serverName`:$serverPort" -Level Info
        
        # Test if files exist
        $missingFiles = @()
        $flexAppClient = if ($flexAppClientTextBox) { $flexAppClientTextBox.Text.Trim() } else { $script:Config.FlexAppClient }
        $passwordFile = if ($passwordFileTextBox) { $passwordFileTextBox.Text.Trim() } else { $script:Config.PasswordFile }
        $aesKeyFile = if ($aesKeyFileTextBox) { $aesKeyFileTextBox.Text.Trim() } else { $script:Config.AESKeyFile }
        $tempPath = if ($tempPathTextBox) { $tempPathTextBox.Text.Trim() } else { $script:Config.TempPath }
        
        if (-not [string]::IsNullOrWhiteSpace($flexAppClient) -and -not (Test-Path $flexAppClient)) {
            $missingFiles += "FlexApp Client: $flexAppClient"
        }
        if (-not [string]::IsNullOrWhiteSpace($passwordFile) -and -not (Test-Path $passwordFile)) {
            $missingFiles += "Password File: $passwordFile"
        }
        if (-not [string]::IsNullOrWhiteSpace($aesKeyFile) -and -not (Test-Path $aesKeyFile)) {
            $missingFiles += "AES Key File: $aesKeyFile"
        }
        if (-not [string]::IsNullOrWhiteSpace($tempPath) -and -not (Test-Path $tempPath)) {
            $missingFiles += "Temp Path: $tempPath"
        }
        
        if ($missingFiles.Count -gt 0) {
            $message = "Missing files/paths:`n" + ($missingFiles -join "`n")
            Write-LogMessage $message -Level Warning
            
            # Show message box in WPF
            try {
                [System.Windows.MessageBox]::Show($message, "Missing Files", "OK", "Warning")
            }
            catch {
                Write-LogMessage "Could not show message box: $($_.Exception.Message)" -Level Warning
            }
        } else {
            Write-LogMessage "All file paths are valid" -Level Success
        }
        
        # Test ProfileUnity connection
        try {
            Initialize-SSLPolicy
            
            # Use Connect-ProfileUnityServer if available, otherwise basic connection test
            if (Get-Command "Connect-ProfileUnityServer" -ErrorAction SilentlyContinue) {
                Connect-ProfileUnityServer
                Write-LogMessage "ProfileUnity Server connection test completed" -Level Success
            } else {
                # Basic connectivity test
                $testUri = "https://$($serverName):$($serverPort)"
                Write-LogMessage "Testing basic connectivity to: $testUri" -Level Info
                
                try {
                    $response = Invoke-WebRequest -Uri $testUri -TimeoutSec 10 -ErrorAction Stop
                    Write-LogMessage "Server is reachable" -Level Success
                }
                catch {
                    Write-LogMessage "Server connection failed: $($_.Exception.Message)" -Level Warning
                }
            }
        }
        catch {
            Write-LogMessage "Connection test failed: $($_.Exception.Message)" -Level Warning
        }
        
        # Show success message
        try {
            [System.Windows.MessageBox]::Show("Settings test completed. Check the console output for details.", "Settings Test", "OK", "Information")
        }
        catch {
            Write-LogMessage "Settings test completed successfully" -Level Success
        }
    }
    catch {
        $errorMessage = "Failed to test global settings: $($_.Exception.Message)"
        Write-LogMessage $errorMessage -Level Error
        
        try {
            [System.Windows.MessageBox]::Show($errorMessage, "Settings Test Failed", "OK", "Error")
        }
        catch {
            Write-LogMessage "Could not show error message box" -Level Warning
        }
    }
}
