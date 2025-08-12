# FlexApp Batch Testing Examples

This document provides examples of how to use the FlexApp Testing Framework for batch testing multiple applications.

## Basic Batch Testing

### Using the Main Launcher
```powershell
# Launch with default settings
.\FlexApp-Launcher.ps1 -BatchConfig "CONFIG\flexapp-config.csv"

# Launch with custom output directory and summary report
.\FlexApp-Launcher.ps1 -BatchConfig "CONFIG\flexapp-config.csv" -OutputDir "C:\TestResults" -GenerateSummaryReport
```

### Using Core Components Directly
```powershell
# Direct execution of batch manager
.\CORE\FlexApp-Batch-Manager.ps1 -ListFile "CONFIG\flexapp-config.csv" -GenerateSummaryReport
```

## Configuration File Format

### CSV Configuration (Recommended)
Create a CSV file with the following columns:

```csv
VHDXPath,VideoCaptureSeconds,RecordBeforeLaunch,WaitAfterAttach
\\server\apps\App1.vhdx,30,TRUE,5
\\server\apps\App2.vhdx,45,FALSE,10
\\server\apps\App3.vhdx,20,TRUE,15
```

### Advanced CSV with Custom Settings
```csv
VHDXPath,VideoCaptureSeconds,RecordBeforeLaunch,WaitAfterAttach,Priority,Category
\\server\apps\CriticalApp.vhdx,60,TRUE,10,High,Production
\\server\apps\TestApp.vhdx,30,FALSE,5,Low,Development
```

### Text File Configuration (Simple)
```text
\\server\apps\App1.vhdx
\\server\apps\App2.vhdx
\\server\apps\App3.vhdx
# This is a comment - lines starting with # or ; are ignored
;\\server\apps\DisabledApp.vhdx
```

## Advanced Batch Testing Options

### Continue on Errors
```powershell
.\FlexApp-Launcher.ps1 -BatchConfig "CONFIG\flexapp-config.csv" -ContinueOnError
```

### Custom Recording Settings
```powershell
.\FlexApp-Launcher.ps1 -BatchConfig "CONFIG\flexapp-config.csv" `
    -VideoCaptureSeconds 45 `
    -RecordBeforeAppLaunch `
    -FFmpegPath "C:\tools\ffmpeg\bin\ffmpeg.exe"
```

### Comprehensive Testing with All Options
```powershell
.\FlexApp-Launcher.ps1 -BatchConfig "CONFIG\flexapp-config.csv" `
    -OutputDir "D:\FlexAppTests\$(Get-Date -Format 'yyyyMMdd')" `
    -FFmpegPath "C:\ffmpeg\bin\ffmpeg.exe" `
    -VideoCaptureSeconds 30 `
    -RecordBeforeAppLaunch `
    -GenerateSummaryReport `
    -ContinueOnError
```

## Output Structure

Batch testing creates the following output structure:
```
OutputDirectory\
├── Batch_YYYYMMDD_HHMMSS\
│   ├── Test_1\
│   │   ├── AppName_Test_YYYYMMDD_HHMMSS.mp4
│   │   ├── AppName_Screenshot_YYYYMMDD_HHMMSS.png
│   │   └── AppName_TestReport_YYYYMMDD_HHMMSS.txt
│   ├── Test_2\
│   │   └── ...
│   ├── BatchTestReport.html
│   └── BatchTestResults.csv
```

## Best Practices

1. **Use CSV configuration** for complex scenarios with per-app settings
2. **Enable summary reports** for batch visibility: `-GenerateSummaryReport`
3. **Use ContinueOnError** for large batches: `-ContinueOnError`
4. **Organize output directories** by date or test purpose
5. **Test critical apps first** by ordering them at the top of your config file
6. **Use meaningful output directory names** to identify test runs

## Troubleshooting

### Common Issues
- **FFmpeg not found**: Ensure FFmpeg path is correct or use `-FFmpegPath` parameter
- **Network timeouts**: Use local script copies for better reliability
- **Permission issues**: Run PowerShell as Administrator if accessing network resources
- **Large batches timing out**: Use `-ContinueOnError` and check individual test logs

### Debug Mode
```powershell
# Enable verbose output (when available)
.\CORE\FlexApp-Batch-Manager.ps1 -ListFile "CONFIG\flexapp-config.csv" -Verbose
```
