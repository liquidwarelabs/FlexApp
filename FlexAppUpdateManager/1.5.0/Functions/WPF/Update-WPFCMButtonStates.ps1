function Update-WPFCMButtonStates {
    [CmdletBinding()]
    param()
    
    try {
        $grid = Find-Control "CMApplicationsGrid"
        $processButton = Find-Control "CMProcessButton"
        
        if (-not $grid -or -not $processButton) {
            Write-LogMessage "Could not find required UI controls for CM button state update" -Level Warning -Tab "Configuration Manager"
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
            Write-LogMessage "CM Process button state changed: Enabled=$($processButton.IsEnabled) (Selected: $($selectedItems.Count) items)" -Level Info -Tab "Configuration Manager"
        }
    }
    catch {
        Write-LogMessage "Error updating CM button states: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
    }
}



