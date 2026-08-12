# Real Log Collection Steps

This guide connects Windows and Linux log sources to the OpenSearch instance running on the Docker host. It intentionally uses placeholders so the repository contains no environment-specific network details.

Replace these values before running a command or copying a configuration:

```text
<OPENSEARCH_HOST_IP>  IP address of the computer running OpenSearch
<LINUX_SOURCE_IP>     IP address of the Linux source host
<LINUX_USERNAME>      SSH user on the Linux source host
<LINUX_SOURCE_HOST>   Meaningful host label, for example: ubuntu-web-01
<PROJECT_DIRECTORY>   Absolute path to this cloned repository
```

Do not put a Linux password, API key, certificate private key, or real customer logs in this repository.

## 1. Confirm OpenSearch connectivity

On the Docker/OpenSearch host, run:

```powershell
Invoke-RestMethod "http://localhost:9200/"
Invoke-RestMethod "http://<OPENSEARCH_HOST_IP>:9200/"
```

If the second command fails, allow inbound TCP port `9200` in the host firewall. Do not expose the PoC ports to untrusted networks because security is disabled in this configuration.

## 2. Collect Windows Event Logs

1. Install Winlogbeat on the Windows source host.
2. Copy [winlogbeat/winlogbeat.yml](winlogbeat/winlogbeat.yml) to `C:\Program Files\winlogbeat\winlogbeat.yml`.
3. Update `output.elasticsearch.hosts` if OpenSearch is on a different computer.
4. Run the following from an elevated PowerShell session:

```powershell
cd "C:\Program Files\winlogbeat"
.\winlogbeat.exe test config
.\winlogbeat.exe test output
.\winlogbeat.exe install
Start-Service winlogbeat
Get-Service winlogbeat
```

Expected index:

```text
logs-windows-YYYY.MM.DD
```

## 3. Collect Linux logs

Connect to the Linux source host:

```bash
ssh <LINUX_USERNAME>@<LINUX_SOURCE_IP>
curl http://<OPENSEARCH_HOST_IP>:9200/
```

Install Filebeat, then copy [filebeat/linux-filebeat.yml](filebeat/linux-filebeat.yml) to `/etc/filebeat/filebeat.yml`. Replace `<OPENSEARCH_HOST_IP>` and `<LINUX_SOURCE_HOST>` in the copied file.

Alternatively, use the setup helper with environment-specific values:

```bash
OPENSEARCH_URL="http://<OPENSEARCH_HOST_IP>:9200" \
SOURCE_HOST="<LINUX_SOURCE_HOST>" \
bash setup-filebeat.sh
```

The configuration collects `/var/log/auth.log` and `/var/log/syslog`, and sends events to `logs-linux-YYYY.MM.DD`.

The included Python shipper can be used instead of Filebeat. Set the same `OPENSEARCH_URL` and `SOURCE_HOST` environment variables in its systemd service environment before starting it.

## 4. Check indexed events

From `<PROJECT_DIRECTORY>` on the Docker/OpenSearch host:

```powershell
.\scripts\check-windows-logs.ps1
.\scripts\check-linux-logs.ps1
Invoke-RestMethod "http://localhost:9200/_cat/indices/logs-*?v"
```

Open OpenSearch Dashboards at <http://localhost:5601>, select **Discover**, then use `logs-windows-*` or `logs-linux-*` with `@timestamp` as the time field.
