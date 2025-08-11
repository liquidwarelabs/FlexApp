# File: Config\Settings-Persistence.ps1
# ================================
# Settings persistence functions with default value management

function Get-DefaultConfig {
    # Returns default configuration values
    # This is the ONLY place where defaults are defined
    return @{
        ServerName = "pro2020"
        ServerPort = 8000
        AdminUser = "administrator"
            PasswordFile = Join-Path $PSScriptRoot "password.txt"
    AESKeyFile = Join-Path $PSScriptRoot "aeskey.txt"
        FlexAppClient = "C:\Program Files (x86)\Liquidware Labs\FlexApp Packaging Automation\primary-client.exe"
        TempPath = $env:TEMP
        ProcessWaitTime = 10
        DefaultFile = Join-Path $PSScriptRoot "Default.json"
        PrimaryServer = "https://pro2020:9075"
        DarkMode = $false
        CMSettings = @{
            SiteServer = ""
            SiteCode = ""
            OutputPath = "$env:USERPROFILE\Desktop\"
        }
        ChocoSettings = @{
            JobFile = ""  # User-configurable, no default path
        }
        WingetSettings = @{
            JobFile = ""  # User-configurable, no default path
        }
    }
}

function Get-ConfigPath {
    # Returns the configuration file path
    return "$env:APPDATA\FlexAppUpdateManager\config.json"
}

function Save-AllSettings {
    param(
        [string]$CMSiteServer,
        [string]$CMSiteCode,
        [string]$CMOutputPath,
        [string]$ChocoJobFile,
        [string]$WingetJobFile
    )
    
    try {
        # Update settings in memory ONLY if provided (not null/empty)
        if (![string]::IsNullOrEmpty($CMSiteServer)) { $script:Config.CMSettings.SiteServer = $CMSiteServer }
        if (![string]::IsNullOrEmpty($CMSiteCode)) { $script:Config.CMSettings.SiteCode = $CMSiteCode }
        if (![string]::IsNullOrEmpty($CMOutputPath)) { $script:Config.CMSettings.OutputPath = $CMOutputPath }
        if (![string]::IsNullOrEmpty($ChocoJobFile)) { $script:Config.ChocoSettings.JobFile = $ChocoJobFile }
        if (![string]::IsNullOrEmpty($WingetJobFile)) { $script:Config.WingetSettings.JobFile = $WingetJobFile }
        
        # Save to config file
        $configPath = Get-ConfigPath
        
        # Ensure directory exists
        $configDir = Split-Path $configPath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        # Save config
        $script:Config | ConvertTo-Json -Depth 10 | Out-File $configPath -Encoding UTF8
        
        Write-LogMessage "Application settings saved successfully" -Level Success -Tab "Configuration"
    }
    catch {
        Write-LogMessage "Failed to save application settings: $($_.Exception.Message)" -Level Error -Tab "Configuration"
    }
}

function Load-AllSettings {
    try {
        $configPath = Get-ConfigPath
        
        if (Test-Path $configPath) {
            # Load from file
            $loadedConfig = Get-Content $configPath -Raw | ConvertFrom-Json
            
            # Start with defaults
            $script:Config = Get-DefaultConfig
            
            # Merge loaded settings over defaults
            # This ensures any new settings added in future versions get default values
            foreach ($property in $loadedConfig.PSObject.Properties) {
                if ($property.Name -eq 'CMSettings' -or $property.Name -eq 'ChocoSettings' -or $property.Name -eq 'WingetSettings') {
                    # Handle nested objects
                    foreach ($subProperty in $property.Value.PSObject.Properties) {
                        $script:Config[$property.Name][$subProperty.Name] = $subProperty.Value
                    }
                } else {
                    # Handle simple properties
                    $script:Config[$property.Name] = $property.Value
                }
            }
            
            Write-LogMessage "Settings loaded from: $configPath" -Level Success -Tab "Configuration"
            return $true
        }
        else {
            # No config file exists, use defaults
            Write-LogMessage "No saved settings found, creating default configuration" -Level Info -Tab "Configuration"
            $script:Config = Get-DefaultConfig
            
            # Save the default configuration
            Save-AllSettings
            
            return $false
        }
    }
    catch {
        Write-LogMessage "Failed to load settings: $($_.Exception.Message)" -Level Error -Tab "Configuration"
        
        # Fall back to defaults on error
        $script:Config = Get-DefaultConfig
        return $false
    }
}

function Update-CMConnectionUI {
    # Call this function when connection is successful to save the settings
    try {
        $siteServerTextBox = $script:MainForm.Controls.Find('CMSiteServerTextBox', $true)[0]
        $siteCodeTextBox = $script:MainForm.Controls.Find('CMSiteCodeTextBox', $true)[0]
        $outputPathTextBox = $script:MainForm.Controls.Find('CMOutputPathTextBox', $true)[0]
        
        $siteServer = if ($siteServerTextBox) { $siteServerTextBox.Text } else { "" }
        $siteCode = if ($siteCodeTextBox) { $siteCodeTextBox.Text } else { "" }
        $outputPath = if ($outputPathTextBox) { $outputPathTextBox.Text } else { "$env:USERPROFILE\Desktop\" }
        
        # Save the settings
        Save-AllSettings -CMSiteServer $siteServer -CMSiteCode $siteCode -CMOutputPath $outputPath
        
        Write-LogMessage "Configuration Manager connection settings saved" -Level Success -Tab "Configuration Manager"
    }
    catch {
        Write-LogMessage "Failed to save Configuration Manager connection settings: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
    }
}

function Save-ChocoSettings {
    # Call this function to save Chocolatey settings
    try {
        $jobFileTextBox = $script:MainForm.Controls.Find('ChocoJobFileTextBox', $true)[0]
        
        $jobFile = if ($jobFileTextBox) { $jobFileTextBox.Text } else { "" }
        
        # Save using the centralized function
        Save-AllSettings -ChocoJobFile $jobFile
        
        Write-LogMessage "Chocolatey settings saved" -Level Success -Tab "Chocolatey"
    }
    catch {
        Write-LogMessage "Failed to save Chocolatey settings: $($_.Exception.Message)" -Level Error -Tab "Chocolatey"
    }
}

function Save-WingetSettings {
    # Call this function to save Winget settings
    try {
        $jobFileTextBox = $script:MainForm.Controls.Find('WingetJobFileTextBox', $true)[0]
        
        $jobFile = if ($jobFileTextBox) { $jobFileTextBox.Text } else { "" }
        
        # Save using the centralized function
        Save-AllSettings -WingetJobFile $jobFile
        
        Write-LogMessage "Winget settings saved" -Level Success -Tab "Winget"
    }
    catch {
        Write-LogMessage "Failed to save Winget settings: $($_.Exception.Message)" -Level Error -Tab "Winget"
    }
}

function Save-CMOutputPath {
    # Call this function when output path changes
    try {
        $outputPathTextBox = $script:MainForm.Controls.Find('CMOutputPathTextBox', $true)[0]
        $outputPath = if ($outputPathTextBox) { $outputPathTextBox.Text } else { "" }
        
        # Save using the centralized function
        Save-AllSettings -CMOutputPath $outputPath
        
        Write-LogMessage "CM Output path saved: $outputPath" -Level Info -Tab "Configuration Manager"
    }
    catch {
        Write-LogMessage "Failed to save CM output path: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
    }
}