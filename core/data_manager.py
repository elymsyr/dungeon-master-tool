import json
import logging
import os
import shutil
import time
import uuid

import msgpack

from config import BASE_DIR, CACHE_DIR, WORLDS_DIR, load_theme, probe_write_access
from core.api_client import DndApiClient
from core.library_fs import migrate_legacy_layout, scan_library_tree, search_library_tree
from core.locales import tr
from core.models import PROPERTY_MAP, SCHEMA_MAP, get_default_entity_structure
from core.entity_repository import EntityRepository
from core.map_data_manager import MapDataManager
from core.session_repository import SessionRepository
from core.settings_manager import SettingsManager

logger = logging.getLogger(__name__)

LIBRARY_DIR = os.path.join(CACHE_DIR, "library")
# We will use .dat (MsgPack) for library cache, but .json support remains
CACHE_FILE_JSON = os.path.join(CACHE_DIR, "reference_indexes.json")
CACHE_FILE_DAT = os.path.join(CACHE_DIR, "reference_indexes.dat")

class DataManager:
    def __init__(self):
        self._settings_mgr = SettingsManager(CACHE_DIR)
        self.settings = self._settings_mgr.settings
        self.current_theme = self._settings_mgr.current_theme
        
        self.current_campaign_path = None
        
        self.data = {
            "world_name": "", 
            "entities": {}, 
            "map_data": {"image_path": "", "pins": [], "timeline": []},
            "sessions": [],
            "last_active_session_id": None,
            "mind_maps": {}  # NEW: field for Mind Map data
        }
        self.api_client = DndApiClient()
        self.reference_cache = {}
        self.library_tree = {}
        self.library_migration_report = {}

        self._entity_repo = EntityRepository(
            get_data=lambda: self.data,
            save_callback=self.save_data,
            fetch_details=self.fetch_details_from_api,
            get_world_name=lambda: self.data.get("world_name", tr("NAME_UNKNOWN")),
        )
        self._session_repo = SessionRepository(
            get_data=lambda: self.data,
            save_callback=self.save_data,
        )
        self._map_mgr = MapDataManager(
            get_data=lambda: self.data,
            save_callback=self.save_data,
        )

        if not os.path.exists(WORLDS_DIR):
            os.makedirs(WORLDS_DIR)

        self.reload_library_cache()

    def reload_library_cache(self) -> None:
        """Loads library index. Tries fast format (.dat) first."""
        if not os.path.exists(CACHE_DIR):
            os.makedirs(CACHE_DIR)

        self.reference_cache = {}
        
        # 1. Fast format available?
        if os.path.exists(CACHE_FILE_DAT):
            try:
                with open(CACHE_FILE_DAT, "rb") as f:
                    # raw=False: Load as String instead of Byte
                    self.reference_cache = msgpack.unpack(f, raw=False)
            except Exception as e:
                logger.error("Cache DAT load error: %s", e)
                self.reference_cache = {}

        # 2. Fall back to JSON if DAT is missing or stale
        if not self.reference_cache and os.path.exists(CACHE_FILE_JSON):
            try:
                with open(CACHE_FILE_JSON, "r", encoding="utf-8") as f:
                    self.reference_cache = json.load(f)
                self._save_reference_cache()
            except Exception:
                self.reference_cache = {}

        self.refresh_library_catalog()

    def _save_reference_cache(self):
        """Saves the library index as MsgPack (.dat)."""
        if not os.path.exists(CACHE_DIR): os.makedirs(CACHE_DIR)
        try:
            with open(CACHE_FILE_DAT, "wb") as f: 
                msgpack.pack(self.reference_cache, f)
        except Exception as e:
            logger.error("Cache save error: %s", e)

    def refresh_library_catalog(self) -> None:
        """Migrates legacy cache layout and refreshes in-memory file catalog."""
        try:
            self.library_migration_report = migrate_legacy_layout(CACHE_DIR, default_source="dnd5e")
        except Exception as e:
            self.library_migration_report = {"errors": [str(e)]}
            logger.error("Library migration error: %s", e)

        try:
            self.library_tree = scan_library_tree(CACHE_DIR, default_source="dnd5e")
        except Exception as e:
            self.library_tree = {}
            logger.error("Library scan error: %s", e)

    def search_library_catalog(self, query: str, normalized_categories: set | None = None, source: str | None = None) -> list:
        """Searches local offline library files from canonical+legacy cache folders."""
        if not self.library_tree:
            self.refresh_library_catalog()
        return search_library_tree(
            self.library_tree,
            query=query,
            normalized_categories=normalized_categories,
            source=source,
        )

    def load_settings(self) -> dict:
        """Returns the current settings dict (delegates to SettingsManager)."""
        return self._settings_mgr.settings

    def save_settings(self, settings: dict) -> None:
        """Merges *settings* into persisted settings (delegates to SettingsManager)."""
        self._settings_mgr.save(settings)
        self.settings = self._settings_mgr.settings
        self.current_theme = self._settings_mgr.current_theme

    def get_api_index(self, category: str, page: int = 1, filters: dict | None = None) -> dict | list:
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
        
        if data_to_cache:
            self.reference_cache[cache_key] = data_to_cache
            self._save_reference_cache()
            return data_to_cache
        return []

    def get_available_campaigns(self) -> list[str]:
        if not os.path.exists(WORLDS_DIR): return []
        return [d for d in os.listdir(WORLDS_DIR) if os.path.isdir(os.path.join(WORLDS_DIR, d))]

    def load_campaign_by_name(self, name: str) -> tuple[bool, str]:
        return self.load_campaign(os.path.join(WORLDS_DIR, name))

    def load_campaign(self, folder: str) -> tuple[bool, str]:
        """
        Loads the campaign.
        Checks .dat (MsgPack) first. If not found, checks .json and converts.
        """
        json_path = os.path.join(folder, "data.json")
        dat_path = os.path.join(folder, "data.dat")
        
        loaded = False
        
        # 1. Try MsgPack (fast format)
        if os.path.exists(dat_path):
            try:
                with open(dat_path, "rb") as f:
                    self.data = msgpack.unpack(f, raw=False)
                loaded = True
            except Exception as e:
                logger.warning("Error loading DAT file, falling back to JSON: %s", e)
        
        # 2. Try JSON if DAT failed or not found
        if not loaded and os.path.exists(json_path):
            try:
                with open(json_path, "r", encoding="utf-8") as f:
                    self.data = json.load(f)
                loaded = True
                # Loaded from JSON: save as DAT for faster loading next time
                self.current_campaign_path = folder
                self.save_data() 
                logger.info(tr("MSG_MIGRATION_CONVERTED"))
            except Exception as e:
                return False, f"JSON Load Error: {str(e)}"

        if not loaded:
            return False, tr("MSG_FILE_NOT_FOUND_DB")

        # --- Data Integrity Checks ---
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
        
        # NEW: Mind Map data structure check
        if "mind_maps" not in self.data:
            self.data["mind_maps"] = {}
        
        if not self.data["sessions"]:
            new_sid = str(uuid.uuid4())
            default_session = {
                "id": new_sid, "name": "Default Session", "date": tr("MSG_TODAY"), 
                "notes": "", "logs": "", "combatants": []
            }
            self.data["sessions"].append(default_session)
            self.data["last_active_session_id"] = new_sid
        
        if not self.data["last_active_session_id"] and self.data["sessions"]:
            self.data["last_active_session_id"] = self.data["sessions"][-1]["id"]

        self.current_campaign_path = folder
        
        # --- PATH AND DATA MIGRATION ---
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

        # Persist the migrated data in fast format
        self.save_data()
        return True, tr("MSG_YUKLENDI")

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
        
        if changed:
            logger.info(tr("MSG_ABSOLUTE_PATHS_FIXED"))

    def create_campaign(self, world_name: str) -> tuple[bool, str]:
        folder = os.path.join(WORLDS_DIR, world_name)
        try:
            if not os.path.exists(folder): os.makedirs(folder)
            if not os.path.exists(os.path.join(folder, "assets")): os.makedirs(os.path.join(folder, "assets"))
            first_sid = str(uuid.uuid4())
            self.data = {
                "world_name": world_name, "entities": {}, 
                "map_data": {"image_path": "", "pins": [], "timeline": []},
                "sessions": [{"id": first_sid, "name": "Session 0", "date": tr("MSG_TODAY"), "notes": "", "logs": "", "combatants": []}],
                "last_active_session_id": first_sid,
                "mind_maps": {}  # NEW
            }
            self.current_campaign_path = folder
            self.save_data()
            return True, tr("MSG_OLUSTURULDU")
        except Exception as e: return False, str(e)

    def save_data(self) -> None:
        """Saves data in MsgPack (.dat) format. Much faster than JSON."""
        if self.current_campaign_path:
            dat_path = os.path.join(self.current_campaign_path, "data.dat")
            try:
                with open(dat_path, "wb") as f:
                    msgpack.pack(self.data, f)
            except Exception as e:
                logger.critical("Save error: %s", e)

    def create_session(self, name: str) -> str:
        """Delegates to SessionRepository.create."""
        return self._session_repo.create(name)

    def get_session(self, session_id: str) -> dict | None:
        """Delegates to SessionRepository.get."""
        return self._session_repo.get(session_id)

    def save_session_data(self, session_id: str, notes: str, logs: str, combatants: list) -> None:
        """Delegates to SessionRepository.save_data."""
        self._session_repo.save_data(session_id, notes, logs, combatants)

    def set_active_session(self, session_id: str) -> None:
        """Delegates to SessionRepository.set_active."""
        self._session_repo.set_active(session_id)

    def get_last_active_session_id(self) -> str | None:
        """Delegates to SessionRepository.get_last_active_id."""
        return self._session_repo.get_last_active_id()

    def save_entity(self, eid: str | None, data: dict, should_save: bool = True, auto_source_update: bool = True) -> str:
        """Delegates to EntityRepository.save (public API preserved for callers)."""
        return self._entity_repo.save(eid, data, should_save=should_save, auto_source_update=auto_source_update)

    def prepare_entity_from_external(self, data: dict, type_override: str | None = None) -> dict:
        """Delegates to EntityRepository.prepare_from_external."""
        return self._entity_repo.prepare_from_external(data, type_override)

    def check_write_permissions(self) -> tuple[bool, str]:
        """Checks if the cache directory is writable."""
        if not probe_write_access(CACHE_DIR):
            return False, tr("MSG_ERR_NO_WRITE_PERMISSION")
        return True, ""

    def fetch_details_from_api(self, category: str, index_name: str, local_only: bool = False) -> tuple[bool, dict | str]:
        # 1. Source-based folder structure (default: dnd5e)
        source_key = self.api_client.current_source_key
        # category names are mapped to folders
        folder_map = {
            "Monster": "monsters", "NPC": "monsters", "Canavar": "monsters",
            "Spell": "spells", "Büyü (Spell)": "spells",
            "Equipment": "equipment", "Eşya (Equipment)": "equipment",
            "Weapon": "weapons", "Armor": "armor",  # additions
            "Class": "classes", "Race": "races",
            "Magic Item": "magic-items", "MagicItem": "magic-items",
            "Feat": "feats", "Condition": "conditions", "Background": "backgrounds"
        }
        folder = folder_map.get(category)
        
        if folder:
            safe_index = str(index_name).lower().replace(" ", "-")
            candidate_bases = [
                os.path.join(LIBRARY_DIR, source_key, folder),  # canonical
                os.path.join(LIBRARY_DIR, folder),              # legacy fallback
            ]
            candidate_names = [f"{index_name}.json", f"{safe_index}.json"]

            # 2. Check cache first (canonical + legacy paths)
            for base_lib in candidate_bases:
                for name in candidate_names:
                    local_path = os.path.join(base_lib, name)
                    if not os.path.exists(local_path):
                        continue
                    try:
                        with open(local_path, "r", encoding="utf-8") as f:
                            raw = json.load(f)
                        parsed = self.api_client.parse_dispatcher(category, raw)
                        return True, parsed
                    except Exception as e:
                        logger.debug("Cache read error (%s): %s", index_name, e)
        
        if local_only: return False, "Not in local cache."

        # 3. Fetch from API (get raw data via get_details)
        raw_data = self.api_client.get_details(category, index_name)
        
        if raw_data:
            # --- METADATA INJECTION ---
            # Embed source info directly into the raw data.
            raw_data["_meta_api_key"] = source_key

            # Build a human-readable source name
            if source_key == "dnd5e":
                raw_data["_meta_source"] = "SRD 5e"
            elif source_key == "open5e":
                # Try to get the Open5e document title; fall back to "Open5e"
                doc_title = raw_data.get("document__title") or raw_data.get("document", {}).get("title", "Open5e")
                raw_data["_meta_source"] = doc_title
            # ---------------------------------
            
            # Return Data Prepare
            parsed_result = self.api_client.parse_dispatcher(category, raw_data)

            if folder:
                # Save to the currently selected source folder
                base_lib = os.path.join(LIBRARY_DIR, source_key, folder)
                try:
                    if not os.path.exists(base_lib): os.makedirs(base_lib)
                    
                    # --- FIX: convert raw_data to dict if it arrived as a string ---
                    save_content = raw_data
                    if isinstance(save_content, str):
                        try: save_content = json.loads(save_content)
                        except json.JSONDecodeError: pass

                    safe_index = index_name.lower().replace(" ", "-")
                    local_path = os.path.join(base_lib, f"{safe_index}.json")
                    
                    # ensure_ascii=False to preserve non-ASCII chars in well-formed JSON
                    with open(local_path, "w", encoding="utf-8") as f:
                        json.dump(save_content, f, indent=2, ensure_ascii=False)
                    logger.debug("Validated and saved to: %s", local_path)
                    self.refresh_library_catalog()
                except Exception as e:
                    logger.error("Cache write error: %s", e)
                    # Add a warning to the result but still return data (avoid crash)
                    if isinstance(parsed_result, dict):
                        parsed_result["_warning"] = tr("MSG_CACHE_WRITE_ERROR")
            
            return True, parsed_result
            
        return False, tr("MSG_SEARCH_NOT_FOUND")

    def delete_entity(self, eid: str) -> None:
        """Delegates to EntityRepository.delete (public API preserved for callers)."""
        self._entity_repo.delete(eid)

    def fetch_from_api(self, category: str, query: str) -> tuple[bool, str, dict | str | None]:
        for eid, ent in self.data["entities"].items():
            if ent.get("name", "").lower() == query.lower() and ent.get("type") == category:
                return True, tr("MSG_DATABASE_EXISTS"), eid
        success, local_data = self.fetch_details_from_api(category, query)
        if success and local_data:
            if category in ["Monster", "NPC"]:
                local_data = self._entity_repo._resolve_dependencies(local_data)

            # Pass along any cache write warning
            msg = tr("MSG_LOADED_FROM_CACHE")
            if isinstance(local_data, dict) and "_warning" in local_data:
                msg += f"\n({local_data.pop('_warning')})"

            return True, msg, local_data

        parsed_data, msg = self.api_client.search(category, query)
        if not parsed_data:
            return False, msg, None
        if category in ["Monster", "NPC"] and isinstance(parsed_data, dict):
            parsed_data = self._entity_repo._resolve_dependencies(parsed_data)
        return True, tr("MSG_FETCHED_FROM_API"), parsed_data

    def import_entity_with_dependencies(self, data: dict, type_override: str | None = None) -> str:
        """Delegates to EntityRepository.import_with_dependencies."""
        return self._entity_repo.import_with_dependencies(data, type_override)

    def import_image(self, src: str) -> str | None:
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
        except Exception as e:
            logger.error("Image import error: %s", e)
            return None

    def import_pdf(self, src: str) -> str | None:
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

    def get_full_path(self, rel: str | None) -> str | None:
        if not rel: return None
        if os.path.isabs(rel): return rel
        base = self.current_campaign_path if self.current_campaign_path else BASE_DIR
        clean_rel = rel.replace("\\", "/")
        full_path = os.path.normpath(os.path.join(base, clean_rel))
        return full_path
    
    # --- MAP & TIMELINE (delegated to MapDataManager) ---
    def set_map_image(self, rel: str) -> None:
        self._map_mgr.set_map_image(rel)

    def add_pin(self, x: float, y: float, eid: str, color: str | None = None, note: str = "") -> None:
        self._map_mgr.add_pin(x, y, eid, color=color, note=note)

    def update_map_pin(self, pin_id: str, color: str | None = None, note: str | None = None) -> None:
        self._map_mgr.update_map_pin(pin_id, color=color, note=note)

    def move_pin(self, pid: str, x: float, y: float) -> None:
        self._map_mgr.move_pin(pid, x, y)

    def remove_specific_pin(self, pid: str) -> None:
        self._map_mgr.remove_specific_pin(pid)

    def add_timeline_pin(self, x: float, y: float, day: int, note: str, parent_id: str | None = None, entity_ids: list | None = None, color: str | None = None, session_id: str | None = None) -> None:
        self._map_mgr.add_timeline_pin(x, y, day, note, parent_id=parent_id, entity_ids=entity_ids, color=color, session_id=session_id)

    def remove_timeline_pin(self, pin_id: str) -> None:
        self._map_mgr.remove_timeline_pin(pin_id)

    def update_timeline_pin(self, pin_id: str, day: int, note: str, entity_ids: list, session_id: str | None = None) -> None:
        self._map_mgr.update_timeline_pin(pin_id, day, note, entity_ids, session_id=session_id)

    def update_timeline_pin_visuals(self, pin_id: str, color: str | None = None) -> None:
        self._map_mgr.update_timeline_pin_visuals(pin_id, color=color)

    def get_timeline_pin(self, pin_id: str) -> dict | None:
        return self._map_mgr.get_timeline_pin(pin_id)

    def update_timeline_chain_color(self, start_pin_id: str, color: str) -> None:
        self._map_mgr.update_timeline_chain_color(start_pin_id, color)

    def move_timeline_pin(self, pin_id: str, x: float, y: float) -> None:
        self._map_mgr.move_timeline_pin(pin_id, x, y)

    def search_in_library(self, category: str, search_text: str) -> list[dict]:
        normalized = None
        if category:
            normalized = {str(category).lower().rstrip("s")}

        rows = self.search_library_catalog(
            query=search_text,
            normalized_categories=normalized,
        )

        results = []
        for row in rows:
            results.append(
                {
                    "id": f"lib_{row['category']}_{row['index']}",
                    "name": row["display_name"],
                    "type": row["category"],
                    "is_library": True,
                    "index": row["index"],
                    "source": row["source"],
                    "path": row["path"],
                }
            )
        return results
    
    def get_all_entity_mentions(self) -> list[dict]:
        """Delegates to EntityRepository.get_all_mentions."""
        return self._entity_repo.get_all_mentions()
