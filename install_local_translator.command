#!/bin/bash
set -e

cd "$(dirname "$0")"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 was not found. Please install Python 3 first."
  read -r -p "Press Enter to exit..."
  exit 1
fi

python3 -m venv ".venv"
source ".venv/bin/activate"
python -m pip install --upgrade pip
python -m pip install --upgrade certifi
python -m pip install -r "requirements_local.txt"
python "local_translation_server.py" --install-model --source en --target zh

echo ""
echo "Installation is complete."
echo "Creating desktop shortcut..."
./create_desktop_shortcut.command --no-pause || true
echo "You can now double-click Prospectus Local Translator.app or the desktop shortcut to open the tool."
echo "The app will ask for the website address every time it opens."
read -r -p "Press Enter to exit..."
