# Functions/Intune/Add-IntuneApplicationMSEndpointMgr.ps1
# Official MSEndpointMgr IntuneWin32App module implementation for uploading Win32 applications to Intune
# This uses the mature, tested MSEndpointMgr module instead of custom Graph API calls

# Helper function for PowerShell 5.1 compatibility
function Invoke-Callback {
    param(
        [scriptblock]$Callback,
        [string]$Message
    )
    if ($Callback) {
        try {
            $Callback.Invoke($Message)
        } catch {
            # Silently ignore callback errors
        }
    }
}

function Add-IntuneApplicationMSEndpointMgr {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Package,
        
        [Parameter(Mandatory = $true)]
        [string]$ClientId,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $true)]
        [string]$ClientSecret,
        
        [string]$Publisher = "YourOrg",
        [string]$RunAsAccount = "user",
        [bool]$AllowAvailableUninstall = $false,
        [string]$DependencyAppId = "",
        [string]$AppVersion = "",
        [string]$ForegroundAccessToken,
        [string]$ForegroundAppId,
        [hashtable]$Templates,
        [scriptblock]$LogCallback
    )

    try {
        # Track upload start time for performance monitoring
        $script:uploadStartTime = Get-Date
        
        Write-Host "=== ADD-INTUNEAPPLICATIONMSEndpointMgr FUNCTION STARTED ===" -ForegroundColor Magenta
        Write-Host "DEBUG: Using official MSEndpointMgr IntuneWin32App module implementation" -ForegroundColor Green
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] INFO: Using official MSEndpointMgr IntuneWin32App module implementation"
        
        # Step 1: Import the Official MSEndpointMgr IntuneWin32App Module (already installed in foreground)
        Write-Host "`nStep 1: Importing MSEndpointMgr IntuneWin32App module..." -ForegroundColor Green
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] INFO: Importing MSEndpointMgr IntuneWin32App module"
        
        try {
            # Import the module (already installed in foreground)
            Import-Module IntuneWin32App -Force
            Write-Host "SUCCESS: IntuneWin32App module imported successfully" -ForegroundColor Green
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SUCCESS: IntuneWin32App module imported successfully"
        } catch {
            Write-Host "ERROR: Failed to import IntuneWin32App module: $($_.Exception.Message)" -ForegroundColor Red
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: Failed to import IntuneWin32App module: $($_.Exception.Message)"
            throw "Failed to import IntuneWin32App module: $($_.Exception.Message)"
        }

        # Step 2: Connect to Microsoft Graph using the official MSEndpointMgr method
        Write-Host "`nStep 2: Connecting to Microsoft Graph..." -ForegroundColor Green
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] INFO: Connecting to Microsoft Graph using MSEndpointMgr method"
        
        try {
            # Use the official Connect-MSIntuneGraph cmdlet with client credentials
            Connect-MSIntuneGraph -ClientId $ClientId -ClientSecret $ClientSecret -TenantId $TenantId
            Write-Host "SUCCESS: Connected to Microsoft Graph successfully using MSEndpointMgr method" -ForegroundColor Green
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SUCCESS: Connected to Microsoft Graph successfully using MSEndpointMgr method"
        } catch {
            Write-Host "ERROR: Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: Failed to connect to Microsoft Graph: $($_.Exception.Message)"
            throw "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
        }

        # Step 3: Get metadata from the .intunewin file and ensure correct filename
        Write-Host "`nStep 3: Getting metadata from .intunewin file and ensuring correct filename..." -ForegroundColor Green
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] INFO: Getting metadata from .intunewin file and ensuring correct filename"
        
        # Debug: Show what we received
        Write-Host "DEBUG: Package object details:" -ForegroundColor Cyan
        Write-Host "  Package.Name: $($Package.Name)" -ForegroundColor Gray
        Write-Host "  Package.IntuneWinPath: $($Package.IntuneWinPath)" -ForegroundColor Gray
        Write-Host "  Package.ExeName: $($Package.ExeName)" -ForegroundColor Gray
        Write-Host "  Package.Size: $($Package.Size)" -ForegroundColor Gray
        
        $intuneWinPath = $Package.IntuneWinPath
        $packageName = $Package.Name
        
        if (-not $intuneWinPath -or -not (Test-Path $intuneWinPath)) {
            throw "IntuneWin file not found: $intuneWinPath"
        }
        
        Write-Host "DEBUG: IntuneWin file verified: $intuneWinPath" -ForegroundColor Green
        
        # Verify the file exists and show its actual name
        if (Test-Path $intuneWinPath) {
            $actualFile = Get-Item $intuneWinPath
            Write-Host "DEBUG: Actual file details:" -ForegroundColor Cyan
            Write-Host "  File Name: $($actualFile.Name)" -ForegroundColor Gray
            Write-Host "  File Size: $($actualFile.Length) bytes" -ForegroundColor Gray
            Write-Host "  File Path: $($actualFile.FullName)" -ForegroundColor Gray
            
            # Use the original filename to preserve specific package names (e.g., Notepadplusplus.intunewin)
            Write-Host "Using original filename: $($actualFile.Name)" -ForegroundColor Green
            Write-Host "This will preserve the specific package name in Intune" -ForegroundColor Cyan
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Using original filename: $($actualFile.Name)"
        } else {
            Write-Host "ERROR: IntuneWin file not found at expected path: $intuneWinPath" -ForegroundColor Red
            throw "IntuneWin file not found: $intuneWinPath"
        }
        
        try {
            # Use the official Get-IntuneWin32AppMetaData function
            $IntuneWinMetaData = Get-IntuneWin32AppMetaData -FilePath $intuneWinPath
            Write-Host "SUCCESS: Metadata extracted successfully" -ForegroundColor Green
            Write-Host "App Name: $($IntuneWinMetaData.ApplicationInfo.Name)" -ForegroundColor Cyan
            Write-Host "App Version: $($IntuneWinMetaData.ApplicationInfo.MsiInfo.MsiProductVersion)" -ForegroundColor Cyan
            Write-Host "Publisher: $($IntuneWinMetaData.ApplicationInfo.MsiInfo.MsiPublisher)" -ForegroundColor Cyan
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SUCCESS: Metadata extracted successfully"
        } catch {
            Write-Host "ERROR: Failed to get metadata: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "This might be expected if the .intunewin file doesn't contain MSI metadata" -ForegroundColor Yellow
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] WARNING: Failed to get metadata: $($_.Exception.Message)"
            # Continue with manual metadata
            $IntuneWinMetaData = $null
        }

        # Step 4: Create detection rule
        Write-Host "`nStep 4: Creating detection rule..." -ForegroundColor Green
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] INFO: Creating detection rule"
        
        try {
            # Create a file system detection rule using the official New-IntuneWin32AppDetectionRuleFile function
            # Use template values if available, otherwise use package name
            $detectionPath = "C:\ProgramData\FlexApp\Cache"
            $detectionFile = "$packageName.exe"
            
            # Check if templates are available for detection path
            if ($Templates -and $Templates.ContainsKey("DetectionPath")) {
                $detectionPath = $Templates.DetectionPath -replace '\{PackageName\}', $packageName
                Write-Host "Using template detection path: $detectionPath" -ForegroundColor Cyan
            }
            
            $DetectionRule = New-IntuneWin32AppDetectionRuleFile -Existence -Path $detectionPath -FileOrFolder $detectionFile -DetectionType "exists" -Check32BitOn64System $false
            Write-Host "SUCCESS: Detection rule created successfully" -ForegroundColor Green
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SUCCESS: Detection rule created successfully"
        } catch {
            Write-Host "ERROR: Failed to create detection rule: $($_.Exception.Message)" -ForegroundColor Red
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: Failed to create detection rule: $($_.Exception.Message)"
            throw "Failed to create detection rule: $($_.Exception.Message)"
        }

        # Step 5: Create requirement rule
        Write-Host "`nStep 5: Creating requirement rule..." -ForegroundColor Green
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] INFO: Creating requirement rule"
        
        try {
            # Create a requirement rule using the official New-IntuneWin32AppRequirementRule function
            # Use the correct enum value from the error message
            $RequirementRule = New-IntuneWin32AppRequirementRule -Architecture "All" -MinimumSupportedWindowsRelease "W10_20H2"
            Write-Host "SUCCESS: Requirement rule created successfully" -ForegroundColor Green
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SUCCESS: Requirement rule created successfully"
        } catch {
            Write-Host "ERROR: Failed to create requirement rule: $($_.Exception.Message)" -ForegroundColor Red
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: Failed to create requirement rule: $($_.Exception.Message)"
            throw "Failed to create requirement rule: $($_.Exception.Message)"
        }

        # Step 6: Create return codes
        Write-Host "`nStep 6: Creating return codes..." -ForegroundColor Green
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] INFO: Creating return codes"
        
        try {
            # Create return codes using the official New-IntuneWin32AppReturnCode function
            $ReturnCode = @(
                New-IntuneWin32AppReturnCode -ReturnCode 0 -Type "success"
                New-IntuneWin32AppReturnCode -ReturnCode 1 -Type "failed"
                New-IntuneWin32AppReturnCode -ReturnCode 3010 -Type "softReboot"
            )
            Write-Host "SUCCESS: Return codes created successfully" -ForegroundColor Green
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SUCCESS: Return codes created successfully"
        } catch {
            Write-Host "ERROR: Failed to create return codes: $($_.Exception.Message)" -ForegroundColor Red
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: Failed to create return codes: $($_.Exception.Message)"
            throw "Failed to create return codes: $($_.Exception.Message)"
        }

        # Step 7: Create the Win32 app using the official Add-IntuneWin32App function
        Write-Host "`nStep 7: Creating Win32 app using official MSEndpointMgr method..." -ForegroundColor Green
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] INFO: Creating Win32 app using official MSEndpointMgr method"
        
        try {
            # Use template values if available, otherwise use package data
            $displayName = "FlexApp - $packageName"
            $description = "FlexApp package for $packageName"
            $installCommand = "$packageName.exe --install"
            $uninstallCommand = "$packageName.exe --uninstall"
            
            # Check if templates are available
            if ($Templates) {
                if ($Templates.ContainsKey("DisplayName")) {
                    $displayName = $Templates.DisplayName -replace '\{PackageName\}', $packageName
                }
                if ($Templates.ContainsKey("Version")) {
                    $version = $Templates.Version -replace '\{PackageName\}', $packageName
                }
                if ($Templates.ContainsKey("Description")) {
                    $description = $Templates.Description -replace '\{PackageName\}', $packageName
                }
                if ($Templates.ContainsKey("InstallCommand")) {
                    $installCommand = $Templates.InstallCommand -replace '\{PackageName\}', $packageName
                }
                if ($Templates.ContainsKey("UninstallCommand")) {
                    $uninstallCommand = $Templates.UninstallCommand -replace '\{PackageName\}', $packageName
                }
            }
            
            # Use AppVersion parameter if provided, otherwise use template version
            if ($AppVersion) {
                $version = $AppVersion
            }
            
            Write-Host "App Details:" -ForegroundColor Cyan
            Write-Host "  Display Name: $displayName" -ForegroundColor Gray
            Write-Host "  Version: $version" -ForegroundColor Gray
            Write-Host "  Description: $description" -ForegroundColor Gray
            Write-Host "  Publisher: $Publisher" -ForegroundColor Gray
            Write-Host "  Install Command: $installCommand" -ForegroundColor Gray
            Write-Host "  Uninstall Command: $uninstallCommand" -ForegroundColor Gray
            Write-Host "  IntuneWin File: $intuneWinPath" -ForegroundColor Gray
            Write-Host "  Package Name: $packageName" -ForegroundColor Gray
            
            # Use the official Add-IntuneWin32App function with all the parameters
            Write-Host "DEBUG: About to call Add-IntuneWin32App with:" -ForegroundColor Yellow
            Write-Host "  FilePath: $intuneWinPath" -ForegroundColor Gray
            Write-Host "  DisplayName: $displayName" -ForegroundColor Gray
            Write-Host "  Publisher: $Publisher" -ForegroundColor Gray
            Write-Host "  InstallCommandLine: $installCommand" -ForegroundColor Gray
            Write-Host "  UninstallCommandLine: $uninstallCommand" -ForegroundColor Gray
            
        Write-Host "STARTING UPLOAD TO INTUNE..." -ForegroundColor Magenta
        Write-Host "This may take several minutes for large files..." -ForegroundColor Yellow
        Write-Host "Uploading file: $([System.IO.Path]::GetFileName($intuneWinPath)) ($((Get-Item $intuneWinPath).Length) bytes)" -ForegroundColor Cyan
        Invoke-Callback -Callback $LogCallback -Message "STARTING UPLOAD TO INTUNE..."
        Invoke-Callback -Callback $LogCallback -Message "This may take several minutes for large files..."
        Invoke-Callback -Callback $LogCallback -Message "Uploading file: $([System.IO.Path]::GetFileName($intuneWinPath)) ($((Get-Item $intuneWinPath).Length) bytes)"
            
            # Start a background job to show progress dots
            $progressJob = Start-Job -ScriptBlock {
                param($LogCallback)
                for ($i = 1; $i -le 60; $i++) {
                    Start-Sleep -Seconds 5
                    Write-Host "PROGRESS: Upload in progress... ($i/60) - Please wait..." -ForegroundColor Yellow
                    if ($LogCallback) {
                        & $LogCallback "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] INFO: Upload in progress... ($i/60)"
                    }
                }
            } -ArgumentList $LogCallback
            
            # Only pass AppVersion if it's not empty
            $addIntuneParams = @{
                FilePath = $intuneWinPath
                DisplayName = $displayName
                Description = $description
                Publisher = $Publisher
                InstallExperience = $RunAsAccount
                RestartBehavior = "suppress"
                DetectionRule = $DetectionRule
                RequirementRule = $RequirementRule
                ReturnCode = $ReturnCode
                InstallCommandLine = $installCommand
                UninstallCommandLine = $uninstallCommand
                Verbose = $true
            }
            
            # Add AppVersion only if it's not empty
            if ($version -and $version.Trim() -ne "") {
                $addIntuneParams.AppVersion = $version
                Write-Host "DEBUG: Adding AppVersion parameter: $version" -ForegroundColor Cyan
            } else {
                Write-Host "DEBUG: Skipping AppVersion parameter (empty or null)" -ForegroundColor Yellow
            }
            
            $Win32App = Add-IntuneWin32App @addIntuneParams
            
            # Stop the progress job
            Stop-Job $progressJob -ErrorAction SilentlyContinue
            Remove-Job $progressJob -ErrorAction SilentlyContinue
            
            Write-Host "COMPLETED: UPLOAD COMPLETED SUCCESSFULLY!" -ForegroundColor Green
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SUCCESS: Upload to Intune completed successfully"
            
            Write-Host "SUCCESS: Win32 app created successfully using official MSEndpointMgr method!" -ForegroundColor Green
            Write-Host "App ID: $($Win32App.id)" -ForegroundColor Cyan
            Write-Host "Display Name: $($Win32App.displayName)" -ForegroundColor Cyan
            Write-Host "Publisher: $($Win32App.publisher)" -ForegroundColor Cyan
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SUCCESS: Win32 app created successfully! App ID: $($Win32App.id)"
            
            # Note: The filename preservation is handled by the IntuneWin32App module itself
            # The original filename (Notepadplusplus.intunewin) should be preserved automatically
            
        } catch {
            Write-Host "ERROR: Failed to create Win32 app: $($_.Exception.Message)" -ForegroundColor Red
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: Failed to create Win32 app: $($_.Exception.Message)"
            throw "Failed to create Win32 app: $($_.Exception.Message)"
        }

        # Step 8: Verify the app was created successfully
        Write-Host "`nStep 8: Verifying app creation..." -ForegroundColor Green
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] INFO: Verifying app creation"
        
        try {
            # Use the official Get-IntuneWin32App function to verify
            $createdApp = Get-IntuneWin32App -DisplayName $displayName
            Write-Host "SUCCESS: App verification successful!" -ForegroundColor Green
            Write-Host "App Status: $($createdApp.uploadState)" -ForegroundColor Cyan
            Write-Host "App Type: $($createdApp.'@odata.type')" -ForegroundColor Cyan
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SUCCESS: App verification successful! Status: $($createdApp.uploadState)"
            
        } catch {
            Write-Host "ERROR: Failed to verify app: $($_.Exception.Message)" -ForegroundColor Red
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] WARNING: Failed to verify app: $($_.Exception.Message)"
            # Don't throw here, as the app might still be created successfully
        }

        # Calculate total upload time
        $totalTime = (Get-Date) - $script:uploadStartTime
        Write-Host "`nCOMPLETED: UPLOAD COMPLETED USING OFFICIAL MSEndpointMgr MODULE!" -ForegroundColor Green
        Write-Host "Total upload time: $($totalTime.TotalSeconds.ToString('F1')) seconds" -ForegroundColor Cyan
        Write-Host "App ID: $($Win32App.id)" -ForegroundColor Cyan
        Write-Host "You can now find your app in the Microsoft Intune admin center." -ForegroundColor Yellow
        Write-Host "`nNote: The MSEndpointMgr module handles all file uploads automatically - no manual Graph API calls needed!" -ForegroundColor Green
        Write-Host "This is the recommended approach for Intune Win32 app management." -ForegroundColor Green
        
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SUCCESS: Upload completed using official MSEndpointMgr module! App ID: $($Win32App.id), Total time: $($totalTime.TotalSeconds.ToString('F1')) seconds"
        
        return $Win32App
        
    } catch {
        Write-Host "ERROR: CRITICAL ERROR in Add-IntuneApplicationMSEndpointMgr: $($_.Exception.Message)" -ForegroundColor Red
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: CRITICAL ERROR in Add-IntuneApplicationMSEndpointMgr: $($_.Exception.Message)"
        throw $_.Exception
    }
}

# Function is available for dot-sourcing (no Export-ModuleMember needed)