import os
import yaml
from .models import Theme, MusicState, Track, LoopNode
from config import BASE_DIR

# Ana ses dosyalarının bulunduğu kök dizin
SOUNDPAD_ROOT = os.path.join(BASE_DIR, "assets", "soundpad")

def load_global_library():
    """
    Global ambiyans, SFX ve varsayılan kısayolları içeren 'soundpad_library.yaml' dosyasını yükler.
    Bu dosya, tüm temalar tarafından paylaşılan ortak bir kaynaktır.
    """
    library = {
        'ambience': [],
        'sfx': [],
        'shortcuts': {}
    }
    library_file = os.path.join(SOUNDPAD_ROOT, "soundpad_library.yaml")
    
    if not os.path.exists(library_file):
        print("Warning: 'soundpad_library.yaml' not found. Ambience and SFX will be empty.")
        return library

    try:
        with open(library_file, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        
        # YAML dosyasından ilgili bölümleri oku, yoksa boş liste/sözlük ata
        library['ambience'] = data.get('ambience', [])
        library['sfx'] = data.get('sfx', [])
        library['shortcuts'] = data.get('shortcuts', {})
        
    except Exception as e:
        print(f"Error loading global sound library: {e}")
    
    return library

def load_all_themes():
    """
    'assets/soundpad' altındaki klasörleri tarar. Her klasördeki 'theme.yaml' dosyasını
    bir müzik teması olarak yükler.
    """
    themes = {}
    if not os.path.exists(SOUNDPAD_ROOT):
        os.makedirs(SOUNDPAD_ROOT)
        return {}

    for folder_name in os.listdir(SOUNDPAD_ROOT):
        folder_path = os.path.join(SOUNDPAD_ROOT, folder_name)
        if os.path.isdir(folder_path):
            yaml_path = os.path.join(folder_path, "theme.yaml")
            if os.path.exists(yaml_path):
                theme = _parse_theme_file(yaml_path, folder_path)
                if theme:
                    themes[theme.id] = theme
    return themes

def _parse_theme_file(yaml_path, base_folder):
    """
    Tek bir 'theme.yaml' dosyasını ayrıştırır. Sadece 'states' (müzik) ve 
    isteğe bağlı 'shortcuts' (kısayol özelleştirmeleri) bölümlerini okur.
    """
    try:
        with open(yaml_path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        if not data: return None

        t_id = data.get("id", os.path.basename(base_folder))
        t_name = data.get("name", t_id)
        
        theme_obj = Theme(name=t_name, id=t_id)
        
        # Temaya özel kısayolları yükle (varsa)
        theme_obj.shortcuts = data.get("shortcuts", {})
        
        # Müzik durumlarını (states) ve katmanlarını (tracks) işle
        raw_states = data.get("states", {}) 
        for state_name, state_data in raw_states.items():
            state_obj = MusicState(name=state_name)
            
            raw_tracks = state_data.get("tracks", {})
            for track_id, track_seq in raw_tracks.items():
                track_obj = Track(name=track_id)
                # Eğer tek dosya varsa, onu liste haline getir
                if not isinstance(track_seq, list): track_seq = [track_seq]

                for node_data in track_seq:
                    # YAML'da sadece dosya adı (string) veya obje ({'file': ...}) olabilir
                    filename = node_data if isinstance(node_data, str) else node_data.get("file")
                    if not filename: continue

                    full_path = os.path.join(base_folder, filename)
                    track_obj.sequence.append(LoopNode(full_path))
                
                state_obj.tracks[track_id] = track_obj
            
            theme_obj.states[state_name] = state_obj
            
        return theme_obj
    except Exception as e:
        print(f"Error parsing theme file '{yaml_path}': {e}")
        return None