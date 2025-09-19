# File: WPF\Show-WPFFlexAppUpdateManager.ps1
# =============================================

# Import configuration functions if not already available
if (-not (Get-Command Load-AllSettings -ErrorAction SilentlyContinue)) {
    # Import configuration files
    $configPath = Join-Path (Split-Path -Parent $PSScriptRoot) "Config"
    if (Test-Path $configPath) {
        $configFiles = @(
            "Configuration.ps1",
            "Settings-Persistence.ps1",
            "Settings-Management.ps1"
        )
        
        foreach ($file in $configFiles) {
            $filePath = Join-Path $configPath $file
            if (Test-Path $filePath) {
                . $filePath
            }
        }
    }
}

# Define Get-ConfigPath function if not available
if (-not (Get-Command Get-ConfigPath -ErrorAction SilentlyContinue)) {
    function Get-ConfigPath {
        return "$env:APPDATA\LiquidwareSparks\FlexAppUpdateManager\config.json"
    }
}

# Helper function to find WPF controls by name
function Find-Control {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ControlName
    )
    
    if (-not $script:WPFMainWindow) {
        Write-LogMessage "WPF window not initialized" -Level Error
        return $null
    }
    
    $control = $script:WPFMainWindow.FindName($ControlName)
    if (-not $control) {
        # Only log warnings for controls that should exist (not removed status labels)
        $removedControls = @("ChocoStatusLabel", "WingetStatusLabel", "CMStatusLabel", "ChocoScanProgressBar", "WingetScanProgressBar", "PUDisconnectButton", "IntuneSourceFolderTextBox")
        if ($ControlName -notin $removedControls) {
            Write-LogMessage "Control '$ControlName' not found" -Level Warning
        }
    }
    return $control
}

function Show-FlexAppUpdateManager {
    [CmdletBinding()]
    param()
    
    # Initialize flag to track successful launch
    $script:WindowLaunchedSuccessfully = $false
    
    try {
        Write-LogMessage "Starting WPF FlexApp Update Manager..." -Level Info
        
        # Load required WPF assemblies
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName PresentationCore
        Add-Type -AssemblyName WindowsBase
        Add-Type -AssemblyName System.Xaml
        Add-Type -AssemblyName System.Windows.Forms
        
        # Get the path to the XAML file
        $scriptPath = $PSScriptRoot
        if (-not $scriptPath) {
            $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        if (-not $scriptPath) {
            # Fallback to current directory
            $scriptPath = Get-Location
        }
        $xamlPath = Join-Path $scriptPath "MainWindow.xaml"
        
        if (-not (Test-Path $xamlPath)) {
            throw "XAML file not found at: $xamlPath"
        }
        
        Write-LogMessage "Loading XAML from: $xamlPath" -Level Info
        
        # Load the XAML
        $xaml = Get-Content $xamlPath -Raw
        
        # Remove the x:Class directive to avoid type conflicts
        $xaml = $xaml -replace 'x:Class="[^"]*"', ''
        
        try {
            $xmlReader = [System.Xml.XmlNodeReader]::New([xml]$xaml)
            Write-LogMessage "XML reader created successfully" -Level Info
            
            $window = [System.Windows.Markup.XamlReader]::Load($xmlReader)
            Write-LogMessage "XAML loaded, window object: $($null -ne $window)" -Level Info
            
            if ($null -eq $window) {
                throw "Failed to load XAML window - XamlReader returned null"
            }
        }
        catch {
            Write-LogMessage "Error loading XAML: $($_.Exception.Message)" -Level Error
            Write-Host "XAML Loading Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
            Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
            throw
        }
        
        # Store the window in script scope
        $script:WPFMainWindow = $window
        
        Write-LogMessage "XAML loaded successfully, setting up event handlers..." -Level Info
        
        # Set up window state event handlers with restore logic
        $window.Add_StateChanged({
            param($sender, $e)
            Write-LogMessage "Window state changed to: $($sender.WindowState)" -Level Info
            
            # If window is minimized, ensure it can be restored
            if ($sender.WindowState -eq [System.Windows.WindowState]::Minimized) {
                Write-LogMessage "Window minimized - ensuring restore capability" -Level Info
                # Set a flag to track minimized state
                $script:WindowMinimized = $true
            } elseif ($sender.WindowState -eq [System.Windows.WindowState]::Normal) {
                Write-LogMessage "Window restored to normal" -Level Info
                $script:WindowMinimized = $false
            } elseif ($sender.WindowState -eq [System.Windows.WindowState]::Maximized) {
                Write-LogMessage "Window maximized" -Level Info
                $script:WindowMinimized = $false
            }
        })
        
        # Add window activated event with restore logic
        $window.Add_Activated({
            param($sender, $e)
            Write-LogMessage "Window activated" -Level Info
            
            # If window was minimized and is now being activated, restore it
            if ($script:WindowMinimized -and $sender.WindowState -eq [System.Windows.WindowState]::Minimized) {
                Write-LogMessage "Attempting to restore minimized window" -Level Info
                $sender.WindowState = [System.Windows.WindowState]::Normal
                $sender.Show()
                $sender.Activate()
            }
        })
        
        # Add window deactivated event (minimal)
        $window.Add_Deactivated({
            param($sender, $e)
            Write-LogMessage "Window deactivated" -Level Info
        })
        
        # Add window source initialized event (minimal)
        $window.Add_SourceInitialized({
            param($sender, $e)
            Write-LogMessage "Window source initialized" -Level Info
        })
        
        $window.Add_Closing({
            param($sender, $e)
            Write-LogMessage "Window is closing..." -Level Info
            $script:WindowClosed = $true
        })
        
        # Set up event handlers for all buttons and controls
        Setup-WPFEventHandlers
        
        # Verify window is still valid after event handlers
        if (-not $window) {
            throw "Window became null after setting up event handlers"
        }
        
        # Initialize the window with saved settings
        Initialize-WPFSettings
        
        # Verify window is still valid after initialization
        if (-not $window) {
            throw "Window became null after initializing settings"
        }
        
        # Apply saved theme
        if ($script:Config.DarkMode) {
            $darkModeRadio = Find-Control -ControlName "DarkModeRadio"
            $lightModeRadio = Find-Control -ControlName "LightModeRadio"
            if ($darkModeRadio -and $lightModeRadio) {
                $darkModeRadio.IsChecked = $true
                $lightModeRadio.IsChecked = $false
                Switch-WPFTheme
            }
        }
        
        Write-LogMessage "WPF window setup complete, showing dialog..." -Level Info
        
        # Final verification before showing dialog
        if (-not $window) {
            throw "Window became null after complete setup - cannot show dialog"
        }
        
        if (-not $script:WPFMainWindow) {
            throw "Script window variable became null - cannot show dialog"
        }
        
        # Show the window
        Write-LogMessage "Attempting to show window..." -Level Info
        Write-LogMessage "Window object type: $($window.GetType().FullName)" -Level Info
        Write-LogMessage "Window IsLoaded: $($window.IsLoaded)" -Level Info
        Write-LogMessage "Window IsVisible: $($window.IsVisible)" -Level Info
        
        # Set up window closed event to clean up timers and exit
        $window.Add_Closed({
            Write-LogMessage "Window closed - cleaning up timers..." -Level Info
            
            # Stop timers when window closes
            if ($script:CMButtonStateTimer) {
                $script:CMButtonStateTimer.Stop()
                $script:CMButtonStateTimer = $null
            }
            if ($script:PUButtonStateTimer) {
                $script:PUButtonStateTimer.Stop()
                $script:PUButtonStateTimer = $null
            }
            if ($script:WingetButtonStateTimer) {
                $script:WingetButtonStateTimer.Stop()
                $script:WingetButtonStateTimer = $null
            }
            if ($script:ChocoButtonStateTimer) {
                $script:ChocoButtonStateTimer.Stop()
                $script:ChocoButtonStateTimer = $null
            }
            
            # Signal that window is closed
            $script:WindowClosed = $true
            Write-LogMessage "Window and timers cleaned up successfully" -Level Info
            
            # Exit the PowerShell session when window closes
            Write-LogMessage "Exiting PowerShell session..." -Level Info
            exit
        })
        
        Write-LogMessage "Showing window..." -Level Info
        Write-Host "DEBUG: About to show window. Window is null: $($null -eq $window)" -ForegroundColor Cyan
        Write-Host "DEBUG: Window type: $($window.GetType().Name)" -ForegroundColor Cyan
        Write-Host "DEBUG: Script:WPFMainWindow is null: $($null -eq $script:WPFMainWindow)" -ForegroundColor Cyan
        
        # Show window
        if ($null -eq $window) {
            Write-Host "ERROR: Window is null, cannot show!" -ForegroundColor Red
            throw "Window object is null - cannot display GUI"
        }
        $window.Show()
        
        Write-LogMessage "Window displayed successfully. Use the interface and close the window when done." -Level Success
        Write-LogMessage "The PowerShell session will remain active to keep the window responsive." -Level Info
        
        # Set flag to prevent cleanup in finally block
        $script:WindowLaunchedSuccessfully = $true
        $script:WindowClosed = $false
        
        # Keep the session alive with a simple message pump
        while (-not $script:WindowClosed) {
            try {
                # Use WPF dispatcher instead of WinForms DoEvents
                [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
            }
            catch {
                # Fallback if dispatcher fails
                Start-Sleep -Milliseconds 50
            }
            Start-Sleep -Milliseconds 100
        }
        
        Write-LogMessage "Window session ended." -Level Info
    }
    catch {
        Write-LogMessage "WPF GUI initialization failed: $($_.Exception.Message)" -Level Error
        [System.Windows.MessageBox]::Show(
            "WPF GUI initialization failed: $($_.Exception.Message)", 
            "Error", 
            [System.Windows.MessageBoxButton]::OK, 
            [System.Windows.MessageBoxImage]::Error
        )
        throw
    }
    finally {
        # Only cleanup if the window wasn't launched successfully
        if (-not $script:WindowLaunchedSuccessfully) {
            Write-LogMessage "Cleaning up due to initialization failure..." -Level Info
            
            # Cleanup timers first
            if ($script:CMButtonStateTimer) {
                try {
                    $script:CMButtonStateTimer.Stop()
                    $script:CMButtonStateTimer = $null
                    Write-LogMessage "CM Button State Timer stopped during cleanup" -Level Info
                } catch {
                    Write-LogMessage "Error stopping CM Button State Timer during cleanup: $($_.Exception.Message)" -Level Warning
                }
            }
            
            if ($script:PUButtonStateTimer) {
                try {
                    $script:PUButtonStateTimer.Stop()
                    $script:PUButtonStateTimer = $null
                    Write-LogMessage "ProfileUnity Button State Timer stopped during cleanup" -Level Info
                } catch {
                    Write-LogMessage "Error stopping ProfileUnity Button State Timer during cleanup: $($_.Exception.Message)" -Level Warning
                }
            }
            
            if ($script:WingetButtonStateTimer) {
                try {
                    $script:WingetButtonStateTimer.Stop()
                    $script:WingetButtonStateTimer = $null
                    Write-LogMessage "Winget Button State Timer stopped during cleanup" -Level Info
                } catch {
                    Write-LogMessage "Error stopping Winget Button State Timer during cleanup: $($_.Exception.Message)" -Level Warning
                }
            }
            
            if ($script:ChocoButtonStateTimer) {
                try {
                    $script:ChocoButtonStateTimer.Stop()
                    $script:ChocoButtonStateTimer = $null
                    Write-LogMessage "Chocolatey Button State Timer stopped during cleanup" -Level Info
                } catch {
                    Write-LogMessage "Error stopping Chocolatey Button State Timer during cleanup: $($_.Exception.Message)" -Level Warning
                }
            }
            
            # Cleanup window
            if ($script:WPFMainWindow) {
                try {
                    $script:WPFMainWindow.Close()
                    Write-LogMessage "WPF window cleanup completed" -Level Info
                }
                catch {
                    Write-LogMessage "Error disposing WPF window: $($_.Exception.Message)" -Level Warning
                }
            }
            $script:WPFMainWindow = $null
        } else {
            Write-LogMessage "Window launched successfully - skipping cleanup to keep window alive" -Level Info
        }
    }
}

function Setup-WPFEventHandlers {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Setting up WPF event handlers..." -Level Info
        
        # Use the global Find-Control function defined at the top of the file
        
        # Chocolatey Tab Event Handlers
        $chocoJobFileBrowseButton = Find-Control -ControlName "ChocoJobFileBrowseButton"
        if ($chocoJobFileBrowseButton) {
            $chocoJobFileBrowseButton.Add_Click({
                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "CSV Files (*.csv)|*.csv"
                $openFileDialog.RestoreDirectory = $true
                if ($openFileDialog.ShowDialog() -eq $true) {
                    $chocoJobFileTextBox = Find-Control -ControlName "ChocoJobFileTextBox"
                    if ($chocoJobFileTextBox) {
                        $chocoJobFileTextBox.Text = $openFileDialog.FileName
                        # Use dynamic theme brush instead of hardcoded black
                        $chocoJobFileTextBox.Foreground = $script:WPFMainWindow.Resources["PrimaryTextBrush"]
                        Save-WPFChocoSettings
                    }
                }
            })
        }
        
        $chocoScanButton = Find-Control -ControlName "ChocoScanButton"
        if ($chocoScanButton) {
            $chocoScanButton.Add_Click({
                try {
                    Write-LogMessage "Chocolatey scan button clicked" -Level Info
                    Start-WPFChocoUpdateScan
                }
                catch {
                    Write-LogMessage "Error during Chocolatey scan: $($_.Exception.Message)" -Level Error
                    [System.Windows.MessageBox]::Show(
                        "Error during scan: $($_.Exception.Message)", 
                        "Scan Error", 
                        [System.Windows.MessageBoxButton]::OK, 
                        [System.Windows.MessageBoxImage]::Error
                    )
                }
            })
        }
        
        $chocoCancelScanButton = Find-Control -ControlName "ChocoCancelScanButton"
        if ($chocoCancelScanButton) {
            $chocoCancelScanButton.Add_Click({
                $script:ChocoScanCancelled = $true
                Write-LogMessage "Scan cancellation requested" -Level Warning -Tab "Chocolatey"
                Update-WPFChocoStatus -Message "Cancelling scan..." -Level Warning
                try {
                    $cancelButton = Find-Control -ControlName "ChocoCancelScanButton"
                    if ($cancelButton) {
                        $cancelButton.Visibility = [System.Windows.Visibility]::Collapsed
                    }
                } catch {
                    Write-LogMessage "Error hiding cancel button: $($_.Exception.Message)" -Level Warning -Tab "Chocolatey"
                }
            })
        }
        
        $chocoSelectAllButton = Find-Control -ControlName "ChocoSelectAllButton"
        if ($chocoSelectAllButton) {
            $chocoSelectAllButton.Add_Click({
                $chocoUpdatesGrid = Find-Control -ControlName "ChocoUpdatesGrid"
                if ($chocoUpdatesGrid -and $chocoUpdatesGrid.ItemsSource) {
                    foreach ($item in $chocoUpdatesGrid.ItemsSource) { $item.Selected = $true }
                    $chocoUpdatesGrid.Items.Refresh()
                }
            })
        }
        
        $chocoSelectNoneButton = Find-Control -ControlName "ChocoSelectNoneButton"
        if ($chocoSelectNoneButton) {
            $chocoSelectNoneButton.Add_Click({
                $chocoUpdatesGrid = Find-Control -ControlName "ChocoUpdatesGrid"
                if ($chocoUpdatesGrid -and $chocoUpdatesGrid.ItemsSource) {
                    foreach ($item in $chocoUpdatesGrid.ItemsSource) { $item.Selected = $false }
                    $chocoUpdatesGrid.Items.Refresh()
                }
            })
        }
        
        $chocoProcessButton = Find-Control -ControlName "ChocoProcessButton"
        if ($chocoProcessButton) {
            $chocoProcessButton.Add_Click({ Start-ChocoSelectedUpdates })
        }
        
        # Winget Tab Event Handlers
        $wingetJobFileBrowseButton = Find-Control -ControlName "WingetJobFileBrowseButton"
        if ($wingetJobFileBrowseButton) {
            $wingetJobFileBrowseButton.Add_Click({
                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "CSV Files (*.csv)|*.csv"
                $openFileDialog.RestoreDirectory = $true
                if ($openFileDialog.ShowDialog() -eq $true) {
                    $wingetJobFileTextBox = Find-Control -ControlName "WingetJobFileTextBox"
                    if ($wingetJobFileTextBox) {
                        $wingetJobFileTextBox.Text = $openFileDialog.FileName
                        # Use dynamic theme brush instead of hardcoded black
                        $wingetJobFileTextBox.Foreground = $script:WPFMainWindow.Resources["PrimaryTextBrush"]
                        Save-WPFWingetSettings
                    }
                }
            })
        }
        
        $wingetInstallerBrowseButton = Find-Control -ControlName "WingetInstallerBrowseButton"
        if ($wingetInstallerBrowseButton) {
            $wingetInstallerBrowseButton.Add_Click({
                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1"
                $openFileDialog.RestoreDirectory = $true
                $openFileDialog.Title = "Select Winget Installer Script"
                if ($openFileDialog.ShowDialog() -eq $true) {
                    $wingetInstallerTextBox = Find-Control -ControlName "WingetInstallerTextBox"
                    if ($wingetInstallerTextBox) {
                        $wingetInstallerTextBox.Text = $openFileDialog.FileName
                        # Use dynamic theme brush instead of hardcoded black
                        $wingetInstallerTextBox.Foreground = $script:WPFMainWindow.Resources["PrimaryTextBrush"]
                        Save-WPFWingetSettings
                    }
                }
            })
        }
        
        $wingetScanButton = Find-Control -ControlName "WingetScanButton"
        if ($wingetScanButton) {
            $wingetScanButton.Add_Click({
                try {
                    Write-LogMessage "Winget scan button clicked" -Level Info
                    Start-WPFWingetUpdateScan
                }
                catch {
                    Write-LogMessage "Error during Winget scan: $($_.Exception.Message)" -Level Error
                    [System.Windows.MessageBox]::Show(
                        "Error during scan: $($_.Exception.Message)", 
                        "Scan Error", 
                        [System.Windows.MessageBoxButton]::OK, 
                        [System.Windows.MessageBoxImage]::Error
                    )
                }
            })
        }
        
        $wingetCancelScanButton = Find-Control -ControlName "WingetCancelScanButton"
        if ($wingetCancelScanButton) {
            $wingetCancelScanButton.Add_Click({
                $script:WingetScanCancelled = $true
                Write-LogMessage "Winget scan cancellation requested" -Level Warning -Tab "Winget"
                Update-WPFWingetStatus -Message "Cancelling scan..." -Level Warning
                try {
                    $cancelButton = Find-Control -ControlName "WingetCancelScanButton"
                    if ($cancelButton) {
                        $cancelButton.Visibility = [System.Windows.Visibility]::Collapsed
                    }
                } catch {
                    Write-LogMessage "Error hiding Winget cancel button: $($_.Exception.Message)" -Level Warning -Tab "Winget"
                }
            })
        }
        
        $wingetSelectAllButton = Find-Control -ControlName "WingetSelectAllButton"
        if ($wingetSelectAllButton) {
            $wingetSelectAllButton.Add_Click({
                $wingetUpdatesGrid = Find-Control -ControlName "WingetUpdatesGrid"
                if ($wingetUpdatesGrid -and $wingetUpdatesGrid.ItemsSource) {
                    foreach ($item in $wingetUpdatesGrid.ItemsSource) { $item.Selected = $true }
                    $wingetUpdatesGrid.Items.Refresh()
                }
            })
        }
        
        $wingetSelectNoneButton = Find-Control -ControlName "WingetSelectNoneButton"
        if ($wingetSelectNoneButton) {
            $wingetSelectNoneButton.Add_Click({
                $wingetUpdatesGrid = Find-Control -ControlName "WingetUpdatesGrid"
                if ($wingetUpdatesGrid -and $wingetUpdatesGrid.ItemsSource) {
                    foreach ($item in $wingetUpdatesGrid.ItemsSource) { $item.Selected = $false }
                    $wingetUpdatesGrid.Items.Refresh()
                }
            })
        }
        
        $wingetProcessButton = Find-Control -ControlName "WingetProcessButton"
        if ($wingetProcessButton) {
            $wingetProcessButton.Add_Click({ Start-WingetSelectedUpdates })
        }
        
        # Configuration Manager Tab Event Handlers
        $cmConnectButton = Find-Control -ControlName "CMConnectButton"
        if ($cmConnectButton) {
            $cmConnectButton.Add_Click({
                try {
                    Connect-WPFConfigurationManager
                }
                catch {
                    Write-LogMessage "Error connecting to Configuration Manager: $($_.Exception.Message)" -Level Error
                    [System.Windows.MessageBox]::Show(
                        "Error connecting to Configuration Manager: $($_.Exception.Message)", 
                        "Connection Error", 
                        [System.Windows.MessageBoxButton]::OK, 
                        [System.Windows.MessageBoxImage]::Error
                    )
                }
            })
        }
        
        $cmDisconnectButton = Find-Control -ControlName "CMDisconnectButton"
        if ($cmDisconnectButton) {
            $cmDisconnectButton.Add_Click({ Disconnect-WPFConfigurationManager })
        }
        
        $cmSelectAllButton = Find-Control -ControlName "CMSelectAllButton"
        if ($cmSelectAllButton) {
            $cmSelectAllButton.Add_Click({
                $cmApplicationsGrid = Find-Control -ControlName "CMApplicationsGrid"
                if ($cmApplicationsGrid -and $cmApplicationsGrid.ItemsSource) {
                    foreach ($item in $cmApplicationsGrid.ItemsSource) { if ($item.PSObject.Properties.Name -contains 'Selected') { $item.Selected = $true } }
                    $cmApplicationsGrid.Items.Refresh()
                    # Update button states after selection change
                    Update-WPFCMButtonStates
                }
            })
        }
        
        $cmSelectNoneButton = Find-Control -ControlName "CMSelectNoneButton"
        if ($cmSelectNoneButton) {
            $cmSelectNoneButton.Add_Click({
                $cmApplicationsGrid = Find-Control -ControlName "CMApplicationsGrid"
                if ($cmApplicationsGrid -and $cmApplicationsGrid.ItemsSource) {
                    foreach ($item in $cmApplicationsGrid.ItemsSource) { if ($item.PSObject.Properties.Name -contains 'Selected') { $item.Selected = $false } }
                    $cmApplicationsGrid.Items.Refresh()
                    # Update button states after selection change
                    Update-WPFCMButtonStates
                }
            })
        }
        
        $cmProcessButton = Find-Control -ControlName "CMProcessButton"
        if ($cmProcessButton) {
            $cmProcessButton.Add_Click({ Start-WPFCMPackageUpdate })
        }
        

        
        # CM Text Box Event Handlers for persistence (using LostFocus instead of TextChanged to avoid crashes)
        $cmServerTextBox = Find-Control -ControlName "CMServerTextBox"
        if ($cmServerTextBox) {
            $cmServerTextBox.Add_LostFocus({
                try {
                    # Ensure Config exists first
                    if (-not $script:Config) {
                        Write-LogMessage "Config not initialized, skipping CM Site Server save" -Level Warning -Tab "Configuration Manager"
                        return
                    }
                    
                    $server = $cmServerTextBox.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($server)) {
                        # Ensure CMSettings exists before accessing it
                        if (-not $script:Config.CMSettings) {
                            Write-LogMessage "Initializing CMSettings object" -Level Info -Tab "Configuration Manager"
                            $script:Config.CMSettings = @{
                                SiteServer = ""
                                SiteCode = ""
                                OutputPath = "$env:USERPROFILE\Desktop\"
                            }
                        }
                        Write-LogMessage "About to set SiteServer: $server" -Level Info -Tab "Configuration Manager"
                        Write-LogMessage "CMSettings type: $($script:Config.CMSettings.GetType().FullName)" -Level Info -Tab "Configuration Manager"
                        Write-LogMessage "CMSettings properties: $($script:Config.CMSettings | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name)" -Level Info -Tab "Configuration Manager"
                        
                        $script:Config.CMSettings.SiteServer = $server
                        
                        Write-LogMessage "About to call Save-AllSettings with server: $server" -Level Info -Tab "Configuration Manager"
                        Save-AllSettings -CMSiteServer $server
                        Write-LogMessage "CM Site Server updated: $server" -Level Info -Tab "Configuration Manager"
                    }
                }
                catch {
                    # Suppress CM Site Server null reference errors as they don't affect functionality
                    # Only log other types of errors
                    if ($_.Exception.Message -notlike "*null-valued expression*") {
                        Write-LogMessage "Error saving CM Site Server: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
                    }
                }
            })
        }
        
        $cmSiteCodeTextBox = Find-Control -ControlName "CMSiteCodeTextBox"
        if ($cmSiteCodeTextBox) {
            $cmSiteCodeTextBox.Add_LostFocus({
                try {
                    # Ensure Config exists first
                    if (-not $script:Config) {
                        Write-LogMessage "Config not initialized, skipping CM Site Code save" -Level Warning -Tab "Configuration Manager"
                        return
                    }
                    
                    $siteCode = $cmSiteCodeTextBox.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($siteCode)) {
                        # Ensure CMSettings exists before accessing it
                        if (-not $script:Config.CMSettings) {
                            Write-LogMessage "Initializing CMSettings object" -Level Info -Tab "Configuration Manager"
                            $script:Config.CMSettings = @{
                                SiteServer = ""
                                SiteCode = ""
                                OutputPath = "$env:USERPROFILE\Desktop\"
                            }
                        }
                        $script:Config.CMSettings.SiteCode = $siteCode
                        Save-AllSettings -CMSiteCode $siteCode
                        Write-LogMessage "CM Site Code updated: $siteCode" -Level Info -Tab "Configuration Manager"
                    }
                }
                catch {
                    # Suppress CM Site Code null reference errors as they don't affect functionality
                    # Only log other types of errors
                    if ($_.Exception.Message -notlike "*null-valued expression*") {
                        Write-LogMessage "Error saving CM Site Code: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
                    }
                }
            })
        }
        
        # ProfileUnity Tab Event Handlers
        $puScanButton = Find-Control -ControlName "PUScanButton"
        if ($puScanButton) {
            $puScanButton.Add_Click({
                try {
                    Start-WPFProfileUnityScan
                }
                catch {
                    Write-LogMessage "Error during scan: $($_.Exception.Message)" -Level Error
                    [System.Windows.MessageBox]::Show(
                        "Error during scan: $($_.Exception.Message)", 
                        "Scan Error", 
                        [System.Windows.MessageBoxButton]::OK, 
                        [System.Windows.MessageBoxImage]::Error
                    )
                }
            })
        }
        
        $puDisconnectButton = Find-Control -ControlName "PUDisconnectButton"
        if ($puDisconnectButton) {
            $puDisconnectButton.Add_Click({
                try {
                    Disconnect-WPFProfileUnityServer
                }
                catch {
                    Write-LogMessage "Error disconnecting: $($_.Exception.Message)" -Level Error
                    [System.Windows.MessageBox]::Show(
                        "Error disconnecting: $($_.Exception.Message)", 
                        "Disconnect Error", 
                        [System.Windows.MessageBoxButton]::OK, 
                        [System.Windows.MessageBoxImage]::Error
                    )
                }
            })
        }
        
        # ProfileUnity Load Configurations button (server is read from Settings; no UI field)
        $puLoadConfigsButton = Find-Control -ControlName "PULoadConfigsButton"
        if ($puLoadConfigsButton) {
            $puLoadConfigsButton.Add_Click({
                try {
                    Import-WPFProfileUnityConfigurations
                }
                catch {
                    Write-LogMessage "Error loading configurations: $($_.Exception.Message)" -Level Error
                    [System.Windows.MessageBox]::Show(
                        "Error loading configurations: $($_.Exception.Message)", 
                        "Load Error", 
                        [System.Windows.MessageBoxButton]::OK, 
                        [System.Windows.MessageBoxImage]::Error
                    )
                }
            })
        }
        
        $puSelectAllButton = Find-Control -ControlName "PUSelectAllButton"
        if ($puSelectAllButton) {
            $puSelectAllButton.Add_Click({
                $puFlexAppsGrid = Find-Control -ControlName "PUFlexAppsGrid"
                if ($puFlexAppsGrid -and $puFlexAppsGrid.ItemsSource) {
                    foreach ($item in $puFlexAppsGrid.ItemsSource) {
                        $item.Selected = $true
                    }
                }
            })
        }
        
        $puSelectNoneButton = Find-Control -ControlName "PUSelectNoneButton"
        if ($puSelectNoneButton) {
            $puSelectNoneButton.Add_Click({
                $puFlexAppsGrid = Find-Control -ControlName "PUFlexAppsGrid"
                if ($puFlexAppsGrid -and $puFlexAppsGrid.ItemsSource) {
                    foreach ($item in $puFlexAppsGrid.ItemsSource) {
                        $item.Selected = $false
                    }
                }
            })
        }
        
        # Set up ProfileUnity event handlers
        try {
            Write-LogMessage "About to call Set-WPFProfileUnityEventHandlers..." -Level Info -Tab "ProfileUnity"
            Set-WPFProfileUnityEventHandlers
            Write-LogMessage "Set-WPFProfileUnityEventHandlers completed successfully" -Level Info -Tab "ProfileUnity"
        }
        catch {
            Write-LogMessage "Error calling Set-WPFProfileUnityEventHandlers: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        }
        
        # Set up Configuration Manager event handlers
        Set-WPFCMEventHandlers
        
        # Set up Winget event handlers
        Set-WPFWingetEventHandlers
        
        # Set up Chocolatey event handlers
        Set-WPFChocoEventHandlers
        
        $puProcessButton = Find-Control -ControlName "PUProcessButton"
        if ($puProcessButton) {
            $puProcessButton.Add_Click({ Process-SelectedFlexApps })
        }
        
        # Settings Tab Event Handlers
        $settingsTestConnectionButton = Find-Control -ControlName "SettingsTestConnectionButton"
        if ($settingsTestConnectionButton) {
            $settingsTestConnectionButton.Add_Click({ Test-GlobalSettings })
        }
        
        $settingsFlexAppClientBrowseButton = Find-Control -ControlName "SettingsFlexAppClientBrowseButton"
        if ($settingsFlexAppClientBrowseButton) {
            $settingsFlexAppClientBrowseButton.Add_Click({
                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "Executable Files (*.exe)|*.exe"
                $openFileDialog.Title = "Select FlexApp Client Executable"
                if ($openFileDialog.ShowDialog() -eq $true) {
                    $settingsFlexAppClientTextBox = Find-Control -ControlName "SettingsFlexAppClientTextBox"
                    if ($settingsFlexAppClientTextBox) {
                        $settingsFlexAppClientTextBox.Text = $openFileDialog.FileName
                    }
                }
            })
        }
        
        $settingsDefaultFileBrowseButton = Find-Control -ControlName "SettingsDefaultFileBrowseButton"
        if ($settingsDefaultFileBrowseButton) {
            $settingsDefaultFileBrowseButton.Add_Click({
                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "All Files (*.*)|*.*"
                $openFileDialog.Title = "Select Default File"
                if ($openFileDialog.ShowDialog() -eq $true) {
                    $settingsDefaultFileTextBox = Find-Control -ControlName "SettingsDefaultFileTextBox"
                    if ($settingsDefaultFileTextBox) {
                        $settingsDefaultFileTextBox.Text = $openFileDialog.FileName
                    }
                }
            })
        }
        
        $settingsPasswordFileBrowseButton = Find-Control -ControlName "SettingsPasswordFileBrowseButton"
        if ($settingsPasswordFileBrowseButton) {
            $settingsPasswordFileBrowseButton.Add_Click({
                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
                $openFileDialog.Title = "Select Password File"
                if ($openFileDialog.ShowDialog() -eq $true) {
                    $settingsPasswordFileTextBox = Find-Control -ControlName "SettingsPasswordFileTextBox"
                    if ($settingsPasswordFileTextBox) {
                        $settingsPasswordFileTextBox.Text = $openFileDialog.FileName
                    }
                }
            })
        }
        
        $settingsAESKeyFileBrowseButton = Find-Control -ControlName "SettingsAESKeyFileBrowseButton"
        if ($settingsAESKeyFileBrowseButton) {
            $settingsAESKeyFileBrowseButton.Add_Click({
                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
                $openFileDialog.Title = "Select AES Key File"
                if ($openFileDialog.ShowDialog() -eq $true) {
                    $settingsAESKeyFileTextBox = Find-Control -ControlName "SettingsAESKeyFileTextBox"
                    if ($settingsAESKeyFileTextBox) {
                        $settingsAESKeyFileTextBox.Text = $openFileDialog.FileName
                    }
                }
            })
        }
        
        $settingsTempPathBrowseButton = Find-Control -ControlName "SettingsTempPathBrowseButton"
        if ($settingsTempPathBrowseButton) {
            $settingsTempPathBrowseButton.Add_Click({
                $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
                $folderDialog.Description = "Select Temp Path"
                if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $settingsTempPathTextBox = Find-Control -ControlName "SettingsTempPathTextBox"
                    if ($settingsTempPathTextBox) {
                        $settingsTempPathTextBox.Text = $folderDialog.SelectedPath
                    }
                }
            })
        }
        
        $settingsSaveButton = Find-Control -ControlName "SettingsSaveButton"
        if ($settingsSaveButton) {
            $settingsSaveButton.Add_Click({ Save-WPFGlobalSettings })
        }
        
        # Reset to defaults button
        $settingsResetButton = Find-Control -ControlName "SettingsResetButton"
        if ($settingsResetButton) {
            $settingsResetButton.Add_Click({ 
                $result = [System.Windows.MessageBox]::Show("Are you sure you want to reset all settings to defaults?", "Confirm Reset", "YesNo", "Question")
                if ($result -eq "Yes") {
                    Reset-WPFGlobalSettings
                }
            })
        }
        
        # Cancel all & restart service button
        $settingsCancelRestartButton = Find-Control -ControlName "SettingsCancelRestartButton"
        if ($settingsCancelRestartButton) {
            $settingsCancelRestartButton.Add_Click({ Stop-WPFAllProcesses })
        }
        
        # Theme toggle button
        $settingsThemeToggleButton = Find-Control -ControlName "SettingsThemeToggleButton"
        if ($settingsThemeToggleButton) {
            $settingsThemeToggleButton.Add_Click({ Toggle-WPFTheme })
        }
        
        # Console toggle button
        $settingsConsoleToggleButton = Find-Control -ControlName "SettingsConsoleToggleButton"
        if ($settingsConsoleToggleButton) {
            $settingsConsoleToggleButton.Add_Click({ Toggle-WPFConsole })
        }
        
        # ===== INTUNE TAB EVENT HANDLERS =====
        
        # Intune source folder browse button
        $intuneSourceFolderBrowseButton = Find-Control -ControlName "IntuneSourceFolderBrowseButton"
        if ($intuneSourceFolderBrowseButton) {
            $intuneSourceFolderBrowseButton.Add_Click({
                $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
                $folderDialog.Description = "Select Source Folder"
                $folderDialog.ShowNewFolderButton = $true
                
                if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $intuneSourceFolderTextBox = Find-Control -ControlName "IntuneSourceFolderTextBox"
                    if ($intuneSourceFolderTextBox) {
                        $intuneSourceFolderTextBox.Text = $folderDialog.SelectedPath
                    }
                }
            })
        }
        
        # Intune output folder browse button
        $intuneOutputFolderBrowseButton = Find-Control -ControlName "IntuneOutputFolderBrowseButton"
        if ($intuneOutputFolderBrowseButton) {
            $intuneOutputFolderBrowseButton.Add_Click({
                $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
                $folderDialog.Description = "Select Output Folder"
                $folderDialog.ShowNewFolderButton = $true
                
                if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $intuneOutputFolderTextBox = Find-Control -ControlName "IntuneOutputFolderTextBox"
                    if ($intuneOutputFolderTextBox) {
                        $intuneOutputFolderTextBox.Text = $folderDialog.SelectedPath
                    }
                }
            })
        }
        
        # Intune tool path browse button
        $intuneToolPathBrowseButton = Find-Control -ControlName "IntuneToolPathBrowseButton"
        if ($intuneToolPathBrowseButton) {
            $intuneToolPathBrowseButton.Add_Click({
                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "Executable Files (*.exe)|*.exe"
                $openFileDialog.Title = "Select IntuneWinAppUtil.exe"
                
                if ($openFileDialog.ShowDialog() -eq $true) {
                    $intuneToolPathTextBox = Find-Control -ControlName "IntuneToolPathTextBox"
                    if ($intuneToolPathTextBox) {
                        $intuneToolPathTextBox.Text = $openFileDialog.FileName
                    }
                }
            })
        }
        
        # Intune test connection button
        $intuneTestConnectionButton = Find-Control -ControlName "IntuneTestConnectionButton"
        if ($intuneTestConnectionButton) {
            Write-LogMessage "Setting up Intune Test Connection button event handler" -Level Info -Tab "Intune"
            $intuneTestConnectionButton.Add_Click({
                try {
                    Write-LogMessage "Intune Test Connection button clicked" -Level Info -Tab "Intune"
                    if (Get-Command Test-WPFIntuneConnection -ErrorAction SilentlyContinue) {
                        Test-WPFIntuneConnection
                    } else {
                        Write-LogMessage "Test-WPFIntuneConnection function not found" -Level Error -Tab "Intune"
                        [System.Windows.MessageBox]::Show("Test-WPFIntuneConnection function not found. Please check module loading.", "Error", "OK", "Error")
                    }
                }
                catch {
                    Write-LogMessage "Error in Intune Test Connection button click: $($_.Exception.Message)" -Level Error -Tab "Intune"
                    [System.Windows.MessageBox]::Show("Error testing connection: $($_.Exception.Message)", "Error", "OK", "Error")
                }
            })
        } else {
            Write-LogMessage "Intune Test Connection button not found" -Level Warning -Tab "Intune"
        }
        
        # Intune start upload button
        $intuneStartUploadButton = Find-Control -ControlName "IntuneStartUploadButton"
        if ($intuneStartUploadButton) {
            Write-LogMessage "Setting up Intune Start Upload button event handler" -Level Info -Tab "Intune"
            $intuneStartUploadButton.Add_Click({
                try {
                    Write-LogMessage "Intune Start Upload button clicked" -Level Info -Tab "Intune"
                    if (Get-Command Start-WPFIntuneUpload -ErrorAction SilentlyContinue) {
                        Start-WPFIntuneUpload
                    } else {
                        Write-LogMessage "Start-WPFIntuneUpload function not found" -Level Error -Tab "Intune"
                        [System.Windows.MessageBox]::Show("Start-WPFIntuneUpload function not found. Please check module loading.", "Error", "OK", "Error")
                    }
                }
                catch {
                    Write-LogMessage "Error in Intune Start Upload button click: $($_.Exception.Message)" -Level Error -Tab "Intune"
                    [System.Windows.MessageBox]::Show("Error starting upload: $($_.Exception.Message)", "Error", "OK", "Error")
                }
            })
        } else {
            Write-LogMessage "Intune Start Upload button not found" -Level Warning -Tab "Intune"
        }
        
        # Intune stop upload button
        $intuneStopUploadButton = Find-Control -ControlName "IntuneStopUploadButton"
        if ($intuneStopUploadButton) {
            $intuneStopUploadButton.Add_Click({ Stop-WPFIntuneUpload })
        }
        
        # Intune refresh button
        $intuneRefreshButton = Find-Control -ControlName "IntuneRefreshButton"
        if ($intuneRefreshButton) {
            Write-LogMessage "Setting up Intune Refresh button event handler" -Level Info -Tab "Intune"
            $intuneRefreshButton.Add_Click({
                try {
                    Write-LogMessage "Intune Refresh button clicked" -Level Info -Tab "Intune"
                    if (Get-Command Load-WPFIntuneSettings -ErrorAction SilentlyContinue) {
                        Load-WPFIntuneSettings
                    } else {
                        Write-LogMessage "Load-WPFIntuneSettings function not found" -Level Error -Tab "Intune"
                    }
                }
                catch {
                    Write-LogMessage "Error in Intune Refresh button click: $($_.Exception.Message)" -Level Error -Tab "Intune"
                }
            })
        } else {
            Write-LogMessage "Intune Refresh button not found" -Level Warning -Tab "Intune"
        }
        
        
        # Try to load Intune settings immediately after GUI setup
        Write-LogMessage "Attempting to load Intune settings during GUI initialization..." -Level Info -Tab "Intune"
        try {
            if (Get-Command Load-WPFIntuneSettings -ErrorAction SilentlyContinue) {
                Write-Host "=== LOADING INTUNE SETTINGS DURING INIT ===" -ForegroundColor Cyan
                Load-WPFIntuneSettings
            } else {
                Write-LogMessage "Load-WPFIntuneSettings function not available during init" -Level Warning -Tab "Intune"
            }
        } catch {
            Write-LogMessage "Error loading Intune settings during init: $($_.Exception.Message)" -Level Warning -Tab "Intune"
            Write-Host "Error loading Intune settings during init: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Intune tab selection event to load settings when first accessed
        $mainTabControl = Find-Control -ControlName "MainTabControl"
        if ($mainTabControl) {
            Write-LogMessage "Setting up Intune tab selection event handler" -Level Info -Tab "Intune"
            $mainTabControl.Add_SelectionChanged({
                # Skip during initialization
                if (-not $script:WindowLaunchedSuccessfully) {
                    Write-Host "Skipping tab selection during initialization" -ForegroundColor Gray
                    return
                }
                
                $selectedTab = $mainTabControl.SelectedItem
                Write-Host "=== TAB SELECTION DEBUG ===" -ForegroundColor Magenta
                Write-Host "Selected tab object: $selectedTab" -ForegroundColor Yellow
                if ($selectedTab) {
                    Write-Host "Selected tab type: $($selectedTab.GetType().Name)" -ForegroundColor Yellow
                    Write-Host "Selected tab Name property: '$($selectedTab.Name)'" -ForegroundColor Yellow
                    Write-Host "Selected tab Header property: '$($selectedTab.Header)'" -ForegroundColor Yellow
                }
                
                Write-LogMessage "Tab selection changed. Selected tab: $($selectedTab.Name)" -Level Info -Tab "Intune"
                
                # Try both Name and Header properties
                $isIntuneTab = ($selectedTab.Name -eq "IntuneTab") -or ($selectedTab.Header -eq "Intune Upload")
                
                if ($selectedTab -and $isIntuneTab) {
                    Write-LogMessage "Intune tab selected, loading settings..." -Level Info -Tab "Intune"
                    Write-Host "Intune tab detected, calling Load-WPFIntuneSettings..." -ForegroundColor Green
                    if (Get-Command Load-WPFIntuneSettings -ErrorAction SilentlyContinue) {
                        Load-WPFIntuneSettings
                    } else {
                        Write-LogMessage "Load-WPFIntuneSettings function not found" -Level Error -Tab "Intune"
                    }
                } else {
                    Write-Host "Not Intune tab, skipping..." -ForegroundColor Gray
                }
            })
        } else {
            Write-LogMessage "MainTabControl not found" -Level Warning -Tab "Intune"
        }
        
        # Intune auto-save event handlers
        $intuneClientIdTextBox = Find-Control -ControlName "IntuneClientIdTextBox"
        if ($intuneClientIdTextBox) {
            $intuneClientIdTextBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { 
                        Write-Host "Config is null, cannot save Intune Client ID" -ForegroundColor Red
                        return 
                    }
                    $control = Find-Control -ControlName "IntuneClientIdTextBox"
                    if (-not $control) {
                        Write-Host "IntuneClientIdTextBox control not found" -ForegroundColor Red
                        return
                    }
                    $value = $control.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        Write-Host "Attempting to save Intune Client ID: $value" -ForegroundColor Green
                        Save-AllSettings -IntuneClientId $value
                        Write-LogMessage "Intune Client ID auto-saved: $value" -Level Info -Tab "Intune"
                    }
                } catch {
                    Write-Host "Error auto-saving Intune Client ID: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
                    Write-LogMessage "Error auto-saving Intune Client ID: $($_.Exception.Message)" -Level Warning -Tab "Intune"
                }
            })
        }
        
        $intuneTenantIdTextBox = Find-Control -ControlName "IntuneTenantIdTextBox"
        if ($intuneTenantIdTextBox) {
            $intuneTenantIdTextBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { return }
                    $value = $intuneTenantIdTextBox.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        Save-AllSettings -IntuneTenantId $value
                        Write-LogMessage "Intune Tenant ID auto-saved: $value" -Level Info -Tab "Intune"
                    }
                } catch {
                    Write-LogMessage "Error auto-saving Intune Tenant ID: $($_.Exception.Message)" -Level Warning -Tab "Intune"
                }
            })
        }
        
        $intuneClientSecretPasswordBox = Find-Control -ControlName "IntuneClientSecretPasswordBox"
        if ($intuneClientSecretPasswordBox) {
            $intuneClientSecretPasswordBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { return }
                    $value = $intuneClientSecretPasswordBox.Password
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        Save-AllSettings -IntuneClientSecret $value
                        Write-LogMessage "Intune Client Secret auto-saved (encrypted)" -Level Info -Tab "Intune"
                    }
                } catch {
                    Write-LogMessage "Error auto-saving Intune Client Secret: $($_.Exception.Message)" -Level Warning -Tab "Intune"
                }
            })
        }
        
        # IntuneSourceFolderTextBox auto-save setup removed - control not found reliably
        
        $intuneOutputFolderTextBox = Find-Control -ControlName "IntuneOutputFolderTextBox"
        if ($intuneOutputFolderTextBox) {
            $intuneOutputFolderTextBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { return }
                    $value = $intuneOutputFolderTextBox.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        Save-AllSettings -IntuneOutputFolder $value
                        Write-LogMessage "Intune Output Folder auto-saved: $value" -Level Info -Tab "Intune"
                    }
                } catch {
                    Write-LogMessage "Error auto-saving Intune Output Folder: $($_.Exception.Message)" -Level Warning -Tab "Intune"
                }
            })
        }
        
        $intuneToolPathTextBox = Find-Control -ControlName "IntuneToolPathTextBox"
        if ($intuneToolPathTextBox) {
            $intuneToolPathTextBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { return }
                    $value = $intuneToolPathTextBox.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        Save-AllSettings -IntuneToolPath $value
                        Write-LogMessage "Intune Tool Path auto-saved: $value" -Level Info -Tab "Intune"
                    }
                } catch {
                    Write-LogMessage "Error auto-saving Intune Tool Path: $($_.Exception.Message)" -Level Warning -Tab "Intune"
                }
            })
        }
        
        $intunePublisherTextBox = Find-Control -ControlName "IntunePublisherTextBox"
        if ($intunePublisherTextBox) {
            $intunePublisherTextBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { return }
                    $control = Find-Control -ControlName "IntunePublisherTextBox"
                    if (-not $control) { return }
                    $value = $control.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        Save-AllSettings -IntunePublisher $value
                        Write-LogMessage "Intune Publisher auto-saved: $value" -Level Info -Tab "Intune"
                    }
                } catch {
                    Write-LogMessage "Error auto-saving Intune Publisher: $($_.Exception.Message)" -Level Warning -Tab "Intune"
                }
            })
        }
        
        $intuneDependencyTextBox = Find-Control -ControlName "IntuneDependencyTextBox"
        if ($intuneDependencyTextBox) {
            $intuneDependencyTextBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { return }
                    $value = $intuneDependencyTextBox.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        Save-AllSettings -IntuneDependencyAppId $value
                        Write-LogMessage "Intune Dependency App ID auto-saved: $value" -Level Info -Tab "Intune"
                    }
                } catch {
                    Write-LogMessage "Error auto-saving Intune Dependency App ID: $($_.Exception.Message)" -Level Warning -Tab "Intune"
                }
            })
        }
        
        # Window closing event
        $script:WPFMainWindow.Add_Closing({
            param($windowSender, $e)
            try {
                # Cleanup background jobs
                if ($script:ChocoBackgroundJob -and $script:ChocoBackgroundJob.State -eq "Running") {
                    Stop-Job -Job $script:ChocoBackgroundJob -ErrorAction SilentlyContinue
                    Remove-Job -Job $script:ChocoBackgroundJob -Force -ErrorAction SilentlyContinue
                }
                
                if ($script:ChocoJobTimer) {
                    $script:ChocoJobTimer.Stop()
                    # DispatcherTimer doesn't have Dispose() method
                    $script:ChocoJobTimer = $null
                }
                
                if ($script:WingetBackgroundJob -and $script:WingetBackgroundJob.State -eq "Running") {
                    Stop-Job -Job $script:WingetBackgroundJob -ErrorAction SilentlyContinue
                    Remove-Job -Job $script:WingetBackgroundJob -Force -ErrorAction SilentlyContinue
                }

                if ($script:WingetJobTimer) {
                    $script:WingetJobTimer.Stop()
                    # DispatcherTimer doesn't have Dispose() method
                    $script:WingetJobTimer = $null
                }
                
                # Cleanup Configuration Manager connection
                if ($global:CMConnected) {
                    try {
                        Set-Location $env:SystemDrive
                        $cmSiteCodeTextBox = Find-Control -ControlName "CMSiteCodeTextBox"
                        if ($cmSiteCodeTextBox -and (Get-PSDrive -Name $cmSiteCodeTextBox.Text -ErrorAction SilentlyContinue)) {
                            Remove-PSDrive -Name $cmSiteCodeTextBox.Text -Force
                        }
                    }
                    catch { }
                }
                
                Write-LogMessage "WPF window cleanup completed" -Level Info
            }
            catch {
                Write-LogMessage "Error during WPF window cleanup: $($_.Exception.Message)" -Level Error
            }
        })
        
        Write-LogMessage "WPF event handlers setup complete" -Level Info
    }
    catch {
        Write-LogMessage "Error setting up WPF event handlers: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Initialize-WPFSettings {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Initializing WPF settings..." -Level Info
        
        # Ensure configuration is loaded
        if (-not $script:Config) {
            Write-LogMessage "Configuration not loaded, loading now..." -Level Info
            Load-AllSettings
        }
        
        # Use the global Find-Control function defined at the top of the file
        
        # Load Chocolatey settings - no default path, user must specify
        $chocoJobFileTextBox = Find-Control -ControlName "ChocoJobFileTextBox"
        if ($chocoJobFileTextBox) {
            Write-LogMessage "UI Init - Reading Choco job file from config: '$($script:Config.ChocoSettings.JobFile)'" -Level Info
            if (![string]::IsNullOrWhiteSpace($script:Config.ChocoSettings.JobFile)) {
                $chocoJobFileTextBox.Text = $script:Config.ChocoSettings.JobFile
                # Use proper theme color for file path
                $chocoJobFileTextBox.Foreground = $script:WPFMainWindow.Resources["PrimaryTextBrush"]
                Write-LogMessage "UI Init - Set Choco textbox to: '$($chocoJobFileTextBox.Text)'" -Level Info
            } else {
                $chocoJobFileTextBox.Text = "Click Browse to select CSV file..."
                # Use secondary text color for placeholder text (respects theme)
                $chocoJobFileTextBox.Foreground = $script:WPFMainWindow.Resources["SecondaryTextBrush"]
                Write-LogMessage "UI Init - Set Choco textbox to placeholder text" -Level Info
            }
        }
        
        # Load Winget settings - no default path, user must specify
        $wingetJobFileTextBox = Find-Control -ControlName "WingetJobFileTextBox"
        if ($wingetJobFileTextBox) {
            Write-LogMessage "UI Init - Reading Winget job file from config: '$($script:Config.WingetSettings.JobFile)'" -Level Info
            if (![string]::IsNullOrWhiteSpace($script:Config.WingetSettings.JobFile)) {
                $wingetJobFileTextBox.Text = $script:Config.WingetSettings.JobFile
                # Use proper theme color for file path
                $wingetJobFileTextBox.Foreground = $script:WPFMainWindow.Resources["PrimaryTextBrush"]
                Write-LogMessage "UI Init - Set Winget textbox to: '$($wingetJobFileTextBox.Text)'" -Level Info
            } else {
                $wingetJobFileTextBox.Text = "Click Browse to select CSV file..."
                # Use secondary text color for placeholder text (respects theme)
                $wingetJobFileTextBox.Foreground = $script:WPFMainWindow.Resources["SecondaryTextBrush"]
                Write-LogMessage "UI Init - Set Winget textbox to placeholder text" -Level Info
            }
        }
        
        # Intune settings will be loaded when the tab is first accessed
        
        # Load Settings tab values and add LostFocus event handlers for auto-save
        $settingsServerTextBox = Find-Control -ControlName "SettingsServerTextBox"
        if ($settingsServerTextBox) {
            $settingsServerTextBox.Text = $script:Config.ServerName
            $settingsServerTextBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { return }
                    $value = $settingsServerTextBox.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        $script:Config.ServerName = $value
                        Save-AllSettings -ServerName $value
                        Write-LogMessage "Server Name auto-saved: $value" -Level Info -Tab "Settings"
                    }
                } catch {
                    Write-LogMessage "Error auto-saving Server Name: $($_.Exception.Message)" -Level Warning -Tab "Settings"
                }
            })
        }
        
        $settingsServerPortTextBox = Find-Control -ControlName "SettingsServerPortTextBox"
        if ($settingsServerPortTextBox) {
            $settingsServerPortTextBox.Text = $script:Config.ServerPort
            $settingsServerPortTextBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { return }
                    $value = $settingsServerPortTextBox.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        $script:Config.ServerPort = $value
                        Save-AllSettings -ServerPort $value
                        Write-LogMessage "Server Port auto-saved: $value" -Level Info -Tab "Settings"
                    }
                } catch {
                    Write-LogMessage "Error auto-saving Server Port: $($_.Exception.Message)" -Level Warning -Tab "Settings"
                }
            })
        }
        
        $settingsAdminUserTextBox = Find-Control -ControlName "SettingsAdminUserTextBox"
        if ($settingsAdminUserTextBox) {
            $settingsAdminUserTextBox.Text = $script:Config.AdminUser
            $settingsAdminUserTextBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { return }
                    $value = $settingsAdminUserTextBox.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        $script:Config.AdminUser = $value
                        Save-AllSettings -AdminUser $value
                        Write-LogMessage "Admin User auto-saved: $value" -Level Info -Tab "Settings"
                    }
                } catch {
                    Write-LogMessage "Error auto-saving Admin User: $($_.Exception.Message)" -Level Warning -Tab "Settings"
                }
            })
        }
        
        $settingsFlexAppClientTextBox = Find-Control -ControlName "SettingsFlexAppClientTextBox"
        if ($settingsFlexAppClientTextBox) {
            $settingsFlexAppClientTextBox.Text = $script:Config.FlexAppClient
            $settingsFlexAppClientTextBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { return }
                    $value = $settingsFlexAppClientTextBox.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        $script:Config.FlexAppClient = $value
                        Save-AllSettings -FlexAppClient $value
                        Write-LogMessage "FlexApp Client auto-saved: $value" -Level Info -Tab "Settings"
                    }
                } catch {
                    Write-LogMessage "Error auto-saving FlexApp Client: $($_.Exception.Message)" -Level Warning -Tab "Settings"
                }
            })
        }
        
        $settingsPasswordFileTextBox = Find-Control -ControlName "SettingsPasswordFileTextBox"
        if ($settingsPasswordFileTextBox) {
            $settingsPasswordFileTextBox.Text = $script:Config.PasswordFile
            $settingsPasswordFileTextBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { return }
                    $value = $settingsPasswordFileTextBox.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        $script:Config.PasswordFile = $value
                        Save-AllSettings -PasswordFile $value
                        Write-LogMessage "Password File auto-saved: $value" -Level Info -Tab "Settings"
                    }
                } catch {
                    Write-LogMessage "Error auto-saving Password File: $($_.Exception.Message)" -Level Warning -Tab "Settings"
                }
            })
        }
        
        $settingsAESKeyFileTextBox = Find-Control -ControlName "SettingsAESKeyFileTextBox"
        if ($settingsAESKeyFileTextBox) {
            $settingsAESKeyFileTextBox.Text = $script:Config.AESKeyFile
            $settingsAESKeyFileTextBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { return }
                    $value = $settingsAESKeyFileTextBox.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        $script:Config.AESKeyFile = $value
                        Save-AllSettings -AESKeyFile $value
                        Write-LogMessage "AES Key File auto-saved: $value" -Level Info -Tab "Settings"
                    }
                } catch {
                    Write-LogMessage "Error auto-saving AES Key File: $($_.Exception.Message)" -Level Warning -Tab "Settings"
                }
            })
        }
        
        $settingsTempPathTextBox = Find-Control -ControlName "SettingsTempPathTextBox"
        if ($settingsTempPathTextBox) {
            $settingsTempPathTextBox.Text = $script:Config.TempPath
            $settingsTempPathTextBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { return }
                    $value = $settingsTempPathTextBox.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        $script:Config.TempPath = $value
                        Save-AllSettings -TempPath $value
                        Write-LogMessage "Temp Path auto-saved: $value" -Level Info -Tab "Settings"
                    }
                } catch {
                    Write-LogMessage "Error auto-saving Temp Path: $($_.Exception.Message)" -Level Warning -Tab "Settings"
                }
            })
        }
        
        $settingsDefaultFileTextBox = Find-Control -ControlName "SettingsDefaultFileTextBox"
        if ($settingsDefaultFileTextBox) {
            $settingsDefaultFileTextBox.Text = $script:Config.DefaultFile
            $settingsDefaultFileTextBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { return }
                    $value = $settingsDefaultFileTextBox.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        $script:Config.DefaultFile = $value
                        Save-AllSettings -DefaultFile $value
                        Write-LogMessage "Default File auto-saved: $value" -Level Info -Tab "Settings"
                    }
                } catch {
                    Write-LogMessage "Error auto-saving Default File: $($_.Exception.Message)" -Level Warning -Tab "Settings"
                }
            })
        }
        
        $settingsPrimaryServerTextBox = Find-Control -ControlName "SettingsPrimaryServerTextBox"
        if ($settingsPrimaryServerTextBox) {
            $settingsPrimaryServerTextBox.Text = $script:Config.PrimaryServer
            $settingsPrimaryServerTextBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { return }
                    $value = $settingsPrimaryServerTextBox.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        $script:Config.PrimaryServer = $value
                        Save-AllSettings -PrimaryServer $value
                        Write-LogMessage "Primary Server auto-saved: $value" -Level Info -Tab "Settings"
                    }
                } catch {
                    Write-LogMessage "Error auto-saving Primary Server: $($_.Exception.Message)" -Level Warning -Tab "Settings"
                }
            })
        }
        
        $settingsProcessWaitTextBox = Find-Control -ControlName "SettingsProcessWaitTextBox"
        if ($settingsProcessWaitTextBox) {
            $settingsProcessWaitTextBox.Text = $script:Config.ProcessWaitTime
            $settingsProcessWaitTextBox.Add_LostFocus({
                try {
                    if (-not $script:Config) { return }
                    $value = $settingsProcessWaitTextBox.Text.Trim()
                    if (![string]::IsNullOrWhiteSpace($value)) {
                        try {
                            $intValue = [int]$value
                            $script:Config.ProcessWaitTime = $intValue
                            Save-AllSettings -ProcessWaitTime $intValue
                            Write-LogMessage "Process Wait Time auto-saved: $intValue" -Level Info -Tab "Settings"
                        } catch {
                            Write-LogMessage "Invalid Process Wait Time value: $value" -Level Warning -Tab "Settings"
                        }
                    }
                } catch {
                    Write-LogMessage "Error auto-saving Process Wait Time: $($_.Exception.Message)" -Level Warning -Tab "Settings"
                }
            })
        }
        
        # Load Configuration Manager settings
        # Ensure CMSettings exists before accessing it
        if (-not $script:Config.CMSettings) {
            $script:Config.CMSettings = @{
                SiteServer = ""
                SiteCode = ""
                OutputPath = "$env:USERPROFILE\Desktop\"
            }
        }
        
        $cmServerTextBox = Find-Control -ControlName "CMServerTextBox"
        if ($cmServerTextBox) {
            if (![string]::IsNullOrWhiteSpace($script:Config.CMSettings.SiteServer)) {
                $cmServerTextBox.Text = $script:Config.CMSettings.SiteServer
            } else {
                $cmServerTextBox.Text = "CM01.contoso.com"
            }
        }
        
        $cmSiteCodeTextBox = Find-Control -ControlName "CMSiteCodeTextBox"
        if ($cmSiteCodeTextBox) {
            if (![string]::IsNullOrWhiteSpace($script:Config.CMSettings.SiteCode)) {
                $cmSiteCodeTextBox.Text = $script:Config.CMSettings.SiteCode
            } else {
                $cmSiteCodeTextBox.Text = "ABC"
            }
        }
        

        
        # Initialize theme settings
        $lightModeRadio = Find-Control -ControlName "LightModeRadio"
        $darkModeRadio = Find-Control -ControlName "DarkModeRadio"
        if ($lightModeRadio -and $darkModeRadio) {
            # Ensure configuration is loaded
            if (-not $script:Config) {
                Write-LogMessage "Configuration not loaded, loading now..." -Level Info
                Load-AllSettings
            }
            
            # Ensure the DarkMode property exists
            if (-not $script:Config.PSObject.Properties.Match('DarkMode')) {
                $script:Config | Add-Member -MemberType NoteProperty -Name 'DarkMode' -Value $false -Force
            }
            if ($script:Config.DarkMode -eq $true) {
                $darkModeRadio.IsChecked = $true
                $lightModeRadio.IsChecked = $false
            } else {
                $lightModeRadio.IsChecked = $true
                $darkModeRadio.IsChecked = $false
            }
        }
        
        # Initialize console debug settings
        $consoleDebugCheckBox = Find-Control -ControlName "ConsoleDebugCheckBox"
        if ($consoleDebugCheckBox) {
            # Ensure configuration is loaded
            if (-not $script:Config) {
                Write-LogMessage "Configuration not loaded, loading now..." -Level Info
                Load-AllSettings
            }
            
            # Ensure the ConsoleDebug property exists
            if (-not $script:Config.PSObject.Properties.Match('ConsoleDebug')) {
                $script:Config | Add-Member -MemberType NoteProperty -Name 'ConsoleDebug' -Value $false -Force
            }
            $consoleDebugCheckBox.IsChecked = $script:Config.ConsoleDebug
        }
        
        Write-LogMessage "WPF settings initialized successfully" -Level Info
        
        # Test progress bars
        Write-LogMessage "Testing status labels..." -Level Info
        
        $chocoProgressBar = Find-Control -ControlName "ChocoScanProgressBar"
        $wingetProgressBar = Find-Control -ControlName "WingetScanProgressBar"
        
        if ($chocoProgressBar) {
            Write-LogMessage "ChocoScanProgressBar found successfully" -Level Info
        }
        # Note: ChocoScanProgressBar was intentionally removed from UI
        
        if ($wingetProgressBar) {
            Write-LogMessage "WingetScanProgressBar found successfully" -Level Info
        }
        # Note: WingetScanProgressBar was intentionally removed from UI
    }
    catch {
        Write-LogMessage "Error initializing WPF settings: $($_.Exception.Message)" -Level Error
        throw
    }
}

# WPF-specific update functions
function Update-WPFChocoStatus {
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    try {
        Write-LogMessage "Updating Chocolatey status: $Message" -Level Info
        if ($script:WPFMainWindow) {
            $script:WPFMainWindow.Dispatcher.Invoke([Action]{
                $chocoStatusLabel = $script:WPFMainWindow.FindName("ChocoStatusLabel")
                if ($chocoStatusLabel) {
                    Write-LogMessage "Found ChocoStatusLabel, updating content to: $Message" -Level Info
                    $chocoStatusLabel.Content = $Message
                }
                # Note: ChocoStatusLabel was intentionally removed from UI
                
                # Update button states based on scan status
                if ($Message -like "*Scanning*" -or $Message -like "*Cancelling*") {
                    $chocoScanButton = $script:WPFMainWindow.FindName("ChocoScanButton")
                    $chocoCancelScanButton = $script:WPFMainWindow.FindName("ChocoCancelScanButton")
                    $chocoScanProgressBar = $script:WPFMainWindow.FindName("ChocoScanProgressBar")
                    
                    if ($chocoScanButton) { $chocoScanButton.IsEnabled = $false }
                    if ($chocoCancelScanButton) { $chocoCancelScanButton.Visibility = [System.Windows.Visibility]::Visible }
                    if ($chocoScanProgressBar) { $chocoScanProgressBar.Visibility = [System.Windows.Visibility]::Visible }
                } else {
                    $chocoScanButton = $script:WPFMainWindow.FindName("ChocoScanButton")
                    $chocoCancelScanButton = $script:WPFMainWindow.FindName("ChocoCancelScanButton")
                    $chocoScanProgressBar = $script:WPFMainWindow.FindName("ChocoScanProgressBar")
                    
                    if ($chocoScanButton) { $chocoScanButton.IsEnabled = $true }
                    if ($chocoCancelScanButton) { $chocoCancelScanButton.Visibility = [System.Windows.Visibility]::Collapsed }
                    if ($chocoScanProgressBar) { $chocoScanProgressBar.Visibility = [System.Windows.Visibility]::Collapsed }
                }
            })
        }
    }
    catch {
        Write-LogMessage "Error updating WPF Chocolatey status: $($_.Exception.Message)" -Level Error
    }
}

function Update-WPFWingetStatus {
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    try {
        Write-LogMessage "Updating Winget status: $Message" -Level Info
        if ($script:WPFMainWindow) {
            $script:WPFMainWindow.Dispatcher.Invoke([Action]{
                $wingetStatusLabel = $script:WPFMainWindow.FindName("WingetStatusLabel")
                if ($wingetStatusLabel) {
                    Write-LogMessage "Found WingetStatusLabel, updating content to: $Message" -Level Info
                    $wingetStatusLabel.Content = $Message
                }
                # Note: WingetStatusLabel was intentionally removed from UI
                
                # Update button states based on scan status
                if ($Message -like "*Scanning*" -or $Message -like "*Cancelling*") {
                    $wingetScanButton = $script:WPFMainWindow.FindName("WingetScanButton")
                    $wingetCancelScanButton = $script:WPFMainWindow.FindName("WingetCancelScanButton")
                    $wingetScanProgressBar = $script:WPFMainWindow.FindName("WingetScanProgressBar")
                    
                    if ($wingetScanButton) { $wingetScanButton.IsEnabled = $false }
                    if ($wingetCancelScanButton) { $wingetCancelScanButton.Visibility = [System.Windows.Visibility]::Visible }
                    if ($wingetScanProgressBar) { $wingetScanProgressBar.Visibility = [System.Windows.Visibility]::Visible }
                } else {
                    $wingetScanButton = $script:WPFMainWindow.FindName("WingetScanButton")
                    $wingetCancelScanButton = $script:WPFMainWindow.FindName("WingetCancelScanButton")
                    $wingetScanProgressBar = $script:WPFMainWindow.FindName("WingetScanProgressBar")
                    
                    if ($wingetScanButton) { $wingetScanButton.IsEnabled = $true }
                    if ($wingetCancelScanButton) { $wingetCancelScanButton.Visibility = [System.Windows.Visibility]::Collapsed }
                    if ($wingetScanProgressBar) { $wingetScanProgressBar.Visibility = [System.Windows.Visibility]::Collapsed }
                }
            })
        }
    }
    catch {
        Write-LogMessage "Error updating WPF Winget status: $($_.Exception.Message)" -Level Error
    }
}

function Populate-WPFChocoUpdatesGrid {
    [CmdletBinding()]
    param(
        [array]$Updates
    )
    
    try {
        if ($script:WPFMainWindow) {
            $script:WPFMainWindow.Dispatcher.Invoke([Action]{
                $chocoUpdatesGrid = $script:WPFMainWindow.FindName("ChocoUpdatesGrid")
                $chocoProcessButton = $script:WPFMainWindow.FindName("ChocoProcessButton")
                
                if ($chocoUpdatesGrid) {
                    $chocoUpdatesGrid.ItemsSource = $Updates
                }
                if ($chocoProcessButton) {
                    $chocoProcessButton.IsEnabled = ($Updates.Count -gt 0)
                }
            })
        }
    }
    catch {
        Write-LogMessage "Error populating WPF Chocolatey updates grid: $($_.Exception.Message)" -Level Error
    }
}

function Populate-WPFWingetUpdatesGrid {
    [CmdletBinding()]
    param(
        [array]$Updates
    )
    
    try {
        if ($script:WPFMainWindow) {
            $script:WPFMainWindow.Dispatcher.Invoke([Action]{
                $wingetUpdatesGrid = $script:WPFMainWindow.FindName("WingetUpdatesGrid")
                $wingetProcessButton = $script:WPFMainWindow.FindName("WingetProcessButton")
                
                if ($wingetUpdatesGrid) {
                    $wingetUpdatesGrid.ItemsSource = $Updates
                }
                if ($wingetProcessButton) {
                    $wingetProcessButton.IsEnabled = ($Updates.Count -gt 0)
                }
            })
        }
    }
    catch {
        Write-LogMessage "Error populating WPF Winget updates grid: $($_.Exception.Message)" -Level Error
    }
}

function Save-WPFChocoSettings {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Save-WPFChocoSettings called from: $((Get-PSCallStack)[1].Command)" -Level Info
        if ($script:WPFMainWindow) {
            $chocoJobFileTextBox = $script:WPFMainWindow.FindName("ChocoJobFileTextBox")
            if ($chocoJobFileTextBox) {
                Write-LogMessage "Saving Chocolatey job file: '$($chocoJobFileTextBox.Text)'" -Level Info
                $script:Config.ChocoSettings.JobFile = $chocoJobFileTextBox.Text
                Save-AllSettings -ChocoJobFile $chocoJobFileTextBox.Text
                Write-LogMessage "WPF Chocolatey settings saved" -Level Info
            }
        }
    }
    catch {
        Write-LogMessage "Error saving WPF Chocolatey settings: $($_.Exception.Message)" -Level Error
    }
}

function Save-WPFWingetSettings {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Save-WPFWingetSettings called from: $((Get-PSCallStack)[1].Command)" -Level Info
        if ($script:WPFMainWindow) {
            $wingetJobFileTextBox = $script:WPFMainWindow.FindName("WingetJobFileTextBox")
            $wingetInstallerTextBox = $script:WPFMainWindow.FindName("WingetInstallerTextBox")
            
            if ($wingetJobFileTextBox) {
                Write-LogMessage "Saving Winget job file: '$($wingetJobFileTextBox.Text)'" -Level Info
                $script:Config.WingetSettings.JobFile = $wingetJobFileTextBox.Text
            }
            
            if ($wingetInstallerTextBox) {
                Write-LogMessage "Saving Winget installer path: '$($wingetInstallerTextBox.Text)'" -Level Info
                $script:Config.WingetSettings.InstallerPath = $wingetInstallerTextBox.Text
            }
            
            Save-AllSettings -WingetJobFile $wingetJobFileTextBox.Text -WingetInstallerPath $wingetInstallerTextBox.Text
            Write-LogMessage "WPF Winget settings saved" -Level Info
        }
    }
    catch {
        Write-LogMessage "Error saving WPF Winget settings: $($_.Exception.Message)" -Level Error
    }
}

function Save-WPFGlobalSettings {
    [CmdletBinding()]
    param()
    
    try {
        if ($script:WPFMainWindow) {
            $settingsServerTextBox = $script:WPFMainWindow.FindName("SettingsServerTextBox")
            $settingsServerPortTextBox = $script:WPFMainWindow.FindName("SettingsServerPortTextBox")
            $settingsAdminUserTextBox = $script:WPFMainWindow.FindName("SettingsAdminUserTextBox")
            $settingsFlexAppClientTextBox = $script:WPFMainWindow.FindName("SettingsFlexAppClientTextBox")
            $settingsPasswordFileTextBox = $script:WPFMainWindow.FindName("SettingsPasswordFileTextBox")
            $settingsAESKeyFileTextBox = $script:WPFMainWindow.FindName("SettingsAESKeyFileTextBox")
            $settingsTempPathTextBox = $script:WPFMainWindow.FindName("SettingsTempPathTextBox")
            $settingsDefaultFileTextBox = $script:WPFMainWindow.FindName("SettingsDefaultFileTextBox")
            $settingsPrimaryServerTextBox = $script:WPFMainWindow.FindName("SettingsPrimaryServerTextBox")
            $settingsProcessWaitTextBox = $script:WPFMainWindow.FindName("SettingsProcessWaitTextBox")
            $lightModeRadio = $script:WPFMainWindow.FindName("LightModeRadio")
            $darkModeRadio = $script:WPFMainWindow.FindName("DarkModeRadio")
            
            if ($settingsServerTextBox) { $script:Config.ServerName = $settingsServerTextBox.Text }
            if ($settingsServerPortTextBox) { $script:Config.ServerPort = $settingsServerPortTextBox.Text }
            if ($settingsAdminUserTextBox) { $script:Config.AdminUser = $settingsAdminUserTextBox.Text }
            if ($settingsFlexAppClientTextBox) { $script:Config.FlexAppClient = $settingsFlexAppClientTextBox.Text }
            if ($settingsPasswordFileTextBox) { $script:Config.PasswordFile = $settingsPasswordFileTextBox.Text }
            if ($settingsAESKeyFileTextBox) { $script:Config.AESKeyFile = $settingsAESKeyFileTextBox.Text }
            if ($settingsTempPathTextBox) { $script:Config.TempPath = $settingsTempPathTextBox.Text }
            if ($settingsDefaultFileTextBox) { $script:Config.DefaultFile = $settingsDefaultFileTextBox.Text }
            if ($settingsPrimaryServerTextBox) { $script:Config.PrimaryServer = $settingsPrimaryServerTextBox.Text }
            if ($settingsProcessWaitTextBox) { $script:Config.ProcessWaitTime = $settingsProcessWaitTextBox.Text }
            if ($darkModeRadio) { 
                # Ensure configuration is loaded
                if (-not $script:Config) {
                    Write-LogMessage "Configuration not loaded, loading now..." -Level Info
                    Load-AllSettings
                }
                
                # Ensure the DarkMode property exists
                if (-not $script:Config.PSObject.Properties.Match('DarkMode')) {
                    $script:Config | Add-Member -MemberType NoteProperty -Name 'DarkMode' -Value $false -Force
                }
                $script:Config.DarkMode = $darkModeRadio.IsChecked 
            }
            
            # Save console debug setting
            $consoleDebugCheckBox = Find-Control -ControlName "ConsoleDebugCheckBox"
            if ($consoleDebugCheckBox) {
                # Ensure the ConsoleDebug property exists
                if (-not $script:Config.PSObject.Properties.Match('ConsoleDebug')) {
                    $script:Config | Add-Member -MemberType NoteProperty -Name 'ConsoleDebug' -Value $false -Force
                }
                $script:Config.ConsoleDebug = $consoleDebugCheckBox.IsChecked
            }
            
            # Save Intune settings
            Save-WPFIntuneSettings
            
            # Save the configuration
            $configPath = Get-ConfigPath
            $configDir = Split-Path $configPath -Parent
            if (-not (Test-Path $configDir)) {
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            }
            $script:Config | ConvertTo-Json -Depth 10 | Out-File $configPath -Encoding UTF8
            Write-LogMessage "WPF global settings saved" -Level Info
            
            [System.Windows.MessageBox]::Show(
                "Settings saved successfully!", 
                "Success", 
                [System.Windows.MessageBoxButton]::OK, 
                [System.Windows.MessageBoxImage]::Information
            )
        }
    }
    catch {
        Write-LogMessage "Error saving WPF global settings: $($_.Exception.Message)" -Level Error
        [System.Windows.MessageBox]::Show(
            "Error saving settings: $($_.Exception.Message)", 
            "Error", 
            [System.Windows.MessageBoxButton]::OK, 
            [System.Windows.MessageBoxImage]::Error
        )
    }
}

function Reset-WPFGlobalSettings {
    [CmdletBinding()]
    param()
    
    try {
        # Reset to default values
        $script:Config.ServerName = "pro2020"
        $script:Config.ServerPort = 8000
        $script:Config.AdminUser = "administrator"
        $script:Config.FlexAppClient = "C:\Program Files (x86)\Liquidware Labs\FlexApp Packaging Automation\primary-client.exe"
        $script:Config.PasswordFile = Join-Path $scriptPath "Config\password.txt"
        $script:Config.AESKeyFile = Join-Path $scriptPath "Config\aeskey.txt"
        $script:Config.TempPath = $env:TEMP
        $script:Config.ProcessWaitTime = 10
        $script:Config.DefaultFile = Join-Path $scriptPath "Config\Default.json"
        $script:Config.PrimaryServer = "https://pro2020:9075"
        
        # Update UI controls
        if ($script:WPFMainWindow) {
            $settingsServerTextBox = $script:WPFMainWindow.FindName("SettingsServerTextBox")
            $settingsServerPortTextBox = $script:WPFMainWindow.FindName("SettingsServerPortTextBox")
            $settingsAdminUserTextBox = $script:WPFMainWindow.FindName("SettingsAdminUserTextBox")
            $settingsFlexAppClientTextBox = $script:WPFMainWindow.FindName("SettingsFlexAppClientTextBox")
            $settingsPasswordFileTextBox = $script:WPFMainWindow.FindName("SettingsPasswordFileTextBox")
            $settingsAESKeyFileTextBox = $script:WPFMainWindow.FindName("SettingsAESKeyFileTextBox")
            $settingsTempPathTextBox = $script:WPFMainWindow.FindName("SettingsTempPathTextBox")
            $settingsProcessWaitTextBox = $script:WPFMainWindow.FindName("SettingsProcessWaitTextBox")
            $settingsDefaultFileTextBox = $script:WPFMainWindow.FindName("SettingsDefaultFileTextBox")
            $settingsPrimaryServerTextBox = $script:WPFMainWindow.FindName("SettingsPrimaryServerTextBox")
            
            if ($settingsServerTextBox) { $settingsServerTextBox.Text = $script:Config.ServerName }
            if ($settingsServerPortTextBox) { $settingsServerPortTextBox.Text = $script:Config.ServerPort }
            if ($settingsAdminUserTextBox) { $settingsAdminUserTextBox.Text = $script:Config.AdminUser }
            if ($settingsFlexAppClientTextBox) { $settingsFlexAppClientTextBox.Text = $script:Config.FlexAppClient }
            if ($settingsPasswordFileTextBox) { $settingsPasswordFileTextBox.Text = $script:Config.PasswordFile }
            if ($settingsAESKeyFileTextBox) { $settingsAESKeyFileTextBox.Text = $script:Config.AESKeyFile }
            if ($settingsTempPathTextBox) { $settingsTempPathTextBox.Text = $script:Config.TempPath }
            if ($settingsProcessWaitTextBox) { $settingsProcessWaitTextBox.Text = $script:Config.ProcessWaitTime }
            if ($settingsDefaultFileTextBox) { $settingsDefaultFileTextBox.Text = $script:Config.DefaultFile }
            if ($settingsPrimaryServerTextBox) { $settingsPrimaryServerTextBox.Text = $script:Config.PrimaryServer }
        }
        
        # Save the reset configuration
        $configPath = Get-ConfigPath
        $configDir = Split-Path $configPath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        $script:Config | ConvertTo-Json -Depth 10 | Out-File $configPath -Encoding UTF8
        
        Write-LogMessage "WPF global settings reset to defaults" -Level Info
        
        [System.Windows.MessageBox]::Show(
            "Settings have been reset to defaults and saved.", 
            "Reset Complete", 
            [System.Windows.MessageBoxButton]::OK, 
            [System.Windows.MessageBoxImage]::Information
        )
    }
    catch {
        Write-LogMessage "Error resetting WPF global settings: $($_.Exception.Message)" -Level Error
        [System.Windows.MessageBox]::Show(
            "Error resetting settings: $($_.Exception.Message)", 
            "Error", 
            [System.Windows.MessageBoxButton]::OK, 
            [System.Windows.MessageBoxImage]::Error
        )
    }
}

# WPF-specific wrapper functions for compatibility
function Start-ChocoSelectedUpdates {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Starting Chocolatey selected updates..." -Level Info
        
        # Get selected packages from WPF DataGrid
        $chocoUpdatesGrid = $script:WPFMainWindow.FindName("ChocoUpdatesGrid")
        if (-not $chocoUpdatesGrid) {
            throw "Could not find ChocoUpdatesGrid control"
        }
        
        # Use centralized default file setting
        $defaultFile = $script:Config.DefaultFile
        if ([string]::IsNullOrWhiteSpace($defaultFile) -or -not (Test-Path $defaultFile)) {
            [System.Windows.MessageBox]::Show("Default file not found or not configured: $defaultFile`n`nPlease configure the Default File in the Settings tab.", "File Not Found", "OK", "Error")
            return
        }
        
        # Use centralized primary server setting
        $server = $script:Config.PrimaryServer
        if ([string]::IsNullOrWhiteSpace($server)) {
            [System.Windows.MessageBox]::Show("Primary Server not configured.`n`nPlease configure the Primary Server in the Settings tab.", "Server Not Configured", "OK", "Error")
            return
        }
        
        $selectedPackages = @()
        foreach ($item in $chocoUpdatesGrid.Items) {
            if ($item.Selected -eq $true) {
                $selectedPackages += $item
            }
        }
        
        if ($selectedPackages.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Please select at least one package to update.", "No Selection", "OK", "Warning")
            return
        }
        
        $packageList = $selectedPackages | ForEach-Object { "- $($_.Name) ($($_.CurrentVersion) -> $($_.NewVersion))" }
        $confirmMessage = "Are you sure you want to update the following $($selectedPackages.Count) package(s)?`n`n$($packageList -join "`n")"
        
        $result = [System.Windows.MessageBox]::Show($confirmMessage, "Confirm Update", "YesNo", "Question")
        
        if ($result -eq "Yes") {
            Update-WPFChocoStatus -Message "Processing $($selectedPackages.Count) selected updates..." -Level Info
            
            $updatePackages = @()
            foreach ($package in $selectedPackages) {
                $updatePackage = [PSCustomObject]@{
                    Name = $package.Name
                    PackageVersion = $package.NewVersion
                    SizeMB = $package.SizeMB
                    Installer = $package.Installer
                    InstallerArgs = $package.InstallerArgs
                }
                $updatePackages += $updatePackage
            }
            
            # Call the WPF-specific update function (prevents focus stealing)
            Start-WPFPackageUpdate -UpdatePackages $updatePackages -DefaultFile $defaultFile -Server $server -SourceTab "Chocolatey"
        }
    }
    catch {
        Write-LogMessage "Error starting Chocolatey updates: $($_.Exception.Message)" -Level Error
        Update-WPFChocoStatus -Message "Update process failed: $($_.Exception.Message)" -Level Error
    }
}

function Start-WingetSelectedUpdates {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Starting Winget selected updates..." -Level Info
        
        # Get selected packages from WPF DataGrid
        $wingetUpdatesGrid = $script:WPFMainWindow.FindName("WingetUpdatesGrid")
        if (-not $wingetUpdatesGrid) {
            throw "Could not find WingetUpdatesGrid control"
        }
        
        # Use centralized default file setting
        $defaultFile = $script:Config.DefaultFile
        if ([string]::IsNullOrWhiteSpace($defaultFile) -or -not (Test-Path $defaultFile)) {
            [System.Windows.MessageBox]::Show("Default file not found or not configured: $defaultFile`n`nPlease configure the Default File in the Settings tab.", "File Not Found", "OK", "Error")
            return
        }
        
        # Use centralized primary server setting
        $server = $script:Config.PrimaryServer
        if ([string]::IsNullOrWhiteSpace($server)) {
            [System.Windows.MessageBox]::Show("Primary Server not configured.`n`nPlease configure the Primary Server in the Settings tab.", "Server Not Configured", "OK", "Error")
            return
        }
        
        $selectedPackages = @()
        foreach ($item in $wingetUpdatesGrid.Items) {
            if ($item.Selected -eq $true) {
                $selectedPackages += $item
            }
        }
        
        if ($selectedPackages.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Please select at least one package to update.", "No Selection", "OK", "Warning")
            return
        }
        
        $packageList = $selectedPackages | ForEach-Object { "- $($_.Name) ($($_.CurrentVersion) -> $($_.NewVersion))" }
        $confirmMessage = "Are you sure you want to update the following $($selectedPackages.Count) package(s)?`n`n$($packageList -join "`n")"
        
        $result = [System.Windows.MessageBox]::Show($confirmMessage, "Confirm Update", "YesNo", "Question")
        
        if ($result -eq "Yes") {
            Update-WPFWingetStatus -Message "Processing $($selectedPackages.Count) selected updates..." -Level Info
            
            $updatePackages = @()
            foreach ($package in $selectedPackages) {
                $updatePackage = [PSCustomObject]@{
                    Name = $package.Name
                    PackageVersion = $package.NewVersion
                    SizeMB = $package.SizeMB
                    Installer = $package.Installer
                    InstallerArgs = $package.InstallerArgs
                }
                $updatePackages += $updatePackage
            }
            
            # Call the WPF-specific update function (prevents focus stealing)
            Start-WPFPackageUpdate -UpdatePackages $updatePackages -DefaultFile $defaultFile -Server $server -SourceTab "Winget"
        }
    }
    catch {
        Write-LogMessage "Error starting Winget updates: $($_.Exception.Message)" -Level Error
        Update-WPFWingetStatus -Message "Update process failed: $($_.Exception.Message)" -Level Error
    }
}

function Invoke-WPFProcessSelectedApplicationsConfirmation {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Processing selected Configuration Manager applications..." -Level Info
        
        # Get selected applications from WPF DataGrid
        $cmApplicationsGrid = $script:WPFMainWindow.FindName("CMApplicationsGrid")
        if (-not $cmApplicationsGrid) {
            throw "Could not find CMApplicationsGrid control"
        }
        
        $selectedApps = @()
        foreach ($item in $cmApplicationsGrid.Items) {
            if ($item.Selected -eq $true) {
                $selectedApps += $item
            }
        }
        
        if ($selectedApps.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Please select at least one application to process.", "No Selection", "OK", "Warning")
            return
        }
        
        $appList = $selectedApps | ForEach-Object { "- $($_.Name) ($($_.Version))" }
        $confirmMessage = "Are you sure you want to process the following $($selectedApps.Count) application(s)?`n`n$($appList -join "`n")"
        
        $result = [System.Windows.MessageBox]::Show($confirmMessage, "Confirm Processing", "YesNo", "Question")
        
        if ($result -eq "Yes") {
            # Call the actual CM processing function
            $selectedAppNames = $selectedApps | ForEach-Object { $_.Name }
            Process-SelectedApplications -SelectedApps $selectedAppNames
        }
    }
    catch {
        Write-LogMessage "Error processing Configuration Manager applications: $($_.Exception.Message)" -Level Error
    }
}

function Process-SelectedFlexApps {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Processing selected ProfileUnity FlexApps..." -Level Info
        
        # Get selected FlexApps from WPF DataGrid
        $puFlexAppsGrid = $script:WPFMainWindow.FindName("PUFlexAppsGrid")
        if (-not $puFlexAppsGrid) {
            throw "Could not find PUFlexAppsGrid control"
        }
        
        $selectedFlexApps = @()
        foreach ($item in $puFlexAppsGrid.Items) {
            if ($item.Selected -eq $true) {
                $selectedFlexApps += $item
            }
        }
        
        if ($selectedFlexApps.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Please select at least one FlexApp to process.", "No Selection", "OK", "Warning")
            return
        }
        
        $flexAppList = $selectedFlexApps | ForEach-Object { "- $($_.Name) ($($_.Version))" }
        $confirmMessage = "Are you sure you want to process the following $($selectedFlexApps.Count) FlexApp(s)?`n`n$($flexAppList -join "`n")"
        
        $result = [System.Windows.MessageBox]::Show($confirmMessage, "Confirm Processing", "YesNo", "Question")
        
        if ($result -eq "Yes") {
            # Call the actual processing function
            $selectedFlexAppNames = $selectedFlexApps | ForEach-Object { $_.Name }
            Process-SelectedFlexApps -SelectedFlexApps $selectedFlexAppNames
        }
    }
    catch {
        Write-LogMessage "Error processing ProfileUnity FlexApps: $($_.Exception.Message)" -Level Error
    }
}

function Test-GlobalSettings {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Testing global settings..." -Level Info
        
        # Get UI controls for status updates
        $statusLabel = Find-Control -ControlName "SettingsGlobalStatusLabel"
        if ($statusLabel) {
            $statusLabel.Content = "Testing connections..."
        }
        
        $allTestsPassed = $true
        $results = @()
        
        # Test ProfileUnity connection
        try {
            Write-LogMessage "Testing ProfileUnity server connection..." -Level Info
            $puConnected = Connect-ProfileUnityServer
            if ($puConnected) {
                $results += "[OK] ProfileUnity: Connected to $($script:Config.ServerName):$($script:Config.ServerPort)"
                Write-LogMessage "ProfileUnity connection test passed" -Level Success
            } else {
                $results += "[FAIL] ProfileUnity: Connection failed"
                $allTestsPassed = $false
                Write-LogMessage "ProfileUnity connection test failed" -Level Error
            }
        }
        catch {
            $results += "[ERROR] ProfileUnity: $($_.Exception.Message)"
            $allTestsPassed = $false
            Write-LogMessage "ProfileUnity connection test error: $($_.Exception.Message)" -Level Error
        }
        
        # Test FlexApp Client path
        try {
            if ($script:Config.FlexAppClient -and (Test-Path $script:Config.FlexAppClient)) {
                $results += "[OK] FlexApp Client: Found at $($script:Config.FlexAppClient)"
                Write-LogMessage "FlexApp Client path test passed" -Level Success
            } else {
                $results += "[FAIL] FlexApp Client: Not found at $($script:Config.FlexAppClient)"
                $allTestsPassed = $false
                Write-LogMessage "FlexApp Client path test failed" -Level Error
            }
        }
        catch {
            $results += "[ERROR] FlexApp Client: $($_.Exception.Message)"
            $allTestsPassed = $false
            Write-LogMessage "FlexApp Client test error: $($_.Exception.Message)" -Level Error
        }
        
        # Update status and show results
        if ($statusLabel) {
            if ($allTestsPassed) {
                $statusLabel.Content = "All tests passed"
                $statusLabel.Foreground = [System.Windows.Media.Brushes]::Green
            } else {
                $statusLabel.Content = "Some tests failed"
                $statusLabel.Foreground = [System.Windows.Media.Brushes]::Red
            }
        }
        
        # Show detailed results in message box
        $resultMessage = "Connection Test Results:`n`n" + ($results -join "`n")
        $messageBoxType = if ($allTestsPassed) { "Information" } else { "Warning" }
        [System.Windows.MessageBox]::Show($resultMessage, "Connection Test Results", "OK", $messageBoxType)
        
        Write-LogMessage "Global settings test completed. All tests passed: $allTestsPassed" -Level Info
    }
    catch {
        Write-LogMessage "Error testing global settings: $($_.Exception.Message)" -Level Error
        if ($statusLabel) {
            $statusLabel.Content = "Test failed with error"
            $statusLabel.Foreground = [System.Windows.Media.Brushes]::Red
        }
        [System.Windows.MessageBox]::Show("Error during connection test: $($_.Exception.Message)", "Test Error", "OK", "Error")
    }
}

function Disconnect-ConfigurationManager {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Disconnecting from Configuration Manager..." -Level Info
        # Call the WPF-specific disconnect function
        Disconnect-WPFConfigurationManager
    }
    catch {
        Write-LogMessage "Error disconnecting from Configuration Manager: $($_.Exception.Message)" -Level Error
    }
}

function Disconnect-ProfileUnityServer {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Disconnecting from ProfileUnity server..." -Level Info
        # This would call the actual function from the main module
        # For now, just log the action
        Write-LogMessage "ProfileUnity disconnect not yet implemented in WPF" -Level Warning
    }
    catch {
        Write-LogMessage "Error disconnecting from ProfileUnity server: $($_.Exception.Message)" -Level Error
    }
}

function Toggle-WPFTheme {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Toggling WPF theme..." -Level Info
        
        # Use the enhanced Switch-WPFTheme function that preserves job files
        Switch-WPFTheme
        
        [System.Windows.MessageBox]::Show(
            "Theme applied successfully!", 
            "Success", 
            [System.Windows.MessageBoxButton]::OK, 
            [System.Windows.MessageBoxImage]::Information
        )
    }
    catch {
        Write-LogMessage "Error toggling WPF theme: $($_.Exception.Message)" -Level Error                                                                       
        [System.Windows.MessageBox]::Show(
            "Error applying theme: $($_.Exception.Message)", 
            "Error", 
            [System.Windows.MessageBoxButton]::OK, 
            [System.Windows.MessageBoxImage]::Error
        )
    }
}

# Test function to debug window state issues
function Test-WindowState {
    [CmdletBinding()]
    param()
    
    if (-not $script:WPFMainWindow) {
        Write-Host "No WPF window available for testing" -ForegroundColor Red
        return
    }
    
    Write-Host "Current window state: $($script:WPFMainWindow.WindowState)" -ForegroundColor Yellow
    Write-Host "Window can resize: $($script:WPFMainWindow.ResizeMode)" -ForegroundColor Yellow
    Write-Host "Window is visible: $($script:WPFMainWindow.IsVisible)" -ForegroundColor Yellow
    Write-Host "Window is active: $($script:WPFMainWindow.IsActive)" -ForegroundColor Yellow
    Write-Host "Window size: $($script:WPFMainWindow.Width) x $($script:WPFMainWindow.Height)" -ForegroundColor Yellow
    Write-Host "Window position: $($script:WPFMainWindow.Left), $($script:WPFMainWindow.Top)" -ForegroundColor Yellow
    Write-Host "Window show in taskbar: $($script:WPFMainWindow.ShowInTaskbar)" -ForegroundColor Yellow
    Write-Host "Window style: $($script:WPFMainWindow.WindowStyle)" -ForegroundColor Yellow
    Write-Host "Window max size: $($script:WPFMainWindow.MaxWidth) x $($script:WPFMainWindow.MaxHeight)" -ForegroundColor Yellow
    Write-Host "Window min size: $($script:WPFMainWindow.MinWidth) x $($script:WPFMainWindow.MinHeight)" -ForegroundColor Yellow
    
    # Test maximize
    Write-Host "Testing maximize..." -ForegroundColor Cyan
    $script:WPFMainWindow.WindowState = [System.Windows.WindowState]::Maximized
    Start-Sleep -Milliseconds 500
    Write-Host "Window state after maximize: $($script:WPFMainWindow.WindowState)" -ForegroundColor Yellow
    
    # Test restore
    Write-Host "Testing restore..." -ForegroundColor Cyan
    $script:WPFMainWindow.WindowState = [System.Windows.WindowState]::Normal
    Start-Sleep -Milliseconds 500
    Write-Host "Window state after restore: $($script:WPFMainWindow.WindowState)" -ForegroundColor Yellow
    
    # Test minimize
    Write-Host "Testing minimize..." -ForegroundColor Cyan
    $script:WPFMainWindow.WindowState = [System.Windows.WindowState]::Minimized
    Start-Sleep -Milliseconds 500
    Write-Host "Window state after minimize: $($script:WPFMainWindow.WindowState)" -ForegroundColor Yellow
    
    # Restore
    Write-Host "Restoring window..." -ForegroundColor Cyan
    $script:WPFMainWindow.WindowState = [System.Windows.WindowState]::Normal
    $script:WPFMainWindow.Show()
    $script:WPFMainWindow.Activate()
    $script:WPFMainWindow.Focus()
    $script:WPFMainWindow.BringIntoView()
    
    # Force window to foreground using Windows API
    try {
        Add-Type -TypeDefinition @"
            using System;
            using System.Runtime.InteropServices;
            public class Win32 {
                [DllImport("user32.dll")]
                public static extern bool SetForegroundWindow(IntPtr hWnd);
                [DllImport("user32.dll")]
                public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
                [DllImport("user32.dll")]
                public static extern IntPtr GetActiveWindow();
            }
"@
        $hwnd = $script:WPFMainWindow.Handle
        [Win32]::SetForegroundWindow($hwnd)
        [Win32]::ShowWindow($hwnd, 9) # SW_RESTORE
        Write-Host "Window forced to foreground using Windows API" -ForegroundColor Green
    }
    catch {
        Write-Host "Could not force window to foreground: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Function to force window to foreground when it gets stuck
function Show-Window {
    [CmdletBinding()]
    param()
    
    if (-not $script:WPFMainWindow) {
        Write-Host "No WPF window available" -ForegroundColor Red
        return
    }
    
    try {
        Write-Host "Forcing window to foreground..." -ForegroundColor Cyan
        
        # Set window state to normal and show
        $script:WPFMainWindow.WindowState = [System.Windows.WindowState]::Normal
        $script:WPFMainWindow.Show()
        $script:WPFMainWindow.Activate()
        $script:WPFMainWindow.Focus()
        $script:WPFMainWindow.BringIntoView()
        
        # Use Windows API to force to foreground
        Add-Type -TypeDefinition @"
            using System;
            using System.Runtime.InteropServices;
            public class Win32 {
                [DllImport("user32.dll")]
                public static extern bool SetForegroundWindow(IntPtr hWnd);
                [DllImport("user32.dll")]
                public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
                [DllImport("user32.dll")]
                public static extern bool IsIconic(IntPtr hWnd);
                [DllImport("user32.dll")]
                public static extern bool IsWindowVisible(IntPtr hWnd);
            }
"@
        
        $hwnd = $script:WPFMainWindow.Handle
        $isMinimized = [Win32]::IsIconic($hwnd)
        $isVisible = [Win32]::IsWindowVisible($hwnd)
        
        Write-Host "Window handle: $hwnd" -ForegroundColor Yellow
        Write-Host "Is minimized: $isMinimized" -ForegroundColor Yellow
        Write-Host "Is visible: $isVisible" -ForegroundColor Yellow
        
        if ($isMinimized) {
            [Win32]::ShowWindow($hwnd, 9) # SW_RESTORE
            Write-Host "Window restored from minimized state" -ForegroundColor Green
        }
        
        [Win32]::SetForegroundWindow($hwnd)
        Write-Host "Window forced to foreground" -ForegroundColor Green
        
        # Final WPF calls
        $script:WPFMainWindow.Topmost = $true
        Start-Sleep -Milliseconds 100
        $script:WPFMainWindow.Topmost = $false
        
    }
    catch {
        Write-Host "Error forcing window to foreground: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to test maximize button functionality
function Test-MaximizeButton {
    [CmdletBinding()]
    param()
    
    if (-not $script:WPFMainWindow) {
        Write-Host "No WPF window available" -ForegroundColor Red
        return
    }
    
    try {
        Write-Host "Testing maximize button functionality..." -ForegroundColor Cyan
        
        # Add Windows API for window manipulation
        Add-Type -TypeDefinition @"
            using System;
            using System.Runtime.InteropServices;
            public class Win32 {
                [DllImport("user32.dll")]
                public static extern IntPtr GetWindowLong(IntPtr hWnd, int nIndex);
                [DllImport("user32.dll")]
                public static extern IntPtr SetWindowLong(IntPtr hWnd, int nIndex, IntPtr dwNewLong);
                [DllImport("user32.dll")]
                public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
                [DllImport("user32.dll")]
                public static extern bool IsZoomed(IntPtr hWnd);
                [DllImport("user32.dll")]
                public static extern bool IsIconic(IntPtr hWnd);
                public const int GWL_STYLE = -16;
                public const int WS_MAXIMIZEBOX = 0x00010000;
                public const int WS_MINIMIZEBOX = 0x00020000;
                public const int WS_SYSMENU = 0x00080000;
                public const int SW_MAXIMIZE = 3;
                public const int SW_RESTORE = 9;
            }
"@
        
        $hwnd = $script:WPFMainWindow.Handle
        Write-Host "Window handle: $hwnd" -ForegroundColor Yellow
        
        # Check current window style
        $style = [Win32]::GetWindowLong($hwnd, [Win32]::GWL_STYLE)
        $hasMaximizeBox = ($style -band [Win32]::WS_MAXIMIZEBOX) -ne 0
        $hasMinimizeBox = ($style -band [Win32]::WS_MINIMIZEBOX) -ne 0
        $hasSysMenu = ($style -band [Win32]::WS_SYSMENU) -ne 0
        
        Write-Host "Window style flags:" -ForegroundColor Yellow
        Write-Host "  Has Maximize Box: $hasMaximizeBox" -ForegroundColor Yellow
        Write-Host "  Has Minimize Box: $hasMinimizeBox" -ForegroundColor Yellow
        Write-Host "  Has System Menu: $hasSysMenu" -ForegroundColor Yellow
        
        if (-not $hasMaximizeBox) {
            Write-Host "Maximize box is missing! Adding it..." -ForegroundColor Red
            $newStyle = $style -bor [Win32]::WS_MAXIMIZEBOX -bor [Win32]::WS_MINIMIZEBOX -bor [Win32]::WS_SYSMENU
            [Win32]::SetWindowLong($hwnd, [Win32]::GWL_STYLE, $newStyle)
            Write-Host "Maximize box added" -ForegroundColor Green
        }
        
        # Test maximize using Windows API
        Write-Host "Testing maximize using Windows API..." -ForegroundColor Cyan
        $result = [Win32]::ShowWindow($hwnd, [Win32]::SW_MAXIMIZE)
        Write-Host "Maximize result: $result" -ForegroundColor Yellow
        
        Start-Sleep -Milliseconds 1000
        
        # Check if maximized
        $isMaximized = [Win32]::IsZoomed($hwnd)
        Write-Host "Is maximized (Windows API): $isMaximized" -ForegroundColor Yellow
        Write-Host "Window state (WPF): $($script:WPFMainWindow.WindowState)" -ForegroundColor Yellow
        
        # Restore
        Write-Host "Restoring window..." -ForegroundColor Cyan
        [Win32]::ShowWindow($hwnd, [Win32]::SW_RESTORE)
        $script:WPFMainWindow.WindowState = [System.Windows.WindowState]::Normal
        
    }
    catch {
        Write-Host "Error testing maximize button: $($_.Exception.Message)" -ForegroundColor Red
    }
}

