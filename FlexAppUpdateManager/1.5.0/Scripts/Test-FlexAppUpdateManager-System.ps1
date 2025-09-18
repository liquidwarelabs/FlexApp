# Scripts/Test-FlexAppUpdateManager-System.ps1
# Comprehensive system test for FlexApp Update Manager
# This script tests the application on different systems

param(
    [switch]$SkipGUI,
    [switch]$Verbose
)

Write-Host "=== FLEXAPP UPDATE MANAGER SYSTEM TEST ===" -ForegroundColor Magenta
Write-Host "Test started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host ""

# Test 1: PowerShell Version Check
Write-Host "TEST 1: PowerShell Version Check" -ForegroundColor Yellow
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "PowerShell Edition: $($PSVersionTable.PSEdition)" -ForegroundColor Gray
Write-Host "OS Version: $([System.Environment]::OSVersion.VersionString)" -ForegroundColor Gray

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "WARNING: PowerShell 5.0 or higher is recommended" -ForegroundColor Yellow
} else {
    Write-Host "SUCCESS: PowerShell version is compatible" -ForegroundColor Green
}
Write-Host ""

# Test 2: Module Loading Test
Write-Host "TEST 2: Module Loading Test" -ForegroundColor Yellow
try {
    $modulePath = Join-Path $PSScriptRoot "..\FlexAppUpdateManager.psm1"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction Stop
        Write-Host "SUCCESS: FlexAppUpdateManager module loaded successfully" -ForegroundColor Green
        
        # Check if key functions are available
        $requiredFunctions = @(
            "Show-FlexAppUpdateManager",
            "Start-WPFIntuneUpload",
            "New-IntunePackage",
            "Add-IntuneApplicationMSEndpointMgr"
        )
        
        foreach ($func in $requiredFunctions) {
            if (Get-Command $func -ErrorAction SilentlyContinue) {
                Write-Host "  SUCCESS: Function $func is available" -ForegroundColor Green
            } else {
                Write-Host "  ERROR: Function $func is missing" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "ERROR: Module file not found at $modulePath" -ForegroundColor Red
    }
} catch {
    Write-Host "ERROR: Failed to load module: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 3: XAML Loading Test
Write-Host "TEST 3: XAML Loading Test" -ForegroundColor Yellow
try {
    $xamlPath = Join-Path $PSScriptRoot "..\GUI\MainWindow.xaml"
    if (Test-Path $xamlPath) {
        Write-Host "SUCCESS: XAML file found at $xamlPath" -ForegroundColor Green
        
        # Test XAML syntax
        $xamlContent = Get-Content $xamlPath -Raw
        if ($xamlContent -match "IntuneConsoleOutputTextBox") {
            Write-Host "SUCCESS: Console output TextBox found in XAML" -ForegroundColor Green
        } else {
            Write-Host "WARNING: Console output TextBox not found in XAML" -ForegroundColor Yellow
        }
        
        if ($xamlContent -match "IntuneClearConsoleButton") {
            Write-Host "SUCCESS: Clear Console button found in XAML" -ForegroundColor Green
        } else {
            Write-Host "WARNING: Clear Console button not found in XAML" -ForegroundColor Yellow
        }
        
        # Check for Unicode characters that might cause issues
        if ($xamlContent -match "[^\x00-\x7F]") {
            Write-Host "WARNING: Unicode characters found in XAML - may cause parsing issues" -ForegroundColor Yellow
        } else {
            Write-Host "SUCCESS: No problematic Unicode characters in XAML" -ForegroundColor Green
        }
    } else {
        Write-Host "ERROR: XAML file not found at $xamlPath" -ForegroundColor Red
    }
} catch {
    Write-Host "ERROR: XAML test failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 4: PowerShell Code Syntax Test
Write-Host "TEST 4: PowerShell Code Syntax Test" -ForegroundColor Yellow
$psFiles = @(
    "Functions\WPF\Start-WPFIntuneUpload.ps1",
    "Functions\Intune\Add-IntuneApplicationMSEndpointMgr.ps1",
    "Functions\Intune\New-IntunePackage.ps1",
    "Functions\Intune\Start-IntuneUpload.ps1"
)

foreach ($file in $psFiles) {
    $filePath = Join-Path $PSScriptRoot "..\$file"
    if (Test-Path $filePath) {
        try {
            # Test syntax by parsing the file
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $filePath -Raw), [ref]$null)
            Write-Host "  SUCCESS: $file syntax is valid" -ForegroundColor Green
        } catch {
            Write-Host "  ERROR: $file has syntax errors: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  WARNING: $file not found" -ForegroundColor Yellow
    }
}
Write-Host ""

# Test 5: Unicode Character Test
Write-Host "TEST 5: Unicode Character Test" -ForegroundColor Yellow
$unicodeFiles = Get-ChildItem -Path (Join-Path $PSScriptRoot "..\Functions") -Filter "*.ps1" -Recurse
$unicodeIssues = 0

foreach ($file in $unicodeFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match "[^\x00-\x7F]") {
        Write-Host "  WARNING: Unicode characters found in $($file.Name)" -ForegroundColor Yellow
        $unicodeIssues++
    }
}

if ($unicodeIssues -eq 0) {
    Write-Host "SUCCESS: No Unicode characters found in PowerShell files" -ForegroundColor Green
} else {
    Write-Host "WARNING: $unicodeIssues files contain Unicode characters" -ForegroundColor Yellow
}
Write-Host ""

# Test 6: Dependencies Test
Write-Host "TEST 6: Dependencies Test" -ForegroundColor Yellow

# Check for IntuneWinAppUtil.exe
$intuneToolPaths = @(
    "C:\Program Files (x86)\Microsoft Intune\IntuneWinAppUtil.exe",
    "C:\Program Files\Microsoft Intune\IntuneWinAppUtil.exe",
    "C:\temp\IntuneWinAppUtil.exe"
)

$intuneToolFound = $false
foreach ($path in $intuneToolPaths) {
    if (Test-Path $path) {
        Write-Host "SUCCESS: IntuneWinAppUtil.exe found at $path" -ForegroundColor Green
        $intuneToolFound = $true
        break
    }
}

if (-not $intuneToolFound) {
    Write-Host "WARNING: IntuneWinAppUtil.exe not found in common locations" -ForegroundColor Yellow
    Write-Host "  This tool is required for creating .intunewin files" -ForegroundColor Gray
}

# Check for MSEndpointMgr module
try {
    $module = Get-Module -ListAvailable -Name "IntuneWin32App" | Select-Object -First 1
    if ($module) {
        Write-Host "SUCCESS: MSEndpointMgr IntuneWin32App module found (Version: $($module.Version))" -ForegroundColor Green
    } else {
        Write-Host "WARNING: MSEndpointMgr IntuneWin32App module not found" -ForegroundColor Yellow
        Write-Host "  This module is required for Intune uploads" -ForegroundColor Gray
    }
} catch {
    Write-Host "WARNING: Could not check for MSEndpointMgr module" -ForegroundColor Yellow
}
Write-Host ""

# Test 7: GUI Test (if not skipped)
if (-not $SkipGUI) {
    Write-Host "TEST 7: GUI Loading Test" -ForegroundColor Yellow
    try {
        # Test if WPF assemblies are available
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Add-Type -AssemblyName PresentationCore -ErrorAction Stop
        Add-Type -AssemblyName WindowsBase -ErrorAction Stop
        Write-Host "SUCCESS: WPF assemblies loaded successfully" -ForegroundColor Green
        
        # Test XAML loading
        $xamlPath = Join-Path $PSScriptRoot "..\GUI\MainWindow.xaml"
        $xamlContent = Get-Content $xamlPath -Raw
        
        # Create XML reader
        $xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
        Write-Host "SUCCESS: XAML XML reader created successfully" -ForegroundColor Green
        
        # Test XAML parsing (without loading into WPF)
        $xamlDoc = New-Object System.Xml.XmlDocument
        $xamlDoc.Load($xmlReader)
        Write-Host "SUCCESS: XAML parsed successfully" -ForegroundColor Green
        
        Write-Host "SUCCESS: GUI components are ready" -ForegroundColor Green
        
    } catch {
        Write-Host "ERROR: GUI test failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  This may indicate WPF or XAML issues" -ForegroundColor Gray
    }
} else {
    Write-Host "TEST 7: GUI Loading Test - SKIPPED" -ForegroundColor Yellow
}
Write-Host ""

# Test 8: File Permissions Test
Write-Host "TEST 8: File Permissions Test" -ForegroundColor Yellow
$testPaths = @(
    (Join-Path $PSScriptRoot "..\Functions"),
    (Join-Path $PSScriptRoot "..\GUI"),
    (Join-Path $PSScriptRoot "..\Config")
)

foreach ($path in $testPaths) {
    if (Test-Path $path) {
        try {
            $testFile = Join-Path $path "test_permissions.tmp"
            "test" | Out-File -FilePath $testFile -ErrorAction Stop
            Remove-Item $testFile -ErrorAction Stop
            Write-Host "  SUCCESS: Write access to $path" -ForegroundColor Green
        } catch {
            Write-Host "  WARNING: No write access to $path" -ForegroundColor Yellow
        }
    }
}
Write-Host ""

# Test 9: Network Connectivity Test
Write-Host "TEST 9: Network Connectivity Test" -ForegroundColor Yellow
$testUrls = @(
    "https://login.microsoftonline.com",
    "https://graph.microsoft.com",
    "https://www.powershellgallery.com"
)

foreach ($url in $testUrls) {
    try {
        $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 10 -ErrorAction Stop
        Write-Host "  SUCCESS: Can reach $url (Status: $($response.StatusCode))" -ForegroundColor Green
    } catch {
        Write-Host "  WARNING: Cannot reach $url - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
Write-Host ""

# Test 10: System Information
Write-Host "TEST 10: System Information" -ForegroundColor Yellow
Write-Host "Computer Name: $($env:COMPUTERNAME)" -ForegroundColor Gray
Write-Host "User: $($env:USERNAME)" -ForegroundColor Gray
Write-Host "Domain: $($env:USERDOMAIN)" -ForegroundColor Gray
Write-Host "Architecture: $($env:PROCESSOR_ARCHITECTURE)" -ForegroundColor Gray
Write-Host "PowerShell Execution Policy: $(Get-ExecutionPolicy)" -ForegroundColor Gray
Write-Host ""

# Summary
Write-Host "=== TEST SUMMARY ===" -ForegroundColor Magenta
Write-Host "Test completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host ""
Write-Host "To run the FlexApp Update Manager GUI:" -ForegroundColor Yellow
Write-Host "  Import-Module .\FlexAppUpdateManager.psm1 -Force" -ForegroundColor Gray
Write-Host "  Show-FlexAppUpdateManager" -ForegroundColor Gray
Write-Host ""
Write-Host "For verbose output during testing:" -ForegroundColor Yellow
Write-Host "  .\Test-FlexAppUpdateManager-System.ps1 -Verbose" -ForegroundColor Gray
Write-Host ""
Write-Host "To skip GUI tests:" -ForegroundColor Yellow
Write-Host "  .\Test-FlexAppUpdateManager-System.ps1 -SkipGUI" -ForegroundColor Gray
