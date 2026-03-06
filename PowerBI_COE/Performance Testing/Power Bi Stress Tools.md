Power Bi Stress Tools
Power BI Realistic Load Testing Framework - Usage Manual

Quick Start Introduction Entry of the tool 
LoadTest.pptx

New to this tool? Follow these 3 steps:

Run .\Install-LoadTestFramework.ps1
Run .\Orchestrator.ps1 -TestId "MyFirstTest"
Follow the prompts
📋 Table of Contents
Quick Start Introduction Entry of the tool 
📋 Table of Contents
🎯 What is This Tool?
Use Cases
✅ Prerequisites
Required Software
System Requirements
Permissions Required
🚀 Installation
Step 1: Download the Framework
Step 2: Run Installation Script
Step 3: Verify Installation
📊 Framework Components
Core Scripts
Configuration Files
Directory Structure
⚙️ Configuration Guide
Understanding PBIReport.JSON
Configuration Parameters
Filter Configuration
Filter Combinations
Multi-Select Filters
How to Find GUIDs
🎮 How to Use
Basic Usage (First Test)
Advanced Usage
📈 Understanding Results
Live Metrics Window
Color Coding
Performance Breakdown
Bottleneck Detection
Log Files
🔬 Dedicated Stress Testing Workspace
Overview
Benefits
Request Access
How to Use
Example KQL Query
Workspace Guidelines
📊 Premium Capacity Logs Analysis
Overview
How It Works
Query Template
Query Parameters
Understanding the Results
Best Practices
Troubleshooting
🎓 Best Practices
Test Design
Instance Sizing
Think Time Configuration
Calculating Real-World Users
🐛 Troubleshooting
Installation Issues
Runtime Issues
Performance Issues
Data Issues
Cleanup
📞 Support & Resources
Command Help
Check System Status
External Links
🔐 Security & Compliance
📋 Quick Reference
Common Commands
Performance Benchmarks
📝 Change Log
Version 2.0 (Current - Enhanced Framework)
Version 1.0 (Original - 8/1/2019)
🎯 What is This Tool?
The Power BI Realistic Load Testing Framework is an automated testing tool that simulates multiple concurrent users accessing Power BI reports. It measures performance under realistic conditions including:

Multiple users viewing reports simultaneously
Users changing filters and slicers
Users clicking through bookmarks
Realistic "think time" between actions
Use Cases



Capacity Planning

Determine max concurrent users before performance degrades

10-50

Report Optimization

Identify slow filter combinations and bottlenecks

2-5

Premium Capacity Testing

Test capacity limits and throttling behavior

50-100+

Cache Analysis

Measure warm vs cold cache performance

5-10

DirectQuery Performance

Measure impact on backend database

10-20

✅ Prerequisites
Required Software
Windows 10/11 with PowerShell 5.0 or higher
Google Chrome - Download - Install using: "ChromeSetup.exe --system-level" - Make sure it's installed in "C:\Program Files"
Power BI Account with access to reports (workspace member role or higher)
Power BI PowerShell Module - Auto-installed by the framework
System Requirements



RAM

8 GB

16 GB+

CPU Cores

4 physical cores

8+ physical cores

Disk Space

500 MB

2 GB

Network

Stable internet

High-speed connection

Rule of Thumb: Maximum instances = Total RAM (GB) / 2
Example: 16 GB RAM = max 8 concurrent instances

Permissions Required
PowerShell Execution Policy: RemoteSigned or Unrestricted
Power BI Workspace Access: Member, Contributor, or Admin role
Reports Location: Must be in a workspace (not "My Workspace")
🚀 Installation
Step 1: Download the Framework
Contact the BTDP Analytics Team for The Files.
The Stress Test files: 

Extract the framework ZIP file to a local folder
Example: C:\OARealisticLoadTestTool
Step 2: Run Installation Script


# Navigate to framework folder
cd C:\OARealisticLoadTestTool

# Run installation validator
.\Install-LoadTestFramework.ps1
Step 3: Verify Installation
The installation script will check:

✅ PowerShell version (5.0+)
✅ Execution policy (RemoteSigned)
✅ Power BI PowerShell module
✅ Google Chrome installation
✅ Required framework files
✅ Creation of logs and ChromeProfiles folders
✅ Script unblocking
If installation fails, see Troubleshooting section below.

📊 Framework Components
Core Scripts



Orchestrator.ps1

Main controller - runs everything

✅ Yes - Start here

setup_load_test.ps1

Configure Power BI reports

❌ No - Called by Orchestrator

run_load_test_only.ps1

Execute load tests

❌ No - Called by Orchestrator

Monitoring.ps1

Collect performance metrics

❌ No - Background process

View-LiveMetrics.ps1

Real-time performance dashboard

❌ No - Auto-opens

Update_Token_Only.ps1

Refresh authentication tokens

✅ Yes - Every 50 min for long tests

Configuration Files



PBIReport.JSON

Report configuration (filters, bookmarks, etc.)

✅ Yes - Advanced users

PBIToken.JSON

Authentication token

❌ No - Auto-generated

RealisticLoadTest.html

Browser test engine

❌ No - Do not modify

Directory Structure
OARealisticLoadTestTool/
├── 📄 Core Scripts (*.ps1)
├── 🌐 Browser Components (*.html, *.json)
├── 📁 logs/                    ← Performance data
│   ├── orchestrator_log.csv    ← Test execution history
│   └── logPage.csv             ← Detailed metrics
├── 📁 ChromeProfiles/          ← Browser profiles
└── 📁 MM-DD-YYYY_HH_MM_SS/    ← Test configuration folders
    ├── RealisticLoadTest.html
    ├── PBIReport.JSON
    └── PBIToken.JSON
⚙️ Configuration Guide
Understanding PBIReport.JSON
After running setup, a timestamped folder is created with PBIReport.JSON. Edit this file to configure advanced test scenarios.

Basic Configuration



reportParameters={
  "reportUrl": "https://app.powerbi.com/reportEmbed?reportId=...",
  "pageName": "ReportSection123abc",
  "bookmarkList": ["Bookmark1", "Bookmark2"],
  "thinkTimeSeconds": 5,
  "sessionRestart": 100,
  "layoutType": "Master"
};
Configuration Parameters



reportUrl

Report embed URL (auto-generated)

Do not change

pageName

Specific page to test (internal ID)

ReportSection123abc or null

bookmarkList

Report Bookmarks to cycle through (GUIDs)

"Bookmark1", "Bookmark2"

thinkTimeSeconds

Wait time between actions (seconds)

0 (stress) to 30 (realistic)

sessionRestart

Reload browser every N iterations

100 (default)

layoutType

Report layout

Master, MobilePortrait, MobileLandscape

Filter Configuration


"filters": [
  {
    "filterTable": "DimProduct",
    "filterColumn": "Category",
    "isSlicer": true,
    "filtersList": ["Bikes", "Accessories", "Clothing"]
  },
  {
    "filterTable": "DimDate",
    "filterColumn": "Year",
    "isSlicer": false,
    "filtersList": ["2023", "2024", "2025"]
  }
]



filterTable

Table name from data model

Exact name from model

filterColumn

Column name from data model

Exact name from model

isSlicer

Simulate slicer click or apply filter

true or false

filtersList

Values to test

Array of values or null

How to Find Table/Column Names:

Open report in Power BI Desktop
Click the visual with the slicer/filter
In Visualizations pane, hover over the field
Use the exact name shown (ignore quotes/brackets)
Filter Combinations
The framework tests ALL permutations of filters:

Example
Configuration:

Filter 1 (Category): 3 values
Filter 2 (Year): 3 values
Filter 3 (Region): 4 values
Bookmarks: 2 bookmarks
Total Combinations: 3 × 3 × 4 × 2 = 72 unique scenarios

The framework randomizes the order to avoid cache bias.

Multi-Select Filters


"filtersList": [
  "North",                                    // Single-select: North only
  ["North", "South"],                         // Multi-select: North AND South
  ["North", "South", "East", "West"],        // Multi-select: All 4 regions
  null                                        // No filter (all data)
]
Alternative notation: null, "A", "B"

First filter = A + B (multi-select)
Second filter = A only
Third filter = B only
Do not mix: null, "A", "B", "C" will not work

How to Find GUIDs
Finding Page GUID

Open report in Power BI Service
Click to the desired page
Check browser URL: .../reports/reportId/ReportSection123abc
Use ReportSection123abc as pageName
Finding Bookmark GUID

Open report in Power BI Service
Click a Report bookmark - (Not personal bookmarks)
Check browser URL: ...?bookmarkGuid=Bookmark1d7f5476
Use Bookmark1d7f5476 in bookmarkList
🎮 How to Use
Basic Usage (First Test)
Step 1: Open PowerShell



cd C:\OARealisticLoadTestTool
Step 2: Run Orchestrator



.\Orchestrator.ps1 -TestId "MyFirstTest"
Step 3: Login to Power BI

Enter your credentials when prompted
Grant permissions if requested
Step 4: Select Workspace

You'll see a numbered list of workspaces
Type the number of your workspace
Press Enter
Step 5: Select Report

You'll see a numbered list of reports in that workspace
Type the number of the report to test
Press Enter
Step 6: Enter Instance Count

Type the number of concurrent users to simulate
Start with 2 or 3 for first test
Press Enter
Step 7: Watch the Test Run

Live Metrics window opens automatically
Chrome windows open (one per instance)
Reports load and refresh automatically
Metrics update every 5 seconds
Step 8: Stop the Test

Press Enter in the main PowerShell window when ready to stop
All windows close automatically
Summary displayed
Advanced Usage
Custom Metrics Refresh Rate



# Faster updates (every 3 seconds)
.\Orchestrator.ps1 -TestId "FastRefresh" -MetricsRefreshSeconds 3

# Slower updates (every 10 seconds - lower CPU usage)
.\Orchestrator.ps1 -TestId "SlowRefresh" -MetricsRefreshSeconds 10
Long-Running Tests (Token Refresh)

For tests longer than 60 minutes:



.\Orchestrator.ps1 -TestId "LongTest"

# Run this in a SEPARATE PowerShell window
while ($true) {
    Start-Sleep -Seconds (50 * 60)  # 50 minutes
    .\Update_Token_Only.ps1
    Write-Host "Token refreshed at $(Get-Date)" -ForegroundColor Green
}


📈 Understanding Results
Live Metrics Window
The Live Metrics window displays real-time performance:






Total Refreshes

Number of report loads completed







Active Instances

Number of concurrent Chrome windows







Average Duration

Mean time to load report

< 5s

5-10s

> 10s

Cache Hit Rate

Percentage of cached operations

> 70%

40-70%

< 40%

Memory Usage

Browser memory consumption

< 300 MB

300-500 MB

> 500 MB

Color Coding
🟢 GREEN (< 10 seconds) - Good performance
🟡 YELLOW (10-20 seconds) - Acceptable
🔴 RED (> 20 seconds) - Needs attention
Performance Breakdown



TimeToLoad

Query execution + network latency

Data model, DAX, aggregations

TimeToRender

Visual drawing in browser

Number/complexity of visuals

TotalTime

Complete user experience

Both areas

IsCached

Whether data came from cache

Cache strategy

Bottleneck Detection


If TimeToLoad > TimeToRender × 1.5:
  → Bottleneck: Query/Data Model
  → Fix: Optimize DAX, add aggregations, reduce data volume

If TimeToRender > TimeToLoad × 1.5:
  → Bottleneck: Visual Rendering
  → Fix: Reduce visuals, simplify charts, limit data points

If balanced:
  → Performance is well-optimized
Log Files



orchestrator_log.csv

.\logs

Test execution history (TestId, Start/End times, Status)

logPage.csv

.\logs

Detailed performance metrics (every refresh logged)

Log Schema (logPage.csv)

TestId, Timestamp, Instance, AvgDuration, Iteration, ErrorCount, 
Status, FilterConfig, BookmarkName, PageName, MemoryUsedMB, 
TimeToLoad, TimeToRender, TotalTime, IsCached
🔬 Dedicated Stress Testing Workspace
Overview
L'Oréal provides a dedicated Microsoft Fabric workspace for load testing with pre-configured monitoring and KQL analytics for performance analysis.

Benefits
Isolated Environment - No impact on production
Pre-configured Monitoring - Automatic performance metrics capture
KQL Analytics - Advanced query capabilities for dataset analysis
Optimized Capacity - Dedicated resources for consistent results
Request Access
Email: 

Include:

Your name and email
Department/Team
Purpose and duration of testing
Number of reports to test
Response Time: 1-2 business days

How to Use
Upload your reports to the dedicated workspace
Run your load test using the Orchestrator


.\Orchestrator.ps1 -TestId "StressTest_YourName"
# Select the dedicated workspace when prompted
Analyze results using provided KQL scripts in Fabric Monitoring Hub
Example KQL Query


// All logs for the last 7 days and parsed for extracting performance metrics
let result = SemanticModelLogs
| where OperationName in ("QueryEnd")  and ItemName=="DatasetName" 
//and ExecutingUser=="UserName" and DurationMs >10000
//and Timestamp between (datetime(2025-20-10 09:00:00.0000) .. datetime(2025-20-10 11:02:20.0000))
 | sort by Timestamp  asc
| extend app = tostring(parse_json(ApplicationContext))
| project   Timestamp, 
            ItemName,
            XmlaSessionId,
            ItemKind,
            DatasetMode,
            OperationName,
            OperationDetailName,
            ApplicationContext,          
            ApplicationName,
            EventText,
            Identity,
            ExecutingUser,
            WorkspaceName, 
            CapacityId, 
            DurationMs,
            CpuTimeMs,
            OperationId,
            datasetid = extract_json("$.DatasetId", app), 
            reportId = extract_json("$.Sources[0].ReportId", app), 
            visualId = extract_json("$.Sources[0].VisualId", app), 
            usersession = extract_json("$.Sources[0].HostProperties.UserSession", app)
| extend WaitTimeMs = toint(extract(@"WaitTime:\s*(\d+)\s*ms", 1, EventText))
| extend upnj = tostring(parse_json(Identity))
| extend claims_upn= extract_json("$.claims.upn", upnj), effectiveclaims_upn= extract_json("$.effectiveClaims.upn", upnj)
| project Timestamp, ItemName,XmlaSessionId, OperationName, OperationDetailName, EventText, ExecutingUser,DurationMs,CpuTimeMs, visualId, usersession, 
           WaitTimeMs,ApplicationContext,OperationId;
result
Workspace Guidelines
Clean up reports within 7 days after testing
Use naming convention: YYYYMMDD_TeamName_Purpose
Run a small test (2-3 instances) first to validate your setup before scaling up
Make sure RLS are applied when executing the stressTest
📊 Premium Capacity Logs Analysis
Overview
After completing your stress test, you can analyze the impact on Premium Capacity by querying consolidated logs stored in Google Cloud Platform (GCP). These logs provide detailed insights into capacity utilization during your test period.

Important: Logs are consolidated every 24 hours. Wait at least 24 hours after your test before running the analysis query.

How It Works
Run your stress test using the framework
Note the exact date and time of your test
Wait 24 hours for log consolidation
Run the GCP query to retrieve capacity metrics
Analyze the impact on interactive and background workloads
Query Template


SELECT  
    capacity_name, 
    interactive_value, 
    background_value, 
    capacity_unit_count
FROM `itg-btdppublished-gbl-ww-pd.btdp_ds_c1_0a2_powerbimetadata_eu_pd.capacity_unit_timepoint_v2` 
WHERE usage_timepoint BETWEEN DATETIME("2025-11-05") 
    AND DATETIME_ADD("2025-11-05", INTERVAL 1 DAY) 
LIMIT 1000
Query Parameters



DATETIME("2025-11-05")

Start date of your test

Replace with your test date in YYYY-MM-DD format

INTERVAL 1 DAY

Duration to analyze

Keep as 1 DAY for full day analysis

LIMIT 1000

Maximum rows returned

Increase if needed for longer tests

Understanding the Results



capacity_name

Name of the Premium Capacity

Verify it matches your test workspace capacity

interactive_value

CPU usage from interactive operations

Spikes during your test period

background_value

CPU usage from background operations

Impact on refresh operations

capacity_unit_count

Total capacity units available

Compare usage vs available units

Best Practices
✅ Record Test Timestamps: Note exact start/end times in your TestId
✅ Wait 24+ Hours: Ensure logs are fully consolidated
✅ Compare Baselines: Query the day before your test for comparison
✅ Check Throttling: Look for interactive_value > 100% indicating throttling
✅ Coordinate with Admins: Share results with capacity administrators
Troubleshooting
No Data Returned

Possible causes:

Logs not yet consolidated (wait longer)
Incorrect date format in query
Wrong capacity name in filter
Query Access Issues

Contact your GCP administrator

Pro Tip: Export query results to CSV and overlay them with your framework's logPage.csv for comprehensive analysis correlating user actions with capacity utilization.

🎓 Best Practices
Test Design
✅ Start Small: Begin with 2-3 instances
✅ Monitor Resources: Watch CPU/RAM during test
✅ Keep CPU < 80%: For accurate results
✅ Use Realistic Think Time: 10-30 seconds for production simulation
✅ Test Non-Production First: Validate setup before testing production reports
✅ Document Configuration: Save PBIReport.JSON for each test scenario
Instance Sizing
Formula: Max Instances = (Physical CPU Cores) AND (Total RAM GB / 2)

Examples
8 cores, 16 GB RAM → Max 8 instances (limited by RAM)
16 cores, 32 GB RAM → Max 16 instances (balanced)
4 cores, 32 GB RAM → Max 4 instances (limited by CPU)
Think Time Configuration



Testing/Setup

5-10 seconds

Visual inspection between iterations

Stress Testing

0-1 seconds

Maximum load, find breaking point

Realistic Simulation

15-30 seconds

Mimic actual user behavior

Capacity Planning

5-10 seconds

Balance between realism and duration

Calculating Real-World Users


Real Users Per Instance = (AvgRefreshTime + RealUserThinkTime) / AvgRefreshTime

Example:
• Avg refresh time: 10 seconds
• Real user think time: 30 seconds
• Calculation: (10 + 30) / 10 = 4
• Result: Each instance simulates 4 real-world users
🐛 Troubleshooting
Installation Issues
Error: File cannot be loaded because you opted not to run this software



# Run as Administrator:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Get-ChildItem -Path . -Filter *.ps1 | Unblock-File
Error: Login-PowerBI command not recognized



Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -Force
Error: Google Chrome not found

Download Chrome: https://www.google.com/chrome/
Install using: "ChromeSetup.exe --system-level". Make sure it's installed in "C:\Program Files"
Or update run_load_test_only.ps1 with your Chrome path
Runtime Issues
Symptom: Chrome opens but reports don't load

Causes & Fixes:

1. Token Expired (most common)



.\Update_Token_Only.ps1
2. Wrong Report URL

Check PBIReport.JSON in test folder
Verify report URL is correct
3. No Access to Report

Verify you can open report in Power BI Service
Check workspace permissions
Symptom: Metrics window shows "Waiting for log file..."

Fixes:

Wait 15-20 seconds (first load is slow)
Check Chrome windows opened
Verify Monitoring job:


Get-Job | Where {$_.Name -like "*Monitor*"}
# Should show "Running"
Check log manually:


Get-Content .\logs\logPage.csv
Symptom: Chrome crashes, system becomes slow

Fix:

Reduce number of instances
Close other applications
Restart computer between tests
Add more RAM to testing machine
Symptom: Orchestrator exits with monitoring error



# Check if port 8080 is in use
Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue

# Kill process using port 8080 if needed
# Or edit Monitoring.ps1 to use different port
Performance Issues
Symptom: All durations > 20 seconds

Checks:

Network: Are you on VPN? Try without VPN
Capacity: Is Premium capacity throttled? Check Capacity Metrics app
Report: Is report optimized? Test in Power BI Desktop first
Instances: Too many? Reduce to 3-5 and retest
Backend: Is DirectQuery source slow? Check database performance
Symptom: Times vary wildly between runs

Tips:

Run tests multiple times
Focus on 95th percentile, not average
Use cache analysis to separate cached vs non-cached
Use longer think time (10-30 seconds)
Test at consistent times of day
Avoid testing during capacity maintenance windows
Data Issues
Location: All logs in .\logs folder

View specific test:



$testId = "MyTest"
Import-Csv .\logs\logPage.csv | Where {$_.TestId -eq $testId}
Symptom: Import-Csv fails



# Backup
Copy-Item .\logs\logPage.csv .\logs\logPage_backup.csv

# Recreate header
"TestId,Timestamp,Instance,AvgDuration,Iteration,ErrorCount,Status,FilterConfig,BookmarkName,PageName,MemoryUsedMB,TimeToLoad,TimeToRender,TotalTime,IsCached" | 
    Set-Content .\logs\logPage_new.csv

# Copy data (skip corrupted header)
Get-Content .\logs\logPage.csv | Select -Skip 1 | Add-Content .\logs\logPage_new.csv
Cleanup
Stop all Chrome processes:



Get-Process chrome | Stop-Process -Force
Delete old test folders:



# Delete folders older than 7 days
Get-ChildItem -Directory | 
    Where {$_.Name -match '\d{2}-\d{2}-\d{4}' -and $_.CreationTime -lt (Get-Date).AddDays(-7)} |
    Remove-Item -Recurse -Force
📞 Support & Resources
Command Help


# Get detailed help for any script
Get-Help .\Orchestrator.ps1 -Detailed
Check System Status


# PowerShell version
$PSVersionTable.PSVersion

# Execution policy
Get-ExecutionPolicy -List

# Power BI module
Get-Module -ListAvailable MicrosoftPowerBIMgmt

# Running processes
Get-Process chrome, powershell

# Background jobs
Get-Job

# Available RAM
Get-CimInstance Win32_OperatingSystem | 
    Select @{N="FreeRAM(GB)";E={[math]::Round($_.FreePhysicalMemory/1MB,2)}}
External Links
Power BI JavaScript API
Power BI PowerShell Module
Premium Capacity Metrics App
🔐 Security & Compliance
Tokens: Authentication tokens are stored in PBIToken.JSON - keep this file secure
Do Not Commit: Never commit PBIToken.JSON to source control
Logs May Contain: Report names and filter values - sanitize before sharing externally
Test Reports: Always test on non-production reports first
Capacity Impact: Load tests create real load on Premium capacity - coordinate with capacity admins
Data Privacy: Ensure test data complies with data protection policies
📋 Quick Reference
Common Commands


# Run basic test
.\Orchestrator.ps1 -TestId "TEST001"

# Refresh token
.\Update_Token_Only.ps1
Performance Benchmarks





Avg Duration

< 3s

3-5s

5-10s

> 10s

95th Percentile

< 5s

5-10s

10-20s

> 20s

Cache Hit Rate

> 70%

50-70%

30-50%

< 30%

Error Rate

0%

< 1%

1-5%

> 5%

Memory per Instance

< 200 MB

200-300 MB

300-500 MB

> 500 MB

📝 Change Log
Version 2.0 (Current - Enhanced Framework)
Added Orchestrator.ps1 for automated workflow
Real-time Live Metrics dashboard
Timing breakdown (query vs render)
Cache hit detection
Memory usage tracking
Enhanced error handling and recovery
Detailed analysis scripts
Version 1.0 (Original - 8/1/2019)
Multiple slicers/filters with random cycling
Support for text and integer filters
Single-select and multi-select support
Bookmark navigation
Page-specific rendering
Mobile layout support