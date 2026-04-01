"""Event schema v1 — Pydantic models for the offline event catalogue.

These models define the canonical payload shape for every event emitted by
DataManager through EventBus.  The NetworkBridge (Sprint 3) will serialise
these to JSON before forwarding them to the WebSocket server.

All models use Pydantic v2 (installed as pydantic>=2).
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any, Literal

from pydantic import BaseModel, Field


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


def _new_id() -> str:
    return str(uuid.uuid4())


# ---------------------------------------------------------------------------
# Envelope
# ---------------------------------------------------------------------------

class EventEnvelope(BaseModel):
    """Top-level wrapper sent over the wire for every event."""

    event_id: str = Field(default_factory=_new_id)
    event_type: str
    session_id: str | None = None
    campaign_id: str | None = None
    emitted_at: datetime = Field(default_factory=_now_utc)
    payload: dict[str, Any]


# ---------------------------------------------------------------------------
# Campaign payloads
# ---------------------------------------------------------------------------

class CampaignLoadedPayload(BaseModel):
    campaign_path: str
    world_name: str = ""


class CampaignSavedPayload(BaseModel):
    campaign_path: str


class CampaignCreatedPayload(BaseModel):
    world_name: str


# ---------------------------------------------------------------------------
# Entity payloads
# ---------------------------------------------------------------------------

class EntityCreatedPayload(BaseModel):
    entity_id: str
    entity_type: str = ""
    name: str = ""


class EntityUpdatedPayload(BaseModel):
    entity_id: str
    changed_fields: list[str] = Field(default_factory=list)


class EntityDeletedPayload(BaseModel):
    entity_id: str
    entity_type: str = ""


# ---------------------------------------------------------------------------
# Session payloads
# ---------------------------------------------------------------------------

class SessionCreatedPayload(BaseModel):
    session_id: str
    session_name: str = ""


class SessionActivatedPayload(BaseModel):
    session_id: str


class CombatantAddedPayload(BaseModel):
    session_id: str
    combatant_id: str
    name: str = ""


class CombatantUpdatedPayload(BaseModel):
    session_id: str
    combatant_id: str
    changes: dict[str, Any] = Field(default_factory=dict)


class TurnAdvancedPayload(BaseModel):
    session_id: str
    new_active_combatant_id: str


# ---------------------------------------------------------------------------
# Map payloads
# ---------------------------------------------------------------------------

class MapImageSetPayload(BaseModel):
    image_path: str


class MapFogUpdatedPayload(BaseModel):
    """Fog-of-war update.  fog_data is an opaque serialised blob."""
    fog_data: str  # base64-encoded PNG mask or JSON polygon list


class MapPinAddedPayload(BaseModel):
    pin_id: str
    x: float
    y: float
    label: str = ""


class MapPinRemovedPayload(BaseModel):
    pin_id: str


# ---------------------------------------------------------------------------
# Mind map payloads
# ---------------------------------------------------------------------------

class MindMapNodeCreatedPayload(BaseModel):
    map_id: str
    node_id: str
    label: str = ""
    x: float = 0.0
    y: float = 0.0


class MindMapNodeUpdatedPayload(BaseModel):
    map_id: str
    node_id: str
    changes: dict[str, Any] = Field(default_factory=dict)


class MindMapNodeDeletedPayload(BaseModel):
    map_id: str
    node_id: str


class MindMapEdgeCreatedPayload(BaseModel):
    map_id: str
    edge_id: str
    source_id: str
    target_id: str


class MindMapEdgeDeletedPayload(BaseModel):
    map_id: str
    edge_id: str


# ---------------------------------------------------------------------------
# Projection payloads
# ---------------------------------------------------------------------------

class ProjectionContentPayload(BaseModel):
    content_type: Literal["map", "entity", "image", "pdf", "blank"]
    content_ref: str = ""


class ProjectionModeChangedPayload(BaseModel):
    mode: Literal["map", "content"]


# ---------------------------------------------------------------------------
# Audio payloads
# ---------------------------------------------------------------------------

class AudioStatePayload(BaseModel):
    theme: str = ""
    intensity: str = ""
    master_volume: float = 1.0


class AudioTrackTriggeredPayload(BaseModel):
    track_id: str
    track_name: str = ""


# ---------------------------------------------------------------------------
# Registry: event_type → payload model
# ---------------------------------------------------------------------------

EVENT_PAYLOAD_MODELS: dict[str, type[BaseModel]] = {
    "campaign.loaded": CampaignLoadedPayload,
    "campaign.saved": CampaignSavedPayload,
    "campaign.created": CampaignCreatedPayload,
    "entity.created": EntityCreatedPayload,
    "entity.updated": EntityUpdatedPayload,
    "entity.deleted": EntityDeletedPayload,
    "session.created": SessionCreatedPayload,
    "session.activated": SessionActivatedPayload,
    "session.combatant_added": CombatantAddedPayload,
    "session.combatant_updated": CombatantUpdatedPayload,
    "session.turn_advanced": TurnAdvancedPayload,
    "map.image_set": MapImageSetPayload,
    "map.fog_updated": MapFogUpdatedPayload,
    "map.pin_added": MapPinAddedPayload,
    "map.pin_removed": MapPinRemovedPayload,
    "mindmap.node_created": MindMapNodeCreatedPayload,
    "mindmap.node_updated": MindMapNodeUpdatedPayload,
    "mindmap.node_deleted": MindMapNodeDeletedPayload,
    "mindmap.edge_created": MindMapEdgeCreatedPayload,
    "mindmap.edge_deleted": MindMapEdgeDeletedPayload,
    "projection.content_set": ProjectionContentPayload,
    "projection.mode_changed": ProjectionModeChangedPayload,
    "audio.state_changed": AudioStatePayload,
    "audio.track_triggered": AudioTrackTriggeredPayload,
}
