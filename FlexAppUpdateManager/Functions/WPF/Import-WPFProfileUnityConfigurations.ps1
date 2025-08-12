function Import-WPFProfileUnityConfigurations {
    [CmdletBinding()]
    param()

    try {
        # Get UI controls
        $configComboBox = Find-Control "PUConfigComboBox"
        $progressBar = Find-Control "PUProgressBar"
        $statusLabel = Find-Control "PUStatusLabel"

        if (-not $configComboBox -or -not $progressBar -or -not $statusLabel) {
            Write-LogMessage "Failed to find required UI controls" -Level Error -Tab "ProfileUnity"
            return $false
        }

        # Update UI state
        $progressBar.Value = 0
        $progressBar.Visibility = "Visible"
        $statusLabel.Content = "Connecting to ProfileUnity server..."

        # Initialize ProfileUnity globals
        Initialize-ProfileUnityGlobals

        # Connect to ProfileUnity server
        if (-not (Connect-ProfileUnityServer)) {
            throw "Failed to connect to ProfileUnity server"
        }

        $statusLabel.Content = "Loading configurations..."

        # Get all configurations from ProfileUnity API
        $configsUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/configuration"
        $response = Invoke-WebRequest -Uri $configsUri -WebSession $script:ChocoSession
        $configData = ($response.Content | ConvertFrom-Json)

        if ($configData.Tag.Rows) {
            $script:PUConfigurations = $configData.Tag.Rows | Where-Object { $_.name -ne $null }

            # Update ComboBox
            $configComboBox.Items.Clear()
            foreach ($config in $script:PUConfigurations) {
                [void]$configComboBox.Items.Add($config.name)
            }

            if ($configComboBox.Items.Count -gt 0) {
                $configComboBox.SelectedIndex = 0
                $statusLabel.Content = "Connected - $($configComboBox.Items.Count) configurations loaded"
            } else {
                $statusLabel.Content = "No configurations found"
            }
        } else {
            throw "No configurations returned from server"
        }

        # Get FlexApp inventory for later use
        $script:PUFlexAppInventory = Get-ProfileUnityFlexApps
        Write-LogMessage "Loaded $($script:PUFlexAppInventory.Count) FlexApp packages from inventory" -Level Info -Tab "ProfileUnity"

        # Update UI state
        $progressBar.Value = 100
        $progressBar.Visibility = "Collapsed"

        Write-LogMessage "Successfully loaded $($script:PUConfigurations.Count) configurations" -Level Success -Tab "ProfileUnity"
        return $true
    }
    catch {
        Write-LogMessage "Failed to load configurations: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        if ($statusLabel) {
            $statusLabel.Content = "Error: $($_.Exception.Message)"
        }
        if ($progressBar) {
            $progressBar.Visibility = "Collapsed"
        }
        return $false
    }
}
