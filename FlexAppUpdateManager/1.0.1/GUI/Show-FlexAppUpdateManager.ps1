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
        $removedControls = @("ChocoStatusLabel", "WingetStatusLabel", "CMStatusLabel", "ChocoScanProgressBar", "WingetScanProgressBar")
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
        
        $xmlReader = [System.Xml.XmlNodeReader]::New([xml]$xaml)
        $window = [System.Windows.Markup.XamlReader]::Load($xmlReader)
        
        if (-not $window) {
            throw "Failed to load XAML window - XamlReader returned null"
        }
        
        # Store the window in script scope
        $script:WPFMainWindow = $window
        
        Write-LogMessage "XAML loaded successfully, setting up event handlers..." -Level Info
        
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
            $darkModeRadio = Find-Control "DarkModeRadio"
            $lightModeRadio = Find-Control "LightModeRadio"
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
        })
        
        Write-LogMessage "Showing window..." -Level Info
        
        # Show window
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
        
        # Helper function to find controls by name
        function Find-Control {
            param([string]$ControlName)
            return $script:WPFMainWindow.FindName($ControlName)
        }
        
        # Chocolatey Tab Event Handlers
        $chocoJobFileBrowseButton = Find-Control "ChocoJobFileBrowseButton"
        if ($chocoJobFileBrowseButton) {
            $chocoJobFileBrowseButton.Add_Click({
                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "CSV Files (*.csv)|*.csv"
                $openFileDialog.RestoreDirectory = $true
                if ($openFileDialog.ShowDialog() -eq $true) {
                    $chocoJobFileTextBox = Find-Control "ChocoJobFileTextBox"
                    if ($chocoJobFileTextBox) {
                        $chocoJobFileTextBox.Text = $openFileDialog.FileName
                        # Use dynamic theme brush instead of hardcoded black
                        $chocoJobFileTextBox.Foreground = $script:WPFMainWindow.Resources["PrimaryTextBrush"]
                        Save-WPFChocoSettings
                    }
                }
            })
        }
        
        $chocoScanButton = Find-Control "ChocoScanButton"
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
        
        $chocoCancelScanButton = Find-Control "ChocoCancelScanButton"
        if ($chocoCancelScanButton) {
            $chocoCancelScanButton.Add_Click({
                $script:ChocoScanCancelled = $true
                Write-LogMessage "Scan cancellation requested" -Level Warning -Tab "Chocolatey"
                Update-WPFChocoStatus -Message "Cancelling scan..." -Level Warning
                try {
                    $cancelButton = Find-Control "ChocoCancelScanButton"
                    if ($cancelButton) {
                        $cancelButton.Visibility = [System.Windows.Visibility]::Collapsed
                    }
                } catch {
                    Write-LogMessage "Error hiding cancel button: $($_.Exception.Message)" -Level Warning -Tab "Chocolatey"
                }
            })
        }
        
        $chocoSelectAllButton = Find-Control "ChocoSelectAllButton"
        if ($chocoSelectAllButton) {
            $chocoSelectAllButton.Add_Click({
                $chocoUpdatesGrid = Find-Control "ChocoUpdatesGrid"
                if ($chocoUpdatesGrid -and $chocoUpdatesGrid.ItemsSource) {
                    foreach ($item in $chocoUpdatesGrid.ItemsSource) { $item.Selected = $true }
                    $chocoUpdatesGrid.Items.Refresh()
                }
            })
        }
        
        $chocoSelectNoneButton = Find-Control "ChocoSelectNoneButton"
        if ($chocoSelectNoneButton) {
            $chocoSelectNoneButton.Add_Click({
                $chocoUpdatesGrid = Find-Control "ChocoUpdatesGrid"
                if ($chocoUpdatesGrid -and $chocoUpdatesGrid.ItemsSource) {
                    foreach ($item in $chocoUpdatesGrid.ItemsSource) { $item.Selected = $false }
                    $chocoUpdatesGrid.Items.Refresh()
                }
            })
        }
        
        $chocoProcessButton = Find-Control "ChocoProcessButton"
        if ($chocoProcessButton) {
            $chocoProcessButton.Add_Click({ Start-ChocoSelectedUpdates })
        }
        
        # Winget Tab Event Handlers
        $wingetJobFileBrowseButton = Find-Control "WingetJobFileBrowseButton"
        if ($wingetJobFileBrowseButton) {
            $wingetJobFileBrowseButton.Add_Click({
                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "CSV Files (*.csv)|*.csv"
                $openFileDialog.RestoreDirectory = $true
                if ($openFileDialog.ShowDialog() -eq $true) {
                    $wingetJobFileTextBox = Find-Control "WingetJobFileTextBox"
                    if ($wingetJobFileTextBox) {
                        $wingetJobFileTextBox.Text = $openFileDialog.FileName
                        # Use dynamic theme brush instead of hardcoded black
                        $wingetJobFileTextBox.Foreground = $script:WPFMainWindow.Resources["PrimaryTextBrush"]
                        Save-WPFWingetSettings
                    }
                }
            })
        }
        
        $wingetInstallerBrowseButton = Find-Control "WingetInstallerBrowseButton"
        if ($wingetInstallerBrowseButton) {
            $wingetInstallerBrowseButton.Add_Click({
                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1"
                $openFileDialog.RestoreDirectory = $true
                $openFileDialog.Title = "Select Winget Installer Script"
                if ($openFileDialog.ShowDialog() -eq $true) {
                    $wingetInstallerTextBox = Find-Control "WingetInstallerTextBox"
                    if ($wingetInstallerTextBox) {
                        $wingetInstallerTextBox.Text = $openFileDialog.FileName
                        # Use dynamic theme brush instead of hardcoded black
                        $wingetInstallerTextBox.Foreground = $script:WPFMainWindow.Resources["PrimaryTextBrush"]
                        Save-WPFWingetSettings
                    }
                }
            })
        }
        
        $wingetScanButton = Find-Control "WingetScanButton"
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
        
        $wingetCancelScanButton = Find-Control "WingetCancelScanButton"
        if ($wingetCancelScanButton) {
            $wingetCancelScanButton.Add_Click({
                $script:WingetScanCancelled = $true
                Write-LogMessage "Winget scan cancellation requested" -Level Warning -Tab "Winget"
                Update-WPFWingetStatus -Message "Cancelling scan..." -Level Warning
                try {
                    $cancelButton = Find-Control "WingetCancelScanButton"
                    if ($cancelButton) {
                        $cancelButton.Visibility = [System.Windows.Visibility]::Collapsed
                    }
                } catch {
                    Write-LogMessage "Error hiding Winget cancel button: $($_.Exception.Message)" -Level Warning -Tab "Winget"
                }
            })
        }
        
        $wingetSelectAllButton = Find-Control "WingetSelectAllButton"
        if ($wingetSelectAllButton) {
            $wingetSelectAllButton.Add_Click({
                $wingetUpdatesGrid = Find-Control "WingetUpdatesGrid"
                if ($wingetUpdatesGrid -and $wingetUpdatesGrid.ItemsSource) {
                    foreach ($item in $wingetUpdatesGrid.ItemsSource) { $item.Selected = $true }
                    $wingetUpdatesGrid.Items.Refresh()
                }
            })
        }
        
        $wingetSelectNoneButton = Find-Control "WingetSelectNoneButton"
        if ($wingetSelectNoneButton) {
            $wingetSelectNoneButton.Add_Click({
                $wingetUpdatesGrid = Find-Control "WingetUpdatesGrid"
                if ($wingetUpdatesGrid -and $wingetUpdatesGrid.ItemsSource) {
                    foreach ($item in $wingetUpdatesGrid.ItemsSource) { $item.Selected = $false }
                    $wingetUpdatesGrid.Items.Refresh()
                }
            })
        }
        
        $wingetProcessButton = Find-Control "WingetProcessButton"
        if ($wingetProcessButton) {
            $wingetProcessButton.Add_Click({ Start-WingetSelectedUpdates })
        }
        
        # Configuration Manager Tab Event Handlers
        $cmConnectButton = Find-Control "CMConnectButton"
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
        
        $cmDisconnectButton = Find-Control "CMDisconnectButton"
        if ($cmDisconnectButton) {
            $cmDisconnectButton.Add_Click({ Disconnect-WPFConfigurationManager })
        }
        
        $cmSelectAllButton = Find-Control "CMSelectAllButton"
        if ($cmSelectAllButton) {
            $cmSelectAllButton.Add_Click({
                $cmApplicationsGrid = Find-Control "CMApplicationsGrid"
                if ($cmApplicationsGrid -and $cmApplicationsGrid.ItemsSource) {
                    foreach ($item in $cmApplicationsGrid.ItemsSource) { if ($item.PSObject.Properties.Name -contains 'Selected') { $item.Selected = $true } }
                    $cmApplicationsGrid.Items.Refresh()
                    # Update button states after selection change
                    Update-WPFCMButtonStates
                }
            })
        }
        
        $cmSelectNoneButton = Find-Control "CMSelectNoneButton"
        if ($cmSelectNoneButton) {
            $cmSelectNoneButton.Add_Click({
                $cmApplicationsGrid = Find-Control "CMApplicationsGrid"
                if ($cmApplicationsGrid -and $cmApplicationsGrid.ItemsSource) {
                    foreach ($item in $cmApplicationsGrid.ItemsSource) { if ($item.PSObject.Properties.Name -contains 'Selected') { $item.Selected = $false } }
                    $cmApplicationsGrid.Items.Refresh()
                    # Update button states after selection change
                    Update-WPFCMButtonStates
                }
            })
        }
        
        $cmProcessButton = Find-Control "CMProcessButton"
        if ($cmProcessButton) {
            $cmProcessButton.Add_Click({ Start-WPFCMPackageUpdate })
        }
        

        
        # CM Text Box Event Handlers for persistence (using LostFocus instead of TextChanged to avoid crashes)
        $cmServerTextBox = Find-Control "CMServerTextBox"
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
        
        $cmSiteCodeTextBox = Find-Control "CMSiteCodeTextBox"
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
        $puScanButton = Find-Control "PUScanButton"
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
        
        $puDisconnectButton = Find-Control "PUDisconnectButton"
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
        $puLoadConfigsButton = Find-Control "PULoadConfigsButton"
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
        
        $puSelectAllButton = Find-Control "PUSelectAllButton"
        if ($puSelectAllButton) {
            $puSelectAllButton.Add_Click({
                $puFlexAppsGrid = Find-Control "PUFlexAppsGrid"
                if ($puFlexAppsGrid -and $puFlexAppsGrid.ItemsSource) {
                    foreach ($item in $puFlexAppsGrid.ItemsSource) {
                        $item.Selected = $true
                    }
                }
            })
        }
        
        $puSelectNoneButton = Find-Control "PUSelectNoneButton"
        if ($puSelectNoneButton) {
            $puSelectNoneButton.Add_Click({
                $puFlexAppsGrid = Find-Control "PUFlexAppsGrid"
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
        
        $puProcessButton = Find-Control "PUProcessButton"
        if ($puProcessButton) {
            $puProcessButton.Add_Click({ Process-SelectedFlexApps })
        }
        
        # Settings Tab Event Handlers
        $settingsTestConnectionButton = Find-Control "SettingsTestConnectionButton"
        if ($settingsTestConnectionButton) {
            $settingsTestConnectionButton.Add_Click({ Test-GlobalSettings })
        }
        
        $settingsFlexAppClientBrowseButton = Find-Control "SettingsFlexAppClientBrowseButton"
        if ($settingsFlexAppClientBrowseButton) {
            $settingsFlexAppClientBrowseButton.Add_Click({
                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "Executable Files (*.exe)|*.exe"
                $openFileDialog.Title = "Select FlexApp Client Executable"
                if ($openFileDialog.ShowDialog() -eq $true) {
                    $settingsFlexAppClientTextBox = Find-Control "SettingsFlexAppClientTextBox"
                    if ($settingsFlexAppClientTextBox) {
                        $settingsFlexAppClientTextBox.Text = $openFileDialog.FileName
                    }
                }
            })
        }
        
        $settingsDefaultFileBrowseButton = Find-Control "SettingsDefaultFileBrowseButton"
        if ($settingsDefaultFileBrowseButton) {
            $settingsDefaultFileBrowseButton.Add_Click({
                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "All Files (*.*)|*.*"
                $openFileDialog.Title = "Select Default File"
                if ($openFileDialog.ShowDialog() -eq $true) {
                    $settingsDefaultFileTextBox = Find-Control "SettingsDefaultFileTextBox"
                    if ($settingsDefaultFileTextBox) {
                        $settingsDefaultFileTextBox.Text = $openFileDialog.FileName
                    }
                }
            })
        }
        
        $settingsPasswordFileBrowseButton = Find-Control "SettingsPasswordFileBrowseButton"
        if ($settingsPasswordFileBrowseButton) {
            $settingsPasswordFileBrowseButton.Add_Click({
                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
                $openFileDialog.Title = "Select Password File"
                if ($openFileDialog.ShowDialog() -eq $true) {
                    $settingsPasswordFileTextBox = Find-Control "SettingsPasswordFileTextBox"
                    if ($settingsPasswordFileTextBox) {
                        $settingsPasswordFileTextBox.Text = $openFileDialog.FileName
                    }
                }
            })
        }
        
        $settingsAESKeyFileBrowseButton = Find-Control "SettingsAESKeyFileBrowseButton"
        if ($settingsAESKeyFileBrowseButton) {
            $settingsAESKeyFileBrowseButton.Add_Click({
                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
                $openFileDialog.Title = "Select AES Key File"
                if ($openFileDialog.ShowDialog() -eq $true) {
                    $settingsAESKeyFileTextBox = Find-Control "SettingsAESKeyFileTextBox"
                    if ($settingsAESKeyFileTextBox) {
                        $settingsAESKeyFileTextBox.Text = $openFileDialog.FileName
                    }
                }
            })
        }
        
        $settingsTempPathBrowseButton = Find-Control "SettingsTempPathBrowseButton"
        if ($settingsTempPathBrowseButton) {
            $settingsTempPathBrowseButton.Add_Click({
                $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
                $folderDialog.Description = "Select Temp Path"
                if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $settingsTempPathTextBox = Find-Control "SettingsTempPathTextBox"
                    if ($settingsTempPathTextBox) {
                        $settingsTempPathTextBox.Text = $folderDialog.SelectedPath
                    }
                }
            })
        }
        
        $settingsSaveButton = Find-Control "SettingsSaveButton"
        if ($settingsSaveButton) {
            $settingsSaveButton.Add_Click({ Save-WPFGlobalSettings })
        }
        
        # Reset to defaults button
        $settingsResetButton = Find-Control "SettingsResetButton"
        if ($settingsResetButton) {
            $settingsResetButton.Add_Click({ 
                $result = [System.Windows.MessageBox]::Show("Are you sure you want to reset all settings to defaults?", "Confirm Reset", "YesNo", "Question")
                if ($result -eq "Yes") {
                    Reset-WPFGlobalSettings
                }
            })
        }
        
        # Cancel all & restart service button
        $settingsCancelRestartButton = Find-Control "SettingsCancelRestartButton"
        if ($settingsCancelRestartButton) {
            $settingsCancelRestartButton.Add_Click({ Stop-WPFAllProcesses })
        }
        
        # Theme toggle button
        $settingsThemeToggleButton = Find-Control "SettingsThemeToggleButton"
        if ($settingsThemeToggleButton) {
            $settingsThemeToggleButton.Add_Click({ Toggle-WPFTheme })
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
                        $cmSiteCodeTextBox = Find-Control "CMSiteCodeTextBox"
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
        
        # Helper function to find controls by name
        function Find-Control {
            param([string]$ControlName)
            return $script:WPFMainWindow.FindName($ControlName)
        }
        
        # Load Chocolatey settings - no default path, user must specify
        $chocoJobFileTextBox = Find-Control "ChocoJobFileTextBox"
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
        $wingetJobFileTextBox = Find-Control "WingetJobFileTextBox"
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
        
        # Load Settings tab values and add LostFocus event handlers for auto-save
        $settingsServerTextBox = Find-Control "SettingsServerTextBox"
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
        
        $settingsServerPortTextBox = Find-Control "SettingsServerPortTextBox"
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
        
        $settingsAdminUserTextBox = Find-Control "SettingsAdminUserTextBox"
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
        
        $settingsFlexAppClientTextBox = Find-Control "SettingsFlexAppClientTextBox"
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
        
        $settingsPasswordFileTextBox = Find-Control "SettingsPasswordFileTextBox"
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
        
        $settingsAESKeyFileTextBox = Find-Control "SettingsAESKeyFileTextBox"
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
        
        $settingsTempPathTextBox = Find-Control "SettingsTempPathTextBox"
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
        
        $settingsDefaultFileTextBox = Find-Control "SettingsDefaultFileTextBox"
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
        
        $settingsPrimaryServerTextBox = Find-Control "SettingsPrimaryServerTextBox"
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
        
        $settingsProcessWaitTextBox = Find-Control "SettingsProcessWaitTextBox"
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
        
        $cmServerTextBox = Find-Control "CMServerTextBox"
        if ($cmServerTextBox) {
            if (![string]::IsNullOrWhiteSpace($script:Config.CMSettings.SiteServer)) {
                $cmServerTextBox.Text = $script:Config.CMSettings.SiteServer
            } else {
                $cmServerTextBox.Text = "CM01.contoso.com"
            }
        }
        
        $cmSiteCodeTextBox = Find-Control "CMSiteCodeTextBox"
        if ($cmSiteCodeTextBox) {
            if (![string]::IsNullOrWhiteSpace($script:Config.CMSettings.SiteCode)) {
                $cmSiteCodeTextBox.Text = $script:Config.CMSettings.SiteCode
            } else {
                $cmSiteCodeTextBox.Text = "ABC"
            }
        }
        

        
        # Initialize theme settings
        $lightModeRadio = Find-Control "LightModeRadio"
        $darkModeRadio = Find-Control "DarkModeRadio"
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
        
        Write-LogMessage "WPF settings initialized successfully" -Level Info
        
        # Test progress bars
        Write-LogMessage "Testing status labels..." -Level Info
        
        $chocoProgressBar = Find-Control "ChocoScanProgressBar"
        $wingetProgressBar = Find-Control "WingetScanProgressBar"
        
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
        $statusLabel = Find-Control "SettingsGlobalStatusLabel"
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

