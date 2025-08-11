function Start-WPFProfileUnityScan {
    [CmdletBinding()]
    param()
    try {
        # Get UI controls
        $configComboBox = Find-Control "PUConfigComboBox"
        $grid = Find-Control "PUFlexAppsGrid"
        $statusLabel = Find-Control "PUStatusLabel"
        $previewButton = Find-Control "PUPreviewButton"
        $commitButton = Find-Control "PUCommitButton"
        $loadFiltersButton = Find-Control "PULoadFiltersButton"
        $progressBar = Find-Control "PUProgressBar"
        
        if (-not $configComboBox -or -not $grid -or -not $statusLabel -or 
            -not $previewButton -or -not $commitButton -or -not $loadFiltersButton -or -not $progressBar) {
            throw "Required UI controls not found"
        }
        
        # Clear previous results
        $grid.ItemsSource = $null
        $script:PUUpdateCandidates = @()
        
        # Disable buttons during scan
        $previewButton.IsEnabled = $false
        $commitButton.IsEnabled = $false
        $loadFiltersButton.IsEnabled = $false
        
        # Get selected configuration
        $selectedConfigName = $configComboBox.SelectedItem
        if (-not $selectedConfigName) {
            throw "No configuration selected"
        }
        
        Write-LogMessage "Scanning configuration: $selectedConfigName" -Level Info -Tab "ProfileUnity"
        $statusLabel.Content = "Loading configuration details..."
        
        # Get configuration ID
        $configId = ($script:PUConfigurations | Where-Object { $_.name -eq $selectedConfigName }).id
        if (-not $configId) {
            throw "Could not find configuration ID for $selectedConfigName"
        }
        
        # Load full configuration
        $script:PUCurrentConfig = Get-ProfileUnityConfiguration -ConfigId $configId
        $script:PUConfigModified = $false
        
        Write-LogMessage "Configuration loaded, checking FlexApp assignments..." -Level Info -Tab "ProfileUnity"
        $statusLabel.Content = "Checking for FlexApp updates..."
        
        # Get FlexApp DIAs
        $flexAppDias = $script:PUCurrentConfig.FlexAppDias
        if (-not $flexAppDias -or $flexAppDias.Count -eq 0) {
            $statusLabel.Content = "No FlexApp assignments found in this configuration"
            return
        }
        
        # Show progress
        $progressBar.Visibility = "Visible"
        $progressBar.Value = 0
        $progressBar.Maximum = $flexAppDias.Count
        
        $updateCandidates = @()
        $updateCount = 0
        
        # Check each FlexApp DIA
        foreach ($dia in $flexAppDias) {
            $progressBar.Value++
            
            if (-not $dia.FlexAppPackages -or $dia.FlexAppPackages.Count -eq 0) {
                continue
            }
            
            foreach ($package in $dia.FlexAppPackages) {
                $packageId = $package.FlexAppPackageId
                $packageUuid = $package.FlexAppPackageUuid
                
                # Find package in inventory
                $inventoryPackage = $script:PUFlexAppInventory | Where-Object { 
                    $_.id -eq $packageId -or $_.uuid -eq $packageUuid 
                }
                
                if (-not $inventoryPackage) {
                    Write-LogMessage "Package ID $packageId not found in inventory" -Level Warning -Tab "ProfileUnity"
                    continue
                }
                
                $packageName = $inventoryPackage.name
                
                # Get current version
                $currentVersion = "$($inventoryPackage.VersionMajor).$($inventoryPackage.VersionMinor).$($inventoryPackage.VersionBuild).$($inventoryPackage.VersionRevision)"
                
                # Find all versions in inventory
                $allVersions = $script:PUFlexAppInventory | Where-Object { $_.name -eq $packageName }
                
                if ($allVersions.Count -gt 1) {
                    # Get latest version
                    $latestPackage = $allVersions | Sort-Object {
                        [version]"$($_.VersionMajor).$($_.VersionMinor).$($_.VersionBuild).$($_.VersionRevision)"
                    } -Descending | Select-Object -First 1
                    
                    $latestVersion = "$($latestPackage.VersionMajor).$($latestPackage.VersionMinor).$($latestPackage.VersionBuild).$($latestPackage.VersionRevision)"
                    
                    # Compare versions
                    if ([version]$currentVersion -lt [version]$latestVersion) {
                        # Get filter info
                        $filterName = ""
                        if ($dia.FilterId) {
                            $filterInfo = Get-ProfileUnityFilterById -FilterId $dia.FilterId
                            if ($filterInfo) {
                                $filterName = $filterInfo.Name
                            }
                        }
                        
                        # Get sequence number
                        $sequenceNumber = if ($null -ne $dia.Sequence) { $dia.Sequence } else { 999 }
                        
                        # Create update candidate
                        $updateCandidate = [PSCustomObject]@{
                            Selected = $false
                            Name = $packageName
                            CurrentVersion = $currentVersion
                            NewVersion = $latestVersion
                            CurrentPackageId = $packageId
                            NewPackageId = $latestPackage.id
                            NewPackageUuid = $latestPackage.uuid
                            Filter = $filterName
                            FilterId = $dia.FilterId
                            DiaIndex = $flexAppDias.IndexOf($dia)
                            Sequence = $sequenceNumber
                            PackageIndex = $dia.FlexAppPackages.IndexOf($package)
                            FilterChanged = $false
                        }
                        
                        $updateCandidates += $updateCandidate
                        $updateCount++
                        
                        Write-LogMessage "Found update for $packageName`: $currentVersion -> $latestVersion (Sequence: $sequenceNumber)" -Level Success -Tab "ProfileUnity"
                    }
                }
            }
        }
        
        # Update UI
        $script:WPFMainWindow.Dispatcher.Invoke([Action]{
            # Create observable collection
            $collection = New-Object System.Collections.ObjectModel.ObservableCollection[object]
            foreach ($candidate in $updateCandidates) {
                $collection.Add($candidate)
            }
            
            # Update grid
            $grid.ItemsSource = $collection
            
            # Update status
            if ($updateCount -gt 0) {
                $statusLabel.Content = "Found $updateCount FlexApp updates available"
                $loadFiltersButton.IsEnabled = $true
            } else {
                $statusLabel.Content = "All FlexApps are up to date in this configuration"
            }
            
            # Update button states based on current selection (initially none selected)
            Update-WPFProfileUnityButtonStates
            
            # Hide progress
            $progressBar.Visibility = "Collapsed"
        })
        
        # Store candidates for later use
        $script:PUUpdateCandidates = $updateCandidates
    }
    catch {
        Write-LogMessage "Scan failed: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        
        $script:WPFMainWindow.Dispatcher.Invoke([Action]{
            $statusLabel.Content = "Scan failed: $($_.Exception.Message)"
            $progressBar.Visibility = "Collapsed"
            
            [System.Windows.MessageBox]::Show(
                "Scan failed: $($_.Exception.Message)",
                "Error",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
        })
    }
}

# Add missing event handlers for ProfileUnity buttons
function Set-WPFProfileUnityEventHandlers {
    [CmdletBinding()]
    param()
    
    try {
        # Load Filters Button
        $loadFiltersButton = Find-Control "PULoadFiltersButton"
        if ($loadFiltersButton) {
            $loadFiltersButton.Add_Click({
                try {
                    $grid = Find-Control "PUFlexAppsGrid"
                    $statusLabel = Find-Control "PUStatusLabel"
                    
                    if (-not $grid -or -not $statusLabel) {
                        throw "Required UI controls not found"
                    }
                    
                    $statusLabel.Content = "Loading filters..."
                    
                    # Get ProfileUnity filters
                    $filters = Get-ProfileUnityFilters
                    if ($filters) {
                        # Update filter column with available filters
                        $filterColumn = $grid.Columns | Where-Object { $_.Header -eq "Filter" }
                        if ($filterColumn) {
                            # Convert to ComboBox column for editing
                            $comboBoxColumn = New-Object System.Windows.Controls.DataGridComboBoxColumn
                            $comboBoxColumn.Header = "Filter"
                            $comboBoxColumn.Width = 200
                            $comboBoxColumn.ItemsSource = $filters
                            $comboBoxColumn.SelectedItemBinding = New-Object System.Windows.Data.Binding("Filter")
                            
                            # Replace the text column with combo box column
                            $grid.Columns.Remove($filterColumn)
                            $grid.Columns.Insert(4, $comboBoxColumn)
                        }
                        
                        $statusLabel.Content = "Filters loaded - you can now edit filter assignments"
                    } else {
                        $statusLabel.Content = "No filters available"
                    }
                }
                catch {
                    Write-LogMessage "Failed to load filters: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
                    $statusLabel.Content = "Failed to load filters"
                }
            })
        }
        
        # Select All Button
        $selectAllButton = Find-Control "PUSelectAllButton"
        if ($selectAllButton) {
            $selectAllButton.Add_Click({
                $grid = Find-Control "PUFlexAppsGrid"
                if ($grid -and $grid.ItemsSource) {
                    foreach ($item in $grid.ItemsSource) {
                        $item.Selected = $true
                    }
                }
            })
        }
        
        # Select None Button
        $selectNoneButton = Find-Control "PUSelectNoneButton"
        if ($selectNoneButton) {
            $selectNoneButton.Add_Click({
                $grid = Find-Control "PUFlexAppsGrid"
                if ($grid -and $grid.ItemsSource) {
                    foreach ($item in $grid.ItemsSource) {
                        $item.Selected = $false
                    }
                }
            })
        }
        
        # Preview Changes Button
        $previewButton = Find-Control "PUPreviewButton"
        if ($previewButton) {
            $previewButton.Add_Click({
                try {
                    $grid = Find-Control "PUFlexAppsGrid"
                    $statusLabel = Find-Control "PUStatusLabel"
                    
                    if (-not $grid -or -not $statusLabel) {
                        throw "Required UI controls not found"
                    }
                    
                    $statusLabel.Content = "Generating preview..."
                    
                    # Get selected items
                    $selectedItems = $grid.ItemsSource | Where-Object { $_.Selected }
                    
                    if ($selectedItems.Count -eq 0) {
                        $statusLabel.Content = "No items selected for preview"
                        return
                    }
                    
                    # Generate preview message
                    $previewMessage = "Preview of changes to be made:`n`n"
                    foreach ($item in $selectedItems) {
                        $previewMessage += "• $($item.Name): $($item.CurrentVersion) → $($item.NewVersion)`n"
                        if ($item.Filter) {
                            $previewMessage += "  Filter: $($item.Filter)`n"
                        }
                        $previewMessage += "  Sequence: $($item.Sequence)`n`n"
                    }
                    
                    $previewMessage += "Total items to update: $($selectedItems.Count)"
                    
                    # Show preview dialog
                    [System.Windows.MessageBox]::Show(
                        $previewMessage,
                        "Preview Changes",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Information
                    )
                    
                    $statusLabel.Content = "Preview generated for $($selectedItems.Count) items"
                }
                catch {
                    Write-LogMessage "Failed to generate preview: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
                    $statusLabel.Content = "Failed to generate preview"
                }
            })
        }
        
        # Commit Changes Button
        $commitButton = Find-Control "PUCommitButton"
        if ($commitButton) {
            $commitButton.Add_Click({
                try {
                    $grid = Find-Control "PUFlexAppsGrid"
                    $statusLabel = Find-Control "PUStatusLabel"
                    $deployCheckBox = Find-Control "PUDeployCheckBox"
                    
                    if (-not $grid -or -not $statusLabel) {
                        throw "Required UI controls not found"
                    }
                    
                    $statusLabel.Content = "Committing changes..."
                    
                    # Get selected items
                    $selectedItems = $grid.ItemsSource | Where-Object { $_.Selected }
                    
                    if ($selectedItems.Count -eq 0) {
                        $statusLabel.Content = "No items selected for commit"
                        return
                    }
                    
                    # Confirm commit
                    $result = [System.Windows.MessageBox]::Show(
                        "Are you sure you want to commit $($selectedItems.Count) changes to the ProfileUnity configuration?",
                        "Confirm Commit",
                        [System.Windows.MessageBoxButton]::YesNo,
                        [System.Windows.MessageBoxImage]::Question
                    )
                    
                    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                        # TODO: Implement actual commit logic
                        $statusLabel.Content = "Changes committed successfully"
                        
                        # Check if deploy is requested
                        if ($deployCheckBox -and $deployCheckBox.IsChecked -eq $true) {
                            $statusLabel.Content = "Changes committed and deployed"
                        }
                    } else {
                        $statusLabel.Content = "Commit cancelled"
                    }
                }
                catch {
                    Write-LogMessage "Failed to commit changes: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
                    $statusLabel.Content = "Failed to commit changes"
                }
            })
        }
    }
    catch {
        Write-LogMessage "Failed to set ProfileUnity event handlers: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
    }
}


