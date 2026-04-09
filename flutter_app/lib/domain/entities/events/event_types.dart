/// Event type sabitleri — Python core/network/events.py EVENT_PAYLOAD_MODELS
/// registry key'leri ile birebir eşleşir.
///
/// Format: `{domain}.{action}` (örn. "entity.created")
abstract final class EventTypes {
  // -- Campaign --
  static const campaignLoaded = 'campaign.loaded';
  static const campaignSaved = 'campaign.saved';
  static const campaignCreated = 'campaign.created';

  // -- Entity --
  static const entityCreated = 'entity.created';
  static const entityUpdated = 'entity.updated';
  static const entityDeleted = 'entity.deleted';

  // -- Session --
  static const sessionCreated = 'session.created';
  static const sessionActivated = 'session.activated';
  static const sessionCombatantAdded = 'session.combatant_added';
  static const sessionCombatantUpdated = 'session.combatant_updated';
  static const sessionTurnAdvanced = 'session.turn_advanced';

  // -- Map --
  static const mapImageSet = 'map.image_set';
  static const mapFogUpdated = 'map.fog_updated';
  static const mapPinAdded = 'map.pin_added';
  static const mapPinRemoved = 'map.pin_removed';

  // -- Mind Map --
  static const mindmapNodeCreated = 'mindmap.node_created';
  static const mindmapNodeUpdated = 'mindmap.node_updated';
  static const mindmapNodeDeleted = 'mindmap.node_deleted';
  static const mindmapEdgeCreated = 'mindmap.edge_created';
  static const mindmapEdgeDeleted = 'mindmap.edge_deleted';

  // -- Projection --
  static const projectionContentSet = 'projection.content_set';
  static const projectionModeChanged = 'projection.mode_changed';

  // -- Audio --
  static const audioStateChanged = 'audio.state_changed';
  static const audioTrackTriggered = 'audio.track_triggered';

  /// NetworkBridge tarafından forward edilecek event'ler.
  /// Python bridge.py ONLINE_EVENTS ile birebir.
  static const onlineEvents = <String>{
    entityCreated,
    entityUpdated,
    entityDeleted,
    sessionCombatantAdded,
    sessionCombatantUpdated,
    sessionTurnAdvanced,
    mapImageSet,
    mapFogUpdated,
    mapPinAdded,
    mapPinRemoved,
    mindmapNodeCreated,
    mindmapNodeUpdated,
    mindmapNodeDeleted,
    mindmapEdgeCreated,
    mindmapEdgeDeleted,
    projectionContentSet,
    audioStateChanged,
  };
}
