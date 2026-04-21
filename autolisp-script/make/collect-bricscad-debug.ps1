#!/usr/bin/env pwsh

param(
  [string]$WorkRoot = "C:\temp\autolisp-debug",
  [string]$SpoolDir = "D:\spool"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $WorkRoot)) {
  throw "Work root not found: $WorkRoot"
}

$latest = Get-ChildItem -LiteralPath $WorkRoot -Directory |
  Sort-Object LastWriteTimeUtc, Name -Descending |
  Select-Object -First 1

if (-not $latest) {
  throw "No autolisp workdir found under $WorkRoot"
}

New-Item -ItemType Directory -Force -Path $SpoolDir | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$dest = Join-Path $SpoolDir ("autolisp-debug-{0}-{1}" -f $stamp, $latest.Name)
New-Item -ItemType Directory -Force -Path $dest | Out-Null

Get-ChildItem -LiteralPath $latest.FullName -Force |
  Copy-Item -Destination $dest -Recurse -Force

@(
  "source=$($latest.FullName)"
  "destination=$dest"
  "copied_at=$(Get-Date -Format o)"
  ""
  Get-ChildItem -LiteralPath $dest -Recurse |
    ForEach-Object {
      if ($_.PSIsContainer) {
        "DIR  $($_.FullName)"
      }
      else {
        "FILE $($_.FullName) $($_.Length)"
      }
    }
) | Set-Content -Path (Join-Path $dest "manifest.txt") -Encoding utf8

Write-Host $dest
