# File: Functions\ProfileUnity\ProfileUnity-FilterDialog.ps1
# ================================
# Comprehensive filter management dialog for ProfileUnity

function Show-FilterManagementDialog {
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Opening filter management dialog..." -Level Info -Tab "ProfileUnity"
        
        # Check if we have a current configuration
        if (-not $script:PUCurrentConfig) {
            [System.Windows.Forms.MessageBox]::Show("Please scan a configuration first", "No Configuration", "OK", "Warning")
            return
        }
        
        # Create the management form
        $filterForm = New-Object System.Windows.Forms.Form
        $filterForm.Text = "Filter Management - $($script:PUCurrentConfig.Name)"
        $filterForm.Size = New-Object System.Drawing.Size(900, 600)
        $filterForm.StartPosition = "CenterScreen"
        $filterForm.MaximizeBox = $false
        $filterForm.MinimizeBox = $false
        $filterForm.FormBorderStyle = "Sizable"
        
        # Create splitter container
        $splitContainer = New-Object System.Windows.Forms.SplitContainer
        $splitContainer.Dock = "Fill"
        $splitContainer.Orientation = "Vertical"
        $splitContainer.SplitterDistance = 300
        
        # Left panel - Filter list
        $filterListPanel = New-Object System.Windows.Forms.Panel
        $filterListPanel.Dock = "Fill"
        
        $filterListLabel = New-Object System.Windows.Forms.Label
        $filterListLabel.Text = "Filters in Configuration:"
        $filterListLabel.Location = New-Object System.Drawing.Point(5, 5)
        $filterListLabel.Size = New-Object System.Drawing.Size(290, 20)
        $filterListLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
        
        $filterListBox = New-Object System.Windows.Forms.ListBox
        $filterListBox.Location = New-Object System.Drawing.Point(5, 30)
        $filterListBox.Size = New-Object System.Drawing.Size(290, 480)
        $filterListBox.SelectionMode = "One"
        
        # Right panel - Filter details
        $detailsPanel = New-Object System.Windows.Forms.Panel
        $detailsPanel.Dock = "Fill"
        
        $detailsLabel = New-Object System.Windows.Forms.Label
        $detailsLabel.Text = "Filter Details and FlexApp Assignments:"
        $detailsLabel.Location = New-Object System.Drawing.Point(5, 5)
        $detailsLabel.Size = New-Object System.Drawing.Size(580, 20)
        $detailsLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
        
        # Filter info group
        $filterInfoGroup = New-Object System.Windows.Forms.GroupBox
        $filterInfoGroup.Text = "Filter Information"
        $filterInfoGroup.Location = New-Object System.Drawing.Point(5, 30)
        $filterInfoGroup.Size = New-Object System.Drawing.Size(580, 100)
        
        $nameLabel = New-Object System.Windows.Forms.Label
        $nameLabel.Text = "Name:"
        $nameLabel.Location = New-Object System.Drawing.Point(10, 25)
        $nameLabel.Size = New-Object System.Drawing.Size(50, 20)
        
        $nameTextBox = New-Object System.Windows.Forms.TextBox
        $nameTextBox.Location = New-Object System.Drawing.Point(70, 23)
        $nameTextBox.Size = New-Object System.Drawing.Size(250, 20)
        $nameTextBox.ReadOnly = $true
        
        $typeLabel = New-Object System.Windows.Forms.Label
        $typeLabel.Text = "Type:"
        $typeLabel.Location = New-Object System.Drawing.Point(330, 25)
        $typeLabel.Size = New-Object System.Drawing.Size(40, 20)
        
        $typeTextBox = New-Object System.Windows.Forms.TextBox
        $typeTextBox.Location = New-Object System.Drawing.Point(380, 23)
        $typeTextBox.Size = New-Object System.Drawing.Size(180, 20)
        $typeTextBox.ReadOnly = $true
        
        $descLabel = New-Object System.Windows.Forms.Label
        $descLabel.Text = "Description:"
        $descLabel.Location = New-Object System.Drawing.Point(10, 55)
        $descLabel.Size = New-Object System.Drawing.Size(70, 20)
        
        $descTextBox = New-Object System.Windows.Forms.TextBox
        $descTextBox.Location = New-Object System.Drawing.Point(85, 53)
        $descTextBox.Size = New-Object System.Drawing.Size(475, 20)
        
        $filterInfoGroup.Controls.AddRange(@($nameLabel, $nameTextBox, $typeLabel, $typeTextBox, $descLabel, $descTextBox))
        
        # FlexApp assignments grid
        $flexAppGrid = New-Object System.Windows.Forms.DataGridView
        $flexAppGrid.Location = New-Object System.Drawing.Point(5, 140)
        $flexAppGrid.Size = New-Object System.Drawing.Size(580, 330)
        $flexAppGrid.AllowUserToAddRows = $false
        $flexAppGrid.AllowUserToDeleteRows = $false
        $flexAppGrid.ReadOnly = $false
        $flexAppGrid.SelectionMode = "FullRowSelect"
        $flexAppGrid.MultiSelect = $true
        
        # Add columns
        $selectCol = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
        $selectCol.Name = "Select"
        $selectCol.HeaderText = "Update"
        $selectCol.Width = 60
        
        $nameCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $nameCol.Name = "FlexAppName"
        $nameCol.HeaderText = "FlexApp Name"
        $nameCol.Width = 200
        $nameCol.ReadOnly = $true
        
        $currentVerCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $currentVerCol.Name = "CurrentVersion"
        $currentVerCol.HeaderText = "Current Version"
        $currentVerCol.Width = 100
        $currentVerCol.ReadOnly = $true
        
        $newVerCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $newVerCol.Name = "NewVersion"
        $newVerCol.HeaderText = "Latest Version"
        $newVerCol.Width = 100
        $newVerCol.ReadOnly = $true
        
        $statusCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $statusCol.Name = "Status"
        $statusCol.HeaderText = "Status"
        $statusCol.Width = 100
        $statusCol.ReadOnly = $true
        
        [void]$flexAppGrid.Columns.Add($selectCol)
        [void]$flexAppGrid.Columns.Add($nameCol)
        [void]$flexAppGrid.Columns.Add($currentVerCol)
        [void]$flexAppGrid.Columns.Add($newVerCol)
        [void]$flexAppGrid.Columns.Add($statusCol)
        
        # Action buttons
        $updateSelectedBtn = New-Object System.Windows.Forms.Button
        $updateSelectedBtn.Text = "Update Selected"
        $updateSelectedBtn.Location = New-Object System.Drawing.Point(5, 480)
        $updateSelectedBtn.Size = New-Object System.Drawing.Size(110, 25)
        $updateSelectedBtn.Enabled = $false
        
        $selectAllUpdatesBtn = New-Object System.Windows.Forms.Button
        $selectAllUpdatesBtn.Text = "Select All Updates"
        $selectAllUpdatesBtn.Location = New-Object System.Drawing.Point(125, 480)
        $selectAllUpdatesBtn.Size = New-Object System.Drawing.Size(120, 25)
        $selectAllUpdatesBtn.Enabled = $false
        
        # Add controls to panels
        $filterListPanel.Controls.AddRange(@($filterListLabel, $filterListBox))
        $detailsPanel.Controls.AddRange(@($detailsLabel, $filterInfoGroup, $flexAppGrid, $updateSelectedBtn, $selectAllUpdatesBtn))
        
        $splitContainer.Panel1.Controls.Add($filterListPanel)
        $splitContainer.Panel2.Controls.Add($detailsPanel)
        
        # Bottom buttons
        $bottomPanel = New-Object System.Windows.Forms.Panel
        $bottomPanel.Height = 50
        $bottomPanel.Dock = "Bottom"
        
        $saveBtn = New-Object System.Windows.Forms.Button
        $saveBtn.Text = "Save All Changes"
        $saveBtn.Location = New-Object System.Drawing.Point(580, 10)
        $saveBtn.Size = New-Object System.Drawing.Size(120, 30)
        $saveBtn.Enabled = $false
        
        $closeBtn = New-Object System.Windows.Forms.Button
        $closeBtn.Text = "Close"
        $closeBtn.Location = New-Object System.Drawing.Point(710, 10)
        $closeBtn.Size = New-Object System.Drawing.Size(80, 30)
        $closeBtn.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        
        $bottomPanel.Controls.AddRange(@($saveBtn, $closeBtn))
        
        # Populate filter list
        $configFilters = @()
        $filterData = @{}
        
        # Ensure we have the available filters
        if (-not $script:PUAvailableFilters -or $script:PUAvailableFilters.Count -eq 0) {
            $script:PUAvailableFilters = Get-ProfileUnityFilters
        }
        
        if ($script:PUCurrentConfig -and $script:PUCurrentConfig.FlexAppDias) {
            $usedFilterIds = $script:PUCurrentConfig.FlexAppDias | 
                Where-Object { $_.FilterId } | 
                Select-Object -ExpandProperty FilterId -Unique
            
            foreach ($filterId in $usedFilterIds) {
                $filter = $script:PUAvailableFilters | Where-Object { $_.id -eq $filterId }
                if ($filter) {
                    $configFilters += $filter
                    $displayText = "$($filter.Name) - $($filter.FilterTypeName)"
                    [void]$filterListBox.Items.Add($displayText)
                    $filterData[$displayText] = $filter
                }
            }
        }
        
        # Track changes
        $configChanges = $false
        $filterChanges = @{}
        
        # Event handlers
        $filterListBox.Add_SelectedIndexChanged({
            if ($filterListBox.SelectedIndex -ge 0) {
                $selectedFilter = $filterData[$filterListBox.SelectedItem]
                if ($selectedFilter) {
                    # Update filter info
                    $nameTextBox.Text = $selectedFilter.Name
                    $typeTextBox.Text = $selectedFilter.FilterTypeName
                    $descTextBox.Text = if ($selectedFilter.Description) { $selectedFilter.Description } else { "" }
                    
                    # Load FlexApp assignments
                    $flexAppGrid.Rows.Clear()
                    $updateSelectedBtn.Enabled = $false
                    $selectAllUpdatesBtn.Enabled = $false
                    
                    $dias = $script:PUCurrentConfig.FlexAppDias | Where-Object { $_.FilterId -eq $selectedFilter.id }
                    $hasUpdates = $false
                    
                    foreach ($dia in $dias) {
                        if ($dia.FlexAppPackages) {
                            foreach ($package in $dia.FlexAppPackages) {
                                $inventoryPackage = $script:PUFlexAppInventory | Where-Object { 
                                    $_.id -eq $package.FlexAppPackageId -or $_.uuid -eq $package.FlexAppPackageUuid 
                                }
                                
                                if ($inventoryPackage) {
                                    $packageName = $inventoryPackage.name
                                    $currentVersion = "$($inventoryPackage.VersionMajor).$($inventoryPackage.VersionMinor).$($inventoryPackage.VersionBuild).$($inventoryPackage.VersionRevision)"
                                    
                                    # Find latest version
                                    $allVersions = $script:PUFlexAppInventory | Where-Object { $_.name -eq $packageName }
                                    $latestPackage = $allVersions | Sort-Object {
                                        [version]"$($_.VersionMajor).$($_.VersionMinor).$($_.VersionBuild).$($_.VersionRevision)"
                                    } -Descending | Select-Object -First 1
                                    
                                    $latestVersion = "$($latestPackage.VersionMajor).$($latestPackage.VersionMinor).$($latestPackage.VersionBuild).$($latestPackage.VersionRevision)"
                                    $updateAvailable = ([version]$currentVersion -lt [version]$latestVersion)
                                    
                                    $row = $flexAppGrid.Rows.Add()
                                    $flexAppGrid.Rows[$row].Cells["Select"].Value = $false
                                    $flexAppGrid.Rows[$row].Cells["FlexAppName"].Value = $packageName
                                    $flexAppGrid.Rows[$row].Cells["CurrentVersion"].Value = $currentVersion
                                    $flexAppGrid.Rows[$row].Cells["NewVersion"].Value = $latestVersion
                                    $flexAppGrid.Rows[$row].Cells["Status"].Value = if ($updateAvailable) { "Update Available" } else { "Up to Date" }
                                    
                                    if ($updateAvailable) {
                                        $flexAppGrid.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::LightYellow
                                        $hasUpdates = $true
                                    }
                                    
                                    # Store metadata in tag
                                    $flexAppGrid.Rows[$row].Tag = @{
                                        Package = $package
                                        LatestPackage = $latestPackage
                                        Dia = $dia
                                        UpdateAvailable = $updateAvailable
                                    }
                                }
                            }
                        }
                    }
                    
                    if ($hasUpdates) {
                        $updateSelectedBtn.Enabled = $true
                        $selectAllUpdatesBtn.Enabled = $true
                    }
                }
            }
        })
        
        $selectAllUpdatesBtn.Add_Click({
            foreach ($row in $flexAppGrid.Rows) {
                if ($row.Tag.UpdateAvailable) {
                    $row.Cells["Select"].Value = $true
                }
            }
        })
        
        $updateSelectedBtn.Add_Click({
            $updatedCount = 0
            foreach ($row in $flexAppGrid.Rows) {
                if ($row.Cells["Select"].Value -eq $true -and $row.Tag.UpdateAvailable) {
                    $metadata = $row.Tag
                    
                    # Update the package reference
                    $metadata.Package.FlexAppPackageId = $metadata.LatestPackage.id
                    $metadata.Package.FlexAppPackageUuid = $metadata.LatestPackage.uuid
                    
                    # Update display
                    $row.Cells["CurrentVersion"].Value = $row.Cells["NewVersion"].Value
                    $row.Cells["Status"].Value = "Updated"
                    $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightGreen
                    $row.Cells["Select"].Value = $false
                    $updatedCount++
                    
                    $configChanges = $true
                }
            }
            
            if ($updatedCount -gt 0) {
                $saveBtn.Enabled = $true
                [System.Windows.Forms.MessageBox]::Show("Updated $updatedCount FlexApp(s) in filter", "Updates Applied", "OK", "Information")
            }
        })
        
        $descTextBox.Add_TextChanged({
            if ($filterListBox.SelectedIndex -ge 0) {
                $selectedFilter = $filterData[$filterListBox.SelectedItem]
                if ($selectedFilter -and $descTextBox.Text -ne $selectedFilter.Description) {
                    $filterChanges[$selectedFilter.id] = $descTextBox.Text
                    $saveBtn.Enabled = $true
                }
            }
        })
        
        $saveBtn.Add_Click({
            try {
                # Save filter description changes
                foreach ($filterId in $filterChanges.Keys) {
                    $filter = $script:PUAvailableFilters | Where-Object { $_.id -eq $filterId }
                    if ($filter) {
                        $fullFilter = Get-ProfileUnityFilterDetails -FilterId $filterId
                        $fullFilter.Description = $filterChanges[$filterId]
                        Update-ProfileUnityFilter -Filter $fullFilter
                    }
                }
                
                # Configuration changes are already applied to the object
                if ($configChanges) {
                    $script:PUConfigModified = $true
                    
                    $result = [System.Windows.Forms.MessageBox]::Show(
                        "All changes have been saved locally.`n`nDo you want to save the configuration now?", 
                        "Save Configuration", 
                        "YesNo", 
                        "Question"
                    )
                    
                    if ($result -eq "Yes") {
                        Save-ProfileUnityConfiguration
                    }
                }
                
                $filterForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show("Error saving changes: $($_.Exception.Message)", "Error", "OK", "Error")
            }
        })
        
        # Add controls to form
        $filterForm.Controls.Add($splitContainer)
        $filterForm.Controls.Add($bottomPanel)
        
        # Show dialog
        $result = $filterForm.ShowDialog()
        
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            # Refresh the main grid if needed
            $statusLabel = $script:MainForm.Controls.Find('PUStatusLabel', $true)[0]
            if ($statusLabel) {
                $statusLabel.Text = "Filter management completed - rescan to see changes"
            }
        }
        
    }
    catch {
        Write-LogMessage "Error in filter management dialog: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        [System.Windows.Forms.MessageBox]::Show("Error in filter management: $($_.Exception.Message)", "Error", "OK", "Error")
    }
    finally {
        if ($filterForm) {
            $filterForm.Dispose()
        }
    }
}