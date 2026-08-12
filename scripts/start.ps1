$ErrorActionPreference = "Stop"

Set-Location (Split-Path -Parent $PSScriptRoot)

docker compose up -d

Write-Host ""
Write-Host "OpenSearch:  http://localhost:9200"
Write-Host "Dashboards:  http://localhost:5601"
Write-Host ""
Write-Host "Run verify:"
Write-Host "  .\scripts\verify.ps1"
