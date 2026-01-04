import os
import json
import shutil
import uuid
from config import WORLDS_DIR, BASE_DIR, CACHE_DIR
from core.models import get_default_entity_structure
from core.api_client import DndApiClient
from core.locales import set_language

LIBRARY_DIR = os.path.join(CACHE_DIR, "library")
CACHE_FILE = os.path.join(CACHE_DIR, "reference_indexes.json")

class DataManager:
    def __init__(self):
        self.settings = self.load_settings()
        set_language(self.settings.get("language", "EN"))
        
        self.current_campaign_path = None
        # Varsayılan boş yapı
        self.data = {
            "world_name": "", 
            "entities": {}, 
            "map_data": {"image_path": "", "pins": []},
            "sessions": [],
            "last_active_session_id": None # Son oturumu hatırlamak için
        }
        self.api_client = DndApiClient()
        self.reference_cache = {}
        
        if not os.path.exists(WORLDS_DIR): os.makedirs(WORLDS_DIR)
        self._load_reference_cache()

    def _load_reference_cache(self):
        if not os.path.exists(CACHE_DIR): os.makedirs(CACHE_DIR)
        if os.path.exists(CACHE_FILE):
            try:
                with open(CACHE_FILE, "r", encoding="utf-8") as f: self.reference_cache = json.load(f)
            except: self.reference_cache = {}
        else: self.reference_cache = {}

    def _save_reference_cache(self):
        if not os.path.exists(CACHE_DIR): os.makedirs(CACHE_DIR)
        with open(CACHE_FILE, "w", encoding="utf-8") as f: json.dump(self.reference_cache, f, indent=4)

    # --- AYARLAR ---
    def load_settings(self):
        path = os.path.join(CACHE_DIR, "settings.json")
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as f: return json.load(f)
            except: pass
        return {"language": "EN"}

    def save_settings(self, settings):
        path = os.path.join(CACHE_DIR, "settings.json")
        if not os.path.exists(CACHE_DIR): os.makedirs(CACHE_DIR)
        with open(path, "w", encoding="utf-8") as f: json.dump(settings, f, indent=4)
        self.settings = settings
        set_language(settings.get("language", "EN"))

    def get_api_index(self, category):
        if category in self.reference_cache: return self.reference_cache[category]
        data = self.api_client.get_list(category)
        if data:
            self.reference_cache[category] = data
            self._save_reference_cache()
            return data
        return []

    # --- KAMPANYA YÖNETİMİ ---
    def get_available_campaigns(self):
        if not os.path.exists(WORLDS_DIR): return []
        return [d for d in os.listdir(WORLDS_DIR) if os.path.isdir(os.path.join(WORLDS_DIR, d))]

    def create_campaign(self, world_name):
        folder = os.path.join(WORLDS_DIR, world_name)
        try:
            if not os.path.exists(folder): os.makedirs(folder)
            if not os.path.exists(os.path.join(folder, "assets")): os.makedirs(os.path.join(folder, "assets"))
            
            self.data = {
                "world_name": world_name, 
                "entities": {}, 
                "map_data": {"image_path": "", "pins": []},
                "sessions": [],
                "last_active_session_id": None
            }
            self.current_campaign_path = folder
            self.save_data()
            return True, "Oluşturuldu"
        except Exception as e: return False, str(e)

    def load_campaign_by_name(self, name):
        return self.load_campaign(os.path.join(WORLDS_DIR, name))

    def load_campaign(self, folder):
        path = os.path.join(folder, "data.json")
        if not os.path.exists(path): return False, "Dosya yok"
        try:
            with open(path, "r", encoding="utf-8") as f: self.data = json.load(f)
            
            # Migration
            if "sessions" not in self.data: self.data["sessions"] = []
            if "entities" not in self.data: self.data["entities"] = {}
            if "map_data" not in self.data: self.data["map_data"] = {"image_path": "", "pins": []}
            if "last_active_session_id" not in self.data: self.data["last_active_session_id"] = None
            
            for eid, ent in self.data["entities"].items():
                default = get_default_entity_structure(ent.get("type", "NPC"))
                for key, val in default.items():
                    if key not in ent: ent[key] = val
                if not ent.get("images") and ent.get("image_path"):
                    ent["images"] = [ent["image_path"]]

            self.current_campaign_path = folder
            return True, "Yüklendi"
        except Exception as e: return False, str(e)

    def save_data(self):
        if self.current_campaign_path:
            with open(os.path.join(self.current_campaign_path, "data.json"), "w", encoding="utf-8") as f:
                json.dump(self.data, f, indent=4, ensure_ascii=False)

    # --- SESSION YÖNETİMİ ---
    def create_session(self, name):
        session_id = str(uuid.uuid4())
        new_session = {
            "id": session_id,
            "name": name,
            "date": "Bugün",
            "notes": "",
            "logs": "",
            "combatants": [] # Yeni yapıda burası dict (state) olabilir
        }
        if "sessions" not in self.data: self.data["sessions"] = []
        self.data["sessions"].append(new_session)
        self.set_active_session(session_id)
        self.save_data()
        return session_id

    def get_session(self, session_id):
        if "sessions" not in self.data: return None
        for s in self.data["sessions"]:
            if s["id"] == session_id: return s
        return None

    def save_session_data(self, session_id, notes, logs, combatants):
        if "sessions" not in self.data: return
        for s in self.data["sessions"]:
            if s["id"] == session_id:
                s["notes"] = notes
                s["logs"] = logs
                s["combatants"] = combatants # Artık state dict'i de olabilir
                self.set_active_session(session_id)
                self.save_data()
                break

    def set_active_session(self, session_id):
        self.data["last_active_session_id"] = session_id
        # save_data burada çağrılmaz, genellikle save_session_data içinde kaydedilir zaten
        # ama anlık değişim için çağrılabilir.
        
    def get_last_active_session_id(self):
        return self.data.get("last_active_session_id")

    # --- VARLIK YÖNETİMİ ---
    def save_entity(self, eid, data):
        if not eid: eid = str(uuid.uuid4())
        if eid in self.data["entities"]: self.data["entities"][eid].update(data)
        else: self.data["entities"][eid] = data
        self.save_data()
        return eid

    def delete_entity(self, eid):
        if eid in self.data["entities"]:
            del self.data["entities"][eid]
            self.save_data()

    def get_entity_name(self, eid):
        if eid in self.data["entities"]:
            return self.data["entities"][eid].get("name")
        return None

    def fetch_from_api(self, category, query):
        for eid, ent in self.data["entities"].items():
            if ent["name"].lower() == query.lower() and ent["type"] == category:
                return True, "Veritabanında zaten var.", eid
        
        parsed_data, msg = self.api_client.search(category, query)
        if not parsed_data: return False, msg, None
        return True, "API'den çekildi.", parsed_data

    def fetch_details_from_api(self, category, index_name):
        folder_map = {
            "Canavar": "monsters", "Büyü (Spell)": "spells", "Eşya (Equipment)": "equipment",
            "Sınıf (Class)": "classes", "Irk (Race)": "races"
        }
        folder = folder_map.get(category)
        
        # 1. Cache Kontrol
        if folder:
            paths = [os.path.join(LIBRARY_DIR, folder, f"{index_name}.json")]
            if category == "Eşya (Equipment)":
                paths.append(os.path.join(LIBRARY_DIR, "magic-items", f"{index_name}.json"))
            
            for local_path in paths:
                if os.path.exists(local_path):
                    try:
                        with open(local_path, "r", encoding="utf-8") as f:
                            raw = json.load(f)
                            return True, self.api_client.parse_dispatcher(category, raw)
                    except: pass

        # 2. API Çekim
        parsed_data, msg = self.api_client.search(category, index_name)
        if parsed_data: return True, parsed_data
        return False, msg

    def import_entity_with_dependencies(self, data):
        """API verisindeki bağlı büyüleri indirip kaydeder."""
        detected_spells = data.pop("_detected_spell_indices", [])
        linked_spell_ids = []

        if detected_spells:
            print(f"🔮 {len(detected_spells)} bağlı büyü indiriliyor...")
            for spell_index in detected_spells:
                success, spell_data = self.fetch_details_from_api("Büyü (Spell)", spell_index)
                if success:
                    spell_name = spell_data.get("name")
                    existing_id = None
                    for eid, ent in self.data["entities"].items():
                        if ent.get("type") == "Büyü (Spell)" and ent.get("name") == spell_name:
                            existing_id = eid; break
                    
                    if existing_id: linked_spell_ids.append(existing_id)
                    else:
                        new_id = self.save_entity(None, spell_data)
                        linked_spell_ids.append(new_id)

        if linked_spell_ids:
            if "spells" not in data: data["spells"] = []
            for sid in linked_spell_ids:
                if sid not in data["spells"]: data["spells"].append(sid)

        return self.save_entity(None, data)

    # --- HARİTA & RESİM ---
    def import_image(self, src):
        if not self.current_campaign_path: return None
        fname = f"{uuid.uuid4().hex}_{os.path.basename(src)}"
        dest = os.path.join(self.current_campaign_path, "assets", fname)
        shutil.copy2(src, dest)
        return os.path.join("assets", fname)

    def import_pdf(self, src):
        if not self.current_campaign_path: return None
        fname = f"{uuid.uuid4().hex}_{os.path.basename(src)}"
        dest = os.path.join(self.current_campaign_path, "assets", fname)
        shutil.copy2(src, dest)
        return os.path.join("assets", fname)

    def get_full_path(self, rel):
        return os.path.join(self.current_campaign_path, rel) if self.current_campaign_path and rel else None
    
    def set_map_image(self, rel): self.data["map_data"]["image_path"] = rel; self.save_data()
    def add_pin(self, x, y, eid): self.data["map_data"]["pins"].append({"id": str(uuid.uuid4()), "x": x, "y": y, "entity_id": eid}); self.save_data()
    def move_pin(self, pid, x, y):
        for p in self.data["map_data"]["pins"]:
             if p.get("id") == pid: p["x"]=x; p["y"]=y; break
        self.save_data()
    def remove_specific_pin(self, pid):
        self.data["map_data"]["pins"] = [p for p in self.data["map_data"]["pins"] if p.get("id") != pid]
        self.save_data()

    def search_in_library(self, category, search_text):
        results = []
        search_text = search_text.lower()
        cats = [category] if category in self.reference_cache else list(self.reference_cache.keys())
        for c in cats:
            for item in self.reference_cache.get(c, []):
                if search_text in item["name"].lower():
                    results.append({"id": f"lib_{c}_{item['index']}", "name": item["name"], "type": c, "is_library": True})
        return results