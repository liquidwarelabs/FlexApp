# Functions/Intune/Start-IntuneUpload-Manifest.ps1
# Main function to start the Intune upload process using manifest-based approach

# Helper function for PowerShell 5.1 compatibility
function Invoke-Callback {
    param(
        [scriptblock]$Callback,
        [string]$Message
    )
    if ($Callback) {
        $null = $Callback.Invoke($Message)
    }
}

function Start-IntuneUpload {
    [CmdletBinding()]
    param(
        [string]$SourceFolder,
        [string]$OutputFolder,
        [string]$IntuneToolPath,
        [string]$ClientId,
        [string]$TenantId,
        [string]$ClientSecret,
        [string]$Publisher = "YourOrg",
        [string]$RunAsAccount = "user",
        [bool]$AllowAvailableUninstall = $false,
        [bool]$CleanupAfterWrap = $true,
        [string]$DependencyAppId = "",
        [bool]$UseCachedAuth = $false,
        [string]$ForegroundAccessToken,
        [string]$ForegroundAppId,
        [hashtable]$Templates,
        [string]$ForegroundPackageName,
        [scriptblock]$ProgressCallback,
        [scriptblock]$StatusCallback,
        [scriptblock]$LogCallback
    )

    try {
        Write-Host "=== START-INTUNEUPLOAD (MANIFEST-BASED) ===" -ForegroundColor Magenta
        Write-Host "Function called with parameters:" -ForegroundColor Yellow
        Write-Host "  SourceFolder: $SourceFolder" -ForegroundColor White
        Write-Host "  OutputFolder: $OutputFolder" -ForegroundColor White
        Write-Host "  ClientId: $ClientId" -ForegroundColor White
        Write-Host "  TenantId: $TenantId" -ForegroundColor White
        Write-Host "  Publisher: $Publisher" -ForegroundColor White
        Write-Host "  UseCachedAuth: $UseCachedAuth" -ForegroundColor White
        Write-Host "  ForegroundAccessToken: $($ForegroundAccessToken -ne $null) $(if($ForegroundAccessToken) {"(Length: $($ForegroundAccessToken.Length) chars)"})" -ForegroundColor White
        Write-Host "  ForegroundAppId: $($ForegroundAppId -ne $null) $(if($ForegroundAppId) {"(ID: $ForegroundAppId)"})" -ForegroundColor White
        Write-Host "  ForegroundPackageName: $(if($ForegroundPackageName) {$ForegroundPackageName} else {'Not provided'})" -ForegroundColor White
        Write-Host "  Templates: $($Templates -ne $null) $(if($Templates) {"(Count: $($Templates.Count))"})" -ForegroundColor White
        Write-Host "  CleanupAfterWrap: $CleanupAfterWrap" -ForegroundColor White
        Write-Host "  IntuneToolPath: $IntuneToolPath" -ForegroundColor White
        Write-Host "=== END PARAMETERS ===" -ForegroundColor Magenta

        # Validate required parameters
        if (-not $SourceFolder -or -not (Test-Path $SourceFolder)) {
            Write-Host "ERROR: Source folder is required and must exist: $SourceFolder" -ForegroundColor Red
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] ERROR: Source folder is required and must exist: $SourceFolder"
            return $false
        }

        if (-not $OutputFolder) {
            Write-Host "ERROR: Output folder is required" -ForegroundColor Red
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] ERROR: Output folder is required"
            return $false
        }

        # Ensure output folder exists
        if (-not (Test-Path $OutputFolder)) {
            New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
            Write-Host "Created output folder: $OutputFolder" -ForegroundColor Green
        }

        # Check authentication requirements
        $authResult = $false
        if ($ClientId -and $TenantId -and $ClientSecret) {
            Write-Host "STEP 1: Azure authentication parameters provided" -ForegroundColor Cyan
            Invoke-Callback -Callback $StatusCallback -Message "Azure authentication parameters provided"
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Azure authentication parameters provided"
            $authResult = $true
        } else {
            Write-Host "STEP 1: No Azure authentication - will only wrap packages" -ForegroundColor Yellow
            Invoke-Callback -Callback $StatusCallback -Message "No Azure authentication - will only wrap packages"
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] No Azure authentication - will only wrap packages"
        }

        # Organize FlexApp packages
        Write-Host "STEP 2: Organizing FlexApp packages..." -ForegroundColor Cyan
        Invoke-Callback -Callback $StatusCallback -Message "Organizing FlexApp packages..."
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Organizing FlexApp packages..."
        
        if ($ForegroundPackageName) {
            # Use the pre-scanned package from foreground
            Write-Host "Using pre-scanned package from foreground: $ForegroundPackageName" -ForegroundColor Green
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Using pre-scanned package: $ForegroundPackageName"
            
            $organizedPackages = @(@{
                Name = $ForegroundPackageName
                ExePath = Join-Path (Join-Path $SourceFolder $ForegroundPackageName) "$ForegroundPackageName.exe"
                ExeName = "$ForegroundPackageName.exe"
                FolderPath = Join-Path $SourceFolder $ForegroundPackageName
                Fa1Path = $null
                Size = 0
            })
        } else {
            # Scan packages normally
            Write-Host "Scanning packages in background job..." -ForegroundColor Yellow
            $organizedPackages = Organize-FlexAppPackages -SourceFolder $SourceFolder -LogCallback $LogCallback
                
            # Ensure we have a proper array
            if ($organizedPackages -isnot [array]) {
                $organizedPackages = @($organizedPackages)
            }
        }
                
        Write-Host "Found $($organizedPackages.Count) packages to process" -ForegroundColor Green
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Found $($organizedPackages.Count) packages to process"

        # Process each package
        $totalPackages = $organizedPackages.Count
        $processedPackages = 0
        $successfulWraps = 0
        $failedWraps = 0

        Write-Host "STEP 3: Wrapping packages and creating manifests..." -ForegroundColor Cyan
        foreach ($package in $organizedPackages) {
            $processedPackages++
            $progressPercent = [math]::Round(($processedPackages / $totalPackages) * 50)  # 50% for wrapping
            if ($ProgressCallback) { $ProgressCallback.Invoke($progressPercent) }
            
            Write-Host "Processing package $processedPackages of ${totalPackages}: $($package.Name)" -ForegroundColor Yellow
            Invoke-Callback -Callback $StatusCallback -Message "Processing package ${processedPackages} of ${totalPackages}: $($package.Name)"
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Processing package: $($package.Name)"

            try {
                # Wrap package for Intune
                Write-Host "Wrapping package: $($package.Name)" -ForegroundColor Cyan
                $wrappedPackage = New-IntunePackage -Package $package -OutputFolder $OutputFolder -IntuneToolPath $IntuneToolPath -LogCallback $LogCallback
                
                if ($wrappedPackage) {
                    Write-Host "Package wrapped successfully: $($package.Name)" -ForegroundColor Green
                    Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Package wrapped successfully: $($package.Name)"
                    
                    # Create upload manifest for this package
                    Write-Host "Creating upload manifest for: $($package.Name)" -ForegroundColor Yellow
                    Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Creating upload manifest for: $($package.Name)"
                    
                    $manifestResult = New-IntuneUploadManifest -Package $package -OutputFolder $OutputFolder -ClientId $ClientId -TenantId $TenantId -ClientSecret $ClientSecret -Publisher $Publisher -RunAsAccount $RunAsAccount -Templates $Templates -LogCallback $LogCallback
                    
                    if ($manifestResult) {
                        Write-Host "Upload manifest created successfully: $($manifestResult.ManifestFileName)" -ForegroundColor Green
                        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Upload manifest created: $($manifestResult.ManifestFileName)"
                        $successfulWraps++
                    } else {
                        Write-Host "Failed to create upload manifest for: $($package.Name)" -ForegroundColor Red
                        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Failed to create upload manifest for: $($package.Name)"
                        $failedWraps++
                    }
                } else {
                    $failedWraps++
                    Write-Host "Failed to wrap package: $($package.Name)" -ForegroundColor Red
                    Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Failed to wrap package: $($package.Name)"
                }
            }
            catch {
                $failedWraps++
                Write-Host "Error processing package $($package.Name): $($_.Exception.Message)" -ForegroundColor Red
                Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Error processing package $($package.Name): $($_.Exception.Message)"
            }
        }

        # Process all upload manifests if we have authentication
        $successfulUploads = 0
        $failedUploads = 0
        
        if ($authResult -and $successfulWraps -gt 0) {
            Write-Host ""
            Write-Host "STEP 4: Processing upload manifests..." -ForegroundColor Cyan
            Invoke-Callback -Callback $StatusCallback -Message "Processing upload manifests..."
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Processing upload manifests..."
            
            $manifestResult = Start-IntuneManifestUpload -OutputFolder $OutputFolder -MaxRetries 3 -LogCallback $LogCallback
            
            if ($manifestResult.Success) {
                Write-Host "All upload manifests processed successfully!" -ForegroundColor Green
                Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] All upload manifests processed successfully!"
                
                # Update counters based on manifest results
                $successfulUploads = $manifestResult.SuccessCount
                $failedUploads = $manifestResult.FailedCount
                
                # Cleanup if requested
                if ($CleanupAfterWrap) {
                    Write-Host "Cleaning up source packages..." -ForegroundColor Yellow
                    foreach ($package in $organizedPackages) {
                        try {
                            Remove-Item -Path $package.FolderPath -Recurse -Force -ErrorAction SilentlyContinue
                            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Cleaned up package: $($package.Name)"
                        } catch {
                            Write-Host "Warning: Could not clean up package: $($package.Name)" -ForegroundColor Yellow
                        }
                    }
                }
            } else {
                Write-Host "Some upload manifests failed to process" -ForegroundColor Red
                Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Some upload manifests failed to process"
                $failedUploads = $manifestResult.FailedCount
            }
        } elseif ($successfulWraps -gt 0) {
            Write-Host ""
            Write-Host "STEP 4: Upload manifests created but not processed (no authentication)" -ForegroundColor Yellow
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Upload manifests created but not processed (no authentication)"
            Write-Host "Manifests are ready for manual upload or when authentication is available" -ForegroundColor Cyan
        }

        # Final status
        Invoke-Callback -Callback $StatusCallback -Message "Upload process completed"
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Upload process completed"
        
        Write-Host ""
        Write-Host "=== FINAL RESULTS ===" -ForegroundColor Magenta
        Write-Host "Total packages processed: $totalPackages" -ForegroundColor Cyan
        Write-Host "Successful wraps: $successfulWraps" -ForegroundColor Green
        Write-Host "Failed wraps: $failedWraps" -ForegroundColor Red
        if ($authResult) {
            Write-Host "Successful uploads: $successfulUploads" -ForegroundColor Green
            Write-Host "Failed uploads: $failedUploads" -ForegroundColor Red
        } else {
            Write-Host "Uploads: Skipped (no authentication)" -ForegroundColor Yellow
        }
        Write-Host "=== END RESULTS ===" -ForegroundColor Magenta

        # Return success if all wraps were successful
        return ($failedWraps -eq 0)

    } catch {
        Write-Host "ERROR: Failed to start Intune upload: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] ERROR: Failed to start Intune upload: $($_.Exception.Message)"
        return $false
    }
}
