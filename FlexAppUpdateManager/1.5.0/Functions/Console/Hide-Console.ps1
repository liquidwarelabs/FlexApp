# Functions/Console/Hide-Console.ps1
# ========================================
# Function to hide the PowerShell console window

function Hide-Console {
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
            [Win32]::ShowWindow($consoleWindow, [Win32]::SW_HIDE)
            Write-LogMessage "Console window hidden" -Level Info
            return $true
        } else {
            Write-LogMessage "Could not find console window" -Level Warning
            return $false
        }
    }
    catch {
        Write-LogMessage "Error hiding console window: $($_.Exception.Message)" -Level Error
        return $false
    }
}

