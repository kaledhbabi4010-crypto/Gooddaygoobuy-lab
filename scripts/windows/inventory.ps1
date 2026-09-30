#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = if ($env:GOODDAY220_LAB_ROOT) {
    $env:GOODDAY220_LAB_ROOT
} else {
    "C:\GOODDAY220-Windows-Lab"
}

$Evidence = Join-Path $Root "evidence"
New-Item -ItemType Directory -Force $Evidence | Out-Null

$items = @()

function Add-Item {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Evidence
    )

    $script:items += [ordered]@{
        name = $Name
        status = $Status
        evidence = $Evidence
    }
}

$commands = @(
    @{n="python"; c="python"; a="--version"},
    @{n="git"; c="git"; a="--version"},
    @{n="dotnet"; c="dotnet"; a="--version"},
    @{n="cmake"; c="cmake"; a="--version"},
    @{n="7zip"; c="7z"; a=""}
)

foreach ($x in $commands) {

    try {
        $cmd = Get-Command $x.c -ErrorAction Stop

        $out = if ($x.a) {
            & $cmd.Source $x.a 2>&1 | Out-String
        } else {
            & $cmd.Source 2>&1 | Out-String
        }

        Add-Item `
            $x.n `
            "RUNTIME_CONFIRMED" `
            $out.Trim()

    } catch {

        Add-Item `
            $x.n `
            "NOT_PROVEN" `
            $_.Exception.Message
    }
}

$result = [ordered]@{
    schema = "GOODDAY220-INVENTORY-1"
    timestamp_utc = (Get-Date).ToUniversalTime().ToString("o")
    hostname = $env:COMPUTERNAME
    items = $items
}

$result |
    ConvertTo-Json -Depth 10 |
    Set-Content -Encoding UTF8 `
    (Join-Path $Evidence "inventory.json")

Get-Content (Join-Path $Evidence "inventory.json")
