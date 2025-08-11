function Get-ChocolateyPackageVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PackageName
    )
    
    try {
        # Use choco search to find available packages in the repository
        $searchOutput = choco search $PackageName --limitoutput 2>$null
        if ($searchOutput) {
            # Parse the search results to find exact matches
            $lines = $searchOutput -split "`n" | Where-Object { $_ -match '\|' }
            foreach ($line in $lines) {
                $parts = $line -split '\|'
                $foundPackage = $parts[0].Trim()
                $foundVersion = $parts[1].Trim()
                
                # Look for exact match first
                if ($foundPackage -eq $PackageName) {
                    Write-LogMessage "Found exact Chocolatey package '$foundPackage' version: $foundVersion" -Level Info -Tab "Chocolatey"
                    return $foundVersion
                }
            }
            
            # If no exact match, try case-insensitive match
            foreach ($line in $lines) {
                $parts = $line -split '\|'
                $foundPackage = $parts[0].Trim()
                $foundVersion = $parts[1].Trim()
                
                if ($foundPackage -eq $PackageName -or 
                    $foundPackage.ToLower() -eq $PackageName.ToLower()) {
                    Write-LogMessage "Found case-insensitive match for Chocolatey package '$foundPackage' version: $foundVersion" -Level Info -Tab "Chocolatey"
                    return $foundVersion
                }
            }
        }
        
        Write-LogMessage "Failed to find Chocolatey package '$PackageName' in repository" -Level Warning -Tab "Chocolatey"
        return $null
    }
    catch {
        Write-LogMessage "Failed to find Chocolatey package '$PackageName': $($_.Exception.Message)" -Level Warning -Tab "Chocolatey"
        return $null
    }
}