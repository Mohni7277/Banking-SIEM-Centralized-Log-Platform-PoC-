#!/usr/bin/env python3
import json
import os
import socket
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib import request

OPENSEARCH = os.getenv("OPENSEARCH_URL", "http://<OPENSEARCH_HOST_IP>:9200")
SOURCE_HOST = os.getenv("SOURCE_HOST", "<LINUX_SOURCE_HOST>")
LOG_FILES = ["/var/log/auth.log", "/var/log/syslog"]
STATE_DIR = Path("/var/lib/bank-siem-log-shipper")
STATE_FILE = STATE_DIR / "state.json"
HOSTNAME = socket.gethostname()


def load_state():
    try:
        return json.loads(STATE_FILE.read_text())
    except Exception:
        return {}


def save_state(state):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = STATE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, indent=2))
    tmp.replace(STATE_FILE)


def post_event(path, line):
    now = datetime.now(timezone.utc)
    index = "logs-linux-" + now.strftime("%Y.%m.%d")
    doc = {
        "@timestamp": now.isoformat().replace("+00:00", "Z"),
        "message": line.rstrip("\n"),
        "host": {"name": HOSTNAME},
        "log": {"file": {"path": path}},
        "siem": {
            "environment": "poc",
            "source_type": "linux_auth" if path.endswith("auth.log") else "linux_system",
            "project": "banking-siem",
            "source_host": SOURCE_HOST,
        },
    }
    data = json.dumps(doc).encode("utf-8")
    req = request.Request(
        f"{OPENSEARCH}/{index}/_doc",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with request.urlopen(req, timeout=5) as resp:
        resp.read()


def initialize_offsets(state):
    changed = False
    for path in LOG_FILES:
        if path not in state and os.path.exists(path):
            state[path] = os.path.getsize(path)
            changed = True
    if changed:
        save_state(state)


def scan_once(state):
    for path in LOG_FILES:
        if not os.path.exists(path):
            continue
        size = os.path.getsize(path)
        offset = int(state.get(path, size))
        if size < offset:
            offset = 0
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            fh.seek(offset)
            for line in fh:
                if line.strip():
                    post_event(path, line)
            state[path] = fh.tell()
    save_state(state)


def main():
    state = load_state()
    initialize_offsets(state)
    while True:
        try:
            scan_once(state)
        except Exception as exc:
            print(f"shipper error: {exc}", flush=True)
        time.sleep(2)


if __name__ == "__main__":
    main()
