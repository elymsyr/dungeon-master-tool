import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import '../character_creation/character_draft_notifier.dart';
import '../providers/entity_provider.dart';
import 'package_import_service.dart';
import 'package_source_entities.dart';

/// In-memory materialization of the bundled SRD 5.2.1 content pack:
/// Tier-0 lookups (abilities, skills, damage types, conditions, …) plus
/// the hand-authored Tier-1 catalog (species, classes, subclasses, feats,
/// spells, gear, monsters, …). All `_lookup` placeholders are resolved
/// against the Tier-0 UUIDs minted in this function, so consumers can
/// hand the map to any code path that expects a real `Map<String, Entity>`.
///
/// This is the wizard's fallback entity source when the user creates a
/// character without picking a world — no campaign DB is touched, but the
/// race/class/background pickers still see SRD content. The character is
/// committed with `worldName == ''`; the editor falls back to the same map.
Map<String, Entity> buildBuiltinSrdEntities() {
  final out = <String, Entity>{};

  // 1. Tier-0 seed rows — abilities, skills, conditions, sizes, etc.
  // Mint stable UUIDv5 ids so wizard picks survive hot restart.
  final build = generateBuiltinDnd5eV2Schema();
  final tier0Index = <String, Map<String, String>>{};
  for (final entry in build.seedRows.entries) {
    final slug = entry.key;
    final slugIdx = tier0Index.putIfAbsent(slug, () => <String, String>{});
    for (final row in entry.value) {
      final name = (row['name'] as String?) ?? '';
      if (name.isEmpty) continue;
      final id = srdStableEntityId(slug, name);
      slugIdx[name] = id;
      out[id] = Entity(
        id: id,
        name: name,
        categorySlug: slug,
        source: srdSourceTag,
        description: (row['description'] as String?) ?? '',
        fields: row['fields'] is Map
            ? Map<String, dynamic>.from(row['fields'] as Map)
            : <String, dynamic>{},
      );
    }
  }

  // 2. Tier-1 SRD pack — resolve `_lookup` placeholders against the just-
  // minted Tier-0 ids. Pack-side ids are already deterministic
  // (`srdStableEntityId`), so we reuse them directly.
  final pack = buildSrdCorePack();
  for (final entry in pack.entities.entries) {
    final id = entry.key;
    final raw = Map<String, dynamic>.from(entry.value as Map);
    final attrs = raw['attributes'] is Map
        ? Map<String, dynamic>.from(raw['attributes'] as Map)
        : <String, dynamic>{};
    final resolved =
        PackageImportService.resolveLookupPlaceholder(attrs, tier0Index)
            as Map<String, dynamic>;
    out[id] = Entity(
      id: id,
      name: (raw['name'] as String?) ?? 'Unnamed',
      categorySlug: (raw['type'] as String?) ?? 'unknown',
      source: (raw['source'] as String?) ?? srdSourceTag,
      description: (raw['description'] as String?) ?? '',
      imagePath: (raw['image_path'] as String?) ?? '',
      images: _toStringList(raw['images']),
      tags: _toStringList(raw['tags']),
      dmNotes: (raw['dm_notes'] as String?) ?? '',
      pdfs: _toStringList(raw['pdfs']),
      locationId: raw['location_id'] as String?,
      fields: resolved,
    );
  }

  return out;
}

List<String> _toStringList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return const [];
}

/// Provider that exposes the bundled SRD entities. Constructed once per
/// app lifetime — `buildBuiltinSrdEntities` mints stable v5 UUIDs so the
/// map is referentially equivalent across rebuilds for downstream
/// consumers (Riverpod will not invalidate gratuitously).
final builtinSrdEntitiesProvider = Provider<Map<String, Entity>>((ref) {
  return buildBuiltinSrdEntities();
});

/// Combined entity-source helper used by wizard + editor. Merges the
/// active campaign's entities with the bundled SRD entities, with the
/// campaign taking precedence on id collisions. When `worldName` is
/// empty, returns the bundled map only — no campaign lookup.
Map<String, Entity> mergeWithBuiltinSrd(
  Map<String, Entity> campaignEntities,
  Map<String, Entity> builtin, {
  required bool useCampaign,
}) {
  if (!useCampaign) return builtin;
  if (campaignEntities.isEmpty) return builtin;
  return {...builtin, ...campaignEntities};
}

/// Convenience: identifier used to flag an empty / unbound world. Avoids
/// stringly-typed checks scattered across consumers.
const kBuiltinSrdWorldSentinel = '';

/// Wizard-side entity source. Falls back to the bundled SRD entity map
/// when the current draft has no `worldName`; otherwise merges the active
/// campaign's entities on top so authored content overrides bundled rows.
/// All wizard step widgets should `ref.watch(wizardEntitiesProvider)`
/// instead of touching `entityProvider` directly.
/// Memoized name-sorted list of entities matching a single category slug
/// (e.g. `'spell'`, `'language'`, `'subclass'`). Wizard/editor steps that
/// repeatedly filter the ~7 K-entry entity map should `ref.watch` this
/// instead of doing `entities.values.where(...).toList()..sort(...)` per
/// build — the family caches per-slug and only invalidates when the
/// upstream `wizardEntitiesProvider` map changes by identity (rare).
final entitiesByCategoryProvider =
    Provider.autoDispose.family<List<Entity>, String>((ref, slug) {
  final all = ref.watch(wizardEntitiesProvider);
  final out = <Entity>[];
  for (final e in all.values) {
    if (e.categorySlug == slug) out.add(e);
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return List<Entity>.unmodifiable(out);
});

final wizardEntitiesProvider = Provider.autoDispose<Map<String, Entity>>((ref) {
  // Narrow the draft watch to just the field we need (W1) — otherwise
  // every keystroke into name/description/backstory invalidates this
  // provider and spreads ~7 K entries downstream.
  final world = ref.watch(
    characterDraftProvider.select((d) => d.worldName),
  );
  final builtin = ref.watch(builtinSrdEntitiesProvider);
  if (world.isEmpty) {
    // Built-in + selected standalone packages mode. No world picked, so the
    // bundled SRD is the base and any ticked packages layer on top.
    final packages = ref.watch(
      characterDraftProvider.select((d) => d.sourcePackages),
    );
    return mergeBuiltinWithPackages(ref, builtin, packages);
  }
  final campaign = ref.watch(entityProvider);
  if (campaign.isEmpty) return builtin;
  // Dedupe by (categorySlug, name): when a world was created by importing
  // the bundled SRD pack, every imported entity got a fresh v4 UUID
  // (PackageImportService line 47). Plain id-based merge then keeps both
  // copies — the user sees every race / spell / background twice.
  // Suppress the builtin row whenever the campaign already supplies one
  // with matching (slug, lowercased name); campaign wins for true
  // overrides too.
  final campaignKeys = <String>{};
  for (final e in campaign.values) {
    campaignKeys.add('${e.categorySlug}::${e.name.toLowerCase()}');
  }
  final merged = <String, Entity>{};
  for (final entry in builtin.entries) {
    final e = entry.value;
    final key = '${e.categorySlug}::${e.name.toLowerCase()}';
    if (campaignKeys.contains(key)) continue;
    merged[entry.key] = e;
  }
  merged.addAll(campaign);
  return Map<String, Entity>.unmodifiable(merged);
});
