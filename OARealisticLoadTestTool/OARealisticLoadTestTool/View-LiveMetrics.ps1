######################################################################################################
# View-LiveMetrics.ps1
# Real-Time Performance Metrics Viewer with Enhanced Data Display
# Displays live performance data including cache hits, timing breakdown, and errors
######################################################################################################

param (
    [Parameter(Mandatory = $true)]
    [string]$LogFile,
    
    [Parameter(Mandatory = $false)]
    [int]$RefreshSeconds = 5
)

function Get-ColorForDuration($duration) {
    if ($duration -lt 10) { return "Green" }
    elseif ($duration -lt 20) { return "Yellow" }
    else { return "Red" }
}

function Get-ColorForCacheRate($rate) {
    if ($rate -gt 70) { return "Green" }
    elseif ($rate -gt 40) { return "Yellow" }
    else { return "Red" }
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  LIVE PERFORMANCE METRICS VIEWER" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Log File: $LogFile" -ForegroundColor White
Write-Host "Refresh: Every $RefreshSeconds seconds" -ForegroundColor White
Write-Host ""

$lastLineCount = 0

while ($true) {
    if (Test-Path $LogFile) {
        $data = Import-Csv $LogFile
        
        if ($data.Count -gt $lastLineCount) {
            Clear-Host
            Write-Host "======================================================================" -ForegroundColor Cyan
            Write-Host "  LIVE PERFORMANCE METRICS - Updated: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
            Write-Host "======================================================================" -ForegroundColor Cyan
            Write-Host ""
            
            # Filter valid data
            $validData = $data | Where-Object {$_.AvgDuration -match '^\d+$'}
            
            if ($validData.Count -gt 0) {
                # Overall statistics
                $totalRefreshes = $validData.Count
                $uniqueInstances = ($validData | Select-Object -Unique Instance).Count
                $avgDuration = [math]::Round(($validData | Measure-Object -Property AvgDuration -Average).Average, 2)
                $maxDuration = ($validData | Measure-Object -Property AvgDuration -Maximum).Maximum
                $minDuration = ($validData | Measure-Object -Property AvgDuration -Minimum).Minimum
                
                # Cache statistics
                $cachedOps = ($validData | Where-Object {$_.IsCached -eq "1"}).Count
                $cacheRate = if ($totalRefreshes -gt 0) { [math]::Round(($cachedOps / $totalRefreshes) * 100, 2) } else { 0 }
                
                # Error statistics
                $errorOps = ($validData | Where-Object {$_.Status -eq "Error"}).Count
                $errorRate = if ($totalRefreshes -gt 0) { [math]::Round(($errorOps / $totalRefreshes) * 100, 2) } else { 0 }
                
                # Timing breakdown
                $timingData = $validData | Where-Object {$_.TimeToLoad -match '^\d+$' -and $_.TimeToRender -match '^-?\d+$'}
                if ($timingData.Count -gt 0) {
                    $avgLoad = [math]::Round(($timingData | Measure-Object -Property TimeToLoad -Average).Average, 2)
                    $avgRender = [math]::Round(($timingData | Measure-Object -Property TimeToRender -Average).Average, 2)
                }
                
                # Memory statistics
                $memoryData = $validData | Where-Object {$_.MemoryUsedMB -match '^\d+$'}
                if ($memoryData.Count -gt 0) {
                    $avgMemory = [math]::Round(($memoryData | Measure-Object -Property MemoryUsedMB -Average).Average, 2)
                    $maxMemory = ($memoryData | Measure-Object -Property MemoryUsedMB -Maximum).Maximum
                }
                
                Write-Host "OVERALL STATISTICS:" -ForegroundColor White
                Write-Host ("  Total Refreshes:   {0,6}" -f $totalRefreshes) -ForegroundColor White
                Write-Host ("  Active Instances:  {0,6}" -f $uniqueInstances) -ForegroundColor White
                Write-Host ("  Average Duration:  {0,6} seconds" -f $avgDuration) -ForegroundColor $(Get-ColorForDuration $avgDuration)
                Write-Host ("  Min Duration:      {0,6} seconds" -f $minDuration) -ForegroundColor Green
                Write-Host ("  Max Duration:      {0,6} seconds" -f $maxDuration) -ForegroundColor $(Get-ColorForDuration $maxDuration)
                Write-Host ""
                
                Write-Host "PERFORMANCE BREAKDOWN:" -ForegroundColor White
                if ($timingData.Count -gt 0) {
                    Write-Host ("  Avg Query/Load:    {0,6} seconds" -f $avgLoad) -ForegroundColor Cyan
                    Write-Host ("  Avg Render:        {0,6} seconds" -f $avgRender) -ForegroundColor Cyan
                    
                    # Bottleneck detection
                    if ($avgLoad -gt $avgRender * 1.5) {
                        Write-Host "  Bottleneck:        Data Model / Query" -ForegroundColor Red
                    } elseif ($avgRender -gt $avgLoad * 1.5) {
                        Write-Host "  Bottleneck:        Visual Rendering" -ForegroundColor Red
                    } else {
                        Write-Host "  Bottleneck:        Balanced" -ForegroundColor Green
                    }
                } else {
                    Write-Host "  Timing data not yet available..." -ForegroundColor Gray
                }
                Write-Host ""
                
                Write-Host "CACHE PERFORMANCE:" -ForegroundColor White
                Write-Host ("  Cache Hits:        {0,6} / {1} ({2}%)" -f $cachedOps, $totalRefreshes, $cacheRate) -ForegroundColor $(Get-ColorForCacheRate $cacheRate)
                
                # Calculate cache effectiveness
                $cachedData = $validData | Where-Object {$_.IsCached -eq "1"}
                $nonCachedData = $validData | Where-Object {$_.IsCached -eq "0"}
                if ($cachedData.Count -gt 0 -and $nonCachedData.Count -gt 0) {
                    $avgCached = [math]::Round(($cachedData | Measure-Object -Property AvgDuration -Average).Average, 2)
                    $avgNonCached = [math]::Round(($nonCachedData | Measure-Object -Property AvgDuration -Average).Average, 2)
                    $speedup = [math]::Round($avgNonCached / $avgCached, 2)
                    Write-Host ("  Cache Speedup:     {0}x faster" -f $speedup) -ForegroundColor Green
                    Write-Host ("  Avg Cached:        {0} seconds" -f $avgCached) -ForegroundColor Green
                    Write-Host ("  Avg Non-Cached:    {0} seconds" -f $avgNonCached) -ForegroundColor Yellow
                }
                Write-Host ""
                
                if ($memoryData.Count -gt 0) {
                    Write-Host "MEMORY USAGE:" -ForegroundColor White
                    Write-Host ("  Average:           {0,6} MB" -f $avgMemory) -ForegroundColor White
                    Write-Host ("  Maximum:           {0,6} MB" -f $maxMemory) -ForegroundColor $(if($maxMemory -gt 500){"Red"}elseif($maxMemory -gt 300){"Yellow"}else{"Green"})
                    Write-Host ""
                }
                
                if ($errorOps -gt 0) {
                    Write-Host "ERROR TRACKING:" -ForegroundColor Red
                    Write-Host ("  Total Errors:      {0,6} ({1}%)" -f $errorOps, $errorRate) -ForegroundColor Red
                    Write-Host ""
                }
                
                # Per-instance performance
                Write-Host "PER-INSTANCE PERFORMANCE:" -ForegroundColor White
                Write-Host ("{0,-25} {1,10} {2,10} {3,10} {4,12}" -f "Instance ID", "Refreshes", "Avg (s)", "Last (s)", "Cache Rate") -ForegroundColor Gray
                Write-Host ("{0,-25} {1,10} {2,10} {3,10} {4,12}" -f "-------------------------", "----------", "----------", "----------", "------------") -ForegroundColor Gray
                
                $validData | 
                    Group-Object Instance | 
                    Sort-Object Name |
                    ForEach-Object {
                        $instanceAvg = [math]::Round(($_.Group | Measure-Object -Property AvgDuration -Average).Average, 2)
                        $count = $_.Count
                        $lastDuration = $_.Group | Select-Object -Last 1 | Select-Object -ExpandProperty AvgDuration
                        $instanceCached = ($_.Group | Where-Object {$_.IsCached -eq "1"}).Count
                        $instanceCacheRate = [math]::Round(($instanceCached / $count) * 100, 2)
                        
                        $color = Get-ColorForDuration $lastDuration
                        Write-Host ("{0,-25} {1,10} {2,10} {3,10} {4,11}%" -f $_.Name, $count, $instanceAvg, $lastDuration, $instanceCacheRate) -ForegroundColor $color
                    }
                
                # Recent activity with enhanced details
                Write-Host ""
                Write-Host "RECENT ACTIVITY (Last 10):" -ForegroundColor White
                Write-Host ("{0,-20} {1,-25} {2,8} {3,7} {4,7} {5,8}" -f "Timestamp", "Instance", "Total", "Load", "Render", "Cached") -ForegroundColor Gray
                Write-Host ("{0,-20} {1,-25} {2,8} {3,7} {4,7} {5,8}" -f "--------------------", "-------------------------", "--------", "-------", "-------", "--------") -ForegroundColor Gray
                
                $validData | Select-Object -Last 10 | ForEach-Object {
                    $color = Get-ColorForDuration $_.AvgDuration
                    $cached = if ($_.IsCached -eq "1") { "YES" } else { "NO" }
                    $cachedColor = if ($_.IsCached -eq "1") { "Green" } else { "Yellow" }
                    
                    $timeToLoad = if ($_.TimeToLoad -match '^\d+$') { $_.TimeToLoad + "s" } else { "-" }
                    $timeToRender = if ($_.TimeToRender -match '^-?\d+$') { $_.TimeToRender + "s" } else { "-" }
                    
                    Write-Host ("{0,-20} {1,-25} " -f $_.Timestamp, $_.Instance) -NoNewline -ForegroundColor $color
                    Write-Host ("{0,8} {1,7} {2,7} " -f ($_.AvgDuration + "s"), $timeToLoad, $timeToRender) -NoNewline -ForegroundColor $color
                    Write-Host ("{0,8}" -f $cached) -ForegroundColor $cachedColor
                }
                
                # Filter/Bookmark insights (if data available)
                $bookmarkData = $validData | Where-Object {$_.BookmarkName -ne ""}
                if ($bookmarkData.Count -gt 5) {
                    Write-Host ""
                    Write-Host "TOP BOOKMARKS BY USAGE:" -ForegroundColor White
                    $bookmarkData | 
                        Group-Object BookmarkName | 
                        Sort-Object Count -Descending |
                        Select-Object -First 5 |
                        ForEach-Object {
                            $bmAvg = [math]::Round(($_.Group | Measure-Object -Property AvgDuration -Average).Average, 2)
                            $bmCached = ($_.Group | Where-Object {$_.IsCached -eq "1"}).Count
                            $bmCacheRate = [math]::Round(($bmCached / $_.Count) * 100, 2)
                            $bmName = $_.Name.Substring(0, [Math]::Min(25, $_.Name.Length))
                            Write-Host ("  {0,-25} | Count: {1,4} | Avg: {2,5}s | Cache: {3,5}%" -f $bmName, $_.Count, $bmAvg, $bmCacheRate) -ForegroundColor Cyan
                        }
                }
            }
            
            Write-Host ""
            Write-Host "======================================================================" -ForegroundColor Cyan
            Write-Host "  Monitoring active - Orchestrator will stop this automatically" -ForegroundColor Yellow
            Write-Host "======================================================================" -ForegroundColor Cyan
            
            $lastLineCount = $data.Count
        }
    } else {
        Write-Host "Waiting for performance log file to be created..." -ForegroundColor Yellow
        Write-Host "Log file expected at: $LogFile" -ForegroundColor Gray
    }
    
    Start-Sleep -Seconds $RefreshSeconds
}