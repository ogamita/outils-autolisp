$ErrorActionPreference = "Stop"
. "$PSScriptRoot\env.ps1"

Set-Location (Join-Path $PSScriptRoot "..")

& bash ./tests/run.sh --timeout 30 --autocad
exit $LASTEXITCODE
