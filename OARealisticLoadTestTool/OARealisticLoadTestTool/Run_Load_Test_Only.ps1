################################################################################################################################################################################
# Script executes the load test
# If run with no parameters, it will execute the load test found in each subfolder:
#  .\Run_Load_Test_Only.ps1
# If run with parameters, it will only execute the subfolders specified:
#  .\Run_Load_Test_Only.ps1 "DemoLoadTest1" "DemoLoadTest2"
# It pauses 5 seconds between opening each window so as not to overload the client machine CPU.
# Once load test windows are opened, press Enter to close only the test Chrome windows.
#
# WHY WE SERVE OVER HTTP:
#   Chrome blocks Web Workers (throttle-immune timers/watchdog) on file:// URLs.
#   A local HTTP server enables Workers fully on all instances.
#
# WHY WE TRACK PIDs:
#   We only kill Chrome processes we launched, preserving any the user had open.
################################################################################################################################################################################

$htmlFileName  = 'RealisticLoadTest.html'
$workingDir    = $pwd.Path
$httpPort      = 18080
$httpServerJob = $null
$launchedPids  = @()

"This script finds all subdirectories with $htmlFileName files and runs a specified number of instances of each."
$instances = [int] $(Read-Host -Prompt 'Enter number of instances to initiate for each report')

$numberOfPhysicalCores = (Get-WmiObject -class Win32_processor).NumberOfCores
if ($numberOfPhysicalCores.Length) {
    $numberOfPhysicalCores = ($numberOfPhysicalCores | Measure-Object -Sum).Sum
}
"Number of chrome processes to create: $numberOfPhysicalCores (# physical cores)"
"Each chrome process requires 1-2GB RAM!"

# Chrome registry tweaks
$registryPath = "HKCU:\Software\Policies\Google\Chrome"
"Setting registry $registryPath to prevent Chrome's software_reporter_tool.exe from running during this test"
$Name  = "ChromeCleanupEnabled"
$Name2 = "ChromeCleanupReportingEnabled"
$value = 0
try {
    New-Item -Path $registryPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name $Name  -Value $value -PropertyType DWORD -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name $Name2 -Value $value -PropertyType DWORD -Force | Out-Null
} catch {
    Write-Warning "Could not set Chrome cleanup policy. Continuing without it."
}

# Locate Chrome
$chromeExe = $null
$possiblePaths = @(
    "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
)
foreach ($path in $possiblePaths) {
    if (Test-Path $path) { $chromeExe = $path; break }
}
if (-not $chromeExe) { $chromeExe = (Get-Command chrome.exe -ErrorAction SilentlyContinue).Source }
if (-not $chromeExe) { throw "Google Chrome not found." }
"Using Chrome at: $chromeExe"

# -----------------------------------------------------------------------
# Start local HTTP server
# .json served as text/javascript (PBIToken.json and PBIReport.json are
# loaded as <script> tags; Chrome blocks them if MIME is application/json)
# /shutdown endpoint stops the server instantly without blocking timeout
# -----------------------------------------------------------------------
"Starting local HTTP server on port $httpPort..."
$httpServerJob = Start-Job -ScriptBlock {
    param($rootDir, $port)
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$port/")
    $listener.Start()
    $mimeTypes = @{
        '.html' = 'text/html; charset=utf-8'; '.htm' = 'text/html; charset=utf-8'
        '.js'   = 'application/javascript'
        '.json' = 'text/javascript'
        '.css'  = 'text/css'; '.png' = 'image/png'; '.jpg' = 'image/jpeg'
        '.jpeg' = 'image/jpeg'; '.gif' = 'image/gif'; '.svg' = 'image/svg+xml'
        '.ico'  = 'image/x-icon'; '.txt' = 'text/plain'
    }
    while ($listener.IsListening) {
        try {
            $context  = $listener.GetContext()
            $request  = $context.Request
            $response = $context.Response
            $urlPath  = [Uri]::UnescapeDataString($request.Url.LocalPath.TrimStart('/'))
            if ($urlPath -eq '__shutdown') {
                $body = [System.Text.Encoding]::UTF8.GetBytes("OK")
                $response.ContentLength64 = $body.Length
                $response.OutputStream.Write($body, 0, $body.Length)
                $response.OutputStream.Close()
                $listener.Stop(); break
            }
            $localPath = Join-Path $rootDir $urlPath
            if (Test-Path $localPath -PathType Leaf) {
                $ext   = [System.IO.Path]::GetExtension($localPath).ToLower()
                $mime  = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { 'application/octet-stream' }
                $bytes = [System.IO.File]::ReadAllBytes($localPath)
                $response.ContentType = $mime; $response.ContentLength64 = $bytes.Length
                $response.Headers.Add("Access-Control-Allow-Origin", "*")
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $response.StatusCode = 404
                $body = [System.Text.Encoding]::UTF8.GetBytes("404: $urlPath")
                $response.ContentLength64 = $body.Length
                $response.OutputStream.Write($body, 0, $body.Length)
            }
            $response.OutputStream.Close()
        } catch { if ($listener.IsListening) { Start-Sleep -Milliseconds 100 } }
    }
} -ArgumentList $workingDir, $httpPort

Start-Sleep -Seconds 2
try {
    Invoke-WebRequest "http://localhost:$httpPort/" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue | Out-Null
    "HTTP server started on http://localhost:$httpPort/"
} catch {
    if ($_ -match "404") { "HTTP server started on http://localhost:$httpPort/" }
    else { Write-Warning "HTTP server may not have started: $_" }
}

# -----------------------------------------------------------------------
# Chrome profile directories
#
# Each Chrome instance MUST have its own --user-data-dir. Without this,
# all chrome.exe invocations connect to the same running Chrome process
# (Chrome is single-instance by design), causing:
#   - All windows sharing one process/session (only 1 set of renderers)
#   - sessionStorage collisions between instances
#   - Start-Process PIDs being launcher stubs that exit immediately,
#     so taskkill finds nothing at cleanup time
#
# With separate --user-data-dir, each invocation is a truly independent
# Chrome process with its own renderer, memory space, sessionStorage,
# and a real persistent PID we can track and kill.
#
# Profiles are stored in ChromeProfiles\ (already excluded from cleanup
# by the orchestrator script). They are wiped and recreated each run to
# ensure clean state (no cached tokens, stale sessionStorage, etc.).
# -----------------------------------------------------------------------
$chromeProfilesDir = Join-Path $workingDir "ChromeProfiles"

# Wipe and recreate profiles dir for a clean run
if (Test-Path $chromeProfilesDir) {
    Remove-Item -Path $chromeProfilesDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -Path $chromeProfilesDir -ItemType Directory -Force | Out-Null
"Chrome profile directory ready: $chromeProfilesDir"

# Build directory list
$profile = 0; $directories = @()
foreach ($destinationDir in $args) { $directories += ,$destinationDir }
if ($directories.Length -eq 0) {
    foreach ($destinationDir in Get-ChildItem -Path $workingDir -Directory) { $directories += ,$destinationDir.Name }
}

# -----------------------------------------------------------------------
# Chrome launch flags:
#   --disable-background-timer-throttling    - stop setTimeout throttling
#   --disable-renderer-backgrounding         - stop CPU starvation of bg renderers
#   --disable-backgrounding-occluded-windows - stop throttling of hidden windows
#   --disable-background-media-suspend       - stop JS suspension in background
#   --disable-features=StopInBackground      - KEY FIX: disables Page Lifecycle
#                                              freeze. Without this, Chrome freezes
#                                              entire background pages (halting ALL
#                                              JS including Workers) under memory
#                                              pressure. Root cause of permanent stops.
#   --disable-features=BackgroundTaskScheduler - stops background task deprioritisation
#
# Start-Process -PassThru captures each PID so we close only our windows at cleanup.
# taskkill /T kills the full process tree (browser + renderers + GPU process).
# -----------------------------------------------------------------------
# -----------------------------------------------------------------------
# CHROME FLAGS — full explanation:
#
# Background throttling prevention (timers/Workers):
#   --disable-background-timer-throttling
#   --disable-renderer-backgrounding
#   --disable-backgrounding-occluded-windows
#   --disable-background-media-suspend
#
# Page Lifecycle freeze prevention:
#   --disable-features=StopInBackground
#       Stops Chrome freezing background pages under memory pressure.
#       navigator.locks in the HTML also guards against this, but the
#       flag is a belt-and-suspenders OS-level enforcement.
#
# OOM renderer kill prevention — the main remaining problem:
#   --memory-pressure-off
#       Disables Chrome's memory pressure notification system entirely.
#       Without this, Chrome monitors system RAM and when it crosses a
#       threshold it terminates background renderer processes outright.
#       A killed renderer cannot recover — no JS events fire, watchdog
#       goes silent, the window empties. This is why all instances die
#       simultaneously after ~1 minute: they all hit the threshold together.
#
#   --disable-features=TabDiscarding
#       Prevents Chrome from discarding (unloading) background pages
#       to reclaim memory. Discarded pages show a blank reload page.
#
#   --disable-features=MemoryPressureBasedSourceBufferGC
#       Prevents Chrome's garbage collector from aggressively evicting
#       source buffers in background pages under memory pressure.
#
#   --disable-features=BackgroundTaskScheduler
#       Stops background task deprioritisation.
# -----------------------------------------------------------------------
$chromeArgs = @(
    "--incognito",
    "--no-first-run",
    "--no-default-browser-check",
    "--new-window",
    "--disable-background-timer-throttling",
    "--disable-renderer-backgrounding",
    "--disable-backgrounding-occluded-windows",
    "--disable-background-media-suspend",
    "--memory-pressure-off",
    "--disable-features=StopInBackground,TabDiscarding,MemoryPressureBasedSourceBufferGC,BackgroundTaskScheduler"
)

foreach ($destinationDir in $directories) {
    $reportHtmlFile = Join-Path (Join-Path $workingDir $destinationDir) $htmlFileName
    if (Test-Path -path $reportHtmlFile) {
        $relativePath = $reportHtmlFile.Substring($workingDir.Length).Replace('\', '/').TrimStart('/')
        $reportUrl    = "http://localhost:$httpPort/$relativePath"
        "Opening: $reportUrl"
        $loopCounter = [int]$instances
        while ($loopCounter -gt 0) {
            # Unique profile dir per instance — forces a separate Chrome process
            $instanceIndex  = ($instances - $loopCounter) + (($instances) * [array]::IndexOf($directories, $destinationDir))
            $profileDir     = Join-Path $chromeProfilesDir "Profile_$instanceIndex"
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null

            $instanceArgs = $chromeArgs + @("--user-data-dir=$profileDir", $reportUrl)

            $proc = Start-Process -FilePath $chromeExe `
                                  -ArgumentList $instanceArgs `
                                  -PassThru -ErrorAction SilentlyContinue

            if ($proc) {
                $launchedPids += $proc.Id
                "  Launched Chrome PID $($proc.Id) | Profile: Profile_$instanceIndex | URL: $reportUrl"
            } else {
                Write-Warning "  Failed to launch Chrome instance $instanceIndex"
            }
            $loopCounter--
            $profile = ($profile + 1) % $numberOfPhysicalCores
            Start-Sleep -Seconds 5
        }
    } else {
        Write-Host "SKIPPED: No HTML file found at $reportHtmlFile" -ForegroundColor Yellow
    }
}

"Press enter when load test is complete: "
pause

# -----------------------------------------------------------------------
# Close ONLY the Chrome windows opened by this script.
#
# WHY NOT USE $launchedPids:
#   Chrome forks during startup. Start-Process -PassThru captures the
#   short-lived launcher process which exits in milliseconds. By the time
#   cleanup runs those PIDs are dead and taskkill finds nothing.
#
# CORRECT APPROACH — WMI command-line query:
#   After launching, we query WMI for all chrome.exe processes whose
#   CommandLine contains our ChromeProfiles directory path. This uniquely
#   identifies our processes since the path is specific to this test run.
#   We wait 3 seconds first to let Chrome fully fork and settle.
# -----------------------------------------------------------------------
"Closing test Chrome windows (only the ones opened by this script)..."


# Get ALL chrome.exe processes whose command line references our profiles dir
$allOurChromeProcs = Get-CimInstance Win32_Process -Filter "Name = 'chrome.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*$chromeProfilesDir*" }

if ($allOurChromeProcs) {
    # Collect all chrome PIDs in our set for fast lookup
    $ourPidSet = $allOurChromeProcs | ForEach-Object { $_.ProcessId }

    # Keep only TOP-LEVEL browser processes:
    # A top-level process is one whose parent is NOT also in our chrome set.
    # This avoids trying to kill renderer/GPU children that die automatically
    # when their browser parent is killed — and avoids the "process not found"
    # error that aborts the loop when a child is already gone.
    $topLevelProcs = $allOurChromeProcs | Where-Object {
        $_.ParentProcessId -notin $ourPidSet
    }

    if ($topLevelProcs) {
        $closed = 0
        foreach ($chromeProc in $topLevelProcs) {
            # Each kill is in its own try/catch so one failure never stops the rest
            try {
                & taskkill /PID $chromeProc.ProcessId /T /F 2>&1 | Out-Null
                $closed++
            } catch {
                Write-Warning "  Could not close PID $($chromeProc.ProcessId): $_"
            }
        }
        "$closed test Chrome window(s) closed."
    } else {
        "All test Chrome processes already exited."
    }
} else {
    Write-Warning "No Chrome processes found matching our profile path."
    Write-Warning "The windows may have already been closed manually."
}

# Restore registry
"Restoring registry..."
Remove-ItemProperty -Path $registryPath -Name $Name  -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $registryPath -Name $Name2 -ErrorAction SilentlyContinue

# Stop HTTP server via shutdown endpoint (instant) then clean up job
"Stopping local HTTP server..."
if ($httpServerJob -ne $null) {
    try { Invoke-WebRequest "http://localhost:$httpPort/__shutdown" -UseBasicParsing -TimeoutSec 3 | Out-Null } catch {}
    Start-Sleep -Milliseconds 500
    Stop-Job  $httpServerJob -ErrorAction SilentlyContinue
    Remove-Job $httpServerJob -ErrorAction SilentlyContinue
    "HTTP server stopped."
}
"Done."