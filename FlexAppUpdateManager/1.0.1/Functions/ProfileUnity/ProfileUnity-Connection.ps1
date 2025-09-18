# File: Functions\ProfileUnity\ProfileUnity-Connection.ps1
# ================================
# Connection and authentication functions for ProfileUnity

function Connect-ProfileUnityServer {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Connecting to ProfileUnity server: $($script:Config.ServerName)" -Level Info -Tab "ProfileUnity"
        
        Initialize-SSLPolicy
        $password = Get-SecureCredentials
        
        $loginUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/authenticate"
        $body = "username=$($script:Config.AdminUser)&password=$password"
        
        $response = Invoke-WebRequest -Uri $loginUri -Body $body -Method Post -SessionVariable session
        $script:ChocoSession = $session
        
        Write-LogMessage "Successfully connected to ProfileUnity server" -Level Success -Tab "ProfileUnity"
        return $true
    }
    catch {
        Write-LogMessage "Failed to connect to ProfileUnity server: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        return $false
    }
}

function Test-ProfileUnityConnection {
    [CmdletBinding()]
    param()
    
    try {
        # Try a simple API call to test the connection
        $testUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/configuration"
        $response = Invoke-WebRequest -Uri $testUri -WebSession $script:ChocoSession -Method Head
        return $response.StatusCode -eq 200
    }
    catch {
        return $false
    }
}

function Get-ProfileUnityFlexApps {
    [CmdletBinding()]
    param()
    
    try {
        $apiUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/flexapppackage"
        $response = Invoke-WebRequest -Uri $apiUri -WebSession $script:ChocoSession
        $flexApps = ($response.Content | ConvertFrom-Json).TAG.ROWS
        
        Write-LogMessage "Retrieved $($flexApps.Count) FlexApp packages from ProfileUnity" -Level Info -Tab "ProfileUnity"
        return $flexApps
    }
    catch {
        Write-LogMessage "Failed to retrieve FlexApp packages: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        throw
    }
}