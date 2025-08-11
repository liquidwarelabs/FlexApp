# File: Functions\ConfigurationManager\Process-SelectedApplications.ps1
# ================================

function Process-SelectedApplications {
    param(
        [array]$SelectedApps,
        [System.Windows.Forms.ProgressBar]$ProgressBar,
        [System.Windows.Forms.Label]$StatusLabel
    )
    
    $ProcessedApps = @()
    $TotalApps = $SelectedApps.Count
    $CurrentApp = 0
    
    if ($TotalApps -eq 0) {
        $StatusLabel.Text = "No applications to process"
        return @()
    }
    
    foreach ($app in $SelectedApps) {
        $CurrentApp++
        if ($TotalApps -gt 0) {
            $ProgressBar.Value = [int](($CurrentApp / $TotalApps) * 100)
        }
        $StatusLabel.Text = "Processing: $app ($CurrentApp of $TotalApps)"
        [System.Windows.Forms.Application]::DoEvents()
        
        try {
            $Appdetails = $null
            
            $Appdetails = Get-CMApplication | Where-Object { $_.LocalizedDisplayName -eq $app }
            
            if ($Appdetails -eq $null) {
                $Appdetails = Get-CMApplication | Where-Object { $_.LocalizedName -eq $app }
            }
            
            if ($Appdetails -eq $null) {
                $Appdetails = Get-CMApplication | Where-Object { $_.CI_UniqueID -eq $app }
            }
            
            if ($Appdetails -eq $null) {
                $Appdetails = Get-CMApplication -name $app -ErrorAction SilentlyContinue
            }
            
            if ($Appdetails -eq $null) {
                Write-LogMessage "Could not find application: $app" -Level Warning -Tab "Configuration Manager"
                continue
            }
            
            if ($Appdetails -is [array]) {
                $Appdetails = $Appdetails[0]
            }
            
            [xml]$appxml = $Appdetails.SDMPackageXML
            
            $AppName = $app
            if (![string]::IsNullOrWhiteSpace($appxml.AppMgmtDigest.Application.DisplayInfo.Info.Title)) {
                $AppName = $appxml.AppMgmtDigest.Application.DisplayInfo.Info.Title
            }
            
            $appVersion = $Appdetails.SoftwareVersion
            $installLocation = $appxml.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location
            $installerArgs = ($appxml.AppMgmtDigest.DeploymentType.Installer.InstallAction.Args.arg | Where-Object {$_.Name -eq "InstallCommandLine"}).'#text'
            
            $Pathandfilename = $installLocation + ((($installerArgs)|ForEach-Object{$_.split('"')[1]}))
            
            if($Pathandfilename -match '.msi'){
                if($installerArgs -match '/qn'){
                    $arglist = (($installerArgs -split '.msi"')[1] -split '/qn')[1]
                }
                elseif ($installerArgs -match '/q'){
                    $arglist = (($installerArgs -split '.msi"')[1] -split '/q')[1]
                }
                elseif ($installerArgs -match '$null'){
                    $arglist = (($installerArgs -split '.msi"')[1] -split '$null')[1]
                }
                else {
                    $arglist = (($installerArgs -split '.msi"')[1])
                }
            }
            else{
                $arglist = ($installerArgs).split('"')[-1]
            }
            
            # Also add lowercase versions for backward compatibility without duplicates
            # Add them as separate properties after the object creation
            $newAppItem = [pscustomobject]@{
                Name = $AppName
                Version = if (![string]::IsNullOrWhiteSpace($appVersion)) { $appVersion } else { "0.0.0.0" }
                PackageVersion = $appVersion
                InstallCommandLine = $installerArgs
                Installer = if (![string]::IsNullOrWhiteSpace($Pathandfilename)) { $Pathandfilename } else { "" }
                InstallerArgs = if (![string]::IsNullOrWhiteSpace($arglist)) { $arglist } else { "" }
                size = 20480
            }
            
            # Add lowercase aliases for backward compatibility
            $newAppItem | Add-Member -NotePropertyName "installer" -NotePropertyValue $newAppItem.Installer -Force
            $newAppItem | Add-Member -NotePropertyName "installerargs" -NotePropertyValue $newAppItem.InstallerArgs -Force
            
            $ProcessedApps += $newAppItem
        }
        catch {
            Write-LogMessage "Error processing app '$app': $($_.Exception.Message)" -Level Warning -Tab "Configuration Manager"
        }
    }
    
    return $ProcessedApps
}