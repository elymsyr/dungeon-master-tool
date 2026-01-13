import os
import yaml
import shutil
from .models import Theme, MusicState, Track, LoopNode
from config import SOUNDPAD_ROOT

# Taranacak geçerli ses dosyası uzantıları
AUDIO_EXTENSIONS = {'.wav', '.mp3', '.ogg', '.flac', '.m4a'}

def _find_audio_files(path_fragment):
    """
    Checks if the given path fragment is a directory.
    If it is a directory, returns a list of all audio files inside.
    If it is a single file, returns a single-element list.
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
    Loads the global library. Scans the 'file' key
    and transforms single files or files inside folders into the 'files' list.
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
    """Parses a single theme file (Logic remains the same)."""
    try:
        with open(yaml_path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        if not data: return None
        t_id = data.get("id", os.path.basename(base_folder))
        t_name = data.get("name", t_id)
        theme_obj = Theme(name=t_name, id=t_id)
        theme_obj.shortcuts = data.get("shortcuts", {})
        
        raw_states = data.get("states", {}) 
        for state_name, state_data in raw_states.items():
            state_obj = MusicState(name=state_name)
            raw_tracks = state_data.get("tracks", {})
            for track_id, track_seq in raw_tracks.items():
                track_obj = Track(name=track_id)
                if not isinstance(track_seq, list):
                    track_seq = [track_seq]
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

def add_to_library(category, name, file_path):
    """
    Adds a new sound file to the global library.
    1. Copies the file to assets/soundpad/imported/
    2. Updates soundpad_library.yaml
    """
    if category not in ['ambience', 'sfx']:
        return False, "Invalid category"

    # 1. Prepare Destination
    imported_dir = os.path.join(SOUNDPAD_ROOT, "imported")
    if not os.path.exists(imported_dir):
        os.makedirs(imported_dir)

    filename = os.path.basename(file_path)
    dest_path = os.path.join(imported_dir, filename)
    
    # Avoid overwrite by appending number if exists
    base, ext = os.path.splitext(filename)
    counter = 1
    while os.path.exists(dest_path):
        dest_path = os.path.join(imported_dir, f"{base}_{counter}{ext}")
        counter += 1
        
    try:
        shutil.copy2(file_path, dest_path)
    except Exception as e:
        return False, f"File copy failed: {e}"

    # 2. Update YAML
    library_file = os.path.join(SOUNDPAD_ROOT, "soundpad_library.yaml")
    data = {'ambience': [], 'sfx': [], 'shortcuts': {}}
    
    if os.path.exists(library_file):
        try:
            with open(library_file, "r", encoding="utf-8") as f:
                loaded = yaml.safe_load(f)
                if loaded: data = loaded
        except Exception as e:
            print(f"Error reading library for update: {e}")

    # Ensure category list exists
    if category not in data:
        data[category] = []

    # Relative path from SOUNDPAD_ROOT
    # dest_path = .../assets/soundpad/imported/file.wav
    # SOUNDPAD_ROOT = .../assets/soundpad
    # relative = imported/file.wav
    rel_path = os.path.relpath(dest_path, SOUNDPAD_ROOT)
    
    # Add new entry
    # Using 'id' as name_timestamp or just uuid could be better, but name slug is simple
    import time
    # simple unique id
    new_id = f"{category}_{int(time.time())}"
    
    new_entry = {
        'id': new_id,
        'name': name,
        'file': rel_path # loader uses 'file' then converts to 'files' list
    }
    
    data[category].append(new_entry)
    
    try:
        with open(library_file, "w", encoding="utf-8") as f:
            yaml.dump(data, f, allow_unicode=True, default_flow_style=False)
    except Exception as e:
        return False, f"YAML update failed: {e}"
        
    return True, new_entry

def create_theme(name, t_id, state_map):
    """
    Creates a new theme directory and yaml file.
    name: Display Name (e.g. "Dark Forest")
    t_id: Directory Name (e.g. "dark_forest")
    state_map: { 
        'normal': { 'base': 'path/to/file.wav', 'level1': '...' },
        'combat': { ... }
    }
    """
    if not name or not t_id or not state_map:
        return False, "Missing info"
        
    theme_dir = os.path.join(SOUNDPAD_ROOT, t_id)
    if os.path.exists(theme_dir):
        return False, "Theme ID already exists"
        
    try:
        os.makedirs(theme_dir)
        
        # Build YAML structure
        yaml_states = {}
        
        for state_name, tracks in state_map.items():
            state_data = {'tracks': {}}
            
            for track_key, src_path in tracks.items():
                if not src_path or not os.path.exists(src_path): 
                    continue
                    
                # Copy file
                # Rename logic: {state}_{track}_{filename}
                ext = os.path.splitext(src_path)[1]
                new_filename = f"{state_name}_{track_key}{ext}"
                dest_path = os.path.join(theme_dir, new_filename)
                
                shutil.copy2(src_path, dest_path)
                
                # Add to yaml data
                # Simplest structure: list of single file with repeat 0
                state_data['tracks'][track_key] = [
                    {'file': new_filename, 'repeat': 0}
                ]
            
            yaml_states[state_name] = state_data
            
        theme_data = {
            'id': t_id,
            'name': name,
            'states': yaml_states
        }
        
        yaml_path = os.path.join(theme_dir, "theme.yaml")
        with open(yaml_path, "w", encoding="utf-8") as f:
            yaml.dump(theme_data, f, allow_unicode=True, default_flow_style=False)
            
        return True, theme_dir
        
    except Exception as e:
        return False, str(e)