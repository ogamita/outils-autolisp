$ErrorActionPreference = "Stop"
. "$PSScriptRoot\env.ps1"

Set-Location (Join-Path $PSScriptRoot "..")

& bash ./tests/run.sh --fake-cad --timeout 30 --bricscad
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

& bash ./tests/run.sh --fake-cad --timeout 30 --autocad
exit $LASTEXITCODE
