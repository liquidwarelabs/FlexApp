function Get-WPFChocoUpdateCandidates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$JobFile,
        [Parameter(Mandatory)]
        [int]$CsvCount
    )
    try {
        Write-LogMessage "Analyzing packages for updates..." -Level Info -Tab "Chocolatey"
        
        # Get UI controls
        $scanStatusLabel = Find-Control "ChocoScanStatusLabel"
        
        if (-not $scanStatusLabel) {
            Write-LogMessage "ChocoScanStatusLabel not found, trying alternative approach" -Level Warning -Tab "Chocolatey"
            # Try to find it directly from the window
            $scanStatusLabel = $script:WPFMainWindow.FindName("ChocoScanStatusLabel")
            if (-not $scanStatusLabel) {
                Write-LogMessage "ChocoScanStatusLabel still not found" -Level Error -Tab "Chocolatey"
                throw "Required UI controls not found"
            }
        }
        
        Write-LogMessage "Found scan status label: $($scanStatusLabel -ne $null)" -Level Info -Tab "Chocolatey"
        Write-LogMessage "Scan status label type: $($scanStatusLabel.GetType().Name)" -Level Info -Tab "Chocolatey"
        
        # Reset scan cancellation flag
        $script:ChocoScanCancelled = $false
        
        try {
            # Get packages from CSV
            if (-not (Test-Path $JobFile)) {
                throw "Job file not found: $JobFile"
            }
            
            $csvPackages = Import-Csv -Path $JobFile
            Write-LogMessage "Loaded $($csvPackages.Count) packages from CSV" -Level Info -Tab "Chocolatey"
            
            # Connect to ProfileUnity
            if (-not (Connect-ProfileUnityServer)) {
                throw "Failed to connect to ProfileUnity server"
            }
            
            # Get FlexApp inventory
            $flexApps = Get-ProfileUnityFlexApps
            Write-LogMessage "Retrieved $($flexApps.Count) FlexApp packages from ProfileUnity" -Level Info -Tab "Chocolatey"
            
            $updateCandidates = @()
            $currentIndex = 0
            
            foreach ($package in $csvPackages) {
                # Check for cancellation
                if ($script:ChocoScanCancelled) {
                    Write-LogMessage "Scan cancelled by user" -Level Warning -Tab "Chocolatey"
                    break
                }
                
                $currentIndex++
                $packageName = $package.name
                
                # Update status with current package being processed
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                    $statusLabel = $script:WPFMainWindow.FindName("ChocoScanStatusLabel")
                    if ($statusLabel) {
                        $statusLabel.Content = "Scanning $packageName... ($currentIndex of $CsvCount)"
                        Write-LogMessage "UI: Status updated to: Scanning $packageName... ($currentIndex of $CsvCount)" -Level Info
                    }
                })
                
                # Allow UI to process events - use WPF dispatcher instead
                $script:WPFMainWindow.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
                
                Write-LogMessage "Processing package: $packageName" -Level Info -Tab "Chocolatey"
                
                # Find package in FlexApp inventory - exact match only
                $existingFlexApp = $flexApps | Where-Object { $_.name -eq $packageName }
                
                # Get Chocolatey version
                $chocolateyVersion = Get-ChocolateyPackageVersion -PackageName $packageName
                
                if (-not $chocolateyVersion) {
                    Write-LogMessage "Skipping '$packageName' - not found in Chocolatey" -Level Warning -Tab "Chocolatey"
                    continue
                }
                
                # Format version to 4-dot notation (e.g., 25.0 -> 25.0.0.0, 20.01 -> 20.1.0.0)
                $formattedChocoVersion = $chocolateyVersion
                if ($chocolateyVersion -match '^(\d+)\.(\d+)$') {
                    $formattedChocoVersion = "$([int]$Matches[1]).$([int]$Matches[2]).0.0"
                } elseif ($chocolateyVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
                    $formattedChocoVersion = "$([int]$Matches[1]).$([int]$Matches[2]).$([int]$Matches[3]).0"
                }
                
                Write-LogMessage "Package '$packageName' Chocolatey version: $formattedChocoVersion (original: $chocolateyVersion)" -Level Info -Tab "Chocolatey"
                
                if ($existingFlexApp) {
                    # Extract the maximum version from FlexApp inventory
                    $currentVersions = $existingFlexApp.version -split '\s+'
                    $currentVersion = ($currentVersions | Measure-Object -Maximum).Maximum
                    Write-LogMessage "Package '$packageName' current FlexApp version: $($existingFlexApp.version)" -Level Info -Tab "Chocolatey"
                    Write-LogMessage "Package '$packageName' using max version: $currentVersion" -Level Info -Tab "Chocolatey"
                    
                    # Compare versions
                    if ($chocolateyVersion -gt $currentVersion) {
                        $updateCandidate = [PSCustomObject]@{
                            Name = $packageName
                            CurrentVersion = $currentVersion
                            NewVersion = $formattedChocoVersion
                            SizeMB = $package.size
                            Selected = $false
                            # Map CSV installer fields to JSON structure
                            Installer = if ($package.installer) { $package.installer } else { $null }
                            InstallerArgs = if ($package.installerargs) { $package.installerargs } else { $null }
                            InstallerUsername = if ($package.installerusername) { $package.installerusername } else { $null }
                            InstallerPassword = if ($package.installerpassword) { $package.installerpassword } else { $null }
                            InstallerExitCode = if ($package.installerexitcode) { $package.installerexitcode } else { $null }
                            InstallerTimeoutMs = if ($package.installertimeoutms) { $package.installertimeoutms } else { $null }
                            # Map other CSV fields
                            Path = if ($package.path) { $package.path } else { $null }
                            PathUsername = if ($package.pathusername) { $package.pathusername } else { $null }
                            PathPassword = if ($package.pathpassword) { $package.pathpassword } else { $null }
                            InitiatingUsername = if ($package.initiatingusername) { $package.initiatingusername } else { $null }
                            SizeGb = if ($package.sizegb) { $package.sizegb } else { $null }
                            Fixed = if ($package.fixed) { $package.fixed } else { $null }
                            Test = if ($package.test) { $package.test } else { "False" }
                            PuAddress = if ($package.puaddress) { $package.puaddress } else { $null }
                            PuUsername = if ($package.puusername) { $package.puusername } else { $null }
                            PuPassword = if ($package.pupassword) { $package.pupassword } else { $null }
                            NoHCCapture = if ($package.nohccapture) { $package.nohccapture } else { $null }
                            NoSystemRestore = if ($package.nosystemrestore) { $package.nosystemrestore } else { $null }
                            AltRestoreCmd = if ($package.altrestorecmd) { $package.altrestorecmd } else { $null }
                            AltRestoreCmdArgs = if ($package.altrestorecmdargs) { $package.altrestorecmdargs } else { $null }
                            WaitAfterInstallerExitsMs = if ($package.waitafterinstallerexitsms) { $package.waitafterinstallerexitsms } else { $null }
                            DontCopyInstallerLocal = if ($package.dontcopyinstallerlocal) { $package.dontcopyinstallerlocal } else { $null }
                            CopyInstallerFolderLocal = if ($package.copyinstallerfolderlocal) { $package.copyinstallerfolderlocal } else { $null }
                            InstallerFolder = if ($package.installerfolder) { $package.installerfolder } else { $null }
                            PreActivationScript = if ($package.preactivationscript) { $package.preactivationscript } else { $null }
                            PostActivationScript = if ($package.postactivationscript) { $package.postactivationscript } else { $null }
                            PreDeactivationScript = if ($package.predeactivationscript) { $package.predeactivationscript } else { $null }
                            PostDeactivationScript = if ($package.postdeactivationscript) { $package.postdeactivationscript } else { $null }
                            NoCallToHome = if ($package.nocalltohome) { $package.nocalltohome } else { $null }
                            DontCreateFlexAppOne = if ($package.dontcreateflexappone) { $package.dontcreateflexappone } else { $null }
                            DontCreateFlexAppOneV1 = if ($package.dontcreateflexapponev1) { $package.dontcreateflexapponev1 } else { $null }
                            DontCreateFlexAppOneV2 = if ($package.dontcreateflexapponev2) { $package.dontcreateflexapponev2 } else { $null }
                            FlexAppOneCliOverride = if ($package.flexapponeclioverride) { $package.flexapponeclioverride } else { $null }
                            DontCaptureUserProfileData = if ($package.dontcaptureuserprofiledata) { $package.dontcaptureuserprofiledata } else { $null }
                            DontCaptureUserRegistry = if ($package.dontcaptureuserregistry) { $package.dontcaptureuserregistry } else { $null }
                            DontCapture = if ($package.dontcapture) { $package.dontcapture } else { $null }
                            PackagesXml = if ($package.packagesxml) { $package.packagesxml } else { $null }
                            PuConfiguration = if ($package.puconfiguration) { $package.puconfiguration } else { $null }
                            PuFilter = if ($package.pufilter) { $package.pufilter } else { $null }
                            PuDescription = if ($package.pudescription) { $package.pudescription } else { $null }
                            CustomStorageUrl = if ($package.customstorageurl) { $package.customstorageurl } else { $null }
                            AzureMaximumConcurrency = if ($package.azuremaximumconcurrency) { $package.azuremaximumconcurrency } else { $null }
                            AzureInitialTransferSizeMb = if ($package.azureinitialtransfersizemb) { $package.azureinitialtransfersizemb } else { $null }
                            AzureMaximumTransferSizeMb = if ($package.azuremaximumtransfersizemb) { $package.azuremaximumtransfersizemb } else { $null }
                        }
                        $updateCandidates += $updateCandidate
                        Write-LogMessage "Found update for '$packageName': $currentVersion -> $formattedChocoVersion" -Level Success -Tab "Chocolatey"
                    } else {
                        Write-LogMessage "Package '$packageName' version $currentVersion is current (Chocolatey: $formattedChocoVersion)" -Level Info -Tab "Chocolatey"
                    }
                } else {
                    # Package not found in FlexApp inventory - create candidate for new packaging
                    $updateCandidate = [PSCustomObject]@{
                        Name = $packageName
                        CurrentVersion = $null  # No current version in ProfileUnity
                        NewVersion = $formattedChocoVersion
                        SizeMB = $package.size
                        Selected = $false
                        # Map CSV installer fields to JSON structure
                        Installer = if ($package.installer) { $package.installer } else { $null }
                        InstallerArgs = if ($package.installerargs) { $package.installerargs } else { $null }
                        InstallerUsername = if ($package.installerusername) { $package.installerusername } else { $null }
                        InstallerPassword = if ($package.installerpassword) { $package.installerpassword } else { $null }
                        InstallerExitCode = if ($package.installerexitcode) { $package.installerexitcode } else { $null }
                        InstallerTimeoutMs = if ($package.installertimeoutms) { $package.installertimeoutms } else { $null }
                        # Map other CSV fields
                        Path = if ($package.path) { $package.path } else { $null }
                        PathUsername = if ($package.pathusername) { $package.pathusername } else { $null }
                        PathPassword = if ($package.pathpassword) { $package.pathpassword } else { $null }
                        InitiatingUsername = if ($package.initiatingusername) { $package.initiatingusername } else { $null }
                        SizeGb = if ($package.sizegb) { $package.sizegb } else { $null }
                        Fixed = if ($package.fixed) { $package.fixed } else { $null }
                        Test = if ($package.test) { $package.test } else { "False" }
                        PuAddress = if ($package.puaddress) { $package.puaddress } else { $null }
                        PuUsername = if ($package.puusername) { $package.puusername } else { $null }
                        PuPassword = if ($package.pupassword) { $package.pupassword } else { $null }
                        NoHCCapture = if ($package.nohccapture) { $package.nohccapture } else { $null }
                        NoSystemRestore = if ($package.nosystemrestore) { $package.nosystemrestore } else { $null }
                        AltRestoreCmd = if ($package.altrestorecmd) { $package.altrestorecmd } else { $null }
                        AltRestoreCmdArgs = if ($package.altrestorecmdargs) { $package.altrestorecmdargs } else { $null }
                        WaitAfterInstallerExitsMs = if ($package.waitafterinstallerexitsms) { $package.waitafterinstallerexitsms } else { $null }
                        DontCopyInstallerLocal = if ($package.dontcopyinstallerlocal) { $package.dontcopyinstallerlocal } else { $null }
                        CopyInstallerFolderLocal = if ($package.copyinstallerfolderlocal) { $package.copyinstallerfolderlocal } else { $null }
                        InstallerFolder = if ($package.installerfolder) { $package.installerfolder } else { $null }
                        PreActivationScript = if ($package.preactivationscript) { $package.preactivationscript } else { $null }
                        PostActivationScript = if ($package.postactivationscript) { $package.postactivationscript } else { $null }
                        PreDeactivationScript = if ($package.predeactivationscript) { $package.predeactivationscript } else { $null }
                        PostDeactivationScript = if ($package.postdeactivationscript) { $package.postdeactivationscript } else { $null }
                        NoCallToHome = if ($package.nocalltohome) { $package.nocalltohome } else { $null }
                        DontCreateFlexAppOne = if ($package.dontcreateflexappone) { $package.dontcreateflexappone } else { $null }
                        DontCreateFlexAppOneV1 = if ($package.dontcreateflexapponev1) { $package.dontcreateflexapponev1 } else { $null }
                        DontCreateFlexAppOneV2 = if ($package.dontcreateflexapponev2) { $package.dontcreateflexapponev2 } else { $null }
                        FlexAppOneCliOverride = if ($package.flexapponeclioverride) { $package.flexapponeclioverride } else { $null }
                        DontCaptureUserProfileData = if ($package.dontcaptureuserprofiledata) { $package.dontcaptureuserprofiledata } else { $null }
                        DontCaptureUserRegistry = if ($package.dontcaptureuserregistry) { $package.dontcaptureuserregistry } else { $null }
                        DontCapture = if ($package.dontcapture) { $package.dontcapture } else { $null }
                        PackagesXml = if ($package.packagesxml) { $package.packagesxml } else { $null }
                        PuConfiguration = if ($package.puconfiguration) { $package.puconfiguration } else { $null }
                        PuFilter = if ($package.pufilter) { $package.pufilter } else { $null }
                        PuDescription = if ($package.pudescription) { $package.pudescription } else { $null }
                        CustomStorageUrl = if ($package.customstorageurl) { $package.customstorageurl } else { $null }
                        AzureMaximumConcurrency = if ($package.azuremaximumconcurrency) { $package.azuremaximumconcurrency } else { $null }
                        AzureInitialTransferSizeMb = if ($package.azureinitialtransfersizemb) { $package.azureinitialtransfersizemb } else { $null }
                        AzureMaximumTransferSizeMb = if ($package.azuremaximumtransfersizemb) { $package.azuremaximumtransfersizemb } else { $null }
                    }
                    $updateCandidates += $updateCandidate
                    Write-LogMessage "Found new package '$packageName' for packaging with version $formattedChocoVersion" -Level Success -Tab "Chocolatey"
                }
            }
            
            return $updateCandidates
        }
        finally {
            # No status update here - let the calling function handle the final status
            Write-LogMessage "Get-WPFChocoUpdateCandidates completed" -Level Info -Tab "Chocolatey"
        }
    }
    catch {
        Write-LogMessage "Error analyzing packages: $($_.Exception.Message)" -Level Error -Tab "Chocolatey"
        throw
    }
}