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
    # Core Fedora dependencies must exist; installation should fail if any are unavailable.
    fedora_core_packages=(
        python3
        python3-pip
        xcb-util-cursor
        xcb-util-wm
        xcb-util-image
        xcb-util-keysyms
        xcb-util-renderutil
        libxkbcommon-x11
        mesa-libEGL
        mesa-libGL
        nss
        alsa-lib
    )

    # Xinerama helper package naming differs across Fedora versions/repos.
    fedora_xinerama_candidates=(
        xcb-util-xinerama
        xcb-util
    )

    package_exists_dnf() {
        local pkg="$1"
        dnf list --installed "$pkg" >/dev/null 2>&1 || dnf list --available "$pkg" >/dev/null 2>&1
    }

    fedora_install_packages=("${fedora_core_packages[@]}")
    xinerama_pkg=""

    for candidate in "${fedora_xinerama_candidates[@]}"; do
        if package_exists_dnf "$candidate"; then
            xinerama_pkg="$candidate"
            break
        fi
    done

    if [[ -n "$xinerama_pkg" ]]; then
        echo "Using Fedora Xinerama package: $xinerama_pkg"
        fedora_install_packages+=("$xinerama_pkg")
    else
        echo "Warning: No Fedora Xinerama helper package found (tried: ${fedora_xinerama_candidates[*]}). Continuing without it."
    fi

    sudo dnf install -y "${fedora_install_packages[@]}"
fi

# 2. Set up virtual environment
echo "Setting up virtual environment..."
python3 -m venv venv
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
