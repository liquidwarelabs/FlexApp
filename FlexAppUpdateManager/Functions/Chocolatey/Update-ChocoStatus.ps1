# File: Functions\Chocolatey\Update-ChocoStatus.ps1
# ================================

function Update-ChocoStatus {
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$Level = 'Info'
    )
    
    try {
        $statusLabel = $script:MainForm.Controls.Find('ChocoStatusLabel', $true)[0]
        if ($statusLabel) {
            $statusLabel.Text = $Message
            
            $colorMap = @{
                Info = [System.Drawing.Color]::Black
                Warning = [System.Drawing.Color]::Orange
                Error = [System.Drawing.Color]::Red
                Success = [System.Drawing.Color]::Green
            }
            
            $statusLabel.ForeColor = $colorMap[$Level]
            $script:MainForm.Refresh()
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
    catch {
        # Ignore GUI update errors
    }
}
