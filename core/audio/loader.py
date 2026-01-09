import os
import yaml
from .models import Theme, MusicState, Track, LoopNode
from config import SOUNDPAD_ROOT

# Taranacak geçerli ses dosyası uzantıları
AUDIO_EXTENSIONS = {'.wav', '.mp3', '.ogg', '.flac', '.m4a'}

def _find_audio_files(path_fragment):
    """
    Verilen yol parçasının bir klasör olup olmadığını kontrol eder.
    Eğer klasörse, içindeki tüm ses dosyalarını liste olarak döndürür.
    Eğer tek bir dosyaysa, tek elemanlı bir liste döndürür.
    """
    full_path = os.path.join(SOUNDPAD_ROOT, path_fragment)
    
    # 1. Eğer yol bir klasör ise
    if os.path.isdir(full_path):
        found_files = []
        for filename in os.listdir(full_path):
            if os.path.splitext(filename)[1].lower() in AUDIO_EXTENSIONS:
                # Klasör içindeki dosyanın göreceli yolunu ekle (örn: sfx/sword-slice/slice-1.wav)
                relative_path = os.path.join(path_fragment, filename)
                found_files.append(relative_path)
        return found_files
        
    # 2. Eğer yol bir dosya ise (uzantısı olsun veya olmasın)
    else:
        # Uzantısı yoksa, geçerli uzantıları deneyerek dosyayı bulmaya çalış
        if not os.path.splitext(full_path)[1]:
            for ext in AUDIO_EXTENSIONS:
                if os.path.exists(full_path + ext):
                    return [path_fragment + ext]
        # Uzantısı varsa ve dosya mevcutsa
        elif os.path.exists(full_path):
            return [path_fragment]
            
    # Hiçbir şey bulunamadıysa
    return []

def load_global_library():
    """
    Global kütüphaneyi yükler. 'file' anahtarını tarayarak
    tekil dosyaları veya klasör içindeki dosyaları 'files' listesine dönüştürür.
    """
    library = {'ambience': [], 'sfx': [], 'shortcuts': {}}
    library_file = os.path.join(SOUNDPAD_ROOT, "soundpad_library.yaml")
    if not os.path.exists(library_file): return library

    try:
        with open(library_file, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        
        # Ambiyans ve SFX listelerini işle
        for sound_type in ['ambience', 'sfx']:
            for item in data.get(sound_type, []):
                if 'file' in item:
                    # 'file' anahtarını işle ve 'files' listesine dönüştür
                    item['files'] = _find_audio_files(item['file'])
                    del item['file'] # Eski anahtarı sil
            library[sound_type] = data.get(sound_type, [])

        library['shortcuts'] = data.get('shortcuts', {})
    except Exception as e:
        print(f"Error loading global sound library: {e}")
    
    return library

def load_all_themes():
    """Müzik temalarını yükler (Bu fonksiyonun mantığı aynı kalır)."""
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
    """Tek bir tema dosyasını ayrıştırır (Bu fonksiyonun mantığı aynı kalır)."""
    try:
        with open(yaml_path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        if not data: return None
        t_id = data.get("id", os.path.basename(base_folder)); t_name = data.get("name", t_id)
        theme_obj = Theme(name=t_name, id=t_id)
        theme_obj.shortcuts = data.get("shortcuts", {})
        
        raw_states = data.get("states", {}) 
        for state_name, state_data in raw_states.items():
            state_obj = MusicState(name=state_name)
            raw_tracks = state_data.get("tracks", {})
            for track_id, track_seq in raw_tracks.items():
                track_obj = Track(name=track_id)
                if not isinstance(track_seq, list): track_seq = [track_seq]
                for node_data in track_seq:
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