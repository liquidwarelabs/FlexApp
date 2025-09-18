# File: WPF\Functions\Show-WPFEditApplicationsDialog.ps1
# ======================================================

function Show-WPFEditApplicationsDialog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Applications,
        
        [System.Windows.Window]$Owner,
        
        [switch]$UseProcessedData
    )
    
    try {
        Write-LogMessage "Opening Edit Applications dialog for $($Applications.Count) applications" -Level Info -Tab "Configuration Manager"
        
        # Convert applications to edit models
        if ($UseProcessedData) {
            # Applications are already processed data from Process-WPFSelectedApplications
            $editModels = ConvertFrom-ProcessedApplicationData -ProcessedApps $Applications
        } else {
            # Applications are raw CM applications, need full conversion
            $editModels = ConvertTo-WPFApplicationEditModels -Applications $Applications
        }
        
        if (-not $editModels -or $editModels.Count -eq 0) {
            [System.Windows.MessageBox]::Show("No applications to edit.", "Information", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            return $null
        }
        
        # Create the WPF dialog window
        $dialog = New-WPFEditApplicationsWindow -Applications $editModels -Owner $Owner
        
        # Show the dialog and get result
        $result = $dialog.ShowDialog()
        
        if ($result -eq $true) {
            # User clicked Continue - validate all applications
            $validationErrors = @()
            $changedApps = @()
            
            foreach ($model in $editModels) {
                $errors = $model.GetValidationErrors()
                if ($errors.Count -gt 0) {
                    $validationErrors += "Application $($model.Index) ($($model.OriginalName)): " + ($errors -join ", ")
                }
                
                if ($model.HasChanges()) {
                    $changedApps += $model
                    Write-LogMessage "Application '$($model.OriginalName)' has changes: Name='$($model.Name)', Version='$($model.Version)', Installer='$($model.Installer)', Args='$($model.InstallerArgs)'" -Level Info -Tab "Configuration Manager"
                }
            }
            
            if ($validationErrors.Count -gt 0) {
                $errorMessage = "Please fix the following errors before continuing:`n`n" + ($validationErrors -join "`n")
                [System.Windows.MessageBox]::Show($errorMessage, "Validation Errors", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                return $null
            }
            
            # Log summary
            Write-LogMessage "Edit dialog completed successfully. Changed applications: $($changedApps.Count)" -Level Success -Tab "Configuration Manager"
            
            # Return the edited models
            return $editModels
        }
        else {
            Write-LogMessage "Edit dialog was cancelled by user" -Level Info -Tab "Configuration Manager"
            return $null
        }
    }
    catch {
        Write-LogMessage "Error showing Edit Applications dialog: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
        [System.Windows.MessageBox]::Show("Error opening edit dialog: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return $null
    }
}

function New-WPFEditApplicationsWindow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Applications,
        
        [System.Windows.Window]$Owner
    )
    
    try {
        # Load the XAML
        $xamlPath = Join-Path $PSScriptRoot "..\..\GUI\EditApplicationsDialog.xaml"
        if (-not (Test-Path $xamlPath)) {
            throw "XAML file not found: $xamlPath"
        }
        
        [xml]$xamlContent = Get-Content $xamlPath -Raw
        $reader = New-Object System.Xml.XmlNodeReader $xamlContent
        $dialog = [System.Windows.Markup.XamlReader]::Load($reader)
        
        if (-not $dialog) {
            throw "Failed to load XAML dialog"
        }
        
        # Set owner if provided and inherit theme resources
        if ($Owner) {
            $dialog.Owner = $Owner
            
            # Copy theme resources from the parent window to the dialog
            try {
                $themeResources = @(
                    "PrimaryBackgroundBrush",
                    "SecondaryBackgroundBrush", 
                    "PrimaryTextBrush",
                    "SecondaryTextBrush",
                    "BorderBrush",
                    "PrimaryButtonBrush",
                    "PrimaryButtonHoverBrush",
                    "PrimaryButtonPressedBrush",
                    "SecondaryButtonBrush",
                    "SecondaryButtonHoverBrush"
                )
                
                foreach ($resourceKey in $themeResources) {
                    if ($Owner.Resources.Contains($resourceKey)) {
                        $dialog.Resources[$resourceKey] = $Owner.Resources[$resourceKey]
                    }
                }
                
                Write-LogMessage "Inherited theme resources from parent window" -Level Info -Tab "Configuration Manager"
            }
            catch {
                Write-LogMessage "Could not inherit theme resources: $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
            }
        }
        
        # Find controls
        $applicationsControl = $dialog.FindName("ApplicationsItemsControl")
        $continueButton = $dialog.FindName("ContinueButton")
        $cancelButton = $dialog.FindName("CancelButton")
        $exportSelectedButton = $dialog.FindName("ExportSelectedButton")
        
        if (-not $applicationsControl) {
            throw "Could not find ApplicationsItemsControl in XAML"
        }
        
        # Create observable collection for data binding
        $observableCollection = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
        foreach ($app in $Applications) {
            $observableCollection.Add($app)
        }
        
        # Set data context
        $dialog.DataContext = @{ Applications = $observableCollection }
        $applicationsControl.ItemsSource = $observableCollection
        
        # Store reference to applications for validation
        $dialog | Add-Member -MemberType NoteProperty -Name "EditModels" -Value $Applications
        
        # Add event handlers
        $continueButton.Add_Click({
            try {
                Write-LogMessage "Process Selected Updates button clicked" -Level Info -Tab "Configuration Manager"
                
                # Always set result to true for Process Selected Updates - validation will be handled by calling function
                $dialog.DialogResult = $true
                $dialog.Close()
            }
            catch {
                Write-LogMessage "Error in Continue button click: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
                [System.Windows.MessageBox]::Show("Error processing continue: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        })
        
        $cancelButton.Add_Click({
            Write-LogMessage "Cancel button clicked" -Level Info -Tab "Configuration Manager"
            $dialog.DialogResult = $false
            $dialog.Close()
        })
        
        # Export Selected button handler
        $exportSelectedButton.Add_Click({
            try {
                Write-LogMessage "Export Selected button clicked" -Level Info -Tab "Configuration Manager"
                
                # Get current values from the edit models and format as FlexApp packages
                # IMPORTANT: Property order MUST match LaunchNotepadPP2.json exactly
                $exportData = @()
                foreach ($model in $Applications) {
                    # Create ordered hashtable to preserve property order
                    $package = [ordered]@{
                        LogPath = $null
                        LogLevel = $null
                        Name = $model.Name
                        Type = $null
                        Path = $null
                        PathUsername = $null
                        PathPassword = $null
                        InitiatingUsername = $null
                        SizeGb = $null
                        Fixed = $null
                        Test = "False"
                        PuAddress = $null
                        PuUsername = $null
                        PuPassword = $null
                        Installer = $model.Installer
                        InstallerUsername = $null
                        InstallerPassword = $null
                        InstallerArgs = $model.InstallerArgs
                        InstallerExitCode = $null
                        InstallerTimeoutMs = $null
                        NoHCCapture = $null
                        NoSystemRestore = $null
                        AltRestoreCmd = $null
                        AltRestoreCmdArgs = $null
                        WaitAfterInstallerExitsMs = $null
                        DontCopyInstallerLocal = $null
                        CopyInstallerFolderLocal = $null
                        InstallerFolder = $null
                        Installer2 = $null
                        InstallerArgs2 = $null
                        InstallerExitCode2 = $null
                        Installer3 = $null
                        InstallerArgs3 = $null
                        InstallerExitCode3 = $null
                        Installer4 = $null
                        InstallerArgs4 = $null
                        InstallerExitCode4 = $null
                        Installer5 = $null
                        InstallerArgs5 = $null
                        InstallerExitCode5 = $null
                        Installer6 = $null
                        InstallerArgs6 = $null
                        InstallerExitCode6 = $null
                        Installer7 = $null
                        InstallerArgs7 = $null
                        InstallerExitCode7 = $null
                        Installer8 = $null
                        InstallerArgs8 = $null
                        InstallerExitCode8 = $null
                        Installer9 = $null
                        InstallerArgs9 = $null
                        InstallerExitCode9 = $null
                        Installer10 = $null
                        InstallerArgs10 = $null
                        InstallerExitCode10 = $null
                        PreActivationScript = $null
                        PostActivationScript = $null
                        PreDeactivationScript = $null
                        PostDeactivationScript = $null
                        NoCallToHome = $null
                        PackageVersion = $model.Version
                        DontCreateFlexAppOne = $null
                        DontCreateFlexAppOneV1 = $null
                        DontCreateFlexAppOneV2 = $null
                        FlexAppOneCliOverride = $null
                        DontCaptureUserProfileData = $null
                        DontCaptureUserRegistry = $null
                        DontCapture = $null
                        PackagesXml = $null
                        PuConfiguration = $null
                        PuFilter = $null
                        PuDescription = $null
                        CustomStorageUrl = $null
                        AzureMaximumConcurrency = $null
                        AzureInitialTransferSizeMb = $null
                        AzureMaximumTransferSizeMb = $null
                    }
                    $exportData += $package
                }
                
                # Show save file dialog
                $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
                $saveFileDialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
                $saveFileDialog.Title = "Export Applications"
                $saveFileDialog.FileName = "FlexAppPackages_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                $saveFileDialog.DefaultExt = ".json"
                
                if ($saveFileDialog.ShowDialog() -eq $true) {
                    $exportPath = $saveFileDialog.FileName
                    Write-LogMessage "Exporting $($exportData.Count) applications as FlexApp packages to: $exportPath" -Level Info -Tab "Configuration Manager"
                    
                    # Export to JSON with FlexApp package format
                    $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $exportPath -Force -Encoding UTF8
                    
                    Write-LogMessage "FlexApp package export completed successfully" -Level Success -Tab "Configuration Manager"
                    [System.Windows.MessageBox]::Show("Successfully exported $($exportData.Count) applications as FlexApp packages to:`n$exportPath", "Export Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                }
            }
            catch {
                Write-LogMessage "Error exporting applications: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
                [System.Windows.MessageBox]::Show("Error exporting applications: $($_.Exception.Message)", "Export Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        })
        
        # Add Browse button handlers after the dialog is rendered
        $dialog.Add_ContentRendered({
            try {
                Write-LogMessage "Dialog content rendered, setting up browse buttons" -Level Info -Tab "Configuration Manager"
                
                # Find all browse buttons in the window using a simple approach
                $browseButtons = @()
                $allButtons = Find-VisualChild -Parent $dialog -Type ([System.Windows.Controls.Button])
                foreach ($button in $allButtons) {
                    if ($button.Content -eq "Browse...") {
                        $browseButtons += $button
                    }
                }
                
                foreach ($browseButton in $browseButtons) {
                    $browseButton.Add_Click({
                        param($buttonSender, $buttonEventArgs)
                        
                        try {
                            $model = $buttonSender.Tag
                            if ($model) {
                                $openDialog = New-Object Microsoft.Win32.OpenFileDialog
                                $openDialog.Title = "Select Installer for $($model.Name)"
                                $openDialog.Filter = "Executable Files (*.exe)|*.exe|MSI Files (*.msi)|*.msi|All Files (*.*)|*.*"
                                $openDialog.InitialDirectory = Split-Path $model.Installer -Parent
                                
                                if ($openDialog.ShowDialog() -eq $true) {
                                    $model.Installer = $openDialog.FileName
                                    Write-LogMessage "Updated installer path for '$($model.Name)': $($openDialog.FileName)" -Level Info -Tab "Configuration Manager"
                                    
                                    # Update the UI
                                    $bindingExpression = $buttonSender.GetBindingExpression([System.Windows.Controls.Button]::TagProperty)
                                    if ($bindingExpression) {
                                        $bindingExpression.UpdateTarget()
                                    }
                                }
                            }
                        }
                        catch {
                            Write-LogMessage "Error in Browse button click: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
                            [System.Windows.MessageBox]::Show("Error browsing for file: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                        }
                    })
                }
                
                Write-LogMessage "Added click handlers to $($browseButtons.Count) browse buttons" -Level Info -Tab "Configuration Manager"
            }
            catch {
                Write-LogMessage "Error setting up browse button handlers: $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
            }
        })
        
        Write-LogMessage "Created Edit Applications dialog with $($Applications.Count) applications" -Level Success -Tab "Configuration Manager"
        return $dialog
    }
    catch {
        Write-LogMessage "Error creating Edit Applications dialog: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
        throw
    }
}

# Helper function to find visual children
function Find-VisualChild {
    param(
        [System.Windows.DependencyObject]$Parent,
        [System.Type]$Type
    )
    
    $children = @()
    if ($Parent) {
        $childrenCount = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($Parent)
        for ($i = 0; $i -lt $childrenCount; $i++) {
            $child = [System.Windows.Media.VisualTreeHelper]::GetChild($Parent, $i)
            if ($child -and $child.GetType() -eq $Type) {
                $children += $child
            }
            $children += Find-VisualChild -Parent $child -Type $Type
        }
    }
    return $children
}
