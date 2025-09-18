function Set-WPFCMEventHandlers {
    [CmdletBinding()]
    param()
    
    try {
        # Set up grid events for real-time button state updates
        $grid = Find-Control "CMApplicationsGrid"
        if ($grid) {
            Write-LogMessage "Setting up CM grid event handlers" -Level Info -Tab "Configuration Manager"
            
            # Add multiple event handlers to catch checkbox changes
            $grid.Add_CellEditEnding({
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                    Update-WPFCMButtonStates
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
            
            # Monitor mouse clicks on the grid
            $grid.Add_PreviewMouseUp({
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                    Update-WPFCMButtonStates
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
            
            # Monitor for any changes to the grid items
            $grid.Add_CurrentCellChanged({
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                    Update-WPFCMButtonStates
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
            
            # Add a timer-based fallback to periodically check selection state
            $checkTimer = New-Object System.Windows.Threading.DispatcherTimer
            $checkTimer.Interval = [TimeSpan]::FromSeconds(2)
            $checkTimer.Add_Tick({
                # Only update button states if window is still initialized
                if ($script:WPFMainWindow -and -not $script:WPFMainWindow.Dispatcher.HasShutdownStarted) {
                    Update-WPFCMButtonStates
                } else {
                    # Stop timer if window is disposed
                    $this.Stop()
                }
            })
            $checkTimer.Start()
            
            # Store timer reference for cleanup
            $script:CMButtonStateTimer = $checkTimer
            
            Write-LogMessage "CM grid event handlers configured successfully" -Level Success -Tab "Configuration Manager"
        }
        else {
            Write-LogMessage "CM grid not found, skipping event handler setup" -Level Warning -Tab "Configuration Manager"
        }
    }
    catch {
        Write-LogMessage "Error setting up CM event handlers: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
    }
}



