#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\env.ps1"

& "$PSScriptRoot\test-fake.ps1"
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

& "$PSScriptRoot\test-bricscad.ps1"
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

& "$PSScriptRoot\test-autocad.ps1"
exit $LASTEXITCODE
