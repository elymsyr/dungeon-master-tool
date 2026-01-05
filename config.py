import os
import sys

def get_settings_path():
    """Return the path to settings.json, using AppData on Windows."""
    if sys.platform == "win32":
        appdata = os.environ.get("APPDATA")
        if appdata:
            app_dir = os.path.join(appdata, "DungeonMasterTool")
            if not os.path.exists(app_dir):
                os.makedirs(app_dir)
            return os.path.join(app_dir, "settings.json")
    elif sys.platform.startswith("linux"):
        xdg_config = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
        app_dir = os.path.join(xdg_config, "DungeonMasterTool")
        if not os.path.exists(app_dir):
            os.makedirs(app_dir)
        return os.path.join(app_dir, "settings.json")
    # Fallback: use cache/settings.json in project or data dir
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "cache", "settings.json")

def get_base_path():
    """ PyInstaller ile uyumlu base path döner. """
    if getattr(sys, 'frozen', False):
        return sys._MEIPASS
    return os.path.dirname(os.path.abspath(__file__))

BASE_DIR = get_base_path()

BASE_DIR = get_base_path()


# --- DATA ROOT SELECTION ---
import json
def get_data_root():
    # Try to read user setting from settings.json (now in AppData on Windows/Linux)
    import json
    settings_path = get_settings_path()
    try:
        if os.path.exists(settings_path):
            with open(settings_path, "r", encoding="utf-8") as f:
                settings = json.load(f)
                data_dir = settings.get("data_dir")
                if data_dir and os.path.isdir(data_dir):
                    return data_dir
    except Exception:
        pass
    # Default: use AppData (Windows) or ~/.config (Linux)
    if sys.platform == "win32":
        appdata = os.environ.get("APPDATA")
        if appdata:
            app_dir = os.path.join(appdata, "DungeonMasterTool")
            if not os.path.exists(app_dir):
                os.makedirs(app_dir)
            return app_dir
    elif sys.platform.startswith("linux"):
        xdg_config = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
        app_dir = os.path.join(xdg_config, "DungeonMasterTool")
        if not os.path.exists(app_dir):
            os.makedirs(app_dir)
        return app_dir
    # Fallback: use exe's parent or project root
    if getattr(sys, 'frozen', False):
        exe_path = sys.executable
        return os.path.dirname(os.path.dirname(exe_path))
    else:
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