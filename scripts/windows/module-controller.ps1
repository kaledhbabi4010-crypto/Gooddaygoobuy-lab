#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("list","verify","install","remove")]
    [string]$Action,

    [Parameter(Mandatory=$true)]
    [ValidateSet("goodday","autocad","revit")]
    [string]$Module
)

$Root = if ($env:GOODDAY220_LAB_ROOT) {
    $env:GOODDAY220_LAB_ROOT
} else {
    "C:\GOODDAY220-Windows-Lab"
}

$Manifest = Join-Path `
    $Root `
    "modules\$Module\module.json"

if (-not (Test-Path $Manifest)) {
    throw "MODULE_MANIFEST_NOT_FOUND: $Module"
}

$data = Get-Content $Manifest -Raw |
    ConvertFrom-Json

switch ($Action) {

    "list" {
        $data | ConvertTo-Json -Depth 20
        exit 0
    }

    "verify" {
        Write-Host "MODULE=$Module"
        Write-Host "STATE=$($data.state)"
        Write-Host "INSTALL_POLICY=$($data.install_policy)"

        if ($data.install_policy -eq "DISABLED") {
            Write-Host "RESULT=NOT_INSTALLED_BY_DESIGN"
            exit 0
        }

        Write-Host "RESULT=NOT_PROVEN"
        exit 10
    }

    "install" {
        if ($data.install_policy -eq "DISABLED") {
            throw "MODULE_INSTALL_DISABLED: $Module"
        }

        throw "MODULE_INSTALLER_NOT_IMPLEMENTED_IN_BASE_PHASE"
    }

    "remove" {
        throw "MODULE_REMOVAL_NOT_ENABLED_IN_BASE_PHASE"
    }
}
