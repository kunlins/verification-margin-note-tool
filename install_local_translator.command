#!/bin/bash
set -e

cd "$(dirname "$0")"

RUNTIME_DIR="$HOME/Library/Application Support/Prospectus Local Translator"
VENV_DIR="$RUNTIME_DIR/venv"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$PLIST_DIR/com.prospectus.localtranslator.plist"
SERVICE_LABEL="com.prospectus.localtranslator"
TRANSLATOR_PORT="18765"
TRANSLATOR_URL="http://127.0.0.1:$TRANSLATOR_PORT"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 was not found. Please install Python 3 first."
  read -r -p "Press Enter to exit..."
  exit 1
fi

mkdir -p "$RUNTIME_DIR"
cp "local_translation_server.py" "$RUNTIME_DIR/local_translation_server.py"
cp "check_site_status.py" "$RUNTIME_DIR/check_site_status.py"
cp "requirements_local.txt" "$RUNTIME_DIR/requirements_local.txt"

python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip
python -m pip install --upgrade certifi
python -m pip install -r "$RUNTIME_DIR/requirements_local.txt"
python "$RUNTIME_DIR/local_translation_server.py" --install-model --source en --target zh

mkdir -p "$PLIST_DIR"
cat > "$PLIST_FILE" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$SERVICE_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$VENV_DIR/bin/python</string>
    <string>$RUNTIME_DIR/local_translation_server.py</string>
    <string>--no-browser</string>
    <string>--port</string>
    <string>$TRANSLATOR_PORT</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$RUNTIME_DIR</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/prospectus-local-translator.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/prospectus-local-translator.log</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)" "$PLIST_FILE" >/dev/null 2>&1 || true
if ! launchctl bootstrap "gui/$(id -u)" "$PLIST_FILE" >/dev/null 2>&1; then
  if ! launchctl load "$PLIST_FILE" >/dev/null 2>&1; then
    echo "Failed to register the macOS background service."
    exit 1
  fi
fi
launchctl kickstart -k "gui/$(id -u)/$SERVICE_LABEL" >/dev/null 2>&1 || true

echo "Waiting for local translation service..."
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS "$TRANSLATOR_URL/health" >/dev/null 2>&1; then
    echo "Local translation service is running."
    break
  fi
  sleep 1
done

if ! curl -fsS "$TRANSLATOR_URL/health" >/dev/null 2>&1; then
  echo "Local translation service failed to start on port $TRANSLATOR_PORT."
  echo "Please review /tmp/prospectus-local-translator.log."
  exit 1
fi

echo ""
echo "Installation is complete."
echo "You can now open the website directly in your browser."
echo "Website: https://kunlins.github.io/verification-margin-note-tool/"
read -r -p "Press Enter to exit..."
