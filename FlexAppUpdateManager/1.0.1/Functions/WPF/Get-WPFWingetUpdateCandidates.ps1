function Get-WPFWingetUpdateCandidates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$JobFile,
        [Parameter(Mandatory)]
        [int]$CsvCount
    )
    try {
        Write-LogMessage "Analyzing packages for Winget updates..." -Level Info -Tab "Winget"
        
        # Get UI controls
        $currentPackageLabel = Find-Control "WingetCurrentPackageLabel"
        
        if (-not $currentPackageLabel) {
            throw "Required UI controls not found"
        }
        
        # Reset scan cancellation flag
        $script:WingetScanCancelled = $false
        
        try {
            # Get packages from CSV
            if (-not (Test-Path $JobFile)) {
                throw "Job file not found: $JobFile"
            }
            
            $csvPackages = Import-Csv -Path $JobFile
            Write-LogMessage "Loaded $($csvPackages.Count) packages from CSV" -Level Info -Tab "Winget"
            
            $updateCandidates = @()
            $currentIndex = 0
            
            foreach ($package in $csvPackages) {
                # Check for cancellation
                if ($script:WingetScanCancelled) {
                    Write-LogMessage "Scan cancelled by user" -Level Warning -Tab "Winget"
                    break
                }
                
                $currentIndex++
                $packageName = $package.name
                
                # Update status with current package being processed
                $script:WPFMainWindow.Dispatcher.BeginInvoke([Action]{
                    $statusLabel = $script:WPFMainWindow.FindName("WingetCurrentPackageLabel")
                    if ($statusLabel) {
                        $statusLabel.Content = "Scanning $packageName... ($currentIndex of $CsvCount)"
                        Write-LogMessage "UI: Winget status updated to: Scanning $packageName... ($currentIndex of $CsvCount)" -Level Info
                    }
                })
                
                # Allow UI to process events - use WPF dispatcher instead
                $script:WPFMainWindow.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
                
                Write-LogMessage "Processing package: $packageName" -Level Info -Tab "Winget"
                
                # Search for the package in Winget
                Write-LogMessage "Searching for package: $packageName" -Level Info -Tab "Winget"
                
                # Use the robust winget version detection from the original function
                $wingetVersion = Get-WingetPackageVersion -PackageId $packageName
                
                if ($wingetVersion) {
                    # Format version to 4-dot notation (e.g., 25.0 -> 25.0.0.0, 20.01 -> 20.1.0.0)
                    $formattedVersion = $wingetVersion
                    if ($wingetVersion -match '^(\d+)\.(\d+)$') {
                        $formattedVersion = "$([int]$Matches[1]).$([int]$Matches[2]).0.0"
                    } elseif ($wingetVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
                        $formattedVersion = "$([int]$Matches[1]).$([int]$Matches[2]).$([int]$Matches[3]).0"
                    }
                    
                    # Get the actual package ID that was found in Winget
                    # This ensures we use the correct case and format
                    $actualPackageId = $packageName
                    
                    # Try to get the exact package ID from winget search
                    try {
                        $searchOutput = & winget search --id $packageName --exact --accept-source-agreements 2>&1
                        if ($searchOutput -and $searchOutput -notlike "*No package*") {
                            $outputLines = @()
                            if ($searchOutput -is [string]) {
                                $outputLines = $searchOutput -split "`r?`n"
                            } else {
                                $outputLines = $searchOutput | Out-String -Stream
                            }
                            
                            # Find the header line and get the actual package ID
                            $foundHeader = $false
                            foreach ($line in $outputLines) {
                                if ($line -match '^-+\s+-+\s+-+') {
                                    $foundHeader = $true
                                    continue
                                }
                                
                                if ($foundHeader -and $line.Trim() -ne "") {
                                    # Parse the line to get the actual package ID
                                    $parts = $line -split '\s{2,}' | Where-Object { $_.Trim() -ne "" }
                                    if ($parts.Count -ge 2) {
                                        # The second column should be the package ID
                                        $actualPackageId = $parts[1]
                                        break
                                    }
                                }
                            }
                        }
                    } catch {
                        Write-LogMessage "Could not determine exact package ID, using original: $packageName" -Level Warning -Tab "Winget"
                    }
                    
                    Write-LogMessage "Successfully found version $formattedVersion for package '$packageName' (ID: $actualPackageId)" -Level Success -Tab "Winget"
                    Write-LogMessage "Package '$packageName' Winget version: $formattedVersion (original: $wingetVersion)" -Level Info -Tab "Winget"
                    
                    # Get the custom installer path from UI
                    $wingetInstallerTextBox = Find-Control "WingetInstallerTextBox"
                    $customInstallerPath = if ($wingetInstallerTextBox -and $wingetInstallerTextBox.Text) { 
                        $wingetInstallerTextBox.Text 
                    } else { 
                        "PreReqs\Winget\winget-installer.ps1" 
                    }
                    
                    # Create update candidate (new app to be packaged)
                    $updateCandidate = [PSCustomObject]@{
                        Name = $packageName
                        CurrentVersion = $null  # New app, no current version
                        NewVersion = $formattedVersion
                        SizeMB = $package.size
                        Selected = $false
                        # Always use Winget-specific installer and args (ignore CSV installer values)
                        Installer = $customInstallerPath
                        InstallerArgs = "-PackageId `"$actualPackageId`""
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
                        PackageVersion = $null  # New package, no version in ProfileUnity
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
                    Write-LogMessage "Found new package '$packageName' with version $formattedVersion" -Level Success -Tab "Winget"
                } else {
                    Write-LogMessage "Package '$packageName' not found in Winget" -Level Warning -Tab "Winget"
                }
            }
            
            return $updateCandidates
        }
        finally {
            # No status update here - let the calling function handle the final status
            Write-LogMessage "Get-WPFWingetUpdateCandidates completed" -Level Info -Tab "Winget"
        }
    }
    catch {
        Write-LogMessage "Scan failed: $($_.Exception.Message)" -Level Error -Tab "Winget"
        throw
    }
}