function Show-WPFPreviewDialog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    try {
        # Create dialog window
        $dialog = New-Object System.Windows.Window
        $dialog.Title = "Preview Changes"
        if ($script:WPFMainWindow) { $dialog.Owner = $script:WPFMainWindow }
        $dialog.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
        $dialog.Width = 650
        $dialog.Height = 480
        $dialog.ResizeMode = 'CanResize'

        # Layout grid
        $grid = New-Object System.Windows.Controls.Grid
        $row1 = New-Object System.Windows.Controls.RowDefinition
        $row1.Height = '1*'
        $row2 = New-Object System.Windows.Controls.RowDefinition
        $row2.Height = 'Auto'
        $grid.RowDefinitions.Add($row1)
        $grid.RowDefinitions.Add($row2)

        # Text content
        $textBox = New-Object System.Windows.Controls.TextBox
        $textBox.Text = $Text
        $textBox.IsReadOnly = $true
        $textBox.TextWrapping = 'Wrap'
        $textBox.VerticalScrollBarVisibility = 'Auto'
        $textBox.HorizontalScrollBarVisibility = 'Auto'
        $textBox.Margin = '10'
        [void]$grid.Children.Add($textBox)
        [System.Windows.Controls.Grid]::SetRow($textBox, 0)

        # Buttons panel
        $buttonsPanel = New-Object System.Windows.Controls.StackPanel
        $buttonsPanel.Orientation = 'Horizontal'
        $buttonsPanel.HorizontalAlignment = 'Right'
        $buttonsPanel.Margin = '10'

        $copyButton = New-Object System.Windows.Controls.Button
        $copyButton.Content = 'Copy to Clipboard'
        $copyButton.Margin = '0,0,10,0'
        $copyButton.Add_Click({ [System.Windows.Clipboard]::SetText($textBox.Text) })

        $closeButton = New-Object System.Windows.Controls.Button
        $closeButton.Content = 'Close'
        $closeButton.Add_Click({ $dialog.DialogResult = $true; $dialog.Close() })

        [void]$buttonsPanel.Children.Add($copyButton)
        [void]$buttonsPanel.Children.Add($closeButton)
        [void]$grid.Children.Add($buttonsPanel)
        [System.Windows.Controls.Grid]::SetRow($buttonsPanel, 1)

        $dialog.Content = $grid
        [void]$dialog.ShowDialog()
    }
    catch {
        Write-LogMessage "Failed to show preview dialog: $($_.Exception.Message)" -Level Error -Tab "ProfileUnity"
    }
}









