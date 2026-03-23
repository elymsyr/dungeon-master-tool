"""Library cache management and API delegation for the Dungeon Master Tool."""

from __future__ import annotations

import json
import logging
import os
from typing import Any

import msgpack

from core.library_fs import migrate_legacy_layout, scan_library_tree, search_library_tree
from core.locales import tr

logger = logging.getLogger(__name__)


class LibraryManager:
    """Manages the offline library cache, API index, and entity fetch/parse logic.

    Owns the reference_cache, library_tree, and library_migration_report state
    that previously lived on DataManager.
    """

    def __init__(
        self,
        cache_dir: str,
        api_client: Any,
    ) -> None:
        self._cache_dir = cache_dir
        self._library_dir = os.path.join(cache_dir, "library")
        self._cache_file_dat = os.path.join(cache_dir, "reference_indexes.dat")
        self._cache_file_json = os.path.join(cache_dir, "reference_indexes.json")
        self.api_client = api_client

        self.reference_cache: dict[str, Any] = {}
        self.library_tree: dict[str, Any] = {}
        self.library_migration_report: dict[str, Any] = {}

        self.reload_library_cache()

    # ------------------------------------------------------------------
    # Cache I/O
    # ------------------------------------------------------------------

    def reload_library_cache(self) -> None:
        """Load the library index.  Tries fast format (.dat) first."""
        os.makedirs(self._cache_dir, exist_ok=True)
        self.reference_cache = {}

        if os.path.exists(self._cache_file_dat):
            try:
                with open(self._cache_file_dat, "rb") as f:
                    self.reference_cache = msgpack.unpack(f, raw=False)
            except Exception as e:
                logger.error("Cache DAT load error: %s", e)
                self.reference_cache = {}

        if not self.reference_cache and os.path.exists(self._cache_file_json):
            try:
                with open(self._cache_file_json, "r", encoding="utf-8") as f:
                    self.reference_cache = json.load(f)
                self._save_reference_cache()
            except Exception:
                self.reference_cache = {}

        self.refresh_library_catalog()

    def _save_reference_cache(self) -> None:
        """Persist the reference cache as MsgPack (.dat)."""
        os.makedirs(self._cache_dir, exist_ok=True)
        try:
            with open(self._cache_file_dat, "wb") as f:
                msgpack.pack(self.reference_cache, f)
        except Exception as e:
            logger.error("Cache save error: %s", e)

    def refresh_library_catalog(self) -> None:
        """Migrate legacy cache layout and refresh the in-memory file catalog."""
        try:
            self.library_migration_report = migrate_legacy_layout(
                self._cache_dir, default_source="dnd5e"
            )
        except Exception as e:
            self.library_migration_report = {"errors": [str(e)]}
            logger.error("Library migration error: %s", e)

        try:
            self.library_tree = scan_library_tree(self._cache_dir, default_source="dnd5e")
        except Exception as e:
            self.library_tree = {}
            logger.error("Library scan error: %s", e)

    def search_library_catalog(
        self,
        query: str,
        normalized_categories: set[str] | None = None,
        source: str | None = None,
    ) -> list[dict[str, Any]]:
        """Search offline library files from canonical and legacy cache folders."""
        if not self.library_tree:
            self.refresh_library_catalog()
        return search_library_tree(
            self.library_tree,
            query=query,
            normalized_categories=normalized_categories,
            source=source,
        )

    # ------------------------------------------------------------------
    # API index
    # ------------------------------------------------------------------

    def get_api_index(
        self,
        category: str,
        page: int = 1,
        filters: dict[str, str] | None = None,
    ) -> dict[str, Any] | list:
        """Return the API index for *category*, using the reference cache."""
        source = self.api_client.current_source_key
        filter_str = str(sorted(filters.items())) if filters else ""
        cache_key = f"{source}_{category}_p{page}_{hash(filter_str)}"

        if cache_key in self.reference_cache:
            return self.reference_cache[cache_key]

        response = self.api_client.get_list(category, page=page, filters=filters)
        if response:
            self.reference_cache[cache_key] = response
            self._save_reference_cache()
            return response
        return []

    # ------------------------------------------------------------------
    # Entity fetch
    # ------------------------------------------------------------------

    def fetch_details_from_api(
        self,
        category: str,
        index_name: str,
        local_only: bool = False,
    ) -> tuple[bool, dict[str, Any] | str]:
        """Look up *index_name* in the local cache; fetch from API if missing."""
        source_key = self.api_client.current_source_key
        folder_map = {
            "Monster": "monsters", "NPC": "monsters", "Canavar": "monsters",
            "Spell": "spells", "Büyü (Spell)": "spells",
            "Equipment": "equipment", "Eşya (Equipment)": "equipment",
            "Weapon": "weapons", "Armor": "armor",
            "Class": "classes", "Race": "races",
            "Magic Item": "magic-items", "MagicItem": "magic-items",
            "Feat": "feats", "Condition": "conditions", "Background": "backgrounds",
        }
        folder = folder_map.get(category)

        if folder:
            safe_index = str(index_name).lower().replace(" ", "-")
            candidate_bases = [
                os.path.join(self._library_dir, source_key, folder),
                os.path.join(self._library_dir, folder),
            ]
            candidate_names = [f"{index_name}.json", f"{safe_index}.json"]

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

        if local_only:
            return False, "Not in local cache."

        raw_data = self.api_client.get_details(category, index_name)

        if raw_data:
            raw_data["_meta_api_key"] = source_key
            if source_key == "dnd5e":
                raw_data["_meta_source"] = "SRD 5e"
            elif source_key == "open5e":
                doc_title = (
                    raw_data.get("document__title")
                    or raw_data.get("document", {}).get("title", "Open5e")
                )
                raw_data["_meta_source"] = doc_title

            parsed_result = self.api_client.parse_dispatcher(category, raw_data)

            if folder:
                base_lib = os.path.join(self._library_dir, source_key, folder)
                try:
                    os.makedirs(base_lib, exist_ok=True)
                    save_content = raw_data
                    if isinstance(save_content, str):
                        try:
                            save_content = json.loads(save_content)
                        except json.JSONDecodeError:
                            pass
                    safe_index = index_name.lower().replace(" ", "-")
                    local_path = os.path.join(base_lib, f"{safe_index}.json")
                    with open(local_path, "w", encoding="utf-8") as f:
                        json.dump(save_content, f, indent=2, ensure_ascii=False)
                    logger.debug("Validated and saved to: %s", local_path)
                    self.refresh_library_catalog()
                except Exception as e:
                    logger.error("Cache write error: %s", e)
                    if isinstance(parsed_result, dict):
                        parsed_result["_warning"] = tr("MSG_CACHE_WRITE_ERROR")

            return True, parsed_result

        return False, tr("MSG_SEARCH_NOT_FOUND")

    # ------------------------------------------------------------------
    # Higher-level search
    # ------------------------------------------------------------------

    def search_in_library(
        self, category: str, search_text: str
    ) -> list[dict[str, Any]]:
        """Search the offline library and format results for the UI."""
        normalized = None
        if category:
            normalized = {str(category).lower().rstrip("s")}

        rows = self.search_library_catalog(
            query=search_text,
            normalized_categories=normalized,
        )
        return [
            {
                "id": f"lib_{row['category']}_{row['index']}",
                "name": row["display_name"],
                "type": row["category"],
                "is_library": True,
                "index": row["index"],
                "source": row["source"],
                "path": row["path"],
            }
            for row in rows
        ]
