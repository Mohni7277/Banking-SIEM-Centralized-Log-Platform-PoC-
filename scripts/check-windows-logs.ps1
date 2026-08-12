$ErrorActionPreference = "Stop"

Write-Host "Indices:"
curl.exe -s "http://localhost:9200/_cat/indices/logs-windows-*?v"

Write-Host ""
Write-Host "Recent Windows logs:"
$body = @{
  size = 10
  sort = @(
    @{
      "@timestamp" = @{
        order = "desc"
      }
    }
  )
  query = @{
    match_all = @{}
  }
} | ConvertTo-Json -Depth 10

Invoke-RestMethod `
  -Uri "http://localhost:9200/logs-windows-*/_search?pretty" `
  -Method Post `
  -ContentType "application/json" `
  -Body $body | ConvertTo-Json -Depth 12
