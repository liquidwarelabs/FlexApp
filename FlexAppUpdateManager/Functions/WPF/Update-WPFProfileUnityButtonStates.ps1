function Update-WPFProfileUnityButtonStates {
    [CmdletBinding()]
    param()
    
    try {
        # Get UI controls
        $grid = Find-Control "PUFlexAppsGrid"
        $previewButton = Find-Control "PUPreviewButton"
        $commitButton = Find-Control "PUCommitButton"
        
        if (-not $grid -or -not $previewButton -or -not $commitButton) {
            Write-LogMessage "Could not find required UI controls for button state update" -Level Warning -Tab "ProfileUnity"
            return
        }
        
        # Check if any items are selected
        $hasSelectedItems = $false
        if ($grid.ItemsSource) {
            $selectedItems = @($grid.ItemsSource | Where-Object { $_.Selected -eq $true })
            $hasSelectedItems = ($selectedItems.Count -gt 0)
            
            # Only log selection changes for debugging if needed
            # Write-LogMessage "Selection check: $selectedCount of $totalItems items selected" -Level Info -Tab "ProfileUnity"
        }
        
        # Update button states based on selection
        $previousPreviewState = $previewButton.IsEnabled
        $previousCommitState = $commitButton.IsEnabled
        
        $previewButton.IsEnabled = $hasSelectedItems
        $commitButton.IsEnabled = $hasSelectedItems
        
        # Only log when state changes to reduce noise
        if ($previousPreviewState -ne $previewButton.IsEnabled -or $previousCommitState -ne $commitButton.IsEnabled) {
            Write-LogMessage "ProfileUnity button states changed: Preview=$($previewButton.IsEnabled), Commit=$($commitButton.IsEnabled)" -Level Info -Tab "ProfileUnity"
        }
        
    } catch {
        Write-LogMessage "Error updating ProfileUnity button states: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
    }
}
