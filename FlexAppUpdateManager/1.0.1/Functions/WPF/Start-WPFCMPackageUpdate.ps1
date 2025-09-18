function Start-WPFCMPackageUpdate {
    [CmdletBinding()]
    param()

    # Helper function to re-enable the process button
    function Enable-CMProcessButton {
        try {
            $script:WPFMainWindow.Dispatcher.Invoke([Action]{
                $btn = Find-Control "CMProcessButton"
                if ($btn) { 
                    $btn.IsEnabled = $true
                    Write-LogMessage "CM Process button re-enabled" -Level Info -Tab "Configuration Manager"
                }
            })
        }
        catch {
            Write-LogMessage "Could not re-enable CM Process button: $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
        }
    }

    try {
        Write-LogMessage "Processing selected Configuration Manager applications..." -Level Info -Tab "Configuration Manager"

        # Ensure WinForms types are available for shared dialogs/utilities
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue | Out-Null
        Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue | Out-Null

        # Get UI controls
        $grid = Find-Control "CMApplicationsGrid"
        $processButton = Find-Control "CMProcessButton"
        $statusLabel = Find-Control "CMConnectionStatusLabel"
        
        if (-not $grid) { throw "Could not find CMApplicationsGrid control" }

        # Gather selected apps from WPF DataGrid first (before disabling button)
        $selectedRows = @()
        foreach ($item in $grid.Items) { if ($item.Selected) { $selectedRows += $item } }

        if ($selectedRows.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Please select at least one application to process.", "No Selection", "OK", "Warning") | Out-Null
            return
        }
        
        # Disable process button during processing (only after we know we have selections)
        if ($processButton) {
            $processButton.IsEnabled = $false
        }

        $selectedNames = $selectedRows | ForEach-Object { $_.Name }

        # Use existing CM helper to expand to full app details (Name, Version, Installer, InstallerArgs)
        # Provide dummy WinForms controls to satisfy parameter types
        $dummyProgressBar = New-Object System.Windows.Forms.ProgressBar
        $dummyStatusLabel = New-Object System.Windows.Forms.Label
        
        # Update status
        $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
            if ($statusLabel) {
                $statusLabel.Content = "Processing $($selectedNames.Count) selected applications..."
            }
        })
        [System.Windows.Forms.Application]::DoEvents()
        
        Write-LogMessage "Processing $($selectedNames.Count) selected applications..." -Level Info -Tab "Configuration Manager"
        $appsForEdit = @()
        
        try {
            # Use WPF-specific version that handles null key errors better
            $appsForEdit = Process-WPFSelectedApplications -SelectedApps $selectedNames -ProgressBar $dummyProgressBar -StatusLabel $dummyStatusLabel
        }
        catch {
            Write-LogMessage "Error in Process-WPFSelectedApplications: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
            # Fallback to original function if WPF version fails
            try {
                $appsForEdit = Process-WPFSelectedApplications -SelectedApps $selectedNames -ProgressBar $dummyProgressBar -StatusLabel $dummyStatusLabel
            }
            catch {
                Write-LogMessage "Both processing methods failed, trying individual apps" -Level Warning -Tab "Configuration Manager"
                # Try individual processing to identify problematic apps
                foreach ($appName in $selectedNames) {
                    try {
                        Write-LogMessage "Attempting to process individual app: $appName" -Level Info -Tab "Configuration Manager"
                        $singleAppResult = Process-WPFSelectedApplications -SelectedApps @($appName) -ProgressBar $dummyProgressBar -StatusLabel $dummyStatusLabel
                        if ($singleAppResult -and $singleAppResult.Count -gt 0) {
                            $appsForEdit += $singleAppResult
                            Write-LogMessage "Successfully processed: $appName" -Level Success -Tab "Configuration Manager"
                        }
                    }
                    catch {
                        Write-LogMessage "Error processing app '$appName': $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
                    }
                }
            }
        }

        if (-not $appsForEdit -or $appsForEdit.Count -eq 0) {
            # Re-enable button before returning
            Enable-CMProcessButton
            [System.Windows.MessageBox]::Show("Could not resolve selected applications from Configuration Manager.", "No Applications", "OK", "Warning") | Out-Null
            return
        }

        # Open edit dialog (WPF) to allow modifications prior to update
        # Use the processed applications data instead of raw CM applications
        $editedApps = Show-WPFEditApplicationsDialog -Applications $appsForEdit -Owner $script:WPFMainWindow -UseProcessedData
        if ($null -eq $editedApps) { 
            # Re-enable button before returning (user cancelled dialog)
            Enable-CMProcessButton
            Write-LogMessage "Edit Applications dialog was cancelled or failed" -Level Info -Tab "Configuration Manager"
            return 
        }

        # Convert edit models back to the format expected by Compare-ApplicationVersions
        $appsForComparison = @()
        foreach ($editModel in $editedApps) {
            $appsForComparison += [PSCustomObject]@{
                Name = $editModel.Name
                Version = $editModel.Version
                Installer = $editModel.Installer
                InstallerArgs = $editModel.InstallerArgs
            }
        }
        
        Write-LogMessage "Converted $($appsForComparison.Count) edit models for version comparison" -Level Info -Tab "Configuration Manager"
        
        # Update status for FlexApp inventory download
        $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
            if ($statusLabel) {
                $statusLabel.Content = "Connecting to FlexApp inventory for version checking..."
            }
        })
        [System.Windows.Forms.Application]::DoEvents()
        
        # Compare versions using existing logic
        $flexAppInventory = Get-FlexAppInventoryForCM
        
        # Update status for version comparison
        $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
            if ($statusLabel) {
                $statusLabel.Content = "Comparing application versions..."
            }
        })
        [System.Windows.Forms.Application]::DoEvents()
        
        $comparison = Compare-ApplicationVersions -SelectedApps $appsForComparison -FlexAppInventory $flexAppInventory

        $appsToProcess = $comparison.ToProcess
        $appsSkipped = $comparison.Skipped
        $appsNotInInventory = $comparison.NotInInventory

        # Summary prompt
        $summary = "Version Comparison Results (After Editing):`n`n"
        if ($appsToProcess.Count -gt 0) {
            $summary += "[OK] WILL BE PROCESSED ($($appsToProcess.Count)):`n"
            foreach ($app in $appsToProcess) { $summary += "  - $($app.Name) ($($app.Version))`n" }
            $summary += "`n"
        }
        if ($appsSkipped.Count -gt 0) {
            $summary += "[SKIP] SKIPPED - Older versions ($($appsSkipped.Count)):`n"
            foreach ($app in $appsSkipped) { $summary += "  - $($app.Name) (Edited: $($app.CMVersion) vs FlexApp: $($app.FlexAppVersion))`n" }
            $summary += "`n"
        }
        if ($appsNotInInventory.Count -gt 0) {
            $summary += "[NEW] NEW - Not in FlexApp inventory ($($appsNotInInventory.Count)):`n"
            foreach ($app in $appsNotInInventory) { $summary += "  - $($app.Name) ($($app.Version))`n" }
        }

        # Check if there are no apps to process first
        if ($appsToProcess.Count -eq 0) {
            # Re-enable button before returning
            Enable-CMProcessButton
            [System.Windows.MessageBox]::Show("No applications need to be processed.", "Nothing To Do", "OK", "Information") | Out-Null
            return
        }
        
        # Show summary and ask for confirmation if there are skipped apps or new apps
        if ($appsSkipped.Count -gt 0 -or $appsNotInInventory.Count -gt 0) {
            $summary += "`n`nDo you want to proceed with processing $($appsToProcess.Count) applications?"
            $proceed = [System.Windows.Forms.MessageBox]::Show($summary, "Version Comparison Results", "YesNo", "Information")
            if ($proceed -ne "Yes") { 
                # Re-enable button before returning (user declined)
                Enable-CMProcessButton
                return 
            }
        }

        # Map back to original selection order and build final list to process
        $finalSelectedAppNames = @()
        for ($i = 0; $i -lt $appsForEdit.Count; $i++) {
            if ($i -lt $editedApps.Count) {
                $editedApp = $editedApps[$i]
                $shouldProcess = $false
                foreach ($appToProcess in $appsToProcess) {
                    if ($appToProcess.Name -eq $editedApp.Name -and $appToProcess.Version -eq $editedApp.Version) { $shouldProcess = $true; break }
                }
                if ($shouldProcess) { $finalSelectedAppNames += $appsForEdit[$i].Name }
            }
        }
        
        # Additional safety check - ensure we have valid apps to process
        if ($finalSelectedAppNames.Count -eq 0) {
            # Re-enable button before returning
            Enable-CMProcessButton
            Write-LogMessage "No applications mapped for processing after filtering" -Level Warning -Tab "Configuration Manager"
            [System.Windows.MessageBox]::Show("No applications to process after filtering.", "Nothing To Do", "OK", "Information") | Out-Null
            return
        }

        # Update status for final processing
        $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
            if ($statusLabel) {
                $statusLabel.Content = "Building export data for $($finalSelectedAppNames.Count) applications..."
            }
        })
        [System.Windows.Forms.Application]::DoEvents()
        
        # Get fully processed CM app objects to export
        $processedApps = Process-WPFSelectedApplications -SelectedApps $finalSelectedAppNames -ProgressBar $dummyProgressBar -StatusLabel $dummyStatusLabel
        if (-not $processedApps -or $processedApps.Count -eq 0) { throw "No processed applications found" }

        # Apply edits back to processed objects
        for ($i = 0; $i -lt $processedApps.Count; $i++) {
            if ($i -lt $editedApps.Count) {
                $processedApps[$i].Name = $editedApps[$i].Name
                $processedApps[$i].PackageVersion = $editedApps[$i].Version
                $processedApps[$i].Installer = $editedApps[$i].Installer
                $processedApps[$i].InstallerArgs = $editedApps[$i].InstallerArgs
                $processedApps[$i] | Add-Member -NotePropertyName "installer" -NotePropertyValue $editedApps[$i].Installer -Force
                $processedApps[$i] | Add-Member -NotePropertyName "installerargs" -NotePropertyValue $editedApps[$i].InstallerArgs -Force
            }
        }

        # Build array for export
        $pkgArrayList = [System.Collections.ArrayList]@()
        foreach ($package in $processedApps) {
            $obj = [pscustomobject]@{
                Name = $package.Name
                PackageVersion = $package.PackageVersion
                SizeMB = $package.size
                Installer = $package.installer
                InstallerArgs = $package.installerargs
            }
            [void]$pkgArrayList.Add($obj)
        }

        if ($pkgArrayList.Count -eq 0) { throw "No valid update packages were created" }

        # Update status for export preparation
        $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
            if ($statusLabel) {
                $statusLabel.Content = "Preparing export data and starting package update..."
            }
        })
        [System.Windows.Forms.Application]::DoEvents()
        
        # Write to temp JSON and start package update using shared routine
        $tempJsonPath = Join-Path $env:temp "cm_update_packages.json"
        $arrayForJson = @() + $pkgArrayList
        $jsonOutput = if ($arrayForJson.Count -eq 1) { ConvertTo-Json -InputObject @($arrayForJson) -Depth 10 } else { ConvertTo-Json -InputObject $arrayForJson -Depth 10 }
        [System.IO.File]::WriteAllText($tempJsonPath, $jsonOutput)

        $defaultFile = $script:Config.DefaultFile
        if ([string]::IsNullOrWhiteSpace($defaultFile) -or -not (Test-Path $defaultFile)) {
            throw "Please specify a valid default file path in Settings. Current: $defaultFile"
        }

        # Final status update before handing off to primary client
        $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
            if ($statusLabel) {
                $statusLabel.Content = "Starting package update on primary client..."
            }
        })
        [System.Windows.Forms.Application]::DoEvents()

        Start-WPFPackageUpdate -UpdatePackages $pkgArrayList -DefaultFile $defaultFile -Server $script:Config.PrimaryServer -SourceTab "Configuration Manager" -TempJsonPath $tempJsonPath
        
        # Success status
        $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
            if ($statusLabel) {
                $statusLabel.Content = "Package update initiated successfully"
            }
        })
    }
    catch {
        Write-LogMessage "Error starting CM package update: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
        [System.Windows.MessageBox]::Show("Error: $($_.Exception.Message)", "CM Update Error", "OK", "Error") | Out-Null
        
        # Error status and re-enable button
        $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
            if ($statusLabel) {
                $statusLabel.Content = "Error during package update"
            }
        })
        # Re-enable button in catch block
        Enable-CMProcessButton
    }
    finally {
        # Re-enable process button (final safety net)
        Enable-CMProcessButton
    }
}


