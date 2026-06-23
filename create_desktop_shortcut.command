#!/bin/bash
set -e

cd "$(dirname "$0")"

TARGET_PATH="$PWD/Prospectus Local Translator.app"
SHORTCUT_PATH="$HOME/Desktop/Prospectus Local Translator.app"

if [ ! -d "$TARGET_PATH" ]; then
  echo "Prospectus Local Translator.app was not found."
  read -r -p "Press Enter to exit..."
  exit 1
fi

rm -f "$SHORTCUT_PATH"
ln -s "$TARGET_PATH" "$SHORTCUT_PATH"
chmod +x "$TARGET_PATH/Contents/MacOS/launcher"

echo "Desktop shortcut created:"
echo "$SHORTCUT_PATH"
if [ "${1:-}" != "--no-pause" ]; then
  read -r -p "Press Enter to exit..."
fi
