import time
import uuid
import os
import json
import shutil
import msgpack  # ADDED FOR FAST FORMAT
from config import WORLDS_DIR, BASE_DIR, CACHE_DIR, load_theme
from core.models import get_default_entity_structure, SCHEMA_MAP, PROPERTY_MAP
from core.api_client import DndApiClient
from core.locales import set_language

LIBRARY_DIR = os.path.join(CACHE_DIR, "library")
# We will use .dat (MsgPack) for library cache, but .json support remains
CACHE_FILE_JSON = os.path.join(CACHE_DIR, "reference_indexes.json")
CACHE_FILE_DAT = os.path.join(CACHE_DIR, "reference_indexes.dat")

class DataManager:
    def __init__(self):
        self.settings = self.load_settings()
        set_language(self.settings.get("language", "EN"))
        self.current_theme = self.settings.get("theme", "dark")
        
        self.current_campaign_path = None
        
        self.data = {
            "world_name": "", 
            "entities": {}, 
            "map_data": {"image_path": "", "pins": [], "timeline": []},
            "sessions": [],
            "last_active_session_id": None
        }
        self.api_client = DndApiClient()
        self.reference_cache = {}
        
        if not os.path.exists(WORLDS_DIR):
            os.makedirs(WORLDS_DIR)
        
        self.reload_library_cache()

    def reload_library_cache(self):
        """Loads library index. Tries fast format (.dat) first."""
        if not os.path.exists(CACHE_DIR):
            os.makedirs(CACHE_DIR)
        
        # 1. Hızlı format var mı?
        if os.path.exists(CACHE_FILE_DAT):
            try:
                with open(CACHE_FILE_DAT, "rb") as f:
                    # raw=False: Load as String instead of Byte
                    self.reference_cache = msgpack.unpack(f, raw=False)
                return
            except Exception as e:
                print(f"Cache DAT load error: {e}")

        # 2. Yoksa eski JSON var mı?
        if os.path.exists(CACHE_FILE_JSON):
            try:
                with open(CACHE_FILE_JSON, "r", encoding="utf-8") as f: 
                    self.reference_cache = json.load(f)
                # If JSON found, convert to fast format immediately and save
                self._save_reference_cache()
            except: 
                self.reference_cache = {}
        else: 
            self.reference_cache = {}

    def _save_reference_cache(self):
        """Kütüphane indeksini MsgPack (.dat) olarak kaydeder."""
        if not os.path.exists(CACHE_DIR): os.makedirs(CACHE_DIR)
        try:
            with open(CACHE_FILE_DAT, "wb") as f: 
                msgpack.pack(self.reference_cache, f)
        except Exception as e:
            print(f"Cache save error: {e}")

    def load_settings(self):
        # Ayarlar küçük olduğu için ve elle düzenlenebildiği için JSON kalması daha iyi
        path = os.path.join(CACHE_DIR, "settings.json")
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as f: return json.load(f)
            except: pass
        return {"language": "EN", "theme": "dark"}

    def save_settings(self, settings):
        path = os.path.join(CACHE_DIR, "settings.json")
        if not os.path.exists(CACHE_DIR): os.makedirs(CACHE_DIR)
        
        new_settings = self.settings.copy()
        new_settings.update(settings)
        
        with open(path, "w", encoding="utf-8") as f: json.dump(new_settings, f, indent=4)
        self.settings = new_settings
        set_language(new_settings.get("language", "EN"))
        self.current_theme = new_settings.get("theme", "dark")

    def get_api_index(self, category, page=1, filters=None):
        # Cache Key Generation
        source = self.api_client.current_source_key
        filter_str = str(sorted(filters.items())) if filters else ""
        cache_key = f"{source}_{category}_p{page}_{hash(filter_str)}"
        
        if cache_key in self.reference_cache: 
            return self.reference_cache[cache_key]
            
        response = self.api_client.get_list(category, page=page, filters=filters)
        
        # Handle new format {"results": [], "count": ...}
        # We cache the WHOLE response dict for paginated sources to preserve next/prev links offline
        data_to_cache = response
        
        # Backward compatibility check for methods expecting just a list (if any)
        # But get_api_index callers likely need to know about pagination now.
        # However, ApiBrowser.load_list calls this.
        
        if data_to_cache:
            self.reference_cache[cache_key] = data_to_cache
            self._save_reference_cache()
            return data_to_cache
        return []

    def get_available_campaigns(self):
        if not os.path.exists(WORLDS_DIR): return []
        return [d for d in os.listdir(WORLDS_DIR) if os.path.isdir(os.path.join(WORLDS_DIR, d))]

    def load_campaign_by_name(self, name):
        return self.load_campaign(os.path.join(WORLDS_DIR, name))

    def load_campaign(self, folder):
        """
        Loads the campaign.
        Checks .dat (MsgPack) first. If not found, checks .json and converts.
        """
        json_path = os.path.join(folder, "data.json")
        dat_path = os.path.join(folder, "data.dat")
        
        loaded = False
        
        # 1. MsgPack (Hızlı Format) Dene
        if os.path.exists(dat_path):
            try:
                with open(dat_path, "rb") as f:
                    self.data = msgpack.unpack(f, raw=False)
                loaded = True
            except Exception as e:
                print(f"Error loading DAT file, falling back to JSON: {e}")
        
        # 2. Başarısızsa veya yoksa JSON Dene
        if not loaded and os.path.exists(json_path):
            try:
                with open(json_path, "r", encoding="utf-8") as f:
                    self.data = json.load(f)
                loaded = True
                # JSON'dan yüklendiyse, bir sonraki sefere hızlı açılması için DAT olarak kaydet
                self.current_campaign_path = folder
                self.save_data() 
                print("MIGRATION: Converted JSON campaign to MsgPack.")
            except Exception as e:
                return False, f"JSON Load Error: {str(e)}"

        if not loaded:
            return False, "Kayıt dosyası bulunamadı (data.dat veya data.json)."

        # --- Veri Bütünlüğü Kontrolleri ---
        if "sessions" not in self.data:
            self.data["sessions"] = []
        if "entities" not in self.data:
            self.data["entities"] = {}
        if "map_data" not in self.data:
            self.data["map_data"] = {"image_path": "", "pins": [], "timeline": []}
        if "timeline" not in self.data["map_data"]:
            self.data["map_data"]["timeline"] = []
        if "last_active_session_id" not in self.data:
            self.data["last_active_session_id"] = None
        
        if not self.data["sessions"]:
            new_sid = str(uuid.uuid4())
            default_session = {
                "id": new_sid, "name": "Default Session", "date": "Bugün", 
                "notes": "", "logs": "", "combatants": []
            }
            self.data["sessions"].append(default_session)
            self.data["last_active_session_id"] = new_sid
        
        if not self.data["last_active_session_id"] and self.data["sessions"]:
            self.data["last_active_session_id"] = self.data["sessions"][-1]["id"]

        self.current_campaign_path = folder
        
        # --- PATH VE VERİ MİGRASYONU ---
        self._fix_absolute_paths()
        
        for eid, ent in self.data["entities"].items():
            old_type = ent.get("type", "NPC")
            if old_type in SCHEMA_MAP: ent["type"] = SCHEMA_MAP[old_type]
            
            attrs = ent.get("attributes", {})
            new_attrs = {}
            for k, v in attrs.items():
                new_key = PROPERTY_MAP.get(k, k)
                new_attrs[new_key] = v
            ent["attributes"] = new_attrs

            default = get_default_entity_structure(ent.get("type", "NPC"))
            for key, val in default.items():
                if key not in ent: ent[key] = val
            
            if not ent.get("images") and ent.get("image_path"):
                ent["images"] = [ent["image_path"]]
        # -------------------------------

        # Güncel halini hızlı formatta kaydet
        self.save_data()
        return True, "Yüklendi"

    def _fix_absolute_paths(self):
        if not self.current_campaign_path: return
        changed = False
        assets_dir = os.path.join(self.current_campaign_path, "assets")
        if not os.path.exists(assets_dir): os.makedirs(assets_dir)

        for eid, ent in self.data["entities"].items():
            new_images = []
            for img_path in ent.get("images", []):
                if os.path.isabs(img_path) and os.path.exists(img_path):
                    rel_path = self.import_image(img_path)
                    if rel_path:
                        new_images.append(rel_path)
                        changed = True
                    else:
                        new_images.append(img_path)
                else:
                    new_images.append(img_path)
            ent["images"] = new_images

            legacy_path = ent.get("image_path")
            if legacy_path and os.path.isabs(legacy_path) and os.path.exists(legacy_path):
                rel_path = self.import_image(legacy_path)
                if rel_path:
                    ent["image_path"] = rel_path
                    changed = True
        
        if changed: print("🔧 Absolute paths fixed and assets copied.")

    def create_campaign(self, world_name):
        folder = os.path.join(WORLDS_DIR, world_name)
        try:
            if not os.path.exists(folder): os.makedirs(folder)
            if not os.path.exists(os.path.join(folder, "assets")): os.makedirs(os.path.join(folder, "assets"))
            first_sid = str(uuid.uuid4())
            self.data = {
                "world_name": world_name, "entities": {}, 
                "map_data": {"image_path": "", "pins": [], "timeline": []},
                "sessions": [{"id": first_sid, "name": "Session 0", "date": "Bugün", "notes": "", "logs": "", "combatants": []}],
                "last_active_session_id": first_sid
            }
            self.current_campaign_path = folder
            self.save_data()
            return True, "Oluşturuldu"
        except Exception as e: return False, str(e)

    def save_data(self):
        """Saves data in MsgPack (.dat) format. Much faster than JSON."""
        if self.current_campaign_path:
            dat_path = os.path.join(self.current_campaign_path, "data.dat")
            try:
                with open(dat_path, "wb") as f:
                    msgpack.pack(self.data, f)
            except Exception as e:
                print(f"CRITICAL SAVE ERROR: {e}")

    def create_session(self, name):
        session_id = str(uuid.uuid4())
        new_session = {"id": session_id, "name": name, "date": "Bugün", "notes": "", "logs": "", "combatants": []}
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
                s["combatants"] = combatants
                self.set_active_session(session_id)
                self.save_data()
                break

    def set_active_session(self, session_id):
        self.data["last_active_session_id"] = session_id

    def get_last_active_session_id(self):
        return self.data.get("last_active_session_id")

    def save_entity(self, eid, data, should_save=True, auto_source_update=True):
        if not eid: 
            eid = str(uuid.uuid4())
        
        if auto_source_update:
            world_name = self.data.get("world_name", "Unknown World")
            current_source = data.get("source", "")
            
            if world_name:
                if not current_source:
                    data["source"] = world_name
                elif world_name not in current_source:
                    data["source"] = f"{current_source} / {world_name}"

        if eid in self.data["entities"]: 
            self.data["entities"][eid].update(data)
        else: 
            self.data["entities"][eid] = data
        
        if should_save:
            self.save_data()
        return eid

    def prepare_entity_from_external(self, data, type_override=None):
        if type_override: data["type"] = type_override
        if not data.get("source"):
            data["source"] = "SRD 5e (2014)" 
        data = self._resolve_dependencies(data)
        return data

    def _resolve_dependencies(self, data):
        if not isinstance(data, dict): return data
        detected_spells = data.pop("_detected_spell_indices", [])
        if detected_spells: self._auto_import_linked_entities(data, detected_spells, "Spell", "spells")
        detected_equip = data.pop("_detected_equipment_indices", [])
        if detected_equip: self._auto_import_linked_entities(data, detected_equip, "Equipment", "equipment_ids")
        return data

    def _auto_import_linked_entities(self, main_data, indices, category, target_list_key):
        if target_list_key not in main_data: main_data[target_list_key] = []
        existing_map = {ent.get("name"): eid for eid, ent in self.data["entities"].items() if ent.get("type") == category}
        for idx in indices:
            success, sub_data = self.fetch_details_from_api(category, idx)
            if success:
                ent_name = sub_data.get("name")
                if ent_name in existing_map: new_id = existing_map[ent_name]
                else: new_id = self.save_entity(None, sub_data, should_save=False, auto_source_update=False); existing_map[ent_name] = new_id
                if new_id not in main_data[target_list_key]: main_data[target_list_key].append(new_id)

    def fetch_details_from_api(self, category, index_name, local_only=False):
        # 1. Kaynak bazlı klasör yapısı (varsayılan dnd5e)
        source_key = self.api_client.current_source_key
        # category names are mapped to folders
        folder_map = {"Monster": "monsters", "NPC": "monsters", "Spell": "spells", "Equipment": "equipment", "Class": "classes", "Race": "races"}
        folder = folder_map.get(category)
        
        if folder:
            # Örnek: cache/library/open5e/monsters/aboleth.json
            base_lib = os.path.join(LIBRARY_DIR, source_key, folder)
            local_path = os.path.join(base_lib, f"{index_name}.json")
            
            # 2. Önce Cache Kontrolü
            if os.path.exists(local_path):
                try:
                    with open(local_path, "r", encoding="utf-8") as f: raw = json.load(f)
                    parsed = self.api_client.parse_dispatcher(category, raw)
                    return True, parsed
                except Exception as e: print(f"DEBUG: Cache Read Error ({index_name}): {e}")
        
        if local_only: return False, "Not in local cache."

        # 3. API'den Çek (get_details ile RAW data al)
        raw_data = self.api_client.get_details(category, index_name)
        
        if raw_data:
            # 4. Cache'e Kaydet
            if folder:
                try:
                    if not os.path.exists(base_lib): os.makedirs(base_lib)
                    with open(local_path, "w", encoding="utf-8") as f:
                        json.dump(raw_data, f, indent=2)
                except Exception as e:
                    print(f"Cache Write Error: {e}")
            
            # 5. Parse Et ve Dön
            parsed_data = self.api_client.parse_dispatcher(category, raw_data)
            return True, parsed_data
            
        return False, tr("MSG_SEARCH_NOT_FOUND")

    def delete_entity(self, eid):
        if eid in self.data["entities"]:
            del self.data["entities"][eid]
            self.save_data()

    def fetch_from_api(self, category, query):
        for eid, ent in self.data["entities"].items():
            if ent["name"].lower() == query.lower() and ent["type"] == category:
                return True, "Veritabanında zaten var.", eid
        success, local_data = self.fetch_details_from_api(category, query)
        if success and local_data:
             if category in ["Monster", "NPC"]: local_data = self._resolve_dependencies(local_data)
             return True, "Cache'den yüklendi.", local_data
        parsed_data, msg = self.api_client.search(category, query)
        if not parsed_data: return False, msg, None
        if category in ["Monster", "NPC"] and isinstance(parsed_data, dict): parsed_data = self._resolve_dependencies(parsed_data)
        return True, "API'den çekildi.", parsed_data

    def import_entity_with_dependencies(self, data, type_override=None):
        if type_override: data["type"] = type_override
        data = self._resolve_dependencies(data)
        return self.save_entity(None, data, auto_source_update=False)

    def import_image(self, src):
        if not self.current_campaign_path: return None
        abs_assets = os.path.abspath(os.path.join(self.current_campaign_path, "assets"))
        abs_src = os.path.abspath(src)
        if abs_src.startswith(abs_assets): return os.path.relpath(abs_src, self.current_campaign_path)
        try:
            fname = f"{uuid.uuid4().hex}_{os.path.basename(src)}"
            dest_dir = os.path.join(self.current_campaign_path, "assets")
            if not os.path.exists(dest_dir): os.makedirs(dest_dir)
            dest = os.path.join(dest_dir, fname)
            shutil.copy2(src, dest)
            return os.path.join("assets", fname)
        except Exception as e: print(f"Image import error: {e}"); return None

    def import_pdf(self, src):
        if not self.current_campaign_path: return None
        abs_assets = os.path.abspath(os.path.join(self.current_campaign_path, "assets"))
        abs_src = os.path.abspath(src)
        if abs_src.startswith(abs_assets): return os.path.relpath(abs_src, self.current_campaign_path)
        try:
            fname = f"{uuid.uuid4().hex}_{os.path.basename(src)}"
            dest = os.path.join(self.current_campaign_path, "assets", fname)
            shutil.copy2(src, dest)
            return os.path.join("assets", fname)
        except Exception: return None

    def get_full_path(self, rel):
        if not rel: return None
        if os.path.isabs(rel): return rel
        base = self.current_campaign_path if self.current_campaign_path else BASE_DIR
        clean_rel = rel.replace("\\", "/")
        full_path = os.path.normpath(os.path.join(base, clean_rel))
        return full_path
    
    # --- MAP & TIMELINE ---
    def set_map_image(self, rel):
        self.data["map_data"]["image_path"] = rel
        self.save_data()
    
    def add_pin(self, x, y, eid, color=None, note=""): 
        pin_data = {"id": str(uuid.uuid4()), "x": x, "y": y, "entity_id": eid, "color": color, "note": note}
        self.data["map_data"]["pins"].append(pin_data)
        self.save_data()
    
    def update_map_pin(self, pin_id, color=None, note=None):
        for p in self.data["map_data"]["pins"]:
            if p.get("id") == pin_id:
                if color is not None: p["color"] = color
                if note is not None: p["note"] = note
                break
        self.save_data()

    def move_pin(self, pid, x, y):
        for p in self.data["map_data"]["pins"]:
             if p.get("id") == pid: p["x"]=x; p["y"]=y; break
        self.save_data()
    
    def remove_specific_pin(self, pid):
        self.data["map_data"]["pins"] = [p for p in self.data["map_data"]["pins"] if p.get("id") != pid]
        self.save_data()

    def add_timeline_pin(self, x, y, day, note, parent_id=None, entity_ids=None, color=None, session_id=None):
        pin = {
            "id": str(uuid.uuid4()),
            "x": x,
            "y": y,
            "day": int(day),
            "note": note,
            "parent_id": parent_id,
            "entity_ids": entity_ids if entity_ids else [],
            "color": color,
            "session_id": session_id
        }
        if "timeline" not in self.data["map_data"]: self.data["map_data"]["timeline"] = []
        self.data["map_data"]["timeline"].append(pin)
        self.data["map_data"]["timeline"].sort(key=lambda k: k['day'])
        self.save_data()

    def remove_timeline_pin(self, pin_id):
        if "timeline" in self.data["map_data"]:
            self.data["map_data"]["timeline"] = [p for p in self.data["map_data"]["timeline"] if p.get("id") != pin_id]
            self.save_data()

    def update_timeline_pin(self, pin_id, day, note, entity_ids, session_id=None):
        if "timeline" in self.data["map_data"]:
            for p in self.data["map_data"]["timeline"]:
                if p["id"] == pin_id:
                    p["day"] = int(day)
                    p["note"] = note
                    p["entity_ids"] = entity_ids
                    p["session_id"] = session_id
                    break
            self.data["map_data"]["timeline"].sort(key=lambda k: k['day'])
            self.save_data()
    
    def update_timeline_pin_visuals(self, pin_id, color=None):
        if "timeline" in self.data["map_data"]:
            for p in self.data["map_data"]["timeline"]:
                if p["id"] == pin_id:
                    if color: p["color"] = color
                    break
            self.save_data()

    def get_timeline_pin(self, pin_id):
        if "timeline" in self.data["map_data"]:
            for p in self.data["map_data"]["timeline"]:
                if p["id"] == pin_id: return p
        return None

    def update_timeline_chain_color(self, start_pin_id, color):
        if "timeline" not in self.data["map_data"]: return
        timeline = self.data["map_data"]["timeline"]
        adjacency = {p["id"]: [] for p in timeline}
        for p in timeline:
            pid = p["id"]; parent = p.get("parent_id")
            if parent and parent in adjacency:
                adjacency[pid].append(parent); adjacency[parent].append(pid)
        connected_ids = set(); queue = [start_pin_id]
        while queue:
            current = queue.pop(0)
            if current in connected_ids: continue
            connected_ids.add(current)
            if current in adjacency:
                for neighbor in adjacency[current]:
                    if neighbor not in connected_ids: queue.append(neighbor)
        for p in timeline:
            if p["id"] in connected_ids: p["color"] = color
        self.save_data()

    def move_timeline_pin(self, pin_id, x, y):
        if "timeline" in self.data["map_data"]:
            for p in self.data["map_data"]["timeline"]:
                if p["id"] == pin_id:
                    p["x"] = x; p["y"] = y; break
            self.save_data()

    def search_in_library(self, category, search_text):
        results = []
        search_text = search_text.lower()
        cats = [category] if category in self.reference_cache else list(self.reference_cache.keys())
        for c in cats:
            for item in self.reference_cache.get(c, []):
                if len(search_text) < 2 or search_text in item["name"].lower():
                    results.append({"id": f"lib_{c}_{item['index']}", "name": item["name"], "type": c, "is_library": True, "index": item["index"]})
        return results
    
    def get_all_entity_mentions(self):
        """@ menüsü için tüm varlıkların isim ve ID'lerini döner."""
        mentions = []
        for eid, ent in self.data["entities"].items():
            mentions.append({"id": eid, "name": ent["name"], "type": ent["type"]})
        return mentions