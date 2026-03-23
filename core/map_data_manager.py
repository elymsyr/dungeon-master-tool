"""Map pin and timeline CRUD operations for the Dungeon Master Tool."""

from __future__ import annotations

import logging
import uuid
from typing import Any, Callable

logger = logging.getLogger(__name__)


class MapDataManager:
    """Manages map pins and timeline entries within a campaign.

    Receives the live campaign data dict via a callable so it always
    operates on the current state without holding a stale reference.
    """

    def __init__(
        self,
        get_data: Callable[[], dict[str, Any]],
        save_callback: Callable[[], None],
    ) -> None:
        self._get_data = get_data
        self._save = save_callback

    # ------------------------------------------------------------------
    # Map image
    # ------------------------------------------------------------------

    def set_map_image(self, rel: str) -> None:
        """Set the map background image path."""
        self._get_data()["map_data"]["image_path"] = rel
        self._save()

    # ------------------------------------------------------------------
    # Map pins
    # ------------------------------------------------------------------

    def add_pin(
        self,
        x: float,
        y: float,
        eid: str,
        color: str | None = None,
        note: str = "",
    ) -> None:
        """Add a new map pin linked to entity *eid*."""
        pin_data = {
            "id": str(uuid.uuid4()),
            "x": x,
            "y": y,
            "entity_id": eid,
            "color": color,
            "note": note,
        }
        self._get_data()["map_data"]["pins"].append(pin_data)
        self._save()

    def update_map_pin(
        self,
        pin_id: str,
        color: str | None = None,
        note: str | None = None,
    ) -> None:
        """Update color and/or note of an existing map pin."""
        for p in self._get_data()["map_data"]["pins"]:
            if p.get("id") == pin_id:
                if color is not None:
                    p["color"] = color
                if note is not None:
                    p["note"] = note
                break
        self._save()

    def move_pin(self, pid: str, x: float, y: float) -> None:
        """Move map pin *pid* to new coordinates."""
        for p in self._get_data()["map_data"]["pins"]:
            if p.get("id") == pid:
                p["x"] = x
                p["y"] = y
                break
        self._save()

    def remove_specific_pin(self, pid: str) -> None:
        """Remove the map pin with the given ID."""
        map_data = self._get_data()["map_data"]
        map_data["pins"] = [p for p in map_data["pins"] if p.get("id") != pid]
        self._save()

    # ------------------------------------------------------------------
    # Timeline pins
    # ------------------------------------------------------------------

    def add_timeline_pin(
        self,
        x: float,
        y: float,
        day: int,
        note: str,
        parent_id: str | None = None,
        entity_ids: list[str] | None = None,
        color: str | None = None,
        session_id: str | None = None,
    ) -> None:
        """Add a new timeline pin (sorted by day after insertion)."""
        pin = {
            "id": str(uuid.uuid4()),
            "x": x,
            "y": y,
            "day": int(day),
            "note": note,
            "parent_id": parent_id,
            "entity_ids": entity_ids if entity_ids else [],
            "color": color,
            "session_id": session_id,
        }
        map_data = self._get_data()["map_data"]
        if "timeline" not in map_data:
            map_data["timeline"] = []
        map_data["timeline"].append(pin)
        map_data["timeline"].sort(key=lambda k: k["day"])
        self._save()

    def remove_timeline_pin(self, pin_id: str) -> None:
        """Remove the timeline pin with the given ID."""
        map_data = self._get_data()["map_data"]
        if "timeline" in map_data:
            map_data["timeline"] = [
                p for p in map_data["timeline"] if p.get("id") != pin_id
            ]
            self._save()

    def update_timeline_pin(
        self,
        pin_id: str,
        day: int,
        note: str,
        entity_ids: list[str],
        session_id: str | None = None,
    ) -> None:
        """Update day, note, entity_ids, and session_id for a timeline pin."""
        map_data = self._get_data()["map_data"]
        if "timeline" in map_data:
            for p in map_data["timeline"]:
                if p["id"] == pin_id:
                    p["day"] = int(day)
                    p["note"] = note
                    p["entity_ids"] = entity_ids
                    p["session_id"] = session_id
                    break
            map_data["timeline"].sort(key=lambda k: k["day"])
            self._save()

    def update_timeline_pin_visuals(
        self, pin_id: str, color: str | None = None
    ) -> None:
        """Update the color of a timeline pin."""
        map_data = self._get_data()["map_data"]
        if "timeline" in map_data:
            for p in map_data["timeline"]:
                if p["id"] == pin_id:
                    if color:
                        p["color"] = color
                    break
            self._save()

    def get_timeline_pin(self, pin_id: str) -> dict[str, Any] | None:
        """Return the timeline pin dict with the given ID, or None."""
        map_data = self._get_data()["map_data"]
        if "timeline" in map_data:
            for p in map_data["timeline"]:
                if p["id"] == pin_id:
                    return p
        return None

    def update_timeline_chain_color(self, start_pin_id: str, color: str) -> None:
        """Propagate *color* to all pins connected to *start_pin_id* via parent_id links."""
        map_data = self._get_data()["map_data"]
        if "timeline" not in map_data:
            return
        timeline = map_data["timeline"]
        adjacency: dict[str, list[str]] = {p["id"]: [] for p in timeline}
        for p in timeline:
            pid = p["id"]
            parent = p.get("parent_id")
            if parent and parent in adjacency:
                adjacency[pid].append(parent)
                adjacency[parent].append(pid)
        connected_ids: set[str] = set()
        queue = [start_pin_id]
        while queue:
            current = queue.pop(0)
            if current in connected_ids:
                continue
            connected_ids.add(current)
            if current in adjacency:
                for neighbor in adjacency[current]:
                    if neighbor not in connected_ids:
                        queue.append(neighbor)
        for p in timeline:
            if p["id"] in connected_ids:
                p["color"] = color
        self._save()

    def move_timeline_pin(self, pin_id: str, x: float, y: float) -> None:
        """Move a timeline pin to new coordinates."""
        map_data = self._get_data()["map_data"]
        if "timeline" in map_data:
            for p in map_data["timeline"]:
                if p["id"] == pin_id:
                    p["x"] = x
                    p["y"] = y
                    break
            self._save()
