#!/usr/bin/env bash
set -euo pipefail

# Replace the defaults below or provide values when invoking this script.
OPENSEARCH_URL="${OPENSEARCH_URL:-http://<OPENSEARCH_HOST_IP>:9200}"
SOURCE_HOST="${SOURCE_HOST:-<LINUX_SOURCE_HOST>}"

echo "Checking OpenSearch reachability: ${OPENSEARCH_URL}"
curl -fsS "${OPENSEARCH_URL}/" >/dev/null

if ! command -v filebeat >/dev/null 2>&1; then
  echo "Filebeat is not installed. Install filebeat-oss 7.10.2 first, then run this script again."
  exit 1
fi

sudo cp /etc/filebeat/filebeat.yml "/etc/filebeat/filebeat.yml.backup.$(date +%Y%m%d%H%M%S)"

sudo tee /etc/filebeat/filebeat.yml >/dev/null <<YAML
filebeat.inputs:
  - type: log
    id: linux-auth-logs
    enabled: true
    paths:
      - /var/log/auth.log
    fields:
      environment: poc
      source_type: linux_auth
      project: banking-siem
      source_host: ${SOURCE_HOST}
    fields_under_root: false

  - type: log
    id: linux-system-logs
    enabled: true
    paths:
      - /var/log/syslog
    fields:
      environment: poc
      source_type: linux_system
      project: banking-siem
      source_host: ${SOURCE_HOST}
    fields_under_root: false

processors:
  - add_host_metadata: {}

output.elasticsearch:
  hosts: ["${OPENSEARCH_URL}"]
  index: "logs-linux-%{+yyyy.MM.dd}"

setup.template.enabled: false
setup.ilm.enabled: false
YAML

sudo filebeat test config
sudo filebeat test output
sudo systemctl enable filebeat
sudo systemctl restart filebeat

logger "banking siem ubuntu test log from ${SOURCE_HOST}"

sudo systemctl --no-pager status filebeat
echo "Done. Check OpenSearch for logs-linux-* index."
