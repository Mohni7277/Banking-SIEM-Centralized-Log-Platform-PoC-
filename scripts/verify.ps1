$ErrorActionPreference = "Stop"

Set-Location (Split-Path -Parent $PSScriptRoot)

Write-Host "Containers:"
docker compose ps

Write-Host ""
Write-Host "OpenSearch root:"
Invoke-RestMethod -Uri "http://localhost:9200/" -Method Get | ConvertTo-Json -Depth 8

Write-Host ""
Write-Host "Cluster health:"
Invoke-RestMethod -Uri "http://localhost:9200/_cluster/health?pretty" -Method Get | ConvertTo-Json -Depth 8
