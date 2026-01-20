#!/bin/bash

# Simple Installer for Dungeon Master Tool (Arch Linux)

set -e

echo "--- Dungeon Master Tool Arch Linux Installer ---"

# 1. Update and install system dependencies
echo "Installing/Updating system dependencies via pacman..."
sudo pacman -S --needed --noconfirm python python-pip \
    xcb-util-cursor xcb-util-wm xcb-util-image xcb-util-keysyms \
    xcb-util-renderutil xcb-util-xinerama libxkbcommon-x11 \
    nss alsa-lib mesa

# 2. Set up virtual environment
echo "Setting up virtual environment..."
python -m venv venv
source venv/bin/activate

# 3. Install Python dependencies
echo "Installing Python dependencies..."
./venv/bin/pip install --upgrade pip
./venv/bin/pip install -r requirements.txt

# 4. Create a launcher script
echo "Creating launcher script..."
cat <<EOF > run.sh
#!/bin/bash
DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
cd "\$DIR"
"\$DIR/venv/bin/python" "\$DIR/main.py"
EOF
chmod +x run.sh

# 5. Optional Desktop Entry
read -p "Do you want to create a desktop entry? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    APP_PATH=$(pwd)
    mkdir -p ~/.local/share/applications
    cat <<EOF > ~/.local/share/applications/dungeon-master-tool.desktop
[Desktop Entry]
Name=Dungeon Master Tool
Exec=$APP_PATH/run.sh
Icon=$APP_PATH/assets/icon.png
Path=$APP_PATH
Type=Application
Categories=Game;RolePlaying;
Terminal=false
EOF
    echo "Desktop entry created at ~/.local/share/applications/dungeon-master-tool.desktop"
fi

echo "--- Installation Complete ---"
echo "You can now run the tool using './run.sh'"
