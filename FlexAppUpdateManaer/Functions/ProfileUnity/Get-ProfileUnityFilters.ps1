function Get-ProfileUnityFilters {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Retrieving ProfileUnity filters..." -Level Info -Tab "ProfileUnity"
        
        $filtersUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/filter"
        $response = Invoke-WebRequest -Uri $filtersUri -WebSession $script:ChocoSession
        $filters = ($response.Content | ConvertFrom-Json).TAG.ROWS
        
        Write-LogMessage "Retrieved $($filters.Count) filters from ProfileUnity" -Level Info -Tab "ProfileUnity"
        return $filters
    }
    catch {
        Write-LogMessage "Failed to retrieve filters: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        throw
    }
}
