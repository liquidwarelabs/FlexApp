# FlexApp-Common-Functions.ps1
# Common utility functions for FlexApp testing in constrained language mode

# Function to load framework configuration
function Get-FrameworkConfig {
    param(
        [string]$ConfigPath = "",
        [switch]$UseNetworkPaths
    )
    
    # Determine config file location
    if (-not $ConfigPath) {
        # Handle case where MyInvocation.MyCommand.Path might be null (dot-sourced scripts)
        $scriptPath = $MyInvocation.MyCommand.Path
        if (-not $scriptPath) {
            # Fall back to PSScriptRoot or current location
            if ($PSScriptRoot) {
                $scriptDir = $PSScriptRoot
            } else {
                $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
                if (-not $scriptDir) {
                    $scriptDir = Get-Location
                }
            }
        } else {
            $scriptDir = Split-Path -Parent $scriptPath
        }
        
        # Navigate up to find the root directory (should contain MODULES folder)
        $currentDir = $scriptDir
        $rootDir = $null
        
        # Look for parent directory containing MODULES folder
        while ($currentDir -and (Split-Path -Parent $currentDir)) {
            if (Test-Path (Join-Path $currentDir "MODULES")) {
                $rootDir = $currentDir
                break
            }
            $currentDir = Split-Path -Parent $currentDir
        }
        
        # If we didn't find it, assume we're in MODULES and go up one level
        if (-not $rootDir) {
            if ($scriptDir -and (Split-Path -Leaf $scriptDir) -eq "MODULES") {
                $rootDir = Split-Path -Parent $scriptDir
            } else {
                # Last resort - use script directory's parent
                $rootDir = Split-Path -Parent $scriptDir
            }
        }
        
        if ($rootDir) {
            $ConfigPath = Join-Path $rootDir "CONFIG\framework-config.json"
        } else {
            # Ultimate fallback
            $ConfigPath = "CONFIG\framework-config.json"
        }
    }
    
    # Default configuration if file doesn't exist
    $defaultConfig = @{
        FrameworkPaths = @{
            TestRunnerPath = ".\CORE\FlexApp-Test-Runner.ps1"
            BatchManagerPath = ".\CORE\FlexApp-Batch-Manager.ps1"
            GUIPath = ".\GUI\FlexApp-Selection-Tool.ps1"
            ModulesPath = ".\MODULES"
            ConfigPath = ".\CONFIG"
            ExamplesPath = ".\EXAMPLES"
        }
        DefaultPaths = @{
            FFmpegPath = "C:\ffmpeg\bin\ffmpeg.exe"
            OutputBaseDir = "C:\Temp\FlexAppTests"
            NetworkFFmpegPath = "\\server\share\Automation\LaunchTesting\Flexapp-Testing\ffmpeg\bin\ffmpeg.exe"
        }
        NetworkPaths = @{
            AutomationRoot = "\\server\share\Automation\LaunchTesting\Flexapp-Testing"
            BatchManagerPath = "\\server\share\Automation\LaunchTesting\Flexapp-Testing\CORE\FlexApp-Batch-Manager.ps1"
            TestRunnerPath = "\\server\share\Automation\LaunchTesting\Flexapp-Testing\CORE\FlexApp-Test-Runner.ps1"
        }
        TestDefaults = @{
            VideoCaptureSeconds = 30
            WaitBeforeRecording = 3
            WaitAfterAttach = 5
            RecordBeforeLaunchDelay = 2
            DelayBetweenTests = 5
        }
    }
    
    # Try to load configuration file
    if ($ConfigPath -and (Test-Path $ConfigPath)) {
        try {
            $configContent = Get-Content $ConfigPath -Raw
            # Simple JSON parsing for constrained mode
            $config = $configContent | ConvertFrom-Json
            
            # Convert PSCustomObject to hashtables for easier access
            $loadedConfig = @{}
            foreach ($property in $config.PSObject.Properties) {
                if ($property.Value -is [PSCustomObject]) {
                    $loadedConfig[$property.Name] = @{}
                    foreach ($subProperty in $property.Value.PSObject.Properties) {
                        $loadedConfig[$property.Name][$subProperty.Name] = $subProperty.Value
                    }
                } else {
                    $loadedConfig[$property.Name] = $property.Value
                }
            }
            
            # Merge with defaults (loaded config takes precedence)
            foreach ($section in $defaultConfig.Keys) {
                if ($loadedConfig -and $loadedConfig.Keys -contains $section) {
                    foreach ($key in $defaultConfig[$section].Keys) {
                        if (-not ($loadedConfig[$section] -and $loadedConfig[$section].Keys -contains $key)) {
                            $loadedConfig[$section][$key] = $defaultConfig[$section][$key]
                        }
                    }
                } else {
                    $loadedConfig[$section] = $defaultConfig[$section]
                }
            }
            
            $config = $loadedConfig
        }
        catch {
            Write-Warning "Failed to load configuration from $ConfigPath. Using defaults. Error: $_"
            $config = $defaultConfig
        }
    } else {
        Write-Verbose "Configuration file not found at $ConfigPath. Using defaults."
        $config = $defaultConfig
    }
    
    # Return appropriate path set based on UseNetworkPaths flag
    if ($UseNetworkPaths -and $config.NetworkPaths) {
        # Merge network paths with framework paths
        foreach ($key in $config.NetworkPaths.Keys) {
            if ($config.FrameworkPaths -and $config.FrameworkPaths.Keys -contains $key) {
                $config.FrameworkPaths[$key] = $config.NetworkPaths[$key]
            }
        }
    }
    
    return $config
}

# Function to resolve framework path with fallback
function Resolve-FrameworkPath {
    param(
        [string]$PathType,
        [hashtable]$Config = $null,
        [string]$FallbackPath = ""
    )
    
    if (-not $Config) {
        $Config = Get-FrameworkConfig
    }
    
    # Try to get path from config
    $path = ""
    if ($Config.FrameworkPaths -and $Config.FrameworkPaths.Keys -contains $PathType) {
        $path = $Config.FrameworkPaths[$PathType]
    } elseif ($Config.DefaultPaths -and $Config.DefaultPaths.Keys -contains $PathType) {
        $path = $Config.DefaultPaths[$PathType]
    }
    
    # If path not found in config, use fallback
    if (-not $path -and $FallbackPath) {
        $path = $FallbackPath
    }
    
    # Convert relative paths to absolute if needed
    # Check if path is rooted without using System.IO.Path (constrained language mode)
    $isPathRooted = $false
    if ($path -and $path.Length -ge 2) {
        # Check for drive letter (C:) or UNC path (\\) or Unix path (/)
        if (($path.Length -ge 3 -and $path[1] -eq ':') -or 
            ($path.Length -ge 2 -and $path[0] -eq '\' -and $path[1] -eq '\') -or
            ($path[0] -eq '/')) {
            $isPathRooted = $true
        }
    }
    if ($path -and -not $isPathRooted) {
        # Handle case where MyInvocation.MyCommand.Path might be null
        $scriptPath = $MyInvocation.MyCommand.Path
        if ($scriptPath) {
            $scriptDir = Split-Path -Parent $scriptPath
            $rootDir = Split-Path -Parent $scriptDir
            $path = Join-Path $rootDir $path
        } else {
            # Fall back to current location or PSScriptRoot
            $currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
            # Try to find root by looking for MODULES folder
            while ($currentDir -and (Split-Path -Parent $currentDir)) {
                if (Test-Path (Join-Path $currentDir "MODULES")) {
                    $path = Join-Path $currentDir $path
                    break
                }
                $currentDir = Split-Path -Parent $currentDir
            }
            # If still relative, leave as-is
        }
    }
    
    return $path
}

# Helper function to get file size in constrained language mode
function Get-FileSizeConstrained {
    param([string]$FilePath)
    
    if (!(Test-Path $FilePath)) {
        return 0
    }
    
    # Use cmd.exe to get file size
    $output = cmd /c "for %I in (`"$FilePath`") do @echo %~zI" 2>$null
    
    if ($output) {
        try {
            return [long]$output
        } catch {
            return 0
        }
    }
    
    return 0
}

# Function to create safe filename (replace problematic characters)
function Get-SafeFileName {
    param([string]$Name)
    
    # Simple approach - replace common invalid characters
    $safeName = $Name
    $safeName = $safeName -replace '\\', '_'
    $safeName = $safeName -replace '/', '_'
    $safeName = $safeName -replace ':', '_'
    $safeName = $safeName -replace '\*', '_'
    $safeName = $safeName -replace '\?', '_'
    $safeName = $safeName -replace '"', '_'
    $safeName = $safeName -replace '<', '_'
    $safeName = $safeName -replace '>', '_'
    $safeName = $safeName -replace '\|', '_'
    $safeName = $safeName -replace ' ', '_'
    
    return $safeName
}

# Function to ensure FFmpeg is available locally
function Get-LocalFFmpeg {
    param(
        [string]$NetworkFFmpegPath,
        [string]$LocalFFmpegDir = (Join-Path $env:TEMP "FlexAppTesting")
    )
    
    Write-Host "Preparing FFmpeg..." -ForegroundColor Gray
    
    # First, check for locally installed FFmpeg (preferred for AppLocker environments)
    $commonLocalPaths = @(
        "C:\ffmpeg\bin\ffmpeg.exe",
        "C:\Program Files\ffmpeg\bin\ffmpeg.exe",
        "C:\Program Files (x86)\ffmpeg\bin\ffmpeg.exe",
        "$env:ProgramFiles\ffmpeg\bin\ffmpeg.exe",
        "${env:ProgramFiles(x86)}\ffmpeg\bin\ffmpeg.exe"
    )
    
    foreach ($localPath in $commonLocalPaths) {
        if (Test-Path $localPath) {
            Write-Host "Found local FFmpeg installation: $localPath" -ForegroundColor Green
            return $localPath
        }
    }
    
    # Check if FFmpeg is in PATH
    try {
        $ffmpegInPath = Get-Command "ffmpeg.exe" -ErrorAction SilentlyContinue
        if ($ffmpegInPath) {
            Write-Host "Found FFmpeg in PATH: $($ffmpegInPath.Source)" -ForegroundColor Green
            return $ffmpegInPath.Source
        }
    }
    catch {
        # Ignore errors - ffmpeg not in PATH
    }
    
    # Only proceed with network copy if no local installation found
    Write-Host "No local FFmpeg installation found. Checking network path..." -ForegroundColor Yellow
    
    # Check if network path looks like a network path (starts with \\)
    $isNetworkPath = $NetworkFFmpegPath -like "\\*"
    
    if (!$isNetworkPath) {
        # If it's already a local path, just return it
        if (Test-Path $NetworkFFmpegPath) {
            Write-Host "Using provided local FFmpeg path: $NetworkFFmpegPath" -ForegroundColor Green
            return $NetworkFFmpegPath
        } else {
            Write-Error "FFmpeg not found at: $NetworkFFmpegPath"
            return $null
        }
    }
    
    # Network path - copy to temp directory to work around AppLocker
    Write-Host "Network FFmpeg detected. Copying to local temp to avoid AppLocker issues..." -ForegroundColor Yellow
    
    if (!(Test-Path $LocalFFmpegDir)) {
        New-Item -ItemType Directory -Path $LocalFFmpegDir -Force | Out-Null
    }
    
    $localFFmpegPath = Join-Path $LocalFFmpegDir "ffmpeg.exe"
    
    # Check if we need to copy FFmpeg
    $needCopy = $false
    if (!(Test-Path $localFFmpegPath)) {
        $needCopy = $true
    } else {
        # Check if file is empty
        $size = Get-FileSizeConstrained -FilePath $localFFmpegPath
        if ($size -eq 0) {
            $needCopy = $true
        }
    }
    
    if ($needCopy) {
        if (Test-Path $NetworkFFmpegPath) {
            Write-Host "Copying FFmpeg to local directory..." -ForegroundColor Yellow
            try {
                Copy-Item -Path $NetworkFFmpegPath -Destination $localFFmpegPath -Force
                Write-Host "FFmpeg copied successfully to: $localFFmpegPath" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to copy FFmpeg: $_"
                Write-Host "Will attempt to use network path directly" -ForegroundColor Yellow
                return $NetworkFFmpegPath
            }
        }
        else {
            Write-Error "FFmpeg not found at: $NetworkFFmpegPath"
            return $null
        }
    }
    else {
        Write-Host "Using existing local FFmpeg copy: $localFFmpegPath" -ForegroundColor Green
    }
    
    return $localFFmpegPath
}

# Function to wait for process with timeout
function Wait-ForProcess {
    param(
        [string]$ProcessName,
        [int]$TimeoutSeconds = 60,
        [switch]$WaitForExit
    )
    
    $waitStart = Get-Date
    $processFound = $false
    
    if ($WaitForExit) {
        # Wait for process to NOT exist
        while ((Get-Process -Name $ProcessName -ErrorAction SilentlyContinue) -and 
               ((Get-Date) - $waitStart).TotalSeconds -lt $TimeoutSeconds) {
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 1
        }
        Write-Host "" # New line
        
        if (-not (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)) {
            return $true
        }
    }
    else {
        # Wait for process to exist
        while (-not $processFound -and ((Get-Date) - $waitStart).TotalSeconds -lt $TimeoutSeconds) {
            $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
            if ($processes) {
                $processFound = $true
                return $true
            }
            else {
                Start-Sleep -Milliseconds 500
            }
        }
    }
    
    return $false
}

# Function to create CSV manually in constrained mode
function Export-CsvConstrained {
    param(
        [string]$FilePath,
        [string[]]$Headers,
        [array]$Data
    )
    
    $csvContent = $Headers -join ','
    
    foreach ($row in $Data) {
        $rowData = @()
        foreach ($header in $Headers) {
            $value = $row.$header
            # Escape quotes and handle commas
            if ($value -match '[,"]') {
                $value = '"' + ($value -replace '"', '""') + '"'
            }
            $rowData += $value
        }
        $csvContent += "`n" + ($rowData -join ',')
    }
    
    $csvContent | Out-File -FilePath $FilePath -Encoding UTF8
}