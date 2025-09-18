# FlexApp Update Manager - WPF Implementation

This directory contains the WPF (Windows Presentation Foundation) implementation of the FlexApp Update Manager GUI.

## Overview

The WPF implementation provides a modern, scalable user interface with the following advantages over the original WinForms version:

- **Modern UI**: Clean, professional appearance with Material Design-inspired styling
- **Better Layout**: Responsive design that adapts to different screen sizes
- **Improved UX**: Better typography, spacing, and visual feedback
- **Hardware Acceleration**: Better performance through GPU acceleration
- **Maintainability**: Separation of UI (XAML) from logic (PowerShell)

## File Structure

```
WPF/
├── MainWindow.xaml                    # Main UI layout and styling
├── EditApplicationsDialog.xaml        # Edit applications dialog
├── Show-WPFFlexAppUpdateManager.ps1  # Main WPF window function
├── FlexAppUpdateManager-WPF.psm1     # PowerShell module
├── Launch-WPF.ps1                    # Launcher script
├── Test-WPF.ps1                      # Basic test script
├── README.md                         # This documentation
├── IMPLEMENTATION_SUMMARY.md         # Detailed implementation summary
└── Functions/                        # WPF-specific functions
    ├── Chocolatey/                   # Chocolatey-related functions
    ├── Winget/                       # Winget-related functions
    ├── ConfigurationManager/         # Configuration Manager functions
    └── ProfileUnity/                 # ProfileUnity functions
```

## Features

### Modern Styling
- Material Design-inspired color scheme
- Rounded corners and modern buttons
- Consistent spacing and typography
- Professional GroupBox styling
- Alternating row colors in DataGrids

### Responsive Layout
- Proper Grid and StackPanel layouts
- ScrollViewer for content overflow
- Minimum window size constraints
- Resizable window with proper constraints

### Enhanced User Experience
- Visual feedback on button hover and press
- Disabled state styling
- Progress indicators during operations
- Modern file dialogs
- Better status messaging

## Usage

### Basic Usage
```powershell
# Import the WPF module
Import-Module ".\WPF\FlexAppUpdateManager-WPF.psm1"

# Show the WPF interface
Show-WPFFlexAppUpdateManager
```

### Automatic GUI Selection
```powershell
# This will automatically choose WPF if available, otherwise fall back to WinForms
Show-FlexAppUpdateManagerGUI
```

### Force Specific Interface
```powershell
# Force WPF interface
Show-FlexAppUpdateManagerGUI -ForceWPF

# Force WinForms interface
Show-FlexAppUpdateManagerGUI -ForceWinForms
```

### Using the Launcher Script
```powershell
# Launch with automatic selection
.\Launch-WPF.ps1

# Force specific interface
.\Launch-WPF.ps1 -ForceWPF
.\Launch-WPF.ps1 -ForceWinForms
```

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- .NET Framework 4.5+ (for WPF assemblies)
- Same prerequisites as the main FlexApp Update Manager

## Integration with Existing Code

The WPF implementation is designed to work alongside the existing WinForms implementation:

1. **Shared Functions**: All business logic functions remain the same
2. **Event Handlers**: WPF event handlers call the same underlying functions
3. **Configuration**: Uses the same configuration system
4. **Logging**: Integrates with the existing logging system

## Key Differences from WinForms

### Event Handling
- Uses WPF event system instead of WinForms events
- Dispatcher.Invoke for thread-safe UI updates
- Modern file dialogs (Microsoft.Win32.OpenFileDialog)

### Data Binding
- DataGrid ItemsSource instead of manual row addition
- ObservableCollection for reactive data updates
- Better selection handling

### Styling
- XAML-based styling instead of code-based styling
- Consistent visual design across all controls
- Better accessibility support

## Testing

### Basic Test
Run the test script to verify WPF functionality:
```powershell
.\Test-WPF.ps1
```

This will check:
- WPF assembly availability
- XAML file presence
- Module import functionality
- Function availability

## Troubleshooting

### WPF Not Available
If WPF assemblies are not available, the system will automatically fall back to WinForms:
```powershell
Test-WPFAvailable  # Returns $false if WPF is not available
```

### XAML Loading Issues
If the XAML file cannot be loaded:
1. Ensure the XAML file is in the same directory as the PowerShell script
2. Check that the XAML syntax is valid
3. Verify .NET Framework is properly installed

### Performance Issues
- WPF uses hardware acceleration by default
- For large datasets, consider virtualizing DataGrid items
- Use background threads for long-running operations

## Migration from WinForms

To migrate existing code to use WPF:

1. **Replace UI calls**: Use WPF-specific update functions
   - `Update-WPFChocoStatus` instead of `Update-ChocoStatus`
   - `Populate-WPFChocoUpdatesGrid` instead of `Populate-ChocoUpdatesGrid`

2. **Update event handlers**: Use WPF event system
   - `Add_Click` instead of `Add_Click`
   - Use Dispatcher.Invoke for thread-safe updates

3. **Data binding**: Use ItemsSource instead of manual grid population
   - Create ObservableCollection objects
   - Bind to DataGrid ItemsSource property

## Future Enhancements

Potential improvements for the WPF implementation:

1. **MVVM Pattern**: Implement proper Model-View-ViewModel architecture
2. **Custom Controls**: Create specialized controls for specific functionality
3. **Themes**: Add support for light/dark themes
4. **Animations**: Add smooth transitions and animations
5. **Accessibility**: Enhanced accessibility features
6. **Touch Support**: Better touch interface support

## 📝 Memorial

This release is dedicated to the memory of Andreas Van Wingerden, who contributed to the FlexApp ecosystem and the broader IT community. His dedication to innovation and excellence continues to inspire the development of tools that make IT professionals' lives easier and more efficient.

*In loving memory of Andreas Van Wingerden.*

## Support

For issues with the WPF implementation:

1. Check the PowerShell console for error messages
2. Verify WPF assemblies are available: `Test-WPFAvailable`
3. Try the WinForms fallback: `Show-FlexAppUpdateManagerGUI -ForceWinForms`
4. Review the logging output for detailed error information
5. Run the test script: `.\Test-WPF.ps1`
