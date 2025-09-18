# Scripts/Deploy-FlexAppUpdateManager.ps1
# Deployment script for testing FlexApp Update Manager on different systems

param(
    [string]$TargetPath = "C:\Temp\FlexAppUpdateManager-Test",
    [switch]$IncludeTestFiles,
    [switch]$CreateShortcut
)

Write-Host "=== FLEXAPP UPDATE MANAGER DEPLOYMENT ===" -ForegroundColor Magenta
Write-Host "Deploying to: $TargetPath" -ForegroundColor Cyan
Write-Host ""

# Create target directory
if (Test-Path $TargetPath) {
    Write-Host "Removing existing deployment directory..." -ForegroundColor Yellow
    Remove-Item $TargetPath -Recurse -Force
}

Write-Host "Creating deployment directory..." -ForegroundColor Yellow
New-Item -Path $TargetPath -ItemType Directory -Force | Out-Null

# Copy core files
Write-Host "Copying core module files..." -ForegroundColor Yellow
$coreFiles = @(
    "FlexAppUpdateManager.psm1",
    "FlexAppUpdateManager.psd1"
)

foreach ($file in $coreFiles) {
    $sourcePath = Join-Path $PSScriptRoot "..\$file"
    $targetFile = Join-Path $TargetPath $file
    if (Test-Path $sourcePath) {
        Copy-Item $sourcePath $targetFile -Force
        Write-Host "  Copied: $file" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: $file not found" -ForegroundColor Yellow
    }
}

# Copy Functions directory
Write-Host "Copying Functions directory..." -ForegroundColor Yellow
$functionsSource = Join-Path $PSScriptRoot "..\Functions"
$functionsTarget = Join-Path $TargetPath "Functions"
if (Test-Path $functionsSource) {
    Copy-Item $functionsSource $functionsTarget -Recurse -Force
    Write-Host "  Copied: Functions directory" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Functions directory not found" -ForegroundColor Red
}

# Copy GUI directory
Write-Host "Copying GUI directory..." -ForegroundColor Yellow
$guiSource = Join-Path $PSScriptRoot "..\GUI"
$guiTarget = Join-Path $TargetPath "GUI"
if (Test-Path $guiSource) {
    Copy-Item $guiSource $guiTarget -Recurse -Force
    Write-Host "  Copied: GUI directory" -ForegroundColor Green
} else {
    Write-Host "  ERROR: GUI directory not found" -ForegroundColor Red
}

# Copy Config directory
Write-Host "Copying Config directory..." -ForegroundColor Yellow
$configSource = Join-Path $PSScriptRoot "..\Config"
$configTarget = Join-Path $TargetPath "Config"
if (Test-Path $configSource) {
    Copy-Item $configSource $configTarget -Recurse -Force
    Write-Host "  Copied: Config directory" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Config directory not found" -ForegroundColor Yellow
}

# Copy Scripts directory
Write-Host "Copying Scripts directory..." -ForegroundColor Yellow
$scriptsSource = Join-Path $PSScriptRoot "..\Scripts"
$scriptsTarget = Join-Path $TargetPath "Scripts"
if (Test-Path $scriptsSource) {
    Copy-Item $scriptsSource $scriptsTarget -Recurse -Force
    Write-Host "  Copied: Scripts directory" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Scripts directory not found" -ForegroundColor Yellow
}

# Copy test files if requested
if ($IncludeTestFiles) {
    Write-Host "Copying test files..." -ForegroundColor Yellow
    $testSource = Join-Path $PSScriptRoot "..\PreReqs"
    $testTarget = Join-Path $TargetPath "PreReqs"
    if (Test-Path $testSource) {
        Copy-Item $testSource $testTarget -Recurse -Force
        Write-Host "  Copied: PreReqs directory" -ForegroundColor Green
    }
}

# Create README for deployment
Write-Host "Creating deployment README..." -ForegroundColor Yellow
$readmeContent = @"
# FlexApp Update Manager - Test Deployment

This is a test deployment of the FlexApp Update Manager.

## System Requirements
- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or higher
- .NET Framework 4.7.2 or higher

## Quick Start

1. Open PowerShell as Administrator
2. Navigate to this directory
3. Run the system test:
   .\Scripts\Test-FlexAppUpdateManager-System.ps1

4. If tests pass, start the application:
   Import-Module .\FlexAppUpdateManager.psm1 -Force
   Show-FlexAppUpdateManager

## Features
- Chocolatey package updates
- Winget package updates  
- Configuration Manager integration
- ProfileUnity configuration management
- Microsoft Intune package upload
- Real-time console output for uploads

## Troubleshooting

If you encounter issues:
1. Run the system test script first
2. Check PowerShell execution policy: Get-ExecutionPolicy
3. Ensure you have internet connectivity
4. Verify WPF assemblies are available

## Support

For issues or questions, check the console output in the Intune tab
for detailed error messages and status updates.

Deployed on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Source: FlexApp Update Manager v1.5.0
"@

$readmePath = Join-Path $TargetPath "README-TestDeployment.txt"
$readmeContent | Out-File -FilePath $readmePath -Encoding UTF8
Write-Host "  Created: README-TestDeployment.txt" -ForegroundColor Green

# Create desktop shortcut if requested
if ($CreateShortcut) {
    Write-Host "Creating desktop shortcut..." -ForegroundColor Yellow
    try {
        $WshShell = New-Object -comObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\FlexApp Update Manager Test.lnk")
        $Shortcut.TargetPath = "powershell.exe"
        $Shortcut.Arguments = "-NoExit -Command `"cd '$TargetPath'; Import-Module .\FlexAppUpdateManager.psm1 -Force; Show-FlexAppUpdateManager`""
        $Shortcut.WorkingDirectory = $TargetPath
        $Shortcut.Description = "FlexApp Update Manager Test"
        $Shortcut.Save()
        Write-Host "  Created: Desktop shortcut" -ForegroundColor Green
    } catch {
        Write-Host "  WARNING: Could not create desktop shortcut: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Create launch script
Write-Host "Creating launch script..." -ForegroundColor Yellow
$launchScript = @"
# Launch script for FlexApp Update Manager Test
Write-Host "Starting FlexApp Update Manager Test..." -ForegroundColor Green
Write-Host "Deployment Path: $TargetPath" -ForegroundColor Cyan
Write-Host ""

# Change to deployment directory
Set-Location "$TargetPath"

# Import module
Write-Host "Importing FlexApp Update Manager module..." -ForegroundColor Yellow
Import-Module .\FlexAppUpdateManager.psm1 -Force

# Start GUI
Write-Host "Starting GUI..." -ForegroundColor Yellow
Show-FlexAppUpdateManager
"@

$launchPath = Join-Path $TargetPath "Launch-FlexAppUpdateManager-Test.ps1"
$launchScript | Out-File -FilePath $launchPath -Encoding UTF8
Write-Host "  Created: Launch-FlexAppUpdateManager-Test.ps1" -ForegroundColor Green

Write-Host ""
Write-Host "=== DEPLOYMENT COMPLETED ===" -ForegroundColor Magenta
Write-Host "Deployment location: $TargetPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "To test on this system:" -ForegroundColor Yellow
Write-Host "  cd `"$TargetPath`"" -ForegroundColor Gray
Write-Host "  .\Scripts\Test-FlexAppUpdateManager-System.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "To start the application:" -ForegroundColor Yellow
Write-Host "  .\Launch-FlexAppUpdateManager-Test.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "Or manually:" -ForegroundColor Yellow
Write-Host "  Import-Module .\FlexAppUpdateManager.psm1 -Force" -ForegroundColor Gray
Write-Host "  Show-FlexAppUpdateManager" -ForegroundColor Gray
