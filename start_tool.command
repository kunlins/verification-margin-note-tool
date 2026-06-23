#!/bin/bash
set -e

cd "$(dirname "$0")"

RUNTIME_DIR="$HOME/Library/Application Support/Prospectus Local Translator"
VENV_PYTHON="$RUNTIME_DIR/venv/bin/python"
SERVER_SCRIPT="$RUNTIME_DIR/local_translation_server.py"

if [ ! -x "$VENV_PYTHON" ] || [ ! -f "$SERVER_SCRIPT" ]; then
  echo "Local Python environment was not found."
  echo "Please run install_local_translator.command first."
  read -r -p "Press Enter to exit..."
  exit 1
fi

SITE_URL="$(osascript <<'APPLESCRIPT'
set dialogResult to display dialog "请输入要打开的网站地址，例如：https://your-name.github.io/verification-margin-note-tool/" default answer "" buttons {"取消", "打开"} default button "打开"
return text returned of dialogResult
APPLESCRIPT
)"

if [ -z "$SITE_URL" ]; then
  echo "No website address was provided."
  read -r -p "Press Enter to exit..."
  exit 1
fi

case "$SITE_URL" in
  http://*|https://*) ;;
  *) SITE_URL="https://$SITE_URL" ;;
esac

STATUS_RESULT="$("$VENV_PYTHON" - "$SITE_URL" <<'PY'
import json
import sys
from urllib.parse import urljoin
from urllib.parse import urlparse
from urllib.request import urlopen

site_url = sys.argv[1]
parsed = urlparse(site_url)
last_path = parsed.path.rsplit("/", 1)[-1]
base_url = site_url if site_url.endswith("/") or "." in last_path else site_url + "/"
status_url = urljoin(base_url, "status.json")

try:
    with urlopen(status_url, timeout=8) as response:
        payload = json.loads(response.read().decode("utf-8"))
except Exception as exc:
    print(json.dumps({
        "enabled": False,
        "message": "无法确认该网站服务状态，请检查网站地址或网络连接。",
        "statusUrl": status_url,
        "detail": str(exc),
    }, ensure_ascii=False))
    raise SystemExit

enabled = bool(payload.get("enabled"))
message = str(payload.get("message") or ("Service available." if enabled else "This service is no longer available."))
print(json.dumps({"enabled": enabled, "message": message, "statusUrl": status_url}, ensure_ascii=False))
PY
)"

STATUS_ENABLED="$("$VENV_PYTHON" - "$STATUS_RESULT" <<'PY'
import json
import sys
print("true" if json.loads(sys.argv[1]).get("enabled") else "false")
PY
)"

if [ "$STATUS_ENABLED" != "true" ]; then
  STATUS_MESSAGE="$("$VENV_PYTHON" - "$STATUS_RESULT" <<'PY'
import json
import sys
data = json.loads(sys.argv[1])
print(data.get("message") or "This service is no longer available.")
PY
)"
  osascript - "$STATUS_MESSAGE" <<'APPLESCRIPT'
on run argv
  display dialog (item 1 of argv) buttons {"确定"} default button "确定"
end run
APPLESCRIPT
  exit 0
fi

echo "Starting local translation service..."
echo "Opening website: $SITE_URL"
nohup "$VENV_PYTHON" "$SERVER_SCRIPT" --no-browser --idle-timeout 14400 >/tmp/prospectus-local-translator.log 2>&1 &
SERVER_PID=$!

cleanup() {
  if kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

sleep 1
open "$SITE_URL"
echo ""
echo "Local translation service is running."
echo "Close this window or press Control-C when you finish using the tool."
wait "$SERVER_PID"
