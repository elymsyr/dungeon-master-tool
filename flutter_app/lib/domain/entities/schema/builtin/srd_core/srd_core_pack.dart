import 'package:uuid/uuid.dart';

import '_helpers.dart';
import 'ammunition.dart';
import 'animals.dart';
import 'armor.dart';
import 'backgrounds.dart';
import 'classes.dart';
import 'creature_actions.dart';
import 'feats.dart';
import 'feats_class.dart';
import 'gear.dart';
import 'magic_items.dart';
import 'monsters.dart';
import 'mounts.dart';
import 'packs.dart';
import 'spells.dart';
import 'species.dart';
import 'subclasses.dart';
import 'subspecies.dart';
import 'tools.dart';
import 'traits.dart';
import 'vehicles.dart';
import 'weapons.dart';

/// SRD 5.2.1 (CC-BY-4.0) attribution string. Required wherever the pack
/// content is surfaced (campaign settings → About panel).
const srdAttribution =
    'This work includes material from the System Reference Document 5.2.1 '
    '("SRD 5.2.1") by Wizards of the Coast LLC, available at '
    'https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the '
    'Creative Commons Attribution 4.0 International License, available at '
    'https://creativecommons.org/licenses/by/4.0/legalcode.';

const srdLicense = 'CC-BY-4.0';
const srdSourceTag = 'SRD 5.2.1';

/// Version of the hand-authored SRD core content. Bump on any content
/// fix / new rows so existing installs re-seed (see [SrdCorePackageBootstrap]).
/// Hoisted to a top-level const so the bootstrap can compare against the
/// stored DB version WITHOUT building the full ~2000-entity pack first.
const srdCorePackVersion = '1.0.8';

/// Output of [buildSrdCorePack]. `entities` is keyed by the freshly minted
/// UUID, value is the wire-format package entity (see `_helpers.packEntity`).
class SrdCorePack {
  final Map<String, dynamic> entities;
  final Map<String, dynamic> metadata;
  const SrdCorePack({required this.entities, required this.metadata});
}

const _uuid = Uuid();

/// Stable namespace UUID for SRD 5.2.1 Core pack entity ids. UUIDv5 inputs
/// (this namespace + the row's "slug:name") produce deterministic ids that
/// stay identical across app starts — critical because pack entity ids
/// are persisted as `package_entity_id` foreign keys in installed
/// campaigns. If the ids changed every session, [PackageSyncService]
/// would treat every existing campaign-side row as orphaned (its
/// `package_entity_id` no longer matches any pack row) and delete them
/// in the remove sweep, then re-insert from the pack with new ids —
/// stranding any open EntityCard tab on a now-invalid entity id.
const _srdNamespaceUuid = '6e7d2a4a-2c2d-4d2c-8a3a-7f0c1b2c3d4e';

/// Deterministic v5 UUID for an SRD pack entity keyed on `slug:name`. Shared
/// by `buildSrdCorePack` (Tier-1 ids) and `SrdCorePackageBootstrap` (Tier-0
/// mirror rows) so both tiers land in `package_entities` with stable ids.
String srdStableEntityId(String slug, String name) =>
    _uuid.v5(_srdNamespaceUuid, '$slug:$name');

/// Returns the per-slug raw row lists the pack ships, in stable order.
/// Order matters for deterministic UUID assignment when needed.
///
/// Public so content tests can inspect what the authoring functions produce
/// *before* [buildSrdCorePack] mints ids and resolves refs — in particular to
/// pin the output of [wireFeatureGrants]. Each call returns fresh maps, so
/// callers may mutate freely.
Map<String, List<Map<String, dynamic>>> srdRawRowsBySlug() => {
      // Tier-1 slugs that don't depend on other Tier-1 rows.
      'weapon': srdWeapons(),
      'armor': srdArmor(),
      'tool': srdTools(),
      'adventuring-gear': srdAdventuringGear(),
      'ammunition': srdAmmunition(),
      'mount': srdMounts(),
      'vehicle': srdVehicles(),
      // First-tier dependencies (refs gear/weapons/armor).
      'pack': srdPacks(),
      // Identity-content groups. Class/subclass auto-grant feats + per-
      // feature option feats (Metamagic, Eldritch Invocations, Pact Boon,
      // Draconic Spells, Fiendish Resilience, Hunter Ranger picks) are
      // authored in feats_class.dart and folded into the same 'feat' slug so
      // `wireFeatureGrants` can hang each one off its Class/Subclass level row
      // and the PendingChoiceKind.featureOption dialog filter finds the options.
      // srdSubclassFeats() also holds every Feature-Option feat at the
      // tail of its list — without it the option dialog renders empty.
      'feat': [
        ...srdFeats(),
        ...srdClassFeats(),
        ...srdSubclassFeats(),
      ],
      'species': srdSpecies(),
      'subspecies': srdSubspecies(),
      'background': srdBackgrounds(),
      // Spells reference classes for `class_refs`, so spells need classes
      // available at resolve time. Both blocks live in the pack so it's fine.
      'spell': srdSpells(),
      'class': srdClasses(),
      'subclass': srdSubclasses(),
      // Trait + creature-action catalogues consumed by monsters.
      'trait': srdTraits(),
      'creature-action': srdCreatureActions(),
      'monster': srdMonsters(),
      'animal': srdAnimals(),
      'magic-item': srdMagicItems(),
      // SRD 5.2.1 omits the d100 trinket table — `trinket` slug intentionally
      // not populated.
    };

/// Build the in-memory SRD pack. Walks all per-slug authoring functions,
/// assigns UUIDs in deterministic order, then resolves every `_ref`
/// placeholder against the freshly minted UUIDs.
///
/// `_lookup` placeholders for Tier-0 categories are left in place — the
/// bootstrap service resolves them at import time once it knows the
/// campaign's Tier-0 row UUIDs.
SrdCorePack buildSrdCorePack() {
  final raw = srdRawRowsBySlug();

  // Pass 0: move every class/subclass-feature feat's placement onto the
  // source card, so "Paladin gains this at level 9" is stored once — on the
  // Paladin card's `features` row — instead of on the feat.
  wireFeatureGrants(raw);

  // Pass 1: mint deterministic UUIDv5s keyed on "slug:name". Stable across
  // sessions so installed-campaign foreign keys (package_entity_id) keep
  // resolving — see `_srdNamespaceUuid` doc for the failure mode this
  // prevents. Track `(slug, name) -> uuid` so pass 2 can resolve inter-row
  // `_ref` placeholders.
  final entities = <String, dynamic>{};
  final refIndex = <String, Map<String, String>>{};
  for (final entry in raw.entries) {
    final slug = entry.key;
    final slugIndex = refIndex.putIfAbsent(slug, () => <String, String>{});
    for (final row in entry.value) {
      final name = row['name'] as String?;
      // Fallback for nameless rows: position-based key so two unnamed rows
      // in the same slug don't collide.
      final key = name ?? 'row-${slugIndex.length}';
      final id = srdStableEntityId(slug, key);
      // Ids are `slug:name` derived, so two rows sharing a name silently
      // overwrite each other — the later one wins and the earlier feature
      // vanishes from the pack with no error anywhere. This shipped twice
      // ("Uncanny Dodge", "Fiendish Vigor") before anyone noticed.
      if (entities.containsKey(id)) {
        throw StateError('duplicate SRD entity "$slug:$key" — pack ids are '
            'derived from the name, so one row would overwrite the other');
      }
      entities[id] = row;
      if (name != null) slugIndex[name] = id;
    }
  }

  // Pass 2: walk every entity's `attributes` map and rewrite `_ref`
  // placeholders to UUIDs. `_lookup` placeholders are left untouched.
  for (final id in entities.keys.toList()) {
    final row = entities[id] as Map<String, dynamic>;
    final attrs = row['attributes'];
    if (attrs is Map) {
      row['attributes'] =
          _resolveRefs(Map<String, dynamic>.from(attrs), refIndex);
    }
  }

  final metadata = <String, dynamic>{
    'attribution': srdAttribution,
    'license': srdLicense,
    'source': srdSourceTag,
    'pack_version': srdCorePackVersion,
  };

  return SrdCorePack(entities: entities, metadata: metadata);
}

/// Rewrite each class/subclass-feature feat's build-time
/// [srdFeatureGrantKey] marker into a `granted_feat_refs` entry on the
/// matching `features` row of its Class / Subclass card, then strip the
/// marker. After this runs no feat carries any notion of who grants it —
/// the class card owns the level, which is the single place a DM edits it.
///
/// Throws when the marker names a Class / Subclass card that does not exist.
///
/// Two kinds of pre-existing disagreement between the class tables and the
/// feature feats surface here, and both are resolved in favour of the **feat's**
/// level, because that is the level the resolver applied before this inversion
/// — so resolved sheets come out byte-identical and only the displayed table
/// changes:
///
///  * row exists under that name at a different level → the row moves;
///  * no row at all → one is synthesized from the feat.
///
/// Returns a `"Class L9 Feature"` descriptor for each row it had to move or
/// synthesize. `srd_core_content_validation_test` pins that list, so a new
/// mismatch (or a typo in `featureName:`) fails loudly instead of quietly
/// growing the class table.
List<String> wireFeatureGrants(Map<String, List<Map<String, dynamic>>> raw) {
  final drifted = <String>[];
  final cards = <String, Map<String, Map<String, dynamic>>>{
    for (final slug in const ['class', 'subclass'])
      slug: {
        for (final row in raw[slug] ?? const <Map<String, dynamic>>[])
          row['name'] as String: row,
      },
  };

  for (final feat in raw['feat'] ?? const <Map<String, dynamic>>[]) {
    final marker = feat.remove(srdFeatureGrantKey);
    if (marker is! Map) continue;
    final source = marker['source'] as String;
    final sourceName = marker['source_name'] as String;
    final featureName = marker['feature_name'] as String;
    final atLevel = marker['at_level'] as int;

    final card = cards[source]?[sourceName];
    if (card == null) {
      throw StateError('feat "${feat['name']}" names a missing '
          '$source "$sourceName"');
    }
    final attrs = card['attributes'] as Map<String, dynamic>;
    final features = (attrs['features'] as List?)?.cast<Map<String, dynamic>>();
    if (features == null) {
      throw StateError('$source "$sourceName" has no `features` table, so '
          'feat "${feat['name']}" has nowhere to hang');
    }

    var row = features
        .cast<Map<String, dynamic>?>()
        .firstWhere((r) => r!['name'] == featureName, orElse: () => null);
    if (row == null) {
      row = <String, dynamic>{
        'level': atLevel,
        'name': featureName,
        'description': feat['description'] ?? '',
      };
      features.add(row);
      drifted.add('$sourceName L$atLevel "$featureName" (satır yoktu, eklendi)');
    } else if (row['level'] != atLevel) {
      drifted.add('$sourceName "$featureName" '
          'L${row['level']} → L$atLevel (feat seviyesine hizalandı)');
      row['level'] = atLevel;
    }
    final refs =
        (row['granted_feat_refs'] ??= <Map<String, dynamic>>[]) as List;
    final edge = ref('feat', feat['name'] as String);
    if (!refs.any((r) => r is Map && r['name'] == edge['name'])) {
      refs.add(edge);
    }
  }
  return drifted;
}

/// Walk a value and rewrite every `{'_ref': slug, 'name': X}` placeholder
/// to the matching UUID from [refIndex]. Returns the rewritten value.
/// Unknown refs become empty strings (caught by the integrity test).
dynamic _resolveRefs(
    dynamic value, Map<String, Map<String, String>> refIndex) {
  if (value is Map) {
    final ref = value['_ref'];
    final name = value['name'];
    if (ref is String && name is String) {
      return refIndex[ref]?[name] ?? '';
    }
    return value
        .map((k, v) => MapEntry(k, _resolveRefs(v, refIndex)));
  }
  if (value is List) {
    return value.map((e) => _resolveRefs(e, refIndex)).toList();
  }
  return value;
}
