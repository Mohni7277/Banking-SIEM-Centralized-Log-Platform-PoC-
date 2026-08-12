# Banking SIEM — Centralized Log Platform (PoC)

A Docker-based proof of concept for centralizing Windows and Ubuntu logs in OpenSearch. It includes OpenSearch Dashboards, Windows Event Log collection, Ubuntu log collection, and a 30-day index-retention policy.

> **PoC only:** the OpenSearch security plugins are disabled and the stack uses plain HTTP. Do not expose ports `9200` or `5601` to an untrusted network or use this configuration in production.

## Features

- OpenSearch 2.13.0 and OpenSearch Dashboards, started with Docker Compose
- Windows `Security`, `System`, and `Application` event-log collection through Winlogbeat
- Ubuntu `/var/log/auth.log` and `/var/log/syslog` collection through Filebeat or the included Python service
- Separate indexes and data views for Windows (`logs-windows-*`) and Linux (`logs-linux-*`)
- Index State Management (ISM) retention policy: hot → cold after 7 days → delete after 30 days
- PowerShell scripts to start, verify, create data views, and check collected logs

## Architecture

```text
Windows Event Logs ── Winlogbeat ─┐
                                  ├── OpenSearch ── OpenSearch Dashboards
Ubuntu auth/syslog ─ Filebeat ────┘
                    or Python shipper
```

## Prerequisites

- Docker Desktop with Docker Compose
- Windows PowerShell 5.1+ (for the helper scripts)
- Optional: Winlogbeat for Windows log shipping
- Optional: an Ubuntu/Debian or RHEL-compatible host for Linux log shipping

## Quick start

From PowerShell at the repository root:

```powershell
docker compose up -d
# or
.\scripts\start.ps1
```

Verify the containers and cluster:

```powershell
.\scripts\verify.ps1
```

Open these local URLs:

- OpenSearch API: <http://localhost:9200>
- OpenSearch Dashboards: <http://localhost:5601>

## Configure retention and data views

Create the 30-day log-retention policy:

```powershell
.\scripts\create-ism-policy.ps1
```

Create Dashboards data views:

```powershell
.\scripts\create-source-data-views.ps1
```

Use `@timestamp` as the time field. The primary data views are:

- `logs-windows-*`
- `logs-linux-*`

## Windows log collection

1. Install Winlogbeat on the Windows source host.
2. Copy [winlogbeat/winlogbeat.yml](winlogbeat/winlogbeat.yml) to `C:\Program Files\winlogbeat\winlogbeat.yml`.
3. In an elevated PowerShell window, run:

```powershell
cd "C:\Program Files\winlogbeat"
.\winlogbeat.exe test config
.\winlogbeat.exe test output
.\winlogbeat.exe install
Start-Service winlogbeat
Get-Service winlogbeat
```

The default configuration writes to `logs-windows-YYYY.MM.DD`. For a remote OpenSearch host, update `output.elasticsearch.hosts` in the Winlogbeat configuration before installing the service.

## Ubuntu/Linux log collection

The Filebeat configuration is at [filebeat/linux-filebeat.yml](filebeat/linux-filebeat.yml). Before using it, replace `<OPENSEARCH_HOST_IP>` and `<LINUX_SOURCE_HOST>` with values for your environment.

The PoC also includes a lightweight Python shipper and a systemd unit:

- [ubuntu/log_shipper.py](ubuntu/log_shipper.py)
- [ubuntu/bank-siem-log-shipper.service](ubuntu/bank-siem-log-shipper.service)

Detailed end-to-end source-host steps are in [REAL_LOG_COLLECTION_STEPS.md](REAL_LOG_COLLECTION_STEPS.md).

## Check indexed logs

```powershell
.\scripts\check-windows-logs.ps1
.\scripts\check-linux-logs.ps1
Invoke-RestMethod "http://localhost:9200/_cat/indices/logs-*?v"
```

In Dashboards, open **Discover**, select a `logs-windows-*` or `logs-linux-*` data view, and choose a suitable time range.

## Stop the stack

```powershell
docker compose down
```

To also remove the local OpenSearch Docker volume (this deletes indexed PoC data):

```powershell
docker compose down -v
```

## Repository layout

```text
dashboards/   OpenSearch Dashboards configuration
filebeat/     Linux Filebeat configuration
opensearch/   OpenSearch configuration
policies/     ISM log-retention policy
scripts/      Start, verify, setup, and log-check PowerShell scripts
ubuntu/       Ubuntu Filebeat setup and Python/systemd shipper
windows/      Windows PowerShell log shipper and instructions
winlogbeat/   Windows Event Log configuration
```

## Security notes

- Do not commit passwords, API keys, certificates, or real customer/transaction logs.
- Replace documented placeholders such as `<OPENSEARCH_HOST_IP>` and `<LINUX_SOURCE_HOST>` with your own environment values.
- Enable OpenSearch security, TLS, authentication, and least-privilege roles before any production use.
