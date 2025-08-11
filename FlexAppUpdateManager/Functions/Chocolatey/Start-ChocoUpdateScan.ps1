# File: Functions\Chocolatey\Start-ChocoUpdateScan.ps1
# ================================

function Start-ChocoUpdateScan {
    [CmdletBinding()]
    param()
    
    try {
        $scanButton = $script:MainForm.Controls.Find('ChocoScanButton', $true)[0]
        $cancelScanButton = $script:MainForm.Controls.Find('ChocoCancelScanButton', $true)[0]
        $processButton = $script:MainForm.Controls.Find('ChocoProcessButton', $true)[0]
        $jobFileTextBox = $script:MainForm.Controls.Find('ChocoJobFileTextBox', $true)[0]
        
        if (-not $scanButton -or -not $processButton -or -not $jobFileTextBox) {
            throw "Could not find required controls"
        }
        
        # Reset scan cancellation flag
        $script:ChocoScanCancelled = $false
        
        # Enable/disable buttons appropriately
        $scanButton.Enabled = $false
        $processButton.Enabled = $false
        if ($cancelScanButton) { $cancelScanButton.Enabled = $true }
        $script:ChocoCancelInProgress = $false
        
        Update-ChocoStatus -Message "Scanning for updates..." -Level Info
        
        # Clear previous results
        $script:ChocoUpdateCandidates = @()
        $updatesGrid = $script:MainForm.Controls.Find('ChocoUpdatesGrid', $true)[0]
        if ($updatesGrid) {
            $updatesGrid.Rows.Clear()
        }
        
        # Perform the scan
        $script:ChocoUpdateCandidates = Get-ChocoUpdateCandidates -JobFile $jobFileTextBox.Text
        
        # Check if scan was cancelled
        if ($script:ChocoScanCancelled) {
            $scanButton.Enabled = $true
            if ($cancelScanButton) { $cancelScanButton.Enabled = $false }
            Update-ChocoStatus -Message "Scan cancelled by user" -Level Warning
            return
        }
        
        # Populate the grid with results
        Populate-ChocoUpdatesGrid -UpdateCandidates $script:ChocoUpdateCandidates
        
        $scanButton.Enabled = $true
        if ($cancelScanButton) { $cancelScanButton.Enabled = $false }
        
        if ($script:ChocoUpdateCandidates.Count -gt 0) {
            $processButton.Enabled = $true
            Update-ChocoStatus -Message "Found $($script:ChocoUpdateCandidates.Count) updates available" -Level Success
        } else {
            Update-ChocoStatus -Message "No updates available" -Level Info
        }
    }
    catch {
        Write-LogMessage "Scan failed: $($_.Exception.Message)" -Level Error -Tab "Chocolatey"
        Update-ChocoStatus -Message "Scan failed: $($_.Exception.Message)" -Level Error
        
        try {
            $scanButton = $script:MainForm.Controls.Find('ChocoScanButton', $true)[0]
            $cancelScanButton = $script:MainForm.Controls.Find('ChocoCancelScanButton', $true)[0]
            if ($scanButton) { $scanButton.Enabled = $true }
            if ($cancelScanButton) { $cancelScanButton.Enabled = $false }
        }
        catch { }
    }
}