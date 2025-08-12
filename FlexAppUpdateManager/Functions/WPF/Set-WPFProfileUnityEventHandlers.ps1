# Add missing event handlers for ProfileUnity buttons
function Set-WPFProfileUnityEventHandlers {
    [CmdletBinding()]
    param()
    
    Write-LogMessage "Setting up ProfileUnity event handlers..." -Level Info -Tab "ProfileUnity"
    
    # Ensure WPF assemblies are loaded for DispatcherTimer
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
        Add-Type -AssemblyName PresentationCore -ErrorAction SilentlyContinue
        Add-Type -AssemblyName WindowsBase -ErrorAction SilentlyContinue
        Write-Host "WPF assemblies loaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Could not load WPF assemblies: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host "About to enter try block..." -ForegroundColor Cyan
    
    try {
        Write-Host "Setting up ProfileUnity grid event handlers" -ForegroundColor Yellow
        Write-LogMessage "Setting up ProfileUnity grid event handlers" -Level Info -Tab "ProfileUnity"
        
        # Set up timer to ensure buttons stay active
        $checkTimer = New-Object System.Windows.Threading.DispatcherTimer
        $checkTimer.Interval = [TimeSpan]::FromSeconds(2)
        $checkTimer.Add_Tick({
            try {
                # Only update button states if window is still initialized
                if ($script:WPFMainWindow -and -not $script:WPFMainWindow.Dispatcher.HasShutdownStarted) {
                    Update-WPFProfileUnityButtonStates
                } else {
                    # Stop timer if window is disposed
                    Write-LogMessage "DEBUG: Timer stopping - window disposed" -Level Info -Tab "ProfileUnity"
                    $this.Stop()
                }
            } catch {
                Write-LogMessage "ERROR: Timer tick failed: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
                # Don't stop the timer on error, just log it
            }
        })
        $checkTimer.Start()
        
        # Store timer reference for cleanup
        $script:PUButtonStateTimer = $checkTimer
        Write-LogMessage "ProfileUnity timer started successfully" -Level Info -Tab "ProfileUnity"
        
        # Set up grid events for real-time button state updates (if available)
        $grid = Find-Control "PUFlexAppsGrid"
        if ($grid) {
            Write-Host "ProfileUnity grid found, adding event handlers..." -ForegroundColor Green
            Write-LogMessage "ProfileUnity grid found, adding event handlers..." -Level Info -Tab "ProfileUnity"
            # Add multiple event handlers to catch checkbox changes
            $grid.Add_CellEditEnding({
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                    Update-WPFProfileUnityButtonStates
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
            
            # Monitor mouse clicks on the grid
            $grid.Add_PreviewMouseUp({
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                    # Force grid refresh to ensure binding updates
                    $grid = Find-Control "PUFlexAppsGrid"
                    if ($grid -and $grid.Items) {
                        $grid.Items.Refresh()
                    }
                    Update-WPFProfileUnityButtonStates
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
            
            # Monitor for any changes to the grid items
            $grid.Add_CurrentCellChanged({
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{

                    Update-WPFProfileUnityButtonStates
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
            
            # Add KeyUp event to catch checkbox space bar presses
            $grid.Add_KeyUp({
                param($sender, $e)
                if ($e.Key -eq [System.Windows.Input.Key]::Space) {
                    $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                        Write-LogMessage "DEBUG: Space key pressed on grid - checkbox likely toggled" -Level Info -Tab "ProfileUnity"
                        Update-WPFProfileUnityButtonStates
                    }, [System.Windows.Threading.DispatcherPriority]::Background)
                }
            })
            
            # Add CellEditEnding event to detect filter changes
            $grid.Add_CellEditEnding({
                param($sender, $e)
                try {
                    # Check if this is the Filter column
                    if ($e.Column.Header -eq "Filter" -and $e.EditingElement) {
                        Write-LogMessage "DEBUG: Filter cell edit ending" -Level Info -Tab "ProfileUnity"
                        
                        # Get the new filter value
                        $newFilterName = $null
                        if ($e.EditingElement -is [System.Windows.Controls.ComboBox]) {
                            $newFilterName = $e.EditingElement.SelectedItem
                        }
                        
                        if ($newFilterName -and $e.Row.DataContext) {
                            Write-LogMessage "DEBUG: New filter selected: '$newFilterName'" -Level Info -Tab "ProfileUnity"
                            
                            # Get filters from script scope (they should be cached)
                            $availableFilters = Get-ProfileUnityFilters
                            $selectedFilter = $availableFilters | Where-Object { $_.Name -eq $newFilterName }
                            
                            if ($selectedFilter) {
                                # Update the data item
                                $dataItem = $e.Row.DataContext
                                $dataItem.Filter = $newFilterName
                                $dataItem.FilterId = $selectedFilter.Id
                                $dataItem.FilterChanged = $true
                                Write-LogMessage "DEBUG: Updated item filter - Name: '$newFilterName', ID: '$($selectedFilter.Id)'" -Level Info -Tab "ProfileUnity"
                            }
                        }
                    }
                } catch {
                    Write-LogMessage "Error handling filter cell edit: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
                }
            })
            
            # Grid event handlers are set up, timer is already running from above
        } else {
            Write-Host "ProfileUnity grid NOT found during initialization - timer already started above" -ForegroundColor Red
            Write-LogMessage "ProfileUnity grid NOT found during initialization - timer already started above" -Level Warning -Tab "ProfileUnity"
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
                        # Use only filter names for display/binding - ensure clean strings
                        $filterNames = @()
                        foreach ($f in $filters) { 
                            if ($null -ne $f.Name -and $f.Name -ne '') { 
                                $cleanName = [string]$f.Name
                                if ($cleanName -and $cleanName -notlike "*@{*") {
                                    $filterNames += $cleanName.Trim()
                                }
                            } 
                        }
                        $filterNames = $filterNames | Sort-Object -Unique
                        
                        Write-LogMessage "Loaded $($filterNames.Count) clean filter names for dropdown" -Level Info -Tab "ProfileUnity"
                        foreach ($name in $filterNames) {
                            Write-LogMessage "Filter name: '$name'" -Level Info -Tab "ProfileUnity"
                        }
                        # Clean up any corrupted filter data first
                        foreach ($item in $grid.Items) {
                            if ($item.Filter -and $item.Filter -like "*@{*") {
                                Write-LogMessage "Cleaning corrupted filter data for $($item.Name)" -Level Warning -Tab "ProfileUnity"
                                $item.Filter = "No Filter"
                            }
                        }
                        
                        # Update filter column with available filters
                        $filterColumn = ($grid.Columns | Where-Object { $_.Header -eq "Filter" } | Select-Object -First 1)
                        if ($filterColumn) {
                            Write-LogMessage "Converting filter column to ComboBox for editing" -Level Info -Tab "ProfileUnity"
                            
                            # Create a simple text column that shows filter names cleanly
                            $textColumn = New-Object System.Windows.Controls.DataGridTextColumn
                            $textColumn.Header = "Filter"
                            $textColumn.Width = 200
                            $textColumn.Binding = New-Object System.Windows.Data.Binding("Filter")
                            $textColumn.IsReadOnly = $false
                            
                            Write-LogMessage "Created clean text column for filter display and editing" -Level Info -Tab "ProfileUnity"
                            
                            # Replace the old column with new clean text column
                            $grid.Columns.Remove($filterColumn)
                            $grid.Columns.Insert(4, $textColumn)
                            
                            Write-LogMessage "Filter column converted successfully" -Level Success -Tab "ProfileUnity"
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
                        [System.Windows.MessageBox]::Show(
                            "Please select at least one item to preview changes.",
                            "No Selection",
                            [System.Windows.MessageBoxButton]::OK,
                            [System.Windows.MessageBoxImage]::Warning
                        )
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
        Write-LogMessage "DEBUG: Looking for PUCommitButton..." -Level Info -Tab "ProfileUnity"
        $commitButton = Find-Control "PUCommitButton"
        Write-LogMessage "DEBUG: PUCommitButton found = $($commitButton -ne $null)" -Level Info -Tab "ProfileUnity"
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
                        [System.Windows.MessageBox]::Show(
                            "Please select at least one item to commit changes.",
                            "No Selection",
                            [System.Windows.MessageBoxButton]::OK,
                            [System.Windows.MessageBoxImage]::Warning
                        )
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
                        Write-LogMessage "DEBUG: About to call Start-WPFProfileUnityCommit..." -Level Info -Tab "ProfileUnity"
                        try {
                            Start-WPFProfileUnityCommit
                            Write-LogMessage "DEBUG: Start-WPFProfileUnityCommit completed successfully" -Level Info -Tab "ProfileUnity"
                        }
                        catch {
                            Write-LogMessage "DEBUG: Start-WPFProfileUnityCommit failed: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
                            throw
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
        
        # Load Filters Button
        Write-LogMessage "DEBUG: Setting up Load Filters button handler..." -Level Info -Tab "ProfileUnity"
        $loadFiltersButton = Find-Control "PULoadFiltersButton"
        if ($loadFiltersButton) {
            Write-LogMessage "DEBUG: Load Filters button found, attaching click handler..." -Level Info -Tab "ProfileUnity"
            $loadFiltersButton.Add_Click({
                try {
                    Write-LogMessage "DEBUG: Load Filters button clicked!" -Level Info -Tab "ProfileUnity"
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
                            # Extract only filter names for clean display
                            $filterNames = @()
                            foreach ($f in $filters) { 
                                if ($null -ne $f.Name -and $f.Name -ne '') { 
                                    $filterNames += [string]$f.Name 
                                } 
                            }
                            $comboBoxColumn.ItemsSource = $filterNames
                            $comboBoxColumn.SelectedItemBinding = New-Object System.Windows.Data.Binding("Filter")
                            
                            # Note: Filter change detection will be handled via grid event handlers
                            # since DataGridComboBoxColumn doesn't support Add_CellEditEnding directly
                            
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
        } else {
            Write-LogMessage "DEBUG: Load Filters button NOT found" -Level Warning -Tab "ProfileUnity"
        }
        
        # Select All Button
        Write-LogMessage "DEBUG: Setting up Select All button handler..." -Level Info -Tab "ProfileUnity"
        $selectAllButton = Find-Control "PUSelectAllButton"
        if ($selectAllButton) {
            Write-LogMessage "DEBUG: Select All button found, attaching click handler..." -Level Info -Tab "ProfileUnity"
            $selectAllButton.Add_Click({
                try {
                    Write-LogMessage "DEBUG: Select All button clicked!" -Level Info -Tab "ProfileUnity"
                    $grid = Find-Control "PUFlexAppsGrid"
                    if ($grid -and $grid.ItemsSource) {
                        foreach ($item in $grid.ItemsSource) {
                            $item.Selected = $true
                        }
                        $grid.Items.Refresh()
                        Write-LogMessage "All items selected" -Level Info -Tab "ProfileUnity"
                    }
                } catch {
                    Write-LogMessage "Error in Select All: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
                }
            })
        } else {
            Write-LogMessage "DEBUG: Select All button NOT found" -Level Warning -Tab "ProfileUnity"
        }
        
        # Select None Button
        Write-LogMessage "DEBUG: Setting up Select None button handler..." -Level Info -Tab "ProfileUnity"
        $selectNoneButton = Find-Control "PUSelectNoneButton"
        if ($selectNoneButton) {

            $selectNoneButton.Add_Click({
                try {

                    $grid = Find-Control "PUFlexAppsGrid"
                    if ($grid -and $grid.ItemsSource) {
                        foreach ($item in $grid.ItemsSource) {
                            $item.Selected = $false
                        }
                        $grid.Items.Refresh()
                        Write-LogMessage "All items deselected" -Level Info -Tab "ProfileUnity"
                    }
                } catch {
                    Write-LogMessage "Error in Select None: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
                }
            })
        } else {

        }

        Write-LogMessage "ProfileUnity grid event handlers configured successfully" -Level Success -Tab "ProfileUnity"
    }
    catch {
        Write-Host "*** ERROR in Set-WPFProfileUnityEventHandlers: $($_.Exception.Message) ***" -ForegroundColor Red
        Write-LogMessage "Failed to set ProfileUnity event handlers: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        Write-LogMessage "Full error details: $($_.Exception.ToString())" -Level Error -Tab "ProfileUnity"
    }
    
    Write-Host "*** EXITING Set-WPFProfileUnityEventHandlers function ***" -ForegroundColor Yellow
}
