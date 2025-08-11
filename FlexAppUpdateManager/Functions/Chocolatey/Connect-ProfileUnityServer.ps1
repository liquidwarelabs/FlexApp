# File: Functions\Chocolatey\Connect-ProfileUnityServer.ps1
# ================================

function Connect-ProfileUnityServer {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Connecting to ProfileUnity server: $($script:Config.ServerName)" -Level Info -Tab "Chocolatey"
        
        Initialize-SSLPolicy
        $password = Get-SecureCredentials
        
        $loginUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/authenticate"
        $body = "username=$($script:Config.AdminUser)&password=$password"
        
        $response = Invoke-WebRequest -Uri $loginUri -Body $body -Method Post -SessionVariable session
        $script:ChocoSession = $session
        
        Write-LogMessage "Successfully connected to ProfileUnity server" -Level Success -Tab "Chocolatey"
        return $true
    }
    catch {
        Write-LogMessage "Failed to connect to ProfileUnity server: $($_.Exception.Message)" -Level Error -Tab "Chocolatey"
        return $false
    }
}
