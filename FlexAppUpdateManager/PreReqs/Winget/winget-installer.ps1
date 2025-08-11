param(
    [Parameter(Mandatory=$true, HelpMessage="Package ID to install (e.g., Google.Chrome, Mozilla.Firefox)")]
    [string]$PackageId,
    
    [Parameter(Mandatory=$false)]
    [switch]$Silent = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$AcceptAgreements = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [string]$Source
)

# Function to find winget.exe
function Find-Winget {
    $wingetPaths = @(
        "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe",
        "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x86__8wekyb3d8bbwe\winget.exe",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    )
    
    foreach ($path in $wingetPaths) {
        $resolved = Resolve-Path $path -ErrorAction SilentlyContinue
        if ($resolved) {
            return $resolved[-1].Path
        }
    }
    
    # Check if winget is in PATH
    $wingetInPath = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetInPath) {
        return $wingetInPath.Path
    }
    
    return $null
}

# Main script
Write-Host "Searching for winget..." -ForegroundColor Cyan
$wingetPath = Find-Winget

if (-not $wingetPath) {
    Write-Host "ERROR: Winget not found!" -ForegroundColor Red
    Write-Host "Please ensure App Installer is installed from the Microsoft Store." -ForegroundColor Yellow
    Write-Host "You can install it from: https://aka.ms/getwinget" -ForegroundColor Yellow
    exit 1
}

Write-Host "Found winget at: $wingetPath" -ForegroundColor Green

# Build winget command arguments
$arguments = @("install", "--exact", "--id", $PackageId)

if ($Silent) {
    $arguments += "--silent"
}

if ($AcceptAgreements) {
    $arguments += "--accept-package-agreements"
    $arguments += "--accept-source-agreements"
}

if ($Force) {
    $arguments += "--force"
}

if ($Version) {
    $arguments += "--version"
    $arguments += $Version
}

if ($Source) {
    $arguments += "--source"
    $arguments += $Source
}

# Display what will be installed
Write-Host "`nInstalling package: $PackageId" -ForegroundColor Cyan
if ($Version) {
    Write-Host "Version: $Version" -ForegroundColor Cyan
}

# Execute winget
Write-Host "`nExecuting: $wingetPath $($arguments -join ' ')" -ForegroundColor Gray
$process = Start-Process -FilePath $wingetPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow

# Check result
if ($process.ExitCode -eq 0) {
    Write-Host "`nPackage '$PackageId' installed successfully!" -ForegroundColor Green
} else {
    Write-Host "`nPackage installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
    
    # Common exit codes
    switch ($process.ExitCode) {
        -1978335212 { Write-Host "Package not found in repository" -ForegroundColor Yellow }
        -1978335226 { Write-Host "Package already installed" -ForegroundColor Yellow }
        -1978335233 { Write-Host "No applicable upgrade found" -ForegroundColor Yellow }
        default { Write-Host "Check winget logs for more details" -ForegroundColor Yellow }
    }
}

exit $process.ExitCode