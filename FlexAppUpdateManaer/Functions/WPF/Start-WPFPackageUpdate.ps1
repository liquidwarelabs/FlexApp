function Start-WPFPackageUpdate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$UpdatePackages,
        
        [Parameter(Mandatory=$true)]
        [string]$DefaultFile,
        
        [Parameter(Mandatory=$false)]
        [string]$Server,
        
        [Parameter(Mandatory=$true)]
        [string]$SourceTab,
        
        [Parameter(Mandatory=$false)]
        [string]$TempJsonPath
    )
    
    try {
        Write-LogMessage "Starting WPF package update for $($UpdatePackages.Count) packages..." -Level Info -Tab $SourceTab
        
        # Create temp JSON file if not provided
        $tempJsonFile = if ($TempJsonPath) {
            $TempJsonPath
        } else {
            $tempPath = Join-Path $env:temp "wpf_update_packages.json"
            $arrayForJson = @() + $UpdatePackages
            $jsonOutput = if ($arrayForJson.Count -eq 1) { 
                ConvertTo-Json -InputObject @($arrayForJson) -Depth 10 
            } else { 
                ConvertTo-Json -InputObject $arrayForJson -Depth 10 
            }
            [System.IO.File]::WriteAllText($tempPath, $jsonOutput)
            
            $jsonPreview = if ($jsonOutput.Length -gt 200) { $jsonOutput.Substring(0, 200) } else { $jsonOutput }
            Write-LogMessage "JSON Preview: $jsonPreview..." -Level Info -Tab $SourceTab
            $tempPath
        }
        
        Write-LogMessage "Using temporary package file: $tempJsonFile" -Level Info -Tab $SourceTab
        
        # Verify FlexApp client exists
        if (-not (Test-Path $script:Config.FlexAppClient)) {
            throw "FlexApp client not found: $($script:Config.FlexAppClient)"
        }
        
        # Build arguments
        $arguments = @(
            "create packages",
            "/packagesfile `"$tempJsonFile`"",
            "/DefaultsJSON `"$DefaultFile`"",
            "/WaitForDone"
        )
        
        # Add server parameter if provided (for Chocolatey/Winget tabs)
        if (![string]::IsNullOrWhiteSpace($Server)) {
            $arguments += "/PrimaryAddress $Server"
        }
        
        $argumentString = $arguments -join " "
        
        Write-LogMessage "Starting FlexApp package creation process..." -Level Info -Tab $SourceTab
        Write-LogMessage "Arguments: $argumentString" -Level Info -Tab $SourceTab
        
        # Store reference to main window for focus management
        $mainWindowHandle = $null
        try {
            if ($script:WPFMainWindow) {
                $mainWindowHandle = $script:WPFMainWindow.WindowInteropHelper_Handle
                if (-not $mainWindowHandle) {
                    # Get window handle using Windows API
                    Add-Type -AssemblyName System.Windows.Forms
                    $source = [System.Windows.Interop.WindowInteropHelper]::new($script:WPFMainWindow)
                    $mainWindowHandle = $source.Handle
                }
            }
        }
        catch {
            Write-LogMessage "Could not get main window handle for focus management: $($_.Exception.Message)" -Level Warning -Tab $SourceTab
        }
        
        # Create script block for background job with focus management
        $scriptBlock = {
            param($FlexAppClient, $Arguments, $TempFile, $SourceTab, $MainWindowHandle)
            
            $startTime = Get-Date
            
            try {
                # Add Windows API functions for focus management
                Add-Type -TypeDefinition @"
                using System;
                using System.Runtime.InteropServices;
                public class Win32 {
                    [DllImport("user32.dll")]
                    public static extern bool SetForegroundWindow(IntPtr hWnd);
                    
                    [DllImport("user32.dll")]
                    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
                    
                    [DllImport("user32.dll")]
                    public static extern IntPtr GetForegroundWindow();
                    
                    public const int SW_MINIMIZE = 6;
                    public const int SW_RESTORE = 9;
                }
"@
                
                # Start process with focus management
                $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
                $processStartInfo.FileName = $FlexAppClient
                $processStartInfo.Arguments = $Arguments
                $processStartInfo.UseShellExecute = $true
                $processStartInfo.CreateNoWindow = $false
                $processStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized  # Start minimized
                
                $process = New-Object System.Diagnostics.Process
                $process.StartInfo = $processStartInfo
                
                if (-not $process.Start()) {
                    throw "Failed to start FlexApp client process"
                }
                
                Write-Output "Process started with PID: $($process.Id) (minimized to prevent focus stealing)"
                
                # Give the process a moment to start, then restore focus to main window
                Start-Sleep -Milliseconds 500
                
                try {
                    if ($MainWindowHandle -and $MainWindowHandle -ne [IntPtr]::Zero) {
                        [Win32]::SetForegroundWindow($MainWindowHandle)
                        Write-Output "Restored focus to main application window"
                    }
                }
                catch {
                    Write-Output "Could not restore focus to main window: $($_.Exception.Message)"
                }
                
                # Wait for process to complete
                $process.WaitForExit()
                
                $endTime = Get-Date
                $duration = $endTime - $startTime
                
                return @{
                    Success = $true
                    ExitCode = $process.ExitCode
                    StartTime = $startTime
                    EndTime = $endTime
                    Duration = $duration
                    TempFile = $TempFile
                    ProcessId = $process.Id
                    SourceTab = $SourceTab
                }
            }
            catch {
                $endTime = Get-Date
                $duration = $endTime - $startTime
                
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                    FullError = $_.Exception.ToString()
                    StartTime = $startTime
                    EndTime = $endTime
                    Duration = $duration
                    TempFile = $TempFile
                    SourceTab = $SourceTab
                }
            }
        }
        
        # Start background job with focus management
        $backgroundJob = Start-Job -ScriptBlock $scriptBlock -ArgumentList $script:Config.FlexAppClient, $argumentString, $tempJsonFile, $SourceTab, $mainWindowHandle
        
        if ($backgroundJob) {
            Write-LogMessage "Background job started with ID: $($backgroundJob.Id)" -Level Success -Tab $SourceTab
            Write-LogMessage "FlexApp primary-client.exe will start minimized to prevent focus stealing" -Level Info -Tab $SourceTab
            
            # Store job reference based on source tab
            if ($SourceTab -eq "Chocolatey") {
                $script:ChocoBackgroundJob = $backgroundJob
                Start-ChocoJobMonitoring
            }
            elseif ($SourceTab -eq "Winget") {
                $script:WingetBackgroundJob = $backgroundJob
                Start-WingetJobMonitoring
            }
            elseif ($SourceTab -eq "Configuration Manager") {
                $script:CMBackgroundJob = $backgroundJob
                # Start CM job monitoring if it exists, otherwise just store the job reference
                if (Get-Command "Start-CMJobMonitoring" -ErrorAction SilentlyContinue) {
                    Start-CMJobMonitoring
                } else {
                    Write-LogMessage "CM job monitoring function not found, job will run in background" -Level Warning -Tab $SourceTab
                }
            }
            
            return $true
        } else {
            throw "Failed to start background job"
        }
    }
    catch {
        Write-LogMessage "Error starting WPF package update: $($_.Exception.Message)" -Level Error -Tab $SourceTab
        throw
    }
}



