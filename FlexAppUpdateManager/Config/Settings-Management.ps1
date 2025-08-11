# File: Config\Settings-Management.ps1
# ================================
# Settings management functions (UI interactions)

function Save-GlobalSettings {
    # Save global configuration settings
    try {
        # Check if MainForm is properly initialized
        if (-not $script:MainForm) {
            Write-LogMessage "MainForm not initialized, skipping save" -Level Warning -Tab "Settings"
            return
        }
        
        # Get all the settings controls
        $serverTextBox = $script:MainForm.Controls.Find('SettingsServerTextBox', $true)[0]
        $serverPortTextBox = $script:MainForm.Controls.Find('SettingsServerPortTextBox', $true)[0]
        $adminUserTextBox = $script:MainForm.Controls.Find('SettingsAdminUserTextBox', $true)[0]
        $flexAppClientTextBox = $script:MainForm.Controls.Find('SettingsFlexAppClientTextBox', $true)[0]
        $passwordFileTextBox = $script:MainForm.Controls.Find('SettingsPasswordFileTextBox', $true)[0]
        $aesKeyFileTextBox = $script:MainForm.Controls.Find('SettingsAESKeyFileTextBox', $true)[0]
        $tempPathTextBox = $script:MainForm.Controls.Find('SettingsTempPathTextBox', $true)[0]
        $processWaitTextBox = $script:MainForm.Controls.Find('SettingsProcessWaitTextBox', $true)[0]
        $defaultFileTextBox = $script:MainForm.Controls.Find('SettingsDefaultFileTextBox', $true)[0]
        $chocoServerTextBox = $script:MainForm.Controls.Find('SettingsPrimaryServerTextBox', $true)[0]
        
        # Update global config values only if controls exist and have values
        if ($serverTextBox -and ![string]::IsNullOrWhiteSpace($serverTextBox.Text)) { 
            $script:Config.ServerName = $serverTextBox.Text.Trim()
        }
        if ($serverPortTextBox -and ![string]::IsNullOrWhiteSpace($serverPortTextBox.Text)) { 
            $script:Config.ServerPort = $serverPortTextBox.Text.Trim()
        }
        if ($adminUserTextBox -and ![string]::IsNullOrWhiteSpace($adminUserTextBox.Text)) { 
            $script:Config.AdminUser = $adminUserTextBox.Text.Trim()
        }
        if ($flexAppClientTextBox -and ![string]::IsNullOrWhiteSpace($flexAppClientTextBox.Text)) { 
            $script:Config.FlexAppClient = $flexAppClientTextBox.Text.Trim()
        }
        if ($passwordFileTextBox -and ![string]::IsNullOrWhiteSpace($passwordFileTextBox.Text)) { 
            $script:Config.PasswordFile = $passwordFileTextBox.Text.Trim()
        }
        if ($aesKeyFileTextBox -and ![string]::IsNullOrWhiteSpace($aesKeyFileTextBox.Text)) { 
            $script:Config.AESKeyFile = $aesKeyFileTextBox.Text.Trim()
        }
        if ($tempPathTextBox -and ![string]::IsNullOrWhiteSpace($tempPathTextBox.Text)) { 
            $script:Config.TempPath = $tempPathTextBox.Text.Trim()
        }
        if ($processWaitTextBox -and ![string]::IsNullOrWhiteSpace($processWaitTextBox.Text)) { 
            $script:Config.ProcessWaitTime = $processWaitTextBox.Text.Trim()
        }
        if ($defaultFileTextBox -and ![string]::IsNullOrWhiteSpace($defaultFileTextBox.Text)) { 
            $script:Config.DefaultFile = $defaultFileTextBox.Text.Trim()
        }
        if ($chocoServerTextBox -and ![string]::IsNullOrWhiteSpace($chocoServerTextBox.Text)) { 
            $script:Config.PrimaryServer = $chocoServerTextBox.Text.Trim()
        }
        
        # Save to config file
        $configPath = "$env:APPDATA\FlexAppUpdateManager\config.json"
        
        # Ensure directory exists
        $configDir = Split-Path $configPath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        # Save config
        $script:Config | ConvertTo-Json -Depth 10 | Out-File $configPath -Encoding UTF8
        
        Write-LogMessage "Global settings saved successfully to: $configPath" -Level Success -Tab "Settings"
        
        # Debug logging - show what was saved
        Write-LogMessage "Saved values - Server: $($script:Config.ServerName), Port: $($script:Config.ServerPort), User: $($script:Config.AdminUser)" -Level Info -Tab "Settings"
        Write-LogMessage "Saved values - Default File: $($script:Config.DefaultFile), Primary Server: $($script:Config.PrimaryServer)" -Level Info -Tab "Settings"
        
    }
    catch {
        Write-LogMessage "Failed to save global settings: $($_.Exception.Message)" -Level Error -Tab "Settings"
        Write-LogMessage "Full error: $($_.Exception.ToString())" -Level Error -Tab "Settings"
    }
}

function Reset-GlobalSettings {
    # Reset global settings to defaults
    try {
        # Reset to default values
        $script:Config.ServerName = "pro2020"
        $script:Config.ServerPort = 8000
        $script:Config.AdminUser = "administrator"
        $script:Config.FlexAppClient = "C:\Program Files (x86)\Liquidware Labs\FlexApp Packaging Automation\primary-client.exe"
        $script:Config.PasswordFile = Join-Path $PSScriptRoot "password.txt"
        $script:Config.AESKeyFile = Join-Path $PSScriptRoot "aeskey.txt"
        $script:Config.TempPath = $env:TEMP
        $script:Config.ProcessWaitTime = 10
        $script:Config.DefaultFile = Join-Path $PSScriptRoot "Default.json"
        $script:Config.PrimaryServer = "https://pro2020:9075"
        
        # Update UI controls
        $serverTextBox = $script:MainForm.Controls.Find('SettingsServerTextBox', $true)[0]
        $serverPortTextBox = $script:MainForm.Controls.Find('SettingsServerPortTextBox', $true)[0]
        $adminUserTextBox = $script:MainForm.Controls.Find('SettingsAdminUserTextBox', $true)[0]
        $flexAppClientTextBox = $script:MainForm.Controls.Find('SettingsFlexAppClientTextBox', $true)[0]
        $passwordFileTextBox = $script:MainForm.Controls.Find('SettingsPasswordFileTextBox', $true)[0]
        $aesKeyFileTextBox = $script:MainForm.Controls.Find('SettingsAESKeyFileTextBox', $true)[0]
        $tempPathTextBox = $script:MainForm.Controls.Find('SettingsTempPathTextBox', $true)[0]
        $processWaitTextBox = $script:MainForm.Controls.Find('SettingsProcessWaitTextBox', $true)[0]
        $defaultFileTextBox = $script:MainForm.Controls.Find('SettingsDefaultFileTextBox', $true)[0]
        $chocoServerTextBox = $script:MainForm.Controls.Find('SettingsPrimaryServerTextBox', $true)[0]
        
        if ($serverTextBox) { $serverTextBox.Text = $script:Config.ServerName }
        if ($serverPortTextBox) { $serverPortTextBox.Text = $script:Config.ServerPort }
        if ($adminUserTextBox) { $adminUserTextBox.Text = $script:Config.AdminUser }
        if ($flexAppClientTextBox) { $flexAppClientTextBox.Text = $script:Config.FlexAppClient }
        if ($passwordFileTextBox) { $passwordFileTextBox.Text = $script:Config.PasswordFile }
        if ($aesKeyFileTextBox) { $aesKeyFileTextBox.Text = $script:Config.AESKeyFile }
        if ($tempPathTextBox) { $tempPathTextBox.Text = $script:Config.TempPath }
        if ($processWaitTextBox) { $processWaitTextBox.Text = $script:Config.ProcessWaitTime }
        if ($defaultFileTextBox) { $defaultFileTextBox.Text = $script:Config.DefaultFile }
        if ($chocoServerTextBox) { $chocoServerTextBox.Text = $script:Config.PrimaryServer }
        
        # Save to config file
        Save-GlobalSettings
        
        Write-LogMessage "Global settings reset to defaults" -Level Success -Tab "Settings"
    }
    catch {
        Write-LogMessage "Failed to reset global settings: $($_.Exception.Message)" -Level Error -Tab "Settings"
    }
}

function Test-GlobalSettings {
    # Test the global settings
    try {
        Write-LogMessage "Testing global settings..." -Level Info -Tab "Settings"
        
        # Test ProfileUnity Server connection
        $serverName = $script:Config.ServerName
        $serverPort = $script:Config.ServerPort
        
        if ([string]::IsNullOrWhiteSpace($serverName)) {
            throw "ProfileUnity Server is not configured"
        }
        
        Write-LogMessage "Testing connection to ProfileUnity Server: $serverName`:$serverPort" -Level Info -Tab "Settings"
        
        # Test if files exist
        $missingFiles = @()
        if (-not (Test-Path $script:Config.FlexAppClient)) {
            $missingFiles += "FlexApp Client: $($script:Config.FlexAppClient)"
        }
        if (-not (Test-Path $script:Config.PasswordFile)) {
            $missingFiles += "Password File: $($script:Config.PasswordFile)"
        }
        if (-not (Test-Path $script:Config.AESKeyFile)) {
            $missingFiles += "AES Key File: $($script:Config.AESKeyFile)"
        }
        if (-not (Test-Path $script:Config.TempPath)) {
            $missingFiles += "Temp Path: $($script:Config.TempPath)"
        }
        
        if ($missingFiles.Count -gt 0) {
            $message = "Missing files/paths:`n" + ($missingFiles -join "`n")
            Write-LogMessage $message -Level Warning -Tab "Settings"
            [System.Windows.Forms.MessageBox]::Show($message, "Missing Files", "OK", "Warning")
        } else {
            Write-LogMessage "All file paths are valid" -Level Success -Tab "Settings"
        }
        
        # Test ProfileUnity connection
        try {
            Initialize-SSLPolicy
            $password = Get-SecureCredentials
            
            $loginUri = "https://$serverName`:$serverPort/authenticate"
            $body = "username=$($script:Config.AdminUser)&password=$password"
            
            $response = Invoke-WebRequest -Uri $loginUri -Body $body -Method Post -TimeoutSec 10
            
            Write-LogMessage "ProfileUnity Server connection test: SUCCESS" -Level Success -Tab "Settings"
            [System.Windows.Forms.MessageBox]::Show("Connection test successful!`n`nProfileUnity Server: $serverName`:$serverPort`nUser: $($script:Config.AdminUser)`nFiles: All found", "Connection Test", "OK", "Information")
        }
        catch {
            Write-LogMessage "ProfileUnity Server connection test failed: $($_.Exception.Message)" -Level Error -Tab "Settings"
            [System.Windows.Forms.MessageBox]::Show("Connection test failed:`n`n$($_.Exception.Message)", "Connection Test Failed", "OK", "Error")
        }
    }
    catch {
        Write-LogMessage "Global settings test failed: $($_.Exception.Message)" -Level Error -Tab "Settings"
        [System.Windows.Forms.MessageBox]::Show("Settings test failed:`n`n$($_.Exception.Message)", "Test Failed", "OK", "Error")
    }
}