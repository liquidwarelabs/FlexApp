# FlexApp Update Manager

A modern PowerShell-based application for managing package updates across multiple platforms including Chocolatey, Winget, Configuration Manager, and ProfileUnity.

## 🚀 Quick Start

```powershell
# Clone the repository
git clone https://github.com/yourusername/FlexAppUpdateManager.git
cd FlexAppUpdateManager

# Launch the application
.\Launch.ps1
```

## 📋 Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+
- .NET Framework 4.5+ (for WPF assemblies)
- Administrator privileges (for Configuration Manager features)

## 🎯 Features

- **Chocolatey Updates** - Scan and update Chocolatey packages
- **Winget Updates** - Manage Windows Package Manager updates  
- **Configuration Manager** - Integration with Microsoft Configuration Manager
- **ProfileUnity** - FlexApp configuration management
- **Modern WPF Interface** - Material Design with responsive layout
- **Centralized Settings** - Unified configuration management
- **Comprehensive Logging** - Full logging and error tracking

## 📁 Project Structure

```
FlexAppUpdateManager/
├── FlexAppUpdateManager.psd1              # Module manifest
├── FlexAppUpdateManager.psm1              # Main module file
├── Launch.ps1                             # Simple launcher (this file)
├── README.md                              # This documentation
├── Config/                                # Configuration files
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
```

## 🔧 Usage

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
.\Launch.ps1

# Or use the full launcher
.\Scripts\Launch-FlexAppUpdateManager.ps1
```

### Testing
```powershell
# Run basic tests
.\Scripts\Test-FlexAppUpdateManager.ps1
```

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

## 📄 License

This project is part of the FlexApp Update Manager suite.

## 📈 Version History

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
