# FlexApp-Media-Capture.ps1
# Functions for video recording and screenshots

# Load common functions - check if we're in Modules subdirectory
if ($PSScriptRoot -like "*\Modules") {
    . "$PSScriptRoot\FlexApp-Common-Functions.ps1"
} else {
    # Fallback if running from different location
    . "$PSScriptRoot\Modules\FlexApp-Common-Functions.ps1"
}

# Function to start video recording
function Start-VideoRecording {
    param(
        [string]$FFmpegPath,
        [string]$OutputPath,
        [int]$Duration
    )
    
    if (!(Test-Path $FFmpegPath)) {
        Write-Error "FFmpeg not found at: $FFmpegPath"
        return $null
    }
    
    # Use local temp file first, then copy to final location (network path workaround)
    $tempPath = $OutputPath
    $useTemp = $false
    
    # Check if output path is a network location
    if ($OutputPath -like "\\*") {
        $tempDir = Join-Path $env:TEMP "FlexAppTesting"
        if (!(Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        $tempPath = Join-Path $tempDir "temp_recording_$(Get-Date -Format 'HHmmss').mp4"
        $useTemp = $true
        Write-Host "Using temporary local file for recording..." -ForegroundColor Gray
    }
    
    Write-Host "Starting video recording for $Duration seconds..." -ForegroundColor Yellow
    Write-Host "Output will be saved to: $OutputPath" -ForegroundColor Yellow
    
    try {
        # Use same basic approach as working screenshots, but with duration
        # Add filter to fix odd resolution issues (width must be even for libx264)
        $ffmpegArgs = @(
            "-hide_banner",
            "-loglevel", "error",
            "-f", "gdigrab",
            "-i", "desktop",
            "-t", $Duration,
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2",
            "-y",
            "`"$tempPath`""
        )
        
        $process = Start-Process -FilePath $FFmpegPath `
            -ArgumentList $ffmpegArgs `
            -WindowStyle Hidden `
            -PassThru
        
        # Store temp info in process object for later use
        if ($useTemp) {
            Add-Member -InputObject $process -MemberType NoteProperty -Name "TempPath" -Value $tempPath
            Add-Member -InputObject $process -MemberType NoteProperty -Name "FinalPath" -Value $OutputPath
            Add-Member -InputObject $process -MemberType NoteProperty -Name "UseTemp" -Value $true
        }
        
        return $process
    }
    catch {
        if ($_.Exception.Message -like "*blocked by group policy*") {
            Write-Warning "FFmpeg execution blocked by Group Policy/AppLocker. Video recording disabled."
            Write-Host "Continuing test without video recording..." -ForegroundColor Yellow
            return $null
        }
        else {
            Write-Error "Failed to start recording: $_"
            return $null
        }
    }
}

# Function to wait for recording completion
function Wait-VideoRecording {
    param(
        [System.Diagnostics.Process]$RecordingProcess,
        [string]$OutputPath,
        [int]$WaitSeconds
    )
    
    if (!$RecordingProcess) {
        Write-Warning "No recording process provided"
        return $false
    }
    
    Write-Host "Waiting for recording to complete ($WaitSeconds seconds)..." -ForegroundColor Yellow
    
    # Wait for the actual FFmpeg process to complete or timeout
    $timeout = $WaitSeconds + 10  # Add extra time for process cleanup
    $elapsed = 0
    
    while (!$RecordingProcess.HasExited -and $elapsed -lt $timeout) {
        Start-Sleep -Seconds 1
        $elapsed++
        if ($elapsed % 5 -eq 0) {
            Write-Host "Still recording... $elapsed/$timeout seconds" -ForegroundColor Gray
        }
    }
    
    if (!$RecordingProcess.HasExited) {
        Write-Warning "FFmpeg process did not complete within timeout, attempting to stop"
        try {
            $RecordingProcess.Kill()
            $RecordingProcess.WaitForExit(5000)
        }
        catch {
            Write-Warning "Could not stop FFmpeg process: $_"
        }
    }
    
    # Give file system time to finalize
    Start-Sleep -Seconds 2
    
    # Handle temp file copying if needed
    $checkPath = $OutputPath
    if ($RecordingProcess.UseTemp) {
        $checkPath = $RecordingProcess.TempPath
        Write-Host "Checking temp file: $checkPath" -ForegroundColor Gray
    }
    
    # Check if output file exists and has content
    if (Test-Path $checkPath) {
        $fileSize = Get-FileSizeConstrained -FilePath $checkPath
        if ($fileSize -gt 1000) {  # At least 1KB
            # Copy from temp to final location if needed
            if ($RecordingProcess.UseTemp) {
                Write-Host "Copying recording to final location..." -ForegroundColor Yellow
                try {
                    # Ensure target directory exists
                    $targetDir = Split-Path $RecordingProcess.FinalPath -Parent
                    if (!(Test-Path $targetDir)) {
                        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                    }
                    
                    Copy-Item -Path $checkPath -Destination $RecordingProcess.FinalPath -Force
                    
                    # Verify copy succeeded
                    if (Test-Path $RecordingProcess.FinalPath) {
                        $finalSize = Get-FileSizeConstrained -FilePath $RecordingProcess.FinalPath
                        $mb = $finalSize / 1048576
                        $mbInt = [int]$mb
                        $mbDecimal = [int](($mb - $mbInt) * 100)
                        Write-Host "Recording saved to: $($RecordingProcess.FinalPath) (Size: $mbInt.$mbDecimal MB)" -ForegroundColor Green
                        
                        # Clean up temp file
                        try { Remove-Item $checkPath -Force -ErrorAction SilentlyContinue } catch { }
                        return $true
                    }
                    else {
                        Write-Warning "Failed to copy recording to final location"
                        return $false
                    }
                }
                catch {
                    Write-Warning "Failed to copy recording to network location: $_"
                    Write-Host "Recording remains at temp location: $checkPath" -ForegroundColor Yellow
                    return $false
                }
            }
            else {
                $mb = $fileSize / 1048576
                $mbInt = [int]$mb
                $mbDecimal = [int](($mb - $mbInt) * 100)
                Write-Host "Recording saved to: $OutputPath (Size: $mbInt.$mbDecimal MB)" -ForegroundColor Green
                return $true
            }
        }
        else {
            Write-Warning "Recording file created but is very small ($fileSize bytes) - may be blank"
            return $false
        }
    }
    else {
        Write-Warning "Recording file was not created at: $checkPath"
        Write-Host "FFmpeg exit code: $($RecordingProcess.ExitCode)" -ForegroundColor Gray
        return $false
    }
}

# Function to record video (blocking)
function Invoke-VideoRecording {
    param(
        [string]$FFmpegPath,
        [string]$OutputPath,
        [int]$Duration
    )
    
    if (!(Test-Path $FFmpegPath)) {
        Write-Error "FFmpeg not found at: $FFmpegPath"
        return $false
    }
    
    Write-Host "Recording for $Duration seconds..." -ForegroundColor Yellow
    
    try {
        # Use same basic approach as working screenshots, but with duration
        # Add filter to fix odd resolution issues (width must be even for libx264)
        $ffmpegArgs = @(
            "-hide_banner",
            "-loglevel", "error",
            "-f", "gdigrab",
            "-i", "desktop",
            "-t", $Duration,
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2",
            "-y",
            "`"$OutputPath`""
        )
        
        $process = Start-Process -FilePath $FFmpegPath `
            -ArgumentList $ffmpegArgs `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardError "NUL" `
            -RedirectStandardOutput "NUL"
        
        if (Test-Path $OutputPath) {
            $fileSize = Get-FileSizeConstrained -FilePath $OutputPath
            if ($fileSize -gt 0) {
                # Simple MB calculation without Math::Round
                $mb = $fileSize / 1048576  # 1MB = 1048576 bytes
                $mbInt = [int]$mb
                $mbDecimal = [int](($mb - $mbInt) * 100)
                Write-Host "Recording saved to: $OutputPath (Size: $mbInt.$mbDecimal MB)" -ForegroundColor Green
            } else {
                Write-Host "Recording saved to: $OutputPath" -ForegroundColor Green
            }
            return $true
        }
        else {
            Write-Warning "Recording file was not created (FFmpeg may be blocked)"
            return $false
        }
    }
    catch {
        if ($_.Exception.Message -like "*blocked by group policy*") {
            Write-Warning "FFmpeg execution blocked by Group Policy/AppLocker. Video recording disabled."
            Write-Host "Continuing test without video recording..." -ForegroundColor Yellow
            return $false
        }
        else {
            Write-Warning "Failed to record video: $_"
            return $false
        }
    }
}

# Function to take screenshot
function Invoke-Screenshot {
    param(
        [string]$FFmpegPath,
        [string]$OutputPath
    )
    
    if (!(Test-Path $FFmpegPath)) {
        Write-Error "FFmpeg not found at: $FFmpegPath"
        return $false
    }
    
    Write-Host "Taking screenshot..." -ForegroundColor Yellow
    
    try {
        $screenshotArgs = @(
            "-hide_banner",
            "-loglevel", "error",
            "-f", "gdigrab",
            "-i", "desktop",
            "-frames:v", "1",
            "-y",
            $OutputPath
        )
        
        $process = Start-Process -FilePath $FFmpegPath `
            -ArgumentList $screenshotArgs `
            -NoNewWindow -Wait -PassThru
        
        if (Test-Path $OutputPath) {
            Write-Host "Screenshot saved to: $OutputPath" -ForegroundColor Green
            return $true
        }
        else {
            Write-Warning "Screenshot was not created (FFmpeg may be blocked)"
            return $false
        }
    }
    catch {
        if ($_.Exception.Message -like "*blocked by group policy*") {
            Write-Warning "FFmpeg execution blocked by Group Policy/AppLocker. Screenshots disabled."
            Write-Host "Continuing test without screenshots..." -ForegroundColor Yellow
            return $false
        }
        else {
            Write-Warning "Failed to take screenshot: $_"
            return $false
        }
    }
}