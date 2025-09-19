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
        PasswordFile = "C:\Users\administrator\Desktop\Automation\password.txt"
        AESKeyFile = "C:\Users\administrator\Desktop\Automation\aeskey.txt"
        FlexAppClient = "C:\Program Files (x86)\Liquidware Labs\FlexApp Packaging Automation\primary-client.exe"
        TempPath = $env:TEMP
        ProcessWaitTime = 10
        DefaultFile = "C:\Users\administrator\Desktop\Default.json"
        PrimaryServer = "https://pro2020:9075"
        DarkMode = $false
        ConsoleDebug = $false
        CMSettings = @{
            SiteServer = ""
            SiteCode = ""
            OutputPath = "$env:USERPROFILE\Desktop\"
        }
        ChocoSettings = @{
            JobFile = "C:\Users\administrator\Desktop\Automation\catalog.csv"
        }
        WingetSettings = @{
            JobFile = "C:\Users\administrator\Desktop\Automation\winget_catalog.csv"
        }
        IntuneSettings = @{
            ClientId = ""
            TenantId = ""
            ClientSecret = ""
            SourceFolder = ""
            OutputFolder = ""
            IntuneToolPath = ""
            Publisher = "YourOrg"
            RunAsAccount = "user"
            AllowAvailableUninstall = $false
            CleanupAfterWrap = $false
            DependencyAppId = ""
        }
    }
}

function Get-ConfigPath {
    # Returns the configuration file path
    return "$env:APPDATA\LiquidwareSparks\FlexAppUpdateManager\config.json"
}

function ConvertTo-EncryptedString {
    param(
        [string]$PlainText,
        [string]$Key
    )
    
    if ([string]::IsNullOrEmpty($PlainText)) {
        return ""
    }
    
    try {
        Write-Host "ConvertTo-EncryptedString: Input length: $($PlainText.Length)" -ForegroundColor Magenta
        Write-Host "ConvertTo-EncryptedString: Input starts with: $($PlainText.Substring(0, [Math]::Min(10, $PlainText.Length)))..." -ForegroundColor Magenta
        Write-Host "ConvertTo-EncryptedString: Input ends with: ...$($PlainText.Substring([Math]::Max(0, $PlainText.Length - 10)))" -ForegroundColor Magenta
        
        # Convert the key string to byte array
        $keyBytes = $Key -split ' ' | ForEach-Object { [byte]$_ }
        
        $secureString = ConvertTo-SecureString -String $PlainText -AsPlainText -Force
        $encryptedString = $secureString | ConvertFrom-SecureString -Key $keyBytes
        
        Write-Host "ConvertTo-EncryptedString: Output length: $($encryptedString.Length)" -ForegroundColor Magenta
        return $encryptedString
    }
    catch {
        Write-LogMessage "Error encrypting string: $($_.Exception.Message)" -Level Error -Tab "Intune"
        Write-Host "ConvertTo-EncryptedString: ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return ""
    }
}

function ConvertFrom-EncryptedString {
    param(
        [string]$EncryptedString,
        [string]$Key
    )
    
    if ([string]::IsNullOrEmpty($EncryptedString)) {
        return ""
    }
    
    try {
        # Convert the key string to byte array
        $keyBytes = $Key -split ' ' | ForEach-Object { [byte]$_ }
        
        $secureString = $EncryptedString | ConvertTo-SecureString -Key $keyBytes
        $plainText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString))
        return $plainText
    }
    catch {
        Write-LogMessage "Error decrypting string: $($_.Exception.Message)" -Level Error -Tab "Intune"
        return ""
    }
}

function Save-AllSettings {
    param(
        [string]$CMSiteServer = $null,
        [string]$CMSiteCode = $null,
        [string]$CMOutputPath = $null,
        [string]$ChocoJobFile = $null,
        [string]$WingetJobFile = $null,
        [string]$IntuneClientId = $null,
        [string]$IntuneTenantId = $null,
        [string]$IntuneClientSecret = $null,
        [string]$IntuneSourceFolder = $null,
        [string]$IntuneOutputFolder = $null,
        [string]$IntuneToolPath = $null,
        [string]$IntunePublisher = $null,
        [string]$IntuneRunAsAccount = $null,
        [System.Nullable[bool]]$IntuneAllowUninstall = $null,
        [System.Nullable[bool]]$IntuneCleanupAfterWrap = $null,
        [string]$IntuneDependencyAppId = $null
    )
    
    try {
        # Ensure Config object exists
        if (-not $script:Config) {
            Write-LogMessage "Config object is null, cannot save settings" -Level Error -Tab "Intune"
            return
        }
        
        # Ensure nested objects exist before accessing them
        if (-not $script:Config.CMSettings) {
            $script:Config.CMSettings = @{
                SiteServer = ""
                SiteCode = ""
                OutputPath = "$env:USERPROFILE\Desktop\"
            }
        }
        if (-not $script:Config.ChocoSettings) {
            $script:Config.ChocoSettings = @{
                JobFile = ""
            }
        }
        if (-not $script:Config.WingetSettings) {
            $script:Config.WingetSettings = @{
                JobFile = ""
            }
        }
        if (-not $script:Config.IntuneSettings) {
            $script:Config.IntuneSettings = @{
                ClientId = ""
                TenantId = ""
                ClientSecret = ""
                SourceFolder = ""
                OutputFolder = ""
                IntuneToolPath = ""
                Publisher = "YourOrg"
                RunAsAccount = "user"
                AllowAvailableUninstall = $false
                CleanupAfterWrap = $false
                DependencyAppId = ""
            }
        }
        
        # Update settings in memory ONLY if provided (not null/empty)
        if (![string]::IsNullOrEmpty($CMSiteServer)) { 
            if (-not $script:Config.CMSettings) { $script:Config.CMSettings = @{ SiteServer = ""; SiteCode = ""; OutputPath = "$env:USERPROFILE\Desktop\" } }
            $script:Config.CMSettings.SiteServer = $CMSiteServer 
        }
        if (![string]::IsNullOrEmpty($CMSiteCode)) { 
            if (-not $script:Config.CMSettings) { $script:Config.CMSettings = @{ SiteServer = ""; SiteCode = ""; OutputPath = "$env:USERPROFILE\Desktop\" } }
            $script:Config.CMSettings.SiteCode = $CMSiteCode 
        }
        if (![string]::IsNullOrEmpty($CMOutputPath)) { 
            if (-not $script:Config.CMSettings) { $script:Config.CMSettings = @{ SiteServer = ""; SiteCode = ""; OutputPath = "$env:USERPROFILE\Desktop\" } }
            $script:Config.CMSettings.OutputPath = $CMOutputPath 
        }
        if (![string]::IsNullOrEmpty($ChocoJobFile)) { 
            if (-not $script:Config.ChocoSettings) { $script:Config.ChocoSettings = @{ JobFile = "" } }
            $script:Config.ChocoSettings.JobFile = $ChocoJobFile 
        }
        if (![string]::IsNullOrEmpty($WingetJobFile)) { 
            if (-not $script:Config.WingetSettings) { $script:Config.WingetSettings = @{ JobFile = "" } }
            $script:Config.WingetSettings.JobFile = $WingetJobFile 
        }
        
        # Update Intune settings
        if (![string]::IsNullOrEmpty($IntuneClientId)) { 
            Write-LogMessage "Saving Intune Client ID: $IntuneClientId" -Level Info -Tab "Intune"
            if (-not $script:Config.IntuneSettings) { 
                Write-LogMessage "Creating IntuneSettings object" -Level Info -Tab "Intune"
                $script:Config.IntuneSettings = @{ ClientId = ""; TenantId = ""; ClientSecret = ""; SourceFolder = ""; OutputFolder = ""; IntuneToolPath = ""; Publisher = "YourOrg"; RunAsAccount = "user"; AllowAvailableUninstall = $false; CleanupAfterWrap = $true; DependencyAppId = "" } 
            }
            Write-LogMessage "Setting ClientId in IntuneSettings" -Level Info -Tab "Intune"
            $script:Config.IntuneSettings.ClientId = $IntuneClientId 
            Write-LogMessage "ClientId saved successfully" -Level Info -Tab "Intune"
        }
        if (![string]::IsNullOrEmpty($IntuneTenantId)) { 
            if (-not $script:Config.IntuneSettings) { $script:Config.IntuneSettings = @{ ClientId = ""; TenantId = ""; ClientSecret = ""; SourceFolder = ""; OutputFolder = ""; IntuneToolPath = ""; Publisher = "YourOrg"; RunAsAccount = "user"; AllowAvailableUninstall = $false; CleanupAfterWrap = $true; DependencyAppId = "" } }
            $script:Config.IntuneSettings.TenantId = $IntuneTenantId 
        }
        if (![string]::IsNullOrEmpty($IntuneClientSecret)) { 
            if (-not $script:Config.IntuneSettings) { $script:Config.IntuneSettings = @{ ClientId = ""; TenantId = ""; ClientSecret = ""; SourceFolder = ""; OutputFolder = ""; IntuneToolPath = ""; Publisher = "YourOrg"; RunAsAccount = "user"; AllowAvailableUninstall = $false; CleanupAfterWrap = $true; DependencyAppId = "" } }
            # Encrypt the client secret before saving
            Write-Host "=== SAVING CLIENT SECRET DEBUG ===" -ForegroundColor Cyan
            Write-Host "Original secret length: $($IntuneClientSecret.Length)" -ForegroundColor Yellow
            Write-Host "Original secret starts with: $($IntuneClientSecret.Substring(0, [Math]::Min(10, $IntuneClientSecret.Length)))..." -ForegroundColor Yellow
            Write-Host "Original secret ends with: ...$($IntuneClientSecret.Substring([Math]::Max(0, $IntuneClientSecret.Length - 10)))" -ForegroundColor Yellow
            
            if (Test-Path $script:Config.AESKeyFile) {
                $aesKey = Get-Content -Path $script:Config.AESKeyFile
                $encryptedSecret = ConvertTo-EncryptedString -PlainText $IntuneClientSecret -Key $aesKey
                Write-Host "Encrypted secret length: $($encryptedSecret.Length)" -ForegroundColor Green
                $script:Config.IntuneSettings.ClientSecret = $encryptedSecret
            } else {
                Write-LogMessage "AES key file not found, storing client secret in plain text (not recommended)" -Level Warning -Tab "Intune"
                Write-Host "Storing in plain text, length: $($IntuneClientSecret.Length)" -ForegroundColor Red
                $script:Config.IntuneSettings.ClientSecret = $IntuneClientSecret
            }
        }
        if (![string]::IsNullOrEmpty($IntuneSourceFolder)) { 
            if (-not $script:Config.IntuneSettings) { $script:Config.IntuneSettings = @{ ClientId = ""; TenantId = ""; ClientSecret = ""; SourceFolder = ""; OutputFolder = ""; IntuneToolPath = ""; Publisher = "YourOrg"; RunAsAccount = "user"; AllowAvailableUninstall = $false; CleanupAfterWrap = $true; DependencyAppId = "" } }
            $script:Config.IntuneSettings.SourceFolder = $IntuneSourceFolder 
        }
        if (![string]::IsNullOrEmpty($IntuneOutputFolder)) { 
            if (-not $script:Config.IntuneSettings) { $script:Config.IntuneSettings = @{ ClientId = ""; TenantId = ""; ClientSecret = ""; SourceFolder = ""; OutputFolder = ""; IntuneToolPath = ""; Publisher = "YourOrg"; RunAsAccount = "user"; AllowAvailableUninstall = $false; CleanupAfterWrap = $true; DependencyAppId = "" } }
            $script:Config.IntuneSettings.OutputFolder = $IntuneOutputFolder 
        }
        if (![string]::IsNullOrEmpty($IntuneToolPath)) { 
            if (-not $script:Config.IntuneSettings) { $script:Config.IntuneSettings = @{ ClientId = ""; TenantId = ""; ClientSecret = ""; SourceFolder = ""; OutputFolder = ""; IntuneToolPath = ""; Publisher = "YourOrg"; RunAsAccount = "user"; AllowAvailableUninstall = $false; CleanupAfterWrap = $true; DependencyAppId = "" } }
            $script:Config.IntuneSettings.IntuneToolPath = $IntuneToolPath 
        }
        if (![string]::IsNullOrEmpty($IntunePublisher)) { 
            if (-not $script:Config.IntuneSettings) { $script:Config.IntuneSettings = @{ ClientId = ""; TenantId = ""; ClientSecret = ""; SourceFolder = ""; OutputFolder = ""; IntuneToolPath = ""; Publisher = "YourOrg"; RunAsAccount = "user"; AllowAvailableUninstall = $false; CleanupAfterWrap = $true; DependencyAppId = "" } }
            $script:Config.IntuneSettings.Publisher = $IntunePublisher 
        }
        if (![string]::IsNullOrEmpty($IntuneRunAsAccount)) { 
            if (-not $script:Config.IntuneSettings) { $script:Config.IntuneSettings = @{ ClientId = ""; TenantId = ""; ClientSecret = ""; SourceFolder = ""; OutputFolder = ""; IntuneToolPath = ""; Publisher = "YourOrg"; RunAsAccount = "user"; AllowAvailableUninstall = $false; CleanupAfterWrap = $true; DependencyAppId = "" } }
            $script:Config.IntuneSettings.RunAsAccount = $IntuneRunAsAccount 
        }
        if ($IntuneAllowUninstall -ne $null) { 
            if (-not $script:Config.IntuneSettings) { $script:Config.IntuneSettings = @{ ClientId = ""; TenantId = ""; ClientSecret = ""; SourceFolder = ""; OutputFolder = ""; IntuneToolPath = ""; Publisher = "YourOrg"; RunAsAccount = "user"; AllowAvailableUninstall = $false; CleanupAfterWrap = $true; DependencyAppId = "" } }
            $script:Config.IntuneSettings.AllowAvailableUninstall = $IntuneAllowUninstall 
        }
        if ($IntuneCleanupAfterWrap -ne $null) { 
            if (-not $script:Config.IntuneSettings) { $script:Config.IntuneSettings = @{ ClientId = ""; TenantId = ""; ClientSecret = ""; SourceFolder = ""; OutputFolder = ""; IntuneToolPath = ""; Publisher = "YourOrg"; RunAsAccount = "user"; AllowAvailableUninstall = $false; CleanupAfterWrap = $true; DependencyAppId = "" } }
            $script:Config.IntuneSettings.CleanupAfterWrap = $IntuneCleanupAfterWrap 
        }
        if (![string]::IsNullOrEmpty($IntuneDependencyAppId)) { 
            if (-not $script:Config.IntuneSettings) { $script:Config.IntuneSettings = @{ ClientId = ""; TenantId = ""; ClientSecret = ""; SourceFolder = ""; OutputFolder = ""; IntuneToolPath = ""; Publisher = "YourOrg"; RunAsAccount = "user"; AllowAvailableUninstall = $false; CleanupAfterWrap = $true; DependencyAppId = "" } }
            $script:Config.IntuneSettings.DependencyAppId = $IntuneDependencyAppId 
        }
        
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
            
            # Migration: Move old CM settings to new nested structure if needed
            if ($loadedConfig.CMServer -and -not $script:Config.CMSettings.SiteServer) {
                $script:Config.CMSettings.SiteServer = $loadedConfig.CMServer
                Write-LogMessage "Migrated CMServer to CMSettings.SiteServer" -Level Info -Tab "Configuration"
            }
            if ($loadedConfig.CMSiteCode -and -not $script:Config.CMSettings.SiteCode) {
                $script:Config.CMSettings.SiteCode = $loadedConfig.CMSiteCode
                Write-LogMessage "Migrated CMSiteCode to CMSettings.SiteCode" -Level Info -Tab "Configuration"
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