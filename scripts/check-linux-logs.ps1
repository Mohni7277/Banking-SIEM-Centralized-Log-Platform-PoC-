$ErrorActionPreference = "Stop"

Write-Host "Indices:"
Invoke-RestMethod "http://localhost:9200/_cat/indices/logs-linux-*?v"

Write-Host ""
Write-Host "Recent Linux logs:"
Invoke-RestMethod `
  -Uri "http://localhost:9200/logs-linux-*/_search?pretty" `
  -Method Post `
  -ContentType "application/json" `
  -Body '{
    "size": 10,
    "sort": [
      { "@timestamp": { "order": "desc" } }
    ],
    "query": {
      "match_all": {}
    }
  }' | ConvertTo-Json -Depth 12
