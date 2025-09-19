# Functions/WPF/Toggle-WPFConsole.ps1
# ========================================
# Function to toggle PowerShell console visibility in WPF

function Toggle-WPFConsole {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Toggling PowerShell console visibility..." -Level Info
        
        # Check if WPF window is available
        if (-not $script:WPFMainWindow) {
            Write-LogMessage "WPF window not available, using simple console toggle" -Level Info
            $result = Toggle-Console
            if ($result -eq "Visible") {
                Write-Host "Console debug enabled - PowerShell console is now visible" -ForegroundColor Green
            } elseif ($result -eq "Hidden") {
                Write-Host "Console debug disabled - PowerShell console is now hidden" -ForegroundColor Yellow
            }
            return
        }
        
        # Get the console debug checkbox
        $consoleDebugCheckBox = Find-Control -ControlName "ConsoleDebugCheckBox"
        
        if ($consoleDebugCheckBox) {
            # Toggle the checkbox state
            $consoleDebugCheckBox.IsChecked = -not $consoleDebugCheckBox.IsChecked
            
            # Update the configuration
            if (-not $script:Config) {
                Load-AllSettings
            }
            
            if (-not $script:Config.PSObject.Properties.Match('ConsoleDebug')) {
                $script:Config | Add-Member -MemberType NoteProperty -Name 'ConsoleDebug' -Value $false -Force
            }
            
            $script:Config.ConsoleDebug = $consoleDebugCheckBox.IsChecked
            
            # Save the configuration
            $configPath = Get-ConfigPath
            $configDir = Split-Path $configPath -Parent
            if (-not (Test-Path $configDir)) {
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            }
            $script:Config | ConvertTo-Json -Depth 10 | Out-File $configPath -Encoding UTF8
            
            # Toggle the actual console visibility
            $result = Toggle-Console
            
            if ($result -eq "Visible") {
                Write-LogMessage "Console debug enabled - PowerShell console is now visible" -Level Success
                [System.Windows.MessageBox]::Show(
                    "Console debug enabled!`n`nThe PowerShell console is now visible for debug information.`n`nThis is especially useful for monitoring Intune uploads and other operations that don't show detailed status in the GUI.", 
                    "Console Debug Enabled", 
                    [System.Windows.MessageBoxButton]::OK, 
                    [System.Windows.MessageBoxImage]::Information
                )
            } elseif ($result -eq "Hidden") {
                Write-LogMessage "Console debug disabled - PowerShell console is now hidden" -Level Success
                [System.Windows.MessageBox]::Show(
                    "Console debug disabled!`n`nThe PowerShell console is now hidden.`n`nDebug information will only be available in the log files.", 
                    "Console Debug Disabled", 
                    [System.Windows.MessageBoxButton]::OK, 
                    [System.Windows.MessageBoxImage]::Information
                )
            } else {
                Write-LogMessage "Error toggling console visibility" -Level Error
                [System.Windows.MessageBox]::Show(
                    "Error toggling console visibility. Please check the logs for more details.", 
                    "Error", 
                    [System.Windows.MessageBoxButton]::OK, 
                    [System.Windows.MessageBoxImage]::Error
                )
            }
        } else {
            Write-LogMessage "Console debug checkbox not found" -Level Error
            [System.Windows.MessageBox]::Show(
                "Console debug checkbox not found. Please restart the application.", 
                "Error", 
                [System.Windows.MessageBoxButton]::OK, 
                [System.Windows.MessageBoxImage]::Error
            )
        }
    }
    catch {
        Write-LogMessage "Error toggling WPF console: $($_.Exception.Message)" -Level Error
        [System.Windows.MessageBox]::Show(
            "Error toggling console: $($_.Exception.Message)", 
            "Error", 
            [System.Windows.MessageBoxButton]::OK, 
            [System.Windows.MessageBoxImage]::Error
        )
    }
}
