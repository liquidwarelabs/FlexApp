# File: FlexAppUpdateManager.psd1
# Module Manifest for FlexApp Update Manager
# Version: 1.0.0
# ================================

@{
    # Module metadata
    RootModule = 'FlexAppUpdateManager.psm1'
    ModuleVersion = '1.0.0'
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
            ModuleVersion = '1.0.0'
            Description = 'FlexApp Update Manager with comprehensive package and configuration management'
            Tags = @('FlexApp', 'Chocolatey', 'Winget', 'ConfigurationManager', 'ProfileUnity', 'GUI', 'PackageManagement')
            ReleaseNotes = @'
Version 1.0.0 - Initial Release
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
'@
        }
    }
}