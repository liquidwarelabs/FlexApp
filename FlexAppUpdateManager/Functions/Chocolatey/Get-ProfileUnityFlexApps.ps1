# File: Functions\Chocolatey\Get-ProfileUnityFlexApps.ps1
# ================================

function Get-ProfileUnityFlexApps {
    [CmdletBinding()]
    param()
    
    try {
        $apiUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/flexapppackage"
        $response = Invoke-WebRequest -Uri $apiUri -WebSession $script:ChocoSession
        $flexApps = ($response.Content | ConvertFrom-Json).TAG.ROWS
        
        Write-LogMessage "Retrieved $($flexApps.Count) FlexApp packages from ProfileUnity" -Level Info -Tab "Chocolatey"
        return $flexApps
    }
    catch {
        Write-LogMessage "Failed to retrieve FlexApp packages: $($_.Exception.Message)" -Level Error -Tab "Chocolatey"
        throw
    }
}
