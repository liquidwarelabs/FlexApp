# File: Functions\ConfigurationManager\Start-CMPackageUpdate.ps1
# ================================

function Start-CMPackageUpdate {
    Write-LogMessage "DEBUG: Using UPDATED Start-CMPackageUpdate function - Version 3.0" -Level Info -Tab "Configuration Manager"
    
    $progressBar = $script:MainForm.Controls.Find('CMProgressBar', $true)[0]
    $statusLabel = $script:MainForm.Controls.Find('CMStatusLabel', $true)[0]
    $startUpdateButton = $script:MainForm.Controls.Find('CMStartUpdateButton', $true)[0]
    $appDataGrid = $script:MainForm.Controls.Find('CMAppDataGrid', $true)[0]
    
    # Use centralized default file setting
    $defaultFile = $script:Config.DefaultFile
    
    if ([string]::IsNullOrWhiteSpace($defaultFile) -or ![System.IO.File]::Exists($defaultFile)) {
        [System.Windows.Forms.MessageBox]::Show("Please specify a valid default file path in the Settings tab.`n`nCurrent path: $defaultFile", "Invalid Default File", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    # Get selected applications
    $selectedFromGlobal = @()
    foreach ($app in $global:CMAppList) {
        if ($global:CMCheckedItems.ContainsKey($app.Name) -and $global:CMCheckedItems[$app.Name]) {
            $selectedFromGlobal += $app.Name
        }
    }
    
    $selectedFromGrid = @()
    if ($appDataGrid) {
        foreach ($row in $appDataGrid.Rows) {
            if ($row.Cells["CMSelect"].Value -eq $true) {
                $appName = $row.Cells["CMName"].Value
                if ($appName) {
                    $selectedFromGrid += $appName
                }
            }
        }
    }
    
    $selectedAppNames = if ($selectedFromGrid.Count -gt 0) { $selectedFromGrid } else { $selectedFromGlobal }
    
    if ($selectedAppNames.Count -eq 0) {
        $message = "Please select at least one application to process.`n`nDebugging info:`n"
        $message += "- Global tracking count: $($global:CMCheckedItems.Count)`n"
        $message += "- Grid selection count: $($selectedFromGrid.Count)`n"
        $message += "- Available apps: $($global:CMAppList.Count)`n`n"
        $message += "Try clicking the checkboxes again or use Select All button."
        
        [System.Windows.Forms.MessageBox]::Show($message, "No Selection - Debug Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    try {
        $startUpdateButton.Enabled = $false
        $progressBar.Value = 0
        $statusLabel.Text = "Preparing applications for editing..."
        
        # FIXED: Get complete app info including installer details for editing
        $selectedAppsForEdit = @()
        foreach ($appName in $selectedAppNames) {
            $appFromList = $global:CMAppList | Where-Object { $_.Name -eq $appName }
            if ($appFromList) {
                Write-LogMessage "DEBUG: Found app in global list - Name: '$($appFromList.Name)' - Installer: '$($appFromList.Installer)' - Args: '$($appFromList.InstallerArgs)'" -Level Info -Tab "Configuration Manager"
                $selectedAppsForEdit += [PSCustomObject]@{
                    Name = $appFromList.Name
                    Version = $appFromList.Version
                    Installer = $appFromList.Installer
                    InstallerArgs = $appFromList.InstallerArgs
                }
            } else {
                Write-LogMessage "DEBUG: App '$appName' not found in global list" -Level Warning -Tab "Configuration Manager"
            }
        }
        
        # Show edit dialog first
        $editedApps = Show-EditApplicationsDialog -SelectedApps $selectedAppsForEdit
        
        if ($editedApps -eq $null) {
            return
        }
        
        # NOW do version checking with the edited versions
        $statusLabel.Text = "Checking FlexApp inventory for version comparison..."
        
        # Get FlexApp inventory for version checking
        $flexAppInventory = Get-FlexAppInventoryForCM
        
        $statusLabel.Text = "Comparing application versions with edited data..."
        
        # Compare versions using the edited app information
        $versionComparisonResult = Compare-ApplicationVersions -SelectedApps $editedApps -FlexAppInventory $flexAppInventory
        
        $appsToProcess = $versionComparisonResult.ToProcess
        $appsSkipped = $versionComparisonResult.Skipped
        $appsNotInInventory = $versionComparisonResult.NotInInventory
        
        # Show user the results of version comparison with ASCII characters
        if ($appsSkipped.Count -gt 0 -or $appsNotInInventory.Count -gt 0) {
            $summaryMessage = "Version Comparison Results (After Editing):`n`n"
            
            if ($appsToProcess.Count -gt 0) {
                $summaryMessage += "[OK] WILL BE PROCESSED ($($appsToProcess.Count)):`n"
                foreach ($app in $appsToProcess) {
                    $summaryMessage += "  - $($app.Name) ($($app.Version))`n"
                }
                $summaryMessage += "`n"
            }
            
            if ($appsSkipped.Count -gt 0) {
                $summaryMessage += "[SKIP] SKIPPED - Older versions ($($appsSkipped.Count)):`n"
                foreach ($app in $appsSkipped) {
                    $summaryMessage += "  - $($app.Name) (Edited: $($app.CMVersion) vs FlexApp: $($app.FlexAppVersion))`n"
                }
                $summaryMessage += "`n"
            }
            
            if ($appsNotInInventory.Count -gt 0) {
                $summaryMessage += "[NEW] NEW - Not in FlexApp inventory ($($appsNotInInventory.Count)):`n"
                foreach ($app in $appsNotInInventory) {
                    $summaryMessage += "  - $($app.Name) ($($app.Version))`n"
                }
            }
            
            $summaryMessage += "`n`nDo you want to proceed with processing $($appsToProcess.Count) applications?"
            
            $result = [System.Windows.Forms.MessageBox]::Show($summaryMessage, "Version Comparison Results", "YesNo", "Information")
            
            if ($result -ne "Yes") {
                Write-LogMessage "User cancelled after version comparison" -Level Info -Tab "Configuration Manager"
                return
            }
        }
        
        if ($appsToProcess.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No applications need to be processed.`n`nAll selected applications either have older versions than what's in FlexApp inventory, or there was an error during version comparison.", "No Applications to Process", "OK", "Information")
            return
        }
        
        # Map the apps to process back to original CM names for processing
        $finalSelectedAppNames = @()
        for ($i = 0; $i -lt $selectedAppsForEdit.Count; $i++) {
            $originalApp = $selectedAppsForEdit[$i]
            if ($i -lt $editedApps.Count) {
                $editedApp = $editedApps[$i]
                # Check if this edited app is in the appsToProcess list
                $shouldProcess = $false
                foreach ($appToProcess in $appsToProcess) {
                    if ($appToProcess.Name -eq $editedApp.Name -and $appToProcess.Version -eq $editedApp.Version) {
                        $shouldProcess = $true
                        break
                    }
                }
                if ($shouldProcess) {
                    $finalSelectedAppNames += $originalApp.Name
                }
            }
        }
        
        if ($finalSelectedAppNames.Count -eq 0) {
            $finalSelectedAppNames = $selectedAppNames
        }
        
        $statusLabel.Text = "Processing selected applications..."
        
        $global:CMProcessedApps = Process-SelectedApplications -SelectedApps $finalSelectedAppNames -ProgressBar $progressBar -StatusLabel $statusLabel
        
        # Apply the edited names, versions, and installer info to the processed apps
        for ($i = 0; $i -lt $global:CMProcessedApps.Count; $i++) {
            if ($i -lt $editedApps.Count) {
                $global:CMProcessedApps[$i].Name = $editedApps[$i].Name
                $global:CMProcessedApps[$i].PackageVersion = $editedApps[$i].Version
                $global:CMProcessedApps[$i].Installer = $editedApps[$i].Installer
                $global:CMProcessedApps[$i].InstallerArgs = $editedApps[$i].InstallerArgs
                # Also update lowercase versions for compatibility
                $global:CMProcessedApps[$i] | Add-Member -NotePropertyName "installer" -NotePropertyValue $editedApps[$i].Installer -Force
                $global:CMProcessedApps[$i] | Add-Member -NotePropertyName "installerargs" -NotePropertyValue $editedApps[$i].InstallerArgs -Force
            }
        }
        
        if ($global:CMProcessedApps.Count -eq 0) {
            throw "No processed applications found"
        }
        
        # Build complete array first, then export to temp JSON file (same as Export-CMApplications.ps1)
        $NewpkgfilePack = [System.Collections.ArrayList]@()
        $TotalApps = $global:CMProcessedApps.Count
        $CurrentApp = 0
        
        ForEach($package in $global:CMProcessedApps){
            $CurrentApp++
            if ($TotalApps -gt 0) {
                $progressBar.Value = [int](($CurrentApp / $TotalApps) * 100)
            }
            $statusLabel.Text = "Processing: $($package.Name) ($CurrentApp of $TotalApps)"
            [System.Windows.Forms.Application]::DoEvents()
            
            $Newpkgfile = [pscustomobject]@{
                Name = $package.Name
                PackageVersion = $package.PackageVersion
                SizeMB = $package.size
                Installer = $package.installer
                InstallerArgs = $package.installerargs
            }
            $null = $NewpkgfilePack.Add($Newpkgfile)
            Start-Sleep -Milliseconds 100
        }
        
        # Export JSON to temporary file with proper formatting - PowerShell 5.1 compatible
        $tempJsonPath = "$env:temp\cm_update_packages.json"
        # Convert ArrayList to regular array
        $arrayForJson = @() + $NewpkgfilePack
        
        # PowerShell 5.1 specific fix for single item arrays
        if ($arrayForJson.Count -eq 1) {
            # For single item, wrap in array and use specific syntax to force array structure
            $jsonOutput = ConvertTo-Json -InputObject @($arrayForJson) -Depth 10
        } else {
            # For multiple items, normal conversion works
            $jsonOutput = ConvertTo-Json -InputObject $arrayForJson -Depth 10
        }
        
        # Export JSON without BOM (PowerShell 5.1 compatible)
        [System.IO.File]::WriteAllText($tempJsonPath, $jsonOutput)
        
        # Verify the JSON is properly formatted
        try {
            $testJson = Get-Content $tempJsonPath -Raw | ConvertFrom-Json
            if ($testJson -is [array]) {
                Write-LogMessage "JSON array format verified: $($testJson.Count) items" -Level Success -Tab "Configuration Manager"
            } else {
                Write-LogMessage "JSON format issue: Not an array" -Level Error -Tab "Configuration Manager"
            }
        } catch {
            Write-LogMessage "JSON format verification failed: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
        }
        
        if ($NewpkgfilePack.Count -eq 0) {
            throw "No valid update packages were created"
        }
        
        Write-LogMessage "DEBUG: About to call Start-PackageUpdate with centralized default file" -Level Info -Tab "Configuration Manager"
        Write-LogMessage "DEBUG: Using Default File: '$defaultFile'" -Level Info -Tab "Configuration Manager"
        Write-LogMessage "DEBUG: TempJsonPath: '$tempJsonPath'" -Level Info -Tab "Configuration Manager"
        Write-LogMessage "DEBUG: File exists check: $(Test-Path $tempJsonPath)" -Level Info -Tab "Configuration Manager"
        
        # Call Start-PackageUpdate with centralized settings
        $tempFunction = {
            param($UpdatePackages, $DefaultFile, $Server, $SourceTab)
            
            # Use our existing cm_update_packages.json file
            $tempJsonFile = "$env:temp\cm_update_packages.json"
            Write-LogMessage "Using existing temporary package file: $tempJsonFile" -Level Info -Tab $SourceTab
            
            # Call the original function logic but with our file
            try {
                Write-LogMessage "Starting package update for $($UpdatePackages.Count) packages..." -Level Info -Tab $SourceTab
                
                # Verify FlexApp client exists
                if (-not (Test-Path $script:Config.FlexAppClient)) {
                    throw "FlexApp client not found: $($script:Config.FlexAppClient)"
                }
                
                # Build arguments
                $arguments = @(
                    "create packages",
                    "/packagesfile `"$tempJsonFile`"",
                    "/DefaultsJSON `"$DefaultFile`"",
                    "/WaitForDone"
                )
                
                # Add server parameter (Primary Server from Settings)
                if (![string]::IsNullOrWhiteSpace($script:Config.PrimaryServer)) {
                    $arguments += "/PrimaryAddress $($script:Config.PrimaryServer)"
                }
                
                $argumentString = $arguments -join " "
                
                Write-LogMessage "Starting FlexApp package creation process..." -Level Info -Tab $SourceTab
                
                # Create script block for background job
                $scriptBlock = {
                    param($FlexAppClient, $Arguments, $TempFile, $SourceTab)
                    
                    $startTime = Get-Date
                    
                    try {
                        # Start process in new console window
                        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
                        $processStartInfo.FileName = $FlexAppClient
                        $processStartInfo.Arguments = $Arguments
                        $processStartInfo.UseShellExecute = $true
                        $processStartInfo.CreateNoWindow = $false
                        $processStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
                        
                        $process = New-Object System.Diagnostics.Process
                        $process.StartInfo = $processStartInfo
                        
                        if (-not $process.Start()) {
                            throw "Failed to start FlexApp client process"
                        }
                        
                        Write-Output "Process started with PID: $($process.Id) in new console window"
                        
                        # Wait for process to complete
                        $process.WaitForExit()
                        
                        $endTime = Get-Date
                        $duration = $endTime - $startTime
                        
                        return @{
                            Success = $true
                            ExitCode = $process.ExitCode
                            StartTime = $startTime
                            EndTime = $endTime
                            Duration = $duration
                            TempFile = $TempFile
                            ProcessId = $process.Id
                            SourceTab = $SourceTab
                        }
                    }
                    catch {
                        $endTime = Get-Date
                        $duration = $endTime - $startTime
                        
                        return @{
                            Success = $false
                            Error = $_.Exception.Message
                            FullError = $_.Exception.ToString()
                            StartTime = $startTime
                            EndTime = $endTime
                            Duration = $duration
                            TempFile = $TempFile
                            SourceTab = $SourceTab
                        }
                    }
                }
                
                # Start background job
                $backgroundJob = Start-Job -ScriptBlock $scriptBlock -ArgumentList $script:Config.FlexAppClient, $argumentString, $tempJsonFile, $SourceTab
                
                if ($backgroundJob) {
                    Write-LogMessage "Background job started with ID: $($backgroundJob.Id)" -Level Success -Tab $SourceTab
                    Write-LogMessage "FlexApp primary-client.exe will open in a new console window" -Level Info -Tab $SourceTab
                    
                    # Store the job reference for monitoring (similar to Chocolatey)
                    $script:CMBackgroundJob = $backgroundJob
                    
                    # Start monitoring timer for CM job
                    $timer = New-Object System.Windows.Forms.Timer
                    $timer.Interval = 2000  # Check every 2 seconds
                    $timer.Add_Tick({
                        try {
                            if ($script:CMBackgroundJob -and $script:CMBackgroundJob.State -eq "Completed") {
                                $result = Receive-Job -Job $script:CMBackgroundJob
                                Remove-Job -Job $script:CMBackgroundJob -Force
                                $script:CMBackgroundJob = $null
                                
                                # Stop the timer
                                $this.Stop()
                                $this.Dispose()
                                
                                # Update UI
                                $statusLabel = $script:MainForm.Controls.Find('CMStatusLabel', $true)[0]
                                $startUpdateButton = $script:MainForm.Controls.Find('CMStartUpdateButton', $true)[0]
                                $progressBar = $script:MainForm.Controls.Find('CMProgressBar', $true)[0]
                                
                                if ($result.Success) {
                                    $formattedTime = "{0:mm\:ss}" -f $result.Duration
                                    Write-LogMessage "FlexApp package creation completed successfully (Duration: $formattedTime)" -Level Success -Tab "Configuration Manager"
                                    
                                    if ($statusLabel) { $statusLabel.Text = "Package creation completed successfully!" }
                                    if ($progressBar) { $progressBar.Value = 100 }
                                    
                                    [System.Windows.Forms.MessageBox]::Show(
                                        "FlexApp package creation completed successfully!`n`nDuration: $formattedTime`nExit Code: $($result.ExitCode)", 
                                        "Process Complete", 
                                        "OK", 
                                        "Information"
                                    )
                                } else {
                                    Write-LogMessage "FlexApp package creation failed: $($result.Error)" -Level Error -Tab "Configuration Manager"
                                    
                                    if ($statusLabel) { $statusLabel.Text = "Package creation failed" }
                                    if ($progressBar) { $progressBar.Value = 0 }
                                    
                                    [System.Windows.Forms.MessageBox]::Show(
                                        "FlexApp package creation failed:`n`n$($result.Error)", 
                                        "Process Error", 
                                        "OK", 
                                        "Error"
                                    )
                                }
                                
                                # Re-enable the button
                                if ($startUpdateButton) { $startUpdateButton.Enabled = $true }
                            }
                            elseif ($script:CMBackgroundJob -and $script:CMBackgroundJob.State -eq "Failed") {
                                $jobError = $script:CMBackgroundJob.ChildJobs[0].JobStateInfo.Reason.Message
                                Remove-Job -Job $script:CMBackgroundJob -Force
                                $script:CMBackgroundJob = $null
                                
                                # Stop the timer
                                $this.Stop()
                                $this.Dispose()
                                
                                # Update UI
                                $statusLabel = $script:MainForm.Controls.Find('CMStatusLabel', $true)[0]
                                $startUpdateButton = $script:MainForm.Controls.Find('CMStartUpdateButton', $true)[0]
                                $progressBar = $script:MainForm.Controls.Find('CMProgressBar', $true)[0]
                                
                                Write-LogMessage "FlexApp package creation job failed: $jobError" -Level Error -Tab "Configuration Manager"
                                
                                if ($statusLabel) { $statusLabel.Text = "Package creation job failed" }
                                if ($progressBar) { $progressBar.Value = 0 }
                                if ($startUpdateButton) { $startUpdateButton.Enabled = $true }
                                
                                [System.Windows.Forms.MessageBox]::Show(
                                    "FlexApp package creation job failed:`n`n$jobError", 
                                    "Job Error", 
                                    "OK", 
                                    "Error"
                                )
                            }
                        }
                        catch {
                            Write-LogMessage "Error in CM job monitoring timer: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
                        }
                    })
                    $timer.Start()
                    
                    # Update status to show process is running
                    $statusLabel.Text = "FlexApp package creation running in background (new console window opened)..."
                    
                    # Show message to user
                    [System.Windows.Forms.MessageBox]::Show(
                        "FlexApp package creation has started in a new console window.`n`nThe GUI will remain responsive while the process runs in the background.`n`nYou will be notified when the process completes.", 
                        "Process Started", 
                        "OK", 
                        "Information"
                    )
                } else {
                    throw "Failed to start background job"
                }
            }
            catch {
                Write-LogMessage "Failed to start package update: $($_.Exception.Message)" -Level Error -Tab $SourceTab
                throw
            }
        }
        
        # Call our temporary function with centralized settings
        & $tempFunction -UpdatePackages $NewpkgfilePack -DefaultFile $defaultFile -Server $script:Config.PrimaryServer -SourceTab "Configuration Manager"
        
        $statusLabel.Text = "Package update completed successfully!"
    }
    catch {
        Write-LogMessage "Error in CM start update: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
        $statusLabel.Text = "Package update failed"
        [System.Windows.Forms.MessageBox]::Show("Package update failed: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    finally {
        $startUpdateButton.Enabled = $true
        $progressBar.Value = 0
    }
}
