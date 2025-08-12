# FlexApp-Operations.ps1
# Core FlexApp attach/detach operations

# Load common functions - check if we're in Modules subdirectory
if ($PSScriptRoot -like "*\Modules") {
    . "$PSScriptRoot\FlexApp-Common-Functions.ps1"
} else {
    # Fallback if running from different location
    . "$PSScriptRoot\Modules\FlexApp-Common-Functions.ps1"
}

# Function to attach FlexApp
function Invoke-FlexAppAttach {
    param(
        [string]$VhdxPath,
        [int]$WaitAfterAttach = 5
    )
    
    Write-Host "`nAttaching FlexApp..." -ForegroundColor Green
    
    try {
        # Start the FlexApp attach process
        $attachProcess = Start-Process -FilePath "C:\Program Files\ProfileUnity\FlexApp\lwl_userapp_trigger.exe" `
            -ArgumentList @("c:\program files\profileunity\client.net\LwL.ProfileUnity.Client.FlexApp", "//Install", "//Package", $VhdxPath, "/elevate") `
            -PassThru
        
        Write-Host "FlexApp attach process started" -ForegroundColor Yellow
        Write-Host "Waiting for LwL.ProfileUnity.Client.FlexApp.exe to complete..." -ForegroundColor Yellow
        
        # Wait for the FlexApp process to start
        $found = Wait-ForProcess -ProcessName "LwL.ProfileUnity.Client.FlexApp" -TimeoutSeconds 60
        
        if ($found) {
            Write-Host "LwL.ProfileUnity.Client.FlexApp.exe process detected" -ForegroundColor Green
            
            # Wait for process to complete
            $completed = Wait-ForProcess -ProcessName "LwL.ProfileUnity.Client.FlexApp" -TimeoutSeconds 60 -WaitForExit
            
            if ($completed) {
                Write-Host "FlexApp attach completed successfully" -ForegroundColor Green
                Start-Sleep -Seconds 2
                return $true
            }
            else {
                Write-Warning "FlexApp process did not complete within timeout"
            }
        }
        else {
            Write-Warning "LwL.ProfileUnity.Client.FlexApp.exe process was not detected"
            Write-Host "Waiting additional $WaitAfterAttach seconds as fallback..." -ForegroundColor Yellow
            Start-Sleep -Seconds $WaitAfterAttach
        }
        
        return $true
    }
    catch {
        Write-Error "Failed to attach FlexApp: $_"
        return $false
    }
}

# Function to detach FlexApp
function Invoke-FlexAppDetach {
    param([string]$VhdxPath)
    
    Write-Host "`nDetaching FlexApp..." -ForegroundColor Green
    
    try {
        # Start the FlexApp detach process
        $detachProcess = Start-Process -FilePath "C:\Program Files\ProfileUnity\FlexApp\lwl_userapp_trigger.exe" `
            -ArgumentList @("c:\program files\profileunity\client.net\LwL.ProfileUnity.Client.FlexApp", "//Uninstall", "//Package", $VhdxPath, "/elevate") `
            -PassThru
        
        Write-Host "FlexApp detach process started" -ForegroundColor Yellow
        Write-Host "Waiting for LwL.ProfileUnity.Client.FlexApp.exe to complete detach..." -ForegroundColor Yellow
        
        # Wait for the FlexApp process to start
        $found = Wait-ForProcess -ProcessName "LwL.ProfileUnity.Client.FlexApp" -TimeoutSeconds 10
        
        if ($found) {
            Write-Host "LwL.ProfileUnity.Client.FlexApp.exe process detected for detach" -ForegroundColor Green
            
            # Wait for process to complete
            $completed = Wait-ForProcess -ProcessName "LwL.ProfileUnity.Client.FlexApp" -TimeoutSeconds 60 -WaitForExit
            
            if ($completed) {
                Write-Host "FlexApp detached successfully" -ForegroundColor Green
                Start-Sleep -Seconds 2
                return $true
            }
            else {
                Write-Warning "FlexApp detach process did not complete within timeout"
            }
        }
        else {
            # If process was not detected, wait using simple sleep
            Write-Host "Waiting for detach trigger to complete..." -ForegroundColor Yellow
            Start-Sleep -Seconds 30
            Write-Host "Detach wait complete" -ForegroundColor Green
            Start-Sleep -Seconds 3
        }
        
        return $true
    }
    catch {
        Write-Error "Failed to detach FlexApp: $_"
        return $false
    }
}

# Function to launch application
function Start-FlexApplication {
    param(
        [hashtable]$LinkInfo,
        [string]$AppName
    )
    
    Write-Host "`nLaunching application..." -ForegroundColor Green
    Write-Host "Target executable: $($LinkInfo.Target)" -ForegroundColor Yellow
    
    if ($LinkInfo.Arguments) {
        Write-Host "Arguments: $($LinkInfo.Arguments)" -ForegroundColor Yellow
    }
    
    if (!(Test-Path $LinkInfo.Target)) {
        Write-Error "Executable not found at: $($LinkInfo.Target)"
        return $null
    }
    
    try {
        $startInfo = @{
            FilePath = $LinkInfo.Target
            PassThru = $true
            ErrorAction = 'Stop'
        }
        
        if ($LinkInfo.Arguments) {
            $startInfo.ArgumentList = $LinkInfo.Arguments
        }
        
        if ($LinkInfo.WorkingDirectory -and (Test-Path $LinkInfo.WorkingDirectory)) {
            $startInfo.WorkingDirectory = $LinkInfo.WorkingDirectory
            Write-Host "Working Directory: $($LinkInfo.WorkingDirectory)" -ForegroundColor Yellow
        }
        
        $process = Start-Process @startInfo
        
        # Get process name for later use
        $processName = Split-Path $LinkInfo.Target -Leaf -ErrorAction SilentlyContinue
        if ($processName -like "*.exe") {
            $processName = $processName -replace '\.exe$', ''
        }
        
        Write-Host "$AppName launched successfully" -ForegroundColor Green
        
        return @{
            Process = $process
            ProcessName = $processName
        }
    }
    catch {
        Write-Error "Failed to launch application: $_"
        return $null
    }
}

# Function to close application
function Stop-FlexApplication {
    param([string]$ProcessName)
    
    if (!$ProcessName) {
        return
    }
    
    Write-Host "`nClosing application..." -ForegroundColor Green
    
    try {
        Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Host "Application closed" -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not close application: $_"
    }
}