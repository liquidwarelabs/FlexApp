# Functions/WPF/Start-WPFIntuneUpload.ps1
# WPF function to start Intune upload process


function Start-WPFIntuneUpload {
    [CmdletBinding()]
    param()

    try {
        Write-LogMessage "Start-WPFIntuneUpload function called" -Level Info -Tab "Intune"
        
        # Get UI controls
        $startButton = Find-Control -ControlName "IntuneStartUploadButton"
        Write-LogMessage "Start button found: $($null -ne $startButton)" -Level Info -Tab "Intune"
        $stopButton = Find-Control -ControlName "IntuneStopUploadButton"

        # Get configuration values
        $clientId = (Find-Control -ControlName "IntuneClientIdTextBox").Text.Trim()
        $tenantId = (Find-Control -ControlName "IntuneTenantIdTextBox").Text.Trim()
        $clientSecret = (Find-Control -ControlName "IntuneClientSecretPasswordBox").Password
        $sourceFolder = (Find-Control -ControlName "IntuneSourceFolderTextBox").Text.Trim()
        $outputFolder = (Find-Control -ControlName "IntuneOutputFolderTextBox").Text.Trim()
        $intuneToolPath = (Find-Control -ControlName "IntuneToolPathTextBox").Text.Trim()
        $publisher = (Find-Control -ControlName "IntunePublisherTextBox").Text.Trim()
        $runAsAccount = (Find-Control -ControlName "IntuneRunAsAccountComboBox").SelectedItem.Content
        
        # Get app metadata template values
        $displayNameTemplate = (Find-Control -ControlName "IntuneDisplayNameTemplateTextBox").Text.Trim()
        $versionTemplate = (Find-Control -ControlName "IntuneVersionTemplateTextBox").Text.Trim()
        $installCommandTemplate = (Find-Control -ControlName "IntuneInstallCommandTemplateTextBox").Text.Trim()
        $uninstallCommandTemplate = (Find-Control -ControlName "IntuneUninstallCommandTemplateTextBox").Text.Trim()
        $descriptionTemplate = (Find-Control -ControlName "IntuneDescriptionTemplateTextBox").Text.Trim()
        $detectionPathTemplate = (Find-Control -ControlName "IntuneDetectionPathTemplateTextBox").Text.Trim()

        # Validate required fields
        if (-not $clientId) {
            Write-LogMessage "Client ID is required for Intune upload" -Level Warning -Tab "Intune"
            return
        }
        if (-not $tenantId) {
            Write-LogMessage "Tenant ID is required for Intune upload" -Level Warning -Tab "Intune"
            return
        }
        if (-not $clientSecret) {
            Write-LogMessage "Client Secret is required for Intune upload" -Level Warning -Tab "Intune"
            return
        }
        if (-not $sourceFolder -or -not (Test-Path $sourceFolder)) {
            Write-LogMessage "Source folder is required and must exist for Intune upload" -Level Warning -Tab "Intune"
            return
        }
        # IntuneToolPath validation removed - no longer needed since we use the module's built-in function

        # Set default values
        if (-not $publisher) { $publisher = "YourOrg" }
        if (-not $runAsAccount) { $runAsAccount = "user" }
        if (-not $outputFolder) { $outputFolder = Join-Path $sourceFolder "IntuneOutput" }
        
        # Check for cached authentication or perform automatic test
        $useCachedAuth = $false
        if ($global:IntuneAuthenticationValid -and 
            $global:IntuneAuthenticationTime -and 
            $global:IntuneClientId -eq $clientId -and 
            $global:IntuneTenantId -eq $tenantId -and
            ((Get-Date) - $global:IntuneAuthenticationTime).TotalMinutes -lt 30) {
            $useCachedAuth = $true
            Write-LogMessage "Using cached Azure authentication (valid for $([math]::Round(30 - ((Get-Date) - $global:IntuneAuthenticationTime).TotalMinutes, 1)) more minutes)" -Level Info -Tab "Intune"
        } else {
            # No valid cached authentication, perform automatic connection test
            Write-LogMessage "No cached authentication found, performing automatic connection test..." -Level Info -Tab "Intune"
            
            
            # Perform connection test
            $testJob = Start-Job -ScriptBlock {
                param($ClientId, $TenantId, $ClientSecret, $ModulePath)
                
                try {
                    Write-Host "=== Automatic Connection Test Started ===" -ForegroundColor Cyan
                    Import-Module $ModulePath -Force
                    $VerbosePreference = "SilentlyContinue"  # Reduce verbose output for automatic test
                    $result = Connect-IntuneGraph -ClientId $ClientId -TenantId $TenantId -ClientSecret $ClientSecret
                    Write-Host "Automatic connection test result: $result" -ForegroundColor $(if($result) {"Green"} else {"Red"})
                    return $result
                }
                catch {
                    Write-Host "Automatic connection test failed: $($_.Exception.Message)" -ForegroundColor Red
                    return $false
                }
            } -ArgumentList $clientId, $tenantId, $clientSecret, (Get-Module FlexAppUpdateManager).Path
            
            # Wait for automatic test with timeout
            $timeout = 45 # seconds - longer timeout for automatic test
            $elapsed = 0
            while ($testJob.State -eq "Running" -and $elapsed -lt $timeout) {
                Start-Sleep -Seconds 1
                $elapsed++
                
                # Update progress every 5 seconds
                if ($elapsed % 5 -eq 0) {
                    # Connection test in progress
                }
            }
            
            if ($testJob.State -eq "Completed") {
                $testResult = Receive-Job -Job $testJob
                Remove-Job -Job $testJob
                
                if ($testResult) {
                    # Cache successful authentication
                    $global:IntuneAuthenticationValid = $true
                    $global:IntuneAuthenticationTime = Get-Date
                    $global:IntuneClientId = $clientId
                    $global:IntuneTenantId = $tenantId
                    $global:IntuneClientSecret = $clientSecret
                    $useCachedAuth = $true
                    
                    Write-LogMessage "Automatic connection test successful - proceeding with upload" -Level Success -Tab "Intune"
                } else {
                    Write-LogMessage "Automatic connection test failed - continuing with package wrapping only" -Level Warning -Tab "Intune"
                }
            } else {
                # Test timed out or failed
                Stop-Job -Job $testJob -ErrorAction SilentlyContinue
                Remove-Job -Job $testJob -Force -ErrorAction SilentlyContinue
                
                Write-LogMessage "Automatic connection test timed out - continuing with package wrapping only" -Level Warning -Tab "Intune"
            }
        }

        Write-LogMessage "Starting Intune upload process" -Level Info -Tab "Intune"
        Write-LogMessage "Source folder: $sourceFolder" -Level Info -Tab "Intune"
        Write-LogMessage "Output folder: $outputFolder" -Level Info -Tab "Intune"
        Write-LogMessage "Publisher: $publisher" -Level Info -Tab "Intune"

        # Update UI state
        $startButton.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Normal, [System.Action]{
            $startButton.IsEnabled = $false
            $stopButton.IsEnabled = $true
        })
        

        # Track start time for progress display
        $script:IntuneUploadStartTime = Get-Date

        # Pre-check and install MSEndpointMgr module in foreground
        Write-Host "Pre-checking MSEndpointMgr IntuneWin32App module in foreground..." -ForegroundColor Cyan
        Write-LogMessage "Pre-checking MSEndpointMgr IntuneWin32App module in foreground..." -Level Info -Tab "Intune"
        
        try {
            # Check if module is already installed
            $module = Get-Module -Name IntuneWin32App -ListAvailable
            if (-not $module) {
                Write-Host "Installing IntuneWin32App module from PowerShell Gallery..." -ForegroundColor Yellow
                Write-LogMessage "Installing IntuneWin32App module from PowerShell Gallery..." -Level Info -Tab "Intune"
                Install-Module -Name IntuneWin32App -Force -AllowClobber
            } else {
                Write-Host "IntuneWin32App module already installed (Version: $($module.Version))" -ForegroundColor Green
                Write-LogMessage "IntuneWin32App module already installed (Version: $($module.Version))" -Level Info -Tab "Intune"
            }
            
            # Test import in foreground
            Import-Module IntuneWin32App -Force
            Write-Host "SUCCESS: IntuneWin32App module pre-checked successfully in foreground" -ForegroundColor Green
            Write-LogMessage "IntuneWin32App module pre-checked successfully in foreground" -Level Success -Tab "Intune"
        } catch {
            Write-Host "ERROR: Failed to pre-check IntuneWin32App module: $($_.Exception.Message)" -ForegroundColor Red
            Write-LogMessage "Failed to pre-check IntuneWin32App module: $($_.Exception.Message)" -Level Error -Tab "Intune"
            return
        }

        # Get OAuth token in foreground first (more reliable than background job HTTP requests)
        $accessToken = $null
        if ($useCachedAuth -and $global:IntuneClientSecret) {
            Write-LogMessage "Getting OAuth token in foreground for reliable HTTP connection..." -Level Info -Tab "Intune"
            
            try {
                # Use the same direct approach but in foreground
                $tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
                $body = @{
                    client_id = $clientId
                    client_secret = $global:IntuneClientSecret
                    scope = 'https://graph.microsoft.com/.default'
                    grant_type = 'client_credentials'
                }
                
                Write-LogMessage "Making OAuth token request in foreground..." -Level Info -Tab "Intune"
                $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded" -TimeoutSec 30
                
                if ($tokenResponse -and $tokenResponse.access_token) {
                    $accessToken = $tokenResponse.access_token
                    Write-LogMessage "OAuth token obtained successfully in foreground (Length: $($accessToken.Length) chars)" -Level Success -Tab "Intune"
                } else {
                    Write-LogMessage "Failed to get OAuth token in foreground" -Level Warning -Tab "Intune"
                }
            } catch {
                Write-LogMessage "Error getting OAuth token in foreground: $($_.Exception.Message)" -Level Error -Tab "Intune"
                $accessToken = $null
            }
        }

        # Scan packages in foreground to get real package names
        Write-Host "DEBUG: Scanning packages in foreground to get real names..." -ForegroundColor Cyan
        
        try {
            # Load the required functions using the correct module path
            $moduleDir = (Split-Path (Get-Module FlexAppUpdateManager).Path -Parent)
            . "$moduleDir\Functions\Intune\Organize-FlexAppPackages.ps1"
            
            Write-Host "DEBUG: Module path resolved to: $moduleDir" -ForegroundColor Yellow
            
            # Verify the function was loaded
            if (-not (Get-Command Organize-FlexAppPackages -ErrorAction SilentlyContinue)) {
                throw "Failed to load Organize-FlexAppPackages function"
            }
            
            Write-Host "DEBUG: Organize-FlexAppPackages function loaded successfully" -ForegroundColor Green
            
            # Get real package list
            Write-Host "DEBUG: Calling Organize-FlexAppPackages with SourceFolder: $sourceFolder" -ForegroundColor Yellow
            $packages = Organize-FlexAppPackages -SourceFolder $sourceFolder
            
            if (-not $packages -or $packages.Count -eq 0) {
                throw "No packages found in source folder: $sourceFolder"
            }
            
            Write-Host "DEBUG: Found $($packages.Count) packages: $($packages.Name -join ', ')" -ForegroundColor Green
            
            # Use the first package for Win32 app creation (assuming single package for now)
            $firstPackage = $packages[0]
            $realPackageName = $firstPackage.Name
            
            Write-Host "DEBUG: Using real package name: $realPackageName" -ForegroundColor Yellow
            
        } catch {
            Write-Host "ERROR: Failed to scan packages: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "DEBUG: Full error details: $($_.Exception | Format-List * | Out-String)" -ForegroundColor Red
            Write-Host "DEBUG: Falling back to scanning packages in background job instead" -ForegroundColor Yellow
            $realPackageName = $null  # This will trigger normal background scanning
        }

        # Prepare template values for upload
        $templates = @{
            DisplayName = $displayNameTemplate
            Version = $versionTemplate
            InstallCommand = $installCommandTemplate
            UninstallCommand = $uninstallCommandTemplate
            Description = $descriptionTemplate
            DetectionPath = $detectionPathTemplate
        }

        # Upload starting - no dialog needed, progress shown in console
        
        # Run Intune upload in FOREGROUND for visible status
        Write-Host "=== RUNNING INTUNE UPLOAD IN FOREGROUND ===" -ForegroundColor Green
        Write-Host "This will show real-time status in the console..." -ForegroundColor Cyan
        
        try {
            # Import the IntuneWin32App module in foreground
            Write-Host "Loading IntuneWin32App module in foreground..." -ForegroundColor Cyan
            Import-Module IntuneWin32App -Force
            Write-Host "SUCCESS: IntuneWin32App module loaded successfully" -ForegroundColor Green
            
            # Create LogCallback function for console updates
            function Invoke-Callback {
                param($Callback, $Message)
                if ($Callback) {
                    try {
                        & $Callback $Message
                    } catch {
                        Write-Host "Callback error: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
            
            # Create LogCallback for console output
            $LogCallback = {
                param($Message)
                # Console output removed - status shown in main console
            }
            
            Write-Host "DEBUG: LogCallback function created for console updates" -ForegroundColor Cyan
            
            Write-Host "=== STARTING FOREGROUND UPLOAD ===" -ForegroundColor Magenta
            Write-Host "Current time: $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')" -ForegroundColor Cyan
            Write-Host "Source Folder: $sourceFolder" -ForegroundColor Gray
            Write-Host "Output Folder: $outputFolder" -ForegroundColor Gray
            Write-Host "Package Name: $realPackageName" -ForegroundColor Gray
            Write-Host "OAuth Token: $(if ($accessToken) { 'Available (Length: ' + $accessToken.Length + ' chars)' } else { 'Not available' })" -ForegroundColor Gray
            
            # Call Start-IntuneUpload directly in foreground
            Write-Host "STARTING: Calling Start-IntuneUpload in foreground..." -ForegroundColor Yellow
            $result = Start-IntuneUpload -SourceFolder $sourceFolder -OutputFolder $outputFolder -IntuneToolPath $intuneToolPath -ClientId $clientId -TenantId $tenantId -ClientSecret $clientSecret -Publisher $publisher -RunAsAccount $runAsAccount -AllowAvailableUninstall $false -CleanupAfterWrap $true -DependencyAppId "" -UseCachedAuth $useCachedAuth -ForegroundAccessToken $accessToken -ForegroundAppId $null -Templates $templates -ForegroundPackageName $realPackageName -LogCallback $LogCallback
            
            Write-Host "=== UPLOAD RESULT ===" -ForegroundColor Magenta
            Write-Host "Upload completed with result: $result" -ForegroundColor Cyan
            
            # Update UI with result
            if ($result) {
                Write-Host "SUCCESS: Intune upload completed successfully!" -ForegroundColor Green
                Write-LogMessage "Intune upload completed successfully!" -Level Success -Tab "Intune"
                
                # Upload completed successfully - status shown in console
                
                } else {
                Write-Host "ERROR: Intune upload failed!" -ForegroundColor Red
                Write-LogMessage "Intune upload failed!" -Level Error -Tab "Intune"
                
                # Upload failed - error details shown in console
            }
            
        } catch {
            Write-Host "ERROR: Error in foreground upload: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
            Write-LogMessage "Error in foreground upload: $($_.Exception.Message)" -Level Error -Tab "Intune"
            
            # Error occurred - details shown in console
            
            throw $_
        }
        
        Write-Host "=== FOREGROUND UPLOAD COMPLETED ===" -ForegroundColor Green
        Write-Host "All upload processing completed in foreground with visible status!" -ForegroundColor Cyan

        Write-LogMessage "Started Intune upload process" -Level Info -Tab "Intune"
    }
    catch {
        Write-LogMessage "Error starting Intune upload: $($_.Exception.Message)" -Level Error -Tab "Intune"
        
        # Reset UI state
        $startButton.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Normal, [System.Action]{
            $startButton.IsEnabled = $true
            $stopButton.IsEnabled = $false
        })
    }
}