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
        
        # Save config preserving all current UI values including job files
        # Get job file values from UI
        $chocoJobFileTextBox = Find-Control "ChocoJobFileTextBox"
        $wingetJobFileTextBox = Find-Control "WingetJobFileTextBox"
        
        $chocoJobFile = if ($chocoJobFileTextBox) { $chocoJobFileTextBox.Text } else { "" }
        $wingetJobFile = if ($wingetJobFileTextBox) { $wingetJobFileTextBox.Text } else { "" }
        
        # Get installer path from UI
        $wingetInstallerTextBox = Find-Control "WingetInstallerTextBox"
        $wingetInstallerPath = if ($wingetInstallerTextBox) { $wingetInstallerTextBox.Text } else { "" }
        
        Write-LogMessage "Theme switch - Current UI values: Choco='$chocoJobFile', Winget='$wingetJobFile', Installer='$wingetInstallerPath'" -Level Info
        Write-LogMessage "Theme switch - Current config values: Choco='$($script:Config.ChocoSettings.JobFile)', Winget='$($script:Config.WingetSettings.JobFile)', Installer='$($script:Config.WingetSettings.InstallerPath)'" -Level Info
        

        
        # Preserve existing job files - only update if UI has valid non-placeholder values
        if (![string]::IsNullOrEmpty($chocoJobFile) -and $chocoJobFile -ne "Click Browse to select CSV file...") {
            Write-LogMessage "Theme switch - Updating Choco job file from UI: '$chocoJobFile'" -Level Info
            $script:Config.ChocoSettings.JobFile = $chocoJobFile
        } else {
            Write-LogMessage "Theme switch - Preserving existing Choco job file: '$($script:Config.ChocoSettings.JobFile)'" -Level Info
        }
        
        if (![string]::IsNullOrEmpty($wingetJobFile) -and $wingetJobFile -ne "Click Browse to select CSV file...") {
            Write-LogMessage "Theme switch - Updating Winget job file from UI: '$wingetJobFile'" -Level Info
            $script:Config.WingetSettings.JobFile = $wingetJobFile
        } else {
            Write-LogMessage "Theme switch - Preserving existing Winget job file: '$($script:Config.WingetSettings.JobFile)'" -Level Info
        }
        
        if (![string]::IsNullOrEmpty($wingetInstallerPath) -and $wingetInstallerPath -ne "PreReqs\Winget\winget-installer.ps1") {
            Write-LogMessage "Theme switch - Updating Winget installer path from UI: '$wingetInstallerPath'" -Level Info
            $script:Config.WingetSettings.InstallerPath = $wingetInstallerPath
        } else {
            Write-LogMessage "Theme switch - Preserving existing Winget installer path: '$($script:Config.WingetSettings.InstallerPath)'" -Level Info
        }
        
        # Save to file
        $configPath = Get-ConfigPath
        $script:Config | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Force
        
        Write-LogMessage "Theme switch - Config saved. Final values: Choco='$($script:Config.ChocoSettings.JobFile)', Winget='$($script:Config.WingetSettings.JobFile)'" -Level Info
        
        # Apply theme - use a completely different approach to avoid resource conflicts
        $script:WPFMainWindow.Dispatcher.Invoke([Action]{
            try {
                Write-LogMessage "DEBUG: Starting theme application, isDarkMode = $isDarkMode" -Level Info
                
                # Remove existing theme-related resources first to avoid conflicts
                $resourceKeysToRemove = @(
                    "PrimaryBackgroundBrush", "SecondaryBackgroundBrush", "PrimaryTextBrush", "SecondaryTextBrush",
                    "BorderBrush", "PrimaryButtonBrush", "PrimaryButtonHoverBrush", "PrimaryButtonPressedBrush",
                    "SecondaryButtonBrush", "SecondaryButtonHoverBrush",
                    "DarkPrimaryBackgroundBrush", "DarkSecondaryBackgroundBrush", "DarkPrimaryTextBrush", 
                    "DarkSecondaryTextBrush", "DarkBorderBrush", "DarkPrimaryButtonBrush", "DarkPrimaryButtonHoverBrush",
                    "DarkPrimaryButtonPressedBrush", "DarkSecondaryButtonBrush", "DarkSecondaryButtonHoverBrush"
                )
                
                foreach ($key in $resourceKeysToRemove) {
                    if ($script:WPFMainWindow.Resources.Contains($key)) {
                        $script:WPFMainWindow.Resources.Remove($key)
                    }
                }
                Write-LogMessage "DEBUG: Removed existing theme resources" -Level Info
                
                if ($isDarkMode) {
                    Write-LogMessage "DEBUG: Creating dark theme resources..." -Level Info
                    # Create completely new resource dictionary for dark theme
                    $darkThemeResources = @{
                        "PrimaryBackgroundBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(45, 45, 48))
                        "SecondaryBackgroundBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(63, 63, 70))
                        "PrimaryTextBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(255, 255, 255))
                        "SecondaryTextBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(204, 204, 204))
                        "BorderBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(85, 85, 85))
                        "PrimaryButtonBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(0, 120, 212))
                        "PrimaryButtonHoverBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(16, 110, 190))
                        "PrimaryButtonPressedBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(0, 90, 158))
                        "SecondaryButtonBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(107, 107, 107))
                        "SecondaryButtonHoverBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(90, 90, 90))
                    }
                    
                    foreach ($kvp in $darkThemeResources.GetEnumerator()) {
                        $script:WPFMainWindow.Resources.Add($kvp.Key, $kvp.Value)
                    }
                    Write-LogMessage "DEBUG: Dark theme resources created and added successfully" -Level Info
                }
                else {
                    Write-LogMessage "DEBUG: Creating light theme resources..." -Level Info
                    # Create completely new resource dictionary for light theme
                    $lightThemeResources = @{
                        "PrimaryBackgroundBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(245, 245, 245))
                        "SecondaryBackgroundBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(255, 255, 255))
                        "PrimaryTextBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(66, 66, 66))
                        "SecondaryTextBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(117, 117, 117))
                        "BorderBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(224, 224, 224))
                        "PrimaryButtonBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(33, 150, 243))
                        "PrimaryButtonHoverBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(25, 118, 210))
                        "PrimaryButtonPressedBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(13, 71, 161))
                        "SecondaryButtonBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(117, 117, 117))
                        "SecondaryButtonHoverBrush" = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(97, 97, 97))
                    }
                    
                    foreach ($kvp in $lightThemeResources.GetEnumerator()) {
                        $script:WPFMainWindow.Resources.Add($kvp.Key, $kvp.Value)
                    }
                    Write-LogMessage "DEBUG: Light theme resources created and added successfully" -Level Info
                }
                
                Write-LogMessage "DEBUG: About to force refresh..." -Level Info
                # Force refresh (simplified to avoid visual artifacts)
                $script:WPFMainWindow.InvalidateVisual()
                Write-LogMessage "DEBUG: Refresh completed successfully" -Level Info
            }
            catch {
                Write-LogMessage "DEBUG: Error in theme application dispatcher: $($_.Exception.Message)" -Level Error
                throw
            }
        })
        
        # Refresh UI controls with saved config values after theme change
        Write-LogMessage "Refreshing job file settings in UI..." -Level Info
        
        # Refresh Chocolatey job file setting
        $chocoJobFileTextBox = Find-Control "ChocoJobFileTextBox"
        if ($chocoJobFileTextBox) {
            if (![string]::IsNullOrWhiteSpace($script:Config.ChocoSettings.JobFile)) {
                $chocoJobFileTextBox.Text = $script:Config.ChocoSettings.JobFile
                $chocoJobFileTextBox.Foreground = $script:WPFMainWindow.Resources["PrimaryTextBrush"]
                Write-LogMessage "Refresh - Set Choco textbox to: '$($chocoJobFileTextBox.Text)'" -Level Info
            } else {
                $chocoJobFileTextBox.Text = "Click Browse to select CSV file..."
                $chocoJobFileTextBox.Foreground = $script:WPFMainWindow.Resources["SecondaryTextBrush"]
                Write-LogMessage "Refresh - Set Choco textbox to placeholder text" -Level Info
            }
        }
        
        # Refresh Winget job file setting
        $wingetJobFileTextBox = Find-Control "WingetJobFileTextBox"
        if ($wingetJobFileTextBox) {
            if (![string]::IsNullOrWhiteSpace($script:Config.WingetSettings.JobFile)) {
                $wingetJobFileTextBox.Text = $script:Config.WingetSettings.JobFile
                $wingetJobFileTextBox.Foreground = $script:WPFMainWindow.Resources["PrimaryTextBrush"]
                Write-LogMessage "Refresh - Set Winget textbox to: '$($wingetJobFileTextBox.Text)'" -Level Info
            } else {
                $wingetJobFileTextBox.Text = "Click Browse to select CSV file..."
                $wingetJobFileTextBox.Foreground = $script:WPFMainWindow.Resources["SecondaryTextBrush"]
                Write-LogMessage "Refresh - Set Winget textbox to placeholder text" -Level Info
            }
        }
        
        # Refresh Winget installer path setting
        $wingetInstallerTextBox = Find-Control "WingetInstallerTextBox"
        if ($wingetInstallerTextBox) {
            if (![string]::IsNullOrWhiteSpace($script:Config.WingetSettings.InstallerPath)) {
                $wingetInstallerTextBox.Text = $script:Config.WingetSettings.InstallerPath
                $wingetInstallerTextBox.Foreground = $script:WPFMainWindow.Resources["PrimaryTextBrush"]
                Write-LogMessage "Refresh - Set Winget installer textbox to: '$($wingetInstallerTextBox.Text)'" -Level Info
            } else {
                $wingetInstallerTextBox.Text = "PreReqs\Winget\winget-installer.ps1"
                $wingetInstallerTextBox.Foreground = $script:WPFMainWindow.Resources["PrimaryTextBrush"]
                Write-LogMessage "Refresh - Set Winget installer textbox to default path" -Level Info
            }
        }
        
        # Refresh Configuration Manager settings
        $cmServerTextBox = Find-Control "CMServerTextBox"
        if ($cmServerTextBox) {
            if (![string]::IsNullOrWhiteSpace($script:Config.CMSettings.SiteServer)) {
                $cmServerTextBox.Text = $script:Config.CMSettings.SiteServer
                Write-LogMessage "Refresh - Set CM Server textbox to: '$($cmServerTextBox.Text)'" -Level Info
            } else {
                $cmServerTextBox.Text = "CM01.contoso.com"
                Write-LogMessage "Refresh - Set CM Server textbox to placeholder text" -Level Info
            }
        }
        
        $cmSiteCodeTextBox = Find-Control "CMSiteCodeTextBox"
        if ($cmSiteCodeTextBox) {
            if (![string]::IsNullOrWhiteSpace($script:Config.CMSettings.SiteCode)) {
                $cmSiteCodeTextBox.Text = $script:Config.CMSettings.SiteCode
                Write-LogMessage "Refresh - Set CM SiteCode textbox to: '$($cmSiteCodeTextBox.Text)'" -Level Info
            } else {
                $cmSiteCodeTextBox.Text = "ABC"
                Write-LogMessage "Refresh - Set CM SiteCode textbox to placeholder text" -Level Info
            }
        }
        
        Write-LogMessage "UI settings refreshed successfully (job files and CM settings)" -Level Success
        Write-LogMessage "Theme toggled successfully" -Level Success
    }
    catch {
        Write-LogMessage "Failed to toggle theme: $($_.Exception.Message)" -Level Error
        throw
    }
}

