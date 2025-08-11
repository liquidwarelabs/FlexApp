# File: Functions\WPF\Test-WPFAvailable.ps1
# ===========================================
# Function to test if WPF assemblies are available

function Test-WPFAvailable {
    [CmdletBinding()]
    param()
    
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Add-Type -AssemblyName PresentationCore -ErrorAction Stop
        Add-Type -AssemblyName WindowsBase -ErrorAction Stop
        Add-Type -AssemblyName System.Xaml -ErrorAction Stop
        return $true
    }
    catch {
        Write-Warning "WPF assemblies not available: $($_.Exception.Message)"
        return $false
    }
}
