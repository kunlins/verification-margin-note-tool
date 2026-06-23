#!/bin/bash
set -e

cd "$(dirname "$0")"

RUNTIME_DIR="$HOME/Library/Application Support/Prospectus Local Translator"
VENV_DIR="$RUNTIME_DIR/venv"

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

echo ""
echo "Installation is complete."
echo "Creating desktop shortcut..."
./create_desktop_shortcut.command --no-pause || true
echo "You can now double-click Prospectus Local Translator.app or the desktop shortcut to open the tool."
echo "The app will ask for the website address every time it opens."
read -r -p "Press Enter to exit..."
