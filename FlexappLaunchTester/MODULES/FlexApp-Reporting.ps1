# FlexApp-Reporting.ps1
# Functions for generating test reports

# Function to generate text report
function New-TextReport {
    param(
        [hashtable]$TestResult,
        [string]$OutputPath
    )
    
    $report = @"
FlexApp Test Report
==================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Application: $($TestResult.ApplicationName)
Version: $($TestResult.Version)
Package: $($TestResult.VhdxPath)

Test Results:
- FlexApp Attached: $(if ($TestResult.AttachSuccess) { "Success" } else { "Failed" })
- Application Launched: $(if ($TestResult.LaunchSuccess) { "Success" } else { "Failed" })$(if ($TestResult.NoExecutablesFound) { " (No executables in package)" })
- Recording Created: $(if ($TestResult.RecordingSuccess) { "Success" } else { "Failed" })
- Screenshot Created: $(if ($TestResult.ScreenshotSuccess) { "Success" } else { "Failed" })

Output Files:
- Video: $($TestResult.VideoPath)
- Screenshot: $($TestResult.ScreenshotPath)

Application Links Found:
$($TestResult.Links | ForEach-Object { "- $($_)" } | Out-String)

$(if ($TestResult.NoExecutablesFound) { 
"Note: This package contains no executable links. This is normal for library or configuration packages."
})
"@
    
    $report | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "Test report saved to: $OutputPath" -ForegroundColor Green
}

# Function to generate HTML report with relative paths
function New-HTMLReport {
    param(
        [array]$TestResults,
        [string]$OutputPath
    )
    
    $totalTests = $TestResults.Count
    $successfulTests = ($TestResults | Where-Object { $_.Success }).Count
    $failedTests = $totalTests - $successfulTests
    $noExecPackages = ($TestResults | Where-Object { $_.NoExecutablesFound }).Count
    
    # Calculate success rate without using Math::Round
    $successRate = 0
    if ($totalTests -gt 0) {
        $rate = ($successfulTests * 100) / $totalTests
        $successRate = [int]($rate + 0.5)  # Simple rounding
    }
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>FlexApp Batch Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .summary { background-color: white; padding: 20px; margin: 20px 0; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .summary-stats { display: flex; justify-content: space-around; margin: 20px 0; }
        .stat-box { text-align: center; padding: 15px; border-radius: 5px; }
        .stat-success { background-color: #27ae60; color: white; }
        .stat-failed { background-color: #e74c3c; color: white; }
        .stat-total { background-color: #3498db; color: white; }
        .stat-noexec { background-color: #f39c12; color: white; }
        table { width: 100%; border-collapse: collapse; background-color: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th { background-color: #34495e; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background-color: #f5f5f5; }
        .success { color: #27ae60; font-weight: bold; }
        .failed { color: #e74c3c; font-weight: bold; }
        .no-exec { color: #f39c12; font-style: italic; }
        .screenshot { max-width: 100px; max-height: 60px; cursor: pointer; }
        video { max-width: 200px; height: auto; }
        .modal { display: none; position: fixed; z-index: 1; left: 0; top: 0; width: 100%; height: 100%; background-color: rgba(0,0,0,0.9); }
        .modal-content { margin: 5% auto; display: block; max-width: 90%; max-height: 90%; }
        .close { position: absolute; top: 15px; right: 35px; color: #f1f1f1; font-size: 40px; font-weight: bold; cursor: pointer; }
    </style>
</head>
<body>
    <div class="header">
        <h1>FlexApp Batch Test Report</h1>
        <p>Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
    </div>
    
    <div class="summary">
        <h2>Test Summary</h2>
        <div class="summary-stats">
            <div class="stat-box stat-total">
                <h3>$totalTests</h3>
                <p>Total Tests</p>
            </div>
            <div class="stat-box stat-success">
                <h3>$successfulTests</h3>
                <p>Successful</p>
            </div>
            <div class="stat-box stat-failed">
                <h3>$failedTests</h3>
                <p>Failed</p>
            </div>
            <div class="stat-box stat-noexec">
                <h3>$noExecPackages</h3>
                <p>No Executables</p>
            </div>
            <div class="stat-box" style="background-color: #9b59b6; color: white;">
                <h3>$successRate%</h3>
                <p>Success Rate</p>
            </div>
        </div>
    </div>
    
    <h2>Test Details</h2>
    <table>
        <tr>
            <th>#</th>
            <th>Application</th>
            <th>VHDX Path</th>
            <th>Status</th>
            <th>Video Duration</th>
            <th>Test Duration</th>
            <th>Screenshot</th>
            <th>Video</th>
            <th>Notes</th>
        </tr>
"@
    
    foreach ($result in $TestResults) {
        $statusClass = if ($result.Success) { "success" } else { "failed" }
        $statusText = if ($result.Success) { "SUCCESS" } else { "FAILED" }
        
        $notes = ""
        if ($result.NoExecutablesFound) {
            $notes = "<span class='no-exec'>No executables in package</span>"
        } elseif ($result.Error) {
            $notes = $result.Error
        }
        
        $duration = "N/A"
        if ($result.Duration) {
            $totalSeconds = [int]$result.Duration.TotalSeconds
            $minutes = [int]($totalSeconds / 60)
            $seconds = $totalSeconds % 60
            $duration = "{0}:{1:00}" -f $minutes, $seconds
        }
        
        # Use relative paths for media files
        $testFolderName = "Test_$($result.TestNumber)"
        
        $videoHtml = "N/A"
        if ($result.VideoPath -and (Test-Path $result.VideoPath)) { 
            $videoFileName = Split-Path $result.VideoPath -Leaf
            $videoHtml = "<video controls><source src='$testFolderName/$videoFileName' type='video/mp4'></video>"
        }
        
        $screenshotHtml = "N/A"
        if ($result.ScreenshotPath -and (Test-Path $result.ScreenshotPath)) {
            $screenshotFileName = Split-Path $result.ScreenshotPath -Leaf
            $screenshotHtml = "<img class='screenshot' src='$testFolderName/$screenshotFileName' onclick='openModal(this)' alt='Screenshot'/>"
        }
        
        $html += @"
        <tr>
            <td>$($result.TestNumber)</td>
            <td>$($result.ApplicationName)</td>
            <td title="$($result.VhdxPath)">$(Split-Path $result.VhdxPath -Leaf)</td>
            <td class="$statusClass">$statusText</td>
            <td>$($result.VideoDuration)s</td>
            <td>$duration</td>
            <td>$screenshotHtml</td>
            <td>$videoHtml</td>
            <td>$notes</td>
        </tr>
"@
    }
    
    $html += @"
    </table>
    
    <div id="imageModal" class="modal" onclick="closeModal()">
        <span class="close">&times;</span>
        <img class="modal-content" id="modalImage">
    </div>
    
    <script>
        function openModal(img) {
            var modal = document.getElementById('imageModal');
            var modalImg = document.getElementById('modalImage');
            modal.style.display = 'block';
            modalImg.src = img.src;
        }
        
        function closeModal() {
            document.getElementById('imageModal').style.display = 'none';
        }
    </script>
</body>
</html>
"@
    
    $html | Out-File -FilePath $OutputPath -Encoding UTF8
}