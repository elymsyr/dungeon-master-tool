"""Backward-compatible re-export facade.

All implementation has moved to ``core/api/``.  Existing imports such as
``from core.api_client import DndApiClient`` continue to work unchanged.
"""

from core.api.client import DndApiClient
from core.api.base_source import ApiSource
from core.api.dnd5e_source import Dnd5eApiSource
from core.api.open5e_source import Open5eApiSource
from core.api.field_mappers import json_dict_to_str

__all__ = [
    "DndApiClient",
    "ApiSource",
    "Dnd5eApiSource",
    "Open5eApiSource",
    "json_dict_to_str",
]
