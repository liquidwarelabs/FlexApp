function Switch-WPFTheme {
    [CmdletBinding()]
    param()
    try {
        Write-LogMessage "Toggling theme..." -Level Info
        
        # Get UI controls
        $lightModeRadio = Find-Control "LightModeRadio"
        $darkModeRadio = Find-Control "DarkModeRadio"
        
        if (-not $lightModeRadio -or -not $darkModeRadio) {
            throw "Required UI controls not found"
        }
        
        # Determine theme from radio buttons
        $isDarkMode = $darkModeRadio.IsChecked
        
        # Update config
        if (-not $script:Config) {
            Load-AllSettings
        }
        
        if (-not $script:Config.PSObject.Properties.Match('DarkMode')) {
            $script:Config | Add-Member -MemberType NoteProperty -Name 'DarkMode' -Value $false -Force
        }
        
        $script:Config.DarkMode = $isDarkMode
        
        # Save config
        $configPath = Get-ConfigPath
        $script:Config | ConvertTo-Json | Out-File -FilePath $configPath -Force
        
        # Apply theme
        $script:WPFMainWindow.Dispatcher.Invoke([Action]{
            if ($isDarkMode) {
                # Apply dark theme resources
                $script:WPFMainWindow.Resources["PrimaryBackgroundBrush"] = $script:WPFMainWindow.Resources["DarkPrimaryBackgroundBrush"]
                $script:WPFMainWindow.Resources["SecondaryBackgroundBrush"] = $script:WPFMainWindow.Resources["DarkSecondaryBackgroundBrush"]
                $script:WPFMainWindow.Resources["PrimaryTextBrush"] = $script:WPFMainWindow.Resources["DarkPrimaryTextBrush"]
                $script:WPFMainWindow.Resources["SecondaryTextBrush"] = $script:WPFMainWindow.Resources["DarkSecondaryTextBrush"]
                $script:WPFMainWindow.Resources["BorderBrush"] = $script:WPFMainWindow.Resources["DarkBorderBrush"]
                $script:WPFMainWindow.Resources["PrimaryButtonBrush"] = $script:WPFMainWindow.Resources["DarkPrimaryButtonBrush"]
                $script:WPFMainWindow.Resources["PrimaryButtonHoverBrush"] = $script:WPFMainWindow.Resources["DarkPrimaryButtonHoverBrush"]
                $script:WPFMainWindow.Resources["PrimaryButtonPressedBrush"] = $script:WPFMainWindow.Resources["DarkPrimaryButtonPressedBrush"]
                $script:WPFMainWindow.Resources["SecondaryButtonBrush"] = $script:WPFMainWindow.Resources["DarkSecondaryButtonBrush"]
                $script:WPFMainWindow.Resources["SecondaryButtonHoverBrush"] = $script:WPFMainWindow.Resources["DarkSecondaryButtonHoverBrush"]
            }
            else {
                # Apply light theme resources
                $script:WPFMainWindow.Resources["PrimaryBackgroundBrush"] = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(245, 245, 245))
                $script:WPFMainWindow.Resources["SecondaryBackgroundBrush"] = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(255, 255, 255))
                $script:WPFMainWindow.Resources["PrimaryTextBrush"] = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(66, 66, 66))
                $script:WPFMainWindow.Resources["SecondaryTextBrush"] = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(117, 117, 117))
                $script:WPFMainWindow.Resources["BorderBrush"] = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(224, 224, 224))
                $script:WPFMainWindow.Resources["PrimaryButtonBrush"] = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(33, 150, 243))
                $script:WPFMainWindow.Resources["PrimaryButtonHoverBrush"] = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(25, 118, 210))
                $script:WPFMainWindow.Resources["PrimaryButtonPressedBrush"] = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(13, 71, 161))
                $script:WPFMainWindow.Resources["SecondaryButtonBrush"] = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(117, 117, 117))
                $script:WPFMainWindow.Resources["SecondaryButtonHoverBrush"] = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(97, 97, 97))
            }
            
            # Force refresh
            $script:WPFMainWindow.InvalidateVisual()
            $script:WPFMainWindow.UpdateLayout()
        })
        
        Write-LogMessage "Theme toggled successfully" -Level Success
    }
    catch {
        Write-LogMessage "Failed to toggle theme: $($_.Exception.Message)" -Level Error
        throw
    }
}

