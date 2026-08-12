$ErrorActionPreference = "Stop"

Set-Location (Split-Path -Parent $PSScriptRoot)

$policyPath = Join-Path (Get-Location) "policies\log-retention.json"
$body = Get-Content -Raw $policyPath

$existing = $null
try {
  $existing = Invoke-RestMethod -Uri "http://localhost:9200/_plugins/_ism/policies/log-retention" -Method Get
} catch {
  $existing = $null
}

if ($existing) {
  Write-Host "ISM policy already exists: log-retention"
  exit 0
}

Invoke-RestMethod `
  -Uri "http://localhost:9200/_plugins/_ism/policies/log-retention" `
  -Method Put `
  -ContentType "application/json" `
  -Body $body | ConvertTo-Json -Depth 12

Write-Host ""
Write-Host "Created ISM policy: log-retention"
