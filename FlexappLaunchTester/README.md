# FlexApp Testing Framework v1.0.0

A comprehensive PowerShell-based testing framework for Liquidware FlexApp applications. This framework provides both GUI and command-line interfaces for testing individual FlexApps or running batch tests across multiple applications.

**Status:** ✅ Stable Release - Production Ready  
**Release Date:** August 12, 2025

## 🚀 Quick Start

### Launch GUI Interface
```powershell
.\FlexApp-Launcher.ps1 -GUI
```

### Single Application Test
```powershell
.\FlexApp-Launcher.ps1 -VhdxPath "\\server\apps\MyApp.vhdx"
```

### Batch Testing
```powershell
.\FlexApp-Launcher.ps1 -BatchConfig "CONFIG\flexapp-config.csv" -GenerateSummaryReport
```

## 📁 Project Structure

```
FlexApp-Testing/
├── FlexApp-Launcher.ps1        # Main entry point - unified access to all functionality
├── README.md                   # This file - comprehensive documentation
├── CONFIG/                     # Configuration files
│   └── flexapp-config.csv      # Sample batch testing configuration
├── CORE/                       # Core testing engines
│   ├── FlexApp-Batch-Manager.ps1   # Batch testing orchestrator
│   └── FlexApp-Test-Runner.ps1     # Individual test executor
├── GUI/                        # User interfaces
│   └── FlexApp-Selection-Tool.ps1  # WPF-based application selector
├── MODULES/                    # Shared functionality modules
│   ├── FlexApp-Common-Functions.ps1    # Common utilities and helpers
│   ├── FlexApp-Media-Capture.ps1       # Video/screenshot capture logic
│   ├── FlexApp-Operations.ps1          # FlexApp attach/detach operations
│   ├── FlexApp-Reporting.ps1           # Report generation (HTML/text)
│   └── FlexApp-XML-Parser.ps1          # FlexApp package XML parsing
└── EXAMPLES/                   # Documentation and usage examples
    ├── batch-testing-examples.md       # Batch testing scenarios
    └── single-test-examples.md         # Single test scenarios
```

## 🎯 Features

### ✅ **Multi-Modal Interface**
- **GUI Mode**: User-friendly WPF interface for application selection
- **Command Line**: Full command-line automation support
- **Unified Launcher**: Single entry point for all functionality

### ✅ **Flexible Testing Options**
- **Single Tests**: Test individual FlexApp packages
- **Batch Testing**: Test multiple applications from CSV configuration
- **Custom Recording**: Configurable screen recording duration and timing
- **Pre-Launch Recording**: Capture system state before application launch

### ✅ **Comprehensive Reporting**
- **Video Recording**: MP4 screen recordings of test execution
- **Screenshots**: PNG captures of final application state
- **Text Reports**: Detailed step-by-step execution logs
- **HTML Summaries**: Rich batch testing summary reports with metrics

### ✅ **Advanced Configuration**
- **CSV Configuration**: Per-application settings in batch mode
- **Persistent Settings**: GUI settings saved in user profile
- **Flexible Paths**: Support for network and local file locations
- **Error Handling**: Robust error management with continuation options

### ✅ **Enterprise Ready**
- **Modular Architecture**: Clean separation of concerns
- **PowerShell 5.x Compatible**: Works on older Windows systems
- **Network Aware**: Handles network file access gracefully
- **Extensible**: Easy to add new functionality or integrate with other tools

## 🛠️ Installation & Setup

### Prerequisites
- **Windows PowerShell 5.1** or later
- **FFmpeg Essentials** for video recording - Download from [https://ffmpeg.org/](https://ffmpeg.org/)
  - Only the "Essentials" build is required (smaller download)
  - Framework includes automatic local copy management
  - Supports any FFmpeg installation location
- **Network access** to FlexApp packages (if using network paths)
- **Liquidware ProfileUnity** with FlexApp service running
- **Test Workstation Requirements**:
  - ProfileUnity client installed and configured
  - Standard user account (non-admin recommended for realistic testing)
  - Access to FlexApp catalog locations

### AppLocker Environment Considerations
If your environment uses **AppLocker** or similar application control policies:

#### Option 1: Local FFmpeg Installation (Recommended)
Install FFmpeg locally on each workstation to avoid AppLocker blocks:
```powershell
# Download FFmpeg and extract to one of these locations:
C:\ffmpeg\bin\ffmpeg.exe                    # Preferred location
C:\Program Files\ffmpeg\bin\ffmpeg.exe      # Alternative
# Or add ffmpeg.exe to your system PATH
```

#### Option 2: AppLocker Exceptions
If using network-shared FFmpeg, configure AppLocker to allow execution from:
```
# Temporary directory path (framework's copy location):
c:\users\*\appdata\local\temp\FlexAppTesting\ffmpeg.exe

# Or original network path (if allowed):
\\server\path\to\ffmpeg\bin\ffmpeg.exe
```

#### FFmpeg Detection Logic
The framework automatically:
1. ✅ **Checks for local FFmpeg installations** first (no AppLocker issues)
2. ✅ **Searches common installation paths** (`C:\ffmpeg\bin\`, Program Files, PATH)
3. ✅ **Falls back to network copy** only if no local installation found
4. ✅ **Copies to %TEMP%** to work around AppLocker (when needed)

### Setup Steps
1. **Download FFmpeg Essentials** from [https://ffmpeg.org/](https://ffmpeg.org/) and extract to your preferred location
   - Download the "Essentials" build (sufficient for screen recording and screenshots)
   - Recommended: `C:\ffmpeg\bin\ffmpeg.exe` (default path in framework)
   - Alternative: Any location accessible by the framework
2. **Extract** the framework to your desired location
3. **Configure paths** in `CONFIG\flexapp-config.csv` for your environment
4. **Update FFmpeg path** if not using default `C:\ffmpeg\bin\ffmpeg.exe` location
5. **Test installation** with: `.\FlexApp-Launcher.ps1 -Help`

## 🔄 Complete Workflow

### Step-by-Step Testing Process

#### Phase 1: Application Discovery & Selection (Development/Admin Workstation)
1. **Scan for FlexApp Applications**
   ```powershell
   # Launch the GUI to scan and select applications
   .\FlexApp-Launcher.ps1 -GUI
   ```

2. **Select Applications to Test**
   - Browse and select FlexApp VHDX files from your catalog
   - Configure individual settings (recording duration, wait times, etc.)
   - Review selected applications in the interface

3. **Export Configuration**
   - Click "Export CSV" to save your selection as `flexapp-config.csv`
   - The CSV file contains all selected applications with their settings
   - Copy the generated PowerShell command for testing

#### Phase 2: Testing Execution (Target Workstation)
1. **Prepare Test Environment**
   - Log into a test workstation with **ProfileUnity installed**
   - Ensure the workstation has **standard user permissions** (non-admin recommended)
   - Verify network access to FlexApp catalog locations

2. **Copy Framework Files**
   - Copy the entire FlexApp Testing Framework to the test workstation
   - Ensure `CONFIG\flexapp-config.csv` is included (or use blank config)

3. **Execute Testing**
   ```powershell
   # Paste the generated command from FlexApp-Launcher GUI
   # Example command format:
   powershell.exe -ExecutionPolicy Bypass -File "C:\FlexApp-Testing\CORE\FlexApp-Batch-Manager.ps1" `
       -ListFile "CONFIG\flexapp-config.csv" `
       -TestRunnerPath "C:\FlexApp-Testing\CORE\FlexApp-Test-Runner.ps1" `
       -OutputBaseDir "C:\TestResults" `
       -FFmpegPath "C:\ffmpeg\bin\ffmpeg.exe" `
       -GenerateSummaryReport `
       -RecordBeforeLaunch `
       -VerifyCleanup
   ```

#### Phase 3: Results Analysis
- Review generated reports in the output directory
- Check video recordings and screenshots
- Analyze HTML summary report for batch results

### Important Notes
- ✅ **Standard User Testing**: Framework works with non-admin accounts
- ✅ **Blank Configuration**: Can start with empty CSV and add applications later
- ✅ **Network Independence**: Once copied, framework works without network access
- ✅ **ProfileUnity Required**: Target workstation must have ProfileUnity client installed

## 📖 Usage Examples

### GUI Mode
Perfect for interactive application selection and configuration:
```powershell
# Launch the graphical interface
.\FlexApp-Launcher.ps1 -GUI
```

### Single Application Testing
Test individual FlexApps with various options:
```powershell
# Basic test
.\FlexApp-Launcher.ps1 -VhdxPath "\\server\apps\MyApp.vhdx"

# Extended test with custom settings
.\FlexApp-Launcher.ps1 -VhdxPath "\\server\apps\MyApp.vhdx" `
    -VideoCaptureSeconds 45 `
    -RecordBeforeAppLaunch `
    -OutputDir "C:\TestResults"
```

### Batch Testing
Test multiple applications efficiently:
```powershell
# Basic batch test
.\FlexApp-Launcher.ps1 -BatchConfig "CONFIG\flexapp-config.csv"

# Comprehensive batch test
.\FlexApp-Launcher.ps1 -BatchConfig "CONFIG\flexapp-config.csv" `
    -GenerateSummaryReport `
    -ContinueOnError `
    -OutputDir "D:\WeeklyTests\$(Get-Date -Format 'yyyyMMdd')"
```

## 📋 Configuration

### CSV Configuration Format
Create a `CONFIG\flexapp-config.csv` file with your applications:

```csv
VHDXPath,VideoCaptureSeconds,RecordBeforeLaunch,WaitAfterAttach
\\server\apps\CriticalApp.vhdx,60,TRUE,10
\\server\apps\StandardApp.vhdx,30,FALSE,5
\\server\apps\QuickApp.vhdx,15,FALSE,3
```

### Starting with Blank Configuration
You can begin with an empty CSV file and add applications later:

```csv
VHDXPath,VideoCaptureSeconds,RecordBeforeLaunch,WaitAfterAttach
```

The framework will:
- ✅ **Skip empty CSV files** gracefully
- ✅ **Allow manual addition** of applications to CSV
- ✅ **Support dynamic configuration** updates
- ✅ **Generate commands** even with empty configurations

### Common Parameters
- **VHDXPath**: Path to FlexApp VHDX file
- **VideoCaptureSeconds**: Recording duration (default: 30)
- **RecordBeforeAppLaunch**: Start recording before app launch
- **WaitAfterAttach**: Seconds to wait after FlexApp attachment
- **OutputDir**: Directory for test outputs
- **FFmpegPath**: Path to FFmpeg executable
- **GenerateSummaryReport**: Create HTML batch summary
- **ContinueOnError**: Continue batch testing on individual failures

## 🔧 Advanced Usage

### Direct Component Access
Access core components directly for automation:

```powershell
# Direct batch manager execution
.\CORE\FlexApp-Batch-Manager.ps1 -ListFile "myapps.csv" -GenerateSummaryReport

# Direct test runner execution  
.\CORE\FlexApp-Test-Runner.ps1 -VhdxPath "\\server\app.vhdx" -Verbose
```

### Integration Examples
```powershell
# PowerShell workflow integration
$apps = @("App1.vhdx", "App2.vhdx", "App3.vhdx")
foreach ($app in $apps) {
    $result = .\FlexApp-Launcher.ps1 -VhdxPath "\\server\apps\$app"
    if (-not $result.Success) {
        Send-MailMessage -To "admin@company.com" -Subject "FlexApp Test Failed: $app"
    }
}

# Scheduled testing
$trigger = New-ScheduledTaskTrigger -Daily -At 2AM
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\FlexApp-Testing\FlexApp-Launcher.ps1 -BatchConfig 'CONFIG\nightly-tests.csv'"
Register-ScheduledTask -TaskName "FlexApp-NightlyTests" -Trigger $trigger -Action $action
```

## 📊 Understanding Results

### Output Structure
```
TestResults/
├── Batch_20241201_143022/          # Batch test folder
│   ├── Test_1/                     # Individual test results
│   │   ├── MyApp_Test_20241201_143025.mp4
│   │   ├── MyApp_Screenshot_20241201_143055.png
│   │   └── MyApp_TestReport_20241201_143055.txt
│   ├── BatchTestReport.html        # Batch summary (if enabled)
│   └── BatchTestResults.csv        # Machine-readable results
```

### Success Indicators
- ✅ **Video file created** and playable
- ✅ **Screenshot captured** showing final state  
- ✅ **Test report** shows all steps completed
- ✅ **No error messages** in console output

### Common Scenarios
- 📋 **"No executables found"**: Normal for library/configuration packages
- ⚠️ **Application launch timeout**: May need longer `WaitAfterAttach`
- ❌ **FFmpeg errors**: Check FFmpeg path and permissions
- 🔌 **Network timeouts**: Use local copies or check network connectivity

## 🚨 Troubleshooting

### Common Issues

#### FFmpeg Not Found
```powershell
# Specify custom FFmpeg path
.\FlexApp-Launcher.ps1 -VhdxPath "app.vhdx" -FFmpegPath "C:\tools\ffmpeg\bin\ffmpeg.exe"
```

#### AppLocker "Program is blocked by group policy" Errors
```powershell
# Best solution: Install FFmpeg locally
# Download from https://ffmpeg.org/ and extract to:
C:\ffmpeg\bin\ffmpeg.exe

# Alternative: Add AppLocker exception for temp directory
# Allow execution from: c:\users\*\appdata\local\temp\FlexAppTesting\ffmpeg.exe

# Verify FFmpeg detection:
.\CORE\FlexApp-Test-Runner.ps1 -VhdxPath "test.vhdx" -Verbose
# Should show: "Found local FFmpeg installation: C:\ffmpeg\bin\ffmpeg.exe"
```

#### Permission Errors
```powershell
# Run PowerShell as Administrator
# Or adjust execution policy:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Network Connectivity
```powershell
# Test network access
Test-Path "\\server\apps\MyApp.vhdx"

# Use local paths if network is unreliable
Copy-Item "\\server\apps\*.vhdx" "C:\LocalApps\"
```

### Debug Mode
```powershell
# Enable verbose output for troubleshooting
.\CORE\FlexApp-Test-Runner.ps1 -VhdxPath "app.vhdx" -Verbose
```

## 📚 Additional Documentation

- **[Batch Testing Examples](EXAMPLES/batch-testing-examples.md)**: Comprehensive batch testing scenarios
- **[Single Test Examples](EXAMPLES/single-test-examples.md)**: Individual test use cases
- **Module Documentation**: See individual files in `MODULES/` for API details

## 🤝 Support & Contributing

### Getting Help
1. Check the `EXAMPLES/` directory for usage patterns
2. Review error messages in test reports
3. Use `-Verbose` flag for detailed troubleshooting
4. Verify FlexApp service status and network connectivity

### Architecture Notes
- **Modular Design**: Each component has a single responsibility
- **Error Isolation**: Batch failures don't affect individual test quality
- **Extensible**: Easy to add new test types or reporting formats
- **PowerShell 5.x Compatible**: Works on older Windows systems

##  License

This framework is designed for internal use with Liquidware FlexApp environments. Ensure you have appropriate licenses for all software components used in your testing environment.

---

**Version**: 1.0.0  
**Last Updated**: August 2025  
**PowerShell Compatibility**: 5.1+  
**OS Compatibility**: Windows 10/11, Windows Server 2016+
