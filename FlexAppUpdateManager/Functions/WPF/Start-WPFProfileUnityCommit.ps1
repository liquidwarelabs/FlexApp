function Start-WPFProfileUnityCommit {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "=== START-WPFPROFILEUNITYCOMMIT FUNCTION CALLED ===" -Level Info -Tab "ProfileUnity"
        Write-LogMessage "Starting ProfileUnity configuration commit..." -Level Info -Tab "ProfileUnity"
        
        # Get UI controls
        $grid = Find-Control "PUFlexAppsGrid"
        $statusLabel = Find-Control "PUStatusLabel"
        $deployCheckBox = Find-Control "PUDeployCheckBox"
        
        if (-not $grid -or -not $statusLabel) {
            throw "Required UI controls not found"
        }
        
        $statusLabel.Content = "Committing changes..."
        
        # Get selected items
        $selectedItems = $grid.ItemsSource | Where-Object { $_.Selected }
        
        if ($selectedItems.Count -eq 0) {
            $statusLabel.Content = "No items selected for commit"
            [System.Windows.MessageBox]::Show(
                "Please select at least one update to commit.", 
                "No Selection", 
                [System.Windows.MessageBoxButton]::OK, 
                [System.Windows.MessageBoxImage]::Warning
            )
            return
        }
        
        # Confirm commit
        $confirmMessage = "Are you sure you want to update $($selectedItems.Count) FlexApp(s) in the ProfileUnity configuration?"
        if ($deployCheckBox -and $deployCheckBox.IsChecked -eq $true) {
            $confirmMessage += "`n`nThe configuration will be DEPLOYED after saving."
        }
        
        $result = [System.Windows.MessageBox]::Show(
            $confirmMessage,
            "Confirm Commit",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )
        
        if ($result -ne [System.Windows.MessageBoxResult]::Yes) {
            $statusLabel.Content = "Commit cancelled"
            return
        }
        
        # Convert selected items to the format expected by ProfileUnity functions
        $script:PUUpdateCandidates = @()
        foreach ($item in $selectedItems) {
            $updateCandidate = [PSCustomObject]@{
                Name = $item.Name
                CurrentVersion = $item.CurrentVersion
                NewVersion = $item.NewVersion
                Sequence = $item.Sequence
                Filter = $item.Filter
                FilterId = $item.FilterId
                FilterChanged = $item.FilterChanged
                ConfigName = $script:PUCurrentConfig.Name
            }
            $script:PUUpdateCandidates += $updateCandidate
        }
        
        # Apply updates to the configuration (using proper ProfileUnity structure)
        Write-LogMessage "Applying $($selectedItems.Count) updates to configuration..." -Level Info -Tab "ProfileUnity"
        $statusLabel.Content = "Applying updates to configuration..."
        
        # Debug: Log the configuration structure  
        $flexAppDias = $script:PUCurrentConfig.FlexAppDias
        Write-LogMessage "Current config has $($flexAppDias.Count) FlexApp DIAs" -Level Info -Tab "ProfileUnity"
        
        foreach ($update in $script:PUUpdateCandidates) {
            Write-LogMessage "Updating $($update.Name) from v$($update.CurrentVersion) to v$($update.NewVersion)..." -Level Info -Tab "ProfileUnity"
            
            # Find the DIA and package in the configuration by sequence number
            $targetDia = $null
            $targetPackage = $null
            $diaIndex = -1
            $packageIndex = -1
            
            for ($i = 0; $i -lt $flexAppDias.Count; $i++) {
                $dia = $flexAppDias[$i]
                if ($dia.Sequence -eq $update.Sequence) {
                    $targetDia = $dia
                    $diaIndex = $i
                    
                    # Look for the package in this DIA
                    if ($dia.FlexAppPackages -and $dia.FlexAppPackages.Count -gt 0) {
                        for ($j = 0; $j -lt $dia.FlexAppPackages.Count; $j++) {
                            $package = $dia.FlexAppPackages[$j]
                            
                            # Find the package in inventory to get its name
                            $inventoryPackage = $script:PUFlexAppInventory | Where-Object { 
                                $_.id -eq $package.FlexAppPackageId 
                            }
                            
                            if ($inventoryPackage -and $inventoryPackage.name -eq $update.Name) {
                                $targetPackage = $package
                                $packageIndex = $j
                                break
                            }
                        }
                    }
                    break
                }
            }
            
            if ($targetDia -and $targetPackage) {
                # Find the new package ID for the updated version
                $newInventoryPackage = $script:PUFlexAppInventory | Where-Object { 
                    $_.name -eq $update.Name -and 
                    "$($_.VersionMajor).$($_.VersionMinor).$($_.VersionBuild).$($_.VersionRevision)" -eq $update.NewVersion 
                }
                
                if ($newInventoryPackage) {
                    # Update the package IDs
                    $targetPackage.FlexAppPackageId = $newInventoryPackage.id
                    $targetPackage.FlexAppPackageUuid = $newInventoryPackage.uuid
                    
                    # Update description with timestamp
                    $date = Get-Date -Format "yyyy-MM-dd HH:mm"
                    $changeText = "Updated $($update.Name) to v$($update.NewVersion) on $date"
                    
                    if ($targetDia.Description) {
                        $targetDia.Description += " | $changeText"
                    } else {
                        $targetDia.Description = $changeText
                    }
                    
                    Write-LogMessage "Successfully updated $($update.Name) to v$($update.NewVersion) (DIA Sequence: $($targetDia.Sequence))" -Level Success -Tab "ProfileUnity"
                } else {
                    Write-LogMessage "Could not find inventory package for $($update.Name) v$($update.NewVersion)" -Level Warning -Tab "ProfileUnity"
                }
                
                # Check if filter was changed and apply filter update
                if ($update.FilterChanged -and $update.FilterId) {
                    Write-LogMessage "Applying filter change for $($update.Name): '$($update.Filter)' (ID: $($update.FilterId))" -Level Info -Tab "ProfileUnity"
                    
                    # Update the DIA's filter assignment
                    if ($targetDia) {
                        $targetDia.FilterId = $update.FilterId
                        Write-LogMessage "Successfully updated filter for $($update.Name) to '$($update.Filter)' (DIA Sequence: $($targetDia.Sequence))" -Level Success -Tab "ProfileUnity"
                    }
                }
            } else {
                Write-LogMessage "Could not find DIA with sequence $($update.Sequence) for $($update.Name)" -Level Warning -Tab "ProfileUnity"
            }
        }
        
        # Save the configuration using ProfileUnity API (same method as original)
        $statusLabel.Content = "Saving configuration to ProfileUnity server..."
        
        Write-LogMessage "DEBUG: Checking script variables before save..." -Level Info -Tab "ProfileUnity"
        Write-LogMessage "DEBUG: script:Config.ServerName = '$($script:Config.ServerName)'" -Level Info -Tab "ProfileUnity"
        Write-LogMessage "DEBUG: script:Config.ServerPort = '$($script:Config.ServerPort)'" -Level Info -Tab "ProfileUnity"
        Write-LogMessage "DEBUG: script:PUCurrentConfig exists = $($script:PUCurrentConfig -ne $null)" -Level Info -Tab "ProfileUnity"
        Write-LogMessage "DEBUG: script:ChocoSession exists = $($script:ChocoSession -ne $null)" -Level Info -Tab "ProfileUnity"
        
        $saveUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/configuration"
        $body = $script:PUCurrentConfig | ConvertTo-Json -Depth 10
        
        Write-LogMessage "Saving configuration to: $saveUri" -Level Info -Tab "ProfileUnity"
        Write-LogMessage "DEBUG: Body length = $($body.Length) characters" -Level Info -Tab "ProfileUnity"
        
        $response = Invoke-WebRequest -Uri $saveUri -Method Post -WebSession $script:ChocoSession -ContentType "application/json" -Body $body
        
        if ($response.StatusCode -eq 200) {
            Write-LogMessage "Configuration saved successfully" -Level Success -Tab "ProfileUnity"
            
            if ($deployCheckBox -and $deployCheckBox.IsChecked -eq $true) {
                $statusLabel.Content = "Deploying configuration..."
                
                # Deploy the configuration
                $configId = ($script:PUConfigurations | Where-Object { $_.name -eq $script:PUCurrentConfig.Name }).id
                $deployUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/configuration/$configId/script?encoding=ascii&deploy=true"
                
                $deployResponse = Invoke-WebRequest -Uri $deployUri -WebSession $script:ChocoSession
                
                if ($deployResponse.StatusCode -eq 200) {
                    Write-LogMessage "Configuration deployed successfully" -Level Success -Tab "ProfileUnity"
                    $statusLabel.Content = "Configuration updated and deployed successfully!"
                } else {
                    Write-LogMessage "Configuration saved but deployment failed" -Level Warning -Tab "ProfileUnity"
                    $statusLabel.Content = "Configuration saved but deployment failed"
                }
            } else {
                $statusLabel.Content = "Configuration updated successfully!"
            }
            
            [System.Windows.MessageBox]::Show(
                "Configuration updated successfully!`n`n$($selectedItems.Count) FlexApp(s) were updated.", 
                "Success", 
                [System.Windows.MessageBoxButton]::OK, 
                [System.Windows.MessageBoxImage]::Information
            )
            
            # Clear the grid and update UI
            $grid.ItemsSource = $null
            $script:PUUpdateCandidates = @()
            
        } else {
            throw "Failed to save configuration. Server returned: $($response.StatusCode)"
        }
    }
    catch {
        Write-LogMessage "Failed to commit changes: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        $statusLabel.Content = "Failed to commit changes"
        [System.Windows.MessageBox]::Show(
            "Error committing changes: $($_.Exception.Message)", 
            "Commit Error", 
            [System.Windows.MessageBoxButton]::OK, 
            [System.Windows.MessageBoxImage]::Error
        )
    }
}
