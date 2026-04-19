/// Container for one campaign's narrative state — separate from the world
/// (rules + content registry) so two campaigns can share a world.
class Campaign {
  final String id;
  final String worldId;
  final String name;
  final String notes;
  final DateTime createdAt;
  final DateTime? lastPlayedAt;

  Campaign._(this.id, this.worldId, this.name, this.notes, this.createdAt,
      this.lastPlayedAt);

  factory Campaign({
    required String id,
    required String worldId,
    required String name,
    String notes = '',
    required DateTime createdAt,
    DateTime? lastPlayedAt,
  }) {
    if (id.isEmpty) throw ArgumentError('Campaign.id must not be empty');
    if (worldId.isEmpty) {
      throw ArgumentError('Campaign.worldId must not be empty');
    }
    if (name.isEmpty) throw ArgumentError('Campaign.name must not be empty');
    if (lastPlayedAt != null && lastPlayedAt.isBefore(createdAt)) {
      throw ArgumentError('Campaign.lastPlayedAt must be >= createdAt');
    }
    return Campaign._(id, worldId, name, notes, createdAt, lastPlayedAt);
  }

  Campaign touch(DateTime at) =>
      Campaign._(id, worldId, name, notes, createdAt, at);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Campaign && other.id == id;
  @override
  int get hashCode => id.hashCode;
  @override
  String toString() => 'Campaign($id, $name)';
}
