$ErrorActionPreference = "Stop"

$OpenSearchUrl = "http://localhost:9200"
$StateDir = "C:\ProgramData\bank-siem-windows-log-shipper"
$StateFile = Join-Path $StateDir "state.json"
$Logs = @("Application", "System", "Security")
$PollSeconds = 5

function Read-State {
  if (Test-Path $StateFile) {
    try {
      $raw = Get-Content -Raw $StateFile
      if ($raw.Trim()) {
        return $raw | ConvertFrom-Json -AsHashtable
      }
    } catch {
      return @{}
    }
  }
  return @{}
}

function Write-State($state) {
  if (-not (Test-Path $StateDir)) {
    New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
  }
  $state | ConvertTo-Json -Depth 8 | Set-Content -Path $StateFile -Encoding UTF8
}

function Get-LastRecordId($state, [string]$logName) {
  if ($state.ContainsKey($logName)) {
    return [int64]$state[$logName]
  }

  try {
    $latest = Get-WinEvent -LogName $logName -MaxEvents 1 -ErrorAction Stop
    if ($latest) {
      return [int64]$latest.RecordId
    }
  } catch {
    return 0
  }

  return 0
}

function Initialize-State($state) {
  $changed = $false
  foreach ($logName in $Logs) {
    if ($state.ContainsKey($logName)) {
      continue
    }

    try {
      $latest = Get-WinEvent -LogName $logName -MaxEvents 1 -ErrorAction Stop
      if ($latest) {
        $state[$logName] = [int64]$latest.RecordId
      } else {
        $state[$logName] = 0
      }
    } catch {
      $state[$logName] = 0
    }
    $changed = $true
  }

  if ($changed) {
    Write-State $state
  }
}

function Convert-EventLevel($levelDisplayName) {
  if ([string]::IsNullOrWhiteSpace($levelDisplayName)) {
    return "unknown"
  }
  return $levelDisplayName.ToLowerInvariant()
}

function Send-Event($event, [string]$logName) {
  $index = "logs-windows-" + (Get-Date -Format "yyyy.MM.dd")
  $message = $event.Message
  if ([string]::IsNullOrWhiteSpace($message)) {
    $message = $event.ProviderName
  }

  $doc = [ordered]@{
    "@timestamp" = $event.TimeCreated.ToUniversalTime().ToString("o")
    message = $message
    event = @{
      code = [string]$event.Id
      provider = $event.ProviderName
      level = Convert-EventLevel $event.LevelDisplayName
      log_name = $logName
      record_id = $event.RecordId
    }
    host = @{
      name = $env:COMPUTERNAME
    }
    winlog = @{
      channel = $logName
      computer_name = $event.MachineName
      process_id = $event.ProcessId
      thread_id = $event.ThreadId
    }
    siem = @{
      environment = "poc"
      source_type = "windows_event"
      project = "banking-siem"
      source_host = $env:COMPUTERNAME
    }
  }

  $body = $doc | ConvertTo-Json -Depth 12
  Invoke-RestMethod -Uri "$OpenSearchUrl/$index/_doc" -Method Post -ContentType "application/json" -Body $body | Out-Null
}

function Poll-Once($state) {
  foreach ($logName in $Logs) {
    $lastRecordId = Get-LastRecordId $state $logName

    try {
      $events = Get-WinEvent -FilterHashtable @{ LogName = $logName } -MaxEvents 200 -ErrorAction Stop |
        Where-Object { [int64]$_.RecordId -gt $lastRecordId } |
        Sort-Object RecordId
    } catch {
      continue
    }

    foreach ($event in $events) {
      try {
        Send-Event $event $logName
        $state[$logName] = [int64]$event.RecordId
      } catch {
        break
      }
    }
  }

  Write-State $state
}

$state = Read-State
Initialize-State $state
while ($true) {
  try {
    Poll-Once $state
  } catch {
    Start-Sleep -Seconds $PollSeconds
  }
  Start-Sleep -Seconds $PollSeconds
}
