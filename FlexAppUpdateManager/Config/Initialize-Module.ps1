# File: Config\Initialize-Module.ps1
# ================================
# Module initialization functions

function Initialize-FlexAppModule {
    [CmdletBinding()]
    param()
    
    # Add required assemblies for GUI
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    # Load settings from file (or create defaults if no file exists)
    Load-AllSettings
    
    # Minimize PowerShell console window
    try {
        Add-Type -TypeDefinition @"
            using System;
            using System.Runtime.InteropServices;
            public class Win32 {
                [DllImport("kernel32.dll")]
                public static extern IntPtr GetConsoleWindow();
                
                [DllImport("user32.dll")]
                public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
                
                public const int SW_HIDE = 0;
                public const int SW_MINIMIZE = 6;
                public const int SW_RESTORE = 9;
            }
"@
        
        $consoleWindow = [Win32]::GetConsoleWindow()
        if ($consoleWindow -ne [IntPtr]::Zero) {
            [Win32]::ShowWindow($consoleWindow, [Win32]::SW_MINIMIZE)
            Write-Host "PowerShell console minimized - GUI will be the primary interface" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Could not minimize console window: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host "FlexApp Update Manager Module v1.0.0 Loaded" -ForegroundColor Green
    Write-Host "Features: Chocolatey Updates + Winget Updates + Configuration Manager Integration" -ForegroundColor Cyan
    Write-Host "Enhanced: Centralized settings management with Winget support" -ForegroundColor Yellow
    
    # Display loaded configuration info
    if ($script:Config) {
        Write-Host "Configuration loaded from: $(Get-ConfigPath)" -ForegroundColor Cyan
    } else {
        Write-Host "Using default configuration" -ForegroundColor Yellow
    }
}