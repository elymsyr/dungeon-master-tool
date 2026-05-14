/// public.entity_shares satırı.
/// [sharedWith] null = world-wide (tüm üyeler).
class EntityShare {
  final String entityId;
  final String worldId;
  final String? sharedWith;
  final String sharedBy;
  final DateTime sharedAt;

  const EntityShare({
    required this.entityId,
    required this.worldId,
    required this.sharedWith,
    required this.sharedBy,
    required this.sharedAt,
  });

  factory EntityShare.fromJson(Map<String, dynamic> json) => EntityShare(
        entityId: json['entity_id'] as String,
        worldId: json['world_id'] as String,
        sharedWith: json['shared_with'] as String?,
        sharedBy: json['shared_by'] as String,
        sharedAt: DateTime.parse(json['shared_at'] as String),
      );

  bool get isWorldWide => sharedWith == null;
}
