# File: Functions\Winget\Set-WingetButtonStates.ps1
# ================================

function Set-WingetButtonStates {
    [CmdletBinding()]
    param(
        [bool]$Processing
    )
    
    try {
        $scanButton = $script:MainForm.Controls.Find('WingetScanButton', $true)[0]
        $processButton = $script:MainForm.Controls.Find('WingetProcessButton', $true)[0]
        
        if ($scanButton) { $scanButton.Enabled = -not $Processing }
        if ($processButton) { $processButton.Enabled = -not $Processing }
    }
    catch {
        Write-LogMessage "Error setting button states: $($_.Exception.Message)" -Level Error -Tab "Winget"
    }
}