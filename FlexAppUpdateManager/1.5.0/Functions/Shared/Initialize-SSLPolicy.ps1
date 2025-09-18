# File: Functions\Shared\Initialize-SSLPolicy.ps1
# ================================

function Initialize-SSLPolicy {
    [CmdletBinding()]
    param()
    
    try {
        # Cross-platform SSL policy that works with both PowerShell 5.x and 7.x
        # Detect PowerShell version and .NET version to use appropriate method
        
        $psVersion = $PSVersionTable.PSVersion.Major
        $dotNetVersion = [System.Environment]::Version
        
        Write-LogMessage "PowerShell version: $psVersion, .NET version: $dotNetVersion" -Level Info
        
        # Method 1: Try ServerCertificateValidationCallback (works in both old and new .NET)
        try {
            if ([System.Net.ServicePointManager] -and [System.Net.ServicePointManager].GetProperty('ServerCertificateValidationCallback')) {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {
                    param($sender, $certificate, $chain, $sslPolicyErrors)
                    return $true
                }
                Write-LogMessage "SSL certificate validation disabled using ServerCertificateValidationCallback" -Level Success
            } else {
                throw "ServerCertificateValidationCallback not available"
            }
        }
        catch {
            Write-LogMessage "ServerCertificateValidationCallback method failed: $($_.Exception.Message)" -Level Warning
            
            # Method 2: Try legacy ICertificatePolicy for older .NET Framework
            try {
                if (-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type) {
                    Add-Type -TypeDefinition @"
using System.Net;
using System.Security.Cryptography.X509Certificates;

namespace SSLWorkaround {
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
}
"@ -ErrorAction Stop
                }
                
                [System.Net.ServicePointManager]::CertificatePolicy = New-Object SSLWorkaround.TrustAllCertsPolicy
                Write-LogMessage "SSL certificate validation disabled using ICertificatePolicy (legacy method)" -Level Success
            }
            catch {
                Write-LogMessage "Legacy ICertificatePolicy method also failed: $($_.Exception.Message)" -Level Warning
                Write-LogMessage "Proceeding without certificate validation override - may fail with self-signed certificates" -Level Warning
            }
        }
        
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