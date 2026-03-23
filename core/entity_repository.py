"""Entity CRUD operations for the Dungeon Master Tool."""

from __future__ import annotations

import logging
import uuid
from typing import Any, Callable

logger = logging.getLogger(__name__)


class EntityRepository:
    """CRUD operations for entities within a campaign.

    Receives the live campaign data dict via a callable so it always
    operates on the current state without holding a stale reference.
    """

    def __init__(
        self,
        get_data: Callable[[], dict[str, Any]],
        save_callback: Callable[[], None],
        fetch_details: Callable[[str, str], tuple[bool, Any]],
        get_world_name: Callable[[], str],
    ) -> None:
        self._get_data = get_data
        self._save = save_callback
        self._fetch_details = fetch_details
        self._get_world_name = get_world_name

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def save(
        self,
        eid: str | None,
        data: dict[str, Any],
        should_save: bool = True,
        auto_source_update: bool = True,
    ) -> str:
        """Persist *data* as an entity and return its ID.

        If *eid* is None a new UUID is generated.  If *eid* already exists
        in the entities dict the record is updated in-place (no duplication).
        """
        if not eid:
            eid = str(uuid.uuid4())

        if auto_source_update:
            world_name = self._get_world_name()
            current_source = data.get("source", "")
            if world_name:
                if not current_source:
                    data["source"] = world_name
                elif world_name not in current_source:
                    data["source"] = f"{current_source} / {world_name}"

        entities = self._get_data()["entities"]
        if eid in entities:
            entities[eid].update(data)
        else:
            entities[eid] = data

        if should_save:
            self._save()
        return eid

    def delete(self, eid: str) -> None:
        """Remove the entity with *eid* from the campaign data."""
        entities = self._get_data()["entities"]
        if eid in entities:
            del entities[eid]
            self._save()

    def prepare_from_external(
        self, data: dict[str, Any], type_override: str | None = None
    ) -> dict[str, Any]:
        """Normalise an externally-sourced entity dict before saving."""
        if type_override:
            data["type"] = type_override
        if not data.get("source"):
            data["source"] = "SRD 5e (2014)"
        data = self._resolve_dependencies(data)
        return data

    def import_with_dependencies(
        self, data: dict[str, Any], type_override: str | None = None
    ) -> str:
        """Save an external entity and auto-import any linked entities."""
        if type_override:
            data["type"] = type_override
        data = self._resolve_dependencies(data)
        return self.save(None, data, auto_source_update=False)

    def get_all_mentions(self) -> list[dict[str, str]]:
        """Return id/name/type dicts for every entity in the campaign."""
        return [
            {"id": eid, "name": ent["name"], "type": ent["type"]}
            for eid, ent in self._get_data()["entities"].items()
        ]

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _resolve_dependencies(self, data: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(data, dict):
            return data
        detected_spells = data.pop("_detected_spell_indices", [])
        if detected_spells:
            self._auto_import_linked(data, detected_spells, "Spell", "spells")
        detected_equip = data.pop("_detected_equipment_indices", [])
        if detected_equip:
            self._auto_import_linked(data, detected_equip, "Equipment", "equipment_ids")
        return data

    def _auto_import_linked(
        self,
        main_data: dict[str, Any],
        indices: list[str],
        category: str,
        target_list_key: str,
    ) -> None:
        if target_list_key not in main_data:
            main_data[target_list_key] = []
        existing_map = {
            ent.get("name"): eid
            for eid, ent in self._get_data()["entities"].items()
            if ent.get("type") == category
        }
        for idx in indices:
            success, sub_data = self._fetch_details(category, idx)
            if success:
                ent_name = sub_data.get("name")
                if ent_name in existing_map:
                    new_id = existing_map[ent_name]
                else:
                    new_id = self.save(None, sub_data, should_save=False, auto_source_update=False)
                    existing_map[ent_name] = new_id
                if new_id not in main_data[target_list_key]:
                    main_data[target_list_key].append(new_id)
