import os
import sys

def get_base_path():
    """ 
    Uygulamanın çalıştığı ana dizini döner.
    Frozen (EXE) modda ise, EXE'nin bulunduğu klasörü (sys.executable) döner.
    Böylece assets/themes/locales klasörleri EXE'nin yanında aranır.
    """
    if getattr(sys, 'frozen', False):
        # .../dist/DungeonMasterTool/DungeonMasterTool.exe -> .../dist/DungeonMasterTool/
        return os.path.dirname(sys.executable)
    
    # Geliştirme ortamı (Dev)
    return os.path.dirname(os.path.abspath(__file__))

BASE_DIR = get_base_path()

def get_data_root():
    """ 
    Kullanıcı verilerinin (save dosyaları, dünyalar) saklanacağı dizin.
    """
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    else:
        return os.path.dirname(os.path.abspath(__file__))

DATA_ROOT = get_data_root()

# Klasör yolları (BASE_DIR'e, yani exe'nin yanına göre ayarlanır)
WORLDS_DIR = os.path.join(DATA_ROOT, "worlds")
CACHE_DIR = os.path.join(DATA_ROOT, "cache")
IMAGES_DIR = os.path.join(DATA_ROOT, "assets") # assets exe'nin yanında olacak

# Klasörleri oluştur (Eğer yoksa)
for d in [WORLDS_DIR, CACHE_DIR, IMAGES_DIR]:
    if not os.path.exists(d):
        os.makedirs(d)

API_BASE_URL = "https://www.dnd5eapi.co/api"

# Temalar ve Locales de artık BASE_DIR (Exe yanı) altında aranacak
THEMES_DIR = os.path.join(BASE_DIR, "themes")
LOCALES_DIR = os.path.join(BASE_DIR, "locales")

def load_theme(theme_name):
    """Loads a .qss theme file from the themes directory."""
    path = os.path.join(THEMES_DIR, f"{theme_name}.qss")
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    return "" 

# Default stylesheet
STYLESHEET = load_theme("dark")