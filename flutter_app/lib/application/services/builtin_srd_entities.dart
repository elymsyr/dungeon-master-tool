import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import '../character_creation/character_draft_notifier.dart';
import '../providers/entity_provider.dart';
import '../providers/package_link_provider.dart' show packageSetKey;
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
  return mergeCampaignOverBuiltin(campaignEntities, builtin);
}

/// Campaign entities layered over the bundled SRD map, deduped by
/// `(categorySlug, lowercased name)`.
///
/// A world's SRD rows never share ids with [builtinSrdEntitiesProvider]:
/// imported worlds minted fresh v4 UUIDs, and F1 worlds synthesise per-world
/// v5 ids from `package_entities`. A plain id-keyed union therefore keeps
/// BOTH copies, and every picker that iterates the map (fighting style,
/// spells, feats, species...) lists each SRD entry twice.
///
/// The suppressed builtin ids stay *resolvable* — a character created
/// worldless and later bound to a world still holds builtin ids in its
/// fields — they just don't show up in `keys` / `values` / `entries`.
Map<String, Entity> mergeCampaignOverBuiltin(
  Map<String, Entity> campaign,
  Map<String, Entity> builtin,
) {
  if (campaign.isEmpty) return builtin;
  final byKey = <String, Entity>{
    for (final e in campaign.values)
      '${e.categorySlug}::${e.name.toLowerCase()}': e,
  };
  final aliases = <String, Entity>{};
  for (final entry in builtin.entries) {
    final e = entry.value;
    final twin = byKey['${e.categorySlug}::${e.name.toLowerCase()}'];
    if (twin != null) aliases[entry.key] = twin;
  }
  return _CampaignOverBuiltinMap(campaign, builtin, aliases);
}

/// Lazy view backing [mergeCampaignOverBuiltin]. Hides the duplicated builtin
/// ids from iteration while still answering lookups for them.
class _CampaignOverBuiltinMap extends UnmodifiableMapBase<String, Entity> {
  final Map<String, Entity> _campaign;
  final Map<String, Entity> _builtin;
  final Map<String, Entity> _aliases;

  _CampaignOverBuiltinMap(this._campaign, this._builtin, this._aliases);

  late final List<String> _keys = <String>[
    ..._campaign.keys,
    for (final k in _builtin.keys)
      if (!_aliases.containsKey(k) && !_campaign.containsKey(k)) k,
  ];

  @override
  Entity? operator [](Object? key) =>
      _campaign[key] ?? _aliases[key] ?? _builtin[key];

  @override
  Iterable<String> get keys => _keys;

  @override
  bool containsKey(Object? key) =>
      _campaign.containsKey(key) ||
      _aliases.containsKey(key) ||
      _builtin.containsKey(key);
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
/// One pass over the merged entity map, bucketed by category slug and
/// name-sorted. Built once per `wizardEntitiesProvider` identity and shared by
/// every `entitiesByCategoryProvider(slug)` watch — a single chargen step
/// (e.g. feats) watches several categories, and each used to re-scan the whole
/// map. With this index those become O(1) bucket lookups.
final categoryIndexProvider =
    Provider.autoDispose<Map<String, List<Entity>>>((ref) {
  final all = ref.watch(wizardEntitiesProvider);
  final index = <String, List<Entity>>{};
  for (final e in all.values) {
    (index[e.categorySlug] ??= <Entity>[]).add(e);
  }
  for (final list in index.values) {
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
  return index;
});

final entitiesByCategoryProvider =
    Provider.autoDispose.family<List<Entity>, String>((ref, slug) {
  final list = ref.watch(categoryIndexProvider)[slug];
  // Unmodifiable *view* (no copy) so a consumer can't mutate the shared bucket.
  return list == null
      ? const <Entity>[]
      : UnmodifiableListView<Entity>(list);
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
    //
    // NUL separator (packageSetKey): package names are human titles
    // ("Adventurer's Guide"), so a space-joined key split back apart turned
    // one package into two nonexistent ones and its content never loaded.
    // Select a value-equal *key* (a joined String) rather than the raw list:
    // a `copyWith` mints a fresh `List` instance every draft change, and a
    // `List` has no value `==`, so watching it directly re-ran this merge (and
    // the whole category index) on every keystroke. The key only changes when
    // the picked-pack set actually changes.
    final packagesKey = ref.watch(
      characterDraftProvider.select((d) => packageSetKey(d.sourcePackages)),
    );
    final packages =
        packagesKey.isEmpty ? const <String>[] : packagesKey.split('\u0000');
    return mergeBuiltinWithPackages(ref, builtin, packages);
  }
  final campaign = ref.watch(entityProvider);
  return mergeCampaignOverBuiltin(campaign, builtin);
});
