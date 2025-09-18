# File: Functions\ConfigurationManager\Get-CMApplicationList.ps1
# ================================

function Get-CMApplicationList {
    param([string]$SiteCode)
    
    try {
        # Verify we're in the correct location
        $currentLocation = Get-Location
        Write-LogMessage "Current location: $currentLocation" -Level Info -Tab "Configuration Manager"
        
        if (-not $currentLocation.Path.StartsWith("$SiteCode`:")) {
            Write-LogMessage "Not in CM drive, attempting to set location..." -Level Warning -Tab "Configuration Manager"
            Set-Location "$($SiteCode):\" -ErrorAction Stop
        }
        
        # Test basic connectivity with site info
        Write-LogMessage "Testing CM connection with site information..." -Level Info -Tab "Configuration Manager"
        $siteInfo = Get-CMSite -SiteCode $SiteCode -ErrorAction Stop
        Write-LogMessage "Site information retrieved: $($siteInfo.SiteName)" -Level Success -Tab "Configuration Manager"
        
        # Get all applications with more detailed error handling
        Write-LogMessage "Retrieving applications from Configuration Manager..." -Level Info -Tab "Configuration Manager"
        
        # Try different methods to get applications
        $allApps = $null
        try {
            $allApps = Get-CMApplication -ErrorAction Stop
        }
        catch {
            Write-LogMessage "First attempt failed: $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
            Write-LogMessage "Trying alternative method..." -Level Info -Tab "Configuration Manager"
            
            # Try with Fast parameter
            $allApps = Get-CMApplication -Fast -ErrorAction Stop
        }
        
        if ($allApps -eq $null) {
            Write-LogMessage "No applications returned from Get-CMApplication" -Level Warning -Tab "Configuration Manager"
            return @()
        }
        
        $appCount = if ($allApps -is [array]) { $allApps.Count } else { 1 }
        Write-LogMessage "Retrieved $appCount applications from Configuration Manager" -Level Info -Tab "Configuration Manager"
        
        if ($appCount -eq 0) {
            Write-LogMessage "No applications found in Configuration Manager" -Level Warning -Tab "Configuration Manager"
            return @()
        }
        
        # Process applications with better error handling
        $appList = @()
        $processedCount = 0
        $skippedCount = 0
        
        foreach ($app in $allApps) {
            try {
                $appName = $null
                $appVersion = if (![string]::IsNullOrWhiteSpace($app.SoftwareVersion)) { $app.SoftwareVersion } else { "0.0.0.0" }
                $installerPath = ""
                $installerArgs = ""
                
                # Try multiple name properties
                if (![string]::IsNullOrWhiteSpace($app.LocalizedDisplayName)) {
                    $appName = $app.LocalizedDisplayName
                }
                elseif (![string]::IsNullOrWhiteSpace($app.LocalizedName)) {
                    $appName = $app.LocalizedName
                }
                elseif (![string]::IsNullOrWhiteSpace($app.CI_UniqueID)) {
                    $appName = $app.CI_UniqueID
                }
                
                # Try to extract installer information from XML
                try {
                    if (![string]::IsNullOrWhiteSpace($app.SDMPackageXML)) {
                        [xml]$appxml = $app.SDMPackageXML
                        
                        # Debug: Log the XML structure for first few apps
                        if ($processedCount -lt 3) {
                            Write-LogMessage "DEBUG: App $appName XML structure exists" -Level Info -Tab "Configuration Manager"
                        }
                        
                        # Try multiple possible XML paths for deployment types
                        $deploymentTypes = @()
                        
                        # Try different possible XML paths
                        if ($appxml.AppMgmtDigest.DeploymentType) {
                            $deploymentTypes = $appxml.AppMgmtDigest.DeploymentType
                        }
                        elseif ($appxml.AppMgmtDigest.Application.DeploymentTypes.DeploymentType) {
                            $deploymentTypes = $appxml.AppMgmtDigest.Application.DeploymentTypes.DeploymentType
                        }
                        
                        if ($deploymentTypes) {
                            # Take the first deployment type
                            $deploymentType = if ($deploymentTypes -is [array]) { $deploymentTypes[0] } else { $deploymentTypes }
                            
                            # Extract installer location and command line
                            $installLocation = $deploymentType.Installer.Contents.Content.Location
                            $installCommandLine = ($deploymentType.Installer.InstallAction.Args.arg | Where-Object {$_.Name -eq "InstallCommandLine"}).'#text'
                            
                            if (![string]::IsNullOrWhiteSpace($installLocation) -and ![string]::IsNullOrWhiteSpace($installCommandLine)) {
                                # Extract installer path - same logic as Process-SelectedApplications
                                $installerPath = $installLocation + ((($installCommandLine)|ForEach-Object{$_.split('"')[1]}))
                                

                                # Extract installer arguments - same logic as Process-SelectedApplications
                                $fileExtensions = @('.msi', '.exe', '.bat', '.ps1', '.vbs', '.cmd')
                                $matchesExtension = $false
                                $matchedExtension = ''
                                
                                foreach ($ext in $fileExtensions) {
                                    if ($installerPath -match [regex]::Escape($ext)) {
                                        $matchesExtension = $true
                                        $matchedExtension = $ext
                                        break
                                    }
                                }
                                
                                if ($matchesExtension) {
                                    if($installCommandLine -match '/qn'){
                                        $installerArgs = (($installCommandLine -split "$matchedExtension`"")[1] -split '/qn')[1]
                                    }
                                    elseif ($installCommandLine -match '/q'){
                                        $installerArgs = (($installCommandLine -split "$matchedExtension`"")[1] -split '/q')[1]
                                    }
                                    elseif ($installCommandLine -match '\$null'){
                                        $installerArgs = (($installCommandLine -split "$matchedExtension`"")[1] -split '\$null')[1]
                                    }
                                    else {
                                        $installerArgs = (($installCommandLine -split "$matchedExtension`"")[1])
                                    }
                                }
                                else {
                                    $installerArgs = ($installCommandLine).split('"')[-1]
                                }
                                
                                # Clean up the extracted values
                                if (![string]::IsNullOrWhiteSpace($installerArgs)) {
                                    $installerArgs = $installerArgs.Trim()
                                }
                                
                                # Log what we found for debugging
                                Write-LogMessage "SUCCESS: App '$appName' - Installer: '$installerPath' - Args: '$installerArgs'" -Level Info -Tab "Configuration Manager"
                            }
                            else {
                                Write-LogMessage "DEBUG: App '$appName' - Missing installLocation or installCommandLine" -Level Warning -Tab "Configuration Manager"
                            }
                        }
                        else {
                            Write-LogMessage "DEBUG: App '$appName' - No deployment types found" -Level Warning -Tab "Configuration Manager"
                        }
                    }
                    else {
                        Write-LogMessage "DEBUG: App '$appName' - No SDMPackageXML" -Level Warning -Tab "Configuration Manager"
                    }
                }
                catch {
                    # If XML parsing fails, just continue with empty installer info
                    Write-LogMessage "ERROR: Could not parse installer info for '$appName': $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
                    $installerPath = ""
                    $installerArgs = ""
                }
                
                if (![string]::IsNullOrWhiteSpace($appName)) {
                    $appItem = [PSCustomObject]@{
                        Name = $appName
                        Version = $appVersion
                        Installer = if (![string]::IsNullOrWhiteSpace($installerPath)) { $installerPath } else { "" }
                        InstallerArgs = if (![string]::IsNullOrWhiteSpace($installerArgs)) { $installerArgs.Trim() } else { "" }
                        CI_UniqueID = $app.CI_UniqueID
                        IsEnabled = $app.IsEnabled
                        IsExpired = $app.IsExpired
                    }
                    $appList += $appItem
                    $processedCount++
                } else {
                    $skippedCount++
                }
            }
            catch {
                Write-LogMessage "Error processing application: $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
                $skippedCount++
            }
        }
        
        # Sort by name and return
        $appList = $appList | Sort-Object Name
        
        Write-LogMessage "Processing complete: $processedCount applications processed, $skippedCount skipped" -Level Success -Tab "Configuration Manager"
        return $appList
    }
    catch {
        $errorMessage = $_.Exception.Message
        $fullError = $_.Exception.ToString()
        
        Write-LogMessage "Failed to retrieve application list: $errorMessage" -Level Error -Tab "Configuration Manager"
        Write-LogMessage "Full error details: $fullError" -Level Error -Tab "Configuration Manager"
        
        # Check if it's a common connection issue
        if ($errorMessage -like "*WMI*" -or $errorMessage -like "*RPC*" -or $errorMessage -like "*access*denied*") {
            Write-LogMessage "This appears to be a connectivity or permissions issue." -Level Error -Tab "Configuration Manager"
            Write-LogMessage "Please ensure:" -Level Info -Tab "Configuration Manager"
            Write-LogMessage "1. You are running as Administrator" -Level Info -Tab "Configuration Manager"
            Write-LogMessage "2. You have Configuration Manager admin rights" -Level Info -Tab "Configuration Manager"
            Write-LogMessage "3. The site server is accessible" -Level Info -Tab "Configuration Manager"
            Write-LogMessage "4. Windows Firewall is not blocking the connection" -Level Info -Tab "Configuration Manager"
        }
        
        return @()
    }
}