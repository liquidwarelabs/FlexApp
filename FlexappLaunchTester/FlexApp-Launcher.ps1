# FlexApp-Launcher.ps1
# Main entry point for FlexApp Testing Framework
# Provides unified access to all testing capabilities

param(
    [Parameter(ParameterSetName="GUI")]
    [switch]$GUI,
    
    [Parameter(ParameterSetName="Batch", Mandatory=$true)]
    [string]$BatchConfig,
    
    [Parameter(ParameterSetName="Single", Mandatory=$true)]
    [string]$VhdxPath,
    
    [Parameter(ParameterSetName="Batch")]
    [Parameter(ParameterSetName="Single")]
    [string]$OutputDir,
    
    [Parameter(ParameterSetName="Batch")]
    [Parameter(ParameterSetName="Single")]
    [string]$FFmpegPath,
    
    [Parameter(ParameterSetName="Batch")]
    [Parameter(ParameterSetName="Single")]
    [int]$VideoCaptureSeconds,
    
    [Parameter(ParameterSetName="Batch")]
    [Parameter(ParameterSetName="Single")]
    [switch]$RecordBeforeAppLaunch,
    
    [Parameter(ParameterSetName="Batch")]
    [switch]$GenerateSummaryReport,
    
    [Parameter(ParameterSetName="Batch")]
    [switch]$ContinueOnError,
    
    [Parameter(ParameterSetName="Single")]
    [switch]$KeepAppOpen,
    
    [Parameter(ParameterSetName="Batch")]
    [Parameter(ParameterSetName="Single")]
    [Parameter(ParameterSetName="GUI")]
    [string]$ConfigPath,  # Optional custom config file path
    
    [Parameter(ParameterSetName="Batch")]
    [Parameter(ParameterSetName="Single")]
    [switch]$UseNetworkPaths,  # Use network paths from configuration
    
    [switch]$Help
)

# Get script directory and set up paths
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreDir = Join-Path $scriptRoot "CORE"
$guiDir = Join-Path $scriptRoot "GUI"
$modulesDir = Join-Path $scriptRoot "MODULES"

# Load common functions for configuration support
. "$modulesDir\FlexApp-Common-Functions.ps1"

# Display help information
function Show-Help {
    Write-Host @"
FlexApp Testing Framework - Unified Launcher
============================================

USAGE:
    .\FlexApp-Launcher.ps1                                # Launch GUI interface (default)
    .\FlexApp-Launcher.ps1 -GUI                           # Launch GUI interface (explicit)
    .\FlexApp-Launcher.ps1 -BatchConfig <csv> [options]   # Batch testing
    .\FlexApp-Launcher.ps1 -VhdxPath <path> [options]     # Single test
    .\FlexApp-Launcher.ps1 -Help                          # Show this help

MODES:
    GUI Mode:
        -GUI                    Launch the graphical application selector

    Batch Testing Mode:
        -BatchConfig <path>     Path to CSV configuration file
        -OutputDir <path>       Base directory for test outputs
        -FFmpegPath <path>      Path to FFmpeg executable
        -VideoCaptureSeconds <n> Recording duration (seconds)
        -RecordBeforeAppLaunch  Record before app launch
        -GenerateSummaryReport  Create HTML summary report
        -ContinueOnError        Continue batch on individual failures
        -ConfigPath <path>      Custom configuration file path
        -UseNetworkPaths        Use network paths from configuration

    Single Test Mode:
        -VhdxPath <path>        Path to FlexApp VHDX file
        -OutputDir <path>       Directory for test outputs
        -FFmpegPath <path>      Path to FFmpeg executable
        -VideoCaptureSeconds <n> Recording duration (seconds)
        -RecordBeforeAppLaunch  Record before app launch
        -KeepAppOpen           Don't close app after test
        -ConfigPath <path>      Custom configuration file path
        -UseNetworkPaths        Use network paths from configuration

EXAMPLES:
    # Launch GUI (default behavior)
    .\FlexApp-Launcher.ps1
    
    # Launch GUI (explicit)
    .\FlexApp-Launcher.ps1 -GUI

    # Batch test with custom settings
    .\FlexApp-Launcher.ps1 -BatchConfig "CONFIG\flexapp-config.csv" -GenerateSummaryReport

    # Batch test using network paths
    .\FlexApp-Launcher.ps1 -BatchConfig "CONFIG\flexapp-config.csv" -UseNetworkPaths

    # Single test
    .\FlexApp-Launcher.ps1 -VhdxPath "\\server\apps\MyApp.vhdx" -VideoCaptureSeconds 30
    
    # Single test with custom configuration
    .\FlexApp-Launcher.ps1 -VhdxPath "\\server\apps\MyApp.vhdx" -ConfigPath ".\config\custom.json"

DIRECTORY STRUCTURE:
    CONFIG\     Configuration files
    CORE\       Core testing engines
    GUI\        User interfaces
    MODULES\    Shared functionality modules
    EXAMPLES\   Documentation and usage examples

For detailed documentation, see EXAMPLES\ directory.
"@ -ForegroundColor Cyan
}

# Validate framework integrity
function Test-FrameworkIntegrity {
    $required = @(
        (Join-Path $coreDir "FlexApp-Batch-Manager.ps1"),
        (Join-Path $coreDir "FlexApp-Test-Runner.ps1"),
        (Join-Path $guiDir "FlexApp-Selection-Tool.ps1"),
        (Join-Path $scriptRoot "MODULES\FlexApp-Common-Functions.ps1")
    )
    
    $missing = @()
    foreach ($file in $required) {
        if (!(Test-Path $file)) {
            $missing += $file
        }
    }
    
    if ($missing.Count -gt 0) {
        Write-Error "Framework integrity check failed. Missing files:"
        $missing | ForEach-Object { Write-Error "  $_" }
        return $false
    }
    
    return $true
}

# Main execution logic
function Main {
    Write-Host "FlexApp Testing Framework" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    
    # Show help if requested
    if ($Help) {
        Show-Help
        return
    }
    
    # Default to GUI if no parameters specified
    if ($PSBoundParameters.Count -eq 0) {
        Write-Host "No parameters specified - launching GUI interface..." -ForegroundColor Green
        $GUI = $true
    }
    
    # Load framework configuration early for path resolution
    $frameworkConfig = Get-FrameworkConfig -ConfigPath $ConfigPath -UseNetworkPaths:$UseNetworkPaths
    
    # Validate framework
    if (!(Test-FrameworkIntegrity)) {
        Write-Error "Framework validation failed. Please check installation."
        exit 1
    }
    
    # Display configuration information if using network paths
    if ($UseNetworkPaths) {
        Write-Host "Using Network Paths Configuration:" -ForegroundColor Yellow
        Write-Host "  Automation Root: $($frameworkConfig.NetworkPaths.AutomationRoot)" -ForegroundColor Gray
    }
    
    try {
        # Determine execution mode
        if ($GUI) {
            Write-Host "Launching GUI Application Selector..." -ForegroundColor Green
            $guiScript = Join-Path $guiDir "FlexApp-Selection-Tool.ps1"
            & $guiScript
        }
        elseif ($BatchConfig) {
            Write-Host "Starting Batch Testing Mode..." -ForegroundColor Green
            
            # Resolve batch manager path from configuration
            $batchScript = Resolve-FrameworkPath -PathType "BatchManagerPath" -Config $frameworkConfig -FallbackPath (Join-Path $coreDir "FlexApp-Batch-Manager.ps1")
            
            # Build parameters for batch manager
            $batchParams = @{
                ListFile = $BatchConfig
            }
            
            # Pass configuration parameters
            if ($ConfigPath) { $batchParams.ConfigPath = $ConfigPath }
            if ($UseNetworkPaths) { $batchParams.UseNetworkPaths = $true }
            
            # Pass other parameters
            if ($OutputDir) { $batchParams.OutputBaseDir = $OutputDir }
            if ($FFmpegPath) { $batchParams.FFmpegPath = $FFmpegPath }
            if ($VideoCaptureSeconds) { $batchParams.VideoCaptureSeconds = $VideoCaptureSeconds }
            if ($RecordBeforeAppLaunch) { $batchParams.RecordBeforeAppLaunch = $true }
            if ($GenerateSummaryReport) { $batchParams.GenerateSummaryReport = $true }
            if ($ContinueOnError) { $batchParams.ContinueOnError = $true }
            
            & $batchScript @batchParams
        }
        elseif ($VhdxPath) {
            Write-Host "Starting Single Test Mode..." -ForegroundColor Green
            
            # Resolve test runner path from configuration
            $testScript = Resolve-FrameworkPath -PathType "TestRunnerPath" -Config $frameworkConfig -FallbackPath (Join-Path $coreDir "FlexApp-Test-Runner.ps1")
            
            # Build parameters for test runner
            $testParams = @{
                VhdxPath = $VhdxPath
            }
            
            # Pass configuration parameters
            if ($ConfigPath) { $testParams.ConfigPath = $ConfigPath }
            if ($UseNetworkPaths) { $testParams.UseNetworkPaths = $true }
            
            # Pass other parameters
            if ($OutputDir) { $testParams.OutputDir = $OutputDir }
            if ($FFmpegPath) { $testParams.FFmpegPath = $FFmpegPath }
            if ($VideoCaptureSeconds) { $testParams.VideoCaptureSeconds = $VideoCaptureSeconds }
            if ($RecordBeforeAppLaunch) { $testParams.RecordBeforeLaunch = $true }
            if ($KeepAppOpen) { $testParams.KeepAppOpen = $true }
            
            & $testScript @testParams
        }
        else {
            Write-Error "No valid execution mode specified. Use -GUI, -BatchConfig, or -VhdxPath."
            exit 1
        }
    }
    catch {
        Write-Error "Execution failed: $_"
        exit 1
    }
}

# Execute main function
Main
