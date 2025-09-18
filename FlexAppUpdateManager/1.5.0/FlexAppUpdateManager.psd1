# File: FlexAppUpdateManager.psd1
# Module Manifest for FlexApp Update Manager
# Version: 1.5.0
# ================================

@{
    # Module metadata
    RootModule = 'FlexAppUpdateManager.psm1'
    ModuleVersion = '1.5.0'
    GUID = 'a1b2c3d4-e5f6-7890-1234-567890abcdef'
    
    Author = 'Administrator'
    CompanyName = 'Your Company'
    Copyright = '(c) 2025 Your Company. All rights reserved.'
    Description = 'FlexApp Update Manager with Chocolatey, Winget, Configuration Manager, ProfileUnity, and Microsoft Intune Configuration Management'
    
    # Minimum PowerShell version
    PowerShellVersion = '5.1'
    
    # Required modules
    RequiredModules = @()
    
    # Required assemblies
    RequiredAssemblies = @(
        'System.Windows.Forms',
        'System.Drawing'
    )
    
    # Functions to export
    FunctionsToExport = @(
        'Show-FlexAppUpdateManager'
    )
    
    # Cmdlets to export
    CmdletsToExport = @()
    
    # Variables to export
    VariablesToExport = @()
    
    # Aliases to export
    AliasesToExport = @()
    
    # Private data
    PrivateData = @{
        PSData = @{
            ModuleVersion = '1.5.0'
            Description = 'FlexApp Update Manager with comprehensive package and configuration management including Microsoft Intune integration'
            Tags = @('FlexApp', 'Chocolatey', 'Winget', 'ConfigurationManager', 'ProfileUnity', 'Intune', 'GUI', 'PackageManagement')
            ReleaseNotes = @'
Version 1.5.0 - Microsoft Intune Integration Release
- NEW: Microsoft Intune Win32 app upload functionality
- NEW: MSEndpointMgr module integration for reliable Intune uploads
- NEW: Dedicated Intune tab in WPF interface
- NEW: Azure App Registration support with secure credential management
- NEW: Template-based metadata generation for Intune packages
- NEW: Intune connection testing and validation
- NEW: IntuneWinAppUtil.exe integration for app packaging
- NEW: Background Intune upload operations with progress monitoring
- Enhanced: Improved error handling for Intune operations
- Enhanced: Comprehensive logging for Intune troubleshooting
- Enhanced: Settings persistence for Intune configuration
- Modern WPF-based user interface with Material Design
- Chocolatey package management and updates
- Winget package management and updates
- Configuration Manager integration
- ProfileUnity configuration management
- Centralized settings management
- Comprehensive logging system
- Background processing with progress tracking
- Multi-tab interface for different management tasks
- SSL/TLS security support
- Cross-platform PowerShell compatibility (5.1+)

Memorial:
This release is dedicated to the memory of Andreas Van Wingerden, who contributed to the FlexApp ecosystem and the broader IT community. His dedication to innovation and excellence continues to inspire the development of tools that make IT professionals' lives easier and more efficient.

In loving memory of Andreas Van Wingerden.
'@
        }
    }
}