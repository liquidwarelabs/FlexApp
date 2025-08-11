# File: Functions\Winget\Complete-WingetJobMonitoring.ps1
# ================================

function Complete-WingetJobMonitoring {
    [CmdletBinding()]
    param()
    
    try {
        if ($script:WingetJobTimer) {
            $script:WingetJobTimer.Stop()
            $script:WingetJobTimer.Dispose()
            $script:WingetJobTimer = $null
        }
        
        if ($script:WingetBackgroundJob) {
            $jobState = $script:WingetBackgroundJob.State
            
            if ($jobState -eq "Completed") {
                $result = Receive-Job -Job $script:WingetBackgroundJob
                
                if ($result -and $result.Success) {
                    $formattedTime = "{0:mm\:ss}" -f $result.Duration
                    Write-LogMessage "FlexApp package creation completed successfully (Duration: $formattedTime)" -Level Success -Tab "Winget"
                    Update-WingetStatus -Message "FlexApp package creation completed successfully!" -Level Success
                    
                    [System.Windows.Forms.MessageBox]::Show(
                        "FlexApp package creation completed successfully!`n`nDuration: $formattedTime`nExit Code: $($result.ExitCode)", 
                        "Process Complete", 
                        "OK", 
                        "Information"
                    )
                } else {
                    $errorMsg = if ($result.Error) { $result.Error } else { "Unknown error occurred" }
                    Write-LogMessage "FlexApp package creation failed: $errorMsg" -Level Error -Tab "Winget"
                    Update-WingetStatus -Message "FlexApp package creation failed" -Level Error
                    
                    [System.Windows.Forms.MessageBox]::Show(
                        "FlexApp package creation failed:`n`n$errorMsg", 
                        "Process Error", 
                        "OK", 
                        "Error"
                    )
                }
                
                if ($result.TempFile -and (Test-Path $result.TempFile)) {
                    Remove-Item -Path $result.TempFile -Force -ErrorAction SilentlyContinue
                }
            }
            
            Remove-Job -Job $script:WingetBackgroundJob -Force -ErrorAction SilentlyContinue
            $script:WingetBackgroundJob = $null
        }
        
        Set-WingetButtonStates -Processing $false
        
        if (-not $script:WingetCancelInProgress) {
            Start-WingetUpdateScan
        }
    }
    catch {
        Write-LogMessage "Error completing job monitoring: $($_.Exception.Message)" -Level Error -Tab "Winget"
        Set-WingetButtonStates -Processing $false
    }
}