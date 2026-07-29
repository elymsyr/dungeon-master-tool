/// One-shot converter that moves a feat's / trait's retired `auto_granted_by`
/// list onto the card that actually grants it.
///
/// Before: the Feat said *"Paladin grants me at level 9"*, while the Paladin
/// card carried an unlinked narrative row for the same feature. Two places
/// stated one fact, and in the shipped SRD content they disagreed nine times.
/// After: the Class / Subclass `features` row for that level names the feat in
/// `granted_feat_refs`, Species / Subspecies name it in their flat
/// `granted_feat_refs`, and the feat says nothing about who hands it out.
///
/// Unlike [migrateRuleEffects] this is **cross-entity** — it reads one card and
/// writes another — so it runs over a whole entity map rather than at the
/// per-entity seams:
///   * `WorldRepositoryImpl._loadFromDb` — after the world's rows and the
///     synthesised built-ins are merged, so existing campaigns convert on open
///     and persist converted on the next save;
///   * `PackagePayloadImporter.install` — over the whole payload, so an old
///     third-party pack lands already inverted.
///
/// Idempotent and allocation-free on converted data: a map where no entity
/// carries `auto_granted_by` is left completely untouched.
library;

/// Entity map shape accepted here: `{entityId: {type, name, attributes}}` —
/// the wire/world format, not the domain `Entity`.
typedef WorldEntityRows = Map<String, dynamic>;

/// Rewrite every `auto_granted_by` in [entities] as a forward edge on the
/// granting card. Mutates the maps in place and returns the number of edges
/// moved (0 when there was nothing to do).
///
/// A source card that is missing from [entities] cannot receive the edge; the
/// feat keeps working only if some other source matched, so the dropped source
/// is recorded on the feat's `mechanical_notes` rather than vanishing.
int invertAutoGrants(WorldEntityRows entities) {
  // Cheap gate — the overwhelmingly common case is already-converted data.
  var anyLegacy = false;
  for (final row in entities.values) {
    if (_attrs(row)?['auto_granted_by'] != null) {
      anyLegacy = true;
      break;
    }
  }
  if (!anyLegacy) return 0;

  // `source_ref` is usually an id, but hand-authored and freshly-imported
  // content can still carry a `{slug, name}` / `{_ref, name}` envelope, so
  // index by name as well.
  final byId = <String, Map<String, dynamic>>{};
  final byTypeName = <String, Map<String, dynamic>>{};
  entities.forEach((id, row) {
    if (row is! Map) return;
    final attrs = _attrs(row);
    if (attrs == null) return;
    final card = <String, dynamic>{'id': id, 'row': row, 'attrs': attrs};
    byId[id] = card;
    final name = row['name']?.toString();
    final type = row['type']?.toString();
    if (name != null && type != null) byTypeName['$type/$name'] = card;
  });

  var moved = 0;
  for (final card in byId.values) {
    final row = card['row'] as Map;
    final attrs = card['attrs'] as Map<String, dynamic>;
    final auto = attrs.remove('auto_granted_by');
    if (auto is! List) continue;

    final slug = row['type']?.toString();
    // Only feats and traits ever carried the field; anything else is noise.
    final refKey = slug == 'trait' ? 'granted_trait_refs' : 'granted_feat_refs';
    final selfId = card['id'] as String;

    for (final srcRaw in auto) {
      if (srcRaw is! Map) continue;
      final source = srcRaw['source']?.toString();
      final target = _lookupSource(srcRaw['source_ref'], source, byId, byTypeName);
      if (target == null) {
        _note(attrs, 'Auto-granted by $source (card not installed)');
        continue;
      }
      final targetAttrs = target['attrs'] as Map<String, dynamic>;
      final atRaw = srcRaw['at_level'];
      final atLevel = atRaw is int ? atRaw : int.tryParse('$atRaw');

      switch (source) {
        case 'class':
        case 'subclass':
          _addToFeatureRow(targetAttrs, atLevel ?? 1, refKey, selfId,
              featureName: row['name']?.toString() ?? '');
          moved++;
        case 'species':
        case 'subspecies':
          _addRef(targetAttrs, refKey, selfId);
          moved++;
        case 'background':
          // A Background states its feat once, on `origin_feat_ref`. Giving it
          // a second list would recreate the ambiguity this whole change
          // removes, so fill that field when free and otherwise say so in
          // prose rather than inventing a field.
          if (refKey == 'granted_trait_refs') {
            _addRef(targetAttrs, 'trait_refs', selfId);
            moved++;
          } else if (_isBlank(targetAttrs['origin_feat_ref'])) {
            targetAttrs['origin_feat_ref'] = selfId;
            moved++;
          } else {
            _note(attrs,
                'Granted by background ${target['row']['name']} (background '
                'already declares a different origin feat)');
          }
        default:
          _note(attrs, 'Auto-granted by an unrecognised source "$source"');
      }
    }
  }
  return moved;
}

/// The entity's `attributes`, guaranteed mutable and `Map<String, dynamic>`.
///
/// Production data comes from `jsonDecode` and already is one, but a narrowly
/// typed literal (`{'k': [<Map>...]}`) satisfies the `Map<String, dynamic>`
/// check while rejecting a `List<String>` write at runtime. Normalising once
/// removes that whole failure mode.
Map<String, dynamic>? _attrs(Object? row) {
  if (row is! Map) return null;
  final a = row['attributes'];
  if (a is! Map) return null;
  final normalised = Map<String, dynamic>.from(a);
  row['attributes'] = normalised;
  return normalised;
}

Map<String, dynamic>? _lookupSource(
  Object? ref,
  String? source,
  Map<String, Map<String, dynamic>> byId,
  Map<String, Map<String, dynamic>> byTypeName,
) {
  if (ref is String && ref.isNotEmpty) {
    final hit = byId[ref];
    if (hit != null) return hit;
  }
  if (ref is Map) {
    final id = ref['id'];
    if (id is String && byId.containsKey(id)) return byId[id];
    final name = ref['name']?.toString();
    final slug = (ref['_ref'] ?? ref['slug'] ?? source)?.toString();
    if (name != null && slug != null) return byTypeName['$slug/$name'];
  }
  return null;
}

/// Append [id] to the `features` row at [level], creating the row when the
/// card has no entry for that level yet.
void _addToFeatureRow(
  Map<String, dynamic> attrs,
  int level,
  String refKey,
  String id, {
  required String featureName,
}) {
  final rows = (attrs['features'] is List)
      ? (attrs['features'] as List)
      : (attrs['features'] = <Map<String, dynamic>>[]) as List;

  Map<String, dynamic>? target;
  for (final r in rows) {
    if (r is! Map) continue;
    if (r['level'] != level) continue;
    // Prefer the row that already describes this feature; otherwise the first
    // row at the level is a fine home — grants are read per level, not per row.
    if (r['name'] == featureName) {
      target = r.cast<String, dynamic>();
      break;
    }
    target ??= r.cast<String, dynamic>();
  }
  if (target == null) {
    target = <String, dynamic>{'level': level, 'name': featureName, 'description': ''};
    rows.add(target);
  }
  final list = (target[refKey] is List)
      ? (target[refKey] as List)
      : (target[refKey] = <String>[]) as List;
  if (!list.contains(id)) list.add(id);
}

void _addRef(Map<String, dynamic> attrs, String key, String id) {
  final list =
      (attrs[key] is List) ? (attrs[key] as List) : (attrs[key] = <String>[]) as List;
  if (!list.contains(id)) list.add(id);
}

void _note(Map<String, dynamic> attrs, String line) {
  final notes = (attrs['mechanical_notes'] is List)
      ? (attrs['mechanical_notes'] as List)
      : (attrs['mechanical_notes'] = <String>[]) as List;
  if (!notes.contains(line)) notes.add(line);
}

bool _isBlank(Object? v) =>
    v == null || (v is String && v.isEmpty) || (v is Map && v.isEmpty);
