#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\env.ps1"

Set-Location (Join-Path $PSScriptRoot "..")

$paths = @("tests/tmp", ".autolisp-runs")
foreach ($path in $paths) {
  if (Test-Path $path) {
    Remove-Item -Recurse -Force $path
  }
  New-Item -ItemType Directory -Path $path | Out-Null
}
