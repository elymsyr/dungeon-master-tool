#!/bin/bash

# Dungeon Master Tool - Arch Linux Installer

set -e

echo "--- Dungeon Master Tool Arch Linux Installer ---"

# Scriptin bulunduğu klasörü al (installer klasörü)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Proje kök dizinine çık
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Project Root: $ROOT_DIR"

# 1. System Dependencies
# 'xcb-util-xinerama' kaldırıldı.
# 'qt6-imageformats' eklendi (Resim desteği için kritik).
# 'tk' eklendi (Python tkinter bazen gerekebiliyor).
echo "Installing system dependencies..."
sudo pacman -S --needed --noconfirm python python-pip \
    xcb-util-cursor xcb-util-wm xcb-util-image xcb-util-keysyms \
    xcb-util-renderutil libxkbcommon-x11 \
    nss alsa-lib mesa qt6-imageformats tk

# 2. Virtual Environment
echo "Setting up virtual environment in $ROOT_DIR..."
cd "$ROOT_DIR"
if [ ! -d "venv" ]; then
    python -m venv venv
fi
source venv/bin/activate

# 3. Python Dependencies
echo "Installing Python requirements..."
# pip'i güncelle
./venv/bin/pip install --upgrade pip
# requirements.txt'yi kök dizinden oku
./venv/bin/pip install -r requirements.txt

# 4. Launcher Script
echo "Creating launcher script..."
cat <<EOF > run.sh
#!/bin/bash
DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
cd "\$DIR"
"\$DIR/venv/bin/python" "\$DIR/main.py"
EOF
chmod +x run.sh

# 5. Desktop Entry
read -p "Create desktop entry? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p ~/.local/share/applications
    cat <<EOF > ~/.local/share/applications/dungeon-master-tool.desktop
[Desktop Entry]
Name=Dungeon Master Tool
Exec=$ROOT_DIR/run.sh
Icon=$ROOT_DIR/assets/icon.png
Path=$ROOT_DIR
Type=Application
Categories=Game;RolePlaying;
Terminal=false
EOF
    echo "Desktop entry created!"
fi

echo "--- Installation Complete! Run with ./run.sh ---"