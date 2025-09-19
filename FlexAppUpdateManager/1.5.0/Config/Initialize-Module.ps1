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
                public const int SW_SHOW = 5;
            }
            
            public class ConsoleWin32 {
                [DllImport("kernel32.dll")]
                public static extern IntPtr GetConsoleWindow();
                
                [DllImport("user32.dll")]
                public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
                
                [DllImport("user32.dll")]
                public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
                
                public const int SW_HIDE = 0;
                public const int SW_MINIMIZE = 6;
                public const int SW_RESTORE = 9;
                public const int SW_SHOW = 5;
                
                public const uint SWP_HIDEWINDOW = 0x0080;
                public const uint SWP_SHOWWINDOW = 0x0040;
                public const uint SWP_NOSIZE = 0x0001;
                public const uint SWP_NOMOVE = 0x0002;
                public const uint SWP_NOZORDER = 0x0004;
            }
"@
        
        # Initialize console debug setting if not exists
        if (-not $script:Config.PSObject.Properties.Match('ConsoleDebug')) {
            $script:Config | Add-Member -MemberType NoteProperty -Name 'ConsoleDebug' -Value $false -Force
        }
        
        $consoleWindow = [Win32]::GetConsoleWindow()
        if ($consoleWindow -ne [IntPtr]::Zero) {
            # Hide console by default unless ConsoleDebug is enabled
            if (-not $script:Config.ConsoleDebug) {
                [Win32]::ShowWindow($consoleWindow, [Win32]::SW_HIDE)
                # Don't use Write-Host here as it will show the console again
            } else {
                [Win32]::ShowWindow($consoleWindow, [Win32]::SW_SHOW)
                # Don't use Write-Host here as it will show the console again
            }
        }
    }
    catch {
        Write-Host "Could not minimize console window: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Don't use Write-Host here as it will show the console
    # Write-Host "FlexApp Update Manager Module v1.5.0 Loaded" -ForegroundColor Green
    # Write-Host "Features: Chocolatey Updates + Winget Updates + Configuration Manager Integration" -ForegroundColor Cyan
    # Write-Host "Enhanced: Centralized settings management with Winget support" -ForegroundColor Yellow
    
    # Display loaded configuration info - commented out to prevent console showing
    # if ($script:Config) {
    #     Write-Host "Configuration loaded from: $(Get-ConfigPath)" -ForegroundColor Cyan
    # } else {
    #     Write-Host "Using default configuration" -ForegroundColor Yellow
    # }
}