# Functions/WPF/Test-WPFIntuneConnection.ps1
# WPF function to test Azure connection for Intune

function Test-WPFIntuneConnection {
    [CmdletBinding()]
    param()

    try {
        # Get UI controls
        $testButton = Find-Control -ControlName "IntuneTestConnectionButton"
        $statusText = Find-Control -ControlName "IntuneStatusTextBlock"
        $logTextBox = Find-Control -ControlName "IntuneLogTextBox"

        # Get configuration values
        $clientId = (Find-Control -ControlName "IntuneClientIdTextBox").Text.Trim()
        $tenantId = (Find-Control -ControlName "IntuneTenantIdTextBox").Text.Trim()
        $clientSecret = (Find-Control -ControlName "IntuneClientSecretPasswordBox").Password
        
        # Debug: Log the values (without exposing the secret)
        Write-LogMessage "Testing connection with Client ID: $clientId, Tenant ID: $tenantId, Secret length: $($clientSecret.Length)" -Level Info -Tab "Intune"

        # Validate required fields
        if (-not $clientId) {
            Write-LogMessage "Client ID is required for Intune connection test" -Level Warning -Tab "Intune"
            [System.Windows.MessageBox]::Show("Client ID is required", "Validation Error", "OK", "Warning")
            return
        }
        if (-not $tenantId) {
            Write-LogMessage "Tenant ID is required for Intune connection test" -Level Warning -Tab "Intune"
            [System.Windows.MessageBox]::Show("Tenant ID is required", "Validation Error", "OK", "Warning")
            return
        }
        if (-not $clientSecret) {
            Write-LogMessage "Client Secret is required for Intune connection test" -Level Warning -Tab "Intune"
            [System.Windows.MessageBox]::Show("Client Secret is required", "Validation Error", "OK", "Warning")
            return
        }

        Write-LogMessage "Starting Intune Azure connection test" -Level Info -Tab "Intune"

        # Update UI state
        $testButton.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Normal, [System.Action]{
            $testButton.IsEnabled = $false
            $testButton.Content = "Testing..."
        })

        $statusText.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Normal, [System.Action]{
            $statusText.Text = "Testing Azure connection..."
        })

        $logTextBox.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Normal, [System.Action]{
            $logTextBox.AppendText("[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Testing Azure connection...`r`n")
            $logTextBox.ScrollToEnd()
        })

        # Test connection in a background job
        $testJob = Start-Job -ScriptBlock {
            param($ClientId, $TenantId, $ClientSecret, $ModulePath)
            
            try {
                Write-Host "=== Intune Connection Test Started ===" -ForegroundColor Cyan
                Write-Host "Client ID: $ClientId" -ForegroundColor Yellow
                Write-Host "Tenant ID: $TenantId" -ForegroundColor Yellow
                Write-Host "Secret Length: $($ClientSecret.Length)" -ForegroundColor Yellow
                
                # Import the main module using full path
                Write-Host "Importing module from: $ModulePath" -ForegroundColor Green
                Import-Module $ModulePath -Force
                Write-Host "Module imported successfully" -ForegroundColor Green
                
                # Test the connection with verbose output
                Write-Host "Testing connection..." -ForegroundColor Green
                $VerbosePreference = "Continue"
                $result = Connect-IntuneGraph -ClientId $ClientId -TenantId $TenantId -ClientSecret $ClientSecret -Verbose
                
                Write-Host "Connection test result: $result" -ForegroundColor $(if($result) {"Green"} else {"Red"})
                Write-Host "=== Intune Connection Test Completed ===" -ForegroundColor Cyan
                
                return $result
            }
            catch {
                Write-Host "=== Intune Connection Test FAILED ===" -ForegroundColor Red
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
                return $false
            }
        } -ArgumentList $clientId, $tenantId, $clientSecret, (Get-Module FlexAppUpdateManager).Path

        # Wait for job completion with timeout
        $timeout = 30 # seconds
        $elapsed = 0
        while ($testJob.State -eq "Running" -and $elapsed -lt $timeout) {
            Start-Sleep -Seconds 1
            $elapsed++
        }

        Write-LogMessage "Job state: $($testJob.State)" -Level Info -Tab "Intune"
        
        if ($testJob.State -eq "Completed") {
            $result = Receive-Job -Job $testJob
            Remove-Job -Job $testJob
            Write-LogMessage "Job completed with result: $result" -Level Info -Tab "Intune"

            if ($result) {
                # Store successful authentication for reuse in upload
                $global:IntuneAuthenticationValid = $true
                $global:IntuneAuthenticationTime = Get-Date
                $global:IntuneClientId = $clientId
                $global:IntuneTenantId = $tenantId
                $global:IntuneClientSecret = $clientSecret
                
                $statusText.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Normal, [System.Action]{
                    $statusText.Text = "Azure connection successful"
                })

                $logTextBox.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Normal, [System.Action]{
                    $logTextBox.AppendText("[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Azure connection successful`r`n")
                    $logTextBox.ScrollToEnd()
                })

                [System.Windows.MessageBox]::Show("Azure connection test successful!", "Connection Test", "OK", "Information")
                Write-LogMessage "Azure connection test successful" -Level Success -Tab "Intune"
            } else {
                $statusText.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Normal, [System.Action]{
                    $statusText.Text = "Azure connection failed"
                })

                $logTextBox.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Normal, [System.Action]{
                    $logTextBox.AppendText("[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Azure connection failed`r`n")
                    $logTextBox.ScrollToEnd()
                })

                [System.Windows.MessageBox]::Show("Azure connection test failed. Please check your credentials and try again.", "Connection Test", "OK", "Error")
                Write-LogMessage "Azure connection test failed" -Level Error -Tab "Intune"
            }
            
            # Reset button state for completed job
            Write-LogMessage "Resetting button state after job completion" -Level Info -Tab "Intune"
            try {
                $testButton.Dispatcher.Invoke([System.Action]{
                    $testButton.IsEnabled = $true
                    $testButton.Content = "Test Azure Connection"
                })
                Write-LogMessage "Button state reset completed" -Level Info -Tab "Intune"
            }
            catch {
                Write-LogMessage "Error resetting button state: $($_.Exception.Message)" -Level Error -Tab "Intune"
            }
        } elseif ($testJob.State -eq "Running") {
            # Timeout
            Stop-Job -Job $testJob
            Remove-Job -Job $testJob -Force

            $statusText.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Normal, [System.Action]{
                $statusText.Text = "Connection test timed out"
            })

            $logTextBox.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Normal, [System.Action]{
                $logTextBox.AppendText("[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Connection test timed out`r`n")
                $logTextBox.ScrollToEnd()
            })

            [System.Windows.MessageBox]::Show("Connection test timed out. Please check your network connection and try again.", "Connection Test", "OK", "Warning")
            Write-LogMessage "Azure connection test timed out" -Level Warning -Tab "Intune"
            
            # Reset button state for timeout
            try {
                $testButton.Dispatcher.Invoke([System.Action]{
                    $testButton.IsEnabled = $true
                    $testButton.Content = "Test Azure Connection"
                })
            }
            catch {
                Write-LogMessage "Error resetting button state after timeout: $($_.Exception.Message)" -Level Error -Tab "Intune"
            }
        } else {
            # Job failed
            $errorResult = Receive-Job -Job $testJob -ErrorAction SilentlyContinue
            Remove-Job -Job $testJob

            $statusText.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Normal, [System.Action]{
                $statusText.Text = "Connection test failed"
            })

            $logTextBox.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Normal, [System.Action]{
                $logTextBox.AppendText("[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Connection test failed: $($errorResult.Exception.Message)`r`n")
                $logTextBox.ScrollToEnd()
            })

            [System.Windows.MessageBox]::Show("Connection test failed: $($errorResult.Exception.Message)", "Connection Test", "OK", "Error")
            Write-LogMessage "Azure connection test failed: $($errorResult.Exception.Message)" -Level Error -Tab "Intune"
            
            # Reset button state for job failure
            try {
                $testButton.Dispatcher.Invoke([System.Action]{
                    $testButton.IsEnabled = $true
                    $testButton.Content = "Test Azure Connection"
                })
            }
            catch {
                Write-LogMessage "Error resetting button state after job failure: $($_.Exception.Message)" -Level Error -Tab "Intune"
            }
        }
    }
    catch {
        Write-LogMessage "Error testing Intune connection: $($_.Exception.Message)" -Level Error -Tab "Intune"
        [System.Windows.MessageBox]::Show("Error testing connection: $($_.Exception.Message)", "Error", "OK", "Error")
        
        # Reset button state
        try {
            $testButton.Dispatcher.Invoke([System.Action]{
                $testButton.IsEnabled = $true
                $testButton.Content = "Test Azure Connection"
            })
        }
        catch {
            Write-LogMessage "Error resetting button state in catch block: $($_.Exception.Message)" -Level Error -Tab "Intune"
        }
    }
}
