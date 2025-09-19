# Functions/Console/Toggle-Console.ps1
# ========================================
# Function to toggle the PowerShell console window visibility

function Toggle-Console {
    [CmdletBinding()]
    param()
    
    try {
        # Win32 type is already defined by the module
        
        $consoleWindow = [ConsoleWin32]::GetConsoleWindow()
        if ($consoleWindow -ne [IntPtr]::Zero) {
            # Check if console debug is enabled in settings to determine current state
            if ($script:Config -and $script:Config.ConsoleDebug -eq $true) {
                # Currently visible, so hide it - use aggressive hiding
                [ConsoleWin32]::ShowWindow($consoleWindow, [ConsoleWin32]::SW_HIDE) | Out-Null
                [ConsoleWin32]::SetWindowPos($consoleWindow, [IntPtr]::Zero, 0, 0, 0, 0, [ConsoleWin32]::SWP_HIDEWINDOW -bor [ConsoleWin32]::SWP_NOSIZE -bor [ConsoleWin32]::SWP_NOMOVE -bor [ConsoleWin32]::SWP_NOZORDER) | Out-Null
                Write-LogMessage "Console window hidden" -Level Info
                return "Hidden"
            } else {
                # Currently hidden, so show it - use aggressive showing
                [ConsoleWin32]::SetWindowPos($consoleWindow, [IntPtr]::Zero, 0, 0, 0, 0, [ConsoleWin32]::SWP_SHOWWINDOW -bor [ConsoleWin32]::SWP_NOSIZE -bor [ConsoleWin32]::SWP_NOMOVE -bor [ConsoleWin32]::SWP_NOZORDER) | Out-Null
                [ConsoleWin32]::ShowWindow($consoleWindow, [ConsoleWin32]::SW_RESTORE) | Out-Null
                [ConsoleWin32]::ShowWindow($consoleWindow, [ConsoleWin32]::SW_SHOW) | Out-Null
                Write-LogMessage "Console window shown for debug information" -Level Info
                return "Visible"
            }
        } else {
            Write-LogMessage "Could not find console window" -Level Warning
            return "Error"
        }
    }
    catch {
        Write-LogMessage "Error toggling console window: $($_.Exception.Message)" -Level Error
        return "Error"
    }
}
