# File: Config\Process-Management.ps1
# ================================
# Process and service management functions

function Cancel-AllProcesses {
    # Cancel all running processes and restart services
    try {
        Write-LogMessage "Canceling all processes and restarting services..." -Level Info -Tab "Settings"
        
        # Set cancellation flags FIRST before doing anything else
        $script:ChocoCancelInProgress = $true
        $script:ChocoScanCancelled = $true
        
        # Update global status
        $globalStatusLabel = $script:MainForm.Controls.Find('GlobalStatusLabel', $true)[0]
        if ($globalStatusLabel) {
            $globalStatusLabel.Text = "Stopping all processes..."
            $globalStatusLabel.ForeColor = [System.Drawing.Color]::Orange
            [System.Windows.Forms.Application]::DoEvents()
        }
        
        # STEP 0: Cancel any active Chocolatey scan
        Write-LogMessage "Cancelling any active Chocolatey operations..." -Level Info -Tab "Settings"
        
        # Hide progress controls
        $progressBar = $script:MainForm.Controls.Find('ChocoScanProgressBar', $true)[0]
        $currentPackageLabel = $script:MainForm.Controls.Find('ChocoCurrentPackageLabel', $true)[0]
        if ($progressBar) { $progressBar.Visible = $false }
        if ($currentPackageLabel) { $currentPackageLabel.Visible = $false }
        
        # Update Chocolatey status
        Update-ChocoStatus -Message "Operations cancelled by user" -Level Warning
        
        # STEP 1: Stop and restart the lw-primary-service
        $serviceName = "lw-primary-service"
        $serviceRestarted = $false
        
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                Write-LogMessage "Found service: $serviceName (Status: $($service.Status))" -Level Info -Tab "Settings"
                
                if ($service.Status -eq "Running") {
                    Write-LogMessage "Stopping service: $serviceName..." -Level Info -Tab "Settings"
                    Stop-Service -Name $serviceName -Force -ErrorAction Stop
                    
                    # Wait for service to stop
                    $timeout = 30
                    $elapsed = 0
                    do {
                        Start-Sleep -Seconds 1
                        $elapsed++
                        $service.Refresh()
                    } while ($service.Status -eq "Running" -and $elapsed -lt $timeout)
                    
                    if ($service.Status -eq "Stopped") {
                        Write-LogMessage "Service $serviceName stopped successfully" -Level Success -Tab "Settings"
                    } else {
                        Write-LogMessage "Service $serviceName did not stop within timeout" -Level Warning -Tab "Settings"
                    }
                }
                
                # Start the service
                Write-LogMessage "Starting service: $serviceName..." -Level Info -Tab "Settings"
                Start-Service -Name $serviceName -ErrorAction Stop
                
                # Wait for service to start
                $timeout = 30
                $elapsed = 0
                do {
                    Start-Sleep -Seconds 1
                    $elapsed++
                    $service.Refresh()
                } while ($service.Status -ne "Running" -and $elapsed -lt $timeout)
                
                if ($service.Status -eq "Running") {
                    Write-LogMessage "Service $serviceName started successfully" -Level Success -Tab "Settings"
                    $serviceRestarted = $true
                } else {
                    Write-LogMessage "Service $serviceName did not start within timeout" -Level Warning -Tab "Settings"
                }
            } else {
                Write-LogMessage "Service $serviceName not found on this system" -Level Warning -Tab "Settings"
            }
        }
        catch {
            Write-LogMessage "Error restarting service $serviceName`: $($_.Exception.Message)" -Level Error -Tab "Settings"
        }
        
        # Update global status
        if ($globalStatusLabel) {
            $globalStatusLabel.Text = "Canceling background jobs..."
            $globalStatusLabel.ForeColor = [System.Drawing.Color]::Orange
            [System.Windows.Forms.Application]::DoEvents()
        }
        
        # STEP 2: Cancel Chocolatey background job if running
        if ($script:ChocoBackgroundJob) {
            Write-LogMessage "Stopping Chocolatey background job (ID: $($script:ChocoBackgroundJob.Id), State: $($script:ChocoBackgroundJob.State))..." -Level Info -Tab "Settings"
            
            try {
                # Try to stop gracefully first with timeout
                if ($script:ChocoBackgroundJob.State -eq "Running") {
                    $stopResult = Stop-Job -Job $script:ChocoBackgroundJob -PassThru -ErrorAction SilentlyContinue
                    
                    # Wait up to 3 seconds for job to stop
                    $timeout = 3
                    $elapsed = 0
                    while ($script:ChocoBackgroundJob.State -eq "Running" -and $elapsed -lt $timeout) {
                        Start-Sleep -Milliseconds 500
                        $elapsed += 0.5
                        Write-LogMessage "Waiting for job to stop... ($elapsed/$timeout seconds)" -Level Info -Tab "Settings"
                    }
                    
                    if ($script:ChocoBackgroundJob.State -eq "Running") {
                        Write-LogMessage "Job still running after timeout, forcing removal..." -Level Warning -Tab "Settings"
                    }
                }
                
                # Force remove the job regardless of state
                Remove-Job -Job $script:ChocoBackgroundJob -Force -ErrorAction SilentlyContinue
                Write-LogMessage "Chocolatey background job removed" -Level Success -Tab "Settings"
            }
            catch {
                Write-LogMessage "Error stopping job (continuing anyway): $($_.Exception.Message)" -Level Warning -Tab "Settings"
            }
            finally {
                # Always clear the job reference
                $script:ChocoBackgroundJob = $null
            }
        }
        else {
            Write-LogMessage "No Chocolatey background job found" -Level Info -Tab "Settings"
        }
        
        # STEP 2B: Cancel Winget background job if running
        if ($script:WingetBackgroundJob) {
            Write-LogMessage "Stopping Winget background job (ID: $($script:WingetBackgroundJob.Id), State: $($script:WingetBackgroundJob.State))..." -Level Info -Tab "Settings"
            
            try {
                if ($script:WingetBackgroundJob.State -eq "Running") {
                    $stopResult = Stop-Job -Job $script:WingetBackgroundJob -PassThru -ErrorAction SilentlyContinue
                    
                    # Wait up to 3 seconds for job to stop
                    $timeout = 3
                    $elapsed = 0
                    while ($script:WingetBackgroundJob.State -eq "Running" -and $elapsed -lt $timeout) {
                        Start-Sleep -Milliseconds 500
                        $elapsed += 0.5
                        Write-LogMessage "Waiting for Winget job to stop... ($elapsed/$timeout seconds)" -Level Info -Tab "Settings"
                    }
                    
                    if ($script:WingetBackgroundJob.State -eq "Running") {
                        Write-LogMessage "Winget job still running after timeout, forcing removal..." -Level Warning -Tab "Settings"
                    }
                }
                
                Remove-Job -Job $script:WingetBackgroundJob -Force -ErrorAction SilentlyContinue
                Write-LogMessage "Winget background job removed" -Level Success -Tab "Settings"
            }
            catch {
                Write-LogMessage "Error stopping Winget job (continuing anyway): $($_.Exception.Message)" -Level Warning -Tab "Settings"
            }
            finally {
                $script:WingetBackgroundJob = $null
            }
        }
        else {
            Write-LogMessage "No Winget background job found" -Level Info -Tab "Settings"
        }
        
        # STEP 3: Stop Chocolatey timer
        if ($script:ChocoJobTimer) {
            try {
                $script:ChocoJobTimer.Stop()
                # DispatcherTimer doesn't have Dispose() method
                $script:ChocoJobTimer = $null
                Write-LogMessage "Chocolatey timer stopped" -Level Success -Tab "Settings"
            }
            catch {
                Write-LogMessage "Error stopping timer: $($_.Exception.Message)" -Level Warning -Tab "Settings"
                $script:ChocoJobTimer = $null
            }
        }
        
        # STEP 3B: Stop Winget timer
        if ($script:WingetJobTimer) {
            try {
                $script:WingetJobTimer.Stop()
                # DispatcherTimer doesn't have Dispose() method
                $script:WingetJobTimer = $null
                Write-LogMessage "Winget timer stopped" -Level Success -Tab "Settings"
            }
            catch {
                Write-LogMessage "Error stopping Winget timer: $($_.Exception.Message)" -Level Warning -Tab "Settings"
                $script:WingetJobTimer = $null
            }
        }
        
        # Reset Winget cancel flag
        $script:WingetCancelInProgress = $false
        
        # Update global status
        if ($globalStatusLabel) {
            $globalStatusLabel.Text = "Cleaning up processes..."
            $globalStatusLabel.ForeColor = [System.Drawing.Color]::Orange
            [System.Windows.Forms.Application]::DoEvents()
        }
        
        # STEP 4: Try to kill any FlexApp processes
        try {
            $flexAppProcesses = Get-Process -Name "primary-client" -ErrorAction SilentlyContinue
            if ($flexAppProcesses) {
                Write-LogMessage "Found $($flexAppProcesses.Count) FlexApp primary-client processes, terminating..." -Level Info -Tab "Settings"
                foreach ($process in $flexAppProcesses) {
                    try {
                        # Verify this is the correct FlexApp process by checking the path
                        $processPath = $process.MainModule.FileName
                        if ($processPath -like "*Liquidware Labs\FlexApp Packaging Automation\primary-client.exe") {
                            Write-LogMessage "Terminating FlexApp process: $processPath (PID: $($process.Id))" -Level Info -Tab "Settings"
                            $process.Kill()
                            $process.WaitForExit(2000)  # Wait up to 2 seconds
                            Write-LogMessage "Terminated FlexApp process PID: $($process.Id)" -Level Success -Tab "Settings"
                        } else {
                            Write-LogMessage "Skipping primary-client.exe at different path: $processPath" -Level Info -Tab "Settings"
                        }
                    }
                    catch {
                        Write-LogMessage "Failed to terminate FlexApp process PID: $($process.Id) - $($_.Exception.Message)" -Level Warning -Tab "Settings"
                    }
                }
            }
            else {
                Write-LogMessage "No FlexApp primary-client processes found" -Level Info -Tab "Settings"
            }
        }
        catch {
            Write-LogMessage "Error during process cleanup: $($_.Exception.Message)" -Level Warning -Tab "Settings"
        }
        
        # Update global status
        if ($globalStatusLabel) {
            $globalStatusLabel.Text = "Cleaning temporary files..."
            $globalStatusLabel.ForeColor = [System.Drawing.Color]::Orange
            [System.Windows.Forms.Application]::DoEvents()
        }
        
        # STEP 5: Clear any temporary files
        try {
            $tempFiles = @()
            if (Test-Path $script:Config.TempPath) {
                $packageTempFiles = Get-ChildItem -Path $script:Config.TempPath -Filter "PackageTemp_*.json" -ErrorAction SilentlyContinue
                $cmTempFiles = Get-ChildItem -Path $script:Config.TempPath -Filter "cm_update_packages.json" -ErrorAction SilentlyContinue
                
                # Combine the arrays properly
                if ($packageTempFiles) { $tempFiles += $packageTempFiles }
                if ($cmTempFiles) { $tempFiles += $cmTempFiles }
            }
            
            if ($tempFiles -and $tempFiles.Count -gt 0) {
                Write-LogMessage "Cleaning up $($tempFiles.Count) temporary files..." -Level Info -Tab "Settings"
                foreach ($file in $tempFiles) {
                    try {
                        Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                        Write-LogMessage "Removed temp file: $($file.Name)" -Level Success -Tab "Settings"
                    }
                    catch {
                        Write-LogMessage "Failed to remove temp file: $($file.Name)" -Level Warning -Tab "Settings"
                    }
                }
            }
            else {
                Write-LogMessage "No temporary files found" -Level Info -Tab "Settings"
            }
        }
        catch {
            Write-LogMessage "Error during temp file cleanup: $($_.Exception.Message)" -Level Warning -Tab "Settings"
        }
        
        # Update global status
        if ($globalStatusLabel) {
            $globalStatusLabel.Text = "Re-enabling buttons..."
            $globalStatusLabel.ForeColor = [System.Drawing.Color]::Orange
            [System.Windows.Forms.Application]::DoEvents()
        }
        
        # STEP 6: Re-enable buttons on all tabs and clear data
        $chocoScanButton = $script:MainForm.Controls.Find('ChocoScanButton', $true)[0]
        $chocoCancelScanButton = $script:MainForm.Controls.Find('ChocoCancelScanButton', $true)[0]
        $chocoProcessButton = $script:MainForm.Controls.Find('ChocoProcessButton', $true)[0]
        # $cmExportButton = $script:MainForm.Controls.Find('CMExportButton', $true)[0]  # Moved to Package Update Edit screen
        $cmStartUpdateButton = $script:MainForm.Controls.Find('CMStartUpdateButton', $true)[0]
        $wingetScanButton = $script:MainForm.Controls.Find('WingetScanButton', $true)[0]
        $wingetProcessButton = $script:MainForm.Controls.Find('WingetProcessButton', $true)[0]
        
        if ($chocoScanButton) { $chocoScanButton.Enabled = $true }
        if ($chocoCancelScanButton) { $chocoCancelScanButton.Enabled = $false }
        if ($chocoProcessButton) { $chocoProcessButton.Enabled = $false }  # Keep disabled until new scan
        # if ($cmExportButton) { $cmExportButton.Enabled = $global:CMConnected }  # Moved to Package Update Edit screen
        if ($cmStartUpdateButton) { $cmStartUpdateButton.Enabled = $global:CMConnected }
        if ($wingetScanButton) { $wingetScanButton.Enabled = $true }
        if ($wingetProcessButton) { $wingetProcessButton.Enabled = $false }  # Keep disabled until new scan
        
        # Clear Chocolatey data
        $script:ChocoUpdateCandidates = @()
        $updatesGrid = $script:MainForm.Controls.Find('ChocoUpdatesGrid', $true)[0]
        if ($updatesGrid) {
            $updatesGrid.Rows.Clear()
        }
        
        # Clear Winget data
        $script:WingetUpdateCandidates = @()
        $wingetUpdatesGrid = $script:MainForm.Controls.Find('WingetUpdatesGrid', $true)[0]
        if ($wingetUpdatesGrid) {
            $wingetUpdatesGrid.Rows.Clear()
        }
        
        # Update status labels
        $chocoStatusLabel = $script:MainForm.Controls.Find('ChocoStatusLabel', $true)[0]
        $cmStatusLabel = $script:MainForm.Controls.Find('CMStatusLabel', $true)[0]
        $wingetStatusLabel = $script:MainForm.Controls.Find('WingetStatusLabel', $true)[0]
        
        if ($chocoStatusLabel) { $chocoStatusLabel.Text = "Ready - Click 'Scan for Updates' to begin" }
        if ($cmStatusLabel) { $cmStatusLabel.Text = "Ready" }
        if ($wingetStatusLabel) { $wingetStatusLabel.Text = "Ready - Click 'Scan for Updates' to begin" }
        
        # Reset cancellation flags at the end
        $script:ChocoCancelInProgress = $false
        $script:ChocoScanCancelled = $false
        
        # Update global status - success
        if ($globalStatusLabel) {
            $globalStatusLabel.Text = "All processes canceled and services restarted"
            $globalStatusLabel.ForeColor = [System.Drawing.Color]::Green
        }
        
        # Create summary message
        $summaryMessage = "All processes have been canceled and services restarted.`n`nActions taken:`n"
        $summaryMessage += "- Cancelled all active operations`n"
        $summaryMessage += "- Restarted lw-primary-service`n"
        $summaryMessage += "- Stopped background jobs`n"
        $summaryMessage += "- Terminated FlexApp processes`n"
        $summaryMessage += "- Cleaned temporary files`n"
        $summaryMessage += "- Re-enabled all buttons`n"
        
        if ($serviceRestarted) {
            $summaryMessage += "`nService restart: SUCCESS"
        } else {
            $summaryMessage += "`nService restart: FAILED or not found"
        }
        
        Write-LogMessage "Cancel and restart operation completed successfully" -Level Success -Tab "Settings"
        [System.Windows.Forms.MessageBox]::Show($summaryMessage, "Cancel & Restart Complete", "OK", "Information")
    }
    catch {
        Write-LogMessage "Cancel and restart operation failed: $($_.Exception.Message)" -Level Error -Tab "Settings"
        Write-LogMessage "Full error: $($_.Exception.ToString())" -Level Error -Tab "Settings"
        
        if ($globalStatusLabel) {
            $globalStatusLabel.Text = "Cancel operation failed"
            $globalStatusLabel.ForeColor = [System.Drawing.Color]::Red
        }
        
        # Still try to clear job reference and reset flags even if error occurred
        $script:ChocoBackgroundJob = $null
        $script:ChocoJobTimer = $null
        $script:ChocoCancelInProgress = $false
        $script:ChocoScanCancelled = $false
        
        [System.Windows.Forms.MessageBox]::Show("Cancel and restart operation failed:`n`n$($_.Exception.Message)", "Cancel & Restart Failed", "OK", "Error")
    }
}