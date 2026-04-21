#!/usr/bin/env pwsh

param(
  [string]$RepoRoot = (Get-Location).Path,
  [string]$WorkRoot = "D:\spool",
  [string]$GitBashExe = "C:\Program Files\Git\bin\bash.exe",
  [string]$BricscadExe = "C:\Program Files\Bricsys\BricsCAD V25 fr_FR\bricscad.exe",
  [int]$WaitSecs = 600,
  [int]$StartupTimeoutSecs = 60
)

$ErrorActionPreference = "Stop"

if (Test-Path -LiteralPath (Join-Path $PSScriptRoot "env.ps1")) {
  . (Join-Path $PSScriptRoot "env.ps1")
}

Set-Location $RepoRoot
New-Item -ItemType Directory -Force $WorkRoot | Out-Null

$env:AUTOLISP_WORKDIR = $WorkRoot
$env:AUTOLISP_KEEP_WORKDIR = "1"
$env:AUTOLISP_VERBOSE = "1"
$env:AUTOLISP_WAIT_SECS = "$WaitSecs"
$env:AUTOLISP_BRICSCAD_BATCH_STARTUP_TIMEOUT = "$StartupTimeoutSecs"
$env:BRICSCAD_COM_MODE = "off"
$env:BRICSCAD_EXE = $BricscadExe

Write-Host "RepoRoot=$((Get-Location).Path)"
Write-Host "AUTOLISP_WORKDIR=$WorkRoot"
Write-Host "GitBashExe=$GitBashExe"
Write-Host "BRICSCAD_EXE=$BricscadExe"
Write-Host "Keeping workdir and writing launcher.log under $WorkRoot"

& $GitBashExe ./autolisp-script/autolisp --bricscad --mode batch --interactive 2>&1 |
  Tee-Object -FilePath (Join-Path $WorkRoot "launcher.log")

exit $LASTEXITCODE
