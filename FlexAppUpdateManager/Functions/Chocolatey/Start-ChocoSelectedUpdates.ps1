# File: Functions\Chocolatey\Start-ChocoSelectedUpdates.ps1
# ================================

function Start-ChocoSelectedUpdates {
    [CmdletBinding()]
    param()
    
    try {
        $updatesGrid = $script:MainForm.Controls.Find('ChocoUpdatesGrid', $true)[0]
        
        if (-not $updatesGrid) {
            throw "Could not find ChocoUpdatesGrid control"
        }
        
        # Use centralized default file setting
        $defaultFile = $script:Config.DefaultFile
        if ([string]::IsNullOrWhiteSpace($defaultFile) -or -not (Test-Path $defaultFile)) {
            [System.Windows.Forms.MessageBox]::Show("Default file not found or not configured: $defaultFile`n`nPlease configure the Default File in the Settings tab.", "File Not Found", "OK", "Error")
            return
        }
        
        # Use centralized primary server setting
        $server = $script:Config.PrimaryServer
        if ([string]::IsNullOrWhiteSpace($server)) {
            [System.Windows.Forms.MessageBox]::Show("Primary Server not configured.`n`nPlease configure the Primary Server in the Settings tab.", "Server Not Configured", "OK", "Error")
            return
        }
        
        $selectedPackages = @()
        foreach ($row in $updatesGrid.Rows) {
            if ($row.Cells["ChocoSelected"].Value -eq $true) {
                $selectedPackages += $row.Tag
            }
        }
        
        if ($selectedPackages.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select at least one package to update.", "No Selection", "OK", "Warning")
            return
        }
        
        $packageList = $selectedPackages | ForEach-Object { "- $($_.Name) ($($_.CurrentVersion) -> $($_.NewVersion))" }
        $confirmMessage = "Are you sure you want to update the following $($selectedPackages.Count) package(s)?`n`n$($packageList -join "`n")"
        
        $result = [System.Windows.Forms.MessageBox]::Show($confirmMessage, "Confirm Update", "YesNo", "Question")
        
        if ($result -eq "Yes") {
            $script:ChocoCancelInProgress = $false
            Update-ChocoStatus -Message "Processing $($selectedPackages.Count) selected updates..." -Level Info
            
            $updatePackages = @()
            foreach ($package in $selectedPackages) {
                $updatePackage = [PSCustomObject]@{
                    Name = $package.Name
                    PackageVersion = $package.NewVersion
                    SizeMB = $package.SizeMB
                    Installer = $package.Installer
                    InstallerArgs = $package.InstallerArgs
                }
                $updatePackages += $updatePackage
            }
            
            Set-ChocoButtonStates -Processing $true
            Start-PackageUpdate -UpdatePackages $updatePackages -DefaultFile $defaultFile -Server $server -SourceTab "Chocolatey"
        }
    }
    catch {
        Write-LogMessage "Update process failed: $($_.Exception.Message)" -Level Error -Tab "Chocolatey"
        Update-ChocoStatus -Message "Update process failed: $($_.Exception.Message)" -Level Error
        Set-ChocoButtonStates -Processing $false
    }
}
