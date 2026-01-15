#!/bin/bash

# Simple Installer for Dungeon Master Tool (Debian/Ubuntu/Generic)

set -e

echo "--- Dungeon Master Tool Linux Installer ---"

# 1. Update and install system dependencies
echo "Installing/Updating system dependencies..."
if command -v apt-get >/dev/null; then
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-venv \
        libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
        libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1 libxkbcommon-x11-0 \
        libegl1 libopengl0 libgl1-mesa-glx libnss3 libasound2
elif command -v dnf >/dev/null; then
    sudo dnf install -y python3 python3-pip \
        xcb-util-cursor xcb-util-wm xcb-util-image xcb-util-keysyms \
        xcb-util-renderutil xcb-util-xinerama libxkbcommon-x11 \
        mesa-libEGL mesa-libGL nss alsa-lib
fi

# 2. Set up virtual environment
echo "Setting up virtual environment..."
python3 -m venv venv
source venv/bin/activate

# 3. Install Python dependencies
echo "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# 4. Create a launcher script
echo "Creating launcher script..."
cat <<EOF > run.sh
#!/bin/bash
source venv/bin/activate
python3 main.py
EOF
chmod +x run.sh

# 5. Optional Desktop Entry
read -p "Do you want to create a desktop entry? (y/n) " -n 1 -r
echo
if [[ \$REPLY =~ ^[Yy]\$ ]]; then
    APP_PATH=\$(pwd)
    mkdir -p ~/.local/share/applications
    cat <<EOF > ~/.local/share/applications/dungeon-master-tool.desktop
[Desktop Entry]
Name=Dungeon Master Tool
Exec=\$APP_PATH/run.sh
Icon=\$APP_PATH/assets/icon.png
Type=Application
Categories=Game;RolePlaying;
EOF
    echo "Desktop entry created at ~/.local/share/applications/dungeon-master-tool.desktop"
fi

echo "--- Installation Complete ---"
echo "You can now run the tool using './run.sh'"
