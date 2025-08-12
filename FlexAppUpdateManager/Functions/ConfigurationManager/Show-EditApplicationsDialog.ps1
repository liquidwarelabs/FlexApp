# File: Functions\ConfigurationManager\Show-EditApplicationsDialog.ps1
# ================================

function Show-EditApplicationsDialog {
    param(
        [array]$SelectedApps
    )
    
    Write-LogMessage "Show-EditApplicationsDialog called with $($SelectedApps.Count) apps" -Level Info -Tab "Configuration Manager"
    
    # Debug: Log what we received
    for ($i = 0; $i -lt $SelectedApps.Count; $i++) {
        $app = $SelectedApps[$i]
        Write-LogMessage "DEBUG: App $($i+1) - Name: '$($app.Name)' - Version: '$($app.Version)' - Installer: '$($app.Installer)' - InstallerArgs: '$($app.InstallerArgs)'" -Level Info -Tab "Configuration Manager"
    }
    
    # Create the edit form
    $editForm = New-Object System.Windows.Forms.Form
    $editForm.Text = "Edit Applications Before Export"
    $editForm.Size = New-Object System.Drawing.Size(900, 600)
    $editForm.StartPosition = "CenterScreen"
    $editForm.MaximizeBox = $false
    $editForm.MinimizeBox = $false
    $editForm.FormBorderStyle = "FixedDialog"
    
    # Instructions label
    $instructionsLabel = New-Object System.Windows.Forms.Label
    $instructionsLabel.Text = "Edit the Name, Version, Installer, and Installer Arguments for each application before export:"
    $instructionsLabel.Location = New-Object System.Drawing.Point(10, 10)
    $instructionsLabel.Size = New-Object System.Drawing.Size(860, 20)
    $instructionsLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    
    # Create a scrollable panel for the textboxes
    $scrollPanel = New-Object System.Windows.Forms.Panel
    $scrollPanel.Location = New-Object System.Drawing.Point(10, 40)
    $scrollPanel.Size = New-Object System.Drawing.Size(860, 460)
    $scrollPanel.AutoScroll = $true
    $scrollPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    
    # Create a simple list of TextBoxes
    $textBoxes = @()
    $yPos = 10
    
    for ($i = 0; $i -lt $SelectedApps.Count; $i++) {
        $app = $SelectedApps[$i]
        
        # App label
        $appLabel = New-Object System.Windows.Forms.Label
        $appLabel.Text = "Application $($i + 1):"
        $appLabel.Location = New-Object System.Drawing.Point(10, [int]$yPos)
        $appLabel.Size = New-Object System.Drawing.Size(100, 20)
        $appLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 8, [System.Drawing.FontStyle]::Bold)
        $scrollPanel.Controls.Add($appLabel)
        
        # Name label and textbox
        $nameLabel = New-Object System.Windows.Forms.Label
        $nameLabel.Text = "Name:"
        $nameLabel.Location = New-Object System.Drawing.Point(10, [int]($yPos + 25))
        $nameLabel.Size = New-Object System.Drawing.Size(50, 20)
        $scrollPanel.Controls.Add($nameLabel)
        
        $nameTextBox = New-Object System.Windows.Forms.TextBox
        $nameTextBox.Location = New-Object System.Drawing.Point(70, [int]($yPos + 23))
        $nameTextBox.Size = New-Object System.Drawing.Size(280, 20)
        $nameTextBox.Text = $app.Name
        $scrollPanel.Controls.Add($nameTextBox)
        
        # Version label and textbox
        $versionLabel = New-Object System.Windows.Forms.Label
        $versionLabel.Text = "Version:"
        $versionLabel.Location = New-Object System.Drawing.Point(360, [int]($yPos + 25))
        $versionLabel.Size = New-Object System.Drawing.Size(50, 20)
        $scrollPanel.Controls.Add($versionLabel)
        
        $versionTextBox = New-Object System.Windows.Forms.TextBox
        $versionTextBox.Location = New-Object System.Drawing.Point(420, [int]($yPos + 23))
        $versionTextBox.Size = New-Object System.Drawing.Size(120, 20)
        $versionTextBox.Text = if ($app.Version -ne $null -and $app.Version -ne "0.0.0.0") { $app.Version } else { "0.0.0.0" }
        $scrollPanel.Controls.Add($versionTextBox)
        
        # Installer label and textbox
        $installerLabel = New-Object System.Windows.Forms.Label
        $installerLabel.Text = "Installer:"
        $installerLabel.Location = New-Object System.Drawing.Point(10, [int]($yPos + 50))
        $installerLabel.Size = New-Object System.Drawing.Size(50, 20)
        $scrollPanel.Controls.Add($installerLabel)
        
        $installerTextBox = New-Object System.Windows.Forms.TextBox
        $installerTextBox.Location = New-Object System.Drawing.Point(70, [int]($yPos + 48))
        $installerTextBox.Size = New-Object System.Drawing.Size(470, 20)
        $installerTextBox.Text = if ($app.Installer -ne $null -and $app.Installer -ne "") { $app.Installer } else { "" }
        $scrollPanel.Controls.Add($installerTextBox)
        
        # Installer Arguments label and textbox
        $installerArgsLabel = New-Object System.Windows.Forms.Label
        $installerArgsLabel.Text = "Installer Args:"
        $installerArgsLabel.Location = New-Object System.Drawing.Point(10, [int]($yPos + 75))
        $installerArgsLabel.Size = New-Object System.Drawing.Size(80, 20)
        $scrollPanel.Controls.Add($installerArgsLabel)
        
        $installerArgsTextBox = New-Object System.Windows.Forms.TextBox
        $installerArgsTextBox.Location = New-Object System.Drawing.Point(100, [int]($yPos + 73))
        $installerArgsTextBox.Size = New-Object System.Drawing.Size(440, 20)
        $installerArgsTextBox.Text = if ($app.InstallerArgs -ne $null -and $app.InstallerArgs -ne "") { $app.InstallerArgs } else { "" }
        $scrollPanel.Controls.Add($installerArgsTextBox)
        
        # Store references to textboxes
        $textBoxes += [PSCustomObject]@{
            NameTextBox = $nameTextBox
            VersionTextBox = $versionTextBox
            InstallerTextBox = $installerTextBox
            InstallerArgsTextBox = $installerArgsTextBox
        }
        
        $yPos += 110
    }
    
    # Buttons - always at the bottom of the form
    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Location = New-Object System.Drawing.Point(10, 510)
    $buttonPanel.Size = New-Object System.Drawing.Size(860, 50)
    
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "Continue Export"
    $okButton.Location = New-Object System.Drawing.Point(680, 10)
    $okButton.Size = New-Object System.Drawing.Size(120, 30)
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Location = New-Object System.Drawing.Point(590, 10)
    $cancelButton.Size = New-Object System.Drawing.Size(80, 30)
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    
    $buttonPanel.Controls.AddRange(@($okButton, $cancelButton))
    
    # Add controls to form
    $editForm.Controls.AddRange(@($instructionsLabel, $scrollPanel, $buttonPanel))
    $editForm.AcceptButton = $okButton
    $editForm.CancelButton = $cancelButton
    
    # Show dialog
    $result = $editForm.ShowDialog()
    
    $editedApps = $null
    
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $editedApps = @()
        for ($i = 0; $i -lt $textBoxes.Count; $i++) {
            $nameValue = $textBoxes[$i].NameTextBox.Text
            $versionValue = $textBoxes[$i].VersionTextBox.Text
            $installerValue = $textBoxes[$i].InstallerTextBox.Text
            $installerArgsValue = $textBoxes[$i].InstallerArgsTextBox.Text
            
            if (![string]::IsNullOrWhiteSpace($nameValue)) {
                $editedApp = [PSCustomObject]@{
                    Name = $nameValue.Trim()
                    Version = if (![string]::IsNullOrWhiteSpace($versionValue)) { $versionValue.Trim() } else { "0.0.0.0" }
                    Installer = if (![string]::IsNullOrWhiteSpace($installerValue)) { $installerValue.Trim() } else { "" }
                    InstallerArgs = if (![string]::IsNullOrWhiteSpace($installerArgsValue)) { $installerArgsValue.Trim() } else { "" }
                }
                $editedApps += $editedApp
            }
        }
    }
    
    # Dispose of the form
    $editForm.Dispose()
    
    return $editedApps
}