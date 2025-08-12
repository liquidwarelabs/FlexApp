function Start-WPFWingetUpdateScan {
    [CmdletBinding()]
    param()
    try {
        # Get UI controls
        $currentPackageLabel = Find-Control "WingetCurrentPackageLabel"
        $scanButton = Find-Control "WingetScanButton"
        $grid = Find-Control "WingetUpdatesGrid"
        $jobFileTextBox = Find-Control "WingetJobFileTextBox"
        
        if (-not $currentPackageLabel -or -not $scanButton -or -not $grid -or -not $jobFileTextBox) {
            throw "Required UI controls not found"
        }
        
        # Check if a file has been selected
        if ([string]::IsNullOrWhiteSpace($jobFileTextBox.Text) -or $jobFileTextBox.Text -eq "Click Browse to select CSV file...") {
            [System.Windows.MessageBox]::Show(
                "Please select a CSV job file first by clicking the Browse button.",
                "No File Selected",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning
            )
            return
        }
        
        # Verify job file exists
        if (-not (Test-Path $jobFileTextBox.Text)) {
            [System.Windows.MessageBox]::Show(
                "Job file not found: $($jobFileTextBox.Text)`n`nPlease select a valid CSV file.",
                "File Not Found",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
            return
        }
        
        # Read CSV file to verify format
        $csvContent = Import-Csv -Path $jobFileTextBox.Text
        Write-LogMessage "Found $($csvContent.Count) packages in CSV" -Level Info -Tab "Winget"
        
        # Disable scan button during scan
        $scanButton.IsEnabled = $false
        
        # Show cancel button during scan
        $cancelScanButton = Find-Control "WingetCancelScanButton"
        if ($cancelScanButton) {
            $cancelScanButton.Visibility = [System.Windows.Visibility]::Visible
        }
        
        # Reset scan cancellation flag
        $script:WingetScanCancelled = $false
        
        # Show scanning status
        $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
            $currentPackageLabel = $script:WPFMainWindow.FindName("WingetCurrentPackageLabel")
            if ($currentPackageLabel) {
                $currentPackageLabel.Content = "Please wait... Scan in progress..."
                Write-LogMessage "UI: Winget scan status updated to: $($currentPackageLabel.Content)" -Level Info
            }
        })
        
        # Force a UI update to make the status visible
        $script:WPFMainWindow.UpdateLayout()
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 100
        
        # Perform the scan with live status updates
        $rawCandidates = Get-WPFWingetUpdateCandidates -JobFile $jobFileTextBox.Text -CsvCount $csvContent.Count
        
        # Filter out empty candidates (fix for the empty entries issue)
        $candidates = $rawCandidates | Where-Object { $_.Name -and $_.Name.Trim() -ne "" }
            
        # Update grid
        $script:WPFMainWindow.Dispatcher.Invoke([Action]{
            $grid = $script:WPFMainWindow.FindName("WingetUpdatesGrid")
            if ($grid) {
                # Clear existing items
                $grid.ItemsSource = $null
                $grid.Items.Clear()
                
                # Create observable collection
                $collection = New-Object System.Collections.ObjectModel.ObservableCollection[object]
                foreach ($candidate in $candidates) {
                    $collection.Add($candidate)
                }
                
                # Set new items source
                $grid.ItemsSource = $collection
                $grid.Items.Refresh()
                
                # Log the number of items for debugging
                Write-LogMessage "Grid updated with $($collection.Count) items" -Level Info -Tab "Winget"
                Write-LogMessage "Candidates count: $($candidates.Count), Collection count: $($collection.Count)" -Level Info -Tab "Winget"
                
                # Update scan status using the actual collection count
                $currentPackageLabel = $script:WPFMainWindow.FindName("WingetCurrentPackageLabel")
                if ($currentPackageLabel) {
                    $currentPackageLabel.Content = "Scan completed. Found $($collection.Count) updates."
                    Write-LogMessage "UI: Winget scan status updated to: $($currentPackageLabel.Content)" -Level Info
                }
            }
        })
        
        Write-LogMessage "Winget scan completed successfully" -Level Success
    }
    catch {
        Write-LogMessage "Scan failed: $($_.Exception.Message)" -Level Error -Tab "Winget"
        [System.Windows.MessageBox]::Show(
            $_.Exception.Message,
            "Scan Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
    finally {
        # Re-enable scan button and hide cancel button
        $script:WPFMainWindow.Dispatcher.Invoke([Action]{
            $scanButton = $script:WPFMainWindow.FindName("WingetScanButton")
            $cancelScanButton = $script:WPFMainWindow.FindName("WingetCancelScanButton")
            
            if ($scanButton) {
                $scanButton.IsEnabled = $true
            }
            if ($cancelScanButton) {
                $cancelScanButton.Visibility = [System.Windows.Visibility]::Collapsed
            }
        })
    }
}