# File: Functions\ProfileUnity\ProfileUnity-ConfigLoader.ps1
# ================================
# Functions for loading ProfileUnity configurations

function Load-ProfileUnityConfigurations {
    [CmdletBinding()]
    param()
    
    try {
        $configComboBox = $script:MainForm.Controls.Find('PUConfigComboBox', $true)[0]
        $scanButton = $script:MainForm.Controls.Find('PUScanButton', $true)[0]
        $connectionStatusLabel = $script:MainForm.Controls.Find('PUConnectionStatusLabel', $true)[0]
        $progressBar = $script:MainForm.Controls.Find('PUProgressBar', $true)[0]
        
        # Initialize globals
        Initialize-ProfileUnityGlobals
        
        # Show progress
        $progressBar.Visible = $true
        $progressBar.Style = "Marquee"
        $connectionStatusLabel.Text = "Connecting to ProfileUnity server..."
        $connectionStatusLabel.ForeColor = [System.Drawing.Color]::Blue
        [System.Windows.Forms.Application]::DoEvents()
        
        # Connect to ProfileUnity
        if (-not (Connect-ProfileUnityServer)) {
            throw "Failed to connect to ProfileUnity server"
        }
        
        Write-LogMessage "Loading ProfileUnity configurations..." -Level Info -Tab "ProfileUnity"
        
        # Get all configurations
        $configsUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/configuration"
        $response = Invoke-WebRequest -Uri $configsUri -WebSession $script:ChocoSession
        $configData = ($response.Content | ConvertFrom-Json)
        
        if ($configData.Tag.Rows) {
            $script:PUConfigurations = $configData.Tag.Rows | Where-Object { $_.name -ne $null }
            
            # Populate combo box
            $configComboBox.Items.Clear()
            foreach ($config in $script:PUConfigurations) {
                [void]$configComboBox.Items.Add($config.name)
            }
            
            if ($configComboBox.Items.Count -gt 0) {
                $configComboBox.SelectedIndex = 0
                $scanButton.Enabled = $true
                $connectionStatusLabel.Text = "Connected - $($configComboBox.Items.Count) configurations loaded"
                $connectionStatusLabel.ForeColor = [System.Drawing.Color]::Green
            } else {
                $connectionStatusLabel.Text = "No configurations found"
                $connectionStatusLabel.ForeColor = [System.Drawing.Color]::Orange
            }
        } else {
            throw "No configurations returned from server"
        }
        
        # Get FlexApp inventory for later use
        $script:PUFlexAppInventory = Get-ProfileUnityFlexApps
        Write-LogMessage "Loaded $($script:PUFlexAppInventory.Count) FlexApp packages from inventory" -Level Info -Tab "ProfileUnity"
        
    }
    catch {
        Write-LogMessage "Failed to load configurations: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        $connectionStatusLabel.Text = "Error: $($_.Exception.Message)"
        $connectionStatusLabel.ForeColor = [System.Drawing.Color]::Red
        [System.Windows.Forms.MessageBox]::Show("Failed to load configurations: $($_.Exception.Message)", "Error", "OK", "Error")
    }
    finally {
        $progressBar.Visible = $false
        $progressBar.Style = "Blocks"
    }
}

function Get-ProfileUnityConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigId
    )
    
    try {
        $configUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/configuration/$ConfigId"
        $response = Invoke-WebRequest -Uri $configUri -WebSession $script:ChocoSession
        $configData = ($response.Content | ConvertFrom-Json)
        return $configData.tag
    }
    catch {
        Write-LogMessage "Failed to get configuration: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        throw
    }
}

function Save-ProfileUnityConfiguration {
    [CmdletBinding()]
    param()
    
    try {
        $statusLabel = $script:MainForm.Controls.Find('PUStatusLabel', $true)[0]
        $progressBar = $script:MainForm.Controls.Find('PUProgressBar', $true)[0]
        
        Write-LogMessage "Saving ProfileUnity configuration..." -Level Info -Tab "ProfileUnity"
        if ($statusLabel) { $statusLabel.Text = "Saving configuration..." }
        
        if ($progressBar) {
            $progressBar.Visible = $true
            $progressBar.Style = "Marquee"
            [System.Windows.Forms.Application]::DoEvents()
        }
        
        # Save the configuration
        $saveUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/configuration"
        $body = $script:PUCurrentConfig | ConvertTo-Json -Depth 10
        
        $response = Invoke-WebRequest -Uri $saveUri -Method Post -WebSession $script:ChocoSession -ContentType "application/json" -Body $body
        
        if ($response.StatusCode -eq 200) {
            Write-LogMessage "Configuration saved successfully" -Level Success -Tab "ProfileUnity"
            if ($statusLabel) { $statusLabel.Text = "Configuration saved successfully" }
            $script:PUConfigModified = $false
            
            [System.Windows.Forms.MessageBox]::Show("Configuration saved successfully!", "Success", "OK", "Information")
        } else {
            throw "Save failed with status code: $($response.StatusCode)"
        }
    }
    catch {
        Write-LogMessage "Failed to save configuration: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        if ($statusLabel) { $statusLabel.Text = "Failed to save configuration" }
        [System.Windows.Forms.MessageBox]::Show("Failed to save configuration: $($_.Exception.Message)", "Error", "OK", "Error")
    }
    finally {
        if ($progressBar) {
            $progressBar.Visible = $false
            $progressBar.Style = "Blocks"
        }
    }
}