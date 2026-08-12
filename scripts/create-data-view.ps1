$ErrorActionPreference = "Stop"

$script = Join-Path $PSScriptRoot "create-source-data-views.ps1"
& $script
