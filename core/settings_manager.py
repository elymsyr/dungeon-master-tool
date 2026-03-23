"""Application settings persistence for the Dungeon Master Tool."""

from __future__ import annotations

import json
import logging
import os
from typing import Any

from core.locales import set_language

logger = logging.getLogger(__name__)


class SettingsManager:
    """Manages loading and saving application settings to a JSON file."""

    _DEFAULTS: dict[str, str] = {"language": "EN", "theme": "dark"}

    def __init__(self, cache_dir: str) -> None:
        self._cache_dir = cache_dir
        self._path = os.path.join(cache_dir, "settings.json")
        self.settings: dict[str, Any] = self._load()
        self.current_theme: str = self.settings.get("theme", "dark")
        set_language(self.settings.get("language", "EN"))

    def _load(self) -> dict[str, Any]:
        if os.path.exists(self._path):
            try:
                with open(self._path, "r", encoding="utf-8") as f:
                    return json.load(f)
            except (json.JSONDecodeError, OSError) as e:
                logger.warning("Failed to load settings from %s: %s", self._path, e)
        return dict(self._DEFAULTS)

    def save(self, updates: dict[str, Any]) -> None:
        """Merge *updates* into current settings and persist to disk."""
        os.makedirs(self._cache_dir, exist_ok=True)
        self.settings.update(updates)
        try:
            with open(self._path, "w", encoding="utf-8") as f:
                json.dump(self.settings, f, indent=4)
        except OSError as e:
            logger.error("Failed to save settings to %s: %s", self._path, e)
        set_language(self.settings.get("language", "EN"))
        self.current_theme = self.settings.get("theme", "dark")
