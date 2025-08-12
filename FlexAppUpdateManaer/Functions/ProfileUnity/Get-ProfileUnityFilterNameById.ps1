function Get-ProfileUnityFilterNameById {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$FilterId
    )
    
    try {
        if ([string]::IsNullOrWhiteSpace($FilterId)) {
            return "No Filter"
        }
        
        # Use cached filters if available
        if ($script:PUAvailableFilters -and $script:PUAvailableFilters.Count -gt 0) {
            $filter = $script:PUAvailableFilters | Where-Object { $_.id -eq $FilterId } | Select-Object -First 1
            if ($filter) {
                return $filter.name
            }
        }
        
        # Otherwise fetch from server
        $filters = Get-ProfileUnityFilters
        $filter = $filters | Where-Object { $_.id -eq $FilterId } | Select-Object -First 1
        if ($filter) {
            return $filter.name
        }
        
        return "No Filter"
    }
    catch {
        Write-LogMessage "Failed to get filter name for ID $FilterId`: $($_.Exception.Message)" -Level Warning -Tab "ProfileUnity"
        return "No Filter"
    }
}
