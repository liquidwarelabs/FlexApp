function Update-WPFChocoButtonStates {
    [CmdletBinding()]
    param()
    
    try {
        $grid = Find-Control "ChocoUpdatesGrid"
        $processButton = Find-Control "ChocoProcessButton"
        
        if (-not $grid -or -not $processButton) {
            Write-LogMessage "Could not find required UI controls for Chocolatey button state update" -Level Warning -Tab "Chocolatey"
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
            Write-LogMessage "Chocolatey Process button state changed: Enabled=$($processButton.IsEnabled) (Selected: $($selectedItems.Count) items)" -Level Info -Tab "Chocolatey"
        }
    }
    catch {
        Write-LogMessage "Error updating Chocolatey button states: $($_.Exception.Message)" -Level Error -Tab "Chocolatey"
    }
}
