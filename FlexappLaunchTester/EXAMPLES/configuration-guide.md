# FlexApp Testing Framework - Configuration Guide

## Overview

The FlexApp Testing Framework now supports configurable paths to address deployment scenarios where scripts need to run from different locations or access resources over the network.

## Problem Solved

Previously, scripts had hardcoded paths like:
- `".\FlexApp-Test-Runner.ps1"` in the Batch Manager
- `"C:\ffmpeg\bin\ffmpeg.exe"` for FFmpeg
- `"\\server\share\Automation\LaunchTesting\Flexapp-Testing\CORE\FlexApp-Batch-Manager.ps1"` in deployment scenarios

These hardcoded paths made it difficult to:
- Deploy the framework to different locations
- Run tests from network shares
- Customize tool locations for different environments

## Configuration System

### Configuration File Structure

The framework uses a JSON configuration file with the following sections:

- **FrameworkPaths**: Core script locations (local deployment)
- **DefaultPaths**: Default tool and output locations
- **NetworkPaths**: Alternative paths for network deployment
- **TestDefaults**: Default test parameter values

### Configuration File Locations

1. **Default**: `CONFIG\framework-config.json` (in framework root)
2. **Custom**: Specify with `-ConfigPath` parameter
3. **Example**: Use `EXAMPLES\network-deployment-config.json` as template

## Usage Examples

### 1. Local Deployment (Default Behavior)

No configuration needed - framework uses relative paths:

```powershell
.\FlexApp-Launcher.ps1 -BatchConfig "CONFIG\flexapp-config.csv"
```

### 2. Network Deployment with Configuration File

Copy the network configuration:

```powershell
Copy-Item "EXAMPLES\network-deployment-config.json" "CONFIG\framework-config.json"
.\FlexApp-Launcher.ps1 -BatchConfig "CONFIG\flexapp-config.csv" -UseNetworkPaths
```

### 3. Custom Configuration File

```powershell
.\FlexApp-Launcher.ps1 -BatchConfig "CONFIG\flexapp-config.csv" -ConfigPath ".\custom-config.json" -UseNetworkPaths
```

### 4. Override Specific Paths

```powershell
# Use network config but override FFmpeg path
.\FlexApp-Launcher.ps1 -BatchConfig "CONFIG\flexapp-config.csv" -UseNetworkPaths -FFmpegPath "C:\Tools\ffmpeg\bin\ffmpeg.exe"
```

## Configuration Parameters

### New Launcher Parameters

- `-ConfigPath <path>`: Custom configuration file location
- `-UseNetworkPaths`: Enable network path mode

### Batch Manager Parameters

- `-ConfigPath <path>`: Custom configuration file location  
- `-UseNetworkPaths`: Enable network path mode
- `-TestRunnerPath <path>`: Override test runner location
- `-OutputBaseDir <path>`: Override output directory
- `-FFmpegPath <path>`: Override FFmpeg location

### Test Runner Parameters

- `-ConfigPath <path>`: Custom configuration file location
- `-UseNetworkPaths`: Enable network path mode
- `-FFmpegPath <path>`: Override FFmpeg location
- `-OutputDir <path>`: Override output directory

## Deployment Scenarios

### Scenario 1: Central Network Share

Framework deployed to `\\server\share\Automation\LaunchTesting\Flexapp-Testing`

**Setup**:
1. Copy framework to network share
2. Use `EXAMPLES\network-deployment-config.json` as template
3. Update paths to match your server/share names
4. Copy to `CONFIG\framework-config.json`

**Usage**:
```powershell
\\server\share\Automation\LaunchTesting\Flexapp-Testing\FlexApp-Launcher.ps1 -BatchConfig "CONFIG\flexapp-config.csv" -UseNetworkPaths
```

### Scenario 2: Local with Network Resources

Framework runs locally but accesses network resources:

**Custom Config**:
```json
{
    "DefaultPaths": {
        "FFmpegPath": "\\\\server\\share\\Tools\\ffmpeg\\bin\\ffmpeg.exe",
        "OutputBaseDir": "C:\\FlexAppTests"
    }
}
```

### Scenario 3: Multiple Environments

Different configurations for development, testing, production:

- `CONFIG\dev-config.json`
- `CONFIG\test-config.json`  
- `CONFIG\prod-config.json`

**Usage**:
```powershell
.\FlexApp-Launcher.ps1 -BatchConfig "CONFIG\flexapp-config.csv" -ConfigPath "CONFIG\prod-config.json"
```

## Migration from Hardcoded Paths

### Batch Manager Changes

**Before**:
```powershell
param(
    [string]$TestRunnerPath = ".\FlexApp-Test-Runner.ps1"
)
```

**After**:
```powershell
param(
    [string]$TestRunnerPath = "",  # Will be loaded from config
    [string]$ConfigPath = "",
    [switch]$UseNetworkPaths
)
```

### Backward Compatibility

- All existing parameter overrides still work
- No configuration file required for local deployment
- Default behavior unchanged if no config specified

## Troubleshooting

### Configuration Not Loading

1. Check file path: `CONFIG\framework-config.json`
2. Verify JSON syntax (use JSON validator)
3. Ensure file permissions allow reading

### Path Resolution Issues

1. Use absolute paths in configuration
2. Check network share accessibility
3. Verify UNC path format: `\\server\share\path`

### Network Path Access

1. Ensure current user has network share permissions
2. Consider using `net use` to map drives if needed
3. Test path accessibility: `Test-Path "\\server\share\path"`

## Configuration File Template

See `EXAMPLES\network-deployment-config.json` for a complete template that addresses the original hardcoded path issue mentioned in your request.

## Benefits

1. **Flexible Deployment**: Easy to move framework between environments
2. **Network Support**: First-class support for network share deployment
3. **Centralized Config**: Single file controls all path settings
4. **Backward Compatible**: Existing scripts continue to work
5. **Override Capable**: Command-line parameters override config settings
