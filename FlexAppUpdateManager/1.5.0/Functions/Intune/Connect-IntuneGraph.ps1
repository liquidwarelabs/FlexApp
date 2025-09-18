# Functions/Intune/Connect-IntuneGraph.ps1
# Function to authenticate with Microsoft Graph API for Intune

function Connect-IntuneGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClientId,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $true)]
        [string]$ClientSecret
    )

    try {
        Write-Verbose "Connect-IntuneGraph called with ClientId: $ClientId, TenantId: $TenantId, Secret length: $($ClientSecret.Length)"
        
        # Improve .NET HTTP stability and avoid closed connection issues
        [System.Net.ServicePointManager]::DefaultConnectionLimit = 100
        [System.Net.ServicePointManager]::Expect100Continue = $false
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        
        # WORKAROUND: Use MSAL.PS directly due to IntuneWin32App module authentication issues
        Write-Verbose "Using MSAL.PS workaround for authentication..."
        
        # Check and install required modules
        $requiredModules = @("MSAL.PS", "IntuneWin32App")
        foreach ($moduleName in $requiredModules) {
            if (-not (Get-Module -ListAvailable -Name $moduleName)) {
                Write-Warning "$moduleName module not found. Attempting installation..."
                Install-Module -Name $moduleName -Force -Scope CurrentUser
            }
            Import-Module $moduleName -Force
        }
        
        # Convert client secret to secure string
        $secureClientSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
        
        # Get access token using MSAL.PS with timeout
        Write-Verbose "Getting access token with MSAL.PS..."
        Write-Host "Attempting Azure authentication (this may take 30-60 seconds)..." -ForegroundColor Yellow
        
        # Use a job with timeout for the authentication
        $authJob = Start-Job -ScriptBlock {
            param($ClientId, $TenantId, $SecureClientSecret)
            Import-Module MSAL.PS -Force
            $tokenResult = Get-MsalToken -ClientId $ClientId -TenantId $TenantId -ClientSecret $SecureClientSecret -Scopes "https://graph.microsoft.com/.default" -ErrorAction Stop
            return $tokenResult
        } -ArgumentList $ClientId, $TenantId, $secureClientSecret
        
        # Wait for authentication with timeout (30 seconds for faster testing)
        $timeout = 30
        Write-Host "Waiting for authentication (timeout: $timeout seconds)..." -ForegroundColor Yellow
        $authCompleted = Wait-Job -Job $authJob -Timeout $timeout
        
        if (-not $authCompleted) {
            Write-Host "Authentication timed out after $timeout seconds!" -ForegroundColor Red
            Stop-Job -Job $authJob
            Remove-Job -Job $authJob -Force
            Write-Error "Azure authentication timed out"
            return $false
        }
        
        $tokenResult = Receive-Job -Job $authJob
        Remove-Job -Job $authJob -Force
        
        Write-Host "Authentication job completed successfully" -ForegroundColor Green
        
        if (-not $tokenResult -or -not $tokenResult.AccessToken) {
            Write-Error "Failed to obtain access token from Azure AD"
            return $false
        }
        
        Write-Verbose "Successfully obtained access token, expires: $($tokenResult.ExpiresOn)"
        
        # Test the token with a simple Graph API call
        $headers = @{
            'Authorization' = "Bearer $($tokenResult.AccessToken)"
            'Content-Type' = 'application/json'
        }
        
        try {
            Write-Verbose "Testing token with Graph API call..."
            $response = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps?`$top=1" -Headers $headers -Method Get -ErrorAction Stop
            Write-Verbose "Graph API test successful - token is valid (found $($response.value.Count) apps)"
            
            # Connect using the official IntuneWin32App module
            try {
                Write-Verbose "Connecting to Intune using IntuneWin32App module..."
                Connect-MSIntuneGraph -ClientID $ClientId -ClientSecret $ClientSecret -TenantID $TenantId
                Write-Verbose "Successfully connected to Intune using IntuneWin32App module"
            }
            catch {
                Write-Warning "IntuneWin32App connection failed, but MSAL token is valid: $($_.Exception.Message)"
                # Store the token as fallback for direct Graph API calls
                $global:AuthenticationHeader = $headers
            }
            
            return $true
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Verbose "Graph API test failed: $errorMsg"
            
            if ($errorMsg -match "401|403|Unauthorized|Access.*denied") {
                Write-Error "Authentication failed - token is invalid: $errorMsg"
            } else {
                Write-Error "Graph API test failed: $errorMsg"
            }
            return $false
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Verbose "MSAL.PS authentication failed: $errorMessage"
        
        # Check for specific Azure AD error patterns
        if ($errorMessage -match "AADSTS7000215") {
            Write-Error "Invalid client secret provided. Please verify the secret value from Azure Portal."
        } elseif ($errorMessage -match "AADSTS700016") {
            Write-Error "Invalid application (client) ID provided."
        } elseif ($errorMessage -match "AADSTS90002") {
            Write-Error "Invalid tenant ID provided."
        } else {
            Write-Error "Azure authentication failed: $errorMessage"
        }
        return $false
    }
}