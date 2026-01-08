import os
import yaml
from .models import Theme, MusicState, Track, LoopNode
from config import BASE_DIR

SOUNDPAD_ROOT = os.path.join(BASE_DIR, "assets", "soundpad")

def load_all_themes():
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
    try:
        with open(yaml_path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        if not data: return None

        t_id = data.get("id", os.path.basename(base_folder))
        t_name = data.get("name", t_id)
        
        theme_obj = Theme(name=t_name, id=t_id)
        
        # 'layers' yerine 'states' okuyoruz
        raw_states = data.get("states", {}) 
        
        for state_name, state_data in raw_states.items():
            state_obj = MusicState(name=state_name)
            
            raw_tracks = state_data.get("tracks", {})
            for track_id, track_seq in raw_tracks.items():
                track_obj = Track(name=track_id)
                if not isinstance(track_seq, list): track_seq = [track_seq]

                for node_data in track_seq:
                    if isinstance(node_data, str):
                        filename = node_data; repeat = 0
                    else:
                        filename = node_data.get("file"); repeat = node_data.get("repeat", 0)
                    
                    full_path = os.path.join(base_folder, filename)
                    track_obj.sequence.append(LoopNode(full_path, repeat))
                
                state_obj.tracks[track_id] = track_obj
            
            theme_obj.states[state_name] = state_obj
            
        return theme_obj
    except Exception as e:
        print(f"Error loading {yaml_path}: {e}")
        return None
