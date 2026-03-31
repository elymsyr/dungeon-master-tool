from __future__ import annotations

import logging
from collections import defaultdict
from typing import Any, Callable

logger = logging.getLogger(__name__)


class EventBus:
    """Application-wide publish-subscribe event bus.

    Handles cross-cutting concerns that span unrelated components.
    Direct parent-child communication should still use PyQt signals.

    Event naming convention: ``{domain}.{action}``

    Current events:
        entity.deleted(entity_id: str)   -- entity removed from campaign
        entity.created(entity_id: str)   -- new entity added
        entity.updated(entity_id: str)   -- entity data modified
        theme.changed(theme_name: str, stylesheet: str)
        language.changed(code: str)

    Usage::

        bus = EventBus()
        bus.subscribe("entity.deleted", sidebar.on_entity_deleted)
        bus.publish("entity.deleted", entity_id="abc123")
    """

    def __init__(self) -> None:
        self._subscribers: dict[str, list[Callable[..., Any]]] = defaultdict(list)

    def subscribe(self, event: str, handler: Callable[..., Any]) -> None:
        if handler not in self._subscribers[event]:
            self._subscribers[event].append(handler)

    def unsubscribe(self, event: str, handler: Callable[..., Any]) -> None:
        try:
            self._subscribers[event].remove(handler)
        except ValueError:
            pass

    def publish(self, event: str, **kwargs: Any) -> None:
        for handler in list(self._subscribers[event]):
            try:
                handler(**kwargs)
            except Exception:
                logger.exception(
                    "Event handler %s failed for event '%s'",
                    getattr(handler, "__qualname__", repr(handler)),
                    event,
                )
