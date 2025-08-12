function Get-ProfileUnityConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigId
    )
    
    try {
        $configUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/configuration/$ConfigId"
        $response = Invoke-WebRequest -Uri $configUri -WebSession $script:ChocoSession
        $configData = ($response.Content | ConvertFrom-Json)
        return $configData.tag
    }
    catch {
        Write-LogMessage "Failed to get configuration: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        throw
    }
}
