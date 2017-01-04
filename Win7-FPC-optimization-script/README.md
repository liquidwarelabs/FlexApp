# Win7-FPC-optimization-script

Description <br>

Powershell Script to Optimize Windows 7 for Flexapp Packaging<br>


Attached in this repository is the PSM1 Module <br>
A PS1 wrapper for function <br>


How to Use<br>
Set the execution policy
```
Set-ExecutionPolicy -ExecutionPolicy Unrestricted
```

Run Script 
```
FPC Win7.ps1
```

You might see Errors this is normal<br>
once the script completes reboot workstation<br>
log back into system, install Flexapp Packaging Console. (extra steps in Video)<br>
Shutdown Workstation<br>
take snapshot<br>

Code<br>

```
<# 
 .DISCLAIMER
  This script is provided "AS IS" with no warranties, confers no rights, and is not supported by VMware.
  
 .SYNOPSIS 
 Windows 7 (Enterprise) VDI ProfileUnity FPC Optimizations
 
    .DESCRIPTION 
 Made for ProfileUnity FPC Optimizations
 
    .NOTES 
        NAME:  FPC WIN7.ps1 
        AUTHOR: Olivier AH-SON, Modified By Jack Smith
        LASTEDIT: 7/15/2016
        KEYWORDS: vdi, golden image, windows 7, optimization, powershell
 
#> 
 
 
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
 
### Get script path
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
 
### Set location to the root of the system drive
Set-Location -Path $env:SystemDrive
 
### Disable firewall on all profiles (domain, etc.) (Never disable the service!)
netsh advfirewall set allprofiles state off | Out-Host
 
### Disable Error Reporting
Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\PCHealth\ErrorReporting" -Name "DoReport" -Value 0
 
### Disable automatic updates
Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -Name "AUOptions" -Value 1
Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -Name "AUState" -Value 7
 
###  Remove Windows components
$featuresToDisable = @(
 "MediaPlayback",
 # If "WindowsMediaPlayer" removed, be aware WMV embedded videos on websites won't work (typically videos on Microsoft website)
 # Removed because another player is used as the standard
 "WindowsMediaPlayer", 
 "MediaCenter", 
 "OpticalMediaDisc", 
 "TabletPCOC", 
 "Printing-Foundation-InternetPrinting-Client", 
 "Printing-Foundation-Features", 
 "FaxServicesClientPackage",
 # If you want to keep the Start Menu search bar,
 # don't remove the "SearchEngine-Client-Package" component 
 #"SearchEngine-Client-Package", 
 "WindowsGadgetPlatform"
)
 
foreach($feature in $featuresToDisable)
{
 dism /online /Disable-Feature /Quiet /NoRestart /FeatureName:$feature  | Out-Host
}
 
### Disable NTFS last access timestamp
fsutil behavior set disablelastaccess 1  | Out-Host
 
### Disable TCP/IP / Large Send Offload
Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "DisableTaskOffload" -Value 1
 
### Disable hard disk timeouts 
POWERCFG /SETACVALUEINDEX 381b4222-f694-41f0-9685-ff5bb260df2e 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0  | Out-Host
POWERCFG /SETDCVALUEINDEX 381b4222-f694-41f0-9685-ff5bb260df2e 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0  | Out-Host
 
### Disable hibernation
powercfg /hibernate off | Out-Host
 
### Disable monitor time out (never)
powercfg -change -monitor-timeout-ac 0
 
###Disable system restore
# System Restore will be disabled on the system drive (usually C:)
Disable-ComputerRestore -Drive $env:SystemDrive 
Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "DisableSR" -Value 1
 
### Disable memory dumps (system crashes, BSOD)
Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "CrashDumpEnabled" -Value 0
Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "LogEvent" -Value 0
Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "SendAlert" -Value 0
Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "AutoReboot" -Value 1
 
### Disable default system screensaver
Set-RegistryKey -Path "Registry::\HKEY_USERS\.DEFAULT\Control Panel\Desktop" -Name "ScreenSaveActive" -Value 0
 
### Increase service startup timeouts
Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "ServicesPipeTimeout" -Value 180000
 
### Increase Disk I/O Timeout to 200 seconds
Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Disk" -Name "TimeOutValue" -Value 200
 
### Disable paging the executive
Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePagingExecutive" -Value 1
 
### Size virtual machine RAM
# Disable the automatic management of the paging filing size
$ComputerSystem = gwmi Win32_ComputerSystem -EnableAllPrivileges
$ComputerSystem.AutomaticManagedPagefile = $False
$AutomaticManagedPagefile = $ComputerSystem.Put()
 
# Modify the existing page file of the C drive to set a fixed size of 2048MB
# Keeping the pagefile at a single size prevents the system from expanding, which creates a significant amount of IO
$CurrentPageFile = gwmi -query "Select * FROM Win32_PageFileSetting WHERE Name='C:\\pagefile.sys'"
$CurrentPageFile.InitialSize = [int]2048
$CurrentPageFile.MaximumSize = [int]2048
$pageFile = $CurrentPageFile.Put()
 
### Disable Machine Account Password Changes
Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "DisablePasswordChange" -Value 1
 
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
 
### Set PopUp Error Mode to "Neither" 
Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Windows" -Name "ErrorMode" -Value 2
 
### Disable UAC secure desktop prompt
Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Value 0
 
### Disable New Network dialog
$newNetworkDialog = New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff" -Force
 
### Disable AutoUpdate of drivers from WU
Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "searchorderConfig" -Value 0
 
### Turn off Windows SideShow
Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Sideshow" -Name "Disabled" -Value 1
 
### Disable IE First Run Wizard and RSS Feeds
Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -Value 1
 
### Disable the ability to clear the paging file during shutdown 
Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SessionManager\Memory Management" -Name "ClearPageFileAtShutdown" -Value 0
 
###############################################
# Disable unnecessary services
###############################################
$servicesToDisable = @(
 "SensrSvc", # Adaptive Brightness
 "ALG", # Application Layer Gateway Service
 "BITS", # Background Intelligent Transfer Service
 "BDESVC", # BitLocker Drive Encryption Service
 "wbengine", # Block Level Backup Engine Service
 "bthserv", # Bluetooth Support Service
 "PeerDistSvc", # BranchCache
 "Browser", # Computer Browser
 "UxSms", # Desktop Window Manager Session Manager - Disable only if Aero not necessary
 "DPS", # Diagnostic Policy Service
 "WdiServiceHost", # Diagnostic Service Host
 "WdiSystemHost", # Diagnostic System Host
 "defragsvc", # Disk Defragmenter
 "TrkWks", # Distributed Link Tracking Client
 "EFS", # Encrypting File System (EFS)
 "Fax", # Fax - Not present in Windows 7 Enterprise
 "fdPHost", # Function Discovery Provider Host
 "FDResPub", # Function Discovery Resource Publication
 #"HomeGroupListener", # HomeGroup Listener - Not present in Windows 7 Enterprise
 "HomeGroupProvider", # HomeGroup Provider
 "UI0Detect", # Interactive Services Detection
 "iphlpsvc", # IP Helper
 "Mcx2Svc", # Media Center Extender Service
 "MSiSCSI", # Microsoft iSCSI Initiator Service
 "netprofm", # Network List Service
 "NlaSvc", # Network Location Awareness
 "CscService", # Offline Files
 "WPCSvc", # Parental Controls
 "wercplsupport", # Problem Reports and Solutions Control Panel Support
 "SstpSvc", # Secure Socket Tunneling Protocol Service
 "wscsvc", # Security Center
 "ShellHWDetection", # Shell Hardware Detection
 "SNMPTRAP", # SNMP Trap
 "SSDPSRV", # SSDP Discovery
 "SysMain", # Superfetch
 "TabletInputService", # Tablet PC Input Service
 "TapiSrv", # Telephony
 "Themes", # Themes - Disable only if you want to run in Classic interface
 "upnphost", # UPnP Device Host
 "SDRSVC", # Windows Backup
 "WcsPlugInService", # Windows Color System
 "wcncsvc", # Windows Connect Now - Config Registrar
 "WinDefend", # Windows Defender
 "WerSvc", # Windows Error Reporting Service
 "ehRecvr", # Windows Media Center Receiver Service
 "ehSched", # Windows Media Center Scheduler Service
 "WMPNetworkSvc", # Windows Media Player Network Sharing Service
 "WSearch", # Windows Search
 "wuauserv", # Windows Update
 "Wlansvc", # WLAN AutoConfig
 "WwanSvc", # WWAN AutoConfig
 "Power",   #Power
 #"Spooler",  #Print Spooler
 #"MpsSvc",  #Windows Firewall
 "VSS"  #Volume Shadow Copy
)
 
foreach($service in $servicesToDisable)
{
    Stop-Service -Name $service -Force # 'Force' parameter stops dependent services 
    Set-Service -Name $service -StartupType Disabled
}
###############################################
 
# Disable SuperFetch
# Service stopped and disabled
Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnableSuperfetch" -Value 0
 
### Disable schedule tasks
$tasksToDisable = @(
 "microsoft\windows\Application Experience\AitAgent",
 "microsoft\windows\Application Experience\ProgramDataUpdater",
 "microsoft\windows\Autochk\Proxy",
 "microsoft\windows\Bluetooth\UninstallDeviceTask", 
 "microsoft\windows\Customer Experience Improvement Program\Consolidator", 
 "microsoft\windows\Customer Experience Improvement Program\KernelCeipTask",
 "microsoft\windows\Customer Experience Improvement Program\UsbCeip",
 "microsoft\windows\Defrag\ScheduledDefrag",
 "microsoft\windows\Diagnosis\Scheduled",
 "microsoft\windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
 "microsoft\windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver", 
 "microsoft\windows\Maintenance\WinSAT", 
 "microsoft\windows\MobilePC\HotStart", 
 "microsoft\windows\RAC\RacTask",
 "microsoft\windows\Ras\MobilityManager",
 "microsoft\windows\Registry\RegIdleBackup",
 "microsoft\windows\SideShow\AutoWake", 
 "microsoft\windows\SideShow\GadgetManager",
 "microsoft\windows\SideShow\SessionAgent",
 "microsoft\windows\SideShow\SystemDataProviders",
 "microsoft\windows\SystemRestore\SR",
 "microsoft\windows\UPnP\UPnPHostConfig",
 "microsoft\windows\WDI\ResolutionHost",
 "microsoft\windows\Windows Filtering Platform\BfeOnServiceStartTypeChange", 
 "microsoft\windows\Windows Media Sharing\UpdateLibrary", 
 "microsoft\windows\WindowsBackup\ConfigNotification"
)
 
foreach ($task in $tasksToDisable) 
{
 schtasks /change /tn $task /Disable | Out-Host
}
 
### Disable unnecessary boot features (for the current operating system)[A]
# Disable the boot debugging 
bcdedit /bootdebug off
bcdedit /debug off
# Disable the bootlog
bcdedit /set bootlog no
# Disable the boot screen animation
# Note: bootux - Not supported in Windows 8 and Windows Server 2012.
bcdedit /set bootux disabled
# Note: Do not use the quietboot option in Windows 8 as it will prevent the display of bug check data in addition to all boot graphics.
bcdedit /set quietboot on
 
 
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
 
# Customization of the default user 
$defaultUserHivePath = $env:SystemDrive + "\Users\Default\NTUSER.DAT"
$userLoadPath = "HKU\TempUser" 
 
# Load Hive
reg load $userLoadPath $defaultUserHivePath | Out-Host
# Create PSDrive
$psDrive = New-PSDrive -Name HKUDefaultUser -PSProvider Registry -Root $userLoadPath
# Reduce menu show delay 
Set-RegistryKey -Path "HKUDefaultUser:\Control Panel\Desktop" -Name "MenuShowDelay" -Value 0
# Disable cursor blink 
Set-RegistryKey -Path "HKUDefaultUser:\Control Panel\Desktop" -Name "CursorBlinkRate" -Value -1
Set-RegistryKey -Path "HKUDefaultUser:\Control Panel\Desktop" -Name "DisableCursorBlink" -Value 1
# Force off-screen composition in IE 
Set-RegistryKey -Path "HKUDefaultUser:\Software\Microsoft\Internet Explorer\Main" -Name "Force Offscreen Composition" -Value 1
# Disable screensavers
Set-RegistryKey -Path "HKUDefaultUser:\Software\Policies\Microsoft\Windows\Control Panel\Desktop" -Name "ScreenSaveActive" -Value 0
Set-RegistryKey -Path "HKUDefaultUser:\Control Panel\Desktop\" -Name "ScreenSaveActive" -Value 0
Set-RegistryKey -Path "Registry::\HKEY_USERS\.DEFAULT\Control Panel\Desktop" -Name "ScreenSaveActive" -Value 0
# Don't show window contents when dragging 
Set-RegistryKey -Path "HKUDefaultUser:\Control Panel\Desktop" -Name "DragFullWindows" -Value 0
# Don't show window minimize/maximize animations
Set-RegistryKey -Path "HKUDefaultUser:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value 0
# Disable font smoothing 
Set-RegistryKey -Path "HKUDefaultUser:\Control Panel\Desktop" -Name "FontSmoothing" -Value 0
 
# Disable most other visual effects 
Set-RegistryKey -Path "HKUDefaultUser:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 3
Set-RegistryKey -Path "HKUDefaultUser:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewAlphaSelect" -Value 0
Set-RegistryKey -Path "HKUDefaultUser:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0
Set-RegistryKey -Path "HKUDefaultUser:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewWatermark" -Value 0
Set-RegistryKey -Path "HKUDefaultUser:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewShadow" -Value 0
Set-RegistryKey -Path "HKUDefaultUser:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x01,0x80)) -PropertyType "Binary"
 
# Disable Action Center Icon
Set-RegistryKey -Path "HKUDefaultUser:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "HideSCAHealth" -Value 1
 
# Disable Network Icon
Set-RegistryKey -Path "HKUDefaultUser:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "HideSCANetwork" -Value 1
 
# Disable IE Persistent Cache 
Set-RegistryKey -Path "HKUDefaultUser:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Cache" -Name "Persistent" -Value 0
Set-RegistryKey -Path "HKUDefaultUser:\Software\Microsoft\Feeds" -Name "SyncStatus" -Value 0
 
# Remove PSDrive
$psDrive = Remove-PSDrive HKUDefaultUser
# Clean up references not in use
$variables = Get-Variable | Where { $_.Name -ne "userLoadPath" } | foreach { $_.Name }
foreach($var in $variables) { Remove-Variable $var -ErrorAction SilentlyContinue }
[gc]::collect()
# Unload Hive
reg unload $userLoadPath | Out-Host
 
# Hide the VMWare tray icon for all users
Set-RegistryKey -Path "HKLM:\SOFTWARE\VMware, Inc.\VMware Tools" -Name "ShowTray" -Value 0

# Disable GWX.exe
Stop-Process -name gwx
Rename-Item c:\windows\system32\gwx gwxOFF
 
Exit 0

```

| OS Version  | Verified |
| ------------- | ------------- |
|Windows 10 | NO |
|Windows Server 2012 | No |
|Windows Server 2012 R2 | No |
|Windows Server 2008 R2 | No |
|Windows Server 2008 | No |
|Windows Server 2003 | No |
|Windows 8 | No |
|Windows 7 | YES |
|Windows Vista | No |
|Windows XP | No |
|Windows 2000 | No |
