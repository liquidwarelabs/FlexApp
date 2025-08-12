# FlexApp-XML-Parser.ps1
# Functions for parsing FlexApp XML manifests

# Function to parse FlexApp XML and extract application information
function Get-FlexAppInfo {
    param([string]$VhdxPath)
    
    # Create XML path without using Substring
    $xmlPath = $VhdxPath
    if ($xmlPath -like "*.vhdx") {
        # Remove .vhdx extension (5 characters)
        $basePath = $VhdxPath -replace '\.vhdx$', ''
        $xmlPath = "$basePath.package.xml"
    } elseif ($xmlPath -like "*.vhd") {
        # Remove .vhd extension (4 characters)
        $basePath = $VhdxPath -replace '\.vhd$', ''
        $xmlPath = "$basePath.package.xml"
    }
    
    if (!(Test-Path $xmlPath)) {
        Write-Warning "Package XML not found at: $xmlPath"
        Write-Host "Attempting to find XML in parent directory..." -ForegroundColor Yellow
        
        # Try to find XML in the same directory
        $vhdxDir = Split-Path $VhdxPath -Parent
        $xmlFiles = Get-ChildItem -Path $vhdxDir -Filter "*.package.xml" | Select-Object -First 1
        
        if ($xmlFiles) {
            $xmlPath = $xmlFiles.FullName
            Write-Host "Found XML: $xmlPath" -ForegroundColor Green
        }
        else {
            throw "No package XML found for $VhdxPath"
        }
    }
    
    try {
        [xml]$packageXml = Get-Content $xmlPath
        
        $appInfo = @{
            DisplayName = $packageXml.Package.DisplayName
            PackageType = $packageXml.Package.PackageType
            Version = "$($packageXml.Package.VersionMajor).$($packageXml.Package.VersionMinor).$($packageXml.Package.VersionBuild).$($packageXml.Package.VersionRevision)"
            Links = @()
            HasExecutables = $false
        }
        
        # Extract all links (shortcuts) from the XML
        foreach ($link in $packageXml.Package.Links.Link) {
            $linkInfo = @{
                Location = $link.Location
                Target = $link.Target
                Arguments = $link.Arguments
                WorkingDirectory = $link.WorkingDirectory
                Description = $link.Description
            }
            $appInfo.Links += $linkInfo
            
            # Check if this is an executable link
            if ($link.Target -and $link.Target -like "*.exe") {
                $appInfo.HasExecutables = $true
            }
        }
        
        return $appInfo
    }
    catch {
        throw "Failed to parse package XML: $_"
    }
}

# Function to find the best executable to launch
function Get-BestExecutable {
    param($AppInfo)
    
    # Check if there are any executables
    if ($AppInfo.Links.Count -eq 0 -or -not $AppInfo.HasExecutables) {
        Write-Warning "No executable links found in package - this may be a library or configuration package"
        return $null
    }
    
    # Priority order for finding executables:
    # 1. Desktop shortcuts
    # 2. Start Menu shortcuts
    # 3. First available link
    
    $desktopLink = $AppInfo.Links | Where-Object { $_.Location -like "*Desktop*" -and $_.Target -like "*.exe" } | Select-Object -First 1
    $startMenuLink = $AppInfo.Links | Where-Object { $_.Location -like "*Start Menu*" -and $_.Target -like "*.exe" } | Select-Object -First 1
    $firstLink = $AppInfo.Links | Where-Object { $_.Target -like "*.exe" } | Select-Object -First 1
    
    if ($desktopLink) {
        return $desktopLink
    }
    elseif ($startMenuLink) {
        return $startMenuLink
    }
    elseif ($firstLink) {
        return $firstLink
    }
    else {
        Write-Warning "No executable links found in package"
        return $null
    }
}