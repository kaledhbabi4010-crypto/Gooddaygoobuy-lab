#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$LabRoot = if ($env:GOODDAY220_LAB_ROOT) {
    $env:GOODDAY220_LAB_ROOT
} else {
    "C:\GOODDAY220-Windows-Lab"
}

$EvidenceDir = Join-Path $LabRoot "evidence"
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

$EvidenceFile = Join-Path $EvidenceDir "base-bootstrap.json"

$results = [ordered]@{
    schema = "GOODDAY220-WINDOWS-BASE-1"
    timestamp_utc = (Get-Date).ToUniversalTime().ToString("o")
    hostname = $env:COMPUTERNAME
    os = [ordered]@{}
    tools = [ordered]@{}
    modules = [ordered]@{
        goodday = "NOT_INSTALLED"
        autocad = "NOT_INSTALLED"
        revit = "NOT_INSTALLED"
    }
}

function Add-ToolEvidence {
    param(
        [string]$Name,
        [string]$Command,
        [string[]]$Arguments = @("--version")
    )

    $item = [ordered]@{
        name = $Name
        command = $Command
        found = $false
        version = $null
        status = "NOT_PROVEN"
    }

    try {
        $cmd = Get-Command $Command -ErrorAction Stop
        $item.found = $true

        try {
            $out = & $cmd.Source @Arguments 2>&1 |
                Out-String
            $item.version = $out.Trim()
        } catch {
            $item.version = "VERSION_QUERY_FAILED"
        }

        $item.status = "RUNTIME_CONFIRMED"
    } catch {
        $item.status = "NOT_FOUND"
    }

    $results.tools[$Name] = $item
}

# ------------------------------------------------
# OS
# ------------------------------------------------

$cv = Get-ItemProperty `
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

$results.os = [ordered]@{
    product_name = $cv.ProductName
    display_version = $cv.DisplayVersion
    current_build = $cv.CurrentBuild
    current_build_number = $cv.CurrentBuildNumber
    architecture = $env:PROCESSOR_ARCHITECTURE
    powershell = $PSVersionTable.PSVersion.ToString()
}

# ------------------------------------------------
# Basic tools
# ------------------------------------------------

Add-ToolEvidence "PowerShell" "pwsh"
if ($results.tools.PowerShell.status -eq "NOT_FOUND") {
    $results.tools.PowerShell = [ordered]@{
        name = "PowerShell"
        command = "powershell"
        found = $true
        version = $PSVersionTable.PSVersion.ToString()
        status = "RUNTIME_CONFIRMED"
    }
}

Add-ToolEvidence "Python" "python" @("--version")
Add-ToolEvidence "PythonLauncher" "py" @("--version")
Add-ToolEvidence "Git" "git" @("--version")
Add-ToolEvidence "CMake" "cmake" @("--version")
Add-ToolEvidence "DotNet" "dotnet" @("--version")
Add-ToolEvidence "7Zip" "7z" @()

# ------------------------------------------------
# MSVC / Visual Studio
# ------------------------------------------------

$vswhereCandidates = @(
    "$env:ProgramFiles(x86)\Microsoft Visual Studio\Installer\vswhere.exe",
    "$env:ProgramFiles\Microsoft Visual Studio\Installer\vswhere.exe"
)

$vswhere = $vswhereCandidates |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

if ($vswhere) {

    $instances = & $vswhere `
        -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -format json 2>$null

    if ($LASTEXITCODE -eq 0 -and $instances) {
        $results.tools["MSVC"] = [ordered]@{
            found = $true
            status = "RUNTIME_CONFIRMED"
            evidence = ($instances | Out-String).Trim()
        }
    } else {
        $results.tools["MSVC"] = [ordered]@{
            found = $false
            status = "NOT_PROVEN"
            evidence = "vswhere exists but MSVC workload not proven"
        }
    }

} else {

    $results.tools["MSVC"] = [ordered]@{
        found = $false
        status = "NOT_PROVEN"
        evidence = "vswhere.exe not found"
    }
}

# ------------------------------------------------
# Windows SDK
# ------------------------------------------------

$sdkRoots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots"
)

$sdkFound = $false
$sdkEvidence = @()

foreach ($root in $sdkRoots) {
    try {
        $p = Get-ItemProperty $root -ErrorAction Stop
        $props = $p.PSObject.Properties |
            Where-Object { $_.Name -like "KitsRoot*" }

        foreach ($prop in $props) {
            if ($prop.Value -and (Test-Path $prop.Value)) {
                $sdkFound = $true
                $sdkEvidence += "$($prop.Name)=$($prop.Value)"
            }
        }
    } catch {}
}

$results.tools["WindowsSDK"] = [ordered]@{
    found = $sdkFound
    status = if ($sdkFound) {
        "RUNTIME_CONFIRMED"
    } else {
        "NOT_PROVEN"
    }
    evidence = $sdkEvidence
}

# ------------------------------------------------
# Hardware
# ------------------------------------------------

$results.hardware = [ordered]@{
    cpu = @(
        Get-CimInstance Win32_Processor |
        Select-Object Name,NumberOfCores,NumberOfLogicalProcessors
    )
    memory_bytes = (
        Get-CimInstance Win32_ComputerSystem
    ).TotalPhysicalMemory
    disks = @(
        Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
        Select-Object DeviceID,Size,FreeSpace
    )
}

# ------------------------------------------------
# Network / DNS
# ------------------------------------------------

try {
    $dns = Resolve-DnsName "github.com" -ErrorAction Stop
    $results.network = [ordered]@{
        github_dns = "RUNTIME_CONFIRMED"
        addresses = @($dns.IPAddress)
    }
} catch {
    $results.network = [ordered]@{
        github_dns = "NOT_PROVEN"
    }
}

# ------------------------------------------------
# Administrator status
# ------------------------------------------------

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)

$results.security = [ordered]@{
    user = $identity.Name
    is_admin = $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

# ------------------------------------------------
# FINAL STATE
# ------------------------------------------------

$baseRequired = @(
    "Python",
    "Git",
    "DotNet",
    "CMake",
    "PowerShell"
)

$missing = @()

foreach ($name in $baseRequired) {
    if (
        -not $results.tools.Contains($name) -or
        $results.tools[$name].status -ne "RUNTIME_CONFIRMED"
    ) {
        $missing += $name
    }
}

$results.summary = [ordered]@{
    base_required = $baseRequired
    missing_required = $missing
    base_status = if ($missing.Count -eq 0) {
        "RUNTIME_CONFIRMED"
    } else {
        "INCOMPLETE"
    }
    future_modules_supported = $true
    future_modules_installable_independently = $true
}

$results |
    ConvertTo-Json -Depth 12 |
    Set-Content -Encoding UTF8 $EvidenceFile

Write-Host ""
Write-Host "GOODDAY220 WINDOWS BASE BOOTSTRAP"
Write-Host "Evidence: $EvidenceFile"
Write-Host ""

Get-Content $EvidenceFile

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "BASE_STATUS=INCOMPLETE"
    exit 10
}

Write-Host ""
Write-Host "BASE_STATUS=RUNTIME_CONFIRMED"
exit 0
