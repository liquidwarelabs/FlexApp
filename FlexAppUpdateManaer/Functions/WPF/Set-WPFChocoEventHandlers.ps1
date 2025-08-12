function Set-WPFChocoEventHandlers {
    [CmdletBinding()]
    param()
    
    try {
        # Set up grid events for real-time button state updates
        $grid = Find-Control "ChocoUpdatesGrid"
        if ($grid) {
            Write-LogMessage "Setting up Chocolatey grid event handlers" -Level Info -Tab "Chocolatey"
            
            # Add multiple event handlers to catch checkbox changes
            $grid.Add_CellEditEnding({
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                    Update-WPFChocoButtonStates
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
            
            # Monitor mouse clicks on the grid
            $grid.Add_PreviewMouseUp({
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                    Update-WPFChocoButtonStates
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
            
            # Monitor for any changes to the grid items
            $grid.Add_CurrentCellChanged({
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                    Update-WPFChocoButtonStates
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
            
            # Add a timer-based fallback to periodically check selection state
            $checkTimer = New-Object System.Windows.Threading.DispatcherTimer
            $checkTimer.Interval = [TimeSpan]::FromSeconds(2)
            $checkTimer.Add_Tick({
                # Only update button states if window is still initialized
                if ($script:WPFMainWindow -and -not $script:WPFMainWindow.Dispatcher.HasShutdownStarted) {
                    Update-WPFChocoButtonStates
                } else {
                    # Stop timer if window is disposed
                    $this.Stop()
                }
            })
            $checkTimer.Start()
            
            # Store timer reference for cleanup
            $script:ChocoButtonStateTimer = $checkTimer
            
            Write-LogMessage "Chocolatey grid event handlers configured successfully" -Level Success -Tab "Chocolatey"
        }
        else {
            Write-LogMessage "Chocolatey grid not found, skipping event handler setup" -Level Warning -Tab "Chocolatey"
        }
        
        # Select All Button
        $selectAllButton = Find-Control "ChocoSelectAllButton"
        if ($selectAllButton) {
            $selectAllButton.Add_Click({
                $grid = Find-Control "ChocoUpdatesGrid"
                if ($grid -and $grid.ItemsSource) {
                    foreach ($item in $grid.ItemsSource) { $item.Selected = $true }
                    $grid.Items.Refresh()
                    
                    # Update button states after selection
                    Update-WPFChocoButtonStates
                }
            })
        }
        
        # Select None Button
        $selectNoneButton = Find-Control "ChocoSelectNoneButton"
        if ($selectNoneButton) {
            $selectNoneButton.Add_Click({
                $grid = Find-Control "ChocoUpdatesGrid"
                if ($grid -and $grid.ItemsSource) {
                    foreach ($item in $grid.ItemsSource) { $item.Selected = $false }
                    $grid.Items.Refresh()
                    
                    # Update button states after deselection
                    Update-WPFChocoButtonStates
                }
            })
        }
        
    } catch {
        Write-LogMessage "Error setting up Chocolatey event handlers: $($_.Exception.Message)" -Level Error -Tab "Chocolatey"
    }
}
