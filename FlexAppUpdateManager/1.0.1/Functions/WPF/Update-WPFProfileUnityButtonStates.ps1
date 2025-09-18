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
            
            # Try different selection patterns
            $selectedItems1 = @($grid.ItemsSource | Where-Object { $_.Selected -eq $true })
            $selectedItems2 = @($grid.ItemsSource | Where-Object { $_.IsSelected -eq $true })
            $selectedItems3 = @($grid.ItemsSource | Where-Object { $_.Selected -eq $true -or $_.IsSelected -eq $true })
            
            $hasSelectedItems = ($selectedItems1.Count -gt 0 -or $selectedItems2.Count -gt 0)
            
            # Check for selected items
            $totalItems = @($grid.ItemsSource).Count
        }
        else {
            # Only warn occasionally to avoid spam - this is normal when no scan has been run
            if (-not $script:PUNoItemsSourceWarningShown) {
                Write-LogMessage "ProfileUnity grid has no ItemsSource (this is normal before running a scan)" -Level Info -Tab "ProfileUnity"
                $script:PUNoItemsSourceWarningShown = $true
            }
        }
        
        # Update button states based on selection
        $previousPreviewState = $previewButton.IsEnabled
        $previousCommitState = $commitButton.IsEnabled
        
        # Always enable buttons - check for selection when clicked
        $previewButton.IsEnabled = $true
        $commitButton.IsEnabled = $true
        
        # Log button state changes
        if ($previousPreviewState -ne $previewButton.IsEnabled -or $previousCommitState -ne $commitButton.IsEnabled) {
            Write-LogMessage "ProfileUnity buttons enabled (always active)" -Level Info -Tab "ProfileUnity"
        }
        
    } catch {
        Write-LogMessage "Error updating ProfileUnity button states: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
    }
}
