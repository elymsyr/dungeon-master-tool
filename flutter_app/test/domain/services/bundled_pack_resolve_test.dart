import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/application/character_creation/pending_choices.dart';
import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/application/services/package_import_service.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/character/effective_character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:dungeon_master_tool/domain/services/entity_ref.dart';
import 'package:flutter_test/flutter_test.dart';

/// One card attached to a throwaway character, resolved. [resolveAt] re-runs
/// the same attachment at another class level — what a level gate needs to be
/// proven rather than asserted.
class _Probe {
  _Probe(this.card, this._resolve);

  final Entity card;
  final EffectiveCharacter? Function(int level) _resolve;

  late final EffectiveCharacter? _base = _resolve(20);

  bool get attached => _base != null;
  EffectiveCharacter get eff => _base!;
  EffectiveCharacter resolveAt(int level) => _resolve(level)!;
}

const _abilityAbbrevs = <String, String>{
  'strength': 'STR', 'dexterity': 'DEX', 'constitution': 'CON',
  'intelligence': 'INT', 'wisdom': 'WIS', 'charisma': 'CHA', //
};

String? _abbrev(String abilityName) =>
    _abilityAbbrevs[abilityName.trim().toLowerCase()];

/// **The bundled third-party packs actually resolve.**
///
/// `grant_contract_test` proves no bundled asset still ships a retired DSL row.
/// That is a statement about the file, not about the app: a pack could be free
/// of legacy keys and still grant nothing, because its `_lookup` placeholders
/// point at Tier-0 rows that do not exist, or because the converted field name
/// is one the resolver never reads.
///
/// This file closes that gap for the three packs `tool/migrate_pack_assets.dart`
/// rewrote. It walks the asset the way an install does — resolve every
/// `{_lookup, name}` placeholder against the campaign's Tier-0 rows, then hand
/// the entity to `CharacterResolver` — and asserts the mechanic lands on the
/// sheet.
void main() {
  final srd = buildBuiltinSrdEntities();

  /// `tier0NameToId[slug][rowName] = uuid`, exactly the map
  /// `PackageImportService` builds at import time.
  final tier0 = <String, Map<String, String>>{};
  for (final e in srd.values) {
    tier0.putIfAbsent(e.categorySlug, () => <String, String>{})[e.name] = e.id;
  }

  /// Load a bundled pack and return its rows as [Entity]s with placeholders
  /// resolved, keyed by a synthetic id — i.e. what lands in the world after an
  /// install.
  Map<String, Entity> installPack(String assetName) {
    final file = File('assets/open5e_packs/$assetName');
    expect(file.existsSync(), isTrue, reason: 'missing asset $assetName');
    final root = jsonDecode(file.readAsStringSync()) as Map;
    final entities = root['entities'] as Map;
    final out = <String, Entity>{};
    entities.forEach((id, raw) {
      final row = raw as Map;
      final attrs = Map<String, dynamic>.from(
          (row['attributes'] as Map?) ?? const <String, dynamic>{});
      final resolved = <String, dynamic>{
        for (final e in attrs.entries)
          e.key: PackageImportService.resolveLookupPlaceholder(e.value, tier0),
      };
      out['$id'] = Entity(
        id: '$id',
        categorySlug: row['type']?.toString() ?? '?',
        name: row['name']?.toString() ?? '',
        fields: resolved,
      );
    });
    return out;
  }

  /// A subspecies names its parent as a cross-pack soft ref (`{slug, name}`),
  /// resolved by name at runtime — not by `resolveLookupPlaceholder`, which
  /// only rewrites Tier-0 `_lookup` envelopes. The wizard stores the id it
  /// resolves to, so the test has to do the same.
  String parentSpeciesId(Map<String, Entity> world, Entity sub) {
    final id = resolveEntityRef(sub.fields['parent_species_ref'], world);
    expect(id, isNotNull,
        reason: '${sub.name}: parent species '
            '${sub.fields['parent_species_ref']} is not installed');
    return id!;
  }

  Entity find(Map<String, Entity> world, String slug, String name) =>
      world.values.firstWhere(
        (e) => e.categorySlug == slug && e.name == name,
        orElse: () => throw StateError('missing $slug/$name'),
      );

  Character pc(Map<String, dynamic> fields) => Character(
        id: 'pc1',
        templateId: 'tpl',
        templateName: 'Tpl',
        worldId: 'w',
        createdAt: '0',
        updatedAt: '0',
        entity: Entity(id: 'pc1_e', categorySlug: 'player', fields: {
          'base_abilities': const {
            'STR': 10, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 10, 'CHA': 10, //
          },
          ...fields,
        }),
      );

  group('open5e-toh (converted ability_score_bonus rows)', () {
    late final world = {...srd, ...installPack('open5e-toh.pkg.json')};

    test('Alseid grants DEX +2 / WIS +1 and Stealth proficiency', () {
      final alseid = find(world, 'species', 'Alseid');
      final eff = CharacterResolver.resolve(
        pc({'race_id': alseid.id}),
        world,
      );
      expect(eff.effectiveAbilities['DEX'], 12);
      expect(eff.effectiveAbilities['WIS'], 11);
      expect(eff.proficiencies.skillIds.map((i) => world[i]?.name),
          contains('Stealth'));
      expect(eff.warnings, isEmpty);
    });

    test('every converted species/subspecies bumps at least one ability', () {
      // 35 rows were converted; a silent failure would show up as a species
      // whose `ability_bonuses` map resolved to nothing.
      var checked = 0;
      for (final e in world.values) {
        if (e.categorySlug != 'species' && e.categorySlug != 'subspecies') {
          continue;
        }
        final bonuses = e.fields['ability_bonuses'];
        if (bonuses is! Map || bonuses.isEmpty) continue;
        checked++;
        final eff = e.categorySlug == 'species'
            ? CharacterResolver.resolve(pc({'race_id': e.id}), world)
            : CharacterResolver.resolve(
                pc({
                  'race_id': parentSpeciesId(world, e),
                  'subspecies_id': e.id,
                }),
                world,
              );
        final bumped = eff.effectiveAbilities.entries
            .where((x) => x.value != 10)
            .length;
        expect(bumped, greaterThan(0),
            reason: '${e.categorySlug}/${e.name} granted no ability bonus');
      }
      expect(checked, greaterThanOrEqualTo(30),
          reason: 'found too few converted rows to mean anything');
    });
  });

  group('open5e-a5e-ag (converted feat effect rows)', () {
    late final world = {...srd, ...installPack('open5e-a5e-ag.pkg.json')};

    test('Heavily Outfitted grants heavy armor proficiency', () {
      final feat = find(world, 'feat', 'Heavily Outfitted');
      final eff = CharacterResolver.resolve(
        pc({'feat_ids': [feat.id]}),
        world,
      );
      expect(eff.proficiencies.armorCategoryIds.map((i) => world[i]?.name),
          contains('Heavy'));
      expect(eff.warnings, isEmpty);
    });

    test('Moderately Outfitted grants both Medium and Shield', () {
      final feat = find(world, 'feat', 'Moderately Outfitted');
      final eff = CharacterResolver.resolve(
        pc({'feat_ids': [feat.id]}),
        world,
      );
      final names =
          eff.proficiencies.armorCategoryIds.map((i) => world[i]?.name).toList();
      expect(names, containsAll(['Medium', 'Shield']));
    });

    test('Crafting Expert still queues its deferred pick', () {
      // `choice_group` → `player_choices`: the row survives conversion in a
      // shape `pending_choices.dart` understands.
      final feat = find(world, 'feat', 'Crafting Expert');
      final rows = feat.fields['player_choices'];
      expect(rows, isA<List>());
      final row = (rows as List).single as Map;
      expect(row['pick'], 2);
      expect(row['pick_kind'], 'skill_or_tool');
      expect(row['group_id'], isNotEmpty);
    });
  });

  group('open5e-open5e (converted subspecies row)', () {
    late final world = {...srd, ...installPack('open5e-open5e.pkg.json')};

    test('Stoor Halfling grants CON +1', () {
      final sub = find(world, 'subspecies', 'Stoor Halfling');
      final eff = CharacterResolver.resolve(
        pc({
          'race_id': parentSpeciesId(world, sub),
          'subspecies_id': sub.id,
        }),
        world,
      );
      expect(eff.effectiveAbilities['CON'], 11);
    });
  });

  // L3: a magic item names the mundane weapon/armor it is built on with a
  // softRef into the built-in pack. The pack ships no base items itself, so
  // every one of these has to land on a built-in card or the link is dead.
  group('open5e-vom (base_item_ref)', () {
    late final pack = installPack('open5e-vom.pkg.json');
    late final world = {...srd, ...pack};

    test('her base_item_ref gömülü bir temel eşyaya çözülür', () {
      const allowed = {'weapon', 'armor', 'adventuring-gear'};
      final withRef = <Entity>[
        for (final e in pack.values)
          if (e.fields['base_item_ref'] != null) e,
      ];
      expect(withRef, hasLength(379));
      final broken = <String>[];
      for (final item in withRef) {
        final id = resolveEntityRef(item.fields['base_item_ref'], world);
        final target = id == null ? null : world[id];
        if (target == null || !allowed.contains(target.categorySlug)) {
          broken.add('${item.name} → ${item.fields['base_item_ref']}');
        }
      }
      expect(broken, isEmpty);
    });

    test('Akaasit Blade temel eşya olarak Dagger gösterir', () {
      final blade = find(world, 'magic-item', 'Akaasit Blade');
      final base =
          world[resolveEntityRef(blade.fields['base_item_ref'], world)];
      expect(base?.name, 'Dagger');
      expect(base?.categorySlug, 'weapon');
    });
  });

  // ── M1 — every mechanic field in every bundled pack lands on a sheet ────
  //
  // The groups above are hand-picked cards. This one is data-driven: it walks
  // all bundled assets, collects every (pack, category, field) triple the asset
  // actually writes on a **player-facing** card, and requires each one to either
  // produce a visible effect on `EffectiveCharacter` or be declared
  // non-resolver with the reader that owns it. An undeclared field fails the
  // run, so a new mapper field cannot land untested.
  //
  // Statblock categories are deliberately out of scope. `monster` writes
  // `speed_fly_ft` (807 rows), `trait_refs` (2,713) and the other movement keys
  // — the same names the grant block uses — but a monster is never handed to
  // `CharacterResolver`, and its traits are owned children (§2.5). Counting
  // those as "mechanic fields" would make the sweep look 20× bigger than the
  // chargen surface actually is.
  group('M1 — pack mechanics reach EffectiveCharacter', () {
    const playerFacing = {
      'species', 'subspecies', 'feat', 'class', 'subclass', 'background',
      'magic-item', //
    };

    /// Fields whose reader is not the resolver. The value names the reader, so
    /// "no sheet assertion" is a recorded decision rather than an omission.
    const notResolverRead = <String, String>{
      'description': 'prose — entity_card / wizard detail panes',
      'category_ref': 'feat grouping in feats_step',
      'prerequisite': 'feats_step gating text',
      'prereq_ability_ref': 'feats_step gating',
      'prereq_clauses': 'feats_step gating',
      'prereq_min_character_level': 'feats_step gating',
      'prereq_min_score': 'feats_step gating',
      'prereq_requires_spellcasting': 'feats_step gating',
      'caster_kind': 'spells_step + level_up_planner',
      // M4 — the three per-level spellcasting tables. Their reader is
      // `caster_progression.dart`, called at wizard commit and by the level-up
      // planner; the grid it returns is stored on the character's own
      // `spell_slots` field, so it never passes through the resolver. No
      // bundled pack writes them today (0 of 2 packaged class cards, both
      // `caster_type: NONE` upstream) — measured and pinned by
      // `test/application/character_creation/spell_slot_grid_reach_test.dart`,
      // which also fails the day a pack ships one.
      'spell_slots_by_level':
          'caster_progression.spellSlotsForClass → wizard commit + level_up_planner',
      'cantrips_known_by_level':
          'caster_progression.levelTableValue → spells_step cantrip cap',
      'prepared_spells_by_level':
          'caster_progression.levelTableValue → spells_step prepared cap',
      'hit_die': 'HP math in the wizard / character_editor (hitDieFaces)',
      'skill_proficiency_choice_count': 'proficiencies_step choice UI',
      'skill_proficiency_options': 'proficiencies_step choice UI',
      'granted_tool_variant_group': 'proficiencies_step tool-variant picker',
      'creature_type_ref': 'entity_card',
      'size_ref': 'wizard seed + entity_card',
      'speed_ft': 'walk speed is read off the species card by the wizard; the '
          'resolver touches it only to expand the -1 "= walking speed" sentinel',
      'base_item_ref': 'asserted by the open5e-vom group above',
      'effects': 'declared non-mechanical by M3 — no reader in domain/',
      'activation': 'no reader — display-only magic-item metadata',
      'magic_category_ref': 'database filter',
      'rarity_ref': 'database filter + entity_card',
      'requires_attunement': 'entity_card',
      'weight_lb': 'inventory weight display',
      // R4 shipped the writer (a5e-ag Tenacious); the reader is the choice
      // dialog, which turns the player's picked ability into a save
      // proficiency the moment the ASI is resolved — the card itself names no
      // ability, so there is nothing for the resolver to apply.
      'grants_save_prof_from_asi':
          'pending_choice_resolver_dialog — applied with the chosen ability',
    };

    /// Fields the assets write that **nothing** reads. Asserted as a closed set
    /// so filling one, or a mapper adding another, fails here first.
    const unreadByAnyone = <String, String>{
      'granted_language_count':
          'written on 24 backgrounds by chargen.dart; no reader in lib/ — and '
              'B7 decided it keeps none: the wizard already grants every '
              'character OriginConstants.standardLanguageChoiceCount (2) '
              'origin languages, which is the same allowance a pre-2024 '
              'background spells out, so wiring it would stack a second pool. '
              'Display-only on the card, deliberately inert (audit §5.8)',
    };

    /// One resolve, plus the ability to re-resolve the same card at another
    /// class level (what `granted_at_level` needs to prove its gate).
    final probes = <String, bool Function(_Probe)>{
      'ability_bonuses': (p) => p.eff.effectiveAbilities.values.any((v) => v != 10),
      'ability_score_options': (p) =>
          p.eff.effectiveAbilities.values.any((v) => v != 10),
      'asi_amount': (p) => p.eff.effectiveAbilities.values.any((v) => v != 10),
      // R5 / F-pass0-03. The fixed half of a background ASI is not a choice,
      // so it moves a score with nothing recorded on the character.
      'asi_fixed_ability_ref': (p) =>
          p.eff.effectiveAbilities.values.any((v) => v != 10),
      // Its companion is a ceiling, and a ceiling's only observable is that
      // shipped content stays under it: no card may resolve into its own
      // "too many free points" warning.
      'asi_free_bonus_count': (p) =>
          !p.eff.warnings.any((w) => w.contains('free points')),
      'asi_ability_options': (p) =>
          p.eff.effectiveAbilities.values.any((v) => v != 10),
      'asi_max_score': (p) =>
          p.eff.effectiveAbilities.values.every((v) => v <= 20),
      // B5/M2 — the rules no typed field could carry. Each source row is one
      // line, so "it arrived" is the card's own line count reaching the sheet.
      'mechanical_notes': (p) =>
          p.eff.mechanicalNotes.length >=
          '${p.card.fields['mechanical_notes']}'.split('\n').length,
      'granted_skill_proficiencies': (p) => p.eff.proficiencies.skillIds.isNotEmpty,
      'granted_skill_refs': (p) => p.eff.proficiencies.skillIds.isNotEmpty,
      'granted_tool_refs': (p) => p.eff.proficiencies.toolIds.isNotEmpty,
      'granted_armor_proficiencies': (p) =>
          p.eff.proficiencies.armorCategoryIds.isNotEmpty,
      'armor_training_refs': (p) =>
          p.eff.proficiencies.armorCategoryIds.isNotEmpty,
      'weapon_proficiency_categories': (p) =>
          p.eff.proficiencies.weaponCategoryIds.isNotEmpty,
      'saving_throw_refs': (p) =>
          p.eff.proficiencies.savingThrowAbilityIds.isNotEmpty,
      'granted_languages': (p) => p.eff.proficiencies.languageIds.isNotEmpty,
      'granted_damage_resistances': (p) => p.eff.damageResistanceIds.isNotEmpty,
      'granted_senses': (p) => p.eff.senseEntityIds.isNotEmpty,
      'granted_spell_refs': (p) => p.eff.grantedSpellIds.isNotEmpty,
      'granted_cantrip_refs': (p) => p.eff.grantedCantripIds.isNotEmpty,
      'speed_bonus_ft': (p) => p.eff.speedBonus != 0,
      'speed_fly_ft': (p) => p.eff.extraSpeeds.containsKey('fly'),
      'speed_swim_ft': (p) => p.eff.extraSpeeds.containsKey('swim'),
      'speed_climb_ft': (p) => p.eff.extraSpeeds.containsKey('climb'),
      'speed_burrow_ft': (p) => p.eff.extraSpeeds.containsKey('burrow'),
      'equipment_choice_groups': (p) => p.eff.inventory.isNotEmpty,
      'features': (p) =>
          p.eff.activeFeatures.any((r) => r.sourceEntityId == p.card.id),
      // A subclass's features are gated on the *parent class's* level, so the
      // ref is only proven by the gate opening at all.
      'parent_class_ref': (p) =>
          p.eff.activeFeatures.any((r) => r.sourceEntityId == p.card.id),
      'parent_species_ref': (p) => p.eff.effectiveAbilities.isNotEmpty,
      // The gate itself: present at L20, absent one level below the grant.
      'granted_at_level': (p) {
        bool has(EffectiveCharacter e) =>
            e.activeFeatures.any((r) => r.sourceEntityId == p.card.id);
        final at = p.card.fields['granted_at_level'] as int;
        if (!has(p.eff)) return false;
        return at <= 1 || !has(p.resolveAt(at - 1));
      },
      // Not a resolved stat by design (see `applyGrantsFrom`'s closing
      // comment) — the sheet effect is the queued pick, so probe its reader.
      'player_choices': (p) => seedFeatChoicePendings(
            feats: [p.card],
            existingFeatChoices: const {},
            level: 1,
          ).isNotEmpty,
    };

    /// `background_asi` needs an ability the card allows, `equipment_choices`
    /// needs one option per group — the resolver applies neither unless the
    /// character recorded a pick, so the probe records the first legal one.
    Map<String, dynamic> backgroundPicks(Entity bg, Map<String, Entity> world) {
      final out = <String, dynamic>{};
      final allowed = resolveEntityRefList(bg.fields['ability_score_options'], world)
          .map((id) => _abbrev(world[id]?.name ?? ''))
          .whereType<String>()
          .toList();
      // R5 / F-pass0-03: a card that declares how many free +1s it hands out
      // is recorded honestly — spending 2 on an A5E background (which allows
      // one, the other point being its fixed ability) is not a legal sheet.
      final free = bg.fields['asi_free_bonus_count'];
      if (allowed.isNotEmpty) {
        out['background_asi'] = {allowed.first: free is int && free > 0 ? free : 2};
      }
      final choices = <String, String>{};
      for (final g in (bg.fields['equipment_choice_groups'] as List? ?? const [])) {
        if (g is! Map) continue;
        final opts = g['options'];
        if (opts is! List || opts.isEmpty) continue;
        final first = opts.first;
        if (first is! Map) continue;
        choices['${bg.id}:${g['group_id']}'] = '${first['option_id']}';
      }
      if (choices.isNotEmpty) out['equipment_choices'] = choices;
      return out;
    }

    /// Attach [card] to a character the way the wizard would, at [level].
    Character? characterFor(Entity card, Map<String, Entity> world, int level) {
      switch (card.categorySlug) {
        case 'species':
          return pc({'race_id': card.id});
        case 'subspecies':
          final parent = resolveEntityRef(card.fields['parent_species_ref'], world);
          if (parent == null) return null;
          return pc({'race_id': parent, 'subspecies_id': card.id});
        case 'feat':
          return pc({'feat_ids': [card.id]});
        case 'class':
          return pc({'class_levels': {card.id: level}});
        case 'subclass':
          final parent = resolveEntityRef(card.fields['parent_class_ref'], world);
          if (parent == null) return null;
          return pc({
            'class_levels': {parent: level},
            'subclass_id': card.id,
          });
        case 'background':
          return pc({'background_id': card.id, ...backgroundPicks(card, world)});
        case 'magic-item':
          return pc({
            'inventory': [
              {'id': card.id, 'equipped': true},
            ],
          });
      }
      return null;
    }

    test('every (pack, mechanic field) pair produces a sheet effect', () {
      final assets = Directory('assets/open5e_packs')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.pkg.json'))
          .toList()
        ..sort();
      expect(assets, hasLength(19));

      final undeclared = <String>{};
      final unreadSeen = <String>{};
      final failures = <String>[];
      final partial = <String>[];
      var pairs = 0;
      var assertions = 0;

      for (final asset in assets) {
        final pack = installPack(asset);
        final world = {...srd, ...pack};

        // (category, field) → the cards in this pack that write it.
        final carriers = <String, List<Entity>>{};
        for (final e in pack.values) {
          if (!playerFacing.contains(e.categorySlug)) continue;
          e.fields.forEach((key, value) {
            if (value == null) return;
            if (value is String && value.isEmpty) return;
            if (value is Iterable && value.isEmpty) return;
            if (value is Map && value.isEmpty) return;
            if (value is num && value == 0) return;
            // `false` is the absent value for a flag, exactly like 0 and []:
            // vom writes `is_cursed`/`is_sentient` on all 1,063 items and
            // `repeatable` on every feat, never once true. The day one is, it
            // arrives here as an undeclared field.
            if (value is bool && !value) return;
            carriers.putIfAbsent('${e.categorySlug} $key', () => []).add(e);
          });
        }

        for (final entry in carriers.entries) {
          final field = entry.key.split(' ')[1];
          if (notResolverRead.containsKey(field)) continue;
          if (unreadByAnyone.containsKey(field)) {
            unreadSeen.add(field);
            continue;
          }
          final probe = probes[field];
          if (probe == null) {
            undeclared.add('$asset ${entry.key.replaceAll(' ', '.')}');
            continue;
          }
          pairs++;
          // Cap the sample: the pair only has to land once, and vom ships
          // 1,063 magic items.
          final cards = entry.value.take(5).toList();
          var passed = 0;
          for (final card in cards) {
            final probeCtx = _Probe(card, (lvl) {
              final ch = characterFor(card, world, lvl);
              if (ch == null) return null;
              return CharacterResolver.resolve(ch, world);
            });
            if (probeCtx.attached && probe(probeCtx)) passed++;
            assertions++;
          }
          if (passed == 0) {
            failures.add('$asset ${entry.key.replaceAll(' ', '.')} '
                '(${cards.map((c) => c.name).join(', ')})');
          } else if (passed < cards.length) {
            partial.add('$asset ${entry.key.replaceAll(' ', '.')}: '
                '$passed/${cards.length}');
          }
        }
      }

      // ignore: avoid_print
      print('M1: $pairs (pack, mechanic field) pairs, $assertions sheet '
          'assertions, ${partial.length} partial:\n  ${partial.join('\n  ')}');

      expect(undeclared, isEmpty,
          reason: 'field written by a pack with no sheet assertion and no '
              'entry in notResolverRead/unreadByAnyone — declare it');
      expect(failures, isEmpty,
          reason: 'mechanic field never reached the sheet');
      expect(unreadSeen, unreadByAnyone.keys.toSet(),
          reason: 'the "nothing reads this" list is stale — a field gained a '
              'reader, or the packs stopped writing one');
      expect(pairs, greaterThanOrEqualTo(40));
    });
  });

  group('placeholders in bundled packs point at rows that exist', () {
    test('no converted grant field resolves to an empty ref', () {
      // `resolveLookupPlaceholder` returns '' for a Tier-0 row the campaign
      // does not have — the grant then vanishes with no warning at install
      // time. Catch it here instead.
      final broken = <String>[];
      for (final asset in Directory('assets/open5e_packs')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.pkg.json'))) {
        final world = installPack(asset);
        for (final e in world.values) {
          for (final key in CharacterResolver.grantFieldKeys) {
            final v = e.fields[key];
            if (v is List && v.contains('')) {
              broken.add('$asset: ${e.categorySlug}/${e.name} → $key');
            }
          }
        }
      }
      expect(broken, isEmpty,
          reason: 'grant ref names a Tier-0 row the app does not ship');
    });
  });
}
