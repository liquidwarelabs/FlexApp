# Functions/Console/Show-Console-Simple.ps1
# ========================================
# Simple function to show the PowerShell console window

function Show-Console-Simple {
    [CmdletBinding()]
    param()
    
    try {
        # Check if Win32 type is already defined
        if (-not ([System.Management.Automation.PSTypeName]'Win32').Type) {
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
"@
        }
        
        $consoleWindow = [Win32]::GetConsoleWindow()
        if ($consoleWindow -ne [IntPtr]::Zero) {
            [Win32]::ShowWindow($consoleWindow, [Win32]::SW_SHOW)
            Write-Host "Console window shown for debug information" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Could not find console window" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "Error showing console window: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

