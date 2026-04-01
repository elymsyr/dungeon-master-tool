"""NetworkBridge skeleton — Sprint 2.

Subscribes to the application EventBus, holds a connection state machine,
and (in Sprint 3) will forward tagged events to the WebSocket server.

Connection states:
    DISCONNECTED  ──connect()──>  CONNECTING
    CONNECTING    ──_on_open()──> CONNECTED
    CONNECTING    ──_on_error()─> ERROR
    CONNECTED     ──disconnect()> DISCONNECTED
    ERROR         ──connect()──>  CONNECTING   (retry)
"""
from __future__ import annotations

import logging
from enum import Enum, auto
from typing import Any

from core.network.events import EVENT_PAYLOAD_MODELS, EventEnvelope

logger = logging.getLogger(__name__)

# Events that will be forwarded to the server when connected.
ONLINE_EVENTS: frozenset[str] = frozenset({
    "entity.created",
    "entity.updated",
    "entity.deleted",
    "session.combatant_added",
    "session.combatant_updated",
    "session.turn_advanced",
    "map.image_set",
    "map.fog_updated",
    "map.pin_added",
    "map.pin_removed",
    "mindmap.node_created",
    "mindmap.node_updated",
    "mindmap.node_deleted",
    "mindmap.edge_created",
    "mindmap.edge_deleted",
    "projection.content_set",
    "audio.state_changed",
})


class ConnectionState(Enum):
    DISCONNECTED = auto()
    CONNECTING = auto()
    CONNECTED = auto()
    ERROR = auto()


class NetworkBridge:
    """Offline-safe event bridge.  Queues events when not connected.

    Usage::

        bridge = NetworkBridge(event_bus)
        bridge.connect("wss://server/ws", token="...")
        # ... later ...
        bridge.disconnect()
    """

    def __init__(self, event_bus) -> None:
        self._event_bus = event_bus
        self._state: ConnectionState = ConnectionState.DISCONNECTED
        self._server_url: str | None = None
        self._token: str | None = None
        self._pending_queue: list[EventEnvelope] = []

        # Subscribe to all events on the bus.
        # EventBus.subscribe supports wildcard "*" for catch-all.
        try:
            self._event_bus.subscribe("*", self._on_any_event)
        except Exception:
            # EventBus may not support "*" yet; wire individual events lazily
            # in Sprint 3 when the bus is extended.
            logger.debug("NetworkBridge: EventBus does not support wildcard subscription; skipping")

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    @property
    def state(self) -> ConnectionState:
        return self._state

    @property
    def is_connected(self) -> bool:
        return self._state is ConnectionState.CONNECTED

    def connect(self, server_url: str, token: str | None = None) -> None:
        """Initiate connection to the WebSocket server."""
        if self._state is ConnectionState.CONNECTED:
            logger.warning("NetworkBridge.connect() called while already connected")
            return
        self._server_url = server_url
        self._token = token
        self._transition(ConnectionState.CONNECTING)
        logger.info("NetworkBridge: connecting to %s", server_url)
        # Sprint 3: instantiate socket.io client and call connect here.

    def disconnect(self) -> None:
        """Close the WebSocket connection gracefully."""
        if self._state is ConnectionState.DISCONNECTED:
            return
        logger.info("NetworkBridge: disconnecting")
        self._transition(ConnectionState.DISCONNECTED)
        # Sprint 3: call sio.disconnect() here.

    # ------------------------------------------------------------------
    # Internal state machine
    # ------------------------------------------------------------------

    def _transition(self, new_state: ConnectionState) -> None:
        old = self._state
        self._state = new_state
        logger.debug("NetworkBridge: %s → %s", old.name, new_state.name)

    def _on_open(self) -> None:
        """Called by the socket client when the connection is established."""
        self._transition(ConnectionState.CONNECTED)
        self._flush_queue()

    def _on_close(self, reason: str = "") -> None:
        """Called by the socket client when the connection closes."""
        logger.info("NetworkBridge: connection closed: %s", reason)
        self._transition(ConnectionState.DISCONNECTED)

    def _on_error(self, error: Any) -> None:
        """Called by the socket client on connection error."""
        logger.error("NetworkBridge: connection error: %s", error)
        self._transition(ConnectionState.ERROR)

    # ------------------------------------------------------------------
    # Event handling
    # ------------------------------------------------------------------

    def _on_any_event(self, event_type: str, **kwargs) -> None:
        """Receives every event from the EventBus."""
        if event_type not in ONLINE_EVENTS:
            return

        payload_model_cls = EVENT_PAYLOAD_MODELS.get(event_type)
        if payload_model_cls is not None:
            try:
                payload_obj = payload_model_cls(**kwargs)
                payload_dict = payload_obj.model_dump()
            except Exception as exc:
                logger.warning("NetworkBridge: payload validation failed for %s: %s", event_type, exc)
                payload_dict = dict(kwargs)
        else:
            payload_dict = dict(kwargs)

        envelope = EventEnvelope(event_type=event_type, payload=payload_dict)

        if self._state is ConnectionState.CONNECTED:
            self._send(envelope)
        else:
            self._queue(envelope)

    def _queue(self, envelope: EventEnvelope) -> None:
        self._pending_queue.append(envelope)
        logger.debug("NetworkBridge: queued %s (queue size: %d)", envelope.event_type, len(self._pending_queue))

    def _flush_queue(self) -> None:
        """Send all queued events after reconnection."""
        if not self._pending_queue:
            return
        logger.info("NetworkBridge: flushing %d queued events", len(self._pending_queue))
        while self._pending_queue:
            self._send(self._pending_queue.pop(0))

    def _send(self, envelope: EventEnvelope) -> None:
        """Serialize and transmit an envelope over WebSocket.

        Sprint 3: replace this stub with ``sio.emit("event", envelope.model_dump_json())``.
        """
        logger.debug("NetworkBridge [STUB]: would send %s", envelope.event_type)
