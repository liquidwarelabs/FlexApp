function Update-WPFWingetButtonStates {
    [CmdletBinding()]
    param()
    
    try {
        $grid = Find-Control "WingetUpdatesGrid"
        $processButton = Find-Control "WingetProcessButton"
        
        if (-not $grid -or -not $processButton) {
            Write-LogMessage "Could not find required UI controls for Winget button state update" -Level Warning -Tab "Winget"
            return
        }
        
        $hasSelectedItems = $false
        if ($grid.ItemsSource) {
            $selectedItems = @($grid.ItemsSource | Where-Object { $_.Selected -eq $true })
            $hasSelectedItems = ($selectedItems.Count -gt 0)
        }
        
        $previousState = $processButton.IsEnabled
        $processButton.IsEnabled = $hasSelectedItems
        
        if ($previousState -ne $processButton.IsEnabled) {
            Write-LogMessage "Winget Process button state changed: Enabled=$($processButton.IsEnabled) (Selected: $($selectedItems.Count) items)" -Level Info -Tab "Winget"
        }
    }
    catch {
        Write-LogMessage "Error updating Winget button states: $($_.Exception.Message)" -Level Error -Tab "Winget"
    }
}
