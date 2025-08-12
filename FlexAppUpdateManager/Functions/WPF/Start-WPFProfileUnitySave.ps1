function Start-WPFProfileUnitySave {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Starting ProfileUnity configuration save..." -Level Info -Tab "ProfileUnity"
        
        # Get UI controls
        $statusLabel = Find-Control "PUStatusLabel"
        
        if (-not $statusLabel) {
            throw "Status label not found"
        }
        
        if (-not $script:PUCurrentConfig) {
            throw "No configuration loaded. Please load a configuration first."
        }
        
        $statusLabel.Content = "Saving configuration..."
        
        # Confirm save
        $result = [System.Windows.MessageBox]::Show(
            "Are you sure you want to save the current configuration to ProfileUnity?",
            "Confirm Save",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )
        
        if ($result -ne [System.Windows.MessageBoxResult]::Yes) {
            $statusLabel.Content = "Save cancelled"
            return
        }
        
        # Save the configuration using ProfileUnity API
        $saveUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/configuration"
        $body = $script:PUCurrentConfig | ConvertTo-Json -Depth 10
        
        $response = Invoke-WebRequest -Uri $saveUri -Method Post -WebSession $script:ChocoSession -ContentType "application/json" -Body $body
        
        if ($response.StatusCode -eq 200) {
            Write-LogMessage "Configuration saved successfully" -Level Success -Tab "ProfileUnity"
            $statusLabel.Content = "Configuration saved successfully!"
            
            [System.Windows.MessageBox]::Show(
                "Configuration saved successfully to ProfileUnity server!", 
                "Success", 
                [System.Windows.MessageBoxButton]::OK, 
                [System.Windows.MessageBoxImage]::Information
            )
        } else {
            throw "Failed to save configuration. Server returned: $($response.StatusCode)"
        }
    }
    catch {
        Write-LogMessage "Failed to save configuration: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        if ($statusLabel) {
            $statusLabel.Content = "Failed to save configuration"
        }
        [System.Windows.MessageBox]::Show(
            "Error saving configuration: $($_.Exception.Message)", 
            "Save Error", 
            [System.Windows.MessageBoxButton]::OK, 
            [System.Windows.MessageBoxImage]::Error
        )
    }
}




