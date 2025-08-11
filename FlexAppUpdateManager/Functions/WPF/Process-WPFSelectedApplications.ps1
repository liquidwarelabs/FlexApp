function Process-WPFSelectedApplications {
    param(
        [array]$SelectedApps,
        [System.Windows.Forms.ProgressBar]$ProgressBar = $null,
        [System.Windows.Forms.Label]$StatusLabel = $null
    )
    
    $ProcessedApps = @()
    $TotalApps = $SelectedApps.Count
    $CurrentApp = 0
    
    Write-LogMessage "Processing $TotalApps selected Configuration Manager applications..." -Level Info -Tab "Configuration Manager"
    
    # Ensure we're in the Configuration Manager PS drive context
    $originalLocation = Get-Location
    try {
        if ($script:Config -and $script:Config.CMSettings -and $script:Config.CMSettings.SiteCode -and $script:Config.CMSettings.SiteServer) {
            $siteCode = $script:Config.CMSettings.SiteCode
            $siteServer = $script:Config.CMSettings.SiteServer
            $cmDrivePath = "$siteCode`:\"
            
            Write-LogMessage "DEBUG: Ensuring CM drive exists: $cmDrivePath (Server: $siteServer)" -Level Info -Tab "Configuration Manager"
            
            # Ensure CM module is imported in this context
            $cmModule = Get-Module -Name ConfigurationManager -ErrorAction SilentlyContinue
            if (-not $cmModule) {
                $cmModulePath = "${env:ProgramFiles(x86)}\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
                if (Test-Path $cmModulePath) {
                    Write-LogMessage "DEBUG: Importing CM module in current context: $cmModulePath" -Level Info -Tab "Configuration Manager"
                    Import-Module $cmModulePath -ErrorAction Stop
                    Write-LogMessage "DEBUG: CM module imported successfully" -Level Info -Tab "Configuration Manager"
                } else {
                    throw "Configuration Manager module not found at: $cmModulePath"
                }
            } else {
                Write-LogMessage "DEBUG: CM module already loaded in current context" -Level Info -Tab "Configuration Manager"
            }
            
            # Check if CM drive exists, create if needed
            $existingDrive = Get-PSDrive -Name $siteCode -ErrorAction SilentlyContinue
            if (-not $existingDrive) {
                Write-LogMessage "DEBUG: CM drive does not exist, creating new drive: $siteCode" -Level Info -Tab "Configuration Manager"
                New-PSDrive -Name $siteCode -PSProvider CMSite -Root $siteServer -Description "CM Site Connection" -ErrorAction Stop | Out-Null
                Write-LogMessage "DEBUG: CM drive created successfully: $siteCode" -Level Info -Tab "Configuration Manager"
            } else {
                Write-LogMessage "DEBUG: Using existing CM drive: $siteCode (Root: $($existingDrive.Root))" -Level Info -Tab "Configuration Manager"
            }
            
            Write-LogMessage "DEBUG: Switching to CM drive context: $cmDrivePath" -Level Info -Tab "Configuration Manager"
            Set-Location $cmDrivePath
            Write-LogMessage "DEBUG: Current location: $(Get-Location)" -Level Info -Tab "Configuration Manager"
        } else {
            Write-LogMessage "ERROR: CM configuration not available (Site: $($script:Config.CMSettings.SiteCode), Server: $($script:Config.CMSettings.SiteServer))" -Level Error -Tab "Configuration Manager"
            # Restore original location before returning
            try { Set-Location $originalLocation } catch { }
            return @()
        }
    }
    catch {
        Write-LogMessage "ERROR: Failed to setup CM drive context: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
        Write-LogMessage "DEBUG: Full CM drive setup error: $($_.Exception.ToString())" -Level Info -Tab "Configuration Manager"
        # Restore original location before returning  
        try { Set-Location $originalLocation } catch { }
        return @()
    }
    
    if ($TotalApps -eq 0) {
        if ($StatusLabel) { $StatusLabel.Text = "No applications to process" }
        # Restore original location before returning
        try {
            Set-Location $originalLocation
        }
        catch {
            Write-LogMessage "WARNING: Failed to restore original location: $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
        }
        return @()
    }
    
    foreach ($app in $SelectedApps) {
        $CurrentApp++
        if ($ProgressBar -and $TotalApps -gt 0) {
            $ProgressBar.Value = [int](($CurrentApp / $TotalApps) * 100)
        }
        if ($StatusLabel) { 
            $StatusLabel.Text = "Processing: $app ($CurrentApp of $TotalApps)"
        }
        if ($ProgressBar) {
            [System.Windows.Forms.Application]::DoEvents()
        }
        
        try {
            Write-LogMessage "Processing CM application: '$app'" -Level Info -Tab "Configuration Manager"
            Write-LogMessage "DEBUG: Starting processing for app: '$app'" -Level Info -Tab "Configuration Manager"
            
            $Appdetails = $null
            
            # Try multiple methods to find the application
            $Appdetails = Get-CMApplication | Where-Object { $_.LocalizedDisplayName -eq $app }
            
            if ($Appdetails -eq $null) {
                $Appdetails = Get-CMApplication | Where-Object { $_.LocalizedName -eq $app }
            }
            
            if ($Appdetails -eq $null) {
                $Appdetails = Get-CMApplication | Where-Object { $_.CI_UniqueID -eq $app }
            }
            
            if ($Appdetails -eq $null) {
                $Appdetails = Get-CMApplication -name $app -ErrorAction SilentlyContinue
            }
            
            if ($Appdetails -eq $null) {
                Write-LogMessage "Could not find application: $app" -Level Warning -Tab "Configuration Manager"
                continue
            }
            
            if ($Appdetails -is [array]) {
                $Appdetails = $Appdetails[0]
            }
            
            Write-LogMessage "Found CM application: $($Appdetails.LocalizedDisplayName)" -Level Info -Tab "Configuration Manager"
            Write-LogMessage "DEBUG: CM app details - Name: '$($Appdetails.LocalizedDisplayName)', ID: '$($Appdetails.CI_UniqueID)'" -Level Info -Tab "Configuration Manager"
            
            # Parse XML with error handling for missing elements
            [xml]$appxml = $null
            try {
                Write-LogMessage "DEBUG: Attempting to parse SDMPackageXML for '$app'" -Level Info -Tab "Configuration Manager"
                [xml]$appxml = $Appdetails.SDMPackageXML
                Write-LogMessage "DEBUG: Successfully parsed XML for '$app'" -Level Info -Tab "Configuration Manager"
            }
            catch {
                Write-LogMessage "Error parsing XML for app '$app': $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
                Write-LogMessage "DEBUG: XML parsing failed with error: $($_.Exception.ToString())" -Level Info -Tab "Configuration Manager"
                continue
            }
            
            # Extract application name with fallbacks
            $AppName = $app
            try {
                Write-LogMessage "DEBUG: Extracting app name from XML for '$app'" -Level Info -Tab "Configuration Manager"
                if ($appxml.AppMgmtDigest.Application.DisplayInfo.Info.Title) {
                    $AppName = $appxml.AppMgmtDigest.Application.DisplayInfo.Info.Title
                    Write-LogMessage "DEBUG: Extracted app name from XML: '$AppName'" -Level Info -Tab "Configuration Manager"
                }
            }
            catch {
                Write-LogMessage "Could not extract title from XML for '$app', using original name" -Level Warning -Tab "Configuration Manager"
                Write-LogMessage "DEBUG: App name extraction error: $($_.Exception.ToString())" -Level Info -Tab "Configuration Manager"
            }
            
            # Extract version with fallback
            $appVersion = "0.0.0.0"
            try {
                Write-LogMessage "DEBUG: Extracting version for '$app'" -Level Info -Tab "Configuration Manager"
                if (![string]::IsNullOrWhiteSpace($Appdetails.SoftwareVersion)) {
                    $appVersion = $Appdetails.SoftwareVersion
                    Write-LogMessage "DEBUG: Extracted version: '$appVersion'" -Level Info -Tab "Configuration Manager"
                }
            }
            catch {
                Write-LogMessage "Could not extract version for '$app', using default" -Level Warning -Tab "Configuration Manager"
                Write-LogMessage "DEBUG: Version extraction error: $($_.Exception.ToString())" -Level Info -Tab "Configuration Manager"
            }
            
            # Use the simpler and more reliable extraction logic from the original version
            $installLocation = ""
            $installerArgs = ""
            $Pathandfilename = ""
            $arglist = ""
            
            try {
                Write-LogMessage "DEBUG: Starting installer data extraction for '$app'" -Level Info -Tab "Configuration Manager"
                # Safe XML navigation with null checks
                $installLocation = ""
                $installerArgs = ""
                
                Write-LogMessage "DEBUG: Checking XML structure for '$app'" -Level Info -Tab "Configuration Manager"
                if ($appxml -and $appxml.AppMgmtDigest -and $appxml.AppMgmtDigest.DeploymentType) {
                    $deploymentType = $appxml.AppMgmtDigest.DeploymentType
                    
                    # Check for installer contents location
                    Write-LogMessage "DEBUG: Checking installer contents for '$app'" -Level Info -Tab "Configuration Manager"
                    if ($deploymentType.Installer -and $deploymentType.Installer.Contents -and $deploymentType.Installer.Contents.Content) {
                        $installLocation = $deploymentType.Installer.Contents.Content.Location
                        if (!$installLocation) { $installLocation = "" }
                        Write-LogMessage "DEBUG: Found install location: '$installLocation'" -Level Info -Tab "Configuration Manager"
                    }
                    
                    # Check for install action args
                    Write-LogMessage "DEBUG: Checking install action args for '$app'" -Level Info -Tab "Configuration Manager"
                    if ($deploymentType.Installer -and $deploymentType.Installer.InstallAction -and $deploymentType.Installer.InstallAction.Args) {
                        Write-LogMessage "DEBUG: Found installer action args for '$app'" -Level Info -Tab "Configuration Manager"
                        $installActionArgs = $deploymentType.Installer.InstallAction.Args.arg
                        if ($installActionArgs) {
                            Write-LogMessage "DEBUG: Processing action args for '$app'" -Level Info -Tab "Configuration Manager"
                            $commandLineArg = $installActionArgs | Where-Object { $_.Name -eq "InstallCommandLine" }
                            if ($commandLineArg -and $commandLineArg.'#text') {
                                $installerArgs = $commandLineArg.'#text'
                                Write-LogMessage "DEBUG: Found installer args: '$installerArgs'" -Level Info -Tab "Configuration Manager"
                            }
                        }
                    }
                } else {
                    Write-LogMessage "DEBUG: XML structure missing for '$app'" -Level Info -Tab "Configuration Manager"
                }
                
                # Build path and filename using the original logic
                if (![string]::IsNullOrWhiteSpace($installLocation) -and ![string]::IsNullOrWhiteSpace($installerArgs)) {
                    $Pathandfilename = $installLocation + ((($installerArgs)|ForEach-Object{$_.split('"')[1]}))
                }
                
                # Extract arguments using the original logic
                if (![string]::IsNullOrWhiteSpace($installerArgs)) {
                    if($Pathandfilename -match '.msi'){
                        if ($installerArgs -match '/qn') {
                            $arglist = (($installerArgs -split '.msi"')[1] -split '/qn')[1]
                        }
                        elseif ($installerArgs -match '/q'){
                            $arglist = (($installerArgs -split '.msi"')[1] -split '/q')[1]
                        }
                        elseif ($installerArgs -match '$null'){
                            $arglist = (($installerArgs -split '.msi"')[1] -split '$null')[1]
                        }
                        else {
                            $arglist = (($installerArgs -split '.msi"')[1])
                        }
                    }
                    else{
                        $arglist = ($installerArgs).split('"')[-1]
                    }
                }
                
                Write-LogMessage "Extracted data for '$AppName': Location='$installLocation', Args='$installerArgs', Path='$Pathandfilename', ArgList='$arglist'" -Level Info -Tab "Configuration Manager"
            }
            catch {
                Write-LogMessage "Error extracting installer data for '$app': $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
                Write-LogMessage "DEBUG: Full installer extraction error for '$app': $($_.Exception.ToString())" -Level Info -Tab "Configuration Manager"
                # Use fallback values
                $Pathandfilename = ""
                $arglist = ""
            }
            
            Write-LogMessage "DEBUG: Final extracted values for '$AppName': InstallLocation='$installLocation', Args='$installerArgs', Path='$Pathandfilename', ArgList='$arglist'" -Level Info -Tab "Configuration Manager"
            
            # Create the application object with safe defaults
            Write-LogMessage "DEBUG: Creating application object for '$AppName'" -Level Info -Tab "Configuration Manager"
            $newAppItem = [pscustomobject]@{
                Name = $AppName
                Version = $appVersion
                PackageVersion = $appVersion
                InstallCommandLine = if (![string]::IsNullOrWhiteSpace($installerArgs)) { $installerArgs } else { "" }
                Installer = if (![string]::IsNullOrWhiteSpace($Pathandfilename)) { $Pathandfilename } else { "" }
                InstallerArgs = if (![string]::IsNullOrWhiteSpace($arglist)) { $arglist } else { "" }
                size = 20480
            }
            Write-LogMessage "DEBUG: Application object created successfully for '$AppName'" -Level Info -Tab "Configuration Manager"
            
            # Add lowercase aliases for backward compatibility with null checks
            try {
                Write-LogMessage "DEBUG: Adding member properties for '$AppName'" -Level Info -Tab "Configuration Manager"
                $installerValue = if ($newAppItem.Installer) { $newAppItem.Installer } else { "" }
                $installerArgsValue = if ($newAppItem.InstallerArgs) { $newAppItem.InstallerArgs } else { "" }
                
                Write-LogMessage "DEBUG: Adding installer property: '$installerValue'" -Level Info -Tab "Configuration Manager"
                $newAppItem | Add-Member -NotePropertyName "installer" -NotePropertyValue $installerValue -Force
                
                Write-LogMessage "DEBUG: Adding installerargs property: '$installerArgsValue'" -Level Info -Tab "Configuration Manager"
                $newAppItem | Add-Member -NotePropertyName "installerargs" -NotePropertyValue $installerArgsValue -Force
                
                Write-LogMessage "DEBUG: Member properties added successfully for '$AppName'" -Level Info -Tab "Configuration Manager"
            }
            catch {
                Write-LogMessage "Error adding member properties for '$AppName': $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
                Write-LogMessage "DEBUG: Full Add-Member error for '$AppName': $($_.Exception.ToString())" -Level Info -Tab "Configuration Manager"
            }
            
            Write-LogMessage "Successfully processed '$AppName' - Version: $appVersion, Installer: $($newAppItem.Installer)" -Level Success -Tab "Configuration Manager"
            $ProcessedApps += $newAppItem
        }
        catch {
            Write-LogMessage "Error processing app '$app': $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
            Write-LogMessage "DEBUG: Full processing error for '$app': $($_.Exception.ToString())" -Level Info -Tab "Configuration Manager"
            Write-LogMessage "DEBUG: Error occurred at line: $($_.InvocationInfo.ScriptLineNumber)" -Level Info -Tab "Configuration Manager"
        }
    }
    
    Write-LogMessage "Completed processing. Successfully processed $($ProcessedApps.Count) of $TotalApps applications" -Level Info -Tab "Configuration Manager"
    
    # Restore original location
    try {
        Write-LogMessage "DEBUG: Restoring original location: $originalLocation" -Level Info -Tab "Configuration Manager"
        Set-Location $originalLocation
    }
    catch {
        Write-LogMessage "WARNING: Failed to restore original location: $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
    }
    
    return $ProcessedApps
}
