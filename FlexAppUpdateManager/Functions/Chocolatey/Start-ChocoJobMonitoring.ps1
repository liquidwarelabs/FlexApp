# File: Functions\Chocolatey\Start-ChocoJobMonitoring.ps1
# ================================

function Start-ChocoJobMonitoring {
    [CmdletBinding()]
    param()
    
    $script:ChocoJobTimer = New-Object System.Windows.Forms.Timer
    $script:ChocoJobTimer.Interval = 1000
    $script:ChocoJobTimer.Add_Tick({
        try {
            if ($script:ChocoBackgroundJob) {
                $jobState = $script:ChocoBackgroundJob.State
                
                if ($jobState -eq "Running") {
                    $runningTime = (Get-Date) - $script:ChocoBackgroundJob.PSBeginTime
                    $formattedTime = "{0:mm\:ss}" -f $runningTime
                    Update-ChocoStatus -Message "FlexApp client is processing packages... (Running for $formattedTime)" -Level Info
                    [System.Windows.Forms.Application]::DoEvents()
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
            Write-LogMessage "Error monitoring job: $($_.Exception.Message)" -Level Error -Tab "Chocolatey"
            Complete-ChocoJobMonitoring
        }
    })
    
    $script:ChocoJobTimer.Start()
}
