function Set-WPFWingetEventHandlers {
    [CmdletBinding()]
    param()
    
    try {
        # Set up grid events for real-time button state updates
        $grid = Find-Control "WingetUpdatesGrid"
        if ($grid) {
            Write-LogMessage "Setting up Winget grid event handlers" -Level Info -Tab "Winget"
            
            # Add multiple event handlers to catch checkbox changes
            $grid.Add_CellEditEnding({
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                    Update-WPFWingetButtonStates
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
            
            # Monitor mouse clicks on the grid
            $grid.Add_PreviewMouseUp({
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                    Update-WPFWingetButtonStates
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
            
            # Monitor for any changes to the grid items
            $grid.Add_CurrentCellChanged({
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                    Update-WPFWingetButtonStates
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
            
            # Add a timer-based fallback to periodically check selection state
            $checkTimer = New-Object System.Windows.Threading.DispatcherTimer
            $checkTimer.Interval = [TimeSpan]::FromSeconds(2)
            $checkTimer.Add_Tick({
                # Only update button states if window is still initialized
                if ($script:WPFMainWindow -and -not $script:WPFMainWindow.Dispatcher.HasShutdownStarted) {
                    Update-WPFWingetButtonStates
                } else {
                    # Stop timer if window is disposed
                    $this.Stop()
                }
            })
            $checkTimer.Start()
            
            # Store timer reference for cleanup
            $script:WingetButtonStateTimer = $checkTimer
            
            Write-LogMessage "Winget grid event handlers configured successfully" -Level Success -Tab "Winget"
        }
        else {
            Write-LogMessage "Winget grid not found, skipping event handler setup" -Level Warning -Tab "Winget"
        }
        
        # Select All Button
        $selectAllButton = Find-Control "WingetSelectAllButton"
        if ($selectAllButton) {
            $selectAllButton.Add_Click({
                $grid = Find-Control "WingetUpdatesGrid"
                if ($grid -and $grid.ItemsSource) {
                    foreach ($item in $grid.ItemsSource) { $item.Selected = $true }
                    $grid.Items.Refresh()
                    
                    # Update button states after selection
                    Update-WPFWingetButtonStates
                }
            })
        }
        
        # Select None Button
        $selectNoneButton = Find-Control "WingetSelectNoneButton"
        if ($selectNoneButton) {
            $selectNoneButton.Add_Click({
                $grid = Find-Control "WingetUpdatesGrid"
                if ($grid -and $grid.ItemsSource) {
                    foreach ($item in $grid.ItemsSource) { $item.Selected = $false }
                    $grid.Items.Refresh()
                    
                    # Update button states after deselection
                    Update-WPFWingetButtonStates
                }
            })
        }
        
    } catch {
        Write-LogMessage "Error setting up Winget event handlers: $($_.Exception.Message)" -Level Error -Tab "Winget"
    }
}
