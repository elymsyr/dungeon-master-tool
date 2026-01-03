import os
import json
import shutil
import uuid
from config import WORLDS_DIR
from core.models import get_default_entity_structure
from core.api_client import DndApiClient

# Cache klasörü ana dizinde olsun
CACHE_DIR = "cache"
CACHE_FILE = os.path.join(CACHE_DIR, "reference_indexes.json")

class DataManager:
    def __init__(self):
        self.current_campaign_path = None
        self.data = {"world_name": "", "entities": {}, "map_data": {"image_path": "", "pins": []}}
        self.api_client = DndApiClient()
        self.reference_cache = {} # Bellekteki cache
        
        if not os.path.exists(WORLDS_DIR): os.makedirs(WORLDS_DIR)
        self._load_reference_cache()

    def _load_reference_cache(self):
        """Global cache dosyasını yükle"""
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
        """Global cache dosyasına yaz"""
        if not os.path.exists(CACHE_DIR): os.makedirs(CACHE_DIR)
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(self.reference_cache, f, indent=4)

    def get_api_index(self, category):
        """
        Kategori listesini (örn: tüm büyüler) getirir.
        Önce cache'e bakar, yoksa API'den çeker ve kaydeder.
        """
        # Cache'de var mı?
        if category in self.reference_cache:
            return self.reference_cache[category]
        
        # Yoksa API'den çek
        print(f"API'den liste çekiliyor: {category}...")
        data = self.api_client.get_list(category)
        
        if data:
            self.reference_cache[category] = data
            self._save_reference_cache()
            return data
        return []

    # --- ESKİ METODLAR (Aynen kalıyor, kısaltıldı) ---
    def get_available_campaigns(self):
        if not os.path.exists(WORLDS_DIR): return []
        return [d for d in os.listdir(WORLDS_DIR) if os.path.isdir(os.path.join(WORLDS_DIR, d))]

    def create_campaign(self, world_name):
        folder = os.path.join(WORLDS_DIR, world_name)
        try:
            if not os.path.exists(folder): os.makedirs(folder)
            if not os.path.exists(os.path.join(folder, "assets")): os.makedirs(os.path.join(folder, "assets"))
            self.data = {"world_name": world_name, "entities": {}, "map_data": {"image_path": "", "pins": []}}
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
            # Migration logic...
            for eid, ent in self.data["entities"].items():
                if "attributes" not in ent: ent["attributes"] = {}
                if "tags" not in ent: ent["tags"] = []
            self.current_campaign_path = folder
            return True, "Yüklendi"
        except Exception as e: return False, str(e)

    def save_data(self):
        if self.current_campaign_path:
            with open(os.path.join(self.current_campaign_path, "data.json"), "w", encoding="utf-8") as f:
                json.dump(self.data, f, indent=4, ensure_ascii=False)

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

    def fetch_details_from_api(self, category, index_name):
        """
        Listeden seçilen spesifik varlığın (index_name) detaylarını çeker.
        """
        # index_name API slug formatındadır (örn: 'acid-arrow')
        parsed_data, msg = self.api_client.search(category, index_name)
        if parsed_data:
            # Hemen kaydetmek yerine döndür, kullanıcı onaylasın veya UI göstersin
            return True, parsed_data
        return False, msg

    def import_image(self, src):
        if not self.current_campaign_path: return None
        fname = f"{uuid.uuid4().hex}_{os.path.basename(src)}"
        dest = os.path.join(self.current_campaign_path, "assets", fname)
        shutil.copy2(src, dest)
        return os.path.join("assets", fname)

    def get_full_path(self, rel):
        return os.path.join(self.current_campaign_path, rel) if self.current_campaign_path and rel else None
    
    def set_map_image(self, rel):
        self.data["map_data"]["image_path"] = rel; self.save_data()
    
    def add_pin(self, x, y, eid):
        self.data["map_data"]["pins"].append({"id": str(uuid.uuid4()), "x": x, "y": y, "entity_id": eid}); self.save_data()
        
    def move_pin(self, pid, x, y):
        for p in self.data["map_data"]["pins"]:
             if p.get("id") == pid: p["x"]=x; p["y"]=y; break
        self.save_data()
        
    def remove_specific_pin(self, pid):
        self.data["map_data"]["pins"] = [p for p in self.data["map_data"]["pins"] if p.get("id") != pid]
        self.save_data()