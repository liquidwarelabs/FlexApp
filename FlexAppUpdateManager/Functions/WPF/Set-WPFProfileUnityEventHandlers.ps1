# Add missing event handlers for ProfileUnity buttons
function Set-WPFProfileUnityEventHandlers {
    [CmdletBinding()]
    param()
    
    try {
        # Set up grid events for real-time button state updates
        $grid = Find-Control "PUFlexAppsGrid"
        if ($grid) {
            # Add multiple event handlers to catch checkbox changes
            $grid.Add_CellEditEnding({
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                    Update-WPFProfileUnityButtonStates
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
            
            # Monitor mouse clicks on the grid
            $grid.Add_PreviewMouseUp({
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                    Update-WPFProfileUnityButtonStates
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
            
            # Monitor for any changes to the grid items
            $grid.Add_CurrentCellChanged({
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                    Update-WPFProfileUnityButtonStates
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
            
            # Add a timer-based fallback to periodically check selection state (less frequent)
            $checkTimer = New-Object System.Windows.Threading.DispatcherTimer
            $checkTimer.Interval = [TimeSpan]::FromSeconds(2)
            $checkTimer.Add_Tick({
                Update-WPFProfileUnityButtonStates
            })
            $checkTimer.Start()
            
            # Store timer reference for cleanup
            $script:PUButtonStateTimer = $checkTimer
        }
        
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
                        # Use only filter names for display/binding
                        $filterNames = @()
                        foreach ($f in $filters) { if ($null -ne $f.Name -and $f.Name -ne '') { $filterNames += $f.Name } }
                        $filterNames = $filterNames | Sort-Object -Unique
                        # Update filter column with available filters
                        $filterColumn = ($grid.Columns | Where-Object { $_.Header -eq "Filter" } | Select-Object -First 1)
                        if ($filterColumn) {
                            # Convert to ComboBox column for editing
                            $comboBoxColumn = New-Object System.Windows.Controls.DataGridComboBoxColumn
                            $comboBoxColumn.Header = "Filter"
                            $comboBoxColumn.Width = 200
                            $comboBoxColumn.ItemsSource = $filterNames
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
                    foreach ($item in $grid.ItemsSource) { $item.Selected = $true }
                    $grid.Items.Refresh()
                    
                    # Update button states after selection
                    Update-WPFProfileUnityButtonStates
                }
            })
        }
        
        # Select None Button
        $selectNoneButton = Find-Control "PUSelectNoneButton"
        if ($selectNoneButton) {
            $selectNoneButton.Add_Click({
                $grid = Find-Control "PUFlexAppsGrid"
                if ($grid -and $grid.ItemsSource) {
                    foreach ($item in $grid.ItemsSource) { $item.Selected = $false }
                    $grid.Items.Refresh()
                    
                    # Update button states after deselection
                    Update-WPFProfileUnityButtonStates
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
                        $previewMessage += "- $($item.Name): $($item.CurrentVersion) -> $($item.NewVersion)`n"
                        if ($item.Filter) {
                            $previewMessage += "  Filter: $($item.Filter)`n"
                        }
                        $previewMessage += "  Sequence: $($item.Sequence)`n`n"
                    }
                    
                    $previewMessage += "Total items to update: $($selectedItems.Count)"
                    
                    # Show preview dialog with copy-to-clipboard button
                    Show-WPFPreviewDialog -Text $previewMessage
                    
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
                        # Call the actual commit function
                        Start-WPFProfileUnityCommit
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
