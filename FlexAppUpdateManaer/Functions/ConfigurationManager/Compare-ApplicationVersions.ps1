# File: Functions\ConfigurationManager\Compare-ApplicationVersions.ps1
# ================================

function Compare-ApplicationVersions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$SelectedApps,
        
        [Parameter(Mandatory)]
        [array]$FlexAppInventory
    )
    
    $appsToProcess = @()
    $appsSkipped = @()
    $appsNotInInventory = @()
    
    foreach ($app in $SelectedApps) {
        $appName = $app.Name
        $appVersion = $app.Version
        
        # Look for the app in FlexApp inventory
        $existingFlexApp = $FlexAppInventory | Where-Object { $_.name -like "*$appName*" -or $appName -like "*$($_.name)*" }
        
        if (-not $existingFlexApp) {
            # App doesn't exist in FlexApp inventory - proceed with packaging
            $appsNotInInventory += $app
            $appsToProcess += $app
            Write-LogMessage "App '$appName' not found in FlexApp inventory - will be packaged" -Level Info -Tab "Configuration Manager"
        } else {
            # App exists in FlexApp inventory - compare versions
            $currentFlexAppVersion = ($existingFlexApp.Version | Measure-Object -Maximum).Maximum
            
            try {
                # Try to compare versions using proper version casting
                if ([string]::IsNullOrWhiteSpace($appVersion) -or $appVersion -eq "0.0.0.0") {
                    # CM app has no version or default version - proceed with packaging
                    $appsToProcess += $app
                    Write-LogMessage "App '$appName' has no version info - will be packaged" -Level Info -Tab "Configuration Manager"
                } elseif ([string]::IsNullOrWhiteSpace($currentFlexAppVersion) -or $currentFlexAppVersion -eq "0.0.0.0") {
                    # FlexApp has no version or default version - proceed with packaging
                    $appsToProcess += $app
                    Write-LogMessage "App '$appName' FlexApp version is empty - will be packaged" -Level Info -Tab "Configuration Manager"
                } else {
                    # Both have versions - compare them using [version] casting
                    $cmVersion = [version]$appVersion
                    $flexAppVersion = [version]$currentFlexAppVersion
                    
                    if ($cmVersion -gt $flexAppVersion) {
                        # CM version is newer - proceed with packaging
                        $appsToProcess += $app
                        Write-LogMessage "App '$appName' version $appVersion is newer than FlexApp version $currentFlexAppVersion - will be packaged" -Level Success -Tab "Configuration Manager"
                    } elseif ($cmVersion -eq $flexAppVersion) {
                        # Same version - proceed with packaging anyway
                        $appsToProcess += $app
                        Write-LogMessage "App '$appName' version $appVersion matches FlexApp version $currentFlexAppVersion - will be packaged anyway" -Level Info -Tab "Configuration Manager"
                    } else {
                        # CM version is older - skip
                        $appsSkipped += [PSCustomObject]@{
                            Name = $appName
                            CMVersion = $appVersion
                            FlexAppVersion = $currentFlexAppVersion
                        }
                        Write-LogMessage "App '$appName' version $appVersion is older than FlexApp version $currentFlexAppVersion - skipping" -Level Warning -Tab "Configuration Manager"
                    }
                }
            }
            catch {
                # Version comparison failed - proceed with packaging
                $appsToProcess += $app
                Write-LogMessage "App '$appName' version comparison failed: $($_.Exception.Message) - will be packaged" -Level Warning -Tab "Configuration Manager"
            }
        }
    }
    
    return @{
        ToProcess = $appsToProcess
        Skipped = $appsSkipped
        NotInInventory = $appsNotInInventory
    }
}
