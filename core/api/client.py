import json
import logging

import requests

from core.api.dnd5e_source import Dnd5eApiSource
from core.api.open5e_source import Open5eApiSource

logger = logging.getLogger(__name__)


class DndApiClient:
    def __init__(self):
        self.session = requests.Session()
        self.session.verify = True

        self.sources = {
            "dnd5e": Dnd5eApiSource(self.session),
            "open5e": Open5eApiSource(self.session),
        }
        self.current_source_key = "dnd5e"

    @property
    def current_source(self):
        return self.sources[self.current_source_key]

    def set_source(self, key: str) -> None:
        if key in self.sources:
            self.current_source_key = key

    def get_available_sources(self) -> list[tuple[str, str]]:
        return [("dnd5e", "D&D 5e API (Official SRD)"), ("open5e", "Open5e API (Community)")]

    def get_supported_categories(self) -> list[str]:
        return self.current_source.get_supported_categories()

    def get_list(self, category: str, page: int = 1, filters: dict | None = None) -> dict | list:
        return self.current_source.get_list(category, page=page, filters=filters)

    def get_documents(self) -> list:
        return self.current_source.get_documents()

    def get_details(self, category: str, index: str) -> dict | None:
        return self.current_source.get_details(category, index)

    def search(self, category: str, query: str) -> tuple[dict | None, str]:
        return self.current_source.search(category, query)

    def download_image_bytes(self, full_url: str) -> bytes | None:
        return self.current_source.download_image_bytes(full_url)

    def parse_dispatcher(self, category: str, data: dict | str) -> dict:
        if isinstance(data, str):
            try:
                data = json.loads(data)
            except json.JSONDecodeError:
                return {"name": "Parse Error", "type": category, "description": str(data)}

        result = self.current_source.parse_dispatcher(category, data)

        if not isinstance(result, dict):
            result = {"name": "Data Error", "type": category, "description": str(result)}

        result["api_source"] = getattr(self, "current_source_key", "unknown")

        if isinstance(data, dict) and "_meta_source" in data:
            result["source"] = data["_meta_source"]

        return result
