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

# --- Dizin Tanımlamaları ---

# Kullanıcı verileri (Değişken, uygulama yanında)
WORLDS_DIR = os.path.join(DATA_ROOT, "worlds")
CACHE_DIR = os.path.join(DATA_ROOT, "cache")

# Uygulama varlıkları (Sabit, exe yanında)
ASSETS_DIR = os.path.join(BASE_DIR, "assets")
IMAGES_DIR = ASSETS_DIR  # IMAGES_DIR eski uyumluluk için kalabilir, artık ASSETS_DIR'i işaret ediyor
THEMES_DIR = os.path.join(BASE_DIR, "themes")
LOCALES_DIR = os.path.join(BASE_DIR, "locales")

# YENİ EKLENEN SOUNDPAD DİZİNİ
SOUNDPAD_ROOT = os.path.join(ASSETS_DIR, "soundpad")

# Gerekli klasörleri uygulamanın başlangıcında oluştur
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