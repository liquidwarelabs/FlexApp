function Start-WPFChocoUpdateScan {
    [CmdletBinding()]
    param()
    try {
        Write-LogMessage "Starting Chocolatey update scan..." -Level Info
        
        # Get UI controls
        $scanStatusLabel = Find-Control "ChocoScanStatusLabel"
        $scanButton = Find-Control "ChocoScanButton"
        $grid = Find-Control "ChocoUpdatesGrid"
        $jobFileTextBox = Find-Control "ChocoJobFileTextBox"
        
        if (-not $scanStatusLabel -or -not $scanButton -or -not $grid -or -not $jobFileTextBox) {
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
        Write-LogMessage "Found $($csvContent.Count) packages in CSV" -Level Info
        
        # Verify CSV has required columns
        $requiredColumns = @('name', 'size')
        $missingColumns = $requiredColumns | Where-Object { $_ -notin $csvContent[0].PSObject.Properties.Name }
        if ($missingColumns) {
            throw "CSV file missing required columns: $($missingColumns -join ', ')"
        }
        
        # Update status and disable scan button during scan
        $scanButton.IsEnabled = $false
        
        # Show cancel button during scan
        $cancelScanButton = Find-Control "ChocoCancelScanButton"
        if ($cancelScanButton) {
            $cancelScanButton.Visibility = [System.Windows.Visibility]::Visible
        }
        
        # Reset scan cancellation flag
        $script:ChocoScanCancelled = $false
        
        # Show scanning status
        $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
            $statusLabel = $script:WPFMainWindow.FindName("ChocoScanStatusLabel")
            if ($statusLabel) {
                $statusLabel.Content = "Please wait... Scan in progress..."
                Write-LogMessage "UI: Scan status updated to: $($statusLabel.Content)" -Level Info
            }
        })
        
        # Force a UI update to make the status visible
        $script:WPFMainWindow.UpdateLayout()
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 100
        
        # Perform the scan with live status updates
        $rawCandidates = Get-WPFChocoUpdateCandidates -JobFile $jobFileTextBox.Text -CsvCount $csvContent.Count
        
        # Filter out empty candidates (fix for the empty entries issue)
        $candidates = $rawCandidates | Where-Object { $_.Name -and $_.Name.Trim() -ne "" }
            
        Write-LogMessage "Found $($candidates.Count) update candidates" -Level Info
        
        # Update grid on UI thread
        $script:WPFMainWindow.Dispatcher.Invoke([Action]{
            # Clear existing items more thoroughly
            $grid.ItemsSource = $null
            $grid.Items.Clear()
            
            # Force grid refresh
            $grid.Items.Refresh()
            
            # Wait a moment for the clear to take effect
            Start-Sleep -Milliseconds 50
            
            # Create observable collection
            $collection = New-Object System.Collections.ObjectModel.ObservableCollection[object]
            foreach ($candidate in $candidates) {
                $collection.Add($candidate)
            }
            
            # Set new items source
            $grid.ItemsSource = $collection
            
            # Force grid refresh again
            $grid.Items.Refresh()
            
            # Log the number of items for debugging
            Write-LogMessage "Grid updated with $($collection.Count) items" -Level Info
            Write-LogMessage "Candidates count: $($candidates.Count), Collection count: $($collection.Count)" -Level Info
            
            # Update scan status using the actual collection count
            $statusLabel = $script:WPFMainWindow.FindName("ChocoScanStatusLabel")
            if ($statusLabel) {
                $statusLabel.Content = "Scan completed. Found $($collection.Count) updates."
                Write-LogMessage "UI: Scan status updated to: $($statusLabel.Content)" -Level Info
            }
        })
        
        Write-LogMessage "Chocolatey scan completed successfully" -Level Success
    }
    catch {
        Write-LogMessage "Error during Chocolatey scan: $($_.Exception.Message)" -Level Error
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
            $scanButton = $script:WPFMainWindow.FindName("ChocoScanButton")
            $cancelScanButton = $script:WPFMainWindow.FindName("ChocoCancelScanButton")
            
            if ($scanButton) {
                $scanButton.IsEnabled = $true
            }
            if ($cancelScanButton) {
                $cancelScanButton.Visibility = [System.Windows.Visibility]::Collapsed
            }
        })
    }
}