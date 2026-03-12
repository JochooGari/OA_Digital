######################################################################################################
# Orchestrator Script
# Runs setup_load_test.ps1, Monitoring.ps1 (background), View-LiveMetrics.ps1 (new window),
# and run_load_test_only.ps1
# Logs test executions with TestId, StartTime, EndTime, Status in a CSV file
######################################################################################################

param (
    [Parameter(Mandatory = $true)]
    [string]$TestId,   # you must provide this when running the script
    
    [Parameter(Mandatory = $false)]
    [int]$MetricsRefreshSeconds = 5  # How often to refresh live metrics
)

$ErrorActionPreference = "Stop"
$workingDir = $PSScriptRoot
$monitorJob = $null
$metricsProcess = $null
$status = "Success"

# Pre-flight check: Unblock scripts
Write-Host "=== Pre-flight Checks ===" -ForegroundColor Cyan
$blockedFiles = Get-ChildItem -Path $workingDir -Filter *.ps1 | Where-Object { 
    (Get-Item $_.FullName -Stream Zone.Identifier -ErrorAction SilentlyContinue) -ne $null 
}

if ($blockedFiles) {
    Write-Host "WARNING: Some scripts are blocked by Windows" -ForegroundColor Yellow
    Write-Host "Attempting to unblock automatically..." -ForegroundColor Cyan
    
    try {
        Get-ChildItem -Path $workingDir -Filter *.ps1 | Unblock-File -ErrorAction Stop
        Write-Host "Scripts unblocked successfully!" -ForegroundColor Green
    } catch {
        Write-Host "Could not unblock scripts automatically" -ForegroundColor Red
        Write-Host "Please run this command manually as Administrator:" -ForegroundColor Yellow
        Write-Host "  Get-ChildItem -Path '$workingDir' -Filter *.ps1 | Unblock-File" -ForegroundColor White
        exit 1
    }
}

# Log directory in script folder
$logDir = Join-Path $workingDir "logs"
if (!(Test-Path $logDir)) { 
    New-Item -Path $logDir -ItemType Directory | Out-Null 
    Write-Host "Created log directory: $logDir" -ForegroundColor Green
}

$logFile = Join-Path $logDir "orchestrator_log.csv"
$performanceLog = Join-Path $logDir "logPage.csv"

# Initialize orchestrator log file with header if it doesn't exist
if (!(Test-Path $logFile)) {
    "TestId,StartTime,EndTime,Status" | Set-Content -Path $logFile
    Write-Host "Initialized orchestrator log: $logFile" -ForegroundColor Green
}

# Capture start time
$startTime = Get-Date

# Step 0: Remove all folders in the current directory except  and "logs"
Write-Host "`n=== Cleanup Phase ===" -ForegroundColor Cyan
Get-ChildItem -Path $workingDir -Directory | Where-Object {$_.Name -notin @("logs")} | ForEach-Object {
    try {
        Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction Stop
        Write-Host "Removed folder: $($_.Name)" -ForegroundColor Gray
    } catch {
        Write-Host "Failed to remove folder $($_.Name): $_" -ForegroundColor Red
        $status = "Failed"
    }
}

try {
    # Step 1: Setup load test
    Write-Host "`n=== Running setup_load_test.ps1 ===" -ForegroundColor Cyan
    & "$workingDir\setup_load_test.ps1"

    # Step 2: Start monitoring in the background
    Write-Host "`n=== Starting Monitoring.ps1 in background ===" -ForegroundColor Cyan
    $monitorJob = Start-Job -FilePath "$workingDir\Monitoring.ps1" -ArgumentList $TestId, $logDir

    # Give monitoring a few seconds to spin up
    Start-Sleep -Seconds 3
    if (-not ($monitorJob | Get-Job).State -eq "Running") {
        throw "Monitoring.ps1 failed to start."
    }
    Write-Host "Monitoring job started successfully (Job ID: $($monitorJob.Id))" -ForegroundColor Green

    # Step 2.5: Start live metrics viewer in a NEW WINDOW
    Write-Host "`n=== Opening Live Metrics Viewer in new window ===" -ForegroundColor Cyan
    
    $metricsScriptPath = Join-Path $workingDir "View-LiveMetrics.ps1"
    
    if (Test-Path $metricsScriptPath) {
        # Build the PowerShell command to run in the new window
        $metricsCommand = "& '$metricsScriptPath' -LogFile '$performanceLog' -RefreshSeconds $MetricsRefreshSeconds"
        
        # Open new PowerShell window with the metrics viewer
        $metricsProcess = Start-Process powershell -ArgumentList @(
            "-NoExit",
            "-ExecutionPolicy", "Bypass",
            "-Command", $metricsCommand
        ) -PassThru -WindowStyle Normal
        
        Write-Host "Live metrics window opened (Process ID: $($metricsProcess.Id))" -ForegroundColor Green
        Write-Host "A new PowerShell window should appear showing live metrics" -ForegroundColor Yellow
    } else {
        Write-Host "WARNING: View-LiveMetrics.ps1 not found at: $metricsScriptPath" -ForegroundColor Yellow
        Write-Host "Continuing without live metrics viewer..." -ForegroundColor Yellow
    }

    # Step 3: Run load test
    Write-Host "`n=== Running run_load_test_only.ps1 ===" -ForegroundColor Cyan
    Write-Host "Chrome windows will open shortly..." -ForegroundColor Yellow
    Write-Host "Watch the Live Metrics window for real-time performance data" -ForegroundColor Yellow
    Write-Host ""
    
    & "$workingDir\run_load_test_only.ps1"

}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    $status = "Failed"
}
finally {
    # Capture end time
    $endTime = Get-Date

    # Stop live metrics viewer window
    if ($metricsProcess -ne $null) {
        Write-Host "`nClosing Live Metrics Viewer window..." -ForegroundColor Cyan
        try {
            if (!$metricsProcess.HasExited) {
                Stop-Process -Id $metricsProcess.Id -Force -ErrorAction SilentlyContinue
                Write-Host "Live metrics viewer window closed" -ForegroundColor Gray
            } else {
                Write-Host "Live metrics viewer window already closed" -ForegroundColor Gray
            }
        } catch {
            Write-Host "WARNING: Could not close metrics viewer window cleanly" -ForegroundColor Yellow
        }
    }

    # Stop monitoring
    if ($monitorJob -ne $null) {
        Write-Host "Stopping Monitoring.ps1..." -ForegroundColor Cyan
        try {
            Write-Host "Sending stop signal to Monitoring.ps1..." -ForegroundColor Gray
            Invoke-WebRequest "http://localhost:8080/?stop=1" -UseBasicParsing -TimeoutSec 5 | Out-Null
            Start-Sleep -Seconds 2
        } catch {
            Write-Host "WARNING: Could not contact Monitoring.ps1 on localhost:8080" -ForegroundColor Yellow
        }

        try { 
            Stop-Job $monitorJob -ErrorAction SilentlyContinue 
            Remove-Job $monitorJob -ErrorAction SilentlyContinue 
            Write-Host "Monitoring job stopped" -ForegroundColor Gray
        } catch {}
    }

    # Append log entry
    $logLine = "$TestId,$startTime,$endTime,$status"
    Add-Content -Path $logFile -Value $logLine

    # Display final summary
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "                      TEST EXECUTION SUMMARY                          " -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Test ID:        $TestId" -ForegroundColor White
    Write-Host "Status:         $status" -ForegroundColor $(if($status -eq "Success"){"Green"}else{"Red"})
    Write-Host "Start Time:     $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
    Write-Host "End Time:       $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
    Write-Host "Duration:       $(($endTime - $startTime).ToString('hh\:mm\:ss'))" -ForegroundColor White
    Write-Host ""
    Write-Host "Logs Location:  $logDir" -ForegroundColor White
    Write-Host "  - orchestrator_log.csv  (Test execution history)" -ForegroundColor Gray
    Write-Host "  - logPage.csv           (Performance metrics)" -ForegroundColor Gray
    Write-Host ""
    
    # Show quick performance summary if available
    if (Test-Path $performanceLog) {
        $perfData = Import-Csv $performanceLog | Where-Object {$_.AvgDuration -match '^\d+$'}
        if ($perfData.Count -gt 0) {
            $avgDuration = [math]::Round(($perfData | Measure-Object -Property AvgDuration -Average).Average, 2)
            $totalRefreshes = $perfData.Count
            $uniqueInstances = ($perfData | Select-Object -Unique Instance).Count
            
            Write-Host "PERFORMANCE SUMMARY:" -ForegroundColor White
            Write-Host "  Total Refreshes:      $totalRefreshes" -ForegroundColor White
            Write-Host "  Concurrent Instances: $uniqueInstances" -ForegroundColor White
            Write-Host "  Average Duration:     $avgDuration seconds" -ForegroundColor $(if($avgDuration -lt 10){"Green"}else{"Yellow"})
            Write-Host ""
        }
    }
    
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "  Next Steps:" -ForegroundColor Yellow
    Write-Host "    Run '.\Generate-TestReport.ps1 -TestId $TestId' for detailed analysis" -ForegroundColor White
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
}