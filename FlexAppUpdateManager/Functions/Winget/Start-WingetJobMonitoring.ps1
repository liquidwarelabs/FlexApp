# File: Functions\Winget\Start-WingetJobMonitoring.ps1
# ================================

function Start-WingetJobMonitoring {
    [CmdletBinding()]
    param()
    
    $script:WingetJobTimer = New-Object System.Windows.Forms.Timer
    $script:WingetJobTimer.Interval = 1000
    $script:WingetJobTimer.Add_Tick({
        try {
            if ($script:WingetBackgroundJob) {
                $jobState = $script:WingetBackgroundJob.State
                
                if ($jobState -eq "Running") {
                    $runningTime = (Get-Date) - $script:WingetBackgroundJob.PSBeginTime
                    $formattedTime = "{0:mm\:ss}" -f $runningTime
                    Update-WingetStatus -Message "FlexApp client is processing packages... (Running for $formattedTime)" -Level Info
                    [System.Windows.Forms.Application]::DoEvents()
                }
                elseif ($jobState -eq "Completed") {
                    Complete-WingetJobMonitoring
                }
                elseif ($jobState -eq "Failed") {
                    Complete-WingetJobMonitoring
                }
                elseif ($jobState -eq "Stopped") {
                    Complete-WingetJobMonitoring
                }
            } else {
                Complete-WingetJobMonitoring
            }
        }
        catch {
            Write-LogMessage "Error monitoring job: $($_.Exception.Message)" -Level Error -Tab "Winget"
            Complete-WingetJobMonitoring
        }
    })
    
    $script:WingetJobTimer.Start()
}