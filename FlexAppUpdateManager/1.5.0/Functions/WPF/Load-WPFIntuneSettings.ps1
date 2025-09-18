# Functions/WPF/Load-WPFIntuneSettings.ps1
# WPF function to load Intune settings

function Load-WPFIntuneSettings {
    [CmdletBinding()]
    param()

    try {
        Write-LogMessage "Load-WPFIntuneSettings function called" -Level Info -Tab "Intune"
        Write-Host "=== Load-WPFIntuneSettings DEBUG ===" -ForegroundColor Cyan
        
        # Get UI controls
        $clientIdTextBox = Find-Control -ControlName "IntuneClientIdTextBox"
        Write-LogMessage "Client ID textbox found: $($null -ne $clientIdTextBox)" -Level Info -Tab "Intune"
        Write-Host "Client ID textbox found: $($null -ne $clientIdTextBox)" -ForegroundColor Yellow
        $tenantIdTextBox = Find-Control -ControlName "IntuneTenantIdTextBox"
        $clientSecretPasswordBox = Find-Control -ControlName "IntuneClientSecretPasswordBox"
        $sourceFolderTextBox = Find-Control -ControlName "IntuneSourceFolderTextBox"
        $outputFolderTextBox = Find-Control -ControlName "IntuneOutputFolderTextBox"
        $toolPathTextBox = Find-Control -ControlName "IntuneToolPathTextBox"
        $publisherTextBox = Find-Control -ControlName "IntunePublisherTextBox"
        $runAsAccountComboBox = Find-Control -ControlName "IntuneRunAsAccountComboBox"
        $allowUninstallCheckBox = Find-Control -ControlName "IntuneAllowUninstallCheckBox"
        $cleanupCheckBox = Find-Control -ControlName "IntuneCleanupCheckBox"
        $dependencyTextBox = Find-Control -ControlName "IntuneDependencyTextBox"

        # Load settings from global settings
        Write-Host "Config object exists: $($null -ne $script:Config)" -ForegroundColor Yellow
        Write-Host "Config type: $($script:Config.GetType().Name)" -ForegroundColor Yellow
        Write-Host "IntuneSettings exists: $($null -ne $script:Config.IntuneSettings)" -ForegroundColor Yellow
        
        if ($script:Config.IntuneSettings) {
            Write-Host "IntuneSettings type: $($script:Config.IntuneSettings.GetType().Name)" -ForegroundColor Yellow
            Write-Host "IntuneSettings keys: $($script:Config.IntuneSettings.Keys -join ', ')" -ForegroundColor Yellow
        }
        
        Write-LogMessage "Config object exists: $($null -ne $script:Config)" -Level Info -Tab "Intune"
        Write-LogMessage "IntuneSettings exists: $($null -ne $script:Config.IntuneSettings)" -Level Info -Tab "Intune"
        
        if ($script:Config.IntuneSettings) {
            $settings = $script:Config.IntuneSettings
            Write-LogMessage "Loading Intune settings: ClientId=$($settings.ClientId), TenantId=$($settings.TenantId), Publisher=$($settings.Publisher)" -Level Info -Tab "Intune"

            # Update UI controls
            $clientIdTextBox.Text = if ($settings.ClientId) { $settings.ClientId } else { "" }
            $tenantIdTextBox.Text = if ($settings.TenantId) { $settings.TenantId } else { "" }
            # Decrypt the client secret when loading
            if ($settings.ClientSecret) {
                Write-Host "Client secret found in settings, length: $($settings.ClientSecret.Length)" -ForegroundColor Yellow
                Write-Host "AES key file path: $($script:Config.AESKeyFile)" -ForegroundColor Yellow
                Write-Host "AES key file exists: $(Test-Path $script:Config.AESKeyFile)" -ForegroundColor Yellow
                
                if (Test-Path $script:Config.AESKeyFile) {
                    try {
                        $aesKey = Get-Content -Path $script:Config.AESKeyFile
                        Write-Host "AES key loaded, length: $($aesKey.Length)" -ForegroundColor Yellow
                        $decryptedSecret = ConvertFrom-EncryptedString -EncryptedString $settings.ClientSecret -Key $aesKey
                        Write-Host "Client secret decrypted successfully, length: $($decryptedSecret.Length)" -ForegroundColor Green
                        Write-Host "Decrypted secret starts with: $($decryptedSecret.Substring(0, [Math]::Min(10, $decryptedSecret.Length)))..." -ForegroundColor Yellow
                        Write-Host "Decrypted secret ends with: ...$($decryptedSecret.Substring([Math]::Max(0, $decryptedSecret.Length - 10)))" -ForegroundColor Yellow
                        $clientSecretPasswordBox.Password = $decryptedSecret
                    }
                    catch {
                        Write-LogMessage "Error decrypting client secret: $($_.Exception.Message)" -Level Warning -Tab "Intune"
                        Write-Host "Error decrypting client secret: $($_.Exception.Message)" -ForegroundColor Red
                        $clientSecretPasswordBox.Password = ""
                    }
                } else {
                    # If no AES key file, assume it's stored in plain text (backward compatibility)
                    Write-Host "No AES key file found, using plain text client secret" -ForegroundColor Yellow
                    $clientSecretPasswordBox.Password = $settings.ClientSecret
                }
            } else {
                Write-Host "No client secret found in settings" -ForegroundColor Red
                $clientSecretPasswordBox.Password = ""
            }
            $sourceFolderTextBox.Text = if ($settings.SourceFolder) { $settings.SourceFolder } else { "" }
            $outputFolderTextBox.Text = if ($settings.OutputFolder) { $settings.OutputFolder } else { "" }
            $toolPathTextBox.Text = if ($settings.IntuneToolPath) { $settings.IntuneToolPath } else { "" }
            $publisherTextBox.Text = if ($settings.Publisher) { $settings.Publisher } else { "YourOrg" }
            $dependencyTextBox.Text = if ($settings.DependencyAppId) { $settings.DependencyAppId } else { "" }

            # Set ComboBox selection
            if ($settings.RunAsAccount) {
                foreach ($item in $runAsAccountComboBox.Items) {
                    if ($item.Content -eq $settings.RunAsAccount) {
                        $runAsAccountComboBox.SelectedItem = $item
                        break
                    }
                }
            } else {
                $runAsAccountComboBox.SelectedIndex = 0 # Default to "user"
            }

            # Set CheckBox states
            $allowUninstallCheckBox.IsChecked = if ($null -ne $settings.AllowAvailableUninstall) { $settings.AllowAvailableUninstall } else { $false }
            $cleanupCheckBox.IsChecked = if ($null -ne $settings.CleanupAfterWrap) { $settings.CleanupAfterWrap } else { $true }
        } else {
            # Set default values
            $publisherTextBox.Text = "YourOrg"
            $runAsAccountComboBox.SelectedIndex = 0
            $allowUninstallCheckBox.IsChecked = $false
            $cleanupCheckBox.IsChecked = $true
        }

        Write-LogMessage "Intune settings loaded" -Level Info -Tab "Intune"
        Write-Host "=== Load-WPFIntuneSettings COMPLETED ===" -ForegroundColor Cyan
    }
    catch {
        Write-LogMessage "Error loading Intune settings: $($_.Exception.Message)" -Level Error -Tab "Intune"
        Write-Host "=== Load-WPFIntuneSettings FAILED: $($_.Exception.Message) ===" -ForegroundColor Red
    }
}

# Debug function to test settings loading manually
function Test-IntuneSettingsLoad {
    Write-Host "=== MANUAL INTUNE SETTINGS TEST ===" -ForegroundColor Magenta
    
    # Check if config exists
    Write-Host "Script:Config exists: $($null -ne $script:Config)" -ForegroundColor Yellow
    
    if ($script:Config) {
        Write-Host "Config keys: $($script:Config.Keys -join ', ')" -ForegroundColor Yellow
        
        if ($script:Config.IntuneSettings) {
            Write-Host "IntuneSettings found!" -ForegroundColor Green
            Write-Host "IntuneSettings content:" -ForegroundColor Green
            $script:Config.IntuneSettings | Format-Table -AutoSize
        } else {
            Write-Host "IntuneSettings NOT found in config" -ForegroundColor Red
        }
    } else {
        Write-Host "Config object is null" -ForegroundColor Red
    }
    
    # Try to load settings manually
    Write-Host "Attempting to call Load-WPFIntuneSettings..." -ForegroundColor Yellow
    try {
        Load-WPFIntuneSettings
    } catch {
        Write-Host "Error calling Load-WPFIntuneSettings: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Simple function to test if UI controls can be found
function Test-IntuneUIControls {
    Write-Host "=== TESTING INTUNE UI CONTROLS ===" -ForegroundColor Magenta
    
    $controlNames = @(
        "IntuneClientIdTextBox",
        "IntuneTenantIdTextBox", 
        "IntuneClientSecretPasswordBox",
        "IntuneSourceFolderTextBox",
        "IntuneOutputFolderTextBox",
        "IntuneToolPathTextBox",
        "IntunePublisherTextBox",
        "IntuneRunAsAccountComboBox",
        "IntuneAllowUninstallCheckBox",
        "IntuneCleanupCheckBox",
        "IntuneDependencyTextBox"
    )
    
    foreach ($controlName in $controlNames) {
        $control = Find-Control -ControlName $controlName
        $found = $null -ne $control
        $color = if ($found) { "Green" } else { "Red" }
        Write-Host "$controlName : $found" -ForegroundColor $color
    }
}
