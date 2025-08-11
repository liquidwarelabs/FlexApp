# File: Functions\Winget\Get-WingetUpdateCandidates.ps1
# ================================
# Enhanced version that handles null/empty versions and missing packages in FlexApp inventory

function Get-WingetUpdateCandidates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$JobFile
    )
    
    try {
        Write-LogMessage "Analyzing packages for Winget updates..." -Level Info -Tab "Winget"
        
        # Get UI controls for progress display
        $progressBar = $script:MainForm.Controls.Find('WingetScanProgressBar', $true)[0]
        $currentPackageLabel = $script:MainForm.Controls.Find('WingetCurrentPackageLabel', $true)[0]
        
        # Check if winget is installed
        try {
            $wingetVersion = winget --version
            Write-LogMessage "Winget version: $wingetVersion" -Level Info -Tab "Winget"
        }
        catch {
            throw "Winget is not installed or not accessible. Please install Windows Package Manager (winget) first."
        }
        
        # Use the shared connection function from Chocolatey
        if (-not (Connect-ProfileUnityServer)) {
            throw "Failed to connect to ProfileUnity server"
        }
        
        $csvPackages = Get-Content -Path $JobFile | ConvertFrom-Csv
        Write-LogMessage "Loaded $($csvPackages.Count) packages from CSV" -Level Info -Tab "Winget"
        
        # Show progress controls
        if ($progressBar) {
            $progressBar.Visible = $true
            $progressBar.Minimum = 0
            $progressBar.Maximum = $csvPackages.Count
            $progressBar.Value = 0
        }
        if ($currentPackageLabel) {
            $currentPackageLabel.Visible = $true
        }
        
        $flexApps = Get-ProfileUnityFlexApps
        $updateCandidates = @()
        $currentIndex = 0
        
        foreach ($package in $csvPackages) {
            $currentIndex++
            $packageId = $package.name
            
            # Update progress
            if ($progressBar) {
                $progressBar.Value = $currentIndex
            }
            if ($currentPackageLabel) {
                $currentPackageLabel.Text = "Scanning: $packageId ($currentIndex of $($csvPackages.Count))"
            }
            [System.Windows.Forms.Application]::DoEvents()
            
            Write-LogMessage "Processing package: $packageId" -Level Info -Tab "Winget"
            
            # Use exact match for FlexApp inventory - no wildcards
            $existingFlexApp = $flexApps | Where-Object { $_.name -eq $packageId }
            
            # Get Winget version first, regardless of FlexApp status
            $wingetVersion = Get-WingetPackageVersion -PackageId $packageId
            
            if (-not $wingetVersion) {
                Write-LogMessage "Skipping '$packageId' - not found in Winget repository" -Level Warning -Tab "Winget"
                continue
            }
            
            Write-LogMessage "Package '$packageId' Winget version: $wingetVersion" -Level Info -Tab "Winget"
            
            # Handle three scenarios:
            # 1. Package doesn't exist in FlexApp - create new
            # 2. Package exists but has null/empty version - update
            # 3. Package exists with version - compare versions
            
            if (-not $existingFlexApp) {
                # Scenario 1: Package doesn't exist - create new
                Write-LogMessage "Package '$packageId' does not exist in FlexApps inventory - will create new package" -Level Info -Tab "Winget"
                
                $updateCandidate = [PSCustomObject]@{
                    Name = $package.Name
                    CurrentVersion = "Not Installed"
                    NewVersion = $wingetVersion
                    SizeMB = $package.size
                    Installer = $package.installer
                    InstallerArgs = $package.installerargs
                    Selected = $false
                }
                
                $updateCandidates += $updateCandidate
                Write-LogMessage "Will create new package '$packageId' with version $wingetVersion" -Level Success -Tab "Winget"
            }
            else {
                # Package exists in FlexApp
                # Get current version and handle null/empty cases
                $currentVersion = ($existingFlexApp.Version | Measure-Object -Maximum).Maximum
                
                # Check if version is null, empty, or "0.0.0.0"
                $versionIsEmpty = [string]::IsNullOrWhiteSpace($currentVersion) -or $currentVersion -eq "0.0.0.0"
                
                if ($versionIsEmpty) {
                    # Scenario 2: Package exists but no version
                    Write-LogMessage "Package '$packageId' exists in FlexApp but has no version (null or empty) - will update with version" -Level Warning -Tab "Winget"
                    
                    $updateCandidate = [PSCustomObject]@{
                        Name = $package.Name
                        CurrentVersion = "Not Set"
                        NewVersion = $wingetVersion
                        SizeMB = $package.size
                        Installer = $package.installer
                        InstallerArgs = $package.installerargs
                        Selected = $false
                    }
                    
                    $updateCandidates += $updateCandidate
                    Write-LogMessage "Found update for '$packageId': Not Set -> $wingetVersion" -Level Success -Tab "Winget"
                }
                else {
                    # Scenario 3: Package exists with version - compare
                    Write-LogMessage "Package '$packageId' current FlexApp version: $currentVersion" -Level Info -Tab "Winget"
                    
                    # Clean version strings for comparison
                    $currentVersionClean = $currentVersion -replace '[^\d\.]', ''
                    $wingetVersionClean = $wingetVersion -replace '[^\d\.]', ''
                    
                    try {
                        if ([version]$currentVersionClean -lt [version]$wingetVersionClean) {
                            $updateCandidate = [PSCustomObject]@{
                                Name = $package.Name
                                CurrentVersion = $currentVersion
                                NewVersion = $wingetVersion
                                SizeMB = $package.size
                                Installer = $package.installer
                                InstallerArgs = $package.installerargs
                                Selected = $false
                            }
                            
                            $updateCandidates += $updateCandidate
                            Write-LogMessage "Found update for '$packageId': $currentVersion -> $wingetVersion" -Level Success -Tab "Winget"
                        }
                        else {
                            Write-LogMessage "Package '$packageId' version $currentVersion is current (Winget: $wingetVersion)" -Level Info -Tab "Winget"
                        }
                    }
                    catch {
                        # If version comparison fails, treat as needing update
                        Write-LogMessage "Version comparison failed for '$packageId': Current=$currentVersion, Winget=$wingetVersion - treating as needs update" -Level Warning -Tab "Winget"
                        
                        $updateCandidate = [PSCustomObject]@{
                            Name = $package.Name
                            CurrentVersion = $currentVersion
                            NewVersion = $wingetVersion
                            SizeMB = $package.size
                            Installer = $package.installer
                            InstallerArgs = $package.installerargs
                            Selected = $false
                        }
                        
                        $updateCandidates += $updateCandidate
                    }
                }
            }
        }
        
        # Hide progress controls
        if ($progressBar) {
            $progressBar.Visible = $false
        }
        if ($currentPackageLabel) {
            $currentPackageLabel.Visible = $false
        }
        
        return $updateCandidates
    }
    catch {
        # Hide progress controls on error
        $progressBar = $script:MainForm.Controls.Find('WingetScanProgressBar', $true)[0]
        $currentPackageLabel = $script:MainForm.Controls.Find('WingetCurrentPackageLabel', $true)[0]
        if ($progressBar) { $progressBar.Visible = $false }
        if ($currentPackageLabel) { $currentPackageLabel.Visible = $false }
        
        Write-LogMessage "Failed to get Winget update candidates: $($_.Exception.Message)" -Level Error -Tab "Winget"
        throw
    }
}