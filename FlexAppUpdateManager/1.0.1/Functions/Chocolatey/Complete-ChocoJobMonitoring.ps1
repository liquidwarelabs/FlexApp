# File: Functions\Chocolatey\Complete-ChocoJobMonitoring.ps1
# ================================

function Complete-ChocoJobMonitoring {
    [CmdletBinding()]
    param()
    
    try {
        if ($script:ChocoJobTimer) {
            $script:ChocoJobTimer.Stop()
            # DispatcherTimer doesn't have Dispose() method, just stop it
            $script:ChocoJobTimer = $null
        }
        
        if ($script:ChocoBackgroundJob) {
            $jobState = $script:ChocoBackgroundJob.State
            
            if ($jobState -eq "Completed") {
                $result = Receive-Job -Job $script:ChocoBackgroundJob
                
                if ($result -and $result.Success) {
                    $formattedTime = "{0:mm\:ss}" -f $result.Duration
                    Write-LogMessage "FlexApp package creation completed successfully (Duration: $formattedTime)" -Level Success -Tab "Chocolatey"
                    Update-WPFChocoStatus -Message "FlexApp package creation completed successfully!" -Level Success
                    
                    [System.Windows.Forms.MessageBox]::Show(
                        "FlexApp package creation completed successfully!`n`nDuration: $formattedTime`nExit Code: $($result.ExitCode)", 
                        "Process Complete", 
                        "OK", 
                        "Information"
                    )
                } else {
                    $errorMsg = if ($result.Error) { $result.Error } else { "Unknown error occurred" }
                    Write-LogMessage "FlexApp package creation failed: $errorMsg" -Level Error -Tab "Chocolatey"
                    Update-WPFChocoStatus -Message "FlexApp package creation failed" -Level Error
                    
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
        
        Update-WPFChocoButtonStates
        
        # IMPORTANT: Don't automatically start a new scan if cancellation is in progress
        if (-not $script:ChocoCancelInProgress -and -not $script:ChocoScanCancelled) {
            # Start-ChocoUpdateScan  # Don't auto-rescan after processing
            Write-LogMessage "Job completed - ready for new operations" -Level Info -Tab "Chocolatey"
            Update-WPFChocoStatus -Message "Ready - Click 'Scan for Updates' to begin" -Level Info
        } else {
            Write-LogMessage "Skipping automatic rescan due to cancellation" -Level Info -Tab "Chocolatey"
            # Reset the status to ready
            Update-WPFChocoStatus -Message "Ready - Click 'Scan for Updates' to begin" -Level Info
        }
    }
    catch {
        Write-LogMessage "Error completing job monitoring: $($_.Exception.Message)" -Level Error -Tab "Chocolatey"
        Update-WPFChocoButtonStates
    }
}