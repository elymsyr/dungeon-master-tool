import '../entities/entity.dart';

/// D&D 5e creature size category. Drives a token's grid footprint on the
/// battle map (Large = 2×2 cells, Huge = 3×3, …) so creatures auto-size to
/// their stat block instead of all rendering at one fixed size.
enum CreatureSize { tiny, small, medium, large, huge, gargantuan }

/// Parses a size name (case-insensitive) to a [CreatureSize]. Unknown / empty
/// names fall back to [CreatureSize.medium] — the "default size".
CreatureSize parseCreatureSize(String? name) {
  switch (name?.trim().toLowerCase()) {
    case 'tiny':
      return CreatureSize.tiny;
    case 'small':
      return CreatureSize.small;
    case 'large':
      return CreatureSize.large;
    case 'huge':
      return CreatureSize.huge;
    case 'gargantuan':
      return CreatureSize.gargantuan;
    case 'medium':
    default:
      return CreatureSize.medium;
  }
}

/// Grid-cell footprint (square side length, in cells) for a creature size.
/// 5e spaces: Tiny 2½ft (half a 5ft cell), Small/Medium 1 cell, Large 2×2,
/// Huge 3×3, Gargantuan 4×4.
double creatureSizeCells(CreatureSize size) {
  switch (size) {
    case CreatureSize.tiny:
      return 0.5;
    case CreatureSize.small:
    case CreatureSize.medium:
      return 1.0;
    case CreatureSize.large:
      return 2.0;
    case CreatureSize.huge:
      return 3.0;
    case CreatureSize.gargantuan:
      return 4.0;
  }
}

/// Resolves a creature's size name from its entity [fields]. Handles all three
/// storage forms seen at runtime:
///  - `fields['size']` — plain enum string (default non-SRD schema).
///  - `fields['size_ref']` as a UUID string — relation to a 'size' lookup
///    entity; resolved to its `.name` via [entities].
///  - `fields['size_ref']` as a `{_lookup:'size', name:'Large'}` placeholder
///    (unresolved built-in seed) — read `name` directly.
/// Returns '' when no size is present.
String creatureSizeName(
  Map<String, dynamic> fields,
  Map<String, Entity> entities,
) {
  final direct = fields['size'];
  if (direct is String && direct.isNotEmpty) return direct;

  final ref = fields['size_ref'];
  if (ref is String && ref.isNotEmpty) {
    return entities[ref]?.name ?? '';
  }
  if (ref is Map) {
    final name = ref['name'];
    if (name is String) return name;
  }
  return '';
}

/// Grid-cell footprint for an entity, falling back to Medium (1 cell) when the
/// entity is null or carries no size. [entities] is needed only to resolve a
/// `size_ref` stored as a bare UUID.
double tokenCellSpan(Entity? entity, Map<String, Entity> entities) {
  if (entity == null) return 1.0;
  return creatureSizeCells(
    parseCreatureSize(creatureSizeName(entity.fields, entities)),
  );
}
