function Initialize-WPFPackageSources {
    [CmdletBinding()]
    param()

    try {
        # Check if Chocolatey is installed
        $chocoInstalled = Get-Command choco -ErrorAction SilentlyContinue
        if (-not $chocoInstalled) {
            Write-LogMessage "Chocolatey not found. Installing Chocolatey..." -Level Info -Tab "General"
            
            # Install Chocolatey
            $installScript = "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
            Invoke-Expression $installScript
            
            # Refresh environment
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            Write-LogMessage "Chocolatey installation completed" -Level Success -Tab "General"
        }

        # Check if Chocolatey provider is available
        $chocoProvider = Get-PackageProvider -Name Chocolatey -ErrorAction SilentlyContinue
        if (-not $chocoProvider) {
            Write-LogMessage "Installing Chocolatey PackageProvider..." -Level Info -Tab "General"
            Install-PackageProvider -Name Chocolatey -Force -Scope CurrentUser | Out-Null
            Write-LogMessage "Chocolatey PackageProvider installed successfully" -Level Success -Tab "General"
        }

        # Check if Chocolatey source exists
        $chocoSource = Get-PackageSource -Name chocolatey -ErrorAction SilentlyContinue
        if (-not $chocoSource) {
            Write-LogMessage "Registering Chocolatey package source..." -Level Info -Tab "General"
            Register-PackageSource -Name chocolatey -Location "https://chocolatey.org/api/v2" -ProviderName Chocolatey -Trusted -Force | Out-Null
            Write-LogMessage "Chocolatey package source registered successfully" -Level Success -Tab "General"
        }

        # Check if NuGet provider is available (needed for some operations)
        $nugetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
        if (-not $nugetProvider) {
            Write-LogMessage "Installing NuGet PackageProvider..." -Level Info -Tab "General"
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
            Write-LogMessage "NuGet PackageProvider installed successfully" -Level Success -Tab "General"
        }

        # Check for Winget (App Installer)
        $wingetInstalled = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $wingetInstalled) {
            Write-LogMessage "Winget not found. Please install App Installer from Microsoft Store for Winget support." -Level Warning -Tab "General"
        } else {
            # Try to register Winget source (this may fail if provider is not available)
            try {
                $wingetSource = Get-PackageSource -Name winget -ErrorAction SilentlyContinue
                if (-not $wingetSource) {
                    Write-LogMessage "Attempting to register Winget package source..." -Level Info -Tab "General"
                    # Try different approaches for Winget
                    try {
                        Register-PackageSource -Name winget -Location "https://api.winget.microsoft.com/api/v1" -ProviderName Microsoft.Winget -Trusted -Force -ErrorAction Stop | Out-Null
                        Write-LogMessage "Winget package source registered successfully" -Level Success -Tab "General"
                    }
                    catch {
                        Write-LogMessage "Winget PackageManagement provider not available, but winget.exe is functional" -Level Info -Tab "General"
                    }
                }
            }
            catch {
                Write-LogMessage "Winget source registration failed: $($_.Exception.Message)" -Level Warning -Tab "General"
            }
        }

        return $true
    }
    catch {
        Write-LogMessage "Failed to initialize package sources: $($_.Exception.Message)" -Level Error -Tab "General"
        return $false
    }
}