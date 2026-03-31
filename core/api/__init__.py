"""core.api — API source abstractions and client.

Public surface:
    DndApiClient   — main entry point, wraps dnd5e and open5e sources
    ApiSource      — abstract base for custom sources
"""

from core.api.client import DndApiClient
from core.api.base_source import ApiSource

__all__ = ["DndApiClient", "ApiSource"]
