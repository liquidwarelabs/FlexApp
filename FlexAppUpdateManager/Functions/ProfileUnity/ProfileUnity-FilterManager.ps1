# File: Functions\ProfileUnity\ProfileUnity-FilterManager.ps1
# ================================
# Functions for managing ProfileUnity filters

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

function Get-ProfileUnityFilterDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilterId
    )
    
    try {
        Write-LogMessage "Retrieving filter details for ID: $FilterId" -Level Info -Tab "ProfileUnity"
        
        $filterUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/filter/$FilterId"
        $response = Invoke-WebRequest -Uri $filterUri -WebSession $script:ChocoSession
        $filterData = ($response.Content | ConvertFrom-Json).tag
        
        Write-LogMessage "Retrieved filter details: $($filterData.name)" -Level Success -Tab "ProfileUnity"
        return $filterData
    }
    catch {
        Write-LogMessage "Failed to retrieve filter details: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        throw
    }
}

function Update-ProfileUnityFilter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Filter
    )
    
    try {
        Write-LogMessage "Updating filter: $($Filter.name)" -Level Info -Tab "ProfileUnity"
        
        $updateUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/filter"
        $body = $Filter | ConvertTo-Json -Depth 10
        
        $response = Invoke-WebRequest -Uri $updateUri -Method Post -WebSession $script:ChocoSession -ContentType "application/json" -Body $body
        
        if ($response.StatusCode -eq 200) {
            Write-LogMessage "Filter updated successfully" -Level Success -Tab "ProfileUnity"
            return $true
        } else {
            throw "Update failed with status code: $($response.StatusCode)"
        }
    }
    catch {
        Write-LogMessage "Failed to update filter: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        throw
    }
}

function Get-ProfileUnityFilterById {
    param([string]$FilterId)
    
    try {
        if ([string]::IsNullOrWhiteSpace($FilterId)) {
            return $null
        }
        
        # Use cached filters if available
        if ($script:PUAvailableFilters -and $script:PUAvailableFilters.Count -gt 0) {
            return $script:PUAvailableFilters | Where-Object { $_.id -eq $FilterId } | Select-Object -First 1
        }
        
        # Otherwise fetch from server
        $filters = Get-ProfileUnityFilters
        return $filters | Where-Object { $_.id -eq $FilterId } | Select-Object -First 1
    }
    catch {
        Write-LogMessage "Failed to get filter info: $($_.Exception.Message)" -Level Warning -Tab "ProfileUnity"
        return $null
    }
}

function Get-ProfileUnityFilterIdByName {
    param([string]$FilterName)
    
    try {
        if ([string]::IsNullOrWhiteSpace($FilterName)) {
            return $null
        }
        
        # Use cached filters if available
        if ($script:PUAvailableFilters -and $script:PUAvailableFilters.Count -gt 0) {
            $filter = $script:PUAvailableFilters | Where-Object { $_.Name -eq $FilterName } | Select-Object -First 1
            if ($filter) { 
                return $filter.id 
            } else { 
                return $null 
            }
        }
        
        # Otherwise fetch from server
        $filters = Get-ProfileUnityFilters
        $filter = $filters | Where-Object { $_.Name -eq $FilterName } | Select-Object -First 1
        if ($filter) { 
            return $filter.id 
        } else { 
            return $null 
        }
    }
    catch {
        Write-LogMessage "Failed to get filter ID by name: $($_.Exception.Message)" -Level Warning -Tab "ProfileUnity"
        return $null
    }
}

function Load-ProfileUnityFilters {
    [CmdletBinding()]
    param()
    
    try {
        $statusLabel = $script:MainForm.Controls.Find('PUStatusLabel', $true)[0]
        $updatesGrid = $script:MainForm.Controls.Find('PUUpdatesGrid', $true)[0]
        
        $statusLabel.Text = "Loading available filters..."
        Write-LogMessage "Loading ProfileUnity filters..." -Level Info -Tab "ProfileUnity"
        
        # Get all filters from ProfileUnity
        $filters = Get-ProfileUnityFilters
        
        # Store filters globally
        $script:PUAvailableFilters = $filters | Where-Object { $_.Name -ne $null }
        
        Write-LogMessage "Loaded $($script:PUAvailableFilters.Count) filters" -Level Info -Tab "ProfileUnity"
        
        # Get the filter column
        $filterColumn = $updatesGrid.Columns["PUFilter"]
        
        if ($filterColumn -and $filterColumn.GetType().Name -eq "DataGridViewComboBoxColumn") {
            # Clear existing items
            $filterColumn.Items.Clear()
            
            # Add empty option
            $filterColumn.Items.Add("")
            
            # Add all filter names
            foreach ($filter in $script:PUAvailableFilters) {
                $filterColumn.Items.Add($filter.Name)
            }
            
            # Update existing rows to have the dropdown populated
            foreach ($row in $updatesGrid.Rows) {
                $currentValue = $row.Cells["PUFilter"].Value
                # Ensure the current value exists in the dropdown
                if ($currentValue -and -not $filterColumn.Items.Contains($currentValue)) {
                    $filterColumn.Items.Add($currentValue)
                }
            }
            
            $statusLabel.Text = "Filters loaded - you can now edit the filter assignments"
            Write-LogMessage "Filter dropdowns populated successfully" -Level Success -Tab "ProfileUnity"
        } else {
            throw "Filter column not found or is not a ComboBox column"
        }
        
    }
    catch {
        Write-LogMessage "Failed to load filters: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        $statusLabel.Text = "Failed to load filters"
        [System.Windows.Forms.MessageBox]::Show("Failed to load filters: $($_.Exception.Message)", "Error", "OK", "Error")
    }
}