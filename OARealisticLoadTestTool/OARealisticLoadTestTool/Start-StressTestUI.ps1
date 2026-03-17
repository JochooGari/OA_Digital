param(
    [int]$Port = 8765,
    [switch]$NoBrowser,
    [ValidateSet("full", "minimal")]
    [string]$UiMode = "full"
)

$ErrorActionPreference = "Stop"

$toolRoot = $PSScriptRoot
$uiFileName = if ($UiMode -eq "minimal") { "StressTestLauncher.Minimal.html" } else { "StressTestLauncher.html" }
$uiFile = Join-Path $toolRoot $uiFileName
$configFile = Join-Path $toolRoot "PBIReport.json"
$configBackupFile = Join-Path $toolRoot "PBIReport.backup.json"
$listenerPrefix = "http://localhost:$Port/"

function Write-JsonResponse {
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerResponse]$Response,
        [Parameter(Mandatory = $true)]
        [hashtable]$Payload,
        [int]$StatusCode = 200
    )

    $json = $Payload | ConvertTo-Json -Depth 10
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $Response.StatusCode = $StatusCode
    $Response.ContentType = "application/json; charset=utf-8"
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Response.OutputStream.Close()
}

function Write-TextResponse {
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerResponse]$Response,
        [Parameter(Mandatory = $true)]
        [string]$Content,
        [string]$ContentType = "text/html; charset=utf-8",
        [int]$StatusCode = 200
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
    $Response.StatusCode = $StatusCode
    $Response.ContentType = $ContentType
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Response.OutputStream.Close()
}

function ConvertTo-ReportScript {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Payload
    )

    $reportParameters = [ordered]@{
        reportUrl = $Payload.reportUrl
        pageName = $Payload.pageName
        sessionRestart = [int]$Payload.sessionRestart
        thinkTimeSeconds = [int]$Payload.thinkTimeSeconds
    }

    if (-not [string]::IsNullOrWhiteSpace($Payload.layoutType)) {
        $reportParameters.layoutType = $Payload.layoutType
    }

    if ($Payload.filters -and $Payload.filters.Count -gt 0) {
        $reportParameters.filters = @()
        foreach ($filter in $Payload.filters) {
            if ([string]::IsNullOrWhiteSpace($filter.filterTable) -or
                [string]::IsNullOrWhiteSpace($filter.filterColumn) -or
                -not $filter.filtersList -or
                $filter.filtersList.Count -eq 0) {
                continue
            }

            $reportParameters.filters += [ordered]@{
                filterTable = $filter.filterTable
                filterColumn = $filter.filterColumn
                isSlicer = [bool]$filter.isSlicer
                filtersList = @($filter.filtersList)
            }
        }
    }

    $json = $reportParameters | ConvertTo-Json -Depth 10
    return "reportParameters= $json;"
}

function Get-DefaultConfig {
    $rawContent = Get-Content -Raw $configFile
    $jsonText = $rawContent -replace '^\s*reportParameters\s*=\s*', ''
    $jsonText = $jsonText.Trim().TrimEnd(';')
    $parsed = $jsonText | ConvertFrom-Json

    $filters = @()
    if ($parsed.filters) {
        foreach ($filter in $parsed.filters) {
            $filters += @{
                filterTable = [string]$filter.filterTable
                filterColumn = [string]$filter.filterColumn
                isSlicer = [bool]$filter.isSlicer
                filtersList = @($filter.filtersList)
            }
        }
    }

    return @{
        reportUrl = [string]$parsed.reportUrl
        pageName = [string]$parsed.pageName
        thinkTimeSeconds = [int]$parsed.thinkTimeSeconds
        sessionRestart = if ($parsed.sessionRestart) { [int]$parsed.sessionRestart } else { 100 }
        layoutType = if ($parsed.layoutType) { [string]$parsed.layoutType } else { "Master" }
        filters = $filters
        metricsRefreshSeconds = 5
        instances = 2
        testId = "TEST_{0}" -f (Get-Date -Format "yyyyMMdd_HHmm")
    }
}

function Save-Config {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Payload
    )

    if (-not (Test-Path $configBackupFile)) {
        Copy-Item $configFile $configBackupFile -Force
    }

    $content = ConvertTo-ReportScript -Payload $Payload
    Set-Content -Path $configFile -Value $content -Encoding UTF8
}

function Start-LoadTest {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Payload
    )

    $testId = [string]$Payload.testId
    if ([string]::IsNullOrWhiteSpace($testId)) {
        $testId = "TEST_{0}" -f (Get-Date -Format "yyyyMMdd_HHmm")
    }

    $instances = [int]$Payload.instances
    if ($instances -lt 1) {
        throw "Le nombre d'instances doit etre superieur ou egal a 1."
    }

    $metricsRefreshSeconds = [int]$Payload.metricsRefreshSeconds
    if ($metricsRefreshSeconds -lt 1) {
        $metricsRefreshSeconds = 5
    }

    $Payload.testId = $testId
    $Payload.instances = $instances
    $Payload.metricsRefreshSeconds = $metricsRefreshSeconds

    try {
        $Payload.accessToken = (Get-PowerBIAccessToken -AsString).Replace("Bearer ", "").Trim()
    }
    catch {
        $Payload.accessToken = ""
    }

    Save-Config -Payload $Payload

    $launchConfigDir = Join-Path $toolRoot "ui-temp"
    if (-not (Test-Path $launchConfigDir)) {
        New-Item -Path $launchConfigDir -ItemType Directory | Out-Null
    }

    $launchConfigPath = Join-Path $launchConfigDir ("launch_{0}.json" -f ([guid]::NewGuid().ToString("N")))
    ($Payload | ConvertTo-Json -Depth 10) | Set-Content -Path $launchConfigPath -Encoding UTF8

    $command = @"
Set-Location '$toolRoot'
& '$toolRoot\Start-QuickLoadTest.ps1' -ConfigPath '$launchConfigPath'
"@

    Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-ExecutionPolicy", "Bypass",
        "-Command", $command
    ) | Out-Null

    return @{
        ok = $true
        message = "Le test a ete lance dans une nouvelle fenetre PowerShell."
    }
}

if (-not (Test-Path $uiFile)) {
    throw "Fichier introuvable : $uiFile"
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($listenerPrefix)
$listener.Start()

Write-Host "Stress Test UI disponible sur $listenerPrefix" -ForegroundColor Green
Write-Host "Appuyez sur Ctrl+C pour arreter le serveur." -ForegroundColor Yellow

if (-not $NoBrowser) {
    Start-Process $listenerPrefix | Out-Null
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        $path = $request.Url.AbsolutePath

        if ($request.HttpMethod -eq "GET" -and $path -eq "/") {
            Write-TextResponse -Response $response -Content (Get-Content -Raw $uiFile)
            continue
        }

        if ($request.HttpMethod -eq "GET" -and $path -eq "/api/defaults") {
            Write-JsonResponse -Response $response -Payload (Get-DefaultConfig)
            continue
        }

        if ($request.HttpMethod -eq "POST" -and $path -eq "/api/launch") {
            try {
                $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
                $body = $reader.ReadToEnd()
                $reader.Close()

                $payloadObject = $body | ConvertFrom-Json
                $payload = @{}
                foreach ($property in $payloadObject.PSObject.Properties) {
                    $payload[$property.Name] = $property.Value
                }

                $result = Start-LoadTest -Payload $payload
                Write-JsonResponse -Response $response -Payload $result
            }
            catch {
                Write-JsonResponse -Response $response -Payload @{
                    ok = $false
                    message = $_.Exception.Message
                } -StatusCode 500
            }
            continue
        }

        Write-JsonResponse -Response $response -Payload @{ ok = $false; message = "Route introuvable." } -StatusCode 404
    }
}
catch {
    Write-Host "Erreur du serveur UI : $_" -ForegroundColor Red
}
finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
}
