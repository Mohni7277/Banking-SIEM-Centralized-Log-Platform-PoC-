# Windows Log Collection

Winlogbeat connected to OpenSearch but failed with this OpenSearch 2.13 error:

```text
Action/metadata line [1] contains an unknown parameter [_type]
```

For this PoC, Windows logs are shipped by:

```text
windows-log-shipper.ps1
```

It reads:

```text
Application
System
Security
```

and writes to:

```text
logs-windows-YYYY.MM.DD
```

Install from an Administrator PowerShell:

```powershell
cd <PROJECT_DIRECTORY>
powershell -ExecutionPolicy Bypass -File .\windows\install-windows-log-shipper.ps1
```

Check:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-windows-logs.ps1
```
