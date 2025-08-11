# File: Functions\Chocolatey\Populate-ChocoUpdatesGrid.ps1
# ================================

function Populate-ChocoUpdatesGrid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$UpdateCandidates
    )
    
    try {
        $updatesGrid = $script:MainForm.Controls.Find('ChocoUpdatesGrid', $true)[0]
        if (-not $updatesGrid) {
            throw "Could not find ChocoUpdatesGrid control"
        }
        
        $updatesGrid.Rows.Clear()
        
        foreach ($candidate in $UpdateCandidates) {
            $row = $updatesGrid.Rows.Add()
            $updatesGrid.Rows[$row].Cells["ChocoSelected"].Value = $false
            $updatesGrid.Rows[$row].Cells["ChocoName"].Value = $candidate.Name
            $updatesGrid.Rows[$row].Cells["ChocoCurrentVersion"].Value = $candidate.CurrentVersion
            $updatesGrid.Rows[$row].Cells["ChocoNewVersion"].Value = $candidate.NewVersion
            $updatesGrid.Rows[$row].Cells["ChocoSizeMB"].Value = $candidate.SizeMB
            $updatesGrid.Rows[$row].Tag = $candidate
        }
        
        Write-LogMessage "Grid populated with $($UpdateCandidates.Count) items" -Level Info -Tab "Chocolatey"
    }
    catch {
        Write-LogMessage "Error populating grid: $($_.Exception.Message)" -Level Error -Tab "Chocolatey"
        throw
    }
}
