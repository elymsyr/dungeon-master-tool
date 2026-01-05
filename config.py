import os

import os
import sys

def get_base_path():
    """ PyInstaller ile uyumlu base path döner. """
    if getattr(sys, 'frozen', False):
        return sys._MEIPASS
    return os.path.dirname(os.path.abspath(__file__))

BASE_DIR = get_base_path()

BASE_DIR = get_base_path()

def get_data_root():
    """ 
    Verilerin saklanacağı dizin.
    User isteği: 'exe dosyasının bir üst dizininde tutsun'
    """
    if getattr(sys, 'frozen', False):
        # Frozen (EXE): sys.executable -> .../dist/Game.exe
        # dirname -> .../dist
        # dirname(dirname) -> .../ (Proje kökü veya exe'nin üst klasörü)
        exe_path = sys.executable
        return os.path.dirname(os.path.dirname(exe_path))
    else:
        # Dev: .../root/config.py -> .../root
        return os.path.dirname(os.path.abspath(__file__))

DATA_ROOT = get_data_root()

WORLDS_DIR = os.path.join(DATA_ROOT, "worlds")
CACHE_DIR = os.path.join(DATA_ROOT, "cache")
IMAGES_DIR = os.path.join(DATA_ROOT, "assets")

# Klasörleri oluştur
for d in [WORLDS_DIR, CACHE_DIR, IMAGES_DIR]:
    if not os.path.exists(d):
        os.makedirs(d)

API_BASE_URL = "https://www.dnd5eapi.co/api"

THEMES_DIR = os.path.join(BASE_DIR, "themes")

def load_theme(theme_name):
    """Loads a .qss theme file from the themes directory."""
    path = os.path.join(THEMES_DIR, f"{theme_name}.qss")
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    return "" # Fallback or empty

# Default stylesheet for initial load
STYLESHEET = load_theme("dark")