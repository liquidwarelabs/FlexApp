# Functions/Intune/New-IntunePackage.ps1
# Function to wrap FlexApp packages into .intunewin format using IntuneWin32App module's built-in function

# Helper function for PowerShell 5.1 compatibility
function Invoke-Callback {
    param(
        [scriptblock]$Callback,
        [string]$Message
    )
    if ($Callback) {
        try {
            $null = $Callback.Invoke($Message)
        } catch {
            # Silently ignore callback errors
        }
    }
}

function New-IntunePackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Package,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputFolder,
        
        [Parameter(Mandatory = $false)]
        [string]$IntuneToolPath,  # Path to IntuneWinAppUtil.exe (optional - module will download if not provided)
        
        [scriptblock]$LogCallback
    )

    try {
        $packageName = $Package.Name
        $exeName = $Package.ExeName
        $folderPath = $Package.FolderPath
        $expectedOutput = Join-Path $OutputFolder "$packageName.intunewin"
        
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Wrapping package: $packageName"

        # Remove existing .intunewin file if it exists
        if (Test-Path $expectedOutput) {
            Remove-Item -Path $expectedOutput -Force
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Removed existing .intunewin file: $packageName"
        }

        # Verify the executable file exists before proceeding
        Write-Host "DEBUG: Verifying executable file exists..." -ForegroundColor Cyan
        Write-Host "DEBUG: Looking for: $($Package.ExePath)" -ForegroundColor Cyan
        if (-not (Test-Path $Package.ExePath)) {
            Write-Host "ERROR: Executable file not found: $($Package.ExePath)" -ForegroundColor Red
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: Executable file not found: $($Package.ExePath)"
            
            # List all files in the folder to see what's actually there
            Write-Host "DEBUG: Files in source folder:" -ForegroundColor Yellow
            Get-ChildItem -Path $folderPath | ForEach-Object {
                Write-Host "  - $($_.Name)" -ForegroundColor Gray
            }
            
            return $null
        }
        
        Write-Host "DEBUG: Executable file verified: $($Package.ExePath)" -ForegroundColor Green

        # Use the IntuneWin32App module's built-in New-IntuneWin32AppPackage function
            Write-Host "Using IntuneWin32App module's built-in New-IntuneWin32AppPackage function..." -ForegroundColor Cyan
            Write-Host "DEBUG: Will rename output file to: $packageName.intunewin" -ForegroundColor Cyan
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Using IntuneWin32App module's built-in packaging function, will rename to: $packageName.intunewin"
        
        try {
            # Create a placeholder file to ensure correct internal filename
            $placeholderFileName = "$packageName.intunewin"
            $placeholderFilePath = Join-Path $folderPath $placeholderFileName
            
            Write-Host "Creating placeholder file for correct internal naming: $placeholderFileName" -ForegroundColor Cyan
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Creating placeholder file: $placeholderFileName"
            
            # Create a simple placeholder file
            "FlexApp Package: $packageName" | Out-File -FilePath $placeholderFilePath -Encoding UTF8
            
            # Call the module's built-in function with the placeholder as setup file
            $packageParams = @{
                SourceFolder = $folderPath
                SetupFile = $placeholderFileName
                OutputFolder = $OutputFolder
                Force = $true
                Verbose = $true
            }
            
            # Add IntuneWinAppUtilPath if provided
            if ($IntuneToolPath -and (Test-Path $IntuneToolPath)) {
                $packageParams.IntuneWinAppUtilPath = $IntuneToolPath
                Write-Host "Using specified IntuneWinAppUtil.exe path: $IntuneToolPath" -ForegroundColor Cyan
            } else {
                Write-Host "IntuneWinAppUtil.exe path not specified or not found, module will download automatically" -ForegroundColor Yellow
            }
            
            $packageResult = New-IntuneWin32AppPackage @packageParams
            
            # Clean up the placeholder file
            if (Test-Path $placeholderFilePath) {
                Remove-Item -Path $placeholderFilePath -Force
                Write-Host "Cleaned up placeholder file: $placeholderFileName" -ForegroundColor Green
            }
            
            # Handle the module's output file location and naming
            if ($packageResult -and $packageResult.Path) {
                $actualOutputPath = $packageResult.Path
                $desiredOutputPath = $expectedOutput
                
                Write-Host "DEBUG: Module created file at: $actualOutputPath" -ForegroundColor Cyan
                Write-Host "DEBUG: Desired location: $desiredOutputPath" -ForegroundColor Cyan
                
                if ($actualOutputPath -ne $desiredOutputPath -and (Test-Path $actualOutputPath)) {
                    Write-Host "DEBUG: Moving file from module's location to desired location..." -ForegroundColor Cyan
                    Write-Host "DEBUG: From: $actualOutputPath" -ForegroundColor Gray
                    Write-Host "DEBUG: To: $desiredOutputPath" -ForegroundColor Gray
                    
                    # Remove existing file if it exists
                    if (Test-Path $desiredOutputPath) {
                        Remove-Item -Path $desiredOutputPath -Force
                        Write-Host "DEBUG: Removed existing file at destination" -ForegroundColor Gray
                    }
                    
                    # Move the file to the desired location with the correct name
                    try {
                        Move-Item -Path $actualOutputPath -Destination $desiredOutputPath -Force
                        Write-Host "SUCCESS: Moved file to: $desiredOutputPath" -ForegroundColor Green
                        
                        # Verify the move was successful
                        if (Test-Path $desiredOutputPath) {
                            Write-Host "DEBUG: Verified file exists at destination: $desiredOutputPath" -ForegroundColor Green
                        } else {
                            Write-Host "ERROR: File move failed - destination file not found" -ForegroundColor Red
                        }
                        
                        # Update the package result path
                        $packageResult.Path = $desiredOutputPath
                    } catch {
                        Write-Host "ERROR: Failed to move file: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "DEBUG: Keeping original path: $actualOutputPath" -ForegroundColor Yellow
                    }
                    
                    # Clean up any empty directories left behind
                    $actualDir = Split-Path $actualOutputPath -Parent
                    if (Test-Path $actualDir -PathType Container) {
                        try {
                            $items = Get-ChildItem -Path $actualDir -Force
                            if ($items.Count -eq 0) {
                                Remove-Item -Path $actualDir -Force -ErrorAction SilentlyContinue
                                Write-Host "DEBUG: Cleaned up empty directory: $actualDir" -ForegroundColor Gray
                            }
                        } catch {
                            # Ignore cleanup errors
                        }
                    }
                } else {
                    Write-Host "DEBUG: File already at correct location: $actualOutputPath" -ForegroundColor Green
                }
            }
            
            if ($packageResult) {
                Write-Host "SUCCESS: Package created using IntuneWin32App module!" -ForegroundColor Green
                Write-Host "Package Details:" -ForegroundColor Cyan
                Write-Host "  Name: $($packageResult.Name)" -ForegroundColor Gray
                Write-Host "  FileName: $($packageResult.FileName)" -ForegroundColor Gray
                Write-Host "  SetupFile: $($packageResult.SetupFile)" -ForegroundColor Gray
                Write-Host "  UnencryptedContentSize: $($packageResult.UnencryptedContentSize)" -ForegroundColor Gray
                Write-Host "  Path: $($packageResult.Path)" -ForegroundColor Gray
                
                Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SUCCESS: Package created using IntuneWin32App module"
                
                # Return package hashtable with the .intunewin file path
                $packageHashtable = @{
                    Name = $packageName
                    IntuneWinPath = $packageResult.Path
                    ExeName = $exeName
                    Size = $packageResult.UnencryptedContentSize
                    ModuleResult = $packageResult  # Include the full module result for additional metadata
                }
                
                # Verify the file was actually created at the location returned by the module
                if (Test-Path $packageResult.Path) {
                    Write-Host "DEBUG: Verified .intunewin file exists at: $($packageResult.Path)" -ForegroundColor Green
                    $fileSize = (Get-Item $packageResult.Path).Length
                    Write-Host "DEBUG: File size: $fileSize bytes" -ForegroundColor Gray
                } else {
                    Write-Host "ERROR: .intunewin file not found at module-returned location: $($packageResult.Path)" -ForegroundColor Red
                    return $null
                }
                
                Write-Host "DEBUG: Returning package hashtable for: $packageName" -ForegroundColor Cyan
                return $packageHashtable
                
            } else {
                Write-Host "ERROR: New-IntuneWin32AppPackage returned null" -ForegroundColor Red
                Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: New-IntuneWin32AppPackage returned null"
                return $null
            }
            
        } catch {
            Write-Host "ERROR: Failed to create package using IntuneWin32App module: $($_.Exception.Message)" -ForegroundColor Red
            Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: Failed to create package using IntuneWin32App module: $($_.Exception.Message)"
            return $null
        }
                
    } catch {
        Write-Host "ERROR: Failed to wrap package: $($_.Exception.Message)" -ForegroundColor Red
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: Failed to wrap package: $($_.Exception.Message)"
        return $null
    }
}