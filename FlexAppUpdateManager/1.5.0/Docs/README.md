# FlexApp Update Manager

A modern PowerShell-based application for managing package updates across multiple platforms including Chocolatey, Winget, Configuration Manager, and ProfileUnity.

## Overview

FlexApp Update Manager provides a unified interface for managing software updates across different package management systems. Built with WPF (Windows Presentation Foundation), it offers a modern, responsive user interface with Material Design-inspired styling.

## Features

### Package Management
- **Chocolatey Updates** - Scan and update Chocolatey packages
- **Winget Updates** - Manage Windows Package Manager updates
- **Configuration Manager** - Integration with Microsoft Configuration Manager
- **ProfileUnity** - FlexApp configuration management

### Modern Interface
- **WPF-based GUI** - Modern, responsive user interface
- **Material Design** - Clean, professional appearance
- **Hardware Acceleration** - Better performance through GPU acceleration
- **Responsive Layout** - Adapts to different screen sizes

### Core Functionality
- **Centralized Settings** - Unified configuration management
- **Logging System** - Comprehensive logging and error tracking
- **Background Processing** - Non-blocking operations
- **Progress Tracking** - Real-time status updates

## Installation

### Prerequisites
- Windows PowerShell 5.1 or PowerShell 7+
- .NET Framework 4.5+ (for WPF assemblies)
- Administrator privileges (for Configuration Manager features)

### Quick Start
1. Clone or download the repository
2. Navigate to the FUM directory
3. Run the launcher script:
   ```powershell
   .\Launch-FlexAppUpdateManager.ps1
   ```

## Usage

### Basic Usage
```powershell
# Import the module
Import-Module ".\FlexAppUpdateManager.psm1"

# Start the application
Show-FlexAppUpdateManager
```

### Using the Launcher
```powershell
# Launch with default settings
.\Launch-FlexAppUpdateManager.ps1

# Force WPF interface
.\Launch-FlexAppUpdateManager.ps1 -ForceWPF
```

### Testing
```powershell
# Run basic tests
.\Test-FlexAppUpdateManager.ps1
```

## File Structure

```
FUM/
├── FlexAppUpdateManager.psd1              # Module manifest
├── FlexAppUpdateManager.psm1              # Main module file
├── Show-FlexAppUpdateManager.ps1          # Main WPF window function
├── Launch-FlexAppUpdateManager.ps1        # Launcher script
├── Test-FlexAppUpdateManager.ps1          # Test script
├── MainWindow.xaml                        # Main WPF UI layout
├── EditApplicationsDialog.xaml            # Edit applications dialog
├── README.md                              # This documentation
├── README-WPF.md                          # WPF-specific documentation
├── WPF-IMPLEMENTATION-SUMMARY.md          # Implementation details
├── Config/                                # Configuration files
│   ├── Configuration.ps1                  # Core configuration
│   ├── Initialize-Module.ps1              # Module initialization
│   ├── process-management.ps1             # Process management
│   ├── Settings-Management.ps1            # Settings management
│   └── Settings-Persistence.ps1           # Settings persistence
├── Functions/                             # Core functionality
│   ├── Chocolatey/                        # Chocolatey functions
│   ├── ConfigurationManager/              # Configuration Manager functions
│   ├── ProfileUnity/                      # ProfileUnity functions
│   ├── Shared/                            # Shared utilities
│   ├── Winget/                            # Winget functions
│   └── WPF/                               # WPF-specific functions
└── PreReqs/                               # Prerequisites
    └── Winget/
        └── winget-installer.ps1           # Winget installer
```

## Configuration

### Settings Management
The application uses a centralized configuration system that stores settings in:
- User-specific configuration files
- Environment-based settings
- Secure credential storage

### Key Settings
- **Server Connections** - ProfileUnity and Configuration Manager servers
- **File Paths** - Default locations for package catalogs
- **Authentication** - Secure credential management
- **Logging** - Configurable logging levels and destinations

## Troubleshooting

### Common Issues

**WPF Not Available**
```powershell
# Check WPF availability
Test-WPFAvailable
```

**Module Import Errors**
```powershell
# Check module path
Get-Module -ListAvailable FlexAppUpdateManager
```

**Permission Issues**
- Ensure PowerShell is running as Administrator
- Check file permissions on the module directory

### Logging
The application provides comprehensive logging:
- Console output with color-coded messages
- File-based logging with configurable levels
- Error tracking and debugging information

## Development

### Architecture
- **Modular Design** - Separated by functionality (Chocolatey, Winget, etc.)
- **WPF Integration** - Modern UI with PowerShell backend
- **Event-Driven** - Responsive user interface
- **Thread-Safe** - Background processing with UI updates

### Extending Functionality
1. Add new functions to appropriate subdirectories
2. Update the main module file to load new functions
3. Add corresponding WPF UI elements if needed
4. Update documentation

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review the logging output
3. Run the test script to verify functionality
4. Check the implementation summary for technical details

## License

This project is part of the FlexApp Update Manager suite.

## 📝 Memorial

This release is dedicated to the memory of Andreas Van Wingerden, who contributed to the FlexApp ecosystem and the broader IT community. His dedication to innovation and excellence continues to inspire the development of tools that make IT professionals' lives easier and more efficient.

*In loving memory of Andreas Van Wingerden.*

## Version History

- **v1.5.0** - Microsoft Intune Integration Release
- **v1.2.4** - Consolidated WPF implementation
- **v1.2.3** - Original WinForms version
- **v1.2.2** - Enhanced Configuration Manager integration
- **v1.2.1** - Added Winget support
- **v1.2.0** - Initial release with Chocolatey support
