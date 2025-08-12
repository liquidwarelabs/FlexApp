# FlexApp Update Manager

A modern PowerShell-based application for managing package updates across multiple platforms including Chocolatey, Winget, Configuration Manager, and ProfileUnity.

## 🚀 Quick Start

```powershell
# Navigate to the FUM directory
cd .\FUM

# Import the module
Import-Module .\FlexAppUpdateManager.psm1

# Launch the GUI
Show-FlexAppUpdateManager
```

### Alternative Launch Methods

```powershell
# Method 1: Direct module import and launch
Import-Module .\FlexAppUpdateManager.psm1; Show-FlexAppUpdateManager

# Method 2: Using the launcher script
.\Scripts\Launch-FlexAppUpdateManager.ps1

# Method 3: Using root directory launcher (if available)
..\Launch.ps1
```

## 📋 Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+
- .NET Framework 4.5+ (for WPF assemblies)
- Administrator privileges (for Configuration Manager features)

## 🎯 Features

### Package Management
- **Chocolatey Updates** - Scan and update Chocolatey packages from CSV files
- **Winget Updates** - Manage Windows Package Manager updates with version checking
- **Configuration Manager** - Integration with Microsoft Configuration Manager
- **ProfileUnity** - FlexApp configuration management and deployment

### User Interface
- **Modern WPF Interface** - Material Design with light/dark theme support
- **Tabbed Navigation** - Organized workflow across different package sources
- **Real-time Status** - Live updates during scanning and processing operations
- **Theme Persistence** - Settings and file paths persist across theme changes

### Configuration & Settings
- **Centralized Settings** - Unified configuration management with auto-save
- **SSL Certificate Handling** - Automatic handling of self-signed certificates
- **Job File Management** - CSV-based package selection with file path persistence
- **Server Connection Testing** - Built-in connectivity testing for ProfileUnity

### Technical Features
- **Comprehensive Logging** - Color-coded logging with different verbosity levels
- **Background Processing** - Non-blocking operations with progress indication
- **Error Handling** - Graceful error recovery and user-friendly error messages
- **PowerShell Compatibility** - Works with both PowerShell 5.1 and 7+

## 📁 Project Structure

```
FUM/                                       # Main application directory
├── FlexAppUpdateManager.psd1              # Module manifest
├── FlexAppUpdateManager.psm1              # Main module file
├── README.md                              # This documentation
├── Config/                                # Configuration files
│   ├── Configuration.ps1                  # Core configuration
│   ├── Initialize-Module.ps1              # Module initialization
│   ├── process-management.ps1             # Process management
│   └── Settings-Persistence.ps1           # Settings persistence
├── Functions/                             # Core functionality
│   ├── Chocolatey/                        # Chocolatey functions
│   ├── ConfigurationManager/              # Configuration Manager functions
│   ├── ProfileUnity/                      # ProfileUnity functions
│   ├── Shared/                            # Shared utilities
│   ├── Winget/                            # Winget functions
│   └── WPF/                               # WPF-specific functions
├── GUI/                                   # WPF interface files
│   ├── MainWindow.xaml                    # Main UI layout
│   ├── EditApplicationsDialog.xaml        # Edit dialog
│   └── Show-FlexAppUpdateManager.ps1      # Main window function
├── Scripts/                               # Utility scripts
│   ├── Launch-FlexAppUpdateManager.ps1    # Main launcher
│   └── Test-FlexAppUpdateManager.ps1      # Test script
├── Docs/                                  # Documentation
└── PreReqs/                               # Prerequisites
    └── Winget/                            # Winget installation helpers
```

## 🔧 Usage

### Basic Usage
```powershell
# Navigate to the FUM directory (if not already there)
cd .\FUM

# Import the module (loads all functions and configurations)
Import-Module .\FlexAppUpdateManager.psm1

# Launch the WPF GUI
Show-FlexAppUpdateManager
```

### One-Line Launch
```powershell
# Single command to import and launch
Import-Module .\FlexAppUpdateManager.psm1; Show-FlexAppUpdateManager
```

### Using the Launcher Script
```powershell
# Use the dedicated launcher script
.\Scripts\Launch-FlexAppUpdateManager.ps1

# The launcher handles module import and error checking automatically
```

### Testing the Installation
```powershell
# Run basic module and GUI tests
.\Scripts\Test-FlexAppUpdateManager.ps1

# Test just the module loading
Import-Module .\FlexAppUpdateManager.psm1 -Verbose
```

### Configuration Setup

First-time setup requires configuring connection settings:

1. **ProfileUnity Connection** - Configure server name and credentials
2. **FlexApp Client Path** - Set path to primary-client.exe
3. **Job Files** - Select CSV files for Chocolatey and Winget scans
4. **Configuration Manager** - Set site server and site code (if using CM)

All settings are saved automatically and persist between sessions.

## 📚 Documentation

- [Main Documentation](Docs/README.md) - Comprehensive guide
- [WPF Implementation](Docs/README-WPF.md) - WPF-specific details
- [Implementation Summary](Docs/WPF-IMPLEMENTATION-SUMMARY.md) - Technical details

## 🛠️ Development

### Architecture
- **Modular Design** - Separated by functionality
- **WPF Integration** - Modern UI with PowerShell backend
- **Event-Driven** - Responsive user interface
- **Thread-Safe** - Background processing with UI updates

### Extending Functionality
1. Add new functions to appropriate subdirectories
2. Update the main module file to load new functions
3. Add corresponding WPF UI elements if needed
4. Update documentation

## 🐛 Troubleshooting

### Common Issues

**Module Import Errors**
```powershell
# Make sure you're in the FUM directory
Get-Location

# Check if the module file exists
Test-Path .\FlexAppUpdateManager.psm1

# Try importing with verbose output to see what's failing
Import-Module .\FlexAppUpdateManager.psm1 -Verbose
```

**GUI Won't Launch**
```powershell
# Run the test script to check all components
.\Scripts\Test-FlexAppUpdateManager.ps1

# Check if the main function is available
Get-Command Show-FlexAppUpdateManager
```

**ProfileUnity Connection Issues**
```powershell
# Test SSL connectivity
Test-NetConnection -ComputerName "your-server" -Port 8000

# Check SSL policy initialization
Initialize-SSLPolicy
```

**Permission Issues**
- Ensure PowerShell is running as Administrator (required for CM features)
- Check file permissions on the FUM directory
- Verify network connectivity to ProfileUnity server

**Theme/Settings Not Persisting**
- Settings are saved to: `$env:APPDATA\LiquidwareSparks\FlexAppUpdateManager\config.json`
- Check if this directory is writable
- Theme switching automatically saves job file paths and CM settings

## 📄 License

This project is part of the FlexApp Update Manager suite.

## 📈 Version History

- **v1.0.1** - Stable release with all critical fixes
  - Fixed GUI launch issues (missing Test-WPFGlobalSettings function)
  - Fixed job file persistence during theme switching
  - Fixed Configuration Manager settings persistence  
  - Fixed SSL certificate handling for ProfileUnity connections
  - Cleaned up codebase (removed obsolete WinForms code and test files)
  - Improved PowerShell 5.x compatibility
- **v1.0.0** - Initial release with WPF interface

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📞 Support

For issues and questions:
1. Check the troubleshooting section
2. Review the logging output
3. Run the test script to verify functionality
4. Check the implementation summary for technical details
