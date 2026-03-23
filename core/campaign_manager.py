"""Campaign I/O and migration for the Dungeon Master Tool."""

from __future__ import annotations

import json
import logging
import os
import uuid
from typing import Any, Callable

import msgpack

from core.locales import tr
from core.models import PROPERTY_MAP, SCHEMA_MAP, get_default_entity_structure

logger = logging.getLogger(__name__)


class CampaignManager:
    """Handles campaign loading, saving, creation, and data migration.

    Accepts callbacks so the orchestrating DataManager can update its own
    ``data`` and ``current_campaign_path`` attributes after a load/create.
    """

    def __init__(
        self,
        worlds_dir: str,
        on_data_loaded: Callable[[dict[str, Any], str], None],
        save_callback: Callable[[], None],
        import_image: Callable[[str], str | None],
        get_campaign_path: Callable[[], str | None],
    ) -> None:
        self._worlds_dir = worlds_dir
        self._on_data_loaded = on_data_loaded
        self._save = save_callback
        self._import_image = import_image
        self._get_path = get_campaign_path

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def get_available(self) -> list[str]:
        """Return names of all campaign folders in the worlds directory."""
        if not os.path.exists(self._worlds_dir):
            return []
        return [
            d
            for d in os.listdir(self._worlds_dir)
            if os.path.isdir(os.path.join(self._worlds_dir, d))
        ]

    def load_by_name(self, name: str) -> tuple[bool, str]:
        """Load a campaign by its folder name."""
        return self.load(os.path.join(self._worlds_dir, name))

    def load(self, folder: str) -> tuple[bool, str]:
        """Load a campaign from *folder*.

        Tries MsgPack (.dat) first; falls back to JSON and auto-migrates.
        Returns (success, message).
        """
        json_path = os.path.join(folder, "data.json")
        dat_path = os.path.join(folder, "data.dat")

        data: dict[str, Any] | None = None

        # 1. Try MsgPack (fast format)
        if os.path.exists(dat_path):
            try:
                with open(dat_path, "rb") as f:
                    data = msgpack.unpack(f, raw=False)
            except Exception as e:
                logger.warning("Error loading DAT file, falling back to JSON: %s", e)

        # 2. Try JSON if DAT failed or not found
        if data is None and os.path.exists(json_path):
            try:
                with open(json_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                # Notify caller so save_data() can persist as DAT
                self._on_data_loaded(data, folder)
                self._save()
                logger.info(tr("MSG_MIGRATION_CONVERTED"))
            except Exception as e:
                return False, f"JSON Load Error: {str(e)}"

        if data is None:
            return False, tr("MSG_FILE_NOT_FOUND_DB")

        # --- Data integrity checks ---
        self._ensure_structure(data)

        # Notify caller before running migration (migration may call save_data)
        self._on_data_loaded(data, folder)

        # --- Path and schema migration ---
        self._fix_absolute_paths(data, folder)
        self._migrate_entity_schemas(data)

        # Persist the migrated data
        self._save()
        return True, tr("MSG_YUKLENDI")

    def create(self, world_name: str) -> tuple[bool, str]:
        """Create a new campaign folder and return (success, message)."""
        folder = os.path.join(self._worlds_dir, world_name)
        try:
            os.makedirs(folder, exist_ok=True)
            os.makedirs(os.path.join(folder, "assets"), exist_ok=True)
            first_sid = str(uuid.uuid4())
            data: dict[str, Any] = {
                "world_name": world_name,
                "entities": {},
                "map_data": {"image_path": "", "pins": [], "timeline": []},
                "sessions": [
                    {
                        "id": first_sid,
                        "name": "Session 0",
                        "date": tr("MSG_TODAY"),
                        "notes": "",
                        "logs": "",
                        "combatants": [],
                    }
                ],
                "last_active_session_id": first_sid,
                "mind_maps": {},
            }
            self._on_data_loaded(data, folder)
            self._save()
            return True, tr("MSG_OLUSTURULDU")
        except Exception as e:
            return False, str(e)

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _ensure_structure(self, data: dict[str, Any]) -> None:
        """Add missing top-level keys so downstream code can assume they exist."""
        if "sessions" not in data:
            data["sessions"] = []
        if "entities" not in data:
            data["entities"] = {}
        if "map_data" not in data:
            data["map_data"] = {"image_path": "", "pins": [], "timeline": []}
        if "timeline" not in data["map_data"]:
            data["map_data"]["timeline"] = []
        if "last_active_session_id" not in data:
            data["last_active_session_id"] = None
        if "mind_maps" not in data:
            data["mind_maps"] = {}

        if not data["sessions"]:
            new_sid = str(uuid.uuid4())
            data["sessions"].append(
                {
                    "id": new_sid,
                    "name": "Default Session",
                    "date": tr("MSG_TODAY"),
                    "notes": "",
                    "logs": "",
                    "combatants": [],
                }
            )
            data["last_active_session_id"] = new_sid

        if not data["last_active_session_id"] and data["sessions"]:
            data["last_active_session_id"] = data["sessions"][-1]["id"]

    def _fix_absolute_paths(
        self, data: dict[str, Any], campaign_path: str
    ) -> None:
        """Convert any absolute image paths to relative paths inside assets/."""
        assets_dir = os.path.join(campaign_path, "assets")
        os.makedirs(assets_dir, exist_ok=True)
        changed = False

        for ent in data["entities"].values():
            new_images = []
            for img_path in ent.get("images", []):
                if os.path.isabs(img_path) and os.path.exists(img_path):
                    rel = self._import_image(img_path)
                    new_images.append(rel if rel else img_path)
                    changed = changed or bool(rel)
                else:
                    new_images.append(img_path)
            ent["images"] = new_images

            legacy = ent.get("image_path")
            if legacy and os.path.isabs(legacy) and os.path.exists(legacy):
                rel = self._import_image(legacy)
                if rel:
                    ent["image_path"] = rel
                    changed = True

        if changed:
            logger.info(tr("MSG_ABSOLUTE_PATHS_FIXED"))

    def _migrate_entity_schemas(self, data: dict[str, Any]) -> None:
        """Migrate legacy Turkish type/attribute keys to current English keys."""
        for ent in data["entities"].values():
            old_type = ent.get("type", "NPC")
            if old_type in SCHEMA_MAP:
                ent["type"] = SCHEMA_MAP[old_type]

            attrs = ent.get("attributes", {})
            ent["attributes"] = {PROPERTY_MAP.get(k, k): v for k, v in attrs.items()}

            default = get_default_entity_structure(ent.get("type", "NPC"))
            for key, val in default.items():
                if key not in ent:
                    ent[key] = val

            if not ent.get("images") and ent.get("image_path"):
                ent["images"] = [ent["image_path"]]
