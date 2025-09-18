# FlexApp Update Manager v1.5.0

A comprehensive PowerShell-based application for managing package updates across multiple platforms including Chocolatey, Winget, Configuration Manager, ProfileUnity, and Microsoft Intune.

## Table of Contents
1. [Overview](#overview)
2. [Features](#features)
3. [Prerequisites](#prerequisites)
4. [Installation](#installation)
5. [Quick Start](#quick-start)
6. [Usage](#usage)
7. [Configuration](#configuration)
8. [Project Structure](#project-structure)
9. [Version History](#version-history)
10. [Troubleshooting](#troubleshooting)
11. [Support](#support)

## Overview

FlexApp Update Manager is a modern PowerShell-based GUI application that provides a unified interface for managing software updates across different package management systems. Built with WPF (Windows Presentation Foundation), it offers a responsive user interface with Material Design-inspired styling and comprehensive package management capabilities.

The application supports multiple package sources and provides centralized configuration management, making it an essential tool for IT administrators managing FlexApp packages across enterprise environments.

## Features

### Package Management
- **Chocolatey Updates** - Scan and update Chocolatey packages from CSV files
- **Winget Updates** - Manage Windows Package Manager updates with version checking
- **Configuration Manager** - Integration with Microsoft Configuration Manager
- **ProfileUnity** - FlexApp configuration management and deployment
- **Microsoft Intune** - Upload Win32 applications to Microsoft Endpoint Manager using MSEndpointMgr module

### User Interface
- **Modern WPF Interface** - Material Design with light/dark theme support
- **Tabbed Navigation** - Organized workflow across different package sources
- **Real-time Status** - Live updates during scanning and processing operations
- **Theme Persistence** - Settings and file paths persist across theme changes
- **Intune Integration Tab** - Dedicated interface for Microsoft Intune application uploads

### Configuration & Settings
- **Centralized Settings** - Unified configuration management with auto-save
- **SSL Certificate Handling** - Automatic handling of self-signed certificates
- **Job File Management** - CSV-based package selection with file path persistence
- **Server Connection Testing** - Built-in connectivity testing for ProfileUnity and Intune
- **Azure App Registration** - Secure credential management for Microsoft Graph API
- **Intune Settings Persistence** - Automatic saving of Intune configuration and credentials

### Technical Features
- **Comprehensive Logging** - Color-coded logging with different verbosity levels
- **Background Processing** - Non-blocking operations with progress indication
- **Error Handling** - Graceful error recovery and user-friendly error messages
- **PowerShell Compatibility** - Works with both PowerShell 5.1 and 7+
- **MSEndpointMgr Integration** - Uses mature, tested module for Intune Win32 app uploads
- **Template-based Metadata** - Dynamic application metadata generation for Intune packages

## Prerequisites

- **Windows PowerShell 5.1** or PowerShell 7+
- **.NET Framework 4.5+** (for WPF assemblies)
- **Administrator privileges** (for Configuration Manager features)
- **ProfileUnity Server** (for ProfileUnity integration)
- **Microsoft Configuration Manager** (optional, for CM features)
- **Azure App Registration** (for Intune integration)

## Installation

### Method 1: Direct Module Import
```powershell
# Navigate to the FUM directory
cd .\FUM

# Import the module
Import-Module .\FlexAppUpdateManager.psm1

# Launch the GUI
Show-FlexAppUpdateManager
```

### Method 2: Using the Launcher Script
```powershell
# Use the dedicated launcher script
.\Scripts\Launch-FlexAppUpdateManager.ps1
```

### Method 3: One-Line Launch
```powershell
# Single command to import and launch
Import-Module .\FlexAppUpdateManager.psm1; Show-FlexAppUpdateManager
```

## Quick Start

1. **Download/Clone** the FlexApp Update Manager to your desired location
2. **Navigate** to the FUM directory
3. **Import** the module: `Import-Module .\FlexAppUpdateManager.psm1`
4. **Launch** the GUI: `Show-FlexAppUpdateManager`
5. **Configure** your settings in the Settings tab upon first launch
6. **Select** your package source (Chocolatey, Winget, CM, ProfileUnity, or Intune)
7. **Scan** for updates and process as needed

## Usage

### Basic Workflow

#### Chocolatey/Winget Updates
1. Navigate to the Chocolatey or Winget tab
2. Load your CSV file containing package information
3. Click "Scan for Updates" to compare with FlexApp inventory
4. Review available updates in the grid
5. Select packages to update and click "Start Updates"

#### Configuration Manager Integration
1. Go to the Configuration Manager tab
2. Connect to your CM site server
3. Export applications to review
4. Edit applications as needed
5. Process selected applications for FlexApp updates

#### ProfileUnity Configuration Management
1. Access the ProfileUnity tab
2. Connect to your ProfileUnity server
3. Load configurations to scan
4. Review outdated FlexApp assignments
5. Preview and commit changes

#### Microsoft Intune Integration
1. Open the Intune tab
2. Configure Azure App Registration credentials
3. Set up source and output folders
4. Organize FlexApp packages
5. Upload Win32 applications to Intune

### Testing the Installation
```powershell
# Run basic module and GUI tests
.\Scripts\Test-FlexAppUpdateManager.ps1

# Test just the module loading
Import-Module .\FlexAppUpdateManager.psm1 -Verbose
```

## Configuration

### First-Time Setup

The application requires initial configuration for various components:

1. **ProfileUnity Connection**
   - Server name and port
   - Authentication credentials
   - FlexApp client path

2. **File Paths**
   - CSV files for Chocolatey and Winget scans
   - Default JSON configuration file
   - Output directories

3. **Configuration Manager** (if using)
   - Site server name
   - Site code
   - Connection credentials

4. **Microsoft Intune** (if using)
   - Azure App Registration details
   - Client ID, Tenant ID, and Client Secret
   - IntuneWinAppUtil.exe path
   - Source and output folder paths

### Intune Configuration Details

To use the Microsoft Intune integration:

1. **Azure App Registration**
   - Create an app registration in Azure AD
   - Grant Microsoft Graph permissions
   - Generate client secret

2. **Required Permissions**
   - `Application.ReadWrite.All`
   - `DeviceManagementApps.ReadWrite.All`

3. **IntuneWinAppUtil.exe**
   - Download from Microsoft
   - Set path in Intune settings
   - Used for Win32 app packaging

## Project Structure

```
FUM/                                       # Main application directory
├── FlexAppUpdateManager.psd1              # Module manifest (v1.2.4)
├── FlexAppUpdateManager.psm1              # Main module file (v1.5.0)
├── README.md                              # This documentation
├── Config/                                # Configuration files
│   ├── Configuration.ps1                  # Core configuration
│   ├── Initialize-Module.ps1              # Module initialization
│   ├── process-management.ps1             # Process management
│   └── Settings-Persistence.ps1           # Settings persistence
├── Functions/                             # Core functionality
│   ├── Chocolatey/                        # Chocolatey functions
│   │   ├── Complete-ChocoJobMonitoring.ps1
│   │   ├── Get-ChocolateyPackageVersion.ps1
│   │   ├── Get-ProfileUnityFlexApps.ps1
│   │   └── Start-ChocoJobMonitoring.ps1
│   ├── ConfigurationManager/              # Configuration Manager functions
│   │   ├── Compare-ApplicationVersions.ps1
│   │   ├── Connect-ConfigurationManager.ps1
│   │   ├── Get-CMApplicationList.ps1
│   │   ├── Get-FlexAppInventoryForCM.ps1
│   │   ├── Process-SelectedApplications.ps1
│   │   └── Show-EditApplicationsDialog.ps1
│   ├── Intune/                            # Microsoft Intune functions
│   │   ├── Add-IntuneApplicationMSEndpointMgr.ps1
│   │   ├── Connect-IntuneGraph.ps1
│   │   ├── New-IntunePackage.ps1
│   │   ├── Organize-FlexAppPackages.ps1
│   │   └── Start-IntuneUpload.ps1
│   ├── ProfileUnity/                      # ProfileUnity functions
│   │   ├── Get-ProfileUnityConfiguration.ps1
│   │   ├── Get-ProfileUnityConfigurations.ps1
│   │   ├── Get-ProfileUnityFilterNameById.ps1
│   │   ├── Get-ProfileUnityFilters.ps1
│   │   ├── ProfileUnity-Connection.ps1
│   │   ├── ProfileUnity-Globals.ps1
│   │   └── ProfileUnity-Module.ps1
│   ├── Shared/                            # Shared utilities
│   │   ├── Get-SecureCredentials.ps1
│   │   ├── Initialize-SSLPolicy.ps1
│   │   ├── Start-PackageUpdate.ps1
│   │   └── Write-LogMessage.ps1
│   ├── Winget/                            # Winget functions
│   │   ├── Complete-WingetJobMonitoring.ps1
│   │   ├── Get-WingetPackageVersion.ps1
│   │   └── Start-WingetJobMonitoring.ps1
│   └── WPF/                               # WPF-specific functions
│       ├── Connect-WPFConfigurationManager.ps1
│       ├── Connect-WPFProfileUnityServer.ps1
│       ├── Disconnect-WPFConfigurationManager.ps1
│       ├── Disconnect-WPFProfileUnityServer.ps1
│       ├── Get-WPFChocoUpdateCandidates.ps1
│       ├── Get-WPFWingetUpdateCandidates.ps1
│       ├── Import-WPFProfileUnityConfigurations.ps1
│       ├── Initialize-WPFPackageSources.ps1
│       ├── Load-WPFIntuneSettings.ps1
│       ├── New-WPFApplicationEditModel.ps1
│       ├── Process-WPFSelectedApplications.ps1
│       ├── Save-WPFGlobalSettings.ps1
│       ├── Save-WPFIntuneSettings.ps1
│       ├── Set-WPFChocoEventHandlers.ps1
│       ├── Set-WPFCMEventHandlers.ps1
│       ├── Set-WPFProfileUnityEventHandlers.ps1
│       ├── Set-WPFWingetEventHandlers.ps1
│       ├── Show-WPFEditApplicationsDialog.ps1
│       ├── Show-WPFPreviewDialog.ps1
│       ├── Start-WPFChocoUpdateScan.ps1
│       ├── Start-WPFCMPackageUpdate.ps1
│       ├── Start-WPFIntuneUpload.ps1
│       ├── Start-WPFPackageUpdate.ps1
│       ├── Start-WPFProfileUnityCommit.ps1
│       ├── Start-WPFProfileUnitySave.ps1
│       ├── Start-WPFProfileUnityScan.ps1
│       ├── Start-WPFWingetUpdateScan.ps1
│       ├── Stop-WPFAllProcesses.ps1
│       ├── Stop-WPFIntuneUpload.ps1
│       ├── Switch-WPFTheme.ps1
│       ├── Test-WPFGlobalSettings.ps1
│       ├── Test-WPFIntuneConnection.ps1
│       ├── Update-WPFChocoButtonStates.ps1
│       ├── Update-WPFCMButtonStates.ps1
│       ├── Update-WPFProfileUnityButtonStates.ps1
│       └── Update-WPFWingetButtonStates.ps1
├── GUI/                                   # WPF interface files
│   ├── EditApplicationsDialog.xaml        # Edit dialog
│   ├── MainWindow.xaml                    # Main UI layout
│   └── Show-FlexAppUpdateManager.ps1      # Main window function
├── Scripts/                               # Utility scripts
│   ├── Deploy-FlexAppUpdateManager.ps1    # Deployment script
│   ├── Launch-FlexAppUpdateManager.ps1    # Main launcher
│   ├── Test-FlexAppUpdateManager-System.ps1 # System test
│   ├── Test-FlexAppUpdateManager.ps1      # Basic test
│   ├── Test-IntuneUpload-MSEndpointMgr.ps1 # Intune test
│   └── Test-On-Different-System.bat       # Cross-system test
├── Intune/                                # Intune utilities
│   └── IntuneWinAppUtil.exe              # Microsoft Intune Win32 app packaging tool
├── Docs/                                  # Documentation
│   ├── README-WPF.md                      # WPF-specific documentation
│   ├── README.md                          # Main documentation
│   └── WPF-IMPLEMENTATION-SUMMARY.md      # Technical implementation details
└── PreReqs/                               # Prerequisites
    └── Winget/                            # Winget installation helpers
        └── [winget installer files]
```

## Version History

### v1.5.0 (Current) - Microsoft Intune Integration
- **NEW: Microsoft Intune Integration** - Complete Intune Win32 app upload functionality
- **NEW: MSEndpointMgr Module Integration** - Uses mature, tested module for reliable Intune uploads
- **NEW: Intune Tab** - Dedicated WPF interface for Intune configuration and management
- **NEW: Azure App Registration Support** - Secure credential management for Microsoft Graph API
- **NEW: Template-based Metadata** - Dynamic application metadata generation for Intune packages
- **NEW: Intune Connection Testing** - Built-in connectivity testing for Azure/Intune services
- **NEW: Intune Settings Persistence** - Automatic saving of Intune configuration and credentials
- **NEW: IntuneWinAppUtil Integration** - Seamless integration with Microsoft's packaging tool
- **NEW: Background Intune Uploads** - Non-blocking upload operations with progress monitoring
- **Enhanced: WPF Interface** - Added Intune tab with comprehensive configuration options
- **Enhanced: Error Handling** - Improved error handling for Intune operations
- **Enhanced: Logging** - Enhanced logging for Intune operations and troubleshooting

### v1.2.4 - Enhanced Stability and Performance
- Improved error handling across all modules
- Enhanced SSL/TLS support with intelligent fallback
- Better progress indicators and status updates
- ProfileUnity Configuration Management improvements
- Performance optimizations for large package lists
- More robust connection handling
- Clearer error messages for troubleshooting

### v1.2.0 - ProfileUnity Configuration Management
- Added ProfileUnity Configuration tab for managing FlexApp assignments
- Scan ProfileUnity configurations for outdated FlexApp versions
- Preview changes before committing
- Bulk update FlexApp assignments to latest versions
- Optional automatic deployment after save
- Maintains filter assignments during updates
- Comprehensive logging of all configuration changes

### v1.1.0 - Major Enhancements
- Added Winget support for package updates
- Enhanced handling of null/empty versions in FlexApp inventory
- Support for creating new packages when not in inventory
- Improved SSL/TLS security (TLS 1.2/1.3 support)
- Fixed exact package matching (no wildcards)
- Better error handling and logging
- Centralized settings management

### v1.0.4 - Centralized Settings
- New Settings tab for global configuration
- Removed redundant fields across tabs
- Enhanced user experience
- Improved settings persistence

### v1.0.1 - Stable Release
- Fixed GUI launch issues
- Fixed job file persistence during theme switching
- Fixed Configuration Manager settings persistence
- Fixed SSL certificate handling for ProfileUnity connections
- Cleaned up codebase
- Improved PowerShell 5.x compatibility

### v1.0.0 - Initial Release
- Initial release with WPF interface
- Basic Chocolatey and Configuration Manager support

## Troubleshooting

### Common Issues

#### Module Import Errors
```powershell
# Make sure you're in the FUM directory
Get-Location

# Check if the module file exists
Test-Path .\FlexAppUpdateManager.psm1

# Try importing with verbose output to see what's failing
Import-Module .\FlexAppUpdateManager.psm1 -Verbose
```

#### GUI Won't Launch
```powershell
# Run the test script to check all components
.\Scripts\Test-FlexAppUpdateManager.ps1

# Check if the main function is available
Get-Command Show-FlexAppUpdateManager
```

#### ProfileUnity Connection Issues
```powershell
# Test SSL connectivity
Test-NetConnection -ComputerName "your-server" -Port 8000

# Check SSL policy initialization
Initialize-SSLPolicy
```

#### Permission Issues
- Ensure PowerShell is running as Administrator (required for CM features)
- Check file permissions on the FUM directory
- Verify network connectivity to ProfileUnity server

#### Theme/Settings Not Persisting
- Settings are saved to: `$env:APPDATA\LiquidwareSparks\FlexAppUpdateManager\config.json`
- Check if this directory is writable
- Theme switching automatically saves job file paths and CM settings

#### Intune Connection Issues
- Verify Azure App Registration permissions
- Check Client ID, Tenant ID, and Client Secret
- Ensure IntuneWinAppUtil.exe is accessible
- Test connection using the built-in connection test

### Logging and Debugging

The application provides comprehensive logging:
- Console output with color-coded messages
- File-based logging with configurable levels
- Error tracking and debugging information
- Verbose mode for detailed troubleshooting

## Support

### Documentation
- [Main Documentation](Docs/README.md) - Comprehensive guide
- [WPF Implementation](Docs/README-WPF.md) - WPF-specific details
- [Implementation Summary](Docs/WPF-IMPLEMENTATION-SUMMARY.md) - Technical details

### Getting Help
For issues and questions:
1. Check the troubleshooting section above
2. Review the logging output
3. Run the test script to verify functionality
4. Check the implementation summary for technical details
5. Review the version history for known issues and fixes

### Testing
```powershell
# Run comprehensive system tests
.\Scripts\Test-FlexAppUpdateManager-System.ps1

# Test Intune functionality specifically
.\Scripts\Test-IntuneUpload-MSEndpointMgr.ps1

# Test on different systems
.\Scripts\Test-On-Different-System.bat
```

## License

This project is part of the FlexApp Update Manager suite.

## Memorial

This release is dedicated to the memory of Andreas Van Wingerden, who contributed to the FlexApp ecosystem and the broader IT community. His dedication to innovation and excellence continues to inspire the development of tools that make IT professionals' lives easier and more efficient.

*In loving memory of Andreas Van Wingerden.*

---

**FlexApp Update Manager v1.5.0**  
*Comprehensive package management for enterprise environments*