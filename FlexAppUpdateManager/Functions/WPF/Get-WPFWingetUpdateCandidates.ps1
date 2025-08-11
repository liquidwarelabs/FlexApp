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
                
                # Allow UI to process events
                [System.Windows.Forms.Application]::DoEvents()
                
                Write-LogMessage "Processing package: $packageName" -Level Info -Tab "Winget"
                
                # Search for the package in Winget
                Write-LogMessage "Searching for package: $packageName" -Level Info -Tab "Winget"
                
                # Use the robust winget version detection from the original function
                $wingetVersion = Get-WingetPackageVersion -PackageId $packageName
                
                if ($wingetVersion) {
                    Write-LogMessage "Successfully found version $wingetVersion for package '$packageName'" -Level Success -Tab "Winget"
                    Write-LogMessage "Package '$packageName' Winget version: $wingetVersion" -Level Info -Tab "Winget"
                    
                    # Create update candidate (new app to be packaged)
                    $updateCandidate = [PSCustomObject]@{
                        Name = $packageName
                        CurrentVersion = ""  # New app, no current version
                        NewVersion = $wingetVersion
                        SizeMB = $package.size
                        Selected = $false
                    }
                    $updateCandidates += $updateCandidate
                    Write-LogMessage "Found new package '$packageName' with version $wingetVersion" -Level Success -Tab "Winget"
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