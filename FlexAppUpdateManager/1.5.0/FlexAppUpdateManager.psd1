# File: FlexAppUpdateManager.psd1
# Module Manifest for FlexApp Update Manager
# Version: 1.2.2
# ================================

@{
    # Module metadata
    RootModule = 'FlexAppUpdateManager.psm1'
    ModuleVersion = '1.2.4'
    GUID = 'a1b2c3d4-e5f6-7890-1234-567890abcdef'
    
    Author = 'Administrator'
    CompanyName = 'Your Company'
    Copyright = '(c) 2025 Your Company. All rights reserved.'
    Description = 'FlexApp Update Manager with Chocolatey, Winget, Configuration Manager, and ProfileUnity Configuration Management'
    
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
            ModuleVersion = '1.2.4'
            Description = 'FlexApp Update Manager with comprehensive package and configuration management'
            Tags = @('FlexApp', 'Chocolatey', 'Winget', 'ConfigurationManager', 'ProfileUnity', 'GUI', 'PackageManagement')
            ReleaseNotes = @'
Version 1.2.4 - Enhanced Stability and Performance
- Improved error handling across all modules
- Enhanced SSL/TLS support with intelligent fallback
- Better progress indicators and status updates
- ProfileUnity Configuration Management improvements
- Performance optimizations for large package lists
- More robust connection handling
- Clearer error messages for troubleshooting

Version 1.2.0 - ProfileUnity Configuration Management
- Added ProfileUnity Configuration tab for managing FlexApp assignments
- Scan ProfileUnity configurations for outdated FlexApp versions
- Preview changes before committing
- Bulk update FlexApp assignments to latest versions
- Optional automatic deployment after save
- Maintains filter assignments during updates
- Comprehensive logging of all configuration changes

Version 1.1.0 - Major Enhancements
- Added Winget support for package updates
- Enhanced handling of null/empty versions in FlexApp inventory
- Support for creating new packages when not in inventory
- Improved SSL/TLS security (TLS 1.2/1.3 support)
- Fixed exact package matching (no wildcards)
- Better error handling and logging
- Centralized settings management

Version 1.0.4 - Centralized Settings
- New Settings tab for global configuration
- Removed redundant fields across tabs
- Enhanced user experience
- Improved settings persistence
'@
        }
    }
}