$ErrorActionPreference = "Stop"

$views = @(
  @{
    id = "logs-windows-star"
    title = "logs-windows-*"
    timeFieldName = "@timestamp"
  },
  @{
    id = "logs-linux-star"
    title = "logs-linux-*"
    timeFieldName = "@timestamp"
  }
)

foreach ($view in $views) {
  $body = @{
    attributes = @{
      title = $view.title
      timeFieldName = $view.timeFieldName
    }
  } | ConvertTo-Json -Depth 5

  Invoke-RestMethod `
    -Uri "http://localhost:5601/api/saved_objects/index-pattern/$($view.id)?overwrite=true" `
    -Method Post `
    -ContentType "application/json" `
    -Headers @{ "osd-xsrf" = "true" } `
    -Body $body | Out-Null

  Write-Host "Created data view: $($view.title)"
}
