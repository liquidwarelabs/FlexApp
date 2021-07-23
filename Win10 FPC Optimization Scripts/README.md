# Win10 FPC optimization script

Description <br>

Powershell Script to Optimize Windows 10 for FlexApp packaging purposes only, DO NOT USE ON GOLD/PARENT IMAGE<br>


Attached in this repository is the PS1 and CSV<br>
Windows10 FPC Optimizerv5.zip


How to Use<br>
In an elevated instance of Powershell.exe, set the execution policy<br>
```
Set-ExecutionPolicy -ExecutionPolicy Unrestricted
```

Run Script 
```
cd "Windows10 FPC Optimizer"
.\FPCW10v5.ps1
```

You might see Errors this is normal<br>
Once the script completes, reboot the VM<br>
Log back into VM, install FlexApp Packaging Console or FlexApp Packaging Automation Capture Agent<br>
Shutdown VM<br>
Take snapshot<br>
Power on VM<br>


| OS Version  | Verified |
| ------------- | ------------- |
| OS Version  | Verified |
| ------------- | ------------- |
|Windows 10 21H1 | YES |
|Windows 10 20H1/2 | YES |
|Windows 10 1903/9 | YES |
|Windows 10 1803/9 | YES |
|Windows 10 1703/9 | YES |
|Windows 10 1607 | NO |
