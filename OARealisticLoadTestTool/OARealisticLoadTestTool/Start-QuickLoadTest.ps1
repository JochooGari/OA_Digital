param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"

function Unblock-ToolScripts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    Get-ChildItem -Path $RootPath -Filter *.ps1 -File -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Unblock-File -Path $_.FullName -ErrorAction SilentlyContinue
        }
        catch {}
    }
}

function Get-PlainToken {
    param(
        [string]$ExistingToken
    )

    if (-not [string]::IsNullOrWhiteSpace($ExistingToken)) {
        return $ExistingToken
    }

    try {
        return (Get-PowerBIAccessToken -AsString).Replace("Bearer ", "").Trim()
    }
    catch {
        Write-Host "Connexion Power BI requise." -ForegroundColor Yellow
        $null = Login-PowerBI
        return (Get-PowerBIAccessToken -AsString).Replace("Bearer ", "").Trim()
    }
}

function ConvertTo-ReportScript {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Payload
    )

    $reportParameters = [ordered]@{
        reportUrl = [string]$Payload.reportUrl
        pageName = [string]$Payload.pageName
        sessionRestart = [int]$Payload.sessionRestart
        thinkTimeSeconds = [int]$Payload.thinkTimeSeconds
    }

    if (-not [string]::IsNullOrWhiteSpace($Payload.layoutType)) {
        $reportParameters.layoutType = [string]$Payload.layoutType
    }

    if ($Payload.filters -and $Payload.filters.Count -gt 0) {
        $filters = @()
        foreach ($filter in $Payload.filters) {
            if ([string]::IsNullOrWhiteSpace($filter.filterTable) -or
                [string]::IsNullOrWhiteSpace($filter.filterColumn) -or
                -not $filter.filtersList -or
                $filter.filtersList.Count -eq 0) {
                continue
            }

            $filters += [ordered]@{
                filterTable = [string]$filter.filterTable
                filterColumn = [string]$filter.filterColumn
                isSlicer = [bool]$filter.isSlicer
                filtersList = @($filter.filtersList)
            }
        }

        if ($filters.Count -gt 0) {
            $reportParameters.filters = $filters
        }
    }

    $json = $reportParameters | ConvertTo-Json -Depth 10
    return "reportParameters= $json;"
}

function Normalize-ReportUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    if ($Url -match "reportId=") {
        return $Url
    }

    if ($Url -match "https://app\.powerbi\.com/groups/(?<groupId>[^/]+)/reports/(?<reportId>[^/]+)/?") {
        $groupId = $matches["groupId"]
        $reportId = $matches["reportId"]
        return "https://app.powerbi.com/reportEmbed?reportId=$reportId&groupId=$groupId&autoAuth=true"
    }

    throw "L'URL fournie ne ressemble pas a une URL de rapport Power BI. Utilisez une URL de type reportEmbed ou l'URL d'un rapport, pas celle d'un workspace."
}

if (-not (Test-Path $ConfigPath)) {
    throw "Config introuvable : $ConfigPath"
}

$toolRoot = $PSScriptRoot
Unblock-ToolScripts -RootPath $toolRoot
$payload = Get-Content -Raw $ConfigPath | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($payload.reportUrl)) {
    throw "Le reportUrl est obligatoire."
}

$payload.reportUrl = Normalize-ReportUrl -Url ([string]$payload.reportUrl)

$testId = [string]$payload.testId
if ([string]::IsNullOrWhiteSpace($testId)) {
    $testId = "TEST_{0}" -f (Get-Date -Format "yyyyMMdd_HHmm")
}

$instances = [int]$payload.instances
if ($instances -lt 1) {
    $instances = 1
}

$metricsRefreshSeconds = [int]$payload.metricsRefreshSeconds
if ($metricsRefreshSeconds -lt 1) {
    $metricsRefreshSeconds = 5
}

$runFolderName = "UI_{0}" -f (Get-Date -Format "MM-dd-yyyy_HH_mm_ss")
$runFolder = Join-Path $toolRoot $runFolderName
New-Item -Path $runFolder -ItemType Directory -Force | Out-Null

Copy-Item (Join-Path $toolRoot "RealisticLoadTest.html") $runFolder -Force
Set-Content -Path (Join-Path $runFolder "PBIReport.json") -Value (ConvertTo-ReportScript -Payload $payload) -Encoding UTF8

$token = Get-PlainToken -ExistingToken ([string]$payload.accessToken)
$tokenContent = "accessToken='{" + '"' + "PBIToken" + '"' + ":" + '"' + $token + '"' + "}';"
Set-Content -Path (Join-Path $runFolder "PBIToken.json") -Value $tokenContent -Encoding UTF8

$logDir = Join-Path $toolRoot "logs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory | Out-Null
}

$monitorJob = $null
$metricsProcess = $null
$performanceLog = Join-Path $logDir "logPage.csv"
$status = "Success"
$startTime = Get-Date

try {
    Write-Host "Demarrage du monitoring..." -ForegroundColor Cyan
    $monitorJob = Start-Job -FilePath (Join-Path $toolRoot "Monitoring.ps1") -ArgumentList $testId, $logDir
    Start-Sleep -Seconds 3

    $metricsScriptPath = Join-Path $toolRoot "View-LiveMetrics.ps1"
    if (Test-Path $metricsScriptPath) {
        $metricsCommand = "& '$metricsScriptPath' -LogFile '$performanceLog' -RefreshSeconds $metricsRefreshSeconds"
        $metricsProcess = Start-Process powershell -ArgumentList @(
            "-NoExit",
            "-ExecutionPolicy", "Bypass",
            "-Command", $metricsCommand
        ) -PassThru -WindowStyle Normal
    }

    Write-Host "Lancement du stress test pour le dossier $runFolderName..." -ForegroundColor Green
    $instances.ToString() | & (Join-Path $toolRoot "Run_Load_Test_Only.ps1") $runFolderName
}
catch {
    $status = "Failed"
    Write-Host "Erreur : $_" -ForegroundColor Red
}
finally {
    $endTime = Get-Date

    if ($metricsProcess -ne $null) {
        try {
            if (-not $metricsProcess.HasExited) {
                Stop-Process -Id $metricsProcess.Id -Force -ErrorAction SilentlyContinue
            }
        }
        catch {}
    }

    if ($monitorJob -ne $null) {
        try {
            Invoke-WebRequest "http://localhost:8080/?stop=1" -UseBasicParsing -TimeoutSec 5 | Out-Null
        }
        catch {}

        try {
            Stop-Job $monitorJob -ErrorAction SilentlyContinue
            Remove-Job $monitorJob -ErrorAction SilentlyContinue
        }
        catch {}
    }

    $orchestratorLog = Join-Path $logDir "orchestrator_log.csv"
    if (-not (Test-Path $orchestratorLog)) {
        "TestId,StartTime,EndTime,Status" | Set-Content -Path $orchestratorLog
    }
    Add-Content -Path $orchestratorLog -Value "$testId,$startTime,$endTime,$status"

    Write-Host ""
    Write-Host "Test termine." -ForegroundColor Cyan
    Write-Host "Test ID   : $testId" -ForegroundColor White
    Write-Host "Statut    : $status" -ForegroundColor White
    Write-Host "Dossier   : $runFolderName" -ForegroundColor White
    Write-Host "Logs      : $logDir" -ForegroundColor White
}
