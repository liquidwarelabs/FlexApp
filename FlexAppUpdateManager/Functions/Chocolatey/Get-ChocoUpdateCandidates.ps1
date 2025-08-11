# File: Functions\Chocolatey\Get-ChocoUpdateCandidates.ps1
# ================================
# Enhanced version that handles null/empty versions and missing packages in FlexApp inventory

function Get-ChocoUpdateCandidates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$JobFile
    )
    
    try {
        Write-LogMessage "Analyzing packages for updates..." -Level Info -Tab "Chocolatey"
        
        # Get UI controls for progress display
        $progressBar = $script:MainForm.Controls.Find('ChocoScanProgressBar', $true)[0]
        $currentPackageLabel = $script:MainForm.Controls.Find('ChocoCurrentPackageLabel', $true)[0]
        
        # Reset the scan cancellation flag
        $script:ChocoScanCancelled = $false
        
        if (-not (Connect-ProfileUnityServer)) {
            throw "Failed to connect to ProfileUnity server"
        }
        
        $csvPackages = Get-Content -Path $JobFile | ConvertFrom-Csv
        Write-LogMessage "Loaded $($csvPackages.Count) packages from CSV" -Level Info -Tab "Chocolatey"
        
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
            # Check for cancellation
            if ($script:ChocoScanCancelled) {
                Write-LogMessage "Scan cancelled by user" -Level Warning -Tab "Chocolatey"
                Update-ChocoStatus -Message "Scan cancelled" -Level Warning
                break
            }
            
            $currentIndex++
            $packageName = $package.name
            
            # Update progress
            if ($progressBar) {
                $progressBar.Value = $currentIndex
            }
            if ($currentPackageLabel) {
                $currentPackageLabel.Text = "Scanning: $packageName ($currentIndex of $($csvPackages.Count))"
            }
            [System.Windows.Forms.Application]::DoEvents()
            
            Write-LogMessage "Processing package: $packageName" -Level Info -Tab "Chocolatey"
            
            # Use exact match for FlexApp inventory - no wildcards
            $existingFlexApp = $flexApps | Where-Object { $_.name -eq $packageName }
            
            # Check for cancellation before making web request
            if ($script:ChocoScanCancelled) {
                Write-LogMessage "Scan cancelled by user" -Level Warning -Tab "Chocolatey"
                Update-ChocoStatus -Message "Scan cancelled" -Level Warning
                break
            }
            
            # Get Chocolatey version first, regardless of FlexApp status
            $chocolateyVersion = Get-ChocolateyPackageVersion -PackageName $packageName
            
            if (-not $chocolateyVersion) {
                Write-LogMessage "Skipping '$packageName' - not found in Chocolatey" -Level Warning -Tab "Chocolatey"
                continue
            }
            
            Write-LogMessage "Package '$packageName' Chocolatey version: $chocolateyVersion" -Level Info -Tab "Chocolatey"
            
            # Handle three scenarios:
            # 1. Package doesn't exist in FlexApp - create new
            # 2. Package exists but has null/empty version - update
            # 3. Package exists with version - compare versions
            
            if (-not $existingFlexApp) {
                # Scenario 1: Package doesn't exist - create new
                Write-LogMessage "Package '$packageName' does not exist in FlexApps inventory - will create new package" -Level Info -Tab "Chocolatey"
                
                $updateCandidate = [PSCustomObject]@{
                    Name = $package.Name
                    CurrentVersion = "Not Installed"
                    NewVersion = $chocolateyVersion
                    SizeMB = $package.size
                    Installer = $package.installer
                    InstallerArgs = $package.installerargs
                    Selected = $false
                }
                
                $updateCandidates += $updateCandidate
                Write-LogMessage "Will create new package '$packageName' with version $chocolateyVersion" -Level Success -Tab "Chocolatey"
            }
            else {
                # Package exists in FlexApp
                # Get current version and handle null/empty cases
                $currentVersion = ($existingFlexApp.Version | Measure-Object -Maximum).Maximum
                
                # Check if version is null, empty, or "0.0.0.0"
                $versionIsEmpty = [string]::IsNullOrWhiteSpace($currentVersion) -or $currentVersion -eq "0.0.0.0"
                
                if ($versionIsEmpty) {
                    # Scenario 2: Package exists but no version
                    Write-LogMessage "Package '$packageName' exists in FlexApp but has no version (null or empty) - will update with version" -Level Warning -Tab "Chocolatey"
                    
                    $updateCandidate = [PSCustomObject]@{
                        Name = $package.Name
                        CurrentVersion = "Not Set"
                        NewVersion = $chocolateyVersion
                        SizeMB = $package.size
                        Installer = $package.installer
                        InstallerArgs = $package.installerargs
                        Selected = $false
                    }
                    
                    $updateCandidates += $updateCandidate
                    Write-LogMessage "Found update for '$packageName': Not Set -> $chocolateyVersion" -Level Success -Tab "Chocolatey"
                }
                else {
                    # Scenario 3: Package exists with version - compare
                    Write-LogMessage "Package '$packageName' current FlexApp version: $currentVersion" -Level Info -Tab "Chocolatey"
                    
                    try {
                        if ([version]$currentVersion -lt [version]$chocolateyVersion) {
                            $updateCandidate = [PSCustomObject]@{
                                Name = $package.Name
                                CurrentVersion = $currentVersion
                                NewVersion = $chocolateyVersion
                                SizeMB = $package.size
                                Installer = $package.installer
                                InstallerArgs = $package.installerargs
                                Selected = $false
                            }
                            
                            $updateCandidates += $updateCandidate
                            Write-LogMessage "Found update for '$packageName': $currentVersion -> $chocolateyVersion" -Level Success -Tab "Chocolatey"
                        }
                        else {
                            Write-LogMessage "Package '$packageName' version $currentVersion is current (Chocolatey: $chocolateyVersion)" -Level Info -Tab "Chocolatey"
                        }
                    }
                    catch {
                        # If version comparison fails, treat as needing update
                        Write-LogMessage "Version comparison failed for '$packageName': Current=$currentVersion, Chocolatey=$chocolateyVersion - treating as needs update" -Level Warning -Tab "Chocolatey"
                        
                        $updateCandidate = [PSCustomObject]@{
                            Name = $package.Name
                            CurrentVersion = $currentVersion
                            NewVersion = $chocolateyVersion
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
        
        # If scan was cancelled, return empty array
        if ($script:ChocoScanCancelled) {
            return @()
        }
        
        return $updateCandidates
    }
    catch {
        # Hide progress controls on error
        $progressBar = $script:MainForm.Controls.Find('ChocoScanProgressBar', $true)[0]
        $currentPackageLabel = $script:MainForm.Controls.Find('ChocoCurrentPackageLabel', $true)[0]
        if ($progressBar) { $progressBar.Visible = $false }
        if ($currentPackageLabel) { $currentPackageLabel.Visible = $false }
        
        Write-LogMessage "Failed to get update candidates: $($_.Exception.Message)" -Level Error -Tab "Chocolatey"
        throw
    }
}