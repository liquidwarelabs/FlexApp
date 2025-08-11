function Save-WPFGlobalSettings {
    [CmdletBinding()]
    param()
    try {
        Write-LogMessage "Saving global settings..." -Level Info
        
        # Get UI controls
        $serverTextBox = Find-Control "SettingsServerTextBox"
        $serverPortTextBox = Find-Control "SettingsServerPortTextBox"
        $adminUserTextBox = Find-Control "SettingsAdminUserTextBox"
        $flexAppClientTextBox = Find-Control "SettingsFlexAppClientTextBox"
        $passwordFileTextBox = Find-Control "SettingsPasswordFileTextBox"
        $aesKeyFileTextBox = Find-Control "SettingsAESKeyFileTextBox"
        $tempPathTextBox = Find-Control "SettingsTempPathTextBox"
        $defaultFileTextBox = Find-Control "SettingsDefaultFileTextBox"
        $primaryServerTextBox = Find-Control "SettingsPrimaryServerTextBox"
        $processWaitTextBox = Find-Control "SettingsProcessWaitTextBox"
        $cmServerTextBox = Find-Control "CMServerTextBox"
        $cmSiteCodeTextBox = Find-Control "CMSiteCodeTextBox"
        
        if (-not $script:Config) {
            Load-AllSettings
        }
        
        # Update config with UI values
        $script:Config.ServerName = $serverTextBox.Text.Trim()
        $script:Config.ServerPort = $serverPortTextBox.Text.Trim()
        $script:Config.AdminUser = $adminUserTextBox.Text.Trim()
        $script:Config.FlexAppClient = $flexAppClientTextBox.Text.Trim()
        $script:Config.PasswordFile = $passwordFileTextBox.Text.Trim()
        $script:Config.AESKeyFile = $aesKeyFileTextBox.Text.Trim()
        $script:Config.TempPath = $tempPathTextBox.Text.Trim()
        $script:Config.DefaultFile = $defaultFileTextBox.Text.Trim()
        $script:Config.PrimaryServer = $primaryServerTextBox.Text.Trim()
        $script:Config.ProcessWaitTime = [int]$processWaitTextBox.Text.Trim()
        $script:Config.CMServer = $cmServerTextBox.Text.Trim()
        $script:Config.CMSiteCode = $cmSiteCodeTextBox.Text.Trim()
        
        # Save config
        $configPath = Get-ConfigPath
        $script:Config | ConvertTo-Json | Out-File -FilePath $configPath -Force
        
        Write-LogMessage "Global settings saved successfully" -Level Success
    }
    catch {
        Write-LogMessage "Failed to save settings: $($_.Exception.Message)" -Level Error
        throw
    }
}

