# File: Functions\Shared\Get-SecureCredentials.ps1
# ================================

function Get-SecureCredentials {
    [CmdletBinding()]
    param()
    
    try {
        if (-not (Test-Path $script:Config.PasswordFile)) {
            throw "Password file not found: $($script:Config.PasswordFile)"
        }
        
        if (-not (Test-Path $script:Config.AESKeyFile)) {
            throw "AES key file not found: $($script:Config.AESKeyFile)"
        }
        
        $aesKey = Get-Content -Path $script:Config.AESKeyFile
        $encryptedPassword = Get-Content -Path $script:Config.PasswordFile
        $securePassword = $encryptedPassword | ConvertTo-SecureString -Key $aesKey
        
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
    }
    catch {
        Write-LogMessage "Failed to retrieve credentials: $($_.Exception.Message)" -Level Error -Tab "Chocolatey"
        throw
    }
}
