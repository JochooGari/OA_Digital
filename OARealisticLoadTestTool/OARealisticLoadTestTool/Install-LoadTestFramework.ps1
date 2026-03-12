######################################################################################################
# Installation and Validation Script
# Checks prerequisites and sets up the environment
######################################################################################################

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  Power BI Load Testing Framework - Installation" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

$workingDir = $PSScriptRoot
$allChecksPass = $true

# Check 1: PowerShell version
Write-Host "Checking PowerShell version..." -ForegroundColor Cyan
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 5) {
    Write-Host "  PowerShell $($psVersion.Major).$($psVersion.Minor) detected" -ForegroundColor Green
} else {
    Write-Host "  ERROR: PowerShell 5.0 or higher required (found $($psVersion.Major).$($psVersion.Minor))" -ForegroundColor Red
    $allChecksPass = $false
}

# Check 2: Execution Policy
Write-Host "`nChecking PowerShell execution policy..." -ForegroundColor Cyan
$execPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($execPolicy -eq "RemoteSigned" -or $execPolicy -eq "Unrestricted" -or $execPolicy -eq "Bypass") {
    Write-Host "  Execution policy is OK: $execPolicy" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Execution policy is $execPolicy" -ForegroundColor Yellow
    Write-Host "  Attempting to set to RemoteSigned..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Host "  Execution policy updated successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Could not update execution policy" -ForegroundColor Red
        Write-Host "  Run this as Administrator: Set-ExecutionPolicy RemoteSigned" -ForegroundColor Yellow
        $allChecksPass = $false
    }
}

# Check 3: Power BI PowerShell Module
Write-Host "`nChecking Power BI PowerShell module..." -ForegroundColor Cyan
$pbiModule = Get-Module -ListAvailable -Name MicrosoftPowerBIMgmt
if ($pbiModule) {
    Write-Host "  Power BI module installed (version $($pbiModule.Version))" -ForegroundColor Green
} else {
    Write-Host "  Power BI module not found. Installing..." -ForegroundColor Yellow
    try {
        Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -Force -AllowClobber
        Write-Host "  Power BI module installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Could not install Power BI module" -ForegroundColor Red
        Write-Host "  Install manually: Install-Module -Name MicrosoftPowerBIMgmt" -ForegroundColor Yellow
        $allChecksPass = $false
    }
}

# Check 4: Google Chrome
Write-Host "`nChecking Google Chrome installation..." -ForegroundColor Cyan
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (Test-Path $chromePath) {
    Write-Host "  Chrome found at: $chromePath" -ForegroundColor Green
} else {
    $chromePath86 = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
    if (Test-Path $chromePath86) {
        Write-Host "  Chrome found at: $chromePath86" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: Google Chrome not found" -ForegroundColor Red
        Write-Host "  Download from: https://www.google.com/chrome/" -ForegroundColor Yellow
        $allChecksPass = $false
    }
}

# Check 5: Required files
Write-Host "`nChecking required framework files..." -ForegroundColor Cyan
$requiredFiles = @(
    "Orchestrator.ps1",
    "setup_load_test.ps1",
    "run_load_test_only.ps1",
    "Monitoring.ps1",
    "View-LiveMetrics.ps1",
    "RealisticLoadTest.html",
    "PBIReport.JSON",
    "PBIToken.JSON"
)

$missingFiles = @()
foreach ($file in $requiredFiles) {
    if (Test-Path (Join-Path $workingDir $file)) {
        Write-Host "  $file" -ForegroundColor Green -NoNewline
        Write-Host " - OK" -ForegroundColor Gray
    } else {
        Write-Host "  $file" -ForegroundColor Red -NoNewline
        Write-Host " - MISSING" -ForegroundColor Red
        $missingFiles += $file
        $allChecksPass = $false
    }
}

# Check 6: Create required folders
Write-Host "`nCreating required folders..." -ForegroundColor Cyan
$requiredFolders = @("logs", "ChromeProfiles")
foreach ($folder in $requiredFolders) {
    $folderPath = Join-Path $workingDir $folder
    if (!(Test-Path $folderPath)) {
        try {
            New-Item -Path $folderPath -ItemType Directory | Out-Null
            Write-Host "  Created folder: $folder" -ForegroundColor Green
        } catch {
            Write-Host "  ERROR: Could not create folder: $folder" -ForegroundColor Red
            $allChecksPass = $false
        }
    } else {
        Write-Host "  Folder exists: $folder" -ForegroundColor Green
    }
}

# Check 7: Unblock all scripts
Write-Host "`nUnblocking PowerShell scripts..." -ForegroundColor Cyan
try {
    Get-ChildItem -Path $workingDir -Filter *.ps1 | Unblock-File
    Write-Host "  All scripts unblocked successfully" -ForegroundColor Green
} catch {
    Write-Host "  WARNING: Could not unblock all scripts" -ForegroundColor Yellow
    Write-Host "  You may need to unblock manually" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
if ($allChecksPass) {
    Write-Host "  INSTALLATION COMPLETE" -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor White
    Write-Host "  1. Run: .\Orchestrator.ps1 -TestId 'YOUR_TEST_NAME'" -ForegroundColor Yellow
    Write-Host "  2. Follow the prompts to configure your Power BI reports" -ForegroundColor Yellow
    Write-Host "  3. Enter the number of concurrent instances to simulate" -ForegroundColor Yellow
    Write-Host "  4. Watch the Live Metrics window for real-time performance data" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "For help, see README.md or run: Get-Help .\Orchestrator.ps1 -Detailed" -ForegroundColor Gray
} else {
    Write-Host "  INSTALLATION INCOMPLETE" -ForegroundColor Red
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please fix the errors above before proceeding." -ForegroundColor Red
    if ($missingFiles.Count -gt 0) {
        Write-Host ""
        Write-Host "Missing files:" -ForegroundColor Red
        foreach ($file in $missingFiles) {
            Write-Host "  - $file" -ForegroundColor Red
        }
    }
}
Write-Host ""