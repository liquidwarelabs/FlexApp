# File: Functions\Winget\Start-WingetUpdateScan.ps1
# ================================

function Start-WingetUpdateScan {
    [CmdletBinding()]
    param()
    
    try {
        $scanButton = $script:MainForm.Controls.Find('WingetScanButton', $true)[0]
        $processButton = $script:MainForm.Controls.Find('WingetProcessButton', $true)[0]
        $jobFileTextBox = $script:MainForm.Controls.Find('WingetJobFileTextBox', $true)[0]
        
        if (-not $scanButton -or -not $processButton -or -not $jobFileTextBox) {
            throw "Could not find required controls"
        }
        
        $scanButton.Enabled = $false
        $processButton.Enabled = $false
        $script:WingetCancelInProgress = $false
        
        Update-WingetStatus -Message "Scanning for updates..." -Level Info
        
        # Clear previous results first
        $script:WingetUpdateCandidates = @()
        $updatesGrid = $script:MainForm.Controls.Find('WingetUpdatesGrid', $true)[0]
        if ($updatesGrid) {
            $updatesGrid.Rows.Clear()
        }
        
        # Get update candidates
        $candidates = Get-WingetUpdateCandidates -JobFile $jobFileTextBox.Text
        
        # Check if we got valid results
        if ($null -eq $candidates) {
            $script:WingetUpdateCandidates = @()
            Write-LogMessage "No update candidates returned from scan" -Level Warning -Tab "Winget"
        } else {
            $script:WingetUpdateCandidates = $candidates
        }
        
        # Only populate grid if we have candidates
        if ($script:WingetUpdateCandidates.Count -gt 0) {
            Populate-WingetUpdatesGrid -UpdateCandidates $script:WingetUpdateCandidates
            $processButton.Enabled = $true
            Update-WingetStatus -Message "Found $($script:WingetUpdateCandidates.Count) updates available" -Level Success
        } else {
            Update-WingetStatus -Message "No updates available" -Level Info
        }
        
        $scanButton.Enabled = $true
    }
    catch {
        Write-LogMessage "Scan failed: $($_.Exception.Message)" -Level Error -Tab "Winget"
        Update-WingetStatus -Message "Scan failed: $($_.Exception.Message)" -Level Error
        
        try {
            $scanButton = $script:MainForm.Controls.Find('WingetScanButton', $true)[0]
            if ($scanButton) { $scanButton.Enabled = $true }
        }
        catch { }
        
        # Show error dialog
        [System.Windows.Forms.MessageBox]::Show(
            "Scan failed: $($_.Exception.Message)", 
            "Winget Scan Error", 
            "OK", 
            "Error"
        )
    }
}