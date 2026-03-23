import logging
import os
import shutil
import uuid

import msgpack

from config import BASE_DIR, CACHE_DIR, WORLDS_DIR, probe_write_access
from core.api_client import DndApiClient
from core.locales import tr
from core.campaign_manager import CampaignManager
from core.entity_repository import EntityRepository
from core.library_manager import LibraryManager
from core.map_data_manager import MapDataManager
from core.session_repository import SessionRepository
from core.settings_manager import SettingsManager

logger = logging.getLogger(__name__)

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

        self._library_mgr = LibraryManager(
            cache_dir=CACHE_DIR,
            api_client=self.api_client,
        )

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
        self._campaign_mgr = CampaignManager(
            worlds_dir=WORLDS_DIR,
            on_data_loaded=self._on_campaign_data_loaded,
            save_callback=self.save_data,
            import_image=self.import_image,
            get_campaign_path=lambda: self.current_campaign_path,
        )

        if not os.path.exists(WORLDS_DIR):
            os.makedirs(WORLDS_DIR)

    # ------------------------------------------------------------------
    # Backward-compat properties for library state attributes
    # ------------------------------------------------------------------

    @property
    def reference_cache(self) -> dict:
        return self._library_mgr.reference_cache

    @property
    def library_tree(self) -> dict:
        return self._library_mgr.library_tree

    @property
    def library_migration_report(self) -> dict:
        return self._library_mgr.library_migration_report

    # ------------------------------------------------------------------
    # Library delegates
    # ------------------------------------------------------------------

    def reload_library_cache(self) -> None:
        """Delegates to LibraryManager.reload_library_cache."""
        self._library_mgr.reload_library_cache()

    def refresh_library_catalog(self) -> None:
        """Delegates to LibraryManager.refresh_library_catalog."""
        self._library_mgr.refresh_library_catalog()

    def search_library_catalog(self, query: str, normalized_categories: set | None = None, source: str | None = None) -> list:
        """Delegates to LibraryManager.search_library_catalog."""
        return self._library_mgr.search_library_catalog(query, normalized_categories=normalized_categories, source=source)

    def load_settings(self) -> dict:
        """Returns the current settings dict (delegates to SettingsManager)."""
        return self._settings_mgr.settings

    def save_settings(self, settings: dict) -> None:
        """Merges *settings* into persisted settings (delegates to SettingsManager)."""
        self._settings_mgr.save(settings)
        self.settings = self._settings_mgr.settings
        self.current_theme = self._settings_mgr.current_theme

    def get_api_index(self, category: str, page: int = 1, filters: dict | None = None) -> dict | list:
        """Delegates to LibraryManager.get_api_index."""
        return self._library_mgr.get_api_index(category, page=page, filters=filters)

    def _on_campaign_data_loaded(self, data: dict, path: str) -> None:
        """Callback invoked by CampaignManager to update data and path on this instance."""
        self.data = data
        self.current_campaign_path = path

    def get_available_campaigns(self) -> list[str]:
        """Delegates to CampaignManager.get_available."""
        return self._campaign_mgr.get_available()

    def load_campaign_by_name(self, name: str) -> tuple[bool, str]:
        """Delegates to CampaignManager.load_by_name."""
        return self._campaign_mgr.load_by_name(name)

    def load_campaign(self, folder: str) -> tuple[bool, str]:
        """Delegates to CampaignManager.load."""
        return self._campaign_mgr.load(folder)

    def create_campaign(self, world_name: str) -> tuple[bool, str]:
        """Delegates to CampaignManager.create."""
        return self._campaign_mgr.create(world_name)

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
        """Delegates to LibraryManager.fetch_details_from_api."""
        return self._library_mgr.fetch_details_from_api(category, index_name, local_only=local_only)

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
        """Delegates to LibraryManager.search_in_library."""
        return self._library_mgr.search_in_library(category, search_text)
    
    def get_all_entity_mentions(self) -> list[dict]:
        """Delegates to EntityRepository.get_all_mentions."""
        return self._entity_repo.get_all_mentions()
