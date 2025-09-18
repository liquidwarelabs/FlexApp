# File: Functions\ConfigurationManager\Get-FlexAppInventoryForCM.ps1
# ================================

function Get-FlexAppInventoryForCM {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Connecting to FlexApp inventory for version checking..." -Level Info -Tab "Configuration Manager"
        
        # Use the same connection logic as Chocolatey tab
        Initialize-SSLPolicy
        $password = Get-SecureCredentials
        
        $loginUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/authenticate"
        $body = "username=$($script:Config.AdminUser)&password=$password"
        
        $response = Invoke-WebRequest -Uri $loginUri -Body $body -Method Post -SessionVariable session
        
        $apiUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/flexapppackage"
        $response = Invoke-WebRequest -Uri $apiUri -WebSession $session
        $flexApps = ($response.Content | ConvertFrom-Json).TAG.ROWS
        
        Write-LogMessage "Retrieved $($flexApps.Count) FlexApp packages for version comparison" -Level Success -Tab "Configuration Manager"
        return $flexApps
    }
    catch {
        Write-LogMessage "Could not retrieve FlexApp inventory: $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
        Write-LogMessage "Proceeding without version checking" -Level Info -Tab "Configuration Manager"
        return @()
    }
}
