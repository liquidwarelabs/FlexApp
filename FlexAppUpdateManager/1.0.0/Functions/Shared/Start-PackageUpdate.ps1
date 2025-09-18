# File: Functions\Shared\Start-PackageUpdate.ps1
# ================================

function Start-PackageUpdate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$UpdatePackages,
        
        [Parameter(Mandatory)]
        [string]$DefaultFile,
        
        [string]$Server = $null,
        
        [string]$SourceTab = "General",
        
        [string]$TempJsonPath = $null  # Add this parameter
    )
    
    try {
        Write-LogMessage "Starting package update for $($UpdatePackages.Count) packages..." -Level Info -Tab $SourceTab
        
        # Check if there are update packages to process
        if ($UpdatePackages.Count -eq 0) {
            throw "No update packages provided"
        }
        
        # Use provided temp file path or create a new one
        if ([string]::IsNullOrWhiteSpace($TempJsonPath)) {
            $tempJsonFile = Join-Path $script:Config.TempPath "PackageTemp_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            
            # FIXED: Ensure the JSON is always an array, even for single items
            if ($UpdatePackages.Count -eq 1) {
                # For single item, explicitly create array format
                $jsonContent = ConvertTo-Json @($UpdatePackages) -Depth 10
            } else {
                # For multiple items, ConvertTo-Json handles it correctly
                $jsonContent = ConvertTo-Json $UpdatePackages -Depth 10
            }
            
            # Write the JSON content to file
            $jsonContent | Out-File -FilePath $tempJsonFile -Encoding ASCII
            
            Write-LogMessage "Created temporary package file: $tempJsonFile" -Level Info -Tab $SourceTab
            
            # Debug: Log first few lines of the JSON to verify format
            $jsonPreview = (Get-Content $tempJsonFile -TotalCount 3) -join " "
            Write-LogMessage "JSON Preview: $jsonPreview..." -Level Info -Tab $SourceTab
        } else {
            $tempJsonFile = $TempJsonPath
            Write-LogMessage "Using existing temporary package file: $tempJsonFile" -Level Info -Tab $SourceTab
        }
        
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
        
        # Create script block for background job
        $scriptBlock = {
            param($FlexAppClient, $Arguments, $TempFile, $SourceTab)
            
            $startTime = Get-Date
            
            try {
                # Start process in new console window
                $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
                $processStartInfo.FileName = $FlexAppClient
                $processStartInfo.Arguments = $Arguments
                $processStartInfo.UseShellExecute = $true
                $processStartInfo.CreateNoWindow = $false
                $processStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
                
                $process = New-Object System.Diagnostics.Process
                $process.StartInfo = $processStartInfo
                
                if (-not $process.Start()) {
                    throw "Failed to start FlexApp client process"
                }
                
                Write-Output "Process started with PID: $($process.Id) in new console window"
                
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
        
        # Start background job
        $backgroundJob = Start-Job -ScriptBlock $scriptBlock -ArgumentList $script:Config.FlexAppClient, $argumentString, $tempJsonFile, $SourceTab
        
        if ($backgroundJob) {
            Write-LogMessage "Background job started with ID: $($backgroundJob.Id)" -Level Success -Tab $SourceTab
            Write-LogMessage "FlexApp primary-client.exe will open in a new console window" -Level Info -Tab $SourceTab
            
            # Store job reference based on source tab
            if ($SourceTab -eq "Chocolatey") {
                $script:ChocoBackgroundJob = $backgroundJob
                Start-ChocoJobMonitoring
            }
            elseif ($SourceTab -eq "Winget") {
                $script:WingetBackgroundJob = $backgroundJob
                Start-WingetJobMonitoring
            }
            
            # For CM tab, we'll wait synchronously for now
            if ($SourceTab -eq "Configuration Manager") {
                $job = Wait-Job -Job $backgroundJob
                $result = Receive-Job -Job $job
                Remove-Job -Job $job -Force
                
                if ($result.Success) {
                    $formattedTime = "{0:mm\:ss}" -f $result.Duration
                    Write-LogMessage "FlexApp package creation completed successfully (Duration: $formattedTime)" -Level Success -Tab $SourceTab
                    
                    [System.Windows.Forms.MessageBox]::Show(
                        "FlexApp package creation completed successfully!`n`nDuration: $formattedTime`nExit Code: $($result.ExitCode)", 
                        "Process Complete", 
                        "OK", 
                        "Information"
                    )
                } else {
                    Write-LogMessage "FlexApp package creation failed: $($result.Error)" -Level Error -Tab $SourceTab
                    [System.Windows.Forms.MessageBox]::Show(
                        "FlexApp package creation failed:`n`n$($result.Error)", 
                        "Process Error", 
                        "OK", 
                        "Error"
                    )
                }
                
                # Cleanup temp file - only if we created it
                if ([string]::IsNullOrWhiteSpace($TempJsonPath) -and (Test-Path $result.TempFile)) {
                    Remove-Item -Path $result.TempFile -Force -ErrorAction SilentlyContinue
                    Write-LogMessage "Cleaned up temporary file: $($result.TempFile)" -Level Info -Tab $SourceTab
                }
            }
        } else {
            throw "Failed to start background job"
        }
    }
    catch {
        Write-LogMessage "Failed to start package update: $($_.Exception.Message)" -Level Error -Tab $SourceTab
        
        # Show error dialog
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to start package update:`n`n$($_.Exception.Message)", 
            "Package Update Error", 
            "OK", 
            "Error"
        )
        
        throw
    }
}