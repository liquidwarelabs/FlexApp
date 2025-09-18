function Start-WPFProfileUnityScan {
    [CmdletBinding()]
    param()
    try {
        # Get UI controls
        $configComboBox = Find-Control "PUConfigComboBox"
        $grid = Find-Control "PUFlexAppsGrid"
        $statusLabel = Find-Control "PUStatusLabel"
        $previewButton = Find-Control "PUPreviewButton"
        $commitButton = Find-Control "PUCommitButton"
        $loadFiltersButton = Find-Control "PULoadFiltersButton"
        $progressBar = Find-Control "PUProgressBar"
        
        if (-not $configComboBox -or -not $grid -or -not $statusLabel -or 
            -not $previewButton -or -not $commitButton -or -not $loadFiltersButton -or -not $progressBar) {
            throw "Required UI controls not found"
        }
        
        # Clear previous results
        $grid.ItemsSource = $null
        $script:PUUpdateCandidates = @()
        # Reset the warning flag so we can detect if ItemsSource becomes null again
        $script:PUNoItemsSourceWarningShown = $false
        
        # Disable buttons during scan
        $previewButton.IsEnabled = $false
        $commitButton.IsEnabled = $false
        $loadFiltersButton.IsEnabled = $false
        
        # Get selected configuration
        $selectedConfigName = $configComboBox.SelectedItem
        if (-not $selectedConfigName) {
            throw "No configuration selected"
        }
        
        Write-LogMessage "Scanning configuration: $selectedConfigName" -Level Info -Tab "ProfileUnity"
        $statusLabel.Content = "Loading configuration details..."
        
        # Get configuration ID
        $configId = ($script:PUConfigurations | Where-Object { $_.name -eq $selectedConfigName }).id
        if (-not $configId) {
            throw "Could not find configuration ID for $selectedConfigName"
        }
        
        # Load full configuration
        $script:PUCurrentConfig = Get-ProfileUnityConfiguration -ConfigId $configId
        $script:PUConfigModified = $false
        
        Write-LogMessage "Configuration loaded, checking FlexApp assignments..." -Level Info -Tab "ProfileUnity"
        $statusLabel.Content = "Checking for FlexApp updates..."
        
        # Get FlexApp DIAs
        $flexAppDias = $script:PUCurrentConfig.FlexAppDias
        if (-not $flexAppDias -or $flexAppDias.Count -eq 0) {
            $statusLabel.Content = "No FlexApp assignments found in this configuration"
            return
        }
        
        # Show progress
        $progressBar.Visibility = "Visible"
        $progressBar.Value = 0
        $progressBar.Maximum = $flexAppDias.Count
        
        $updateCandidates = @()
        $updateCount = 0
        
        # Check each FlexApp DIA
        foreach ($dia in $flexAppDias) {
            $progressBar.Value++
            
            if (-not $dia.FlexAppPackages -or $dia.FlexAppPackages.Count -eq 0) {
                continue
            }
            
            foreach ($package in $dia.FlexAppPackages) {
                $packageId = $package.FlexAppPackageId
                $packageUuid = $package.FlexAppPackageUuid
                
                # Find package in inventory
                $inventoryPackage = $script:PUFlexAppInventory | Where-Object { 
                    $_.id -eq $packageId -or $_.uuid -eq $packageUuid 
                }
                
                if (-not $inventoryPackage) {
                    Write-LogMessage "Package ID $packageId not found in inventory" -Level Warning -Tab "ProfileUnity"
                    continue
                }
                
                $packageName = $inventoryPackage.name
                
                # Get current version
                $currentVersion = "$($inventoryPackage.VersionMajor).$($inventoryPackage.VersionMinor).$($inventoryPackage.VersionBuild).$($inventoryPackage.VersionRevision)"
                
                # Find all versions in inventory
                $allVersions = $script:PUFlexAppInventory | Where-Object { $_.name -eq $packageName }
                
                if ($allVersions.Count -gt 1) {
                    # Get latest version
                    $latestPackage = $allVersions | Sort-Object {
                        [version]"$($_.VersionMajor).$($_.VersionMinor).$($_.VersionBuild).$($_.VersionRevision)"
                    } -Descending | Select-Object -First 1
                    
                    $latestVersion = "$($latestPackage.VersionMajor).$($latestPackage.VersionMinor).$($latestPackage.VersionBuild).$($latestPackage.VersionRevision)"
                    
                    # Compare versions
                    if ([version]$currentVersion -lt [version]$latestVersion) {
                        # Get filter name using safe helper function
                        $filterName = Get-ProfileUnityFilterNameById -FilterId $dia.FilterId
                        Write-LogMessage "Filter name for $packageName`: '$filterName'" -Level Info -Tab "ProfileUnity"
                        
                        # Get sequence number
                        $sequenceNumber = if ($null -ne $dia.Sequence) { $dia.Sequence } else { 999 }
                        
                        # Create update candidate
                        $updateCandidate = [PSCustomObject]@{
                            Selected = $false
                            Name = $packageName
                            CurrentVersion = $currentVersion
                            NewVersion = $latestVersion
                            CurrentPackageId = $packageId
                            NewPackageId = $latestPackage.id
                            NewPackageUuid = $latestPackage.uuid
                            Filter = $filterName
                            FilterId = $dia.FilterId
                            DiaIndex = $flexAppDias.IndexOf($dia)
                            Sequence = $sequenceNumber
                            PackageIndex = $dia.FlexAppPackages.IndexOf($package)
                            FilterChanged = $false
                        }
                        
                        $updateCandidates += $updateCandidate
                        $updateCount++
                        
                        Write-LogMessage "Found update for $packageName`: $currentVersion -> $latestVersion (Sequence: $sequenceNumber)" -Level Success -Tab "ProfileUnity"
                    }
                }
            }
        }
        
        # Update UI
        $script:WPFMainWindow.Dispatcher.Invoke([Action]{
            # Create observable collection
            $collection = New-Object System.Collections.ObjectModel.ObservableCollection[object]
            foreach ($candidate in $updateCandidates) {
                $collection.Add($candidate)
            }
            
            # Update grid
            $grid.ItemsSource = $collection
            
            # Update status
            if ($updateCount -gt 0) {
                $statusLabel.Content = "Found $updateCount FlexApp updates available"
                $loadFiltersButton.IsEnabled = $true
            } else {
                $statusLabel.Content = "All FlexApps are up to date in this configuration"
            }
            
            # Re-enable buttons now that scan is complete (they will be properly managed by selection state)
            $previewButton.IsEnabled = $false  # Disabled until items are selected
            $commitButton.IsEnabled = $false   # Disabled until items are selected
            
            # Update button states based on current selection (initially none selected)
            Update-WPFProfileUnityButtonStates
            
            Write-LogMessage "Scan completed - buttons re-enabled and ready for selection-based state management" -Level Info -Tab "ProfileUnity"
            
            # Hide progress
            $progressBar.Visibility = "Collapsed"
        })
        
        # Store candidates for later use
        $script:PUUpdateCandidates = $updateCandidates
    }
    catch {
        Write-LogMessage "Scan failed: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        
        $script:WPFMainWindow.Dispatcher.Invoke([Action]{
            $statusLabel.Content = "Scan failed: $($_.Exception.Message)"
            $progressBar.Visibility = "Collapsed"
            
            [System.Windows.MessageBox]::Show(
                "Scan failed: $($_.Exception.Message)",
                "Error",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
        })
    }
}

# NOTE: Removed duplicate Set-WPFProfileUnityEventHandlers function
# The real event handlers are in Functions/WPF/Set-WPFProfileUnityEventHandlers.ps1


