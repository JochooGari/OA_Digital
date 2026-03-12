######################################################################################################
# Monitoring Script
# HTTP listener that logs performance metrics during load tests
######################################################################################################

param (
    [Parameter(Mandatory = $true)]
    [string]$TestId,
    
    [Parameter(Mandatory = $false)]
    [string]$LogDir
)

# Use passed log directory or fallback to script directory
if ([string]::IsNullOrEmpty($LogDir)) {
    $LogDir = Join-Path $PSScriptRoot "logs"
}

# Ensure log directory exists
if (!(Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory | Out-Null
    Write-Output "Created log directory: $LogDir"
}

# Log file in script directory
$logFile = Join-Path $LogDir "logPage.csv"

# Always create CSV with header if it doesn't exist
if (!(Test-Path $logFile)) { 
    "TestId,Timestamp,Instance,AvgDuration,Iteration,ErrorCount,Status,FilterConfig,BookmarkName,PageName,MemoryUsedMB,TimeToLoad,TimeToRender,TotalTime,IsCached" | Out-File -FilePath $logFile -Encoding UTF8 
    Write-Output "Initialized performance log: $logFile"
}

# Start HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8080/")
$listener.Start()
Write-Output "======================================"
Write-Output "Monitoring started on http://localhost:8080/"
Write-Output "Logging to: $logFile"
Write-Output "Send 'stop=1' in query string to stop listener"
Write-Output "======================================"

$requestCount = 0

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $stop = $ctx.Request.QueryString["stop"]
        $avg = $ctx.Request.QueryString["avg"]
        $instance = $ctx.Request.QueryString["instance"]

        if ($stop -eq "1") {
            Write-Output "Stop request received. Shutting down..."
            Write-Output "Total requests logged: $requestCount"
            $listener.Stop()
            break
        }

  if ($avg) {
    $iteration = $ctx.Request.QueryString["iteration"]
    $errorCount = $ctx.Request.QueryString["errorCount"]
    $status = $ctx.Request.QueryString["status"]
    $filterConfig = $ctx.Request.QueryString["filterConfig"]
    $bookmarkName = $ctx.Request.QueryString["bookmarkName"]
    $pageName = $ctx.Request.QueryString["pageName"]
    $memoryMB = $ctx.Request.QueryString["memoryMB"]
    $timeToLoad = $ctx.Request.QueryString["timeToLoad"]
    $timeToRender = $ctx.Request.QueryString["timeToRender"]
    $totalTime = $ctx.Request.QueryString["totalTime"]
    $isCached = $ctx.Request.QueryString["isCached"]
    
    # Default values if not provided
    if ([string]::IsNullOrEmpty($iteration)) { $iteration = "" }
    if ([string]::IsNullOrEmpty($errorCount)) { $errorCount = "0" }
    if ([string]::IsNullOrEmpty($status)) { $status = "Success" }
    if ([string]::IsNullOrEmpty($filterConfig)) { $filterConfig = "" }
    if ([string]::IsNullOrEmpty($bookmarkName)) { $bookmarkName = "" }
    if ([string]::IsNullOrEmpty($pageName)) { $pageName = "" }
    if ([string]::IsNullOrEmpty($memoryMB)) { $memoryMB = "" }
    if ([string]::IsNullOrEmpty($timeToLoad)) { $timeToLoad = "" }
    if ([string]::IsNullOrEmpty($timeToRender)) { $timeToRender = "" }
    if ([string]::IsNullOrEmpty($totalTime)) { $totalTime = "" }
    if ([string]::IsNullOrEmpty($isCached)) { $isCached = "0" }
    
    $logLine = "$TestId,$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$instance,$avg,$iteration,$errorCount,$status,$filterConfig,$bookmarkName,$pageName,$memoryMB,$timeToLoad,$timeToRender,$totalTime,$isCached"
    Add-Content -Path $logFile -Value $logLine
    $requestCount++
    
    $cacheIndicator = if ($isCached -eq "1") { "(CACHED)" } else { "" }
    Write-Output "[$requestCount] Instance=$instance, Load=$timeToLoad s, Render=$timeToRender s, Total=$totalTime s $cacheIndicator"
}

        $ctx.Response.StatusCode = 200
        $ctx.Response.Close()
    }
}
catch {
    Write-Output "ERROR: An error occurred: $_"
}
finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
    $listener.Dispose()
    Write-Output "======================================"
    Write-Output "Listener stopped and resources cleaned up."
    Write-Output "Total metrics logged: $requestCount"
    Write-Output "Log file: $logFile"
}