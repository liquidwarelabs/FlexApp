# File: Functions\ConfigurationManager\Export-CMApplications.ps1
# ================================

function Export-CMApplications {
    # Export functionality with version checking and FIXED JSON export
    $outputPathTextBox = $script:MainForm.Controls.Find('CMOutputPathTextBox', $true)[0]
    $progressBar = $script:MainForm.Controls.Find('CMProgressBar', $true)[0]
    $statusLabel = $script:MainForm.Controls.Find('CMStatusLabel', $true)[0]
    $exportButton = $script:MainForm.Controls.Find('CMExportButton', $true)[0]
    $appDataGrid = $script:MainForm.Controls.Find('CMAppDataGrid', $true)[0]
    
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
        $message = "Please select at least one application to export.`n`nDebugging info:`n"
        $message += "- Global tracking count: $($global:CMCheckedItems.Count)`n"
        $message += "- Grid selection count: $($selectedFromGrid.Count)`n"
        $message += "- Available apps: $($global:CMAppList.Count)`n`n"
        $message += "Try clicking the checkboxes again or use Select All button."
        
        [System.Windows.Forms.MessageBox]::Show($message, "No Selection - Debug Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $outputPath = $outputPathTextBox.Text
    if ([string]::IsNullOrWhiteSpace($outputPath)) {
        [System.Windows.Forms.MessageBox]::Show("Please specify an output file path.", "No Output Path", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    # Ensure the path has .json extension
    if (-not $outputPath.EndsWith('.json', [System.StringComparison]::OrdinalIgnoreCase)) {
        $outputPath += '.json'
    }
    
    try {
        $exportButton.Enabled = $false
        $progressBar.Value = 0
        $statusLabel.Text = "Preparing applications for editing..."
        
        # FIXED: Get complete app info including installer details for editing
        $selectedAppsForEdit = @()
        foreach ($appName in $selectedAppNames) {
            $appFromList = $global:CMAppList | Where-Object { $_.Name -eq $appName }
            if ($appFromList) {
                $selectedAppsForEdit += [PSCustomObject]@{
                    Name = $appFromList.Name
                    Version = $appFromList.Version
                    Installer = $appFromList.Installer
                    InstallerArgs = $appFromList.InstallerArgs
                }
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
                $summaryMessage += "[OK] WILL BE EXPORTED ($($appsToProcess.Count)):`n"
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
            
            $summaryMessage += "`n`nDo you want to proceed with exporting $($appsToProcess.Count) applications?"
            
            $result = [System.Windows.Forms.MessageBox]::Show($summaryMessage, "Version Comparison Results", "YesNo", "Information")
            
            if ($result -ne "Yes") {
                Write-LogMessage "User cancelled export after version comparison" -Level Info -Tab "Configuration Manager"
                return
            }
        }
        
        if ($appsToProcess.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No applications need to be exported.`n`nAll selected applications either have older versions than what's in FlexApp inventory, or there was an error during version comparison.", "No Applications to Export", "OK", "Information")
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
        
        $statusLabel.Text = "Exporting to JSON..."
        $progressBar.Value = 0
        
        if ($global:CMProcessedApps.Count -eq 0) {
            throw "No processed applications found to export"
        }
        
        # Ensure the directory exists for the output file
        $outputDirectory = Split-Path $outputPath -Parent
        if (!(Test-Path $outputDirectory)) {
            New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
        }
        
        # FIXED JSON EXPORT - Build complete array first, then export once
        $NewpkgfilePack = @()
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
            $NewpkgfilePack += $Newpkgfile
            Start-Sleep -Seconds 1
        }
        
        # Export JSON ONCE at the end with proper formatting to the specified file path
        $jsonOutput = ConvertTo-Json -InputObject $NewpkgfilePack -Depth 10
        $jsonOutput | Out-File $outputPath -Encoding UTF8
        
        # Verify the JSON is properly formatted
        try {
            $testJson = Get-Content $outputPath -Raw | ConvertFrom-Json
            if ($testJson -is [array]) {
                Write-LogMessage "JSON array format verified: $($testJson.Count) items" -Level Success -Tab "Configuration Manager"
            } else {
                Write-LogMessage "JSON format issue: Not an array" -Level Error -Tab "Configuration Manager"
            }
        } catch {
            Write-LogMessage "JSON format verification failed: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
        }
        
        $progressBar.Value = 100
        $statusLabel.Text = "JSON export completed successfully!"
        
        $fileName = Split-Path $outputPath -Leaf
        $message = "Successfully exported $($global:CMProcessedApps.Count) applications to JSON:`n`n"
        $message += "File: $outputPath`n`n"
        $message += "The $fileName file contains all $($global:CMProcessedApps.Count) packages with proper array formatting."
        
        [System.Windows.Forms.MessageBox]::Show($message, "Export Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    catch {
        $statusLabel.Text = "Export failed"
        [System.Windows.Forms.MessageBox]::Show("Export failed: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    finally {
        $exportButton.Enabled = $true
        $progressBar.Value = 0
    }
}
