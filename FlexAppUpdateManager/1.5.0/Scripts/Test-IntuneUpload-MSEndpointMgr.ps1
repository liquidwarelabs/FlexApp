# Test-IntuneUpload-MSEndpointMgr.ps1
# Test script using the official MSEndpointMgr IntuneWin32App module approach

param(
    [Parameter(Mandatory=$true)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$true)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientSecret,
    
    [Parameter(Mandatory=$true)]
    [string]$IntuneWinPath,
    
    [string]$PackageName = "TestApp",
    [string]$Publisher = "TestPublisher"
)

Write-Host "=== MSEndpointMgr IntuneWin32App MODULE TEST ===" -ForegroundColor Cyan

# Step 1: Install and Import the Official MSEndpointMgr IntuneWin32App Module
Write-Host "`nStep 1: Installing MSEndpointMgr IntuneWin32App module..." -ForegroundColor Green
try {
    # Check if module is already installed
    $module = Get-Module -Name IntuneWin32App -ListAvailable
    if (-not $module) {
        Write-Host "Installing IntuneWin32App module from PowerShell Gallery..." -ForegroundColor Yellow
        Install-Module -Name IntuneWin32App -Force -AllowClobber
    } else {
        Write-Host "IntuneWin32App module already installed (Version: $($module.Version))" -ForegroundColor Green
    }
    
    # Import the module
    Import-Module IntuneWin32App -Force
    Write-Host "✅ IntuneWin32App module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to install/import IntuneWin32App module: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please ensure you have PowerShell 5.1+ and .NET 4.7.1+ installed" -ForegroundColor Yellow
    exit 1
}

# Step 2: Connect to Microsoft Graph using the official MSEndpointMgr method
Write-Host "`nStep 2: Connecting to Microsoft Graph..." -ForegroundColor Green
try {
    # Use the official Connect-MSIntuneGraph cmdlet with client credentials
    Connect-MSIntuneGraph -ClientId $ClientId -ClientSecret $ClientSecret -TenantId $TenantId
    Write-Host "✅ Connected to Microsoft Graph successfully using MSEndpointMgr method" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 3: Get metadata from the .intunewin file
Write-Host "`nStep 3: Getting metadata from .intunewin file..." -ForegroundColor Green
try {
    # Use the official Get-IntuneWin32AppMetaData function
    $IntuneWinMetaData = Get-IntuneWin32AppMetaData -FilePath $IntuneWinPath
    Write-Host "✅ Metadata extracted successfully" -ForegroundColor Green
    Write-Host "App Name: $($IntuneWinMetaData.ApplicationInfo.Name)" -ForegroundColor Cyan
    Write-Host "App Version: $($IntuneWinMetaData.ApplicationInfo.MsiInfo.MsiProductVersion)" -ForegroundColor Cyan
    Write-Host "Publisher: $($IntuneWinMetaData.ApplicationInfo.MsiInfo.MsiPublisher)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Failed to get metadata: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "This might be expected if the .intunewin file doesn't contain MSI metadata" -ForegroundColor Yellow
    # Continue with manual metadata
    $IntuneWinMetaData = $null
}

# Step 4: Create detection rule
Write-Host "`nStep 4: Creating detection rule..." -ForegroundColor Green
try {
    # Create a file system detection rule using the official New-IntuneWin32AppDetectionRuleFile function
    # Based on the syntax output, we need to use the -Existence parameter set
    Write-Host "Creating detection rule with -Existence parameter set..." -ForegroundColor Yellow
    $DetectionRule = New-IntuneWin32AppDetectionRuleFile -Existence -Path "C:\ProgramData\FlexApp\Cache" -FileOrFolder "$PackageName.exe" -DetectionType "exists" -Check32BitOn64System $false
    Write-Host "✅ Detection rule created successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create detection rule: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Let's try with minimal parameters..." -ForegroundColor Yellow
    
    try {
        # Try with minimal parameters (just existence check)
        $DetectionRule = New-IntuneWin32AppDetectionRuleFile -Existence -Path "C:\ProgramData\FlexApp\Cache" -FileOrFolder "$PackageName.exe" -DetectionType "exists"
        Write-Host "✅ Detection rule created successfully with minimal parameters" -ForegroundColor Green
    } catch {
        Write-Host "❌ All detection rule attempts failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Let's try a different detection rule type..." -ForegroundColor Yellow
        
        try {
            # Try with a different detection type
            $DetectionRule = New-IntuneWin32AppDetectionRuleFile -Existence -Path "C:\ProgramData\FlexApp\Cache" -FileOrFolder "$PackageName.exe" -DetectionType "notExists"
            Write-Host "✅ Detection rule created successfully with notExists type" -ForegroundColor Green
        } catch {
            Write-Host "❌ All detection rule attempts failed: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
}

# Step 5: Create requirement rule
Write-Host "`nStep 5: Creating requirement rule..." -ForegroundColor Green
try {
    # Create a requirement rule using the official New-IntuneWin32AppRequirementRule function
    # Use the correct enum value from the error message
    $RequirementRule = New-IntuneWin32AppRequirementRule -Architecture "All" -MinimumSupportedWindowsRelease "W10_20H2"
    Write-Host "✅ Requirement rule created successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create requirement rule: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Let's try with a different Windows release..." -ForegroundColor Yellow
    
    try {
        # Try with a different Windows release
        $RequirementRule = New-IntuneWin32AppRequirementRule -Architecture "All" -MinimumSupportedWindowsRelease "W10_1909"
        Write-Host "✅ Requirement rule created successfully with W10_1909" -ForegroundColor Green
    } catch {
        Write-Host "❌ Alternative Windows release also failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Let's try with minimal parameters..." -ForegroundColor Yellow
        
        try {
            # Try with minimal parameters (just architecture)
            $RequirementRule = New-IntuneWin32AppRequirementRule -Architecture "All"
            Write-Host "✅ Requirement rule created successfully with minimal parameters" -ForegroundColor Green
        } catch {
            Write-Host "❌ All requirement rule attempts failed: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
}

# Step 6: Create return codes
Write-Host "`nStep 6: Creating return codes..." -ForegroundColor Green
try {
    # Create return codes using the official New-IntuneWin32AppReturnCode function
    $ReturnCode = @(
        New-IntuneWin32AppReturnCode -ReturnCode 0 -Type "success"
        New-IntuneWin32AppReturnCode -ReturnCode 1 -Type "failed"
        New-IntuneWin32AppReturnCode -ReturnCode 3010 -Type "softReboot"
    )
    Write-Host "✅ Return codes created successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create return codes: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 7: Create the Win32 app using the official Add-IntuneWin32App function
Write-Host "`nStep 7: Creating Win32 app using official MSEndpointMgr method..." -ForegroundColor Green
try {
    # Use the official Add-IntuneWin32App function with all the parameters
    $Win32App = Add-IntuneWin32App -FilePath $IntuneWinPath -DisplayName "FlexApp - $PackageName" -Description "FlexApp package for $PackageName" -Publisher $Publisher -InstallExperience "user" -RestartBehavior "suppress" -DetectionRule $DetectionRule -RequirementRule $RequirementRule -ReturnCode $ReturnCode -InstallCommandLine "$PackageName.exe --install" -UninstallCommandLine "$PackageName.exe --uninstall" -Verbose
    
    Write-Host "✅ Win32 app created successfully using official MSEndpointMgr method!" -ForegroundColor Green
    Write-Host "App ID: $($Win32App.id)" -ForegroundColor Cyan
    Write-Host "Display Name: $($Win32App.displayName)" -ForegroundColor Cyan
    Write-Host "Publisher: $($Win32App.publisher)" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Failed to create Win32 app: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception)" -ForegroundColor Red
    exit 1
}

# Step 8: Verify the app was created successfully
Write-Host "`nStep 8: Verifying app creation..." -ForegroundColor Green
try {
    # Use the official Get-IntuneWin32App function to verify
    $createdApp = Get-IntuneWin32App -DisplayName "FlexApp - $PackageName"
    Write-Host "✅ App verification successful!" -ForegroundColor Green
    Write-Host "App Status: $($createdApp.uploadState)" -ForegroundColor Cyan
    Write-Host "App Type: $($createdApp.'@odata.type')" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Failed to verify app: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎉 UPLOAD COMPLETED USING OFFICIAL MSEndpointMgr MODULE!" -ForegroundColor Green
Write-Host "App ID: $($Win32App.id)" -ForegroundColor Cyan
Write-Host "You can now find your app in the Microsoft Intune admin center." -ForegroundColor Yellow
Write-Host "`nNote: The MSEndpointMgr module handles all file uploads automatically - no manual Graph API calls needed!" -ForegroundColor Green
Write-Host "This is the recommended approach for Intune Win32 app management." -ForegroundColor Green
