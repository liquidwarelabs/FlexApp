# File: Functions\Winget\Populate-WingetUpdatesGrid.ps1
# ================================

function Populate-WingetUpdatesGrid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$UpdateCandidates
    )
    
    try {
        $updatesGrid = $script:MainForm.Controls.Find('WingetUpdatesGrid', $true)[0]
        if (-not $updatesGrid) {
            throw "Could not find WingetUpdatesGrid control"
        }
        
        $updatesGrid.Rows.Clear()
        
        foreach ($candidate in $UpdateCandidates) {
            $row = $updatesGrid.Rows.Add()
            $updatesGrid.Rows[$row].Cells["WingetSelected"].Value = $false
            $updatesGrid.Rows[$row].Cells["WingetName"].Value = $candidate.Name
            $updatesGrid.Rows[$row].Cells["WingetCurrentVersion"].Value = $candidate.CurrentVersion
            $updatesGrid.Rows[$row].Cells["WingetNewVersion"].Value = $candidate.NewVersion
            $updatesGrid.Rows[$row].Cells["WingetSizeMB"].Value = $candidate.SizeMB
            $updatesGrid.Rows[$row].Tag = $candidate
        }
        
        Write-LogMessage "Grid populated with $($UpdateCandidates.Count) items" -Level Info -Tab "Winget"
    }
    catch {
        Write-LogMessage "Error populating grid: $($_.Exception.Message)" -Level Error -Tab "Winget"
        throw
    }
}