import os
import sys
import uuid

APP_NAME = "DungeonMasterTool"


def get_base_path():
    """
    Returns the main directory where the application is running.
    In frozen mode, this is the folder containing the executable.
    """
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))


def get_portable_data_root():
    """Portable data root (next to executable/repo root)."""
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))


def get_user_data_root(platform_name=None, env_map=None):
    """Returns an OS-appropriate user data directory for this app."""
    platform_name = platform_name or sys.platform
    env_map = os.environ if env_map is None else env_map
    home = os.path.expanduser("~")

    if platform_name.startswith("win"):
        base = env_map.get("LOCALAPPDATA") or env_map.get("APPDATA") or home
        return os.path.join(base, APP_NAME)

    if platform_name == "darwin":
        return os.path.join(home, "Library", "Application Support", APP_NAME)

    base = env_map.get("XDG_DATA_HOME") or os.path.join(home, ".local", "share")
    return os.path.join(base, "dungeon-master-tool")


def probe_write_access(directory):
    """
    Checks writeability by creating and deleting a short-lived probe file.
    """
    try:
        os.makedirs(directory, exist_ok=True)
    except OSError:
        return False

    probe_name = f"dm_write_probe_{os.getpid()}_{uuid.uuid4().hex}.tmp"
    probe_path = os.path.join(directory, probe_name)
    try:
        with open(probe_path, "w", encoding="utf-8") as f:
            f.write("ok")
        os.remove(probe_path)
        return True
    except OSError:
        try:
            if os.path.exists(probe_path):
                os.remove(probe_path)
        except OSError:
            pass
        return False


def resolve_data_root(portable_root, env_map=None, platform_name=None, probe=None):
    """
    Resolves data root with this priority:
    1) DM_DATA_ROOT env override (if writable)
    2) Portable root (if writable)
    3) OS user-data fallback (if writable)
    """
    env_map = os.environ if env_map is None else env_map
    platform_name = platform_name or sys.platform
    probe = probe_write_access if probe is None else probe

    reasons = []
    override_raw = (env_map.get("DM_DATA_ROOT") or "").strip()
    if override_raw:
        override = os.path.abspath(
            os.path.expandvars(os.path.expanduser(override_raw))
        )
        if probe(override):
            return override, "override", "env_override"
        reasons.append(f"override_unwritable:{override}")

    if probe(portable_root):
        return portable_root, "portable", ";".join(reasons) if reasons else "portable_writable"
    reasons.append(f"portable_unwritable:{portable_root}")

    fallback = get_user_data_root(platform_name=platform_name, env_map=env_map)
    if probe(fallback):
        return fallback, "fallback", ";".join(reasons)
    reasons.append(f"fallback_unwritable:{fallback}")

    raise RuntimeError(
        "No writable data directory found for DungeonMasterTool. "
        f"Tried portable='{portable_root}' and fallback='{fallback}'."
    )


BASE_DIR = get_base_path()
PORTABLE_DATA_ROOT = get_portable_data_root()
DATA_ROOT, DATA_ROOT_MODE, DATA_ROOT_REASON = resolve_data_root(PORTABLE_DATA_ROOT)

# --- Directory Definitions ---
WORLDS_DIR = os.path.join(DATA_ROOT, "worlds")
CACHE_DIR = os.path.join(DATA_ROOT, "cache")

# Application assets (fixed, next to executable/repo)
ASSETS_DIR = os.path.join(BASE_DIR, "assets")
IMAGES_DIR = ASSETS_DIR
THEMES_DIR = os.path.join(BASE_DIR, "themes")
LOCALES_DIR = os.path.join(BASE_DIR, "locales")
SOUNDPAD_ROOT = os.path.join(ASSETS_DIR, "soundpad")

for required_dir in [WORLDS_DIR, CACHE_DIR]:
    try:
        os.makedirs(required_dir, exist_ok=True)
    except OSError as exc:
        raise RuntimeError(
            f"Unable to create required data directory: {required_dir}"
        ) from exc

# Optional resource dirs: best effort only
for optional_dir in [ASSETS_DIR, SOUNDPAD_ROOT]:
    if not os.path.exists(optional_dir):
        try:
            os.makedirs(optional_dir, exist_ok=True)
        except OSError:
            pass

# --- Other Settings ---
API_BASE_URL = "https://www.dnd5eapi.co/api"


def load_theme(theme_name):
    """Loads a .qss theme file from the themes directory."""
    path = os.path.join(THEMES_DIR, f"{theme_name}.qss")
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    return ""


STYLESHEET = load_theme("dark")
