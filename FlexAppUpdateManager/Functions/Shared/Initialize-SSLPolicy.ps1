# File: Functions\Shared\Initialize-SSLPolicy.ps1
# ================================

function Initialize-SSLPolicy {
    [CmdletBinding()]
    param()
    
    try {
        # Add type for trusting all certificates (useful for self-signed certs)
        Add-Type -TypeDefinition @"
            using System.Net;
            using System.Security.Cryptography.X509Certificates;
            public class TrustAllCertsPolicy : ICertificatePolicy {
                public bool CheckValidationResult(
                    ServicePoint srvPoint, X509Certificate certificate,
                    WebRequest request, int certificateProblem) {
                    return true;
                }
            }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        
        # Configure security protocols
        # Best practice: Use TLS 1.2 and 1.3 only
        # Compatibility mode: Include TLS 1.0 and 1.1 for older servers
        
        $modernProtocols = $false
        
        try {
            # First attempt: Try modern protocols only (TLS 1.2 and 1.3)
            # Note: Tls13 enum value = 12288 (0x3000)
            $tls12 = [System.Net.SecurityProtocolType]::Tls12
            $tls13 = [System.Net.SecurityProtocolType]12288
            
            [System.Net.ServicePointManager]::SecurityProtocol = $tls12 -bor $tls13
            Write-LogMessage "SSL policy initialized with modern protocols (TLS 1.2, 1.3)" -Level Success
            $modernProtocols = $true
        }
        catch {
            Write-LogMessage "TLS 1.3 not available on this system" -Level Info
        }
        
        if (-not $modernProtocols) {
            try {
                # Second attempt: TLS 1.2 only (minimum recommended)
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
                Write-LogMessage "SSL policy initialized with TLS 1.2 only" -Level Success
            }
            catch {
                # Final fallback: Include older protocols for compatibility
                # This should only be used if absolutely necessary
                Write-LogMessage "TLS 1.2 not available, falling back to compatibility mode" -Level Warning
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls,Tls11,Tls12'
                Write-LogMessage "SSL policy initialized in compatibility mode (TLS 1.0, 1.1, 1.2)" -Level Warning
                Write-LogMessage "WARNING: TLS 1.0 and 1.1 are deprecated. Consider updating .NET Framework." -Level Warning
            }
        }
        
        # Additional security settings
        [System.Net.ServicePointManager]::CheckCertificateRevocationList = $true
        [System.Net.ServicePointManager]::DefaultConnectionLimit = 10
        [System.Net.ServicePointManager]::Expect100Continue = $true
        [System.Net.ServicePointManager]::UseNagleAlgorithm = $false
        
    }
    catch {
        Write-LogMessage "Failed to initialize SSL policy: $($_.Exception.Message)" -Level Error
        throw
    }
}