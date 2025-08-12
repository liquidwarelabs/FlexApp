# FlexApp Single Test Examples

This document provides examples of how to use the FlexApp Testing Framework for testing individual applications.

## Basic Single Testing

### Using the Main Launcher
```powershell
# Basic single test
.\FlexApp-Launcher.ps1 -VhdxPath "\\server\apps\MyApp.vhdx"

# Single test with custom recording duration
.\FlexApp-Launcher.ps1 -VhdxPath "\\server\apps\MyApp.vhdx" -VideoCaptureSeconds 45
```

### Using Core Components Directly
```powershell
# Direct execution of test runner
.\CORE\FlexApp-Test-Runner.ps1 -VhdxPath "\\server\apps\MyApp.vhdx"
```

## Advanced Single Testing Options

### Custom Output Directory
```powershell
.\FlexApp-Launcher.ps1 -VhdxPath "\\server\apps\MyApp.vhdx" `
    -OutputDir "C:\MyTests\$(Get-Date -Format 'yyyyMMdd')"
```

### Recording Before App Launch
```powershell
.\FlexApp-Launcher.ps1 -VhdxPath "\\server\apps\MyApp.vhdx" `
    -RecordBeforeAppLaunch `
    -VideoCaptureSeconds 30
```

### Keep Application Open for Manual Testing
```powershell
.\FlexApp-Launcher.ps1 -VhdxPath "\\server\apps\MyApp.vhdx" `
    -KeepAppOpen
```

### Complete Custom Test Setup
```powershell
.\FlexApp-Launcher.ps1 -VhdxPath "\\server\apps\CriticalApp.vhdx" `
    -OutputDir "D:\TestResults\CriticalApp" `
    -FFmpegPath "C:\tools\ffmpeg\bin\ffmpeg.exe" `
    -VideoCaptureSeconds 60 `
    -RecordBeforeAppLaunch `
    -KeepAppOpen
```

## Direct Test Runner Usage

The Test Runner provides more granular control:

### Basic Usage
```powershell
.\CORE\FlexApp-Test-Runner.ps1 `
    -VhdxPath "\\server\apps\MyApp.vhdx" `
    -OutputDir "C:\Tests"
```

### Advanced Options
```powershell
.\CORE\FlexApp-Test-Runner.ps1 `
    -VhdxPath "\\server\apps\MyApp.vhdx" `
    -OutputDir "C:\Tests" `
    -FFmpegPath "C:\ffmpeg\bin\ffmpeg.exe" `
    -VideoCaptureSeconds 30 `
    -WaitBeforeRecording 5 `
    -WaitAfterAttach 10 `
    -RecordBeforeLaunch `
    -RecordBeforeLaunchDelay 3 `
    -Verbose `
    -ReturnDetailedResults
```

### Skip Operations
```powershell
# Keep app open and skip detach (for manual inspection)
.\CORE\FlexApp-Test-Runner.ps1 `
    -VhdxPath "\\server\apps\MyApp.vhdx" `
    -KeepAppOpen `
    -SkipDetach
```

## Output Files

Single tests create the following files:
```
OutputDirectory\
├── AppName_Test_YYYYMMDD_HHMMSS.mp4       # Screen recording
├── AppName_Screenshot_YYYYMMDD_HHMMSS.png # Final screenshot
└── AppName_TestReport_YYYYMMDD_HHMMSS.txt # Detailed test report
```

## Understanding Test Results

### Success Indicators
- **Test completes without errors**
- **Video file is created and playable**
- **Screenshot captures final state**
- **Test report shows all steps completed**

### Common Scenarios
- **No Executables Found**: Normal for library/configuration packages
- **Application Launch Failed**: May indicate package issues or dependencies
- **Recording Failed**: Usually FFmpeg path or permission issues
- **Attach Failed**: Network connectivity or FlexApp service issues

## Timing Parameters

### Understanding Wait Times
- **WaitAfterAttach**: Time to wait after FlexApp attachment (default: 5s)
- **WaitBeforeRecording**: Time to wait before starting recording (default: 3s)
- **RecordBeforeLaunchDelay**: Time to record before launching app (default: 2s)
- **VideoCaptureSeconds**: Total recording duration (default: 10s)

### Recommended Settings by App Type
```powershell
# Fast-loading applications
-VideoCaptureSeconds 15 -WaitAfterAttach 3

# Complex applications with long startup
-VideoCaptureSeconds 45 -WaitAfterAttach 10 -WaitBeforeRecording 5

# Applications requiring pre-launch recording
-RecordBeforeAppLaunch -RecordBeforeLaunchDelay 5 -VideoCaptureSeconds 30
```

## Troubleshooting Single Tests

### Test Runner Verbosity
```powershell
# Enable detailed logging
.\CORE\FlexApp-Test-Runner.ps1 -VhdxPath "\\server\apps\MyApp.vhdx" -Verbose
```

### Common Issues and Solutions

#### FlexApp Attach Fails
```powershell
# Increase wait time
-WaitAfterAttach 15
```

#### Application Won't Launch
```powershell
# Check if it's a library package (normal)
# Verify in test report: "No executables found"
```

#### Recording Issues
```powershell
# Verify FFmpeg path
-FFmpegPath "C:\ffmpeg\bin\ffmpeg.exe"

# Check permissions
# Run PowerShell as Administrator
```

#### Performance Issues
```powershell
# Use local output directory
-OutputDir "C:\TempTests"

# Reduce recording time for initial testing
-VideoCaptureSeconds 10
```

## Integration with Other Tools

### PowerShell Workflows
```powershell
# Test and analyze result
$result = .\FlexApp-Launcher.ps1 -VhdxPath "\\server\apps\MyApp.vhdx"
if ($result.Success) {
    Write-Host "Test passed, opening video..."
    Start-Process $result.VideoPath
}
```

### Scheduled Testing
```powershell
# Create scheduled task for regular testing
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\FlexApp-Testing\FlexApp-Launcher.ps1 -VhdxPath '\\server\apps\CriticalApp.vhdx'"
```
