# Functions/WPF/Save-WPFIntuneSettings.ps1
# WPF function to save Intune settings

function Save-WPFIntuneSettings {
    [CmdletBinding()]
    param()

    try {
        # Get UI controls
        $clientIdTextBox = Find-Control -ControlName "IntuneClientIdTextBox"
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

        # Create Intune settings object
        $intuneSettings = @{
            ClientId = $clientIdTextBox.Text.Trim()
            TenantId = $tenantIdTextBox.Text.Trim()
            ClientSecret = $clientSecretPasswordBox.Password
            SourceFolder = $sourceFolderTextBox.Text.Trim()
            OutputFolder = $outputFolderTextBox.Text.Trim()
            IntuneToolPath = $toolPathTextBox.Text.Trim()
            Publisher = $publisherTextBox.Text.Trim()
            RunAsAccount = $runAsAccountComboBox.SelectedItem.Content
            AllowAvailableUninstall = $allowUninstallCheckBox.IsChecked
            CleanupAfterWrap = $cleanupCheckBox.IsChecked
            DependencyAppId = $dependencyTextBox.Text.Trim()
        }

        # Save to global settings using Save-AllSettings function
        Save-AllSettings -IntuneClientId $intuneSettings.ClientId -IntuneTenantId $intuneSettings.TenantId -IntuneClientSecret $intuneSettings.ClientSecret -IntuneSourceFolder $intuneSettings.SourceFolder -IntuneOutputFolder $intuneSettings.OutputFolder -IntuneToolPath $intuneSettings.IntuneToolPath -IntunePublisher $intuneSettings.Publisher -IntuneRunAsAccount $intuneSettings.RunAsAccount -IntuneAllowUninstall $intuneSettings.AllowAvailableUninstall -IntuneCleanupAfterWrap $intuneSettings.CleanupAfterWrap -IntuneDependencyAppId $intuneSettings.DependencyAppId

        Write-LogMessage "Intune settings saved" -Level Info -Tab "Intune"
    }
    catch {
        Write-LogMessage "Error saving Intune settings: $($_.Exception.Message)" -Level Error -Tab "Intune"
    }
}
