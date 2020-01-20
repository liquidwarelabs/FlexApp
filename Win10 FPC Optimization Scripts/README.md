# Win10 FPC optimization script

Description <br>

Powershell Script to Optimize Windows 10 for Flexapp Packaging reference workstation, DO NOT USE ON GOLD/PARENT IMAGE<br>


Attached in this repository is the PS1 and CSV<br>
Windows10 FPC Optimizer.zip [Windows10 FPC Optimizer.zip][Win10Optimizer]<br>


How to Use<br>
Set the execution policy
```
Set-ExecutionPolicy -ExecutionPolicy Unrestricted
```

Run Script 
```
FPCW10v3.ps1
```

You might see Errors this is normal<br>
once the script completes reboot workstation<br>
log back into system, install Flexapp Packaging Console. (extra steps in Video)<br>
Shutdown Workstation<br>
take snapshot<br>

Code<br>

```
<#
.SYNOPSIS
    This script configures Windows 10 with minimal configuration for Liquidware Flexapp Packaging Console.
.DESCRIPTION
    This script configures Windows 10 with minimal configuration for Liquidware Flexapp Packaging Console.
    
    // ============== 
    // General Advice 
    // ============== 

    Before finalizing the image perform the following tasks: 
    - Ensure no unwanted startup files by using autoruns.exe from SysInternals 
    - Run the Disk Cleanup tool as administrator and delete all temporary files and system restore points
    - Run disk defrag and consolidate free space: defrag c: /v /x
    - Reboot the machine 6 times and wait 120 seconds after logging on before performing the next reboot (boot prefetch training)
    - Run disk defrag and optimize boot files: defrag c: /v /b
    - If using a dynamic virtual disk, use the vendor's utilities to perform a "shrink" operation
    - If including antivirus software, do a full scan after a def update to hash the disk - should improve disk perf

    // ************* 
    // *  CAUTION  * 
    // ************* 

    THIS SCRIPT MAKES CONSIDERABLE CHANGES TO THE DEFAULT CONFIGURATION OF WINDOWS AND SHOULD ONLY BE USED ON THE LIQUIDWARE FPC

    Please review this script THOROUGHLY before applying to your virtual machine.

    This script is provided AS-IS - usage of this source assumes that you are at the very least familiar with PowerShell, and the tools used
    to create and debug this script.

.EXAMPLE
    .\Powershellv4.ps1
.NOTES
    Author:       Jack Smith
    Last Update:  15th Jan 2019
    Version:      4.0.0
.LOG
1.0.0 FPC Package Script for windows 10
2.0.0 Updates to Code Documenting
3.0.0 Added better pinned item clean up, Added local account added to admin group, added nGen cleanup routine, disabled Brower, and trusted installer removal
4.0.0 Changed the Service Shutdown section to not output errors on nonexisting services. (Removed the red)
#>

# // ============
# Configure Constants:

$Install_FrameWorks = "False"
$FrameWork_Source = "$scriptPath\FrameWorks"

# // ============


### Function to set a registry property value
### Create the registry key if it doesn't exist

Function Set-RegistryKey
{
 [CmdletBinding()]
 Param(
 [Parameter(Mandatory=$True,HelpMessage="Please Enter Registry Item Path",Position=1)]
 $Path,
 [Parameter(Mandatory=$True,HelpMessage="Please Enter Registry Item Name",Position=2)]
 $Name,
 [Parameter(Mandatory=$True,HelpMessage="Please Enter Registry Property Item Value",Position=3)]
 $Value,
 [Parameter(Mandatory=$False,HelpMessage="Please Enter Registry Property Type",Position=4)]
 $PropertyType = "DWORD"
 )

 # If path does not exist, create it
 If( (Test-Path $Path) -eq $False ) {

 $newItem = New-Item -Path $Path -Force

 } 

 # Update registry value, create it if does not exist (DWORD is default)
 $itemProperty = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
 If($itemProperty -ne $null) {

 $itemProperty = Set-ItemProperty -Path $Path -Name $Name -Value $Value
 } Else {

 $itemProperty = New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $PropertyType
 }

}

### Function to set startmenu tile pins
### Add/Remove StartMenu Pins

function Pin-App { param(
[string]$appname,
[switch]$unpin
)
try{
if ($unpin.IsPresent){
((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | ?{$_.Name -like $appname}).Verbs() | ?{$_.Name.replace('&','') -match 'From "Start" UnPin|Unpin from Start'} | %{$_.DoIt()}
return "App '$appname' unpinned from Start"
}else{
((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | ?{$_.Name -like $appname}).Verbs() | ?{$_.Name.replace('&','') -match 'To "Start" Pin|Pin to Start'} | %{$_.DoIt()}
return "App '$appname' pinned to Start"
}
}catch{
Write-Error "Error Pinning/Unpinning App! (App-Name correct?)"
}
}

### Get script path
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

### Set location to the root of the system drive
Set-Location -Path $env:SystemDrive


#Install FrameWorks
If ($Install_FrameWorks -eq "True")
{
    Write-Host "Installing All FrameWorks..." -ForegroundColor Green
    cmd.exe /c $FrameWork_Source\all.bat
    Write-Host ""
    Write-Host ""
}


# Customization of the default user 
$defaultUserHivePath = $env:SystemDrive + "\Users\Default\NTUSER.DAT"
$userLoadPath = "HKU\Temp" 

# Load Hive
reg load $userLoadPath $defaultUserHivePath | Out-Host

# Create PSDrive
$psDrive = New-PSDrive -Name HKUDefaultUser -PSProvider Registry -Root $userLoadPath

# // ============
# // Begin Config
# // ============

######################################
# Load Keys Manual

### Disable New Network dialog
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff" -Force
Set-RegistryKey -Path "HKUDefaultUser:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x01,0x80)) -PropertyType "Binary"
Set-RegistryKey -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x01,0x80)) -PropertyType "Binary"
Set-RegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" -Name "OneDrive" -Value ([byte[]](0x03,0x00,0x00,0x00,0x0d,0xe5,0x6c,0xcc,0x4f,0xce,0xd2,0x01)) -PropertyType "Binary"
reg delete "HKU\Temp\Software\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f
######################################

# Load Regkeys from CSV
$global:optregkeys=import-csv $scriptPath\Settings\regkeys.csv

foreach ($optregkey in $optregkeys)
{
[string]$optpath=$optregkey.path
[string]$optname=$optregkey.Name
[string]$optvalue=$optregkey.Value
[string]$optPropertyType=$optregkey.PropertyType

set-RegistryKey "$optpath" -name "$optname" -value "$optvalue" -propertyType "$optPropertyType"

}

# Remove PSDrive
$psDrive = Remove-PSDrive HKUDefaultUser
# Clean up references not in use
$variables = Get-Variable | Where { $_.Name -ne "userLoadPath" } | foreach { $_.Name }
foreach($var in $variables) { Remove-Variable $var -ErrorAction SilentlyContinue }
[gc]::collect()
# Unload Hive
reg unload $userLoadPath | Out-Host

#########################################################################


### Disable firewall on all profiles (domain, etc.) (Never disable the service!)
netsh advfirewall set allprofiles state off | Out-Host

### Disable Error Reporting
Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\PCHealth\ErrorReporting" -Name "DoReport" -Value 0

#Set system to High Performance
Powercfg.exe /S SCHEME_MIN 

#Hard disk timeouts on ac power	
powercfg -change -disk-timeout-ac 0 

#Hard disk timeouts on dc power	
powercfg -change -disk-timeout-dc 0 

#Hibernation for Power Config	
powercfg /h off 

#Last Access Timestamp
fsutil behavior set DisableLastAccess 1 

#Monitor timeouts on ac power	
powercfg -change -monitor-timeout-ac 0 

#Monitor timeouts on dc power	
powercfg -change -monitor-timeout-dc 0 

#PC Sleep Timeout On AC Power
powercfg -change -monitor-timeout-ac 0 

#PC Sleep Timeout On DC Power
powercfg -change -monitor-timeout-dc 0 

#Removes All System Restore
vssadmin delete shadows /for=c: /all /quiet

###Disable system restore
# System Restore will be disabled on the system drive (usually C:)
Disable-ComputerRestore -Drive $env:SystemDrive 
Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "DisableSR" -Value 1

###  Remove Windows components
$featuresToDisable = @(
 "MediaPlayback",
 # If "WindowsMediaPlayer" removed, be aware WMV embedded videos on websites won't work (typically videos on Microsoft website)
 # Removed because another player is used as the standard
 "WindowsMediaPlayer",  
 "Printing-Foundation-InternetPrinting-Client", 
 "Printing-Foundation-Features", 
 "FaxServicesClientPackage",
 # If you want to keep the Start Menu search bar,
 # don't remove the "SearchEngine-Client-Package" component 
 "SearchEngine-Client-Package",
 "WCF-Services45"
 "Xps-Foundation-Xps-Viewer"
 "SMB1Protocol"
 "Microsoft-Windows-HyperV-Guest-Package"
)

foreach($feature in $featuresToDisable)
{
 dism /online /Disable-Feature /NoRestart /FeatureName:$feature  | Out-Host
}

### Remove Scheduled Tasks

### Disable schedule tasks
$tasksToDisable = @(
"Microsoft\Windows\AppID\SmartScreenSpecific"
"Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
"Microsoft\Windows\Application Experience\ProgramDataUpdater"
"Microsoft\Windows\Application Experience\StartupAppTask"
"Microsoft\Windows\Autochk\Proxy"
"Microsoft\Windows\Bluetooth\UninstallDeviceTask"
"Microsoft\Windows\Chkdsk\ProactiveScan"
"Microsoft\Windows\CloudExperienceHost\CreateObjectTask"
"Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
"Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask"
"Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
"Microsoft\Windows\Defrag\ScheduledDefrag"
"Microsoft\Windows\Diagnosis\Scheduled"
"Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
"Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver"
"Microsoft\Windows\Feedback\Siuf\DmClient"
"Microsoft\Windows\FileHistory\File History (maintenance mode)"
"Microsoft\Windows\Location\Notifications"
"Microsoft\Windows\Maintenance\WinSAT"
"Microsoft\Windows\Maps\MapsToastTask"
"Microsoft\Windows\Maps\MapsUpdateTask"
"Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents"
"Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic"
"Microsoft\Windows\Mobile Broadband Accounts\MNO Metadata Parse"
"Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"
"Microsoft\Windows\Ras\MobilityManager"
"Microsoft\Windows\Registry\RegIdleBackup"
"Microsoft\Windows\Shell\FamilySafetyMonitor"
"Microsoft\Windows\Shell\FamilySafetyRefresh"
"Microsoft\Windows\Shell\IndexerAutomaticMaintenance"
"Microsoft\Windows\SystemRestore\SR"
"Microsoft\Windows\TPM\Tpm-Maintenance"
"Microsoft\Windows\UPnP\UPnPHostConfig"
"Microsoft\Windows\WDI\ResolutionHost"
"Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance"
"Microsoft\Windows\Windows Defender\Windows Defender Cleanup"
"Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan"
"Microsoft\Windows\Windows Defender\Windows Defender Verification"
"Microsoft\Windows\Windows Error Reporting\QueueReporting" 
"Microsoft\Windows\Windows Filtering Platform\BfeonServiceStartTypeChange"
"Microsoft\Windows\Windows Media Sharing\UpdateLibrary"
"Microsoft\Windows\WOF\WIM-Hash-Management"
"Microsoft\Windows\WOF\WIM-Hash-Validation"
"Microsoft\Windows\UpdateOrchestrator\Schedule Scan"
"Microsoft\Windows\UpdateOrchestrator\Refresh Settings"
"Microsoft\Windows\WindowsUpdate\Scheduled Start"
"Microsoft\Windows\WindowsUpdate\Automatic App Update"
"Microsoft\Windows\WindowsUpdate\sih"
"Microsoft\Windows\WindowsUpdate\sihboot"
"Microsoft\Windows\Rempl\shell"
"Microsoft\Windows\Rempl\shell-maintenance"
)

foreach ($task in $tasksToDisable) 
{
 schtasks /change /tn $task /Disable | Out-Host
}

###############################################
# Disable unnecessary services
###############################################
# Options: Continue [default], Stop, SilentlyContinue, Inquire.
$ErrorActionPreference= 'silentlycontinue'
###############################################

$servicesToDisable = @(
"AJRouter"
"ALG"
"bits"
"wbengine"
"BthHFSrv"
"bthserv"
"BDESVC"
"PeerDistSvc"
# "Browser"
"DsmSvc"
"DPS"
"WdiServiceHost"
"WdiSystemHost"
"DiagTrack"
"MapsBroker"
"EFS"
"Fax"
"fdPHost"
"FDResPub"
"HomeGroupListener"
"HomeGroupProvider"
"vmickvpexchange"
"vmicguestinterface"
"vmicshutdown"
"vmicheartbeat"
"vmicrdv"
"vmictimesync"
"vmicvmsession"
"vmicvss"
"UI0Detect"
"SharedAccess"
"iphlpsvc"
"diagnosticshub.standardcollector.service"
"MSiSCSI"
"swprv"
"CscService"
"defragsvc"
"PcaSvc"
"QWAVE"
"wercplsupport"
"RetailDemo"
"SstpSvc"
"wscsvc"
"SensorDataService"
"SensrSvc"
"SensorService"
"ShellHWDetection"
"SNMPTRAP"
"svsvc"
"SSDPSRV"
"WiaRpc"
"StorSvc"
"SysMain"
"TapiSrv"
"Themes"
"upnphost"
"VSS"
# "dmwappushsvc"
"SDRSVC"
"WbioSrvc"
# "WcsPlugInService"
"wcncsvc"
"WerSvc"
# "WMPNetworkSvc"
"icssvc"
"WSearch"
"wuauserv"
"Wlansvc"
"WwanSvc"
"XblAuthManager"
"XblGameSave"
"XboxNetApiSvc"
#(optional Service Disable if processing Appx with ProfileUnity, Disable for FPC)
"AppReadiness"
# "TrustedInstaller"
# "WpnService"
)

foreach($service in $servicesToDisable)
{
    # 'Force' parameter stops dependent services
    Write-Host "Disabling $service..." -ForegroundColor Cyan
    Stop-Service -Name $service -Force -erroraction $ErrorActionPreference
    Set-Service -Name $service -StartupType Disabled -erroraction $ErrorActionPreference
}


###############################################

### Configure Event Logs to 1028KB (Minimum size under Vista/7) and overflowaction to "overwrite" 
$logs = Get-EventLog -LogName * | foreach{$_.Log.ToString()}
$limitParam = @{
  logname = ""
  Maximumsize = 1024KB
  OverflowAction = "OverwriteAsNeeded"
}

foreach($log in $logs) {

    $limitParam.logname = $log 
    Limit-EventLog @limitParam | Where {$_.Log -eq $limitparam.logname}
    Clear-EventLog -LogName $log

}

###############################################

# Configure WMI:
Write-Host "Modifying WMI Configuration..." -ForegroundColor Green
Write-Host ""
$oWMI=get-wmiobject -Namespace root -Class __ProviderHostQuotaConfiguration
$oWMI.MemoryPerHost=768*1024*1024
$oWMI.MemoryAllHosts=1536*1024*1024
$oWMI.put()
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Winmgmt -Name 'Group' -Value 'COM Infrastructure'
winmgmt /standalonehost
Write-Host ""

###############################################

### Perform a disk cleanup 
# Automate by creating the reg checks corresponding to "cleanmgr /sageset:100" so we can use "sagerun:100" 
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Active Setup Temp Folders" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Downloaded Program Files" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Internet Cache Files" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Memory Dump Files" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Offline Pages Files" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Old ChkDsk Files" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Previous Installations" -Name "StateFlags0100" -Value 0
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Recycle Bin" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Setup Log Files" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\System error memory dump files" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\System error minidump files" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Files" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Setup Files" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Thumbnail Cache" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Upgrade Discarded Files" -Name "StateFlags0100" -Value 0
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting Archive Files" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting Queue Files" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting System Archive Files" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting System Queue Files" -Name "StateFlags0100" -Value 2
Set-RegistryKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Upgrade Log Files" -Name "StateFlags0100" -Value 2

cleanmgr.exe /sagerun:100  | Out-Host

###############################################

#Remove All AppX Packages
#Get-AppxPackage -AllUsers | Remove-AppxPackage -erroraction 'silentlycontinue'

###############################################
# Remove all pinned Items and replace with "This PC"

(New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items()| foreach { ($_).Verbs() | ?{$_.Name.Replace('&', '') -match 'From "Start" UnPin|Unpin from Start'} | %{$_.DoIt()}  }
Pin-App -appname "This PC"
Export-StartLayout $env:temp\default.xml
Import-StartLayout $env:temp\default.xml -MountPath c:\

###############################################
# Create Local Service Account for Packaging

New-LocalUser -Name "ProUFPC" -Description "ProfileUnity FPC Service Account" -NoPassword
Add-LocalGroupMember -Group "Administrators" -Member "ProUFPC"

###############################################
#Dot.net complile

$Env:PATH = [Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
[AppDomain]::CurrentDomain.GetAssemblies() | % {
  $pt = $_.Location
  if (! $pt) {continue}
  if ($cn++) {''}
  $na = Split-Path -Leaf $pt
  Write-Host -ForegroundColor Yellow "NGENing $na"
  ngen install $pt
}

###############################################

```

[Win10Optimizer]: https://github.com/liquidwarelabs/FlexApp/raw/master/Win10%20FPC%20Optimization%20Scripts/Windows10%20FPC%20Optimizer.zip

| OS Version  | Verified |
| ------------- | ------------- |
| OS Version  | Verified |
| ------------- | ------------- |
|Windows 10 1909 | YES |
|Windows 10 1903 | YES |
|Windows 10 1809 | YES |
|Windows 10 1803 | YES |
|Windows 10 1709 | YES |
|Windows 10 1703 | YES |
|Windows 10 1607 | NO |
