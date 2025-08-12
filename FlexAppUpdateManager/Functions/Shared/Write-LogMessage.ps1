# File: Functions\Shared\Write-LogMessage.ps1
# ================================

function Write-LogMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info',
        
        [string]$Tab = 'General'
    )
    
    $colors = @{
        Info = @{ ForegroundColor = 'White' }
        Warning = @{ ForegroundColor = 'Yellow'; BackgroundColor = 'DarkRed' }
        Error = @{ ForegroundColor = 'Red' }
        Success = @{ ForegroundColor = 'Black'; BackgroundColor = 'Green' }
    }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $colorParams = $colors[$Level]
    Write-Host "[$timestamp] [$Tab] [$Level] $Message" @colorParams
}
