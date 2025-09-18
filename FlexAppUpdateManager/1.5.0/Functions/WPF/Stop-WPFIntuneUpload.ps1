# Functions/WPF/Stop-WPFIntuneUpload.ps1
# WPF function to stop Intune upload process

function Stop-WPFIntuneUpload {
    [CmdletBinding()]
    param()

    try {
        # Get UI controls
        $startButton = Find-Control -ControlName "IntuneStartUploadButton"
        $stopButton = Find-Control -ControlName "IntuneStopUploadButton"
        $progressBar = Find-Control -ControlName "IntuneProgressBar"
        $statusText = Find-Control -ControlName "IntuneStatusTextBlock"

        # Stop the upload job if it's running
        if ($script:IntuneUploadJob -and $script:IntuneUploadJob.State -eq "Running") {
            Stop-Job -Job $script:IntuneUploadJob
            Remove-Job -Job $script:IntuneUploadJob -Force
            Write-LogMessage "Stopped Intune upload job" -Level Info -Tab "Intune"
        }

        # Stop the timer if it's running
        if ($script:IntuneUploadTimer) {
            $script:IntuneUploadTimer.Stop()
            $script:IntuneUploadTimer = $null
        }

        # Update UI state
        $startButton.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Normal, [System.Action]{
            $startButton.IsEnabled = $true
            $stopButton.IsEnabled = $false
            $progressBar.Visibility = "Collapsed"
        })

        $statusText.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Normal, [System.Action]{
            $statusText.Text = "Upload stopped"
        })

        Write-LogMessage "Intune upload process stopped" -Level Info -Tab "Intune"
    }
    catch {
        Write-LogMessage "Error stopping Intune upload: $($_.Exception.Message)" -Level Error -Tab "Intune"
    }
}
