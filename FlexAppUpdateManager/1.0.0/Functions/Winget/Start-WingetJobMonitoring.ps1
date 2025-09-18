# File: Functions\Winget\Start-WingetJobMonitoring.ps1
# ================================

function Start-WingetJobMonitoring {
    [CmdletBinding()]
    param()
    
    # Use WPF DispatcherTimer instead of WinForms Timer to prevent UI lockups
    $script:WingetJobTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:WingetJobTimer.Interval = [TimeSpan]::FromMilliseconds(1000)
    $script:WingetJobTimer.Add_Tick({
        try {
            if ($script:WingetBackgroundJob) {
                $jobState = $script:WingetBackgroundJob.State
                
                if ($jobState -eq "Running") {
                    $runningTime = (Get-Date) - $script:WingetBackgroundJob.PSBeginTime
                    $formattedTime = "{0:mm\:ss}" -f $runningTime
                    Update-WPFWingetStatus -Message "FlexApp client is processing packages... (Running for $formattedTime)" -Level Info
                    # No need for DoEvents() with WPF DispatcherTimer
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
            Write-LogMessage "Error monitoring Winget job: $($_.Exception.Message)" -Level Error -Tab "Winget"
            Complete-WingetJobMonitoring
        }
    })
    
    $script:WingetJobTimer.Start()
    Write-LogMessage "Winget job monitoring started with WPF timer" -Level Info -Tab "Winget"
}