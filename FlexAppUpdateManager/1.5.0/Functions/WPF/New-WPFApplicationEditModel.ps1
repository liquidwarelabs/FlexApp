# File: WPF\Functions\New-WPFApplicationEditModel.ps1
# ===================================================

function New-WPFApplicationEditModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Version,
        
        [Parameter(Mandatory)]
        [string]$Installer,
        
        [string]$InstallerArgs = "",
        
        [int]$Index = 1
    )
    
    try {
        # Create a PowerShell custom object that can be used with WPF data binding
        $model = New-Object PSObject -Property @{
            Name = $Name
            Version = $Version
            Installer = $Installer
            InstallerArgs = $InstallerArgs
            Index = $Index
            DisplayHeader = "Application $Index"
            OriginalName = $Name
            OriginalVersion = $Version
            OriginalInstaller = $Installer
            OriginalInstallerArgs = $InstallerArgs
        }
        
        # Add ScriptMethods for validation and change detection
        $model | Add-Member -MemberType ScriptMethod -Name "IsValid" -Value {
            return -not [string]::IsNullOrWhiteSpace($this.Name) -and
                   -not [string]::IsNullOrWhiteSpace($this.Version) -and
                   -not [string]::IsNullOrWhiteSpace($this.Installer)
        }
        
        $model | Add-Member -MemberType ScriptMethod -Name "HasChanges" -Value {
            return $this.Name -ne $this.OriginalName -or
                   $this.Version -ne $this.OriginalVersion -or
                   $this.Installer -ne $this.OriginalInstaller -or
                   $this.InstallerArgs -ne $this.OriginalInstallerArgs
        }
        
        $model | Add-Member -MemberType ScriptMethod -Name "GetValidationErrors" -Value {
            $errors = @()
            
            if ([string]::IsNullOrWhiteSpace($this.Name)) {
                $errors += "Name is required"
            }
            
            if ([string]::IsNullOrWhiteSpace($this.Version)) {
                $errors += "Version is required"
            }
            
            if ([string]::IsNullOrWhiteSpace($this.Installer)) {
                $errors += "Installer path is required"
            }
            # Note: Skipping path validation for CM-extracted paths as they may be UNC paths
            # not accessible from the current system but valid for the deployment
            
            return $errors
        }
        
        $model | Add-Member -MemberType ScriptMethod -Name "ResetToOriginal" -Value {
            $this.Name = $this.OriginalName
            $this.Version = $this.OriginalVersion
            $this.Installer = $this.OriginalInstaller
            $this.InstallerArgs = $this.OriginalInstallerArgs
        }
        
        $model | Add-Member -MemberType ScriptMethod -Name "CommitChanges" -Value {
            $this.OriginalName = $this.Name
            $this.OriginalVersion = $this.Version
            $this.OriginalInstaller = $this.Installer
            $this.OriginalInstallerArgs = $this.InstallerArgs
        }
        
        Write-LogMessage "Created application edit model for '$Name' v$Version" -Level Info -Tab "General"
        return $model
    }
    catch {
        Write-LogMessage "Error creating application edit model: $($_.Exception.Message)" -Level Error -Tab "General"
        throw
    }
}

# Function to convert CM applications to edit models
function ConvertTo-WPFApplicationEditModels {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Applications
    )
    
    try {
        $models = @()
        $index = 1
        
        foreach ($app in $Applications) {
            # Validate application has required properties
            $appName = if ($app.LocalizedDisplayName) { $app.LocalizedDisplayName } else { $app.Name }
            if ([string]::IsNullOrWhiteSpace($appName)) {
                Write-LogMessage "Skipping application with empty name (Index: $index)" -Level Warning -Tab "Configuration Manager"
                $index++
                continue
            }
            
            $appVersion = if ($app.SoftwareVersion) { $app.SoftwareVersion } else { "1.0.0" }
            if ([string]::IsNullOrWhiteSpace($appVersion)) {
                $appVersion = "1.0.0"
                Write-LogMessage "Using default version '1.0.0' for application '$appName'" -Level Warning -Tab "Configuration Manager"
            }
            
            Write-LogMessage "Converting application '$appName' to edit model" -Level Info -Tab "Configuration Manager"
            
            # Extract installer and args from the application
            $installer = ""
            $installerArgs = ""
            
            if ($app.SDMPackageXML) {
                try {
                    $xml = [xml]$app.SDMPackageXML
                    $deploymentType = $xml.AppMgmtDigest.DeploymentType
                    
                    if ($deploymentType -and $deploymentType.Installer) {
                        $installAction = $deploymentType.Installer.InstallAction
                        
                        if ($installAction -and $installAction.Args -and $installAction.Args.arg) {
                            $argNodes = $installAction.Args.arg
                            if ($argNodes -is [array]) {
                                $installer = $argNodes[0].'#text'
                                if ($argNodes.Count -gt 1) {
                                    $installerArgs = ($argNodes[1..($argNodes.Count-1)] | ForEach-Object { $_.'#text' }) -join " "
                                }
                            } else {
                                $installer = $argNodes.'#text'
                            }
                        }
                    }
                }
                catch {
                    Write-LogMessage "Error parsing SDMPackageXML for '$appName': $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
                    # Use fallback values
                    $installer = "C:\FlexApp\$appName\install.exe"
                    $installerArgs = "/S"
                }
            }
            
            # Ensure installer path is not empty
            if ([string]::IsNullOrWhiteSpace($installer)) {
                $installer = "C:\FlexApp\$appName\install.exe"
                Write-LogMessage "Using default installer path for '$appName': $installer" -Level Info -Tab "Configuration Manager"
            }
            
            # Create the edit model
            $model = New-WPFApplicationEditModel -Name $appName -Version $appVersion -Installer $installer -InstallerArgs $installerArgs -Index $index
            
            # Add the original CM application reference
            $model | Add-Member -MemberType NoteProperty -Name "CMApplication" -Value $app
            
            $models += $model
            $index++
        }
        
        Write-LogMessage "Converted $($models.Count) applications to edit models" -Level Success -Tab "Configuration Manager"
        return $models
    }
    catch {
        Write-LogMessage "Error converting applications to edit models: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
        throw
    }
}

# Function to convert already processed application data to edit models
function ConvertFrom-ProcessedApplicationData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$ProcessedApps
    )
    
    try {
        $models = @()
        $index = 1
        
        foreach ($app in $ProcessedApps) {
            Write-LogMessage "Converting processed application '$($app.Name)' to edit model" -Level Info -Tab "Configuration Manager"
            
            # Use the data that was already extracted by Process-WPFSelectedApplications
            $appName = $app.Name
            $appVersion = $app.Version
            $installer = $app.Installer
            $installerArgs = $app.InstallerArgs
            
            # Validate required fields
            if ([string]::IsNullOrWhiteSpace($appName)) {
                Write-LogMessage "Skipping processed application with empty name (Index: $index)" -Level Warning -Tab "Configuration Manager"
                $index++
                continue
            }
            
            if ([string]::IsNullOrWhiteSpace($appVersion)) {
                $appVersion = "1.0.0"
                Write-LogMessage "Using default version '1.0.0' for processed application '$appName'" -Level Warning -Tab "Configuration Manager"
            }
            
            if ([string]::IsNullOrWhiteSpace($installer)) {
                $installer = "C:\FlexApp\$appName\install.exe"
                Write-LogMessage "Using default installer path for processed application '$appName': $installer" -Level Info -Tab "Configuration Manager"
            }
            
            # Create the edit model with the processed data
            $model = New-WPFApplicationEditModel -Name $appName -Version $appVersion -Installer $installer -InstallerArgs $installerArgs -Index $index
            
            # Add the original processed application reference
            $model | Add-Member -MemberType NoteProperty -Name "ProcessedApplication" -Value $app
            
            $models += $model
            $index++
        }
        
        Write-LogMessage "Converted $($models.Count) processed applications to edit models" -Level Success -Tab "Configuration Manager"
        return $models
    }
    catch {
        Write-LogMessage "Error converting processed applications to edit models: $($_.Exception.Message)" -Level Error -Tab "Configuration Manager"
        throw
    }
}
