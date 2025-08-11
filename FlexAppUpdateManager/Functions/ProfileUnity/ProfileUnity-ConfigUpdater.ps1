# File: Functions\ProfileUnity\ProfileUnity-ConfigUpdater.ps1
# ================================
# Functions for previewing and committing ProfileUnity configuration updates

function Preview-ProfileUnityConfigChanges {
    [CmdletBinding()]
    param()
    
    try {
        $updatesGrid = $script:MainForm.Controls.Find('PUUpdatesGrid', $true)[0]
        $commitButton = $script:MainForm.Controls.Find('PUCommitButton', $true)[0]
        
        if (-not $updatesGrid) {
            throw "Could not find updates grid"
        }
        
        $selectedUpdates = @()
        
        foreach ($row in $updatesGrid.Rows) {
            if ($row.Cells["PUSelected"].Value -eq $true) {
                $selectedUpdates += $row.Tag
            }
        }
        
        if ($selectedUpdates.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select at least one update to preview", "No Selection", "OK", "Warning")
            return
        }
        
        # Create preview dialog
        $previewForm = New-Object System.Windows.Forms.Form
        $previewForm.Text = "Preview Configuration Changes"
        $previewForm.Size = New-Object System.Drawing.Size(700, 600)
        $previewForm.StartPosition = "CenterParent"
        $previewForm.MinimizeBox = $false
        $previewForm.MaximizeBox = $false
        $previewForm.FormBorderStyle = "FixedDialog"
        $previewForm.ShowInTaskbar = $false
        
        # Create a rich text box for better formatting
        $previewRichTextBox = New-Object System.Windows.Forms.RichTextBox
        $previewRichTextBox.Location = New-Object System.Drawing.Point(10, 10)
        $previewRichTextBox.Size = New-Object System.Drawing.Size(665, 510)
        $previewRichTextBox.ReadOnly = $true
        $previewRichTextBox.Font = New-Object System.Drawing.Font("Consolas", 10)
        $previewRichTextBox.BackColor = [System.Drawing.Color]::White
        $previewRichTextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
        
        # Build preview text with formatting
        $previewRichTextBox.Clear()
        $previewRichTextBox.SelectionFont = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
        $previewRichTextBox.AppendText("PREVIEW OF CHANGES:`n`n")
        
        $previewRichTextBox.SelectionFont = New-Object System.Drawing.Font("Consolas", 10)
        $previewRichTextBox.AppendText("Configuration: $($script:PUCurrentConfig.Name)`n")
        $previewRichTextBox.AppendText("Updates to apply: $($selectedUpdates.Count)`n")
        $previewRichTextBox.AppendText("=" * 70 + "`n`n")
        
        # Sort by sequence for display
        $sortedUpdates = $selectedUpdates | Sort-Object Sequence
        
        foreach ($update in $sortedUpdates) {
            # FlexApp name in bold
            $previewRichTextBox.SelectionFont = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
            $previewRichTextBox.SelectionColor = [System.Drawing.Color]::DarkBlue
            $previewRichTextBox.AppendText("FlexApp: $($update.Name)`n")
            
            # Details in regular font
            $previewRichTextBox.SelectionFont = New-Object System.Drawing.Font("Consolas", 10)
            $previewRichTextBox.SelectionColor = [System.Drawing.Color]::Black
            $previewRichTextBox.AppendText("  Current Version: v$($update.CurrentVersion)`n")
            $previewRichTextBox.AppendText("  New Version:     v$($update.NewVersion)`n")
            
            # Show filter changes
            if ($update.FilterChanged) {
                $previewRichTextBox.SelectionColor = [System.Drawing.Color]::DarkOrange
                $previewRichTextBox.AppendText("  Filter:          CHANGED to '$($update.FilterName)'`n")
                $previewRichTextBox.SelectionColor = [System.Drawing.Color]::Black
            } elseif ($update.FilterName) {
                $previewRichTextBox.AppendText("  Filter:          $($update.FilterName)`n")
            }
            
            $previewRichTextBox.AppendText("  Sequence:        $($update.Sequence)`n")
            $previewRichTextBox.AppendText("-" * 50 + "`n")
        }
        
        # OK button
        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Text = "OK"
        $okButton.Location = New-Object System.Drawing.Point(600, 530)
        $okButton.Size = New-Object System.Drawing.Size(75, 25)
        $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
        
        # Copy button
        $copyButton = New-Object System.Windows.Forms.Button
        $copyButton.Text = "Copy to Clipboard"
        $copyButton.Location = New-Object System.Drawing.Point(10, 530)
        $copyButton.Size = New-Object System.Drawing.Size(120, 25)
        $copyButton.Add_Click({
            [System.Windows.Forms.Clipboard]::SetText($previewRichTextBox.Text)
            [System.Windows.Forms.MessageBox]::Show("Preview copied to clipboard", "Copied", "OK", "Information")
        })
        
        $previewForm.Controls.AddRange(@($previewRichTextBox, $okButton, $copyButton))
        $previewForm.AcceptButton = $okButton
        
        # Show the dialog
        $dialogResult = $previewForm.ShowDialog()
        
        # Enable commit button after preview
        if ($commitButton) {
            $commitButton.Enabled = $true
        }
        
        # Dispose of the form
        $previewForm.Dispose()
        
    }
    catch {
        Write-LogMessage "Preview failed: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        [System.Windows.Forms.MessageBox]::Show("Preview failed: $($_.Exception.Message)", "Error", "OK", "Error")
    }
}

function Commit-ProfileUnityConfigChanges {
    [CmdletBinding()]
    param()
    
    try {
        $updatesGrid = $script:MainForm.Controls.Find('PUUpdatesGrid', $true)[0]
        $statusLabel = $script:MainForm.Controls.Find('PUStatusLabel', $true)[0]
        $deployCheckBox = $script:MainForm.Controls.Find('PUDeployCheckBox', $true)[0]
        $progressBar = $script:MainForm.Controls.Find('PUProgressBar', $true)[0]
        
        $selectedUpdates = @()
        
        foreach ($row in $updatesGrid.Rows) {
            if ($row.Cells["PUSelected"].Value -eq $true) {
                $selectedUpdates += $row.Tag
            }
        }
        
        if ($selectedUpdates.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select at least one update to commit", "No Selection", "OK", "Warning")
            return
        }
        
        $confirmMessage = "Are you sure you want to update $($selectedUpdates.Count) FlexApp(s) in configuration '$($script:PUCurrentConfig.Name)'?"
        if ($deployCheckBox.Checked) {
            $confirmMessage += "`n`nThe configuration will be DEPLOYED after saving."
        }
        
        $result = [System.Windows.Forms.MessageBox]::Show($confirmMessage, "Confirm Update", "YesNo", "Question")
        
        if ($result -ne "Yes") {
            return
        }
        
        Write-LogMessage "Starting configuration update..." -Level Info -Tab "ProfileUnity"
        $statusLabel.Text = "Updating configuration..."
        
        # Show progress
        $progressBar.Visible = $true
        $progressBar.Value = 0
        $progressBar.Maximum = $selectedUpdates.Count
        
        # Apply updates to the configuration
        foreach ($update in $selectedUpdates) {
            $progressBar.Value++
            $statusLabel.Text = "Updating $($update.Name)..."
            [System.Windows.Forms.Application]::DoEvents()
            
            # Find the DIA in the configuration
            $dia = $script:PUCurrentConfig.FlexAppDias[$update.DiaIndex]
            
            # Update the FlexApp package reference
            $package = $dia.FlexAppPackages[$update.PackageIndex]
            if ($package.FlexAppPackageId -eq $update.CurrentPackageId) {
                # Update package IDs
                $package.FlexAppPackageId = $update.NewPackageId
                $package.FlexAppPackageUuid = $update.NewPackageUuid
                
                # The sequence is at the DIA level and should be preserved
                if ($null -ne $update.Sequence -and $update.Sequence -ne 0) {
                    $dia.Sequence = $update.Sequence
                    Write-LogMessage "Preserving DIA sequence: $($dia.Sequence) for $($update.Name)" -Level Info -Tab "ProfileUnity"
                }
                
                Write-LogMessage "Updated $($update.Name) from v$($update.CurrentVersion) to v$($update.NewVersion) (DIA Sequence: $($dia.Sequence))" -Level Success -Tab "ProfileUnity"
            }
            
            # Update filter if changed
            if ($update.FilterChanged) {
                $dia.FilterId = $update.FilterId
                Write-LogMessage "Updated filter for $($update.Name) to: $($update.FilterName) (ID: $($update.FilterId))" -Level Success -Tab "ProfileUnity"
            }
            
            # Update description with date/time
            $date = Get-Date -Format "yyyy-MM-dd HH:mm"
            $changeText = "Updated $($update.Name) to v$($update.NewVersion)"
            if ($update.FilterChanged) {
                $changeText += " with filter '$($update.FilterName)'"
            }
            $changeText += " on $date"
            
            if ($dia.Description) {
                $dia.Description += " | $changeText"
            } else {
                $dia.Description = $changeText
            }
        }
        
        $statusLabel.Text = "Saving configuration..."
        
        # Save the configuration
        Save-ProfileUnityConfiguration
        
        # Deploy if requested
        if ($deployCheckBox.Checked) {
            $statusLabel.Text = "Deploying configuration..."
            
            # Deploy the configuration
            $configId = ($script:PUConfigurations | Where-Object { $_.name -eq $script:PUCurrentConfig.Name }).id
            $deployUri = "https://$($script:Config.ServerName):$($script:Config.ServerPort)/api/configuration/$configId/script?encoding=ascii&deploy=true"
            
            $deployResponse = Invoke-WebRequest -Uri $deployUri -WebSession $script:ChocoSession
            
            if ($deployResponse.StatusCode -eq 200) {
                Write-LogMessage "Configuration deployed successfully" -Level Success -Tab "ProfileUnity"
                $statusLabel.Text = "Configuration updated and deployed successfully!"
            } else {
                Write-LogMessage "Configuration saved but deployment failed" -Level Warning -Tab "ProfileUnity"
                $statusLabel.Text = "Configuration saved but deployment failed"
            }
        } else {
            $statusLabel.Text = "Configuration updated successfully!"
        }
        
        $filterChanges = $selectedUpdates | Where-Object { $_.FilterChanged }
        $filterMessage = if ($filterChanges.Count -gt 0) { "`nFilter changes: $($filterChanges.Count)" } else { "" }
        
        [System.Windows.Forms.MessageBox]::Show("Configuration updated successfully!`n`n$($selectedUpdates.Count) FlexApp(s) were updated.$filterMessage", "Success", "OK", "Information")
        
        # Clear the grid and disable buttons
        $updatesGrid.Rows.Clear()
        $script:PUUpdateCandidates = @()
        $script:MainForm.Controls.Find('PUPreviewButton', $true)[0].Enabled = $false
        $script:MainForm.Controls.Find('PUCommitButton', $true)[0].Enabled = $false
        $script:MainForm.Controls.Find('PULoadFiltersButton', $true)[0].Enabled = $false
        
    }
    catch {
        Write-LogMessage "Configuration update failed: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
        $statusLabel.Text = "Update failed: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Configuration update failed: $($_.Exception.Message)", "Error", "OK", "Error")
    }
    finally {
        $progressBar.Visible = $false
    }
}