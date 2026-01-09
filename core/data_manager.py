
import time
import uuid
import os
import json
import shutil
import uuid
from config import WORLDS_DIR, BASE_DIR, CACHE_DIR, load_theme
from core.models import get_default_entity_structure, SCHEMA_MAP, PROPERTY_MAP, ENTITY_SCHEMAS
from core.api_client import DndApiClient
from core.locales import set_language

LIBRARY_DIR = os.path.join(CACHE_DIR, "library")
CACHE_FILE = os.path.join(CACHE_DIR, "reference_indexes.json")

class DataManager:
    def __init__(self):
        self.settings = self.load_settings()
        set_language(self.settings.get("language", "EN"))
        self.current_theme = self.settings.get("theme", "dark")
        
        self.current_campaign_path = None
        
        self.data = {
            "world_name": "", 
            "entities": {}, 
            "map_data": {"image_path": "", "pins": []},
            "sessions": [],
            "last_active_session_id": None
        }
        self.api_client = DndApiClient()
        self.reference_cache = {}
        
        if not os.path.exists(WORLDS_DIR): os.makedirs(WORLDS_DIR)
        
        self.reload_library_cache()

    def reload_library_cache(self):
        if not os.path.exists(CACHE_DIR): os.makedirs(CACHE_DIR)
        if os.path.exists(CACHE_FILE):
            try:
                with open(CACHE_FILE, "r", encoding="utf-8") as f: 
                    self.reference_cache = json.load(f)
            except: 
                self.reference_cache = {}
        else: 
            self.reference_cache = {}

    def _save_reference_cache(self):
        if not os.path.exists(CACHE_DIR): os.makedirs(CACHE_DIR)
        with open(CACHE_FILE, "w", encoding="utf-8") as f: 
            json.dump(self.reference_cache, f, indent=4)

    def load_settings(self):
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

    def get_api_index(self, category):
        if category in self.reference_cache: return self.reference_cache[category]
        data = self.api_client.get_list(category)
        if data:
            self.reference_cache[category] = data
            self._save_reference_cache()
            return data
        return []

    def get_available_campaigns(self):
        if not os.path.exists(WORLDS_DIR): return []
        return [d for d in os.listdir(WORLDS_DIR) if os.path.isdir(os.path.join(WORLDS_DIR, d))]

    def load_campaign_by_name(self, name):
        return self.load_campaign(os.path.join(WORLDS_DIR, name))

    def load_campaign(self, folder):
        path = os.path.join(folder, "data.json")
        if not os.path.exists(path): return False, "Dosya yok"
        try:
            with open(path, "r", encoding="utf-8") as f: self.data = json.load(f)
            
            if "sessions" not in self.data: self.data["sessions"] = []
            if "entities" not in self.data: self.data["entities"] = {}
            if "map_data" not in self.data: self.data["map_data"] = {"image_path": "", "pins": []}
            if "last_active_session_id" not in self.data: self.data["last_active_session_id"] = None
            
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
                # Tip güncellemesi (Eski Türkçe tipleri İngilizceye çevir)
                old_type = ent.get("type", "NPC")
                if old_type in SCHEMA_MAP: ent["type"] = SCHEMA_MAP[old_type]
                
                # Attribute key güncellemesi
                attrs = ent.get("attributes", {})
                new_attrs = {}
                for k, v in attrs.items():
                    new_key = PROPERTY_MAP.get(k, k)
                    new_attrs[new_key] = v
                ent["attributes"] = new_attrs

                # --- KRİTİK NOKTA: Eksik alanları tamamla ---
                # get_default_entity_structure içinde "dm_notes" var.
                # Aşağıdaki döngü, mevcut entity'de "dm_notes" yoksa ekler.
                default = get_default_entity_structure(ent.get("type", "NPC"))
                for key, val in default.items():
                    if key not in ent: ent[key] = val
                
                # Resim path güncellemesi
                if not ent.get("images") and ent.get("image_path"):
                    ent["images"] = [ent["image_path"]]
            # -------------------------------

            self.save_data()
            return True, "Yüklendi"
        except Exception as e: return False, str(e)

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
                "map_data": {"image_path": "", "pins": []},
                "sessions": [{"id": first_sid, "name": "Session 0", "date": "Bugün", "notes": "", "logs": "", "combatants": []}],
                "last_active_session_id": first_sid
            }
            self.current_campaign_path = folder
            self.save_data()
            return True, "Oluşturuldu"
        except Exception as e: return False, str(e)

    def save_data(self):
        if self.current_campaign_path:
            with open(os.path.join(self.current_campaign_path, "data.json"), "w", encoding="utf-8") as f:
                json.dump(self.data, f, indent=4, ensure_ascii=False)

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
                s["notes"] = notes; s["logs"] = logs; s["combatants"] = combatants
                self.set_active_session(session_id)
                self.save_data()
                break

    def set_active_session(self, session_id): self.data["last_active_session_id"] = session_id
    def get_last_active_session_id(self): return self.data.get("last_active_session_id")

    def save_entity(self, eid, data, should_save=True):
        """
        Varlığı kaydeder. 
        should_save=False yapılırsa sadece belleğe yazar, diske (data.json) yazmaz.
        Bu, toplu işlemlerde (örn: yaratıkla gelen 20 büyüyü eklerken) hızı artırır.
        """
        if not eid: 
            eid = str(uuid.uuid4())
        
        if eid in self.data["entities"]: 
            self.data["entities"][eid].update(data)
        else: 
            self.data["entities"][eid] = data
        
        if should_save:
            self.save_data()
        return eid

# core/data_manager.py içinde ilgili kısımları bulun ve değiştirin:

    def _resolve_dependencies(self, data):
        if not isinstance(data, dict): return data
        
        # 1. RESİM İNDİRME VE CACHE'E KAYDETME
        remote_url = data.pop("_remote_image_url", None)
        if remote_url:
            # Resmin kaydedileceği yer: cache/library/images/
            library_img_dir = os.path.join(LIBRARY_DIR, "images")
            if not os.path.exists(library_img_dir): os.makedirs(library_img_dir)
            
            # Dosya adı oluştur (index veya isimden)
            safe_name = "".join([c for c in data.get("name", "img") if c.isalnum()]).lower()
            ext = ".jpg" if ".jpg" in remote_url.lower() else ".png"
            filename = f"{safe_name}{ext}"
            full_lib_path = os.path.join(library_img_dir, filename)
            
            # Eğer kütüphane cache'inde yoksa indir
            if not os.path.exists(full_lib_path):
                img_bytes = self.api_client.download_image_bytes(remote_url)
                if img_bytes:
                    with open(full_lib_path, "wb") as f: f.write(img_bytes)
            
            # Şimdi bu resmi kampanya klasörüne (worlds/X/assets) kopyala (aktif kullanım için)
            if self.current_campaign_path and os.path.exists(full_lib_path):
                rel_path = self.import_image(full_lib_path) # Mevcut kopyalama mantığını kullanır
                data["image_path"] = rel_path
                data["images"] = [rel_path]

        # 2. BÜYÜLERİ ÇEK VE LOKAL VERİTABANINA (CAMPAIGN) EKLE
        detected_spells = data.pop("_detected_spell_indices", [])
        if detected_spells:
            linked_ids = []
            for s_idx in detected_spells:
                # Önce kütüphaneye bak, yoksa internetten indir ve kütüphaneye de kaydet
                success, spell_data = self.fetch_details_from_api("Spell", s_idx)
                if success:
                    # Kampanyada var mı kontrol et
                    existing_id = None
                    for eid, ent in self.data["entities"].items():
                        if ent.get("name") == spell_data["name"] and ent.get("type") == "Spell":
                            existing_id = eid; break
                    
                    if existing_id: linked_ids.append(existing_id)
                    else:
                        new_id = self.save_entity(None, spell_data, should_save=False)
                        linked_ids.append(new_id)
            
            if linked_ids:
                if "spells" not in data: data["spells"] = []
                for sid in linked_ids:
                    if sid not in data["spells"]: data["spells"].append(sid)

        return data

    def fetch_details_from_api(self, category, index_name, local_only=False):
        """
        Kütüphane verisini çeker. 
        local_only=True ise asla internete çıkmaz, sadece yerel 'cache/library' klasörüne bakar.
        """
        fetch_start = time.perf_counter()
        
        folder_map = {
            "Monster": "monsters", "NPC": "monsters", "Spell": "spells", 
            "Equipment": "equipment", "Class": "classes", "Race": "races"
        }
        folder = folder_map.get(category)
        
        # 1. YEREL CACHE KONTROLÜ
        if folder:
            paths = [os.path.join(LIBRARY_DIR, folder, f"{index_name}.json")]
            if category == "Equipment":
                paths.append(os.path.join(LIBRARY_DIR, "magic-items", f"{index_name}.json"))
            
            for local_path in paths:
                if os.path.exists(local_path):
                    try:
                        with open(local_path, "r", encoding="utf-8") as f:
                            raw = json.load(f)
                        parsed = self.api_client.parse_dispatcher(category, raw)
                        return True, parsed
                    except Exception as e:
                        print(f"DEBUG: Cache Read Error ({index_name}): {e}")

        # 2. İNTERNET FALLBACK
        if local_only:
            return False, "Not in local cache."

        # İnternetten çek (local_only=False ise buraya düşer)
        parsed_data, msg = self.api_client.search(category, index_name)
        if parsed_data:
            return True, parsed_data
            
        return False, msg

    def delete_entity(self, eid):
        if eid in self.data["entities"]:
            del self.data["entities"][eid]
            self.save_data()

    def fetch_from_api(self, category, query):
        # 1. Check existing active entities
        for eid, ent in self.data["entities"].items():
            if ent["name"].lower() == query.lower() and ent["type"] == category:
                return True, "Veritabanında zaten var.", eid
        
        # 2. Try to fetch from local Library Cache first
        # This prevents "Category not supported" if API is down and speeds up loading
        success, local_data = self.fetch_details_from_api(category, query)
        if success and local_data:
             # Resolve dependencies (spells, images) for local data too
             if category in ["Monster", "NPC"]:
                 local_data = self._resolve_dependencies(local_data)
             return True, "Cache'den yüklendi.", local_data

        # 3. Fallback to Internet API
        parsed_data, msg = self.api_client.search(category, query)
        if not parsed_data: return False, msg, None
        
        if category in ["Monster", "NPC"] and isinstance(parsed_data, dict):
            parsed_data = self._resolve_dependencies(parsed_data)
            
        return True, "API'den çekildi.", parsed_data

    def import_entity_with_dependencies(self, data, type_override=None):
        if type_override: data["type"] = type_override
        data = self._resolve_dependencies(data)
        return self.save_entity(None, data)

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
        """Relative yolu Absolute yola çevirir."""
        if not rel: return None
        if os.path.isabs(rel): return rel
        
        # Eğer kampanya seçilmediyse ana assets'e bak
        base = self.current_campaign_path if self.current_campaign_path else BASE_DIR
        
        # Yoldaki ters/düz slaşları normalize et (Windows/Linux uyumu)
        clean_rel = rel.replace("\\", "/")
        full_path = os.path.normpath(os.path.join(base, clean_rel))
        
        return full_path
    
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
                if len(search_text) < 2 or search_text in item["name"].lower():
                    results.append({"id": f"lib_{c}_{item['index']}", "name": item["name"], "type": c, "is_library": True, "index": item["index"]})
        return results