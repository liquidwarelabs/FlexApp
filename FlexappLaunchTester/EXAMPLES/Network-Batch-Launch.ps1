# Network-Batch-Launch.ps1
# Quick launcher for running FlexApp batch testing from network locations
# Pre-configured with your specific network paths

param(
    [string]$ConfigFile = "\\pro2020\profileUnity\Automation\LaunchTesting\FlexappLaunchTester\CONFIG\flexapp-config.csv",
    [string]$OutputDir = "",  # Will default to \\pro2020\ProfileShare\$env:USERNAME\Captures
    [int]$VideoCaptureSeconds = 60,
    [int]$WaitAfterAttach = 15,
    [switch]$GenerateSummaryReport,
    [switch]$RecordBeforeAppLaunch,
    [switch]$VerifyCleanup,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Network Batch Launch Script
===========================
Quick launcher for FlexApp batch testing from network deployment.

USAGE:
    .\Network-Batch-Launch.ps1 [options]

OPTIONS:
    -ConfigFile <path>          CSV config file (default: network location)
    -OutputDir <path>           Output directory (default: user profile share)
    -VideoCaptureSeconds <n>    Recording duration (default: 60)
    -WaitAfterAttach <n>        Wait time after attach (default: 15)
    -GenerateSummaryReport      Create HTML summary report
    -RecordBeforeAppLaunch      Record before app launch
    -VerifyCleanup              Verify cleanup between tests
    -Help                       Show this help

EXAMPLES:
    # Basic run with defaults
    .\Network-Batch-Launch.ps1

    # With summary report and recording
    .\Network-Batch-Launch.ps1 -GenerateSummaryReport -RecordBeforeAppLaunch

    # Custom output location
    .\Network-Batch-Launch.ps1 -OutputDir "C:\Temp\MyTests" -VideoCaptureSeconds 90

PRE-CONFIGURED PATHS:
    Batch Manager: \\server\share\Automation\LaunchTesting\Flexapp-Testing\CORE\FlexApp-Batch-Manager.ps1
    Test Runner:   \\pro2020\profileUnity\Automation\LaunchTesting\FlexappLaunchTester\CORE\FlexApp-Test-Runner.ps1
    FFmpeg:        \\pro2020\profileUnity\Automation\LaunchTesting\FlexappLaunchTester\ffmpeg\bin\ffmpeg.exe
    Config File:   \\pro2020\profileUnity\Automation\LaunchTesting\FlexappLaunchTester\CONFIG\flexapp-config.csv

This script eliminates the need to manually configure paths in the GUI.
"@ -ForegroundColor Cyan
    return
}

# Set default output directory if not specified
if (-not $OutputDir) {
    $OutputDir = "\\pro2020\ProfileShare\$env:USERNAME\Captures"
}

# Pre-configured network paths (exactly matching your command)
$batchManagerPath = "\\server\share\Automation\LaunchTesting\Flexapp-Testing\CORE\FlexApp-Batch-Manager.ps1"
$testRunnerPath = "\\pro2020\profileUnity\Automation\LaunchTesting\FlexappLaunchTester\CORE\FlexApp-Test-Runner.ps1"
$ffmpegPath = "\\pro2020\profileUnity\Automation\LaunchTesting\FlexappLaunchTester\ffmpeg\bin\ffmpeg.exe"

Write-Host "FlexApp Network Batch Launcher" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "Config File: $ConfigFile" -ForegroundColor Yellow
Write-Host "Output Dir:  $OutputDir" -ForegroundColor Yellow
Write-Host "Video Duration: $VideoCaptureSeconds seconds" -ForegroundColor Yellow
Write-Host "Wait After Attach: $WaitAfterAttach seconds" -ForegroundColor Yellow
Write-Host ""

# Build the command arguments
$arguments = @(
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$batchManagerPath`"",
    "-TestRunnerPath", "`"$testRunnerPath`"",
    "-ListFile", "`"$ConfigFile`"",
    "-OutputBaseDir", "`"$OutputDir`"",
    "-FFmpegPath", "`"$ffmpegPath`"",
    "-VideoCaptureSeconds", $VideoCaptureSeconds,
    "-WaitAfterAttach", $WaitAfterAttach
)

# Add optional switches
if ($GenerateSummaryReport) {
    $arguments += "-GenerateSummaryReport"
    Write-Host "Summary Report: Enabled" -ForegroundColor Green
}

if ($RecordBeforeAppLaunch) {
    $arguments += "-RecordBeforeAppLaunch"
    Write-Host "Record Before Launch: Enabled" -ForegroundColor Green
}

if ($VerifyCleanup) {
    $arguments += "-VerifyCleanup"
    Write-Host "Verify Cleanup: Enabled" -ForegroundColor Green
}

Write-Host ""
Write-Host "Starting batch test execution..." -ForegroundColor Green

try {
    # Execute the batch manager
    & powershell.exe @arguments
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Batch testing completed successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Batch testing completed with errors (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
    }
}
catch {
    Write-Error "Failed to execute batch testing: $_"
    exit 1
}
