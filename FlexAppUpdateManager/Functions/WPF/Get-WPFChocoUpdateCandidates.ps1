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
                
                # Allow UI to process events
                [System.Windows.Forms.Application]::DoEvents()
                
                Write-LogMessage "Processing package: $packageName" -Level Info -Tab "Chocolatey"
                
                # Find package in FlexApp inventory - exact match only
                $existingFlexApp = $flexApps | Where-Object { $_.name -eq $packageName }
                
                # Get Chocolatey version
                $chocolateyVersion = Get-ChocolateyPackageVersion -PackageName $packageName
                
                if (-not $chocolateyVersion) {
                    Write-LogMessage "Skipping '$packageName' - not found in Chocolatey" -Level Warning -Tab "Chocolatey"
                    continue
                }
                
                Write-LogMessage "Package '$packageName' Chocolatey version: $chocolateyVersion" -Level Info -Tab "Chocolatey"
                
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
                            NewVersion = $chocolateyVersion
                            SizeMB = $package.size
                            Selected = $false
                        }
                        $updateCandidates += $updateCandidate
                        Write-LogMessage "Found update for '$packageName': $currentVersion -> $chocolateyVersion" -Level Success -Tab "Chocolatey"
                    } else {
                        Write-LogMessage "Package '$packageName' version $currentVersion is current (Chocolatey: $chocolateyVersion)" -Level Info -Tab "Chocolatey"
                    }
                } else {
                    Write-LogMessage "Package '$packageName' not found in FlexApp inventory" -Level Warning -Tab "Chocolatey"
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