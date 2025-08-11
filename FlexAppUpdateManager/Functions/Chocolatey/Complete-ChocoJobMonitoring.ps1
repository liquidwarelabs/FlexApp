# File: Functions\Chocolatey\Complete-ChocoJobMonitoring.ps1
# ================================

function Complete-ChocoJobMonitoring {
    [CmdletBinding()]
    param()
    
    try {
        if ($script:ChocoJobTimer) {
            $script:ChocoJobTimer.Stop()
            $script:ChocoJobTimer.Dispose()
            $script:ChocoJobTimer = $null
        }
        
        if ($script:ChocoBackgroundJob) {
            $jobState = $script:ChocoBackgroundJob.State
            
            if ($jobState -eq "Completed") {
                $result = Receive-Job -Job $script:ChocoBackgroundJob
                
                if ($result -and $result.Success) {
                    $formattedTime = "{0:mm\:ss}" -f $result.Duration
                    Write-LogMessage "FlexApp package creation completed successfully (Duration: $formattedTime)" -Level Success -Tab "Chocolatey"
                    Update-ChocoStatus -Message "FlexApp package creation completed successfully!" -Level Success
                    
                    [System.Windows.Forms.MessageBox]::Show(
                        "FlexApp package creation completed successfully!`n`nDuration: $formattedTime`nExit Code: $($result.ExitCode)", 
                        "Process Complete", 
                        "OK", 
                        "Information"
                    )
                } else {
                    $errorMsg = if ($result.Error) { $result.Error } else { "Unknown error occurred" }
                    Write-LogMessage "FlexApp package creation failed: $errorMsg" -Level Error -Tab "Chocolatey"
                    Update-ChocoStatus -Message "FlexApp package creation failed" -Level Error
                    
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
            
            Remove-Job -Job $script:ChocoBackgroundJob -Force -ErrorAction SilentlyContinue
            $script:ChocoBackgroundJob = $null
        }
        
        Set-ChocoButtonStates -Processing $false
        
        # IMPORTANT: Don't automatically start a new scan if cancellation is in progress
        if (-not $script:ChocoCancelInProgress -and -not $script:ChocoScanCancelled) {
            Start-ChocoUpdateScan
        } else {
            Write-LogMessage "Skipping automatic rescan due to cancellation" -Level Info -Tab "Chocolatey"
            # Reset the status to ready
            Update-ChocoStatus -Message "Ready - Click 'Scan for Updates' to begin" -Level Info
        }
    }
    catch {
        Write-LogMessage "Error completing job monitoring: $($_.Exception.Message)" -Level Error -Tab "Chocolatey"
        Set-ChocoButtonStates -Processing $false
    }
}