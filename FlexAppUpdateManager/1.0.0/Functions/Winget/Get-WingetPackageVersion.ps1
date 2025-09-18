# File: Functions\Winget\Get-WingetPackageVersion.ps1
# ================================

function Get-WingetPackageVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PackageId
    )
    
    try {
        # Check if winget is available
        $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $wingetPath) {
            Write-LogMessage "Winget not found in PATH" -Level Warning -Tab "Winget"
            return $null
        }
        
        Write-LogMessage "Searching for package: $PackageId" -Level Info -Tab "Winget"
        
        # Use winget show to get exact package info
        # Redirect stderr to stdout and capture all output
        $showOutput = & winget show --id $PackageId --accept-source-agreements 2>&1
        
        # Check if package was found
        $packageFound = $false
        $version = $null
        
        # Convert output to string array if needed
        if ($showOutput -is [System.Management.Automation.ErrorRecord]) {
            Write-LogMessage "Package '$PackageId' not found in Winget" -Level Warning -Tab "Winget"
            return $null
        }
        
        $outputLines = @()
        if ($showOutput -is [string]) {
            $outputLines = $showOutput -split "`r?`n"
        } else {
            $outputLines = $showOutput | Out-String -Stream
        }
        
        # Parse the output looking for version
        foreach ($line in $outputLines) {
            # Look for version line in winget show output
            # Winget uses "ShowLabelVersion" in its output
            if ($line -match '^\s*ShowLabelVersion\s+(.+?)\s*$' -or 
                $line -match '^\s*Version:\s*(.+?)\s*$') {
                $version = $Matches[1].Trim()
                $packageFound = $true
                Write-LogMessage "Found version through show command: $version" -Level Info -Tab "Winget"
                break
            }
        }
        
        # If not found with show, try list with exact ID
        if (-not $packageFound) {
            Write-LogMessage "Trying list command for package: $PackageId" -Level Info -Tab "Winget"
            
            # Use list to find exact package
            $listOutput = & winget list --id $PackageId --exact --accept-source-agreements 2>&1
            
            if ($listOutput -and $listOutput -notlike "*No installed package*") {
                $outputLines = @()
                if ($listOutput -is [string]) {
                    $outputLines = $listOutput -split "`r?`n"
                } else {
                    $outputLines = $listOutput | Out-String -Stream
                }
                
                # Skip header lines and find the package
                $foundHeader = $false
                foreach ($line in $outputLines) {
                    # Skip until we find the header line with dashes
                    if ($line -match '^-+\s+-+\s+-+') {
                        $foundHeader = $true
                        continue
                    }
                    
                    if ($foundHeader -and $line.Trim() -ne "") {
                        # Parse the line - format is: Name ID Version Available Source
                        # Split by multiple spaces to handle spacing
                        $parts = $line -split '\s{2,}' | Where-Object { $_.Trim() -ne "" }
                        
                        if ($parts.Count -ge 3) {
                            # Check if this line contains our package ID
                            foreach ($part in $parts) {
                                if ($part -eq $PackageId) {
                                    # Find the version (usually after the ID)
                                    $idIndex = [array]::IndexOf($parts, $part)
                                    if ($idIndex -lt $parts.Count - 1) {
                                        $potentialVersion = $parts[$idIndex + 1]
                                        # Check if it looks like a version
                                        if ($potentialVersion -match '[\d\.]') {
                                            $version = $potentialVersion
                                            $packageFound = $true
                                            Write-LogMessage "Found version through list command: $version" -Level Info -Tab "Winget"
                                            break
                                        }
                                    }
                                }
                            }
                        }
                        
                        if ($packageFound) { break }
                    }
                }
            }
        }
        
        # If still not found, try search as last resort
        if (-not $packageFound) {
            Write-LogMessage "Trying search command for package: $PackageId" -Level Info -Tab "Winget"
            
            $searchOutput = & winget search --id $PackageId --exact --accept-source-agreements 2>&1
            
            if ($searchOutput -and $searchOutput -notlike "*No package*") {
                $outputLines = @()
                if ($searchOutput -is [string]) {
                    $outputLines = $searchOutput -split "`r?`n"
                } else {
                    $outputLines = $searchOutput | Out-String -Stream
                }
                
                # Skip header lines and find the package
                $foundHeader = $false
                foreach ($line in $outputLines) {
                    # Skip until we find the header line with dashes
                    if ($line -match '^-+\s+-+\s+-+') {
                        $foundHeader = $true
                        continue
                    }
                    
                    if ($foundHeader -and $line.Trim() -ne "") {
                        # Check if line contains exact package ID
                        if ($line -match "\s$([regex]::Escape($PackageId))\s") {
                            # Parse the line - format is: Name ID Version Match/Source
                            $parts = $line -split '\s{2,}' | Where-Object { $_.Trim() -ne "" }
                            
                            if ($parts.Count -ge 3) {
                                # Find the ID in parts and get next element as version
                                for ($i = 0; $i -lt $parts.Count; $i++) {
                                    if ($parts[$i] -eq $PackageId -and $i -lt $parts.Count - 1) {
                                        $potentialVersion = $parts[$i + 1]
                                        # Check if it looks like a version
                                        if ($potentialVersion -match '^[\d\.]+') {
                                            $version = $potentialVersion
                                            $packageFound = $true
                                            Write-LogMessage "Found version through search command: $version" -Level Info -Tab "Winget"
                                            break
                                        }
                                    }
                                }
                            }
                        }
                        
                        if ($packageFound) { break }
                    }
                }
            }
        }
        
        if ($packageFound -and $version) {
            Write-LogMessage "Successfully found version $version for package '$PackageId'" -Level Success -Tab "Winget"
            return $version
        } else {
            Write-LogMessage "Could not find package '$PackageId' in any Winget source" -Level Warning -Tab "Winget"
            return $null
        }
    }
    catch {
        Write-LogMessage "Error getting Winget package version for '$PackageId': $($_.Exception.Message)" -Level Error -Tab "Winget"
        return $null
    }
}