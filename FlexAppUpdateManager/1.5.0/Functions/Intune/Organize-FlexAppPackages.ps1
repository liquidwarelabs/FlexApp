# Functions/Intune/Organize-FlexAppPackages.ps1
# Function to organize FlexApp packages for Intune processing

# Helper function for PowerShell 5.1 compatibility
function Invoke-Callback {
    param(
        [scriptblock]$Callback,
        [string]$Message
    )
    if ($Callback) {
        try {
            $Callback.Invoke($Message)
        } catch {
            # Silently ignore callback errors
        }
    }
}

function Organize-FlexAppPackages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFolder,
        
        [scriptblock]$LogCallback
    )

            try {
                $packages = @()
        
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Scanning source folder: $SourceFolder"

        # First, organize loose .exe files into folders
        $looseExes = Get-ChildItem -Path $SourceFolder -Filter "*.exe" -File
        foreach ($exe in $looseExes) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($exe.Name)
            $newFolder = Join-Path $SourceFolder $baseName
            $newExePath = Join-Path $newFolder $exe.Name

            if (-not (Test-Path $newFolder)) {
                New-Item -Path $newFolder -ItemType Directory -Force | Out-Null
                Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Created folder: $newFolder"
            }

            if (-not (Test-Path $newExePath)) {
                Move-Item -Path $exe.FullName -Destination $newExePath -Force
                Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Moved $($exe.Name) to $newFolder"
            }

            # Look for corresponding .fa1 file
            $fa1Path = Join-Path $SourceFolder "$baseName.fa1"
            if (Test-Path $fa1Path) {
                $newFa1Path = Join-Path $newFolder "$baseName.fa1"
                if (-not (Test-Path $newFa1Path)) {
                    Move-Item -Path $fa1Path -Destination $newFa1Path -Force
                    Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Moved $baseName.fa1 to $newFolder"
                }
            }
        }

                # Now process organized folders
                $appDirs = Get-ChildItem -Path $SourceFolder -Directory
                
                foreach ($dir in $appDirs) {
            $exeFile = Get-ChildItem -Path $dir.FullName -Filter "*.exe" -File | Select-Object -First 1
            if ($exeFile) {
                # Calculate size with timeout protection
                $packageSize = 0
                try {
                    Write-Host "DEBUG: Calculating size for $($dir.FullName)..." -ForegroundColor Cyan
                    $sizeJob = Start-Job -ScriptBlock {
                        param($Path)
                        (Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                    } -ArgumentList $dir.FullName
                    
                    # Wait for size calculation with 30 second timeout
                    $timeout = 30
                    $completed = Wait-Job -Job $sizeJob -Timeout $timeout
                    
                    if ($completed) {
                        $packageSize = Receive-Job -Job $sizeJob
                        Write-Host "DEBUG: Size calculation completed: $packageSize bytes" -ForegroundColor Green
                    } else {
                        Write-Host "WARNING: Size calculation timed out after $timeout seconds, using default size" -ForegroundColor Yellow
                        $packageSize = 100MB # Default size assumption
                    }
                    
                    Remove-Job -Job $sizeJob -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-Host "WARNING: Error calculating size: $($_.Exception.Message), using default size" -ForegroundColor Yellow
                    $packageSize = 100MB # Default size assumption
                }
                
                $package = @{
                    Name = [System.IO.Path]::GetFileNameWithoutExtension($exeFile.Name)
                    ExePath = $exeFile.FullName
                    ExeName = $exeFile.Name
                    FolderPath = $dir.FullName
                    Fa1Path = $null
                    Size = $packageSize
                }

                # Check for .fa1 file
                $fa1File = Get-ChildItem -Path $dir.FullName -Filter "*.fa1" -File | Select-Object -First 1
                if ($fa1File) {
                    $package.Fa1Path = $fa1File.FullName
                }

                # Check package size (Intune limit is 7.5GB)
                $maxSize = 7.5GB
                if ($package.Size -gt $maxSize) {
                    $sizeMB = [math]::Round($package.Size / 1MB, 2)
                    Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Skipping $($package.Name): Size is $sizeMB MB (limit is 7,500 MB)"
                    continue
                }

                $packages += $package
                Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Added package: $($package.Name)"
            }
        }

                Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Found $($packages.Count) packages ready for processing"
                
                # Ensure we return a proper array, even for single items
                # Use the comma operator to force array creation
                return ,$packages
    }
    catch {
        Write-Host "Error in Organize-FlexAppPackages: $($_.Exception.Message)" -ForegroundColor Red
        Invoke-Callback -Callback $LogCallback -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Error organizing packages: $($_.Exception.Message)"
        throw
    }
}
