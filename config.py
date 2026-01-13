import os
import sys

def get_base_path():
    """ 
    Returns the main directory where the application is running.
    In Frozen (EXE) mode, returns the folder containing the EXE (sys.executable).
    This ensures assets/themes/locales folders are looked for next to the EXE.
    """
    if getattr(sys, 'frozen', False):
        # .../dist/DungeonMasterTool/DungeonMasterTool.exe -> .../dist/DungeonMasterTool/
        return os.path.dirname(sys.executable)
    
    # Development environment (Dev)
    return os.path.dirname(os.path.abspath(__file__))

BASE_DIR = get_base_path()

def get_data_root():
    """ 
    Directory where user data (save files, worlds) will be stored.
    """
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    else:
        return os.path.dirname(os.path.abspath(__file__))

DATA_ROOT = get_data_root()

# --- Directory Definitions ---

# User data (Variable, next to application)
WORLDS_DIR = os.path.join(DATA_ROOT, "worlds")
CACHE_DIR = os.path.join(DATA_ROOT, "cache")

# Application assets (Fixed, next to exe)
ASSETS_DIR = os.path.join(BASE_DIR, "assets")
IMAGES_DIR = ASSETS_DIR  # IMAGES_DIR can remain for backwards compatibility, now points to ASSETS_DIR
THEMES_DIR = os.path.join(BASE_DIR, "themes")
LOCALES_DIR = os.path.join(BASE_DIR, "locales")

# NEW ADDED SOUNDPAD DIRECTORY
SOUNDPAD_ROOT = os.path.join(ASSETS_DIR, "soundpad")

# Create necessary folders at application startup
for d in [WORLDS_DIR, CACHE_DIR, ASSETS_DIR, SOUNDPAD_ROOT]:
    if not os.path.exists(d):
        os.makedirs(d)

# --- Diğer Ayarlar ---

API_BASE_URL = "https://www.dnd5eapi.co/api"

def load_theme(theme_name):
    """Loads a .qss theme file from the themes directory."""
    path = os.path.join(THEMES_DIR, f"{theme_name}.qss")
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    return "" 

# Default stylesheet
STYLESHEET = load_theme("dark")