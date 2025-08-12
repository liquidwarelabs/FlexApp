function Stop-WPFAllProcesses {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Canceling all processes and restarting services..." -Level Info -Tab "Settings"
        
        # Get UI controls
        $cancelButton = Find-Control "SettingsCancelRestartButton"
        $statusLabel = Find-Control "SettingsGlobalStatusLabel"
        
        if (-not $cancelButton -or -not $statusLabel) {
            throw "Required UI controls not found"
        }
        
        # Disable button during operation
        $cancelButton.IsEnabled = $false
        $statusLabel.Content = "Canceling processes..."
        
        try {
            # Set cancellation flags FIRST before doing anything else
            $script:ChocoCancelInProgress = $true
            $script:ChocoScanCancelled = $true
            
            # Update status
            $statusLabel.Content = "Stopping all processes..."
            
            # Stop button state timers first
            if ($script:CMButtonStateTimer) {
                try {
                    $script:CMButtonStateTimer.Stop()
                    $script:CMButtonStateTimer = $null
                    Write-LogMessage "CM Button State Timer stopped" -Level Info -Tab "Settings"
                } catch {
                    Write-LogMessage "Error stopping CM Button State Timer: $($_.Exception.Message)" -Level Warning -Tab "Settings"
                }
            }
            
            if ($script:PUButtonStateTimer) {
                try {
                    $script:PUButtonStateTimer.Stop()
                    $script:PUButtonStateTimer = $null
                    Write-LogMessage "ProfileUnity Button State Timer stopped" -Level Info -Tab "Settings"
                } catch {
                    Write-LogMessage "Error stopping ProfileUnity Button State Timer: $($_.Exception.Message)" -Level Warning -Tab "Settings"
                }
            }
            
            if ($script:WingetButtonStateTimer) {
                try {
                    $script:WingetButtonStateTimer.Stop()
                    $script:WingetButtonStateTimer = $null
                    Write-LogMessage "Winget Button State Timer stopped" -Level Info -Tab "Settings"
                } catch {
                    Write-LogMessage "Error stopping Winget Button State Timer: $($_.Exception.Message)" -Level Warning -Tab "Settings"
                }
            }
            
            if ($script:ChocoButtonStateTimer) {
                try {
                    $script:ChocoButtonStateTimer.Stop()
                    $script:ChocoButtonStateTimer = $null
                    Write-LogMessage "Chocolatey Button State Timer stopped" -Level Info -Tab "Settings"
                } catch {
                    Write-LogMessage "Error stopping Chocolatey Button State Timer: $($_.Exception.Message)" -Level Warning -Tab "Settings"
                }
            }
            
            # STEP 0: Cancel any active Chocolatey scan
            Write-LogMessage "Cancelling any active Chocolatey operations..." -Level Info -Tab "Settings"
            
            # Update Chocolatey status
            Update-WPFChocoStatus -Message "Operations cancelled by user" -Level Warning
            
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
            
            # Update status
            $statusLabel.Content = "Canceling background jobs..."
            
            # STEP 2: Cancel Chocolatey background job if running
            if ($script:ChocoBackgroundJob) {
                Write-LogMessage "Stopping Chocolatey background job (ID: $($script:ChocoBackgroundJob.Id), State: $($script:ChocoBackgroundJob.State))..." -Level Info -Tab "Settings"
                
                try {
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
                    
                    Remove-Job -Job $script:ChocoBackgroundJob -Force -ErrorAction SilentlyContinue
                    Write-LogMessage "Chocolatey background job removed" -Level Success -Tab "Settings"
                }
                catch {
                    Write-LogMessage "Error stopping job (continuing anyway): $($_.Exception.Message)" -Level Warning -Tab "Settings"
                }
                finally {
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
                    $script:ChocoJobTimer.Dispose()
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
                    $script:WingetJobTimer.Dispose()
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
            
            # Update status
            $statusLabel.Content = "Cleaning up processes..."
            
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
            
            # Update status
            $statusLabel.Content = "Cleaning temporary files..."
            
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
            
            # Update status
            $statusLabel.Content = "Re-enabling buttons..."
            
            # STEP 6: Re-enable buttons on all tabs and clear data using WPF controls
            $script:WPFMainWindow.Dispatcher.Invoke([Action]{
                # Chocolatey tab
                $chocoScanButton = Find-Control "ChocoScanButton"
                $chocoCancelScanButton = Find-Control "ChocoCancelScanButton"
                $chocoProcessButton = Find-Control "ChocoProcessButton"
                if ($chocoScanButton) { $chocoScanButton.IsEnabled = $true }
                if ($chocoCancelScanButton) { $chocoCancelScanButton.IsEnabled = $false }
                if ($chocoProcessButton) { $chocoProcessButton.IsEnabled = $false }
                
                # Configuration Manager tab
                # CMExportButton was moved to Package Update Edit screen
                # $cmExportButton = Find-Control "CMExportButton"
                $cmProcessButton = Find-Control "CMProcessButton"
                # if ($cmExportButton) { $cmExportButton.IsEnabled = $false }  # Will be enabled when connected
                if ($cmProcessButton) { $cmProcessButton.IsEnabled = $false }  # Will be enabled when connected
                
                # Winget tab
                $wingetScanButton = Find-Control "WingetScanButton"
                $wingetProcessButton = Find-Control "WingetProcessButton"
                if ($wingetScanButton) { $wingetScanButton.IsEnabled = $true }
                if ($wingetProcessButton) { $wingetProcessButton.IsEnabled = $false }
                
                # Clear Chocolatey data
                $chocoUpdatesGrid = Find-Control "ChocoUpdatesGrid"
                if ($chocoUpdatesGrid) {
                    $chocoUpdatesGrid.ItemsSource = $null
                }
                
                # Clear Winget data
                $wingetUpdatesGrid = Find-Control "WingetUpdatesGrid"
                if ($wingetUpdatesGrid) {
                    $wingetUpdatesGrid.ItemsSource = $null
                }
                
                # Update status labels
                $chocoStatusLabel = Find-Control "ChocoStatusLabel"
                $cmStatusLabel = Find-Control "CMStatusLabel"
                $wingetStatusLabel = Find-Control "WingetStatusLabel"
                
                if ($chocoStatusLabel) { $chocoStatusLabel.Content = "Ready - Click 'Scan for Updates' to begin" }
                if ($cmStatusLabel) { $cmStatusLabel.Content = "Ready" }
                if ($wingetStatusLabel) { $wingetStatusLabel.Content = "Ready - Click 'Scan for Updates' to begin" }
            })
            
            # Reset cancellation flags at the end
            $script:ChocoCancelInProgress = $false
            $script:ChocoScanCancelled = $false
            
            # Update status - success
            $statusLabel.Content = "All processes canceled and services restarted"
            Write-LogMessage "Successfully canceled all processes and restarted services" -Level Success -Tab "Settings"
            
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
            
            [System.Windows.MessageBox]::Show($summaryMessage, "Cancel & Restart Complete", "OK", "Information") | Out-Null
        }
        catch {
            Write-LogMessage "Cancel and restart operation failed: $($_.Exception.Message)" -Level Error -Tab "Settings"
            Write-LogMessage "Full error: $($_.Exception)" -Level Error -Tab "Settings"
            
            $statusLabel.Content = "Cancel operation failed"
            [System.Windows.MessageBox]::Show("Cancel and restart operation failed:`n`n$($_.Exception.Message)", "Cancel & Restart Failed", "OK", "Error") | Out-Null
            
            # Still try to clear job reference and reset flags even if error occurred
            $script:ChocoBackgroundJob = $null
            $script:ChocoJobTimer = $null
            $script:ChocoCancelInProgress = $false
            $script:ChocoScanCancelled = $false
        }
        finally {
            # Re-enable button
            $cancelButton.IsEnabled = $true
        }
    }
    catch {
        Write-LogMessage "Operation failed: $($_.Exception.Message)" -Level Error -Tab "Settings"
        [System.Windows.MessageBox]::Show("Operation failed: $($_.Exception.Message)", "Error", "OK", "Error") | Out-Null
    }
}