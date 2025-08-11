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
        $xamlPath = Join-Path $PSScriptRoot "..\EditApplicationsDialog.xaml"
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
                Write-LogMessage "Continue Export button clicked" -Level Info -Tab "Configuration Manager"
                
                # Always set result to true for Continue Export - validation will be handled by calling function
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
                        param($buttonSender, $eventArgs)
                        
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
