# File: Functions\ProfileUnity\ProfileUnity-ConfigScanner.ps1
# ================================
# Functions for scanning ProfileUnity configurations for updates

function Start-ProfileUnityConfigScan {
    [CmdletBinding()]
    param()
    
    try {
        $configComboBox = $script:MainForm.Controls.Find('PUConfigComboBox', $true)[0]
        $updatesGrid = $script:MainForm.Controls.Find('PUUpdatesGrid', $true)[0]
        $statusLabel = $script:MainForm.Controls.Find('PUStatusLabel', $true)[0]
        $previewButton = $script:MainForm.Controls.Find('PUPreviewButton', $true)[0]
        $commitButton = $script:MainForm.Controls.Find('PUCommitButton', $true)[0]
        $loadFiltersButton = $script:MainForm.Controls.Find('PULoadFiltersButton', $true)[0]
        $progressBar = $script:MainForm.Controls.Find('PUProgressBar', $true)[0]
        
        # Clear previous results
        $updatesGrid.Rows.Clear()
        $script:PUUpdateCandidates = @()
        $previewButton.Enabled = $false
        $commitButton.Enabled = $false
        $loadFiltersButton.Enabled = $false
      
        
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
        $script:PUCurrentConfig = Get-ProfileUnityConfiguration -ConfigId $configId
        $script:PUConfigModified = $false
        
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
                        
                        # Get the sequence number from the DIA
                        $sequenceNumber = if ($null -ne $dia.Sequence) { $dia.Sequence } else { 999 }
                        
                        # Add to update candidates with sequence number
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
                            Sequence = $sequenceNumber
                            PackageIndex = $dia.FlexAppPackages.IndexOf($package)
                            FilterChanged = $false
                        }
                        
                        $script:PUUpdateCandidates += $updateCandidate
                        
                        # Add to grid
                        $row = $updatesGrid.Rows.Add()
                        $updatesGrid.Rows[$row].Cells["PUSelected"].Value = $false
                        $updatesGrid.Rows[$row].Cells["PUName"].Value = $packageName
                        $updatesGrid.Rows[$row].Cells["PUCurrentVersion"].Value = $currentVersion
                        $updatesGrid.Rows[$row].Cells["PUNewVersion"].Value = $latestVersion
                        
                        # For the filter column, ensure the value exists in the ComboBox items
                        $filterColumn = $updatesGrid.Columns["PUFilter"]
                        if ($filterColumn -and $filterColumn.GetType().Name -eq "DataGridViewComboBoxColumn") {
                            # Add the current filter name to the items if it's not already there
                            if ($filterName -and -not $filterColumn.Items.Contains($filterName)) {
                                $filterColumn.Items.Add($filterName)
                            }
                            # Now safely set the value
                            $updatesGrid.Rows[$row].Cells["PUFilter"].Value = $filterName
                        }
                        
                        $updatesGrid.Rows[$row].Cells["PUSequence"].Value = $sequenceNumber
                        $updatesGrid.Rows[$row].Tag = $updateCandidate
                        
                        $updateCount++
                        Write-LogMessage "Found update for $packageName`: $currentVersion -> $latestVersion (Sequence: $sequenceNumber)" -Level Success -Tab "ProfileUnity"
                    }
                }
            }
        }
        
        $progressBar.Visible = $false
        
        if ($updateCount -gt 0) {
            $statusLabel.Text = "Found $updateCount FlexApp updates available"
            $previewButton.Enabled = $true
            $loadFiltersButton.Enabled = $true
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