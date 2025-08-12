# FlexApp-Test-Runner.ps1
# Individual FlexApp test execution engine
# Executes a single FlexApp test with comprehensive logging and result reporting

param(
    [Parameter(Mandatory=$true)]
    [string]$VhdxPath,
    
    [string]$FFmpegPath = "",  # Will be loaded from config or default
    
    [string]$OutputDir = "",  # Will be loaded from config or default
    
    [string]$ConfigPath = "",  # Optional custom config file path
    
    [switch]$UseNetworkPaths,  # Use network paths from configuration
    
    [int]$VideoCaptureSeconds = 10,
    
    [int]$WaitBeforeRecording = 3,
    
    [int]$WaitAfterAttach = 5,
    
    [switch]$KeepAppOpen,
    
    [switch]$SkipDetach,
    
    [switch]$RecordBeforeLaunch,
    
    [int]$RecordBeforeLaunchDelay = 2,
    
    [switch]$VerboseLogging,
    
    [switch]$ReturnDetailedResults
)

# Load all required modules
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
$modulesDir = Join-Path $rootDir "MODULES"

try {
    . "$modulesDir\FlexApp-Common-Functions.ps1"
    . "$modulesDir\FlexApp-XML-Parser.ps1"
    . "$modulesDir\FlexApp-Operations.ps1"
    . "$modulesDir\FlexApp-Media-Capture.ps1"
    . "$modulesDir\FlexApp-Reporting.ps1"
}
catch {
    Write-Error "Failed to load required modules: $_"
    exit 1
}

# Load framework configuration
$frameworkConfig = Get-FrameworkConfig -ConfigPath $ConfigPath -UseNetworkPaths:$UseNetworkPaths

# Apply configuration to parameters if not explicitly provided
if (-not $FFmpegPath) {
    $FFmpegPath = if ($frameworkConfig.DefaultPaths.FFmpegPath) { 
        $frameworkConfig.DefaultPaths.FFmpegPath 
    } else { 
        "C:\ffmpeg\bin\ffmpeg.exe" 
    }
}

if (-not $OutputDir) {
    $OutputDir = if ($frameworkConfig.DefaultPaths.OutputBaseDir) { 
        # Use a test-specific subdirectory within the base directory
        Join-Path $frameworkConfig.DefaultPaths.OutputBaseDir "SingleTest"
    } else { 
        "C:\Temp\FlexAppTest" 
    }
}

# Apply test defaults - simplified for constrained language mode
# Parameters are already set with defaults in the param block, so this section is not needed

# Function to write verbose output
function Write-TestLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN"  { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "INFO"  { Write-Host $logMessage -ForegroundColor Cyan }
        default { Write-Host $logMessage -ForegroundColor Gray }
    }
    
    if ($Verbose) {
        # Could add file logging here if needed
    }
}

# Function to create comprehensive test result object
function New-TestResult {
    param(
        [string]$VhdxPath,
        [bool]$Success = $false,
        [string]$ErrorMessage = "",
        [hashtable]$Details = @{}
    )
    
    $result = @{
        VhdxPath = $VhdxPath
        StartTime = Get-Date
        Success = $Success
        Error = $ErrorMessage
        NoExecutablesFound = $false
        
        # Application details
        ApplicationName = ""
        Version = ""
        PackageType = ""
        
        # Test execution details
        AttachSuccess = $false
        LaunchSuccess = $false
        RecordingSuccess = $false
        ScreenshotSuccess = $false
        DetachSuccess = $false
        
        # Output files
        VideoPath = ""
        ScreenshotPath = ""
        ReportPath = ""
        
        # Performance metrics
        AttachDuration = [TimeSpan]::Zero
        LaunchDuration = [TimeSpan]::Zero
        RecordingDuration = [TimeSpan]::Zero
        TotalDuration = [TimeSpan]::Zero
        
        # Additional details
        ExecutablePaths = @()
        ProcessesLaunched = @()
        CleanupVerified = $false
    }
    
    # Merge in any additional details
    foreach ($key in $Details.Keys) {
        $result[$key] = $Details[$key]
    }
    
    return $result
}

#region Main Test Execution

Write-TestLog "FlexApp Test Runner Starting" "INFO"
Write-TestLog "Target VHDX: $VhdxPath" "INFO"

# Initialize test result
$testResult = New-TestResult -VhdxPath $VhdxPath

try {
    # Ensure output directory exists
    if (!(Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        Write-TestLog "Created output directory: $OutputDir" "INFO"
    }
    
    # Try to get local FFmpeg copy (AppLocker workaround)
    $localFFmpeg = Get-LocalFFmpeg -NetworkFFmpegPath $FFmpegPath
    if (!$localFFmpeg) {
        Write-TestLog "WARNING: FFmpeg not available - media capture will be disabled" "WARN"
        $localFFmpeg = $FFmpegPath  # Fallback to network path
    } else {
        Write-TestLog "FFmpeg verified: $localFFmpeg" "SUCCESS"
    }
    
    #region Step 1: Parse FlexApp Information
    Write-TestLog "Step 1: Reading FlexApp package information..." "INFO"
    $stepStartTime = Get-Date
    
    $appInfo = Get-FlexAppInfo -VhdxPath $VhdxPath
    if (!$appInfo) {
        throw "Failed to parse FlexApp information from: $VhdxPath"
    }
    
    # Update test result with app information
    $testResult.ApplicationName = $appInfo.DisplayName
    $testResult.Version = $appInfo.Version
    $testResult.PackageType = $appInfo.PackageType
    $testResult.ExecutablePaths = $appInfo.Links | ForEach-Object { $_.Target }
    
    Write-TestLog "Application: $($appInfo.DisplayName)" "INFO"
    Write-TestLog "Version: $($appInfo.Version)" "INFO"
    Write-TestLog "Package Type: $($appInfo.PackageType)" "INFO"
    
    if ($appInfo.HasExecutables) {
        Write-TestLog "Found $($appInfo.Links.Count) executable link(s)" "INFO"
    } else {
        Write-TestLog "No executable links found - may be library/config package" "WARN"
        $testResult.NoExecutablesFound = $true
    }
    
    # Generate output file paths
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $safeAppName = Get-SafeFileName -Name $appInfo.DisplayName
    $outputVideo = Join-Path $OutputDir "${safeAppName}_Test_$timestamp.mp4"
    $outputScreenshot = Join-Path $OutputDir "${safeAppName}_Screenshot_$timestamp.png"
    $reportPath = Join-Path $OutputDir "${safeAppName}_TestReport_$timestamp.txt"
    
    $testResult.VideoPath = $outputVideo
    $testResult.ScreenshotPath = $outputScreenshot
    $testResult.ReportPath = $reportPath
    
    #endregion
    
    #region Step 2: Attach FlexApp
    Write-TestLog "Step 2: Attaching FlexApp..." "INFO"
    $stepStartTime = Get-Date
    
    $attachResult = Invoke-FlexAppAttach -VhdxPath $VhdxPath -WaitAfterAttach $WaitAfterAttach
    $testResult.AttachDuration = (Get-Date) - $stepStartTime
    $testResult.AttachSuccess = $attachResult
    
    if (!$attachResult) {
        throw "Failed to attach FlexApp: $VhdxPath"
    }
    
    Write-TestLog "FlexApp attached successfully" "SUCCESS"
    #endregion
    
    #region Step 3: Launch Application (if executables exist)
    $bestLink = Get-BestExecutable -AppInfo $appInfo
    $appLaunch = $null
    $recordingProcess = $null
    
    if ($bestLink) {
        Write-TestLog "Step 3: Launching application..." "INFO"
        $stepStartTime = Get-Date
        
        # Handle recording before launch
        if ($RecordBeforeLaunch) {
            Write-TestLog "Starting recording before application launch..." "INFO"
            $recordingProcess = Start-VideoRecording -FFmpegPath $localFFmpeg -OutputPath $outputVideo -Duration $VideoCaptureSeconds
            
            if ($recordingProcess) {
                Write-TestLog "Waiting $RecordBeforeLaunchDelay seconds before launching..." "INFO"
                Start-Sleep -Seconds $RecordBeforeLaunchDelay
            }
        }
        
        # Launch the application
        $appLaunch = Start-FlexApplication -LinkInfo $bestLink -AppName $appInfo.DisplayName
        $testResult.LaunchDuration = (Get-Date) - $stepStartTime
        
        if ($appLaunch) {
            $testResult.LaunchSuccess = $true
            $testResult.ProcessesLaunched += $appLaunch.ProcessName
            Write-TestLog "Application launched successfully: $($appLaunch.ProcessName)" "SUCCESS"
            
            if (!$RecordBeforeLaunch) {
                Write-TestLog "Waiting $WaitBeforeRecording seconds for app to load..." "INFO"
                Start-Sleep -Seconds $WaitBeforeRecording
            }
        } else {
            Write-TestLog "Application launch failed or no process detected" "WARN"
        }
    } else {
        Write-TestLog "Step 3: Skipping application launch (no executables)" "WARN"
        $testResult.LaunchSuccess = $true  # Not a failure - just nothing to launch
        
        Write-TestLog "Waiting $WaitBeforeRecording seconds..." "INFO"
        Start-Sleep -Seconds $WaitBeforeRecording
    }
    #endregion
    
    #region Step 4: Handle Screen Recording
    Write-TestLog "Step 4: Managing screen recording..." "INFO"
    $stepStartTime = Get-Date
    
    if (!$RecordBeforeLaunch) {
        Write-TestLog "Starting screen recording..." "INFO"
        $testResult.RecordingSuccess = Invoke-VideoRecording -FFmpegPath $localFFmpeg -OutputPath $outputVideo -Duration $VideoCaptureSeconds
    } else {
        Write-TestLog "Waiting for pre-launch recording to complete..." "INFO"
        $remainingTime = $VideoCaptureSeconds - $RecordBeforeLaunchDelay
        
        if ($remainingTime -gt 0 -and $recordingProcess) {
            $testResult.RecordingSuccess = Wait-VideoRecording -RecordingProcess $recordingProcess -OutputPath $outputVideo -WaitSeconds $remainingTime
        } else {
            $testResult.RecordingSuccess = $true
        }
    }
    
    $testResult.RecordingDuration = (Get-Date) - $stepStartTime
    
    if ($testResult.RecordingSuccess) {
        Write-TestLog "Screen recording completed: $outputVideo" "SUCCESS"
    } else {
        Write-TestLog "Screen recording failed" "ERROR"
    }
    #endregion
    
    #region Step 5: Take Screenshot
    Write-TestLog "Step 5: Taking screenshot..." "INFO"
    $testResult.ScreenshotSuccess = Invoke-Screenshot -FFmpegPath $localFFmpeg -OutputPath $outputScreenshot
    
    if ($testResult.ScreenshotSuccess) {
        Write-TestLog "Screenshot captured: $outputScreenshot" "SUCCESS"
    } else {
        Write-TestLog "Screenshot capture failed" "WARN"
    }
    #endregion
    
    #region Step 6: Close Application
    if (!$KeepAppOpen -and $appLaunch -and $appLaunch.ProcessName) {
        Write-TestLog "Step 6: Closing application..." "INFO"
        $closeResult = Stop-FlexApplication -ProcessName $appLaunch.ProcessName
        Write-TestLog "Application close result: $closeResult" "INFO"
    } elseif ($KeepAppOpen) {
        Write-TestLog "Step 6: Skipping application close (KeepAppOpen specified)" "INFO"
    } else {
        Write-TestLog "Step 6: No application to close" "INFO"
    }
    #endregion
    
    #region Step 7: Detach FlexApp
    if (!$SkipDetach) {
        Write-TestLog "Step 7: Detaching FlexApp..." "INFO"
        $detachResult = Invoke-FlexAppDetach -VhdxPath $VhdxPath
        $testResult.DetachSuccess = $detachResult
        
        if ($detachResult) {
            Write-TestLog "FlexApp detached successfully" "SUCCESS"
        } else {
            Write-TestLog "FlexApp detach failed" "WARN"
        }
    } else {
        Write-TestLog "Step 7: Skipping FlexApp detach (SkipDetach specified)" "INFO"
        $testResult.DetachSuccess = $true
    }
    #endregion
    
    # Mark test as successful
    $testResult.Success = $true
    Write-TestLog "Test execution completed successfully" "SUCCESS"
    
}
catch {
    $testResult.Success = $false
    $testResult.Error = $_.Exception.Message
    Write-TestLog "Test execution failed: $($_.Exception.Message)" "ERROR"
}
finally {
    $testResult.EndTime = Get-Date
    $testResult.TotalDuration = $testResult.EndTime - $testResult.StartTime
    
    Write-TestLog "Test duration: $($testResult.TotalDuration.TotalSeconds) seconds" "INFO"
}

#endregion

#region Generate Test Report
Write-TestLog "Generating test report..." "INFO"

try {
    New-TextReport -TestResult $testResult -OutputPath $testResult.ReportPath
    Write-TestLog "Test report saved: $($testResult.ReportPath)" "SUCCESS"
}
catch {
    Write-TestLog "Failed to generate test report: $_" "ERROR"
}
#endregion

#region Output Summary
Write-TestLog "`n=== Test Execution Summary ===" "INFO"
Write-TestLog "Application: $($testResult.ApplicationName) v$($testResult.Version)" "INFO"
Write-TestLog "Success: $($testResult.Success)" "INFO"

if ($testResult.NoExecutablesFound) {
    Write-TestLog "Note: No executables found (normal for some packages)" "WARN"
}

if ($testResult.Success) {
    Write-TestLog "Video: $($testResult.VideoPath)" "INFO"
    Write-TestLog "Screenshot: $($testResult.ScreenshotPath)" "INFO"
    Write-TestLog "Report: $($testResult.ReportPath)" "INFO"
}

if ($testResult.Error) {
    Write-TestLog "Error: $($testResult.Error)" "ERROR"
}
#endregion

# Return results (for batch processing)
if ($ReturnDetailedResults) {
    return $testResult
} else {
    # Return simplified result for backward compatibility
    return @{
        ApplicationName = $testResult.ApplicationName
        Version = $testResult.Version
        VideoPath = $testResult.VideoPath
        ScreenshotPath = $testResult.ScreenshotPath
        ReportPath = $testResult.ReportPath
        Success = $testResult.Success
        NoExecutablesFound = $testResult.NoExecutablesFound
        Error = $testResult.Error
    }
}
