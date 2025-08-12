# FlexApp-Batch-Manager.ps1
# Simplified batch testing orchestrator

param(
    [Parameter(Mandatory=$true)]
    [string]$ListFile,
    [string]$TestRunnerPath = ".\FlexApp-Test-Runner.ps1",
    [string]$OutputBaseDir = "C:\Temp\FlexAppBatchTests",
    [string]$FFmpegPath = "C:\ffmpeg\bin\ffmpeg.exe",
    [int]$VideoCaptureSeconds = 30,
    [switch]$RecordBeforeLaunch,
    [switch]$RecordBeforeAppLaunch,
    [int]$RecordBeforeLaunchDelay = 2,
    [int]$WaitBeforeRecording = 3,
    [int]$WaitAfterAttach = 5,
    [int]$DelayBetweenTests = 5,
    [switch]$ContinueOnError,
    [switch]$GenerateSummaryReport,
    [switch]$VerifyCleanup
)

Write-Host "FlexApp Batch Test Manager" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

# Load required modules (assuming they are in a 'MODULES' directory relative to this script's root)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
$modulesDir = Join-Path $rootDir "MODULES"

# Dot-source common functions
. "$modulesDir\FlexApp-Common-Functions.ps1"
. "$modulesDir\FlexApp-Reporting.ps1"

# Handle aliases
if ($RecordBeforeAppLaunch) {
    $RecordBeforeLaunch = $true
}

# Verify input file
if (!(Test-Path $ListFile)) {
    Write-Error "Configuration file not found: $ListFile"
    exit 1
}

# Get local FFmpeg copy (AppLocker workaround)
Write-Host "Preparing FFmpeg for batch testing..." -ForegroundColor Gray
$localFFmpeg = Get-LocalFFmpeg -NetworkFFmpegPath $FFmpegPath
if (!$localFFmpeg) {
    Write-Warning "FFmpeg not available - media capture will be disabled for all tests"
    $localFFmpeg = $FFmpegPath  # Fallback to network path
} else {
    Write-Host "FFmpeg prepared: $localFFmpeg" -ForegroundColor Green
}

# Create output directory
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$batchOutputDir = Join-Path $OutputBaseDir "Batch_$timestamp"
New-Item -ItemType Directory -Path $batchOutputDir -Force | Out-Null
Write-Host "Batch output directory: $batchOutputDir" -ForegroundColor Green

# Read CSV file
$csvData = Import-Csv $ListFile
$configs = @()

foreach ($row in $csvData) {
    if ($row.VHDXPath -and $row.VHDXPath -notlike "#*") {
        # Process video duration
        $videoDuration = $VideoCaptureSeconds
        if ($row.VideoCaptureSeconds) {
            $videoDuration = [int]$row.VideoCaptureSeconds
        }
        
        # Process wait after attach
        $waitAfterAttach = $WaitAfterAttach
        if ($row.WaitAfterAttach) {
            $waitAfterAttach = [int]$row.WaitAfterAttach
        }
        
        # Process record before launch
        $recordBefore = $RecordBeforeLaunch
        if ($row.RecordBeforeLaunch -eq "TRUE") {
            $recordBefore = $true
        }
        
        $config = New-Object PSObject -Property @{
            VHDXPath = $row.VHDXPath
            VideoDuration = $videoDuration
            WaitAfterAttach = $waitAfterAttach
            RecordBeforeLaunch = $recordBefore
        }
        $configs += $config
    }
}

Write-Host "Found $($configs.Count) application(s) to test" -ForegroundColor Green

# Execute tests
$testResults = @()
$testNumber = 1

foreach ($config in $configs) {
    Write-Host ""
    Write-Host "=== TEST $testNumber of $($configs.Count) ===" -ForegroundColor Cyan
    Write-Host "Application: $($config.VHDXPath)" -ForegroundColor Yellow
    
    $testOutputDir = Join-Path $batchOutputDir "Test_$testNumber"
    New-Item -ItemType Directory -Path $testOutputDir -Force | Out-Null
    
    # Build command arguments
    $testArgs = @(
        "-VhdxPath"
        "`"$($config.VHDXPath)`""
        "-OutputDir"
        "`"$testOutputDir`""
        "-FFmpegPath"
        "`"$localFFmpeg`""
        "-VideoCaptureSeconds"
        $config.VideoDuration
        "-WaitAfterAttach"
        $config.WaitAfterAttach
        "-WaitBeforeRecording"
        $WaitBeforeRecording
    )
    
    if ($config.RecordBeforeLaunch) {
        $testArgs += "-RecordBeforeLaunch"
        $testArgs += "-RecordBeforeLaunchDelay"
        $testArgs += $RecordBeforeLaunchDelay
    }
    
    # Execute test
    Write-Host "Executing test..." -ForegroundColor Green
    $startTime = Get-Date
    & powershell.exe -ExecutionPolicy Bypass -File $TestRunnerPath @testArgs
    $endTime = Get-Date
    
    # Record result with enhanced properties for HTML reporting
    $appName = Split-Path (Split-Path $config.VHDXPath -Parent) -Leaf
    $videoFile = Get-ChildItem -Path $testOutputDir -Filter "*.mp4" | Select-Object -First 1
    $screenshotFile = Get-ChildItem -Path $testOutputDir -Filter "*.png" | Select-Object -First 1
    
    $testResult = New-Object PSObject -Property @{
        TestNumber = $testNumber
        VhdxPath = $config.VHDXPath
        ApplicationName = $appName
        Success = ($LASTEXITCODE -eq 0)
        Duration = $endTime - $startTime
        OutputDir = $testOutputDir
        VideoPath = if ($videoFile) { $videoFile.FullName } else { $null }
        ScreenshotPath = if ($screenshotFile) { $screenshotFile.FullName } else { $null }
        VideoDuration = $config.VideoDuration
        Error = if ($LASTEXITCODE -ne 0) { "Exit code: $LASTEXITCODE" } else { $null }
        NoExecutablesFound = $false  # This would need to be detected from test runner output
    }
    
    if ($testResult.Success) {
        Write-Host "Test completed successfully" -ForegroundColor Green
    } else {
        Write-Host "Test failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        if (!$ContinueOnError) {
            break
        }
    }
    
    $testResults += $testResult
    
    # Cleanup verification
    if ($VerifyCleanup -and $testNumber -lt $configs.Count) {
        Write-Host ""
        Write-Host "Verifying cleanup..." -ForegroundColor Yellow
        $flexAppProcesses = Get-Process -Name "*FlexApp*" -ErrorAction SilentlyContinue
        if ($flexAppProcesses) {
            Write-Host "Waiting for FlexApp processes to complete..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            # Check again
            $flexAppProcesses = Get-Process -Name "*FlexApp*" -ErrorAction SilentlyContinue
            if (!$flexAppProcesses) {
                Write-Host "Cleanup verified" -ForegroundColor Green
            } else {
                Write-Host "Some FlexApp processes still running" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Cleanup verified (no FlexApp processes found)" -ForegroundColor Green
        }
    }
    
    # Delay between tests
    if ($DelayBetweenTests -gt 0 -and $testNumber -lt $configs.Count) {
        Write-Host "Waiting $DelayBetweenTests seconds before next test..." -ForegroundColor Yellow
        Start-Sleep -Seconds $DelayBetweenTests
    }
    
    $testNumber++
}

# Summary
$successCount = ($testResults | Where-Object { $_.Success }).Count
$failedCount = $testResults.Count - $successCount

Write-Host ""
Write-Host "=== BATCH SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total Tests: $($testResults.Count)" -ForegroundColor Yellow
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failedCount" -ForegroundColor Red
Write-Host "Output Directory: $batchOutputDir" -ForegroundColor Yellow

# Export results as CSV
$csvPath = Join-Path $batchOutputDir "BatchTestResults.csv"
try {
    $testResults | Export-Csv -Path $csvPath -NoTypeInformation -Force
    Write-Host "Results exported to: $csvPath" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to export CSV: $_"
}

# Generate simple text summary report if requested
if ($GenerateSummaryReport) {
    Write-Host ""
    Write-Host "Generating batch summary report..." -ForegroundColor Cyan
    $reportPath = Join-Path $batchOutputDir "BatchSummaryReport.txt"
    
    try {
        $reportContent = @()
        $reportContent += "FlexApp Batch Test Summary"
        $reportContent += "=========================="
        $reportContent += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $reportContent += "Output Directory: $batchOutputDir"
        $reportContent += ""
        $reportContent += "Summary Statistics"
        $reportContent += "------------------"
        $reportContent += "Total Tests: $($testResults.Count)"
        $reportContent += "Successful: $successCount"
        $reportContent += "Failed: $failedCount"
        if ($testResults.Count -gt 0) {
            $successRate = [int](($successCount / $testResults.Count) * 100)
            $reportContent += "Success Rate: $successRate%"
        }
        $reportContent += ""
        $reportContent += "Test Results"
        $reportContent += "------------"
        
        foreach ($result in $testResults) {
            $statusText = if ($result.Success) { "PASS" } else { "FAIL" }
            $appName = Split-Path (Split-Path $result.VHDXPath -Parent) -Leaf
            $durationText = if ($result.Duration) { "$([int]$result.Duration.TotalSeconds)s" } else { "N/A" }
            
            $reportContent += "Test $($result.TestNumber): $appName - $statusText ($durationText)"
            $reportContent += "  Output: $($result.OutputDir)"
        }
        
        $reportContent | Out-File -FilePath $reportPath -Encoding UTF8
        Write-Host "Summary report generated: $reportPath" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to generate text report: $_"
    }
    
    # Generate HTML report
    Write-Host "Generating HTML report..." -ForegroundColor Cyan
    $htmlReportPath = Join-Path $batchOutputDir "BatchTestReport.html"
    
    try {
        New-HTMLReport -TestResults $testResults -OutputPath $htmlReportPath
        Write-Host "HTML report generated: $htmlReportPath" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to generate HTML report: $_"
    }
}

if ($failedCount -gt 0) {
    exit 1
} else {
    exit 0
}