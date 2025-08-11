# File: Functions\ProfileUnity\ProfileUnity-ConfigFunctions.ps1
# ================================

# Global variables for ProfileUnity configuration management
$script:PUConfigurations = @()
$script:PUCurrentConfig = $null
$script:PUUpdateCandidates = @()
$script:PUFlexAppInventory = @()

function Load-ProfileUnityConfigurations {
    [CmdletBinding()]
    param()
    
    try {
        $configComboBox = $script:MainForm.Controls.Find('PUConfigComboBox', $true)[0]
        $scanButton = $script:MainForm.Controls.Find('PUScanButton', $true)[0]
        $connectionStatusLabel = $script:MainForm.Controls.Find('PUConnectionStatusLabel', $true)[0]
        $progressBar = $script:MainForm.Controls.Find('PUProgressBar', $true)[0]
        
        # Show progress
        $progressBar.Visible = $true
        $progressBar.Style = "Marquee"
        $connectionStatusLabel.Text = "Connecting to ProfileUnity server..."
        $connectionStatusLabel.ForeColor = [System.Drawing.Color]::Blue
        [System.Windows.Forms.Application]::DoEvents()
        
        # Connect to ProfileUnity
        if (-not (Connect-ProfileUnityServer)) {
            throw "Failed to connect to ProfileUnity server"
        }
        
        Write-LogMessage "Loading ProfileUnity configurations..." -Level Info -Tab "ProfileUnity"
        
        # Get all configurations
        $configsUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/configuration"
        $response = Invoke-WebRequest -Uri $configsUri -WebSession $script:ChocoSession
        $configData = ($response.Content | ConvertFrom-Json)
        
        if ($configData.Tag.Rows) {
            $script:PUConfigurations = $configData.Tag.Rows | Where-Object { $_.name -ne $null }
            
            # Populate combo box
            $configComboBox.Items.Clear()
            foreach ($config in $script:PUConfigurations) {
                [void]$configComboBox.Items.Add($config.name)
            }
            
            if ($configComboBox.Items.Count -gt 0) {
                $configComboBox.SelectedIndex = 0
                $scanButton.Enabled = $true
                $connectionStatusLabel.Text = "Connected - $($configComboBox.Items.Count) configurations loaded"
                $connectionStatusLabel.ForeColor = [System.Drawing.Color]::Green
            } else {
                $connectionStatusLabel.Text = "No configurations found"
                $connectionStatusLabel.ForeColor = [System.Drawing.Color]::Orange
            }
        } else {
            throw "No configurations returned from server"
        }
        
        # Get FlexApp inventory for later use
        $script:PUFlexAppInventory = Get-ProfileUnityFlexApps
        Write-LogMessage "Loaded $($script:PUFlexAppInventory.Count) FlexApp packages from inventory" -Level Info -Tab "ProfileUnity"
        
    }
    catch {
        Write-LogMessage "Failed to load configurations: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        $connectionStatusLabel.Text = "Error: $($_.Exception.Message)"
        $connectionStatusLabel.ForeColor = [System.Drawing.Color]::Red
        [System.Windows.Forms.MessageBox]::Show("Failed to load configurations: $($_.Exception.Message)", "Error", "OK", "Error")
    }
    finally {
        $progressBar.Visible = $false
        $progressBar.Style = "Blocks"
    }
}

function Start-ProfileUnityConfigScan {
    [CmdletBinding()]
    param()
    
    try {
        $configComboBox = $script:MainForm.Controls.Find('PUConfigComboBox', $true)[0]
        $updatesGrid = $script:MainForm.Controls.Find('PUUpdatesGrid', $true)[0]
        $statusLabel = $script:MainForm.Controls.Find('PUStatusLabel', $true)[0]
        $previewButton = $script:MainForm.Controls.Find('PUPreviewButton', $true)[0]
        $commitButton = $script:MainForm.Controls.Find('PUCommitButton', $true)[0]
        $progressBar = $script:MainForm.Controls.Find('PUProgressBar', $true)[0]
        
        # Clear previous results
        $updatesGrid.Rows.Clear()
        $script:PUUpdateCandidates = @()
        $previewButton.Enabled = $false
        $commitButton.Enabled = $false
        
        $selectedConfigName = $configComboBox.SelectedItem
        if (-not $selectedConfigName) {
            throw "No configuration selected"
        }
        
        Write-LogMessage "Scanning configuration: $selectedConfigName" -Level Info -Tab "ProfileUnity"
        $statusLabel.Text = "Loading configuration details..."
        
        # Get the configuration ID
        $configId = ($script:PUConfigurations | Where-Object { $_.name -eq $selectedConfigName }).id
        if (-not $configId) {
            throw "Could not find configuration ID for $selectedConfigName"
        }
        
        # Load the full configuration
        $configUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/configuration/$configId"
        $response = Invoke-WebRequest -Uri $configUri -WebSession $script:ChocoSession
        $configData = ($response.Content | ConvertFrom-Json)
        $script:PUCurrentConfig = $configData.tag
        
        Write-LogMessage "Configuration loaded, checking FlexApp assignments..." -Level Info -Tab "ProfileUnity"
        $statusLabel.Text = "Checking for FlexApp updates..."
        
        # Get FlexApp DIAs from the configuration
        $flexAppDias = $script:PUCurrentConfig.FlexAppDias
        if (-not $flexAppDias -or $flexAppDias.Count -eq 0) {
            $statusLabel.Text = "No FlexApp assignments found in this configuration"
            return
        }
        
        # Progress setup
        $progressBar.Visible = $true
        $progressBar.Value = 0
        $progressBar.Maximum = $flexAppDias.Count
        
        $updateCount = 0
        
        # Check each FlexApp DIA
        foreach ($dia in $flexAppDias) {
            $progressBar.Value++
            [System.Windows.Forms.Application]::DoEvents()
            
            if (-not $dia.FlexAppPackages -or $dia.FlexAppPackages.Count -eq 0) {
                continue
            }
            
            foreach ($package in $dia.FlexAppPackages) {
                $packageId = $package.FlexAppPackageId
                $packageUuid = $package.FlexAppPackageUuid
                
                # Find the package in inventory
                $inventoryPackage = $script:PUFlexAppInventory | Where-Object { 
                    $_.id -eq $packageId -or $_.uuid -eq $packageUuid 
                }
                
                if (-not $inventoryPackage) {
                    Write-LogMessage "Package ID $packageId not found in inventory" -Level Warning -Tab "ProfileUnity"
                    continue
                }
                
                $packageName = $inventoryPackage.name
                
                # Get current version from the configuration
                $currentVersion = "$($inventoryPackage.VersionMajor).$($inventoryPackage.VersionMinor).$($inventoryPackage.VersionBuild).$($inventoryPackage.VersionRevision)"
                
                # Find all versions of this package in inventory
                $allVersions = $script:PUFlexAppInventory | Where-Object { $_.name -eq $packageName }
                
                if ($allVersions.Count -gt 1) {
                    # Get the latest version
                    $latestPackage = $allVersions | Sort-Object {
                        [version]"$($_.VersionMajor).$($_.VersionMinor).$($_.VersionBuild).$($_.VersionRevision)"
                    } -Descending | Select-Object -First 1
                    
                    $latestVersion = "$($latestPackage.VersionMajor).$($latestPackage.VersionMinor).$($latestPackage.VersionBuild).$($latestPackage.VersionRevision)"
                    
                    # Compare versions
                    if ([version]$currentVersion -lt [version]$latestVersion) {
                        # Get filter info
                        $filterName = ""
                        if ($dia.FilterId) {
                            $filterInfo = Get-ProfileUnityFilterById -FilterId $dia.FilterId
                            if ($filterInfo) {
                                $filterName = $filterInfo.Name
                            }
                        }
                        
                        # Add to update candidates
                        $updateCandidate = [PSCustomObject]@{
                            Name = $packageName
                            CurrentVersion = $currentVersion
                            NewVersion = $latestVersion
                            CurrentPackageId = $packageId
                            NewPackageId = $latestPackage.id
                            NewPackageUuid = $latestPackage.uuid
                            FilterName = $filterName
                            FilterId = $dia.FilterId
                            DiaIndex = $flexAppDias.IndexOf($dia)
                            Selected = $false
                        }
                        
                        $script:PUUpdateCandidates += $updateCandidate
                        
                        # Add to grid
                        $row = $updatesGrid.Rows.Add()
                        $updatesGrid.Rows[$row].Cells["PUSelected"].Value = $false
                        $updatesGrid.Rows[$row].Cells["PUName"].Value = $packageName
                        $updatesGrid.Rows[$row].Cells["PUCurrentVersion"].Value = $currentVersion
                        $updatesGrid.Rows[$row].Cells["PUNewVersion"].Value = $latestVersion
                        $updatesGrid.Rows[$row].Cells["PUFilter"].Value = $filterName
                        $updatesGrid.Rows[$row].Tag = $updateCandidate
                        
                        $updateCount++
                        Write-LogMessage "Found update for $packageName`: $currentVersion -> $latestVersion" -Level Success -Tab "ProfileUnity"
                    }
                }
            }
        }
        
        $progressBar.Visible = $false
        
        if ($updateCount -gt 0) {
            $statusLabel.Text = "Found $updateCount FlexApp updates available"
            $previewButton.Enabled = $true
        } else {
            $statusLabel.Text = "All FlexApps are up to date in this configuration"
        }
        
    }
    catch {
        Write-LogMessage "Scan failed: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        $statusLabel.Text = "Scan failed: $($_.Exception.Message)"
        $progressBar.Visible = $false
        [System.Windows.Forms.MessageBox]::Show("Scan failed: $($_.Exception.Message)", "Error", "OK", "Error")
    }
}

function Get-ProfileUnityFilterById {
    param([string]$FilterId)
    
    try {
        if ([string]::IsNullOrWhiteSpace($FilterId)) {
            return $null
        }
        
        $filtersUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/Filter"
        $response = Invoke-WebRequest -Uri $filtersUri -WebSession $script:ChocoSession
        $filters = ($response.Content | ConvertFrom-Json).Tag.Rows
        
        return $filters | Where-Object { $_.id -eq $FilterId } | Select-Object -First 1
    }
    catch {
        Write-LogMessage "Failed to get filter info: $($_.Exception.Message)" -Level Warning -Tab "ProfileUnity"
        return $null
    }
}

function Preview-ProfileUnityConfigChanges {
    [CmdletBinding()]
    param()
    
    try {
        $updatesGrid = $script:MainForm.Controls.Find('PUUpdatesGrid', $true)[0]
        $previewTextBox = $script:MainForm.Controls.Find('PUPreviewTextBox', $true)[0]
        $commitButton = $script:MainForm.Controls.Find('PUCommitButton', $true)[0]
        
        $selectedUpdates = @()
        
        foreach ($row in $updatesGrid.Rows) {
            if ($row.Cells["PUSelected"].Value -eq $true) {
                $selectedUpdates += $row.Tag
            }
        }
        
        if ($selectedUpdates.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select at least one update to preview", "No Selection", "OK", "Warning")
            return
        }
        
        # Build preview text
        $previewText = "PREVIEW OF CHANGES:`r`n`r`n"
        $previewText += "Configuration: $($script:PUCurrentConfig.Name)`r`n"
        $previewText += "Updates to apply: $($selectedUpdates.Count)`r`n"
        $previewText += "=" * 40 + "`r`n`r`n"
        
        foreach ($update in $selectedUpdates) {
            $previewText += "FlexApp: $($update.Name)`r`n"
            $previewText += "  Current: v$($update.CurrentVersion)`r`n"
            $previewText += "  New:     v$($update.NewVersion)`r`n"
            if ($update.FilterName) {
                $previewText += "  Filter:  $($update.FilterName)`r`n"
            }
            $previewText += "`r`n"
        }
        
        $previewTextBox.Text = $previewText
        $commitButton.Enabled = $true
        
    }
    catch {
        Write-LogMessage "Preview failed: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        [System.Windows.Forms.MessageBox]::Show("Preview failed: $($_.Exception.Message)", "Error", "OK", "Error")
    }
}

function Commit-ProfileUnityConfigChanges {
    [CmdletBinding()]
    param()
    
    try {
        $updatesGrid = $script:MainForm.Controls.Find('PUUpdatesGrid', $true)[0]
        $statusLabel = $script:MainForm.Controls.Find('PUStatusLabel', $true)[0]
        $deployCheckBox = $script:MainForm.Controls.Find('PUDeployCheckBox', $true)[0]
        $progressBar = $script:MainForm.Controls.Find('PUProgressBar', $true)[0]
        
        $selectedUpdates = @()
        
        foreach ($row in $updatesGrid.Rows) {
            if ($row.Cells["PUSelected"].Value -eq $true) {
                $selectedUpdates += $row.Tag
            }
        }
        
        if ($selectedUpdates.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select at least one update to commit", "No Selection", "OK", "Warning")
            return
        }
        
        $confirmMessage = "Are you sure you want to update $($selectedUpdates.Count) FlexApp(s) in configuration '$($script:PUCurrentConfig.Name)'?"
        if ($deployCheckBox.Checked) {
            $confirmMessage += "`n`nThe configuration will be DEPLOYED after saving."
        }
        
        $result = [System.Windows.Forms.MessageBox]::Show($confirmMessage, "Confirm Update", "YesNo", "Question")
        
        if ($result -ne "Yes") {
            return
        }
        
        Write-LogMessage "Starting configuration update..." -Level Info -Tab "ProfileUnity"
        $statusLabel.Text = "Updating configuration..."
        
        # Show progress
        $progressBar.Visible = $true
        $progressBar.Value = 0
        $progressBar.Maximum = $selectedUpdates.Count
        
        # Apply updates to the configuration
        foreach ($update in $selectedUpdates) {
            $progressBar.Value++
            $statusLabel.Text = "Updating $($update.Name)..."
            [System.Windows.Forms.Application]::DoEvents()
            
            # Find the DIA in the configuration
            $dia = $script:PUCurrentConfig.FlexAppDias[$update.DiaIndex]
            
            # Update the FlexApp package reference
            foreach ($package in $dia.FlexAppPackages) {
                if ($package.FlexAppPackageId -eq $update.CurrentPackageId) {
                    $package.FlexAppPackageId = $update.NewPackageId
                    $package.FlexAppPackageUuid = $update.NewPackageUuid
                    
                    Write-LogMessage "Updated $($update.Name) from v$($update.CurrentVersion) to v$($update.NewVersion)" -Level Success -Tab "ProfileUnity"
                    break
                }
            }
            
            # Update description with date/time
            $date = Get-Date -Format "yyyy-MM-dd HH:mm"
            if ($dia.Description) {
                $dia.Description += " | Updated $($update.Name) to v$($update.NewVersion) on $date"
            } else {
                $dia.Description = "Updated $($update.Name) to v$($update.NewVersion) on $date"
            }
        }
        
        $statusLabel.Text = "Saving configuration..."
        
        # Save the configuration
        $saveUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/configuration"
        $body = $script:PUCurrentConfig | ConvertTo-Json -Depth 10
        
        $response = Invoke-WebRequest -Uri $saveUri -Method Post -WebSession $script:ChocoSession -ContentType "application/json" -Body $body
        
        if ($response.StatusCode -eq 200) {
            Write-LogMessage "Configuration saved successfully" -Level Success -Tab "ProfileUnity"
            
            if ($deployCheckBox.Checked) {
                $statusLabel.Text = "Deploying configuration..."
                
                # Deploy the configuration
                $configId = ($script:PUConfigurations | Where-Object { $_.name -eq $script:PUCurrentConfig.Name }).id
                $deployUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/configuration/$configId/script?encoding=ascii&deploy=true"
                
                $deployResponse = Invoke-WebRequest -Uri $deployUri -WebSession $script:ChocoSession
                
                if ($deployResponse.StatusCode -eq 200) {
                    Write-LogMessage "Configuration deployed successfully" -Level Success -Tab "ProfileUnity"
                    $statusLabel.Text = "Configuration updated and deployed successfully!"
                } else {
                    Write-LogMessage "Configuration saved but deployment failed" -Level Warning -Tab "ProfileUnity"
                    $statusLabel.Text = "Configuration saved but deployment failed"
                }
            } else {
                $statusLabel.Text = "Configuration updated successfully!"
            }
            
            [System.Windows.Forms.MessageBox]::Show("Configuration updated successfully!`n`n$($selectedUpdates.Count) FlexApp(s) were updated.", "Success", "OK", "Information")
            
            # Clear the grid and disable buttons
            $updatesGrid.Rows.Clear()
            $script:PUUpdateCandidates = @()
            $script:MainForm.Controls.Find('PUPreviewButton', $true)[0].Enabled = $false
            $script:MainForm.Controls.Find('PUCommitButton', $true)[0].Enabled = $false
            $script:MainForm.Controls.Find('PUPreviewTextBox', $true)[0].Text = ""
            
        } else {
            throw "Save failed with status code: $($response.StatusCode)"
        }
        
    }
    catch {
        Write-LogMessage "Configuration update failed: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        $statusLabel.Text = "Update failed: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Configuration update failed: $($_.Exception.Message)", "Error", "OK", "Error")
    }
    finally {
        $progressBar.Visible = $false
    }
}