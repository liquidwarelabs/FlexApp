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
        
        # Ensure CMSettings object exists
        if (-not $script:Config.CMSettings) {
            $script:Config.CMSettings = @{
                SiteServer = ""
                SiteCode = ""
                OutputPath = "$env:USERPROFILE\Desktop\"
            }
        }
        
        # Update config with UI values (safely handle null controls)
        if ($serverTextBox) { $script:Config.ServerName = $serverTextBox.Text.Trim() }
        if ($serverPortTextBox) { $script:Config.ServerPort = $serverPortTextBox.Text.Trim() }
        if ($adminUserTextBox) { $script:Config.AdminUser = $adminUserTextBox.Text.Trim() }
        if ($flexAppClientTextBox) { $script:Config.FlexAppClient = $flexAppClientTextBox.Text.Trim() }
        if ($passwordFileTextBox) { $script:Config.PasswordFile = $passwordFileTextBox.Text.Trim() }
        if ($aesKeyFileTextBox) { $script:Config.AESKeyFile = $aesKeyFileTextBox.Text.Trim() }
        if ($tempPathTextBox) { $script:Config.TempPath = $tempPathTextBox.Text.Trim() }
        if ($defaultFileTextBox) { $script:Config.DefaultFile = $defaultFileTextBox.Text.Trim() }
        if ($primaryServerTextBox) { $script:Config.PrimaryServer = $primaryServerTextBox.Text.Trim() }
        if ($processWaitTextBox) { $script:Config.ProcessWaitTime = [int]$processWaitTextBox.Text.Trim() }
        
        # Save CM settings to the correct location (CMSettings nested object)
        if ($cmServerTextBox) { 
            $script:Config.CMSettings.SiteServer = $cmServerTextBox.Text.Trim()
            # Also maintain backward compatibility with old CMServer property
            $script:Config.CMServer = $cmServerTextBox.Text.Trim()
        }
        if ($cmSiteCodeTextBox) { 
            $script:Config.CMSettings.SiteCode = $cmSiteCodeTextBox.Text.Trim()
            # Also maintain backward compatibility with old CMSiteCode property
            $script:Config.CMSiteCode = $cmSiteCodeTextBox.Text.Trim()
        }
        
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

