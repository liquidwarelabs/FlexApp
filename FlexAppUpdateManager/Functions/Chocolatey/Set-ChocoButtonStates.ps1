# File: Functions\Chocolatey\Set-ChocoButtonStates.ps1
# ================================

function Set-ChocoButtonStates {
    [CmdletBinding()]
    param(
        [bool]$Processing
    )
    
    try {
        $scanButton = $script:MainForm.Controls.Find('ChocoScanButton', $true)[0]
        $processButton = $script:MainForm.Controls.Find('ChocoProcessButton', $true)[0]
        $cancelButton = $script:MainForm.Controls.Find('ChocoCancelButton', $true)[0]
        
        if ($scanButton) { $scanButton.Enabled = -not $Processing }
        if ($processButton) { $processButton.Enabled = -not $Processing }
        if ($cancelButton) { $cancelButton.Enabled = $true }
    }
    catch {
        Write-LogMessage "Error setting button states: $($_.Exception.Message)" -Level Error -Tab "Chocolatey"
    }
}
