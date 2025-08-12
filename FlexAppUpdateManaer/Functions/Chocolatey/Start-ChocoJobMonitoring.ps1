# File: Functions\Chocolatey\Start-ChocoJobMonitoring.ps1
# ================================

function Start-ChocoJobMonitoring {
    [CmdletBinding()]
    param()
    
    # Use WPF DispatcherTimer instead of WinForms Timer to prevent UI lockups
    $script:ChocoJobTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:ChocoJobTimer.Interval = [TimeSpan]::FromMilliseconds(1000)
    $script:ChocoJobTimer.Add_Tick({
        try {
            if ($script:ChocoBackgroundJob) {
                $jobState = $script:ChocoBackgroundJob.State
                
                if ($jobState -eq "Running") {
                    $runningTime = (Get-Date) - $script:ChocoBackgroundJob.PSBeginTime
                    $formattedTime = "{0:mm\:ss}" -f $runningTime
                    Update-WPFChocoStatus -Message "FlexApp client is processing packages... (Running for $formattedTime)" -Level Info
                    # No need for DoEvents() with WPF DispatcherTimer
                }
                elseif ($jobState -eq "Completed") {
                    Complete-ChocoJobMonitoring
                }
                elseif ($jobState -eq "Failed") {
                    Complete-ChocoJobMonitoring
                }
                elseif ($jobState -eq "Stopped") {
                    Complete-ChocoJobMonitoring
                }
            } else {
                Complete-ChocoJobMonitoring
            }
        }
        catch {
            Write-LogMessage "Error monitoring Chocolatey job: $($_.Exception.Message)" -Level Error -Tab "Chocolatey"
            Complete-ChocoJobMonitoring
        }
    })
    
    $script:ChocoJobTimer.Start()
    Write-LogMessage "Chocolatey job monitoring started with WPF timer" -Level Info -Tab "Chocolatey"
}
