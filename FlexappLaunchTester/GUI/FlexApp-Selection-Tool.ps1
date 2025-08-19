# Get-FlexAppSelection-WPF.ps1
# WPF GUI wrapper for FlexApp selection and export with tabbed interface
# PowerShell 5.x compatible version with enhanced batch testing support

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Function to parse FlexApp package XML files
function Get-FlexAppInfo {
    param(
        [string]$XmlPath
    )
    
    try {
        $xml = [xml](Get-Content -Path $XmlPath -ErrorAction Stop)
        $package = $xml.Package
        
        # Extract link information
        $links = @()
        if ($package.Links -and $package.Links.Link) {
            foreach ($link in $package.Links.Link) {
                $links += [PSCustomObject]@{
                    Location = $link.Location
                    Target = $link.Target
                    Arguments = $link.Arguments
                    WorkingDirectory = $link.WorkingDirectory
                    Description = $link.Description
                }
            }
        }
        
        # Parse modified date
        $modifiedDate = $null
        if ($package.DateModified) {
            try {
                $modifiedDate = [DateTime]::Parse($package.DateModified)
            } catch {
                $modifiedDate = [DateTime]::MinValue
            }
        } else {
            $modifiedDate = [DateTime]::MinValue
        }
        
        # Robust boolean parsing - handles non-standard boolean values
        $disabledValue = $package.Disabled
        $parsedDisabled = $false
        
        if ($null -ne $disabledValue) {
            $disabledStr = $disabledValue.ToString().Trim().ToLower()
            switch ($disabledStr) {
                "true" { $parsedDisabled = $true }
                "1" { $parsedDisabled = $true }
                "yes" { $parsedDisabled = $true }
                "y" { $parsedDisabled = $true }
                "false" { $parsedDisabled = $false }
                "0" { $parsedDisabled = $false }
                "no" { $parsedDisabled = $false }
                "n" { $parsedDisabled = $false }
                "" { $parsedDisabled = $false }
                default { 
                    # Try to parse as boolean, fallback to false
                    if ([bool]::TryParse($disabledStr, [ref]$parsedDisabled)) {
                        # Successfully parsed
                    } else {
                        $parsedDisabled = $false
                    }
                }
            }
        }
        
        # Build app info object
        $appInfo = @{
            Name = $package.DisplayName
            Version = "$($package.VersionMajor).$($package.VersionMinor).$($package.VersionBuild).$($package.VersionRevision)"
            PackageId = $package.Id
            PackageUuid = $package.Uuid
            PackageType = $package.PackageType
            FilePath = $package.FilePath
            FileName = $package.FileName
            VhdxPath = Join-Path $package.FilePath $package.FileName
            DateCreated = $package.DateCreated
            DateModified = $package.DateModified
            DateModifiedParsed = $modifiedDate
            UseCount = $package.UseCount
            Disabled = $parsedDisabled
            SizeInGB = $package.SizeInGb
            ActualSizeInBytes = $package.ActualSizeInBytes
            ActualSizeMB = [math]::Round($package.ActualSizeInBytes / 1MB, 2)
            Installer = if ($package.Installers.string) { $package.Installers.string -join "; " } else { "" }
            XmlPath = $XmlPath
            ParentDirectory = Split-Path -Parent $XmlPath
            Links = $links
            ExecutablePath = if ($links.Count -gt 0) { $links[0].Target } else { "" }
            WorkingDirectory = if ($links.Count -gt 0) { $links[0].WorkingDirectory } else { "" }
            CommandLineArgs = if ($links.Count -gt 0) { $links[0].Arguments } else { "" }
        }
        
        return New-Object PSObject -Property $appInfo
    }
    catch {
        Write-Warning "Failed to parse XML: $XmlPath - $($_.Exception.Message)"
        return $null
    }
}

# PowerShell 5.x compatible FlexAppItem creation function
function New-FlexAppItem {
    param([object]$appInfo)
    
    $item = New-Object PSObject -Property @{
        IsSelected = $false
        Name = $appInfo.Name
        Version = $appInfo.Version
        PackageType = $appInfo.PackageType
        ActualSizeMB = $appInfo.ActualSizeMB
        UseCount = $appInfo.UseCount
        Status = if ($appInfo.Disabled) { "Disabled" } else { "Enabled" }
        DateModified = $appInfo.DateModified
        ExecutablePath = $appInfo.ExecutablePath
        AppInfo = $appInfo
    }
    
    return $item
}

# XAML for the WPF interface with tabbed layout
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="FlexApp Selection Tool - WPF Tabbed" Height="850" Width="1200"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResize">
    <Window.Resources>
        <Style TargetType="GroupBox">
            <Setter Property="Margin" Value="5"/>
            <Setter Property="Padding" Value="10"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="BorderBrush" Value="#FF6B73C7"/>
            <Setter Property="BorderThickness" Value="2"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="Margin" Value="2"/>
            <Setter Property="Background" Value="#FF4472C4"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FF5B84D4"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Background" Value="#FFCCCCCC"/>
                    <Setter Property="Foreground" Value="#FF666666"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="TabItem">
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="10,5"/>
        </Style>
    </Window.Resources>
    
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Menu -->
        <Menu Grid.Row="0">
            <MenuItem Header="_File">
                <MenuItem Header="E_xit" Name="ExitMenuItem"/>
            </MenuItem>
            <MenuItem Header="_Help">
                <MenuItem Header="_About" Name="AboutMenuItem"/>
            </MenuItem>
        </Menu>
        
        <!-- Tab Control -->
        <TabControl Grid.Row="1" Name="MainTabControl" Margin="5">
            
            <!-- TAB 1: Application Selection -->
            <TabItem Header="Application Selection" Name="AppSelectionTab">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    
                    <!-- Path Selection -->
                    <GroupBox Grid.Row="0" Header="FlexApp Catalog Path">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            
                            <Label Grid.Row="0" Grid.Column="0" Content="UNC Path:" VerticalAlignment="Center"/>
                            <TextBox Grid.Row="0" Grid.Column="1" Name="PathTextBox" 
                                     Text="\\server\share\FlexApps\Catalog" 
                                     VerticalAlignment="Center" Margin="5,0"/>
                            <Button Grid.Row="0" Grid.Column="2" Name="BrowseButton" Content="Browse..." MinWidth="80"/>
                            <Button Grid.Row="0" Grid.Column="3" Name="ScanButton" Content="Scan" MinWidth="80"/>
                            
                            <CheckBox Grid.Row="1" Grid.Column="1" Name="IncludeDisabledCheckbox" 
                                      Content="Include disabled applications" Margin="5,10,0,0"/>
                        </Grid>
                    </GroupBox>
                    
                    <!-- Sort and Search Controls -->
                    <GroupBox Grid.Row="1" Header="Sort &amp; Search Options">
                        <StackPanel Orientation="Horizontal">
                            <Label Content="Sort by:" VerticalAlignment="Center"/>
                            <ComboBox Name="SortComboBox" Width="200" VerticalAlignment="Center" Margin="5,0">
                                <ComboBoxItem Content="Name (A-Z)" Tag="Name_Asc" IsSelected="True"/>
                                <ComboBoxItem Content="Name (Z-A)" Tag="Name_Desc"/>
                                <ComboBoxItem Content="Modified Date (Newest)" Tag="Modified_Desc"/>
                                <ComboBoxItem Content="Modified Date (Oldest)" Tag="Modified_Asc"/>
                                <ComboBoxItem Content="Size (Largest)" Tag="Size_Desc"/>
                                <ComboBoxItem Content="Size (Smallest)" Tag="Size_Asc"/>
                                <ComboBoxItem Content="Use Count (Highest)" Tag="UseCount_Desc"/>
                                <ComboBoxItem Content="Use Count (Lowest)" Tag="UseCount_Asc"/>
                            </ComboBox>
                            
                            <!-- Search Controls -->
                            <Label Content="Search:" VerticalAlignment="Center" Margin="20,0,0,0"/>
                            <TextBox Name="SearchTextBox" Width="200" VerticalAlignment="Center" Margin="5,0" 
                                     ToolTip="Search applications by name (case-insensitive)"/>
                            <Button Name="ClearSearchButton" Content="Clear" VerticalAlignment="Center" Margin="5,0"
                                    ToolTip="Clear search filter"/>
                        </StackPanel>
                    </GroupBox>
                    
                    <!-- Applications List -->
                    <GroupBox Grid.Row="2" Header="Applications">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            
                            <!-- DataGrid for applications -->
                            <DataGrid Grid.Row="0" Name="AppsDataGrid" 
                                      AutoGenerateColumns="False" 
                                      CanUserSortColumns="True"
                                      SelectionMode="Extended"
                                      GridLinesVisibility="All"
                                      AlternatingRowBackground="#FFF0F0F0"
                                      HeadersVisibility="Column"
                                      Margin="5">
                                <DataGrid.Columns>
                                    <DataGridCheckBoxColumn Header="Select" Binding="{Binding IsSelected}" Width="60"/>
                                    <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="250" IsReadOnly="True"/>
                                    <DataGridTextColumn Header="Version" Binding="{Binding Version}" Width="80" IsReadOnly="True"/>
                                    <DataGridTextColumn Header="Type" Binding="{Binding PackageType}" Width="60" IsReadOnly="True"/>
                                    <DataGridTextColumn Header="Size (MB)" Binding="{Binding ActualSizeMB}" Width="80" IsReadOnly="True"/>
                                    <DataGridTextColumn Header="Use Count" Binding="{Binding UseCount}" Width="80" IsReadOnly="True"/>
                                    <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="80" IsReadOnly="True"/>
                                    <DataGridTextColumn Header="Modified Date" Binding="{Binding DateModified}" Width="120" IsReadOnly="True"/>
                                    <DataGridTextColumn Header="Executable" Binding="{Binding ExecutablePath}" Width="*" IsReadOnly="True"/>
                                </DataGrid.Columns>
                            </DataGrid>
                            
                            <!-- Selection Controls -->
                            <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="5">
                                <Button Name="SelectAllButton" Content="Select All" MinWidth="100"/>
                                <Button Name="SelectNoneButton" Content="Select None" MinWidth="100"/>
                                <Button Name="SelectEnabledButton" Content="Select Enabled" MinWidth="120"/>
                                <Label Name="SelectedCountLabel" Content="Selected: 0 apps (0 MB)" 
                                       VerticalAlignment="Center" Margin="20,0,0,0" FontWeight="Bold"/>
                            </StackPanel>
                        </Grid>
                    </GroupBox>
                </Grid>
            </TabItem>
            
            <!-- TAB 2: Settings & Export -->
            <TabItem Header="Settings &amp; Export" Name="SettingsTab">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    
                    <!-- PowerShell Command Generator -->
                    <GroupBox Grid.Row="0" Header="PowerShell Launch Tester Command Generator">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            
                            <Label Grid.Row="0" Grid.Column="0" Content="Generated PowerShell Command:" Margin="0,0,0,5"/>
                            <TextBox Grid.Row="1" Grid.Column="0" Name="PowerShellCommandTextBox" 
                                     TextWrapping="Wrap" Height="120" IsReadOnly="True"
                                     VerticalScrollBarVisibility="Auto" Margin="0,0,10,0"
                                     FontFamily="Consolas" FontSize="10"/>
                            
                            <StackPanel Grid.Row="1" Grid.Column="1" VerticalAlignment="Top">
                                <Button Name="CopyCommandButton" Content="Copy Command" MinWidth="120" Margin="0,0,0,5"/>
                                <Button Name="UpdateCommandButton" Content="Update Command" MinWidth="120"/>
                            </StackPanel>
                        </Grid>
                    </GroupBox>
                    
                    <!-- Command Configuration -->
                    <GroupBox Grid.Row="1" Header="Command Configuration">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            
                            <!-- Row 1 -->
                            <Label Grid.Row="0" Grid.Column="0" Content="Batch Manager Path:" VerticalAlignment="Center"/>
                            <TextBox Grid.Row="0" Grid.Column="1" Name="BatchManagerPathTextBox" 
                                     Text="\\server\share\Automation\LaunchTesting\Flexapp-Testing\CORE\FlexApp-Batch-Manager.ps1"
                                     VerticalAlignment="Center" Margin="5,2"/>
                            
                            <Label Grid.Row="0" Grid.Column="2" Content="Test Runner Path:" VerticalAlignment="Center" Margin="10,0,0,0"/>
                            <TextBox Grid.Row="0" Grid.Column="3" Name="TestScriptPathTextBox" 
                                     Text="\\pro2020\profileUnity\Automation\LaunchTesting\FlexappLaunchTester\CORE\FlexApp-Test-Runner.ps1"
                                     VerticalAlignment="Center" Margin="5,2"/>
                            
                            <!-- Row 2 -->
                            <Label Grid.Row="1" Grid.Column="0" Content="List File:" VerticalAlignment="Center"/>
                            <TextBox Grid.Row="1" Grid.Column="1" Name="ListFilePathTextBox" 
                                     Text="\\pro2020\profileUnity\Automation\LaunchTesting\FlexappLaunchTester\CONFIG\flexapp-config.csv"
                                     VerticalAlignment="Center" Margin="5,2"/>
                            
                            <Label Grid.Row="1" Grid.Column="2" Content="Output Base Dir:" VerticalAlignment="Center" Margin="10,0,0,0"/>
                            <TextBox Grid.Row="1" Grid.Column="3" Name="OutputBaseDirTextBox" 
                                     Text="\\pro2020\ProfileShare\$($env:USERNAME)\Captures"
                                     VerticalAlignment="Center" Margin="5,2"/>
                            
                            <!-- Row 3 -->
                            <Label Grid.Row="2" Grid.Column="0" Content="FFmpeg Path:" VerticalAlignment="Center"/>
                            <TextBox Grid.Row="2" Grid.Column="1" Name="FFmpegPathTextBox" 
                                     Text="\\pro2020\profileUnity\Automation\LaunchTesting\FlexappLaunchTester\ffmpeg\bin\ffmpeg.exe"
                                     VerticalAlignment="Center" Margin="5,2"/>
                            
                            <!-- Row 4 -->
                            <Label Grid.Row="3" Grid.Column="0" Content="Video Capture (sec):" VerticalAlignment="Center"/>
                            <TextBox Grid.Row="3" Grid.Column="1" Name="VideoCaptureSecondsTextBox" Text="60" 
                                     Width="100" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="5,2"/>
                            
                            <Label Grid.Row="3" Grid.Column="2" Content="Wait After Attach (sec):" VerticalAlignment="Center" Margin="10,0,0,0"/>
                            <TextBox Grid.Row="3" Grid.Column="3" Name="WaitAfterAttachTextBox" Text="15" 
                                     Width="100" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="5,2"/>
                            
                            <!-- Row 5 - Checkboxes -->
                            <StackPanel Grid.Row="4" Grid.Column="0" Grid.ColumnSpan="4" Orientation="Horizontal" Margin="0,10,0,0">
                                <CheckBox Name="GenerateSummaryReportCheckBox" Content="Generate Summary Report" 
                                          IsChecked="True" Margin="0,0,20,0"/>
                                <CheckBox Name="RecordBeforeAppLaunchCheckBox" Content="Record Before App Launch" 
                                          IsChecked="True" Margin="0,0,20,0"/>
                                <CheckBox Name="VerifyCleanupCheckBox" Content="Verify Cleanup" 
                                          IsChecked="True" Margin="0,0,20,0"/>
                            </StackPanel>
                        </Grid>
                    </GroupBox>
                    
                    <!-- Export Options -->
                    <GroupBox Grid.Row="2" Header="Export Options">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            
                            <!-- Export Path -->
                            <Label Grid.Row="0" Grid.Column="0" Content="Export Path:" VerticalAlignment="Center"/>
                            <TextBox Grid.Row="0" Grid.Column="1" Name="ExportPathTextBox" 
                                     Text="CONFIG\flexapp-config.csv" VerticalAlignment="Center" Margin="5,2"/>
                            <Button Grid.Row="0" Grid.Column="2" Name="ExportBrowseButton" Content="Browse..." MinWidth="80"/>
                            <Button Grid.Row="0" Grid.Column="3" Name="ExportButton" Content="Export Selected" 
                                    MinWidth="120" IsEnabled="False"/>
                            
                            <!-- Additional Options -->
                            <CheckBox Grid.Row="1" Grid.Column="1" Name="OpenAfterExportCheckbox" 
                                      Content="Open file after export" Margin="5,10,0,0" IsChecked="False"/>
                        </Grid>
                    </GroupBox>
                </Grid>
            </TabItem>
        </TabControl>
        
        <!-- Status Bar -->
        <StatusBar Grid.Row="2">
            <StatusBarItem>
                <TextBlock Name="StatusLabel" Text="Ready"/>
            </StatusBarItem>
        </StatusBar>
    </Grid>
</Window>
"@

# Load XAML
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$PathTextBox = $window.FindName("PathTextBox")
$BrowseButton = $window.FindName("BrowseButton")
$ScanButton = $window.FindName("ScanButton")
$IncludeDisabledCheckbox = $window.FindName("IncludeDisabledCheckbox")
$SortComboBox = $window.FindName("SortComboBox")
$SearchTextBox = $window.FindName("SearchTextBox")
$ClearSearchButton = $window.FindName("ClearSearchButton")
$AppsDataGrid = $window.FindName("AppsDataGrid")
$SelectAllButton = $window.FindName("SelectAllButton")
$SelectNoneButton = $window.FindName("SelectNoneButton")
$SelectEnabledButton = $window.FindName("SelectEnabledButton")
$SelectedCountLabel = $window.FindName("SelectedCountLabel")
$ExportPathTextBox = $window.FindName("ExportPathTextBox")
$ExportBrowseButton = $window.FindName("ExportBrowseButton")
$ExportButton = $window.FindName("ExportButton")
$OpenAfterExportCheckbox = $window.FindName("OpenAfterExportCheckbox")
$ExitMenuItem = $window.FindName("ExitMenuItem")
$AboutMenuItem = $window.FindName("AboutMenuItem")
$StatusLabel = $window.FindName("StatusLabel")

# Settings controls
$PowerShellCommandTextBox = $window.FindName("PowerShellCommandTextBox")
$CopyCommandButton = $window.FindName("CopyCommandButton")
$UpdateCommandButton = $window.FindName("UpdateCommandButton")
$BatchManagerPathTextBox = $window.FindName("BatchManagerPathTextBox")
$TestScriptPathTextBox = $window.FindName("TestScriptPathTextBox")
$ListFilePathTextBox = $window.FindName("ListFilePathTextBox")
$OutputBaseDirTextBox = $window.FindName("OutputBaseDirTextBox")
$FFmpegPathTextBox = $window.FindName("FFmpegPathTextBox")
$VideoCaptureSecondsTextBox = $window.FindName("VideoCaptureSecondsTextBox")
$WaitAfterAttachTextBox = $window.FindName("WaitAfterAttachTextBox")
$GenerateSummaryReportCheckBox = $window.FindName("GenerateSummaryReportCheckBox")
$RecordBeforeAppLaunchCheckBox = $window.FindName("RecordBeforeAppLaunchCheckBox")
$VerifyCleanupCheckBox = $window.FindName("VerifyCleanupCheckBox")

# Global variables
$script:allAppItems = @()  # Master collection holding all scanned applications
$script:appItems = New-Object System.Collections.ObjectModel.ObservableCollection[Object]  # Filtered/sorted collection for display
$AppsDataGrid.ItemsSource = $script:appItems

# Settings persistence
$script:SettingsPath = Join-Path $env:APPDATA "LiquidwareSparks\ApplicationLauncher"
$script:SettingsFile = Join-Path $script:SettingsPath "FlexAppSettings.json"

# Function to save settings
function Save-Settings {
    try {
        # Ensure directory exists
        if (!(Test-Path $script:SettingsPath)) {
            New-Item -ItemType Directory -Path $script:SettingsPath -Force | Out-Null
        }
        
        $settings = @{
            PathTextBox = $PathTextBox.Text
            BatchManagerPath = $BatchManagerPathTextBox.Text
            TestScriptPath = $TestScriptPathTextBox.Text
            ListFilePath = $ListFilePathTextBox.Text
            OutputBaseDir = $OutputBaseDirTextBox.Text
            FFmpegPath = $FFmpegPathTextBox.Text
            VideoCaptureSeconds = $VideoCaptureSecondsTextBox.Text
            WaitAfterAttach = $WaitAfterAttachTextBox.Text
            GenerateSummaryReport = $GenerateSummaryReportCheckBox.IsChecked
            RecordBeforeAppLaunch = $RecordBeforeAppLaunchCheckBox.IsChecked
            VerifyCleanup = $VerifyCleanupCheckBox.IsChecked
            ExportPath = $ExportPathTextBox.Text
            OpenAfterExport = $OpenAfterExportCheckbox.IsChecked
            IncludeDisabled = $IncludeDisabledCheckbox.IsChecked
            SearchText = $SearchTextBox.Text
        }
        
        $settings | ConvertTo-Json | Set-Content -Path $script:SettingsFile -Encoding UTF8
    }
    catch {
        # Silently fail if settings can't be saved
    }
}

# Function to load settings
function Load-Settings {
    try {
        if (Test-Path $script:SettingsFile) {
            $settings = Get-Content -Path $script:SettingsFile -Encoding UTF8 | ConvertFrom-Json
            
            if ($settings.PathTextBox) { $PathTextBox.Text = $settings.PathTextBox }
            if ($settings.BatchManagerPath) { $BatchManagerPathTextBox.Text = $settings.BatchManagerPath }
            if ($settings.TestScriptPath) { $TestScriptPathTextBox.Text = $settings.TestScriptPath }
            if ($settings.ListFilePath) { $ListFilePathTextBox.Text = $settings.ListFilePath }
            if ($settings.OutputBaseDir) { $OutputBaseDirTextBox.Text = $settings.OutputBaseDir }
            if ($settings.FFmpegPath) { $FFmpegPathTextBox.Text = $settings.FFmpegPath }
            if ($settings.VideoCaptureSeconds) { $VideoCaptureSecondsTextBox.Text = $settings.VideoCaptureSeconds }
            if ($settings.WaitAfterAttach) { $WaitAfterAttachTextBox.Text = $settings.WaitAfterAttach }
            if ($null -ne $settings.GenerateSummaryReport) { $GenerateSummaryReportCheckBox.IsChecked = $settings.GenerateSummaryReport }
            if ($null -ne $settings.RecordBeforeAppLaunch) { $RecordBeforeAppLaunchCheckBox.IsChecked = $settings.RecordBeforeAppLaunch }
            if ($null -ne $settings.VerifyCleanup) { $VerifyCleanupCheckBox.IsChecked = $settings.VerifyCleanup }
            if ($settings.ExportPath) { $ExportPathTextBox.Text = $settings.ExportPath }
            if ($null -ne $settings.OpenAfterExport) { $OpenAfterExportCheckbox.IsChecked = $settings.OpenAfterExport }
            if ($null -ne $settings.IncludeDisabled) { $IncludeDisabledCheckbox.IsChecked = $settings.IncludeDisabled }
            if ($settings.SearchText) { $SearchTextBox.Text = $settings.SearchText }
        }
    }
    catch {
        # Silently fail if settings can't be loaded
    }
}

# Function to update PowerShell command
function Update-PowerShellCommand {
    $command = @"
powershell.exe -ExecutionPolicy Bypass -File "$($BatchManagerPathTextBox.Text)" ``
    -TestRunnerPath "$($TestScriptPathTextBox.Text)" ``
    -ListFile "$($ListFilePathTextBox.Text)" ``
    -OutputBaseDir "$($OutputBaseDirTextBox.Text)" ``
    -FFmpegPath "$($FFmpegPathTextBox.Text)" ``
    -VideoCaptureSeconds $([int]$VideoCaptureSecondsTextBox.Text) ``
    -WaitAfterAttach $([int]$WaitAfterAttachTextBox.Text)
"@

    if ($GenerateSummaryReportCheckBox.IsChecked) {
        $command += " ```n    -GenerateSummaryReport"
    }
    if ($RecordBeforeAppLaunchCheckBox.IsChecked) {
        $command += " ```n    -RecordBeforeAppLaunch"
    }
    if ($VerifyCleanupCheckBox.IsChecked) {
        $command += " ```n    -VerifyCleanup"
    }
    
    $PowerShellCommandTextBox.Text = $command
}

# Function to filter and sort applications
function Filter-And-Sort-Applications {
    # Get search filter
    $searchFilter = $SearchTextBox.Text.Trim()
    
    # Start with all items from the master collection
    $filteredItems = $script:allAppItems
    
    # Apply search filter if specified
    if (-not [string]::IsNullOrEmpty($searchFilter)) {
        $filteredItems = $filteredItems | Where-Object { 
            $_.Name -like "*$searchFilter*" 
        }
    }
    
    # Apply sort
    $sortBy = $SortComboBox.SelectedItem.Tag
    $sortedItems = switch ($sortBy) {
        "Name_Asc" { $filteredItems | Sort-Object Name }
        "Name_Desc" { $filteredItems | Sort-Object Name -Descending }
        "Modified_Desc" { $filteredItems | Sort-Object { $_.AppInfo.DateModifiedParsed } -Descending }
        "Modified_Asc" { $filteredItems | Sort-Object { $_.AppInfo.DateModifiedParsed } }
        "Size_Desc" { $filteredItems | Sort-Object ActualSizeMB -Descending }
        "Size_Asc" { $filteredItems | Sort-Object ActualSizeMB }
        "UseCount_Desc" { $filteredItems | Sort-Object UseCount -Descending }
        "UseCount_Asc" { $filteredItems | Sort-Object UseCount }
        default { $filteredItems | Sort-Object Name }
    }
    
    # Update the displayed collection
    $script:appItems.Clear()
    foreach ($item in $sortedItems) {
        $script:appItems.Add($item)
    }
    
    # Update status
    $totalCount = $script:allAppItems.Count
    $filteredCount = $script:appItems.Count
    if ($filteredCount -eq $totalCount) {
        $StatusLabel.Text = "Found $filteredCount applications"
    } else {
        $StatusLabel.Text = "Showing $filteredCount of $totalCount applications"
    }
}

# Function to update selected count
function Update-SelectedCount {
    $selectedCount = 0
    $totalSize = 0
    
    foreach ($item in $script:appItems) {
        if ($item.IsSelected) {
            $selectedCount++
            $totalSize += $item.ActualSizeMB
        }
    }
    
    $SelectedCountLabel.Content = "Selected: $selectedCount apps ($([math]::Round($totalSize, 2)) MB)"
}

# Event handlers
$ExitMenuItem.Add_Click({ 
    Save-Settings
    $window.Close() 
})

$AboutMenuItem.Add_Click({
    [System.Windows.MessageBox]::Show(
        "FlexApp Selection Tool - WPF Tabbed Edition`nVersion 3.1`n`nSelect FlexApp applications for testing and export to CSV.`n`nFeatures:`n- Tabbed Interface`n- PowerShell 5.x Compatible`n- Enhanced Command Generator`n- Full Batch Testing Support",
        "About",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    )
})

$BrowseButton.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select FlexApp Catalog Folder"
    
    if ($folderBrowser.ShowDialog() -eq "OK") {
        $PathTextBox.Text = $folderBrowser.SelectedPath
    }
})

$ExportBrowseButton.Add_Click({
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
    $saveFileDialog.DefaultExt = "csv"
    
    if ($saveFileDialog.ShowDialog() -eq "OK") {
        $ExportPathTextBox.Text = $saveFileDialog.FileName
    }
})

$ScanButton.Add_Click({
    $script:allAppItems = @()
    $script:appItems.Clear()
    $StatusLabel.Text = "Scanning for FlexApp packages..."
    
    $path = $PathTextBox.Text
    if (-not (Test-Path -Path $path)) {
        [System.Windows.MessageBox]::Show(
            "Path not found: $path",
            "Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
        $StatusLabel.Text = "Ready"
        return
    }
    
    # Scan for XML files
    $xmlFiles = Get-ChildItem -Path $path -Filter "*.package.xml" -Recurse -ErrorAction SilentlyContinue
    
    if ($xmlFiles.Count -eq 0) {
        [System.Windows.MessageBox]::Show(
            "No package XML files found in the specified path.",
            "No Files Found",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
        $StatusLabel.Text = "Ready"
        return
    }
    
    $StatusLabel.Text = "Parsing $($xmlFiles.Count) XML files..."
    
    foreach ($xmlFile in $xmlFiles) {
        $appInfo = Get-FlexAppInfo -XmlPath $xmlFile.FullName
        if ($null -ne $appInfo) {
            if ($appInfo.Disabled -and -not $IncludeDisabledCheckbox.IsChecked) {
                continue
            }
            
            $flexAppItem = New-FlexAppItem -appInfo $appInfo
            $script:allAppItems += $flexAppItem
        }
    }
    
    Filter-And-Sort-Applications
    $ExportButton.IsEnabled = $script:appItems.Count -gt 0
})

$SortComboBox.Add_SelectionChanged({
    if ($script:allAppItems.Count -gt 0) {
        Filter-And-Sort-Applications
    }
})

# Search functionality event handlers
$SearchTextBox.Add_TextChanged({
    if ($script:allAppItems.Count -gt 0) {
        Filter-And-Sort-Applications
        Update-SelectedCount
    }
})

$ClearSearchButton.Add_Click({
    $SearchTextBox.Text = ""
    if ($script:allAppItems.Count -gt 0) {
        Filter-And-Sort-Applications
        Update-SelectedCount
    }
})

$SelectAllButton.Add_Click({
    foreach ($item in $script:appItems) {
        $item.IsSelected = $true
    }
    $AppsDataGrid.Items.Refresh()
    Update-SelectedCount
})

$SelectNoneButton.Add_Click({
    foreach ($item in $script:appItems) {
        $item.IsSelected = $false
    }
    $AppsDataGrid.Items.Refresh()
    Update-SelectedCount
})

$SelectEnabledButton.Add_Click({
    foreach ($item in $script:appItems) {
        $item.IsSelected = ($item.Status -eq "Enabled")
    }
    $AppsDataGrid.Items.Refresh()
    Update-SelectedCount
})

# Handle checkbox changes in DataGrid
$AppsDataGrid.Add_CellEditEnding({
    # Use Dispatcher.BeginInvoke to delay the update so the checkbox change is processed first
    $AppsDataGrid.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [System.Action]{
        Update-SelectedCount
    })
})

$UpdateCommandButton.Add_Click({
    Update-PowerShellCommand
    Save-Settings
})

$CopyCommandButton.Add_Click({
    [System.Windows.Clipboard]::SetText($PowerShellCommandTextBox.Text)
    [System.Windows.MessageBox]::Show(
        "PowerShell command copied to clipboard!",
        "Copied",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    )
})

$ExportButton.Add_Click({
    $selectedItems = $script:appItems | Where-Object { $_.IsSelected }
    
    if ($selectedItems.Count -eq 0) {
        [System.Windows.MessageBox]::Show(
            "Please select at least one application to export.",
            "No Selection",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
        return
    }
    
    $StatusLabel.Text = "Exporting selected applications..."
    
    # Prepare CSV data
    $csvData = @()
    foreach ($item in $selectedItems) {
        $app = $item.AppInfo
        
        $csvData += [PSCustomObject]@{
            VHDXPath = $app.VhdxPath
            VideoCaptureSeconds = [int]$VideoCaptureSecondsTextBox.Text
            RecordBeforeLaunch = $RecordBeforeAppLaunchCheckBox.IsChecked
            WaitAfterAttach = [int]$WaitAfterAttachTextBox.Text
        }
    }
    
    # Export to CSV
    try {
        $csvData | Export-Csv -Path $ExportPathTextBox.Text -NoTypeInformation -Force
        
        $StatusLabel.Text = "Exported $($csvData.Count) applications"
        
        [System.Windows.MessageBox]::Show(
            "Successfully exported $($csvData.Count) applications to:`n$($ExportPathTextBox.Text)",
            "Export Complete",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        )
        
        if ($OpenAfterExportCheckbox.IsChecked) {
            Start-Process $ExportPathTextBox.Text
        }
        
        Save-Settings
    }
    catch {
        [System.Windows.MessageBox]::Show(
            "Failed to export: $_",
            "Export Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
        $StatusLabel.Text = "Export failed"
    }
})

# Load saved settings
Load-Settings

# Initialize PowerShell command
Update-PowerShellCommand

# Add window closing event to save settings
$window.Add_Closing({
    Save-Settings
})

# Show window
$window.ShowDialog()