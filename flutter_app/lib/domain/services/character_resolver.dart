import '../entities/character.dart';
import '../entities/character/effective_character.dart';
import '../entities/entity.dart';
import 'entity_ref.dart';
import '../entities/schema/rule_config.dart';
import 'count_formula.dart';

/// Pure-function read-time resolver. Walks a [Character]'s raw choices
/// (`class_levels`, `subclass_id`, `feat_ids`, `equipment_choices`) and the
/// referenced source entities, then folds them into an [EffectiveCharacter]
/// that the editor / sheet can read for derived stats.
///
/// Stateless. Safe to call on every read. Not memoized at this layer; wrap
/// with a Riverpod `Provider.family` for caching.
class CharacterResolver {
  /// Every field key of the shared grant block (`_FB.grantBlock` in
  /// `builtin/content.dart`). This is the *complete* contract between an
  /// authored card and the resolved sheet — there is no effect DSL, no kind
  /// registry and no predicate language behind it. [applyGrantsFrom] is the
  /// single reader, so adding a mechanic means adding a key here and a line
  /// there.
  ///
  /// The one-shot data migration (`data/schema/rule_effects_migration.dart`)
  /// targets these keys when it converts pre-existing `rule_effects` /
  /// `granted_modifiers` rows, so keep the two in sync.
  static const Set<String> grantFieldKeys = {
    'active_while_state_ref',
    'granted_skill_proficiencies', 'granted_tool_proficiencies',
    'granted_save_proficiencies', 'granted_weapon_proficiencies',
    'granted_armor_proficiencies', 'granted_expertise_skills',
    'granted_languages',
    'granted_spell_refs', 'granted_cantrip_refs', 'always_prepared_spell_refs',
    'granted_spells_at_level',
    'ability_bonuses', 'ability_bonus_cap', 'ac_bonus', 'speed_bonus_ft',
    'initiative_bonus',
    'hp_bonus_flat', 'hp_bonus_per_level',
    'extra_attack_count', 'extra_attack_count_by_level', 'crit_threshold',
    'weapon_mastery_count',
    'unarmored_ac_base', 'unarmored_ac_abilities',
    'unarmored_ac_shield_allowed',
    'granted_damage_resistances', 'granted_damage_immunities',
    'granted_damage_vulnerabilities', 'granted_condition_immunities',
    'granted_senses',
    'speed_fly_ft', 'speed_swim_ft', 'speed_climb_ft', 'speed_burrow_ft',
    'granted_action_refs', 'granted_bonus_action_refs', 'granted_reaction_refs',
    'trait_refs',
    'resource_pool_grants', 'player_choices',
    'mechanical_notes',
  };

  /// Grant keys that can meaningfully surface as a *conditional* grant when the
  /// card sets `active_while_state_ref` (e.g. Rage's resistances). Everything
  /// else on a state-gated card is roll-time behaviour the sheet cannot
  /// pre-compute, so it stays out of the unconditional totals and is surfaced
  /// through `mechanical_notes` instead.
  static const Map<String, String> _conditionalGrantKinds = {
    'granted_damage_resistances': 'damage_resistance',
    'granted_damage_immunities': 'damage_immunity',
    'granted_damage_vulnerabilities': 'damage_vulnerability',
    'granted_condition_immunities': 'condition_immunity_grant',
  };

  /// Resolve [pc] against the campaign-wide entity map [entitiesById].
  ///
  /// Missing references are silently dropped and surfaced in
  /// [EffectiveCharacter.warnings] for debug display.
  static EffectiveCharacter resolve(
    Character pc,
    Map<String, Entity> entitiesById, {
    RuleConfig config = RuleConfig.dnd5eDefaults,
  }) {
    final fields = pc.entity.fields;
    final warnings = <String>[];

    // ── 1. Raw choice reads ─────────────────────────────────────────────
    // `feat_ids` / `race_id` / `background_id` / `subclass_id` wizard'ın
    // yazdığı **id-anahtarlı** seçim alanları. Blueprint ya da paket
    // kaynaklı bir PC bunları taşımaz; elinde yalnız şemanın relation
    // alanları vardır (`feats`, `species_ref`, `background_ref`,
    // `subclass_refs`). Karşılığı okunmazsa sınıf/tür/background hiç
    // uygulanmaz — kart sınıf özelliği, trait ve yetkinlik olmadan çözülür.
    //
    var featIds = _readStringList(fields['feat_ids']);
    if (featIds.isEmpty) {
      featIds = resolveEntityRefList(fields['feats'], entitiesById);
    }
    final equipmentChoices = _readStringMap(fields['equipment_choices']);
    final subclassRefs =
        resolveEntityRefList(fields['subclass_refs'], entitiesById);
    final subclassId = _readNullableString(fields['subclass_id']) ??
        (subclassRefs.isEmpty ? null : subclassRefs.first);
    final classLevels = _resolveClassLevels(fields['class_levels'], entitiesById);
    final raceId = _readNullableString(fields['race_id']) ??
        resolveEntityRef(fields['species_ref'], entitiesById);
    final subspeciesId = _readNullableString(fields['subspecies_id']);
    final backgroundId = _readNullableString(fields['background_id']) ??
        resolveEntityRef(fields['background_ref'], entitiesById);
    // `base_abilities` yoksa `stat_block`. Boş bırakılınca resolver tüm
    // yetenekleri 10 varsayıyor; AC, spell save DC, initiative ve beceri
    // modifikatörlerinin hepsi bundan türediği için paket kaynaklı bir PC
    // DEX 16 ile 11 AC gösteriyordu. Yalnız `base_abilities` boşken
    // devreye girer — kartın kendi kaydı her zaman kazanır.
    //
    // Not: bir background `asi_fixed_ability_ref` taşıyorsa (SRD'de yok,
    // yalnız üçüncü parti içerikte olabilir) o +1 zaten nihai olan
    // `stat_block`'un üstüne biner.
    var baseAbilities = _readIntMap(fields['base_abilities']);
    if (baseAbilities.isEmpty) baseAbilities = _readIntMap(fields['stat_block']);
    // Per-feat recorded ASI ability picks: `{featId: {ABBR: amount}}`. When a
    // feat with `asi_amount > 0` has a recorded pick the resolver applies it
    // verbatim (honoring the user's choice) instead of the first-option
    // heuristic. Absent → heuristic fallback (legacy / not-yet-resolved).
    final featAsiChoices = fields['feat_asi_choices'];

    // ── 2. Pass 1: class + subclass features by level ──────────────────
    // Narrative rows only — mechanics live on the auto-granted Feat/Trait
    // cards (Pass 4b), never inline on the class's features table.
    final activeFeatures = <ResolvedFeatureRow>[];

    for (final entry in classLevels.entries) {
      final classEntity = entitiesById[entry.key];
      if (classEntity == null) {
        warnings.add('Missing class entity ${entry.key}');
        continue;
      }
      _collectFeaturesByLevel(classEntity, entry.value, activeFeatures);
    }
    if (subclassId != null) {
      final sub = entitiesById[subclassId];
      if (sub != null) {
        // SRD §1.10: subclass features gate on the *parent class's* level,
        // not the character's total or max-of-all-classes level. Look up
        // parent_class_ref, find its current level in classLevels, fall
        // back to the max heuristic only when the ref is missing.
        final parentRef = sub.fields['parent_class_ref'];
        final parentId = _resolveRef(parentRef, entitiesById);
        var gateLevel = 0;
        if (parentId != null && classLevels.containsKey(parentId)) {
          gateLevel = classLevels[parentId] ?? 0;
        } else {
          gateLevel = classLevels.values.fold<int>(0, (a, b) => a > b ? a : b);
        }
        final grantedAt = (sub.fields['granted_at_level'] is int)
            ? sub.fields['granted_at_level'] as int
            : 1;
        if (gateLevel >= grantedAt) {
          _collectFeaturesByLevel(sub, gateLevel, activeFeatures);
        }
      }
    }

    // ── 4. Working accumulators ────────────────────────────────────────
    final abilities = Map<String, int>.from(baseAbilities.isEmpty
        ? const {'STR': 10, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 10, 'CHA': 10}
        : baseAbilities);
    var acBonus = 0;
    var speedBonus = 0;
    final extraSpeeds = <String, int>{};
    var hpBonusFlat = 0;
    var hpBonusPerLevel = 0;
    var initiativeBonus = 0;
    var extraAttackCount = 0; // multiclass takes max, not sum
    var critRangeMin = 20;
    final grantedSpellIds = <String>[];
    final grantedCantripIds = <String>[];
    final senses = <String>[];
    final senseRanges = <String, int>{};
    final conditionalGrants = <Map<String, dynamic>>[];
    final damageRes = <String>[];
    final damageImmunities = <String>[];
    final damageVulnerabilities = <String>[];
    final conditionImmunities = <String>[];
    // Creature-action IDs picked up from species/subspecies grant fields.
    // Populated in Pass 5; surfaced separately so the sheet can render them
    // under the Actions section.
    final grantedActionIds = <String>[];
    final grantedBonusActionIds = <String>[];
    final grantedReactionIds = <String>[];
    // id → ordered list of source names (deduped). Populated everywhere a
    // grant lands on senses/damageRes/damageImmunities/damageVulnerabilities/
    // conditionImmunities so the sheet can render "<Grant> — <Source>".
    final grantSources = <String, List<String>>{};
    // Strip the `kind:` prefix that `applyGrantsFrom` call sites pass
    // (`species:Dwarf`, `feat:Magic Initiate`, `subspecies:Dwarf/Hill`) so
    // the chip subtitle stays clean. Subspecies tags become "Hill Dwarf".
    String cleanSource(String s) {
      if (s.isEmpty) return s;
      final colon = s.indexOf(':');
      if (colon < 0) return s;
      final rest = s.substring(colon + 1);
      final slash = rest.indexOf('/');
      if (slash > 0) {
        return '${rest.substring(slash + 1)} ${rest.substring(0, slash)}';
      }
      return rest;
    }
    void noteSource(String id, String source) {
      final clean = cleanSource(source);
      if (clean.isEmpty) return;
      final list = grantSources.putIfAbsent(id, () => <String>[]);
      if (!list.contains(clean)) list.add(clean);
    }

    final expertiseSkills = <String>[];
    final alwaysPreparedSpells = <String>[];
    final unarmoredFormulas = <Map<String, dynamic>>[];
    final resourcePools = <Map<String, dynamic>>[];
    final skills = <String>[];
    final tools = <String>[];
    final saves = <String>[];
    final languages = <String>[];
    final weaponCats = <String>[];
    final armorCats = <String>[];

    final mechanicalNotes = <String>[];
    var weaponMasteryCount = 0;
    // Feats / traits pulled in by the auto-grant walker (Pass 3). Declared here
    // because `applyGrantsFrom` writes `trait_refs` into the trait list.
    final autoGrantedFeatIds = <String>[];
    final autoGrantedTraitIds = <String>[];

    /// Read an ability relation-list field down to `STR`/`DEX`/… abbreviations.
    /// Ids, `{_lookup, name}` envelopes and plain ability names all appear in
    /// this shape depending on where the card came from — see
    /// [abilityAbbrevFromRef].
    List<String> abilityAbbrevs(Object? raw) {
      final out = <String>[];
      if (raw is! List) return out;
      for (final entry in raw) {
        final abbrev = abilityAbbrevFromRef(entry, entitiesById);
        if (abbrev != null && !out.contains(abbrev)) out.add(abbrev);
      }
      return out;
    }

    /// Fold one `granted_senses` row. Accepts the current
    /// `{sense_ref, range_ft}` shape and a bare ref (a sense with no stated
    /// range), so hand-authored and migrated data both read cleanly. The
    /// largest range per sense wins — Drow's Superior Darkvision 120 beats the
    /// base 60.
    void addSense(Object? row, String src) {
      Object? refRaw = row;
      int range = 0;
      if (row is Map) {
        refRaw = row['sense_ref'] ?? row['ref'];
        range = _intOf(row['range_ft']);
      }
      final id = _resolveRef(refRaw, entitiesById);
      if (id == null) return;
      if (!senses.contains(id)) senses.add(id);
      noteSource(id, src);
      if (range > 0 && range > (senseRanges[id] ?? 0)) senseRanges[id] = range;
    }

    /// Resolve a `{lvl: value}` level table down to the value for the highest
    /// level not above the character's. [classRef] scopes the lookup to that
    /// class's level; absent, total character level is used. This is what
    /// makes Fighter's Extra Attack (5→2, 11→3, 20→4) and Barbarian's Rage
    /// uses (1→2, 3→3, 6→4, …) work without a scaling DSL.
    int? valueForLevel(Object? table, {Object? classRef}) {
      if (table is! Map) return null;
      var lookupLvl = classLevels.values.fold<int>(0, (a, b) => a + b);
      if (classRef != null) {
        final classId = _resolveRef(classRef, entitiesById);
        if (classId == null) return null;
        lookupLvl = classLevels[classId] ?? 0;
      }
      int? best;
      var bestLvl = -1;
      for (final e in table.entries) {
        final lvl = _intOf(e.key is int ? e.key : int.tryParse(e.key.toString()));
        if (lvl <= lookupLvl && lvl > bestLvl) {
          bestLvl = lvl;
          best = _intOf(e.value);
        }
      }
      return best;
    }

    /// Fold a card's `resource_pool_grants` rows into [resourcePools].
    /// Max = level table, else `count_formula` (cha_mod_min_1 and friends),
    /// else the flat `count`. Runtime tracks the remaining value.
    void applyResourcePools(Map<String, dynamic> f) {
      for (final row in _readMapList(f['resource_pool_grants'])) {
        final scaled =
            valueForLevel(row['count_by_level'], classRef: row['class_ref']);
        final formula = evalCountFormula(
          row['count_formula']?.toString(),
          abilities: abilities,
          classLevels: classLevels,
          entitiesById: entitiesById,
        );
        resourcePools.add(<String, dynamic>{
          // Havuz kimliği id'ye çözülür. Built-in SRD haritasında `_lookup`
          // zarfları zaten id'ye dönmüş geliyor, pakete/blueprint'e dayanan
          // içerikte `{_lookup|slug, name}` olarak kalabiliyor — ham
          // bırakılınca sayfa satırı String beklediği için havuz sessizce
          // düşüyordu, yani aynı sınıf nereden geldiğine göre farklı
          // görünüyordu. Çözülemeyen değer aynen kalır.
          'pool_ref': _resolveRef(row['pool_ref'], entitiesById) ??
              row['pool_ref'],
          'max': scaled ?? formula ?? row['count'],
          'recharge': row['recharge'],
        });
      }
    }

    /// Apply everything a card grants to the working accumulators.
    ///
    /// [f] is a card's raw `fields` map. Feat, Trait, Magic Item, Species,
    /// Subspecies and the nested `subspecies_options` rows all speak the same
    /// grant-block keys ([grantFieldKeys]), so this one reader covers every
    /// source — there is no per-source effect interpreter behind it.
    ///
    /// When the card sets `active_while_state_ref` its grants are *conditional*:
    /// the four defense keys land in [conditionalGrants] so the sheet can draw
    /// them as "while raging" chips, and the rest are skipped — a state-gated
    /// numeric bonus must not be folded into a resting sheet total. Runtime
    /// flips the state and the sheet re-resolves.
    void applyGrantsFrom(Map<String, dynamic> f, String src) {
      // The gating tag is the state entity's *name* (`state:raging`) — that is
      // what runtime `active_states[]` stores and what the sheet's
      // "(while raging)" chips display. Fall back to the raw ref for
      // unresolvable/legacy values so the gate never silently opens.
      final stateRef = f['active_while_state_ref'];
      String? stateId;
      if (stateRef != null) {
        final resolved = _resolveRef(stateRef, entitiesById);
        if (resolved != null) {
          stateId = entitiesById[resolved]?.name ?? resolved;
        } else if (stateRef is Map) {
          stateId = (stateRef['name'] ?? stateRef['_lookup'])?.toString();
        } else if (stateRef is String) {
          stateId = stateRef;
        }
      }
      final gated = stateId != null && stateId.isNotEmpty;

      // Notes first: they are the one thing that must survive on a gated card,
      // since that is where its roll-time behaviour is written down.
      for (final line in _readLines(f['mechanical_notes'])) {
        final label = gated ? '${_stateLabel(stateId)}: $line' : line;
        if (!mechanicalNotes.contains(label)) mechanicalNotes.add(label);
      }

      if (gated) {
        // Defense grants surface as "(while raging)" chips…
        for (final entry in _conditionalGrantKinds.entries) {
          final ids = _readRefList(f[entry.key], entitiesById);
          if (ids.isEmpty) continue;
          conditionalGrants.add(<String, dynamic>{
            'state': stateId,
            'kind': entry.value,
            'ids': ids,
            'source': src,
          });
        }
        // …but the card's resource pools always apply: the pool is the
        // counter of how often the state can be *entered* (Rage uses), not
        // something that exists only while raging. Everything else on a
        // gated card is roll-time behaviour and belongs in its
        // `mechanical_notes` (already collected above).
        applyResourcePools(f);
        return;
      }

      // ── Proficiencies ───────────────────────────────────────────────────
      void addAll(List<String> ids, List<String> into) {
        for (final id in ids) {
          if (!into.contains(id)) into.add(id);
        }
      }
      addAll(_readRefList(f['granted_skill_proficiencies'], entitiesById), skills);
      addAll(_readRefList(f['granted_tool_proficiencies'], entitiesById), tools);
      addAll(_readRefList(f['granted_save_proficiencies'], entitiesById), saves);
      addAll(_readRefList(f['granted_weapon_proficiencies'], entitiesById), weaponCats);
      addAll(_readRefList(f['granted_armor_proficiencies'], entitiesById), armorCats);
      addAll(_readRefList(f['granted_expertise_skills'], entitiesById), expertiseSkills);
      addAll(_readRefList(f['granted_languages'], entitiesById), languages);

      // ── Spells ──────────────────────────────────────────────────────────
      for (final id in _readRefList(f['granted_spell_refs'], entitiesById)) {
        if (!grantedSpellIds.contains(id)) grantedSpellIds.add(id);
        noteSource(id, src);
      }
      for (final id in _readRefList(f['granted_cantrip_refs'], entitiesById)) {
        if (!grantedCantripIds.contains(id)) grantedCantripIds.add(id);
        noteSource(id, src);
      }
      addAll(_readRefList(f['always_prepared_spell_refs'], entitiesById),
          alwaysPreparedSpells);
      _applyLevelGatedSpells(
        rows: _readMapList(f['granted_spells_at_level']),
        totalLevel: classLevels.values.fold<int>(0, (a, b) => a + b),
        entitiesById: entitiesById,
        grantedSpellIds: grantedSpellIds,
        grantedCantripIds: grantedCantripIds,
        resourcePools: resourcePools,
        noteSource: (id) => noteSource(id, src),
      );

      // ── Numeric bonuses ─────────────────────────────────────────────────
      final abilityBonuses = f['ability_bonuses'];
      if (abilityBonuses is Map) {
        // Default cap 20; Primal Champion-style cards raise it via
        // `ability_bonus_cap`.
        final capRaw = _intOf(f['ability_bonus_cap']);
        final cap = capRaw >= 20 ? capRaw : 20;
        for (final e in abilityBonuses.entries) {
          final abbrev = _abilityAbbrev(e.key.toString()) ?? e.key.toString().toUpperCase();
          if (!_abilityAbbrevs.contains(abbrev)) continue;
          final amt = _intOf(e.value);
          if (amt == 0) continue;
          final next = (abilities[abbrev] ?? 10) + amt;
          abilities[abbrev] = next > cap ? cap : next;
        }
      }
      acBonus += _intOf(f['ac_bonus']);
      speedBonus += _intOf(f['speed_bonus_ft']);
      initiativeBonus += _intOf(f['initiative_bonus']);
      hpBonusFlat += _intOf(f['hp_bonus_flat']);
      hpBonusPerLevel += _intOf(f['hp_bonus_per_level']);
      weaponMasteryCount += _intOf(f['weapon_mastery_count']);

      // Multiclass takes the max attack count, never the sum. The level table
      // wins over the flat value when it has a row for the current level.
      final attacksScaled = valueForLevel(f['extra_attack_count_by_level']);
      final attacks = attacksScaled ?? _intOf(f['extra_attack_count']);
      if (attacks > extraAttackCount) extraAttackCount = attacks;

      // A threshold of 0/1 would crit on every roll — always an authoring
      // slip, so warn instead of applying it.
      final crit = _intOf(f['crit_threshold']);
      if (crit >= 2 && crit < critRangeMin) {
        critRangeMin = crit;
      } else if (crit > 0 && crit < 2) {
        warnings.add('crit_threshold $crit ignored (from $src)');
      }

      // Unarmored AC replacement (Barbarian / Monk / Draconic Sorcerer). The
      // field name carries the "while not wearing armor" condition, so no
      // predicate is needed; `_computeArmorClass` only consults these when no
      // armor is equipped.
      final unarmoredBase = f['unarmored_ac_base'];
      if (unarmoredBase is int) {
        unarmoredFormulas.add(<String, dynamic>{
          'payload': <String, dynamic>{
            'base': unarmoredBase,
            'ability_mods': abilityAbbrevs(f['unarmored_ac_abilities']),
            'shield_allowed': f['unarmored_ac_shield_allowed'] == true,
          },
        });
      }

      // ── Defense ─────────────────────────────────────────────────────────
      for (final id in _readRefList(f['granted_damage_resistances'], entitiesById)) {
        if (!damageRes.contains(id)) damageRes.add(id);
        noteSource(id, src);
      }
      for (final id in _readRefList(f['granted_damage_immunities'], entitiesById)) {
        if (!damageImmunities.contains(id)) damageImmunities.add(id);
        noteSource(id, src);
      }
      for (final id in _readRefList(f['granted_damage_vulnerabilities'], entitiesById)) {
        if (!damageVulnerabilities.contains(id)) damageVulnerabilities.add(id);
        noteSource(id, src);
      }
      for (final id in _readRefList(f['granted_condition_immunities'], entitiesById)) {
        if (!conditionImmunities.contains(id)) conditionImmunities.add(id);
        noteSource(id, src);
      }

      // ── Senses ──────────────────────────────────────────────────────────
      final rawSenses = f['granted_senses'];
      if (rawSenses is List) {
        for (final row in rawSenses) {
          addSense(row, src);
        }
      }

      // ── Movement ────────────────────────────────────────────────────────
      // `-1` means "equal to walking speed" — the sentinel the sheet already
      // understands for Spider Climb / Second-Story Work style grants.
      const speedModeByField = {
        'speed_fly_ft': 'fly',
        'speed_swim_ft': 'swim',
        'speed_climb_ft': 'climb',
        'speed_burrow_ft': 'burrow',
      };
      // An explicit distance is more specific than "= walking speed", so it
      // wins over the sentinel regardless of order; between two explicit
      // distances the larger wins.
      speedModeByField.forEach((field, mode) {
        final v = f[field];
        if (v is! int || v == 0) return;
        final cur = extraSpeeds[mode];
        if (v == -1) {
          if (cur == null) extraSpeeds[mode] = -1;
        } else if (cur == null || cur == -1 || v > cur) {
          extraSpeeds[mode] = v;
        }
      });

      // ── Granted actions + traits ────────────────────────────────────────
      for (final id in _readRefList(f['granted_action_refs'], entitiesById)) {
        if (!grantedActionIds.contains(id)) grantedActionIds.add(id);
        noteSource(id, src);
      }
      for (final id in _readRefList(f['granted_bonus_action_refs'], entitiesById)) {
        if (!grantedBonusActionIds.contains(id)) grantedBonusActionIds.add(id);
        noteSource(id, src);
      }
      for (final id in _readRefList(f['granted_reaction_refs'], entitiesById)) {
        if (!grantedReactionIds.contains(id)) grantedReactionIds.add(id);
        noteSource(id, src);
      }
      for (final id in _readRefList(f['trait_refs'], entitiesById)) {
        if (!autoGrantedTraitIds.contains(id)) autoGrantedTraitIds.add(id);
        noteSource(id, src);
      }

      // ── Resource pools ──────────────────────────────────────────────────
      applyResourcePools(f);

      // `player_choices` rows are deliberately not read here — pending-choice
      // queueing is a chargen/level-up concern (`pending_choices.dart` reads
      // the card fields directly), not a resolved-sheet stat.
    }

    // ── 4b. Auto-grant walker. Each card states what it hands out: a Class /
    // Subclass on the `features` row for the level, a Species / Subspecies on
    // its flat `granted_feat_refs` + `trait_refs`, a Background on
    // `origin_feat_ref`. Collect everything the character has already earned;
    // the grant block of each is applied below, exactly like a chosen feat.
    //
    // This replaced an inverse `auto_granted_by` edge declared on the feat,
    // which meant the level lived on the feat while the class card carried an
    // unrelated narrative row for the same feature — two places to edit, and
    // in practice they disagreed. It also had to scan every entity in the
    // world; this walks only the four cards the character actually has.
    void grantFeat(String id) {
      if (featIds.contains(id) || autoGrantedFeatIds.contains(id)) return;
      if (entitiesById[id]?.categorySlug != 'feat') return;
      autoGrantedFeatIds.add(id);
    }

    void grantTrait(String id) {
      if (autoGrantedTraitIds.contains(id)) return;
      if (entitiesById[id]?.categorySlug != 'trait') return;
      autoGrantedTraitIds.add(id);
    }

    /// Walk [src]'s level table and take every row at or below [upTo].
    void collectLevelGrants(Entity? src, int upTo) {
      if (src == null) return;
      for (final row in _readMapList(src.fields['features'])) {
        final lvl = (row['level'] is int) ? row['level'] as int : 1;
        if (lvl > upTo) continue;
        for (final id in _readRefList(row['granted_feat_refs'], entitiesById)) {
          grantFeat(id);
        }
        for (final id in _readRefList(row['granted_trait_refs'], entitiesById)) {
          grantTrait(id);
        }
        // R5 / F-pass0-08: a domain / circle spell list arrives in tiers
        // ("1st: false life, ray of sickness · 3rd: …"), so it is gated by the
        // row's own level exactly like the feats above. Built-in 2024 content
        // hands the same mechanic out through a feat card; a 2014-shaped pack
        // writes it on the row, and both end up in `alwaysPreparedSpells`.
        for (final id in _readRefList(
            row['always_prepared_spell_refs'], entitiesById)) {
          if (!alwaysPreparedSpells.contains(id)) alwaysPreparedSpells.add(id);
        }
      }
    }

    for (final entry in classLevels.entries) {
      collectLevelGrants(entitiesById[entry.key], entry.value);
    }
    if (subclassId != null) {
      final sub = entitiesById[subclassId];
      // Gate subclass rows by the parent class's level so an L6/L10/L14
      // feature doesn't arrive the moment the L3 subclass is picked. Falls
      // back to total character level when there's no `parent_class_ref`.
      final parentClassId =
          _resolveRef(sub?.fields['parent_class_ref'], entitiesById);
      collectLevelGrants(
        sub,
        parentClassId != null
            ? (classLevels[parentClassId] ?? 0)
            : classLevels.values.fold<int>(0, (a, b) => a + b),
      );
    }
    // Species / subspecies have no level table — everything they name arrives
    // at character creation. (A Background's `origin_feat_ref` is deliberately
    // NOT read here: the wizard writes it into `feat_ids` so the player can
    // swap it afterwards, and force-applying it would put a removed feat back.)
    for (final id in [raceId, subspeciesId]) {
      final card = (id == null) ? null : entitiesById[id];
      if (card == null) continue;
      for (final fid
          in _readRefList(card.fields['granted_feat_refs'], entitiesById)) {
        grantFeat(fid);
      }
    }

    // ── 5. Pass 3: feat ASI + grant block ──────────────────────────────
    final allFeatIds = [...featIds, ...autoGrantedFeatIds];
    for (final fid in allFeatIds) {
      final feat = entitiesById[fid];
      if (feat == null) {
        warnings.add('Missing feat entity $fid');
        continue;
      }
      // ASI: typed scalar fields. Apply once per feat occurrence; if the feat
      // is repeatable and listed multiple times we apply once each.
      final asiAmount = _intOf(feat.fields['asi_amount']);
      final asiMax = (feat.fields['asi_max_score'] is int)
          ? feat.fields['asi_max_score'] as int
          : 20;
      if (asiAmount > 0) {
        final recorded =
            (featAsiChoices is Map) ? featAsiChoices[fid] : null;
        if (recorded is Map && recorded.isNotEmpty) {
          // Honor the user's recorded pick(s) for this feat (cap-aware).
          const valid = {'STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'};
          recorded.forEach((k, v) {
            if (k is! String) return;
            final abbrev = _abilityAbbrev(k) ?? k.toUpperCase();
            if (!valid.contains(abbrev)) return;
            final amt = _intOf(v);
            if (amt == 0) return;
            final cur = abilities[abbrev] ?? 10;
            final next = cur + amt;
            abilities[abbrev] = next > asiMax ? asiMax : next;
          });
        } else {
          // Heuristic: bump first option ability that isn't already capped.
          // The option list is a relation list, so after an install it holds
          // ids, not `{_lookup, name}` maps — reading only the map shape meant
          // no packaged feat ever applied its ASI (audit M1).
          for (final abbrev in abilityAbbrevs(feat.fields['asi_ability_options'])) {
            final cur = abilities[abbrev] ?? 10;
            if (cur + asiAmount <= asiMax) {
              abilities[abbrev] = cur + asiAmount;
              break;
            }
          }
        }
      }
      applyGrantsFrom(feat.fields, 'feat:${feat.name}');
    }

    // ── 7. Pass 5: species + background grants ─────────────────────────
    if (raceId != null) {
      final sp = entitiesById[raceId];
      if (sp != null) {
        // The species entity itself, a chosen subspecies entity and (legacy) a
        // nested subspecies_options row all speak the grant-block keys, so the
        // shared reader covers all three.
        applyGrantsFrom(sp.fields, 'species:${sp.name}');

        // Subspecies — a first-class `subspecies` entity (preferred) or, for
        // legacy data, a nested `subspecies_options` row. `subspeciesId` may be
        // the entity id (new selections), the entity name, or the original
        // option name (saves predating the field→entity migration), matched via
        // `legacy_subspecies_key`.
        if (subspeciesId != null && subspeciesId.isNotEmpty) {
          Entity? sub = entitiesById[subspeciesId];
          if (sub == null || sub.categorySlug != 'subspecies') {
            sub = null;
            for (final e in entitiesById.values) {
              if (e.categorySlug != 'subspecies') continue;
              if (_resolveRef(e.fields['parent_species_ref'], entitiesById) !=
                  raceId) {
                continue;
              }
              if (e.name == subspeciesId ||
                  e.fields['legacy_subspecies_key']?.toString() ==
                      subspeciesId) {
                sub = e;
                break;
              }
            }
          }
          if (sub != null) {
            applyGrantsFrom(sub.fields, 'subspecies:${sp.name}/${sub.name}');
          } else {
            // Legacy fallback: nested subspecies_options row matched by name.
            for (final row in _readMapList(sp.fields['subspecies_options'])) {
              if (row['name']?.toString() != subspeciesId) continue;
              applyGrantsFrom(row, 'subspecies:${sp.name}/$subspeciesId');
              break;
            }
          }
        }
      }
    }
    if (backgroundId != null) {
      final bg = entitiesById[backgroundId];
      if (bg != null) {
        for (final s in _readRefList(bg.fields['granted_skill_refs'], entitiesById)) {
          if (!skills.contains(s)) skills.add(s);
        }
        for (final t in _readRefList(bg.fields['granted_tool_refs'], entitiesById)) {
          if (!tools.contains(t)) tools.add(t);
        }
        // R5 / F-pass0-09: `granted_language_count` counts the free picks;
        // this holds the ones the background names outright (Thieves' Cant).
        // Same key the class pass reads, for the same reason.
        for (final l in _readRefList(bg.fields['granted_languages'], entitiesById)) {
          if (!languages.contains(l)) languages.add(l);
        }
        // SRD 2024 p.83: each background allows either +2/+1 to two abilities
        // or +1/+1/+1 to three. PC stores the chosen distribution as
        // `background_asi: {STR: 2, CON: 1}` — resolver bumps the abilities
        // here. Total must be 3; resolver applies whatever is stored without
        // re-validating, so the wizard/editor enforces the distribution rule.
        // Bumps gated by ability_score_options when present; out-of-list
        // entries are dropped with a warning. Cap at 20.
        // R5 / F-pass0-03: "+1 Charisma and one other ability score" — the
        // Charisma half is not a choice, so it applies whether or not the
        // player recorded it. It is added once: a `background_asi` entry for
        // the same ability is the player's record of this very bump.
        final asi = _readIntMap(fields['background_asi']);
        final fixedId = _resolveRef(bg.fields['asi_fixed_ability_ref'], entitiesById);
        final fixed = fixedId == null
            ? null
            : _abilityAbbrev(entitiesById[fixedId]?.name ?? '');
        if (fixed != null && !asi.containsKey(fixed)) {
          final cur = abilities[fixed] ?? 10;
          abilities[fixed] = cur + 1 > 20 ? 20 : cur + 1;
        }
        if (asi.isNotEmpty) {
          final allowed = <String>{};
          for (final r in _readRefList(
              bg.fields['ability_score_options'], entitiesById)) {
            final name = entitiesById[r]?.name ?? '';
            final abbrev = _abilityAbbrev(name);
            if (abbrev != null) allowed.add(abbrev);
          }
          // The fixed ability is granted by this very card, so a stored bump on
          // it is never "outside the options".
          if (fixed != null) allowed.add(fixed);
          // Declared free picks are a ceiling: the card says how many +1s the
          // player chooses, and anything past that is a wizard bug, surfaced
          // rather than silently applied twice.
          final freeCap = _intOf(bg.fields['asi_free_bonus_count']);
          if (freeCap > 0) {
            final free = asi.entries
                .where((e) =>
                    (_abilityAbbrev(e.key) ?? e.key.toUpperCase()) != fixed)
                .fold<int>(0, (a, e) => a + e.value);
            if (free > freeCap) {
              warnings.add('background_asi grants $free free points, '
                  '${bg.name} allows $freeCap');
            }
          }
          for (final entry in asi.entries) {
            final abbrev = _abilityAbbrev(entry.key) ?? entry.key.toUpperCase();
            const valid = {'STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'};
            if (!valid.contains(abbrev)) continue;
            if (allowed.isNotEmpty && !allowed.contains(abbrev)) {
              warnings.add(
                  'background_asi $abbrev not in ${bg.name}.ability_score_options');
              continue;
            }
            final cur = abilities[abbrev] ?? 10;
            final next = cur + entry.value;
            abilities[abbrev] = next > 20 ? 20 : next;
          }
        }
      }
    }

    // ── 8b. Pass 5b: granted traits + equipped items ───────────────────
    // Traits carry the same grant block as feats — applied once granted
    // (species trait_refs, auto-grant walker). A trait's own `trait_refs` is
    // deliberately not declared in the schema, so this cannot recurse.
    // Magic items apply their block while equipped.
    for (final tid in List<String>.from(autoGrantedTraitIds)) {
      final tr = entitiesById[tid];
      if (tr == null) continue;
      applyGrantsFrom(tr.fields, 'trait:${tr.name}');
    }
    for (final row in _iterEquippedInventory(fields)) {
      final id = _resolveRef(row, entitiesById);
      if (id == null) continue;
      final item = entitiesById[id];
      if (item == null) continue;
      applyGrantsFrom(item.fields, 'item:${item.name}');
    }

    // ── 8. Class proficiency grants (saves + weapon/armor categories) ──
    for (final classId in classLevels.keys) {
      final cls = entitiesById[classId];
      if (cls == null) continue;
      for (final s in _readRefList(cls.fields['saving_throw_refs'], entitiesById)) {
        if (!saves.contains(s)) saves.add(s);
      }
      for (final t in _readRefList(cls.fields['granted_tool_refs'], entitiesById)) {
        if (!tools.contains(t)) tools.add(t);
      }
      // Druid's Druidic, Rogue's Thieves' Cant. Same field key the grant block
      // uses on feats/species — the class simply does not carry the rest of
      // the block, so it is read here instead of through `applyGrantsFrom`.
      for (final l in _readRefList(cls.fields['granted_languages'], entitiesById)) {
        if (!languages.contains(l)) languages.add(l);
      }
      final wcats = cls.fields['weapon_proficiency_categories'];
      if (wcats is List) {
        for (final v in wcats) {
          if (v is String && !weaponCats.contains(v)) weaponCats.add(v);
        }
      }
      final acats = cls.fields['armor_training_refs'];
      if (acats is List) {
        for (final v in acats) {
          if (v is String && !armorCats.contains(v)) armorCats.add(v);
        }
      }
    }
    // Subclass-level proficiency grants (some subclasses extend saves /
    // weapon / armor training beyond the parent class). Feature-row effects
    // already flow through Pass 4 via `proficiency_grant`; these top-level
    // refs cover authored subclass entities that declare grants directly.
    if (subclassId != null) {
      final sub = entitiesById[subclassId];
      if (sub != null) {
        for (final s in _readRefList(sub.fields['saving_throw_refs'], entitiesById)) {
          if (!saves.contains(s)) saves.add(s);
        }
        final wcats = sub.fields['weapon_proficiency_categories'];
        if (wcats is List) {
          for (final v in wcats) {
            if (v is String && !weaponCats.contains(v)) weaponCats.add(v);
          }
        }
        final acats = sub.fields['armor_training_refs'];
        if (acats is List) {
          for (final v in acats) {
            if (v is String && !armorCats.contains(v)) armorCats.add(v);
          }
        }
      }
    }

    // ── 8b. Armor-worn conditions (SRD 5.2.1 p. 92) ────────────────────
    // STR-requirement speed penalty, untrained-armor warning, and stealth
    // disadvantage. Runs after Pass 8 so `armorCats` is complete, and before
    // the `extraSpeeds` resolution below so the speed cut propagates into
    // walk-derived speeds. Shields are excluded by `_equippedArmor`, so the
    // STR / stealth checks only see body armor (SRD shields have neither).
    final armorNotes = <String>[];
    final wornArmor = _equippedArmor(fields, entitiesById);
    if (wornArmor != null) {
      final strReq = wornArmor.fields['strength_requirement'];
      if (strReq is int && (abilities['STR'] ?? 10) < strReq) {
        speedBonus -= 10;
        armorNotes.add(
          'Speed −10 ft: STR ${abilities['STR'] ?? 10} is below '
          "${wornArmor.name}'s requirement ($strReq).");
      }
      final catId = _resolveRef(wornArmor.fields['category_ref'], entitiesById);
      if (catId != null && !armorCats.contains(catId)) {
        final catName = entitiesById[catId]?.name ?? 'this';
        armorNotes.add(
          'Untrained in $catName armor: Disadvantage on STR/DEX D20 Tests, '
          "and you can't cast spells.");
      }
      if (wornArmor.fields['stealth_disadvantage'] == true) {
        armorNotes.add(
          '${wornArmor.name}: Disadvantage on Dexterity (Stealth) checks.');
      }
    }

    // ── 9. Pass 6: equipment ───────────────────────────────────────────
    final inventory = <ResolvedInventoryItem>[];

    void mergeChoiceGroups(Entity src, String sourceTag) {
      final groups = _readMapList(src.fields['equipment_choice_groups']);
      for (final g in groups) {
        final groupId = g['group_id']?.toString() ?? '';
        // Choices are stored scoped by source entity id (`$sourceId:$groupId`)
        // so class + background picks with identical group_ids don't collide —
        // mirror the key the wizard writes (equipment_step.dart storageKey).
        final pickedOption = equipmentChoices['${src.id}:$groupId'];
        if (pickedOption == null) continue;
        final opts = _readMapList(g['options']);
        for (final o in opts) {
          if (o['option_id'] != pickedOption) continue;
          final items = _readMapList(o['items']);
          for (final item in items) {
            final id = _resolveRef(item['ref'], entitiesById);
            if (id == null) continue;
            inventory.add(ResolvedInventoryItem(
              entityId: id,
              quantity: _intOf(item['quantity']) > 0 ? _intOf(item['quantity']) : 1,
              source: '$sourceTag:option:$pickedOption',
            ));
          }
        }
      }
      final defaults = _readMapList(src.fields['default_inventory_refs']);
      for (final r in defaults) {
        final id = _resolveRef(r, entitiesById);
        if (id != null) {
          inventory.add(ResolvedInventoryItem(entityId: id, source: '$sourceTag:default'));
        }
      }
    }

    for (final classId in classLevels.keys) {
      final cls = entitiesById[classId];
      if (cls != null) mergeChoiceGroups(cls, 'class:${cls.name}');
    }
    if (backgroundId != null) {
      final bg = entitiesById[backgroundId];
      if (bg != null) mergeChoiceGroups(bg, 'background:${bg.name}');
    }

    // Resolve `extraSpeeds` sentinels (-1 = "equals walking speed"). Walk
    // speed = species `speed_ft` (default 30 ft if unauthored) + speedBonus.
    if (extraSpeeds.containsValue(-1)) {
      var walkBase = 30;
      if (raceId != null) {
        final sp = entitiesById[raceId];
        final raw = sp?.fields['speed_ft'];
        if (raw is int) walkBase = raw;
      }
      final walk = walkBase + speedBonus;
      for (final mode in extraSpeeds.keys.toList()) {
        if (extraSpeeds[mode] == -1) extraSpeeds[mode] = walk;
      }
    }

    return EffectiveCharacter(
      characterId: pc.id,
      classLevels: classLevels,
      subclassId: subclassId,
      featIds: featIds,
      effectiveAbilities: abilities,
      proficiencies: ResolvedProficiencies(
        skillIds: skills,
        toolIds: tools,
        savingThrowAbilityIds: saves,
        languageIds: languages,
        weaponCategoryIds: weaponCats,
        armorCategoryIds: armorCats,
      ),
      acBonus: acBonus,
      armorClass: _computeArmorClass(
        fields: fields,
        entitiesById: entitiesById,
        abilities: abilities,
        acBonus: acBonus,
        unarmoredFormulas: unarmoredFormulas,
        config: config,
      ),
      armorNotes: armorNotes,
      speedBonus: speedBonus,
      extraSpeeds: extraSpeeds,
      hpBonusFlat: hpBonusFlat,
      hpBonusPerLevel: hpBonusPerLevel,
      initiativeBonus: initiativeBonus,
      grantedSpellIds: grantedSpellIds,
      grantedCantripIds: grantedCantripIds,
      activeFeatures: activeFeatures,
      inventory: inventory,
      senseEntityIds: senses,
      senseRanges: senseRanges,
      conditionalGrants: conditionalGrants,
      damageResistanceIds: damageRes,
      damageImmunityIds: damageImmunities,
      damageVulnerabilityIds: damageVulnerabilities,
      conditionImmunityIds: conditionImmunities,
      expertiseSkillIds: expertiseSkills,
      alwaysPreparedSpellIds: alwaysPreparedSpells,
      autoGrantedFeatIds: autoGrantedFeatIds,
      autoGrantedTraitIds: autoGrantedTraitIds,
      grantedActionIds: grantedActionIds,
      grantedBonusActionIds: grantedBonusActionIds,
      grantedReactionIds: grantedReactionIds,
      unarmoredFormulas: unarmoredFormulas,
      extraAttackCount: extraAttackCount,
      critRangeMin: critRangeMin,
      weaponMasteryCount: weaponMasteryCount,
      mechanicalNotes: mechanicalNotes,
      resourcePools: resourcePools,
      grantSources: grantSources,
      freeCastSpellIds: _readStringList(fields['free_cast_spell_ids']),
      ritualBookSpellIds: _readStringList(fields['ritual_book_spell_ids']),
      activeConditionIds: _readStringList(fields['active_conditions']),
      warnings: warnings,
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────

  static void _collectFeaturesByLevel(
    Entity src,
    int level,
    List<ResolvedFeatureRow> out,
  ) {
    final rows = _readMapList(src.fields['features']);
    for (final r in rows) {
      final lvl = (r['level'] is int) ? r['level'] as int : 1;
      if (lvl > level) continue;
      out.add(ResolvedFeatureRow(
        level: lvl,
        description: (r['description'] ?? '').toString(),
        sourceEntityId: src.id,
      ));
    }
  }

  /// Compute the PC's armor class from equipped armor + Dex (capped by
  /// armor row), shield bonus, generic `ac_bonus` grants, and any
  /// unarmored-AC formulas collected from `unarmored_ac_base` fields.
  /// Mirrors SRD §1 Armor Class rules. Surfaced on EffectiveCharacter so
  /// the sheet's AC chip refreshes whenever inventory equip flags change
  /// without forcing the player to retype the value into combat_stats.
  static int _computeArmorClass({
    required Map<String, dynamic> fields,
    required Map<String, Entity> entitiesById,
    required Map<String, int> abilities,
    required int acBonus,
    required List<Map<String, dynamic>> unarmoredFormulas,
    required RuleConfig config,
  }) {
    final shield = config.acShieldBonus;
    final dex = config.abilityModifier(abilities['DEX'] ?? 10);
    final hasShield = _hasEquippedShield(fields, entitiesById);
    final armor = _equippedArmor(fields, entitiesById);
    if (armor != null) {
      final base = _intOf(armor.fields['base_ac']);
      final addsDex = armor.fields['adds_dex'] == true;
      final dexCapRaw = armor.fields['dex_cap'];
      int dexContrib;
      if (!addsDex) {
        dexContrib = 0;
      } else if (dexCapRaw is int) {
        dexContrib = dex > dexCapRaw ? dexCapRaw : dex;
      } else {
        dexContrib = dex;
      }
      return base + dexContrib + (hasShield ? shield : 0) + acBonus;
    }
    // Unarmored: SRD default base + Dex; replaced by the highest matching
    // unarmored_ac_formula (Barbarian, Monk, Draconic Sorcerer). Shield is
    // additive when the formula allows it (Barbarian yes, Monk no).
    var best = config.acUnarmoredBase + dex + (hasShield ? shield : 0);
    for (final f in unarmoredFormulas) {
      final payload = f['payload'];
      if (payload is! Map) continue;
      final baseRaw = payload['base'];
      final base = baseRaw is int ? baseRaw : config.acUnarmoredBase;
      final mods = payload['ability_mods'];
      var sum = base;
      if (mods is List) {
        for (final m in mods) {
          if (m is String) {
            sum += config.abilityModifier(abilities[m] ?? 10);
          }
        }
      }
      final shieldAllowed = payload['shield_allowed'] == true;
      final withShield = sum + (hasShield && shieldAllowed ? shield : 0);
      if (withShield > best) best = withShield;
    }
    return best + acBonus;
  }

  /// Walk a PC's `inventory` field and return the first equipped armor
  /// entity (category slug `armor`). Inventory rows are either bare ID
  /// strings (no equip toggle) or `{id, equipped}` maps. Shields share the
  /// `armor` slug — they're excluded here (handled by _hasEquippedShield)
  /// by resolving `category_ref` to the armor-category name.
  static Entity? _equippedArmor(
    Map<String, dynamic> fields,
    Map<String, Entity> entitiesById,
  ) {
    for (final row in _iterEquippedInventory(fields)) {
      final id = _resolveRef(row, entitiesById);
      if (id == null) continue;
      final e = entitiesById[id];
      if (e == null) continue;
      if (e.categorySlug != 'armor') continue;
      // Treat shields as a separate concern (handled by _hasEquippedShield).
      final catRef = e.fields['category_ref'];
      final catId = _resolveRef(catRef, entitiesById);
      final catName = catId != null
          ? (entitiesById[catId]?.name.toLowerCase() ?? '')
          : '';
      if (catName.contains('shield')) continue;
      return e;
    }
    return null;
  }

  /// True iff the PC has an equipped shield in `inventory`. Shields are
  /// armor-category entities whose `category_ref` resolves to a name
  /// containing "shield".
  static bool _hasEquippedShield(
    Map<String, dynamic> fields,
    Map<String, Entity> entitiesById,
  ) {
    for (final row in _iterEquippedInventory(fields)) {
      final id = _resolveRef(row, entitiesById);
      if (id == null) continue;
      final e = entitiesById[id];
      if (e == null) continue;
      if (e.categorySlug != 'armor') continue;
      final catRef = e.fields['category_ref'];
      final catId = _resolveRef(catRef, entitiesById);
      final catName = catId != null
          ? (entitiesById[catId]?.name.toLowerCase() ?? '')
          : '';
      if (catName.contains('shield')) return true;
    }
    return false;
  }

  /// Iterate inventory rows that are flagged as equipped. Yields the raw
  /// ref payload (string ID or `{id, equipped}` map) so callers can resolve
  /// it via [_resolveRef].
  static Iterable<Object?> _iterEquippedInventory(
    Map<String, dynamic> fields,
  ) sync* {
    final raw = fields['inventory'];
    if (raw is! List) return;
    for (final row in raw) {
      if (row is Map) {
        // `id` yoksa satırın kendisi bir ref zarfıdır (`{_ref|slug|_lookup,
        // name, equipped}`) — paket/blueprint kaynaklı envanter böyle gelir.
        // Yalnız `row['id']` okumak, kuşanılmış zırhı/silahı AC ve saldırı
        // hesabından sessizce düşürüyordu.
        if (row['equipped'] == true) yield row['id'] ?? row;
      }
    }
  }

  // Ref resolution lives in `entity_ref.dart` so the chargen/level-up
  // selection UI resolves the same softRef envelopes this resolver does.
  static String? _resolveRef(Object? raw, Map<String, Entity> all) =>
      resolveEntityRef(raw, all);

  static const Set<String> _abilityAbbrevs = {
    'STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA', //
  };

  /// Split a `mechanical_notes` value into displayable lines. The field is a
  /// textarea (one note per line), but a migrated list of strings reads the
  /// same way.
  static List<String> _readLines(Object? raw) {
    if (raw is List) {
      return [
        for (final v in raw)
          if (v is String && v.trim().isNotEmpty) v.trim(),
      ];
    }
    if (raw is String) {
      return [
        for (final line in raw.split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
      ];
    }
    return const [];
  }

  /// Human label for a state id/tag: `state:raging` → `while raging`.
  static String _stateLabel(String stateId) {
    final name = stateId.startsWith('state:')
        ? stateId.substring('state:'.length)
        : stateId;
    return 'while ${name.replaceAll('_', ' ')}';
  }

  static List<String> _readStringList(Object? raw) {
    if (raw is List) return [for (final v in raw) if (v is String) v];
    return const [];
  }

  static String? _readNullableString(Object? raw) =>
      raw is String && raw.isNotEmpty ? raw : null;

  /// `class_levels` anahtarı wizard'da class entity **id**'sidir; blueprint
  /// kaynaklı bir kartta sınıfın **adı** olur (`{"Fighter": 2}`) — id ile
  /// aranınca "Missing class entity Fighter" düşer ve sınıfın hiçbir
  /// özelliği uygulanmaz. Ad → id çevrilir; çevrilemeyen anahtar aynen
  /// bırakılır ki uyarı gerçekten eksik sınıf için düşsün.
  static Map<String, int> _resolveClassLevels(
    Object? raw,
    Map<String, Entity> byId,
  ) {
    final src = _readIntMap(raw);
    if (src.isEmpty) return src;
    final out = <String, int>{};
    for (final entry in src.entries) {
      final key = byId.containsKey(entry.key)
          ? entry.key
          : (findEntityIdByName(byId, 'class', entry.key) ?? entry.key);
      out[key] = entry.value;
    }
    return out;
  }

  static Map<String, int> _readIntMap(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, int>{};
    raw.forEach((k, v) {
      if (k is String && v is int) out[k] = v;
      if (k is String && v is num) out[k] = v.toInt();
    });
    return out;
  }

  static Map<String, String> _readStringMap(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((k, v) {
      if (k is String && v is String) out[k] = v;
    });
    return out;
  }

  static List<Map<String, dynamic>> _readMapList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final v in raw)
        if (v is Map) Map<String, dynamic>.from(v),
    ];
  }

  static List<String> _readRefList(Object? raw, Map<String, Entity> all) {
    if (raw is! List) return const [];
    final out = <String>[];
    for (final v in raw) {
      final id = _resolveRef(v, all);
      if (id != null) out.add(id);
    }
    return out;
  }

  static int _intOf(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// Process subspecies / species `granted_spells_at_level` rows. Row shape:
  /// `{spell_ref: {slug, name}, at_level: int, is_cantrip?: bool,
  /// uses_per_long_rest?: int}`. Rows with `at_level > totalLevel` are
  /// skipped. If `is_cantrip` is true the spell goes to cantrips; otherwise
  /// to leveled spells. When `uses_per_long_rest` is set, a resource pool
  /// keyed by the spell id is appended so the sheet can render a daily
  /// counter (SRD 5.2.1 innate spells are 1/day).
  static void _applyLevelGatedSpells({
    required List<Map<String, dynamic>> rows,
    required int totalLevel,
    required Map<String, Entity> entitiesById,
    required List<String> grantedSpellIds,
    required List<String> grantedCantripIds,
    required List<Map<String, dynamic>> resourcePools,
    required void Function(String id) noteSource,
  }) {
    for (final row in rows) {
      final atLevel = _intOf(row['at_level']);
      if (atLevel > totalLevel) continue;
      final id = _resolveRef(row['spell_ref'], entitiesById);
      if (id == null) continue;
      final isCantrip = row['is_cantrip'] == true;
      if (isCantrip) {
        if (!grantedCantripIds.contains(id)) grantedCantripIds.add(id);
      } else {
        if (!grantedSpellIds.contains(id)) grantedSpellIds.add(id);
      }
      noteSource(id);
      final uses = _intOf(row['uses_per_long_rest']);
      if (uses > 0) {
        final already = resourcePools.any((p) => p['pool_ref'] == id);
        if (!already) {
          resourcePools.add({
            'pool_ref': id,
            'max': uses,
            'recharge': 'long_rest',
          });
        }
      }
    }
  }

  static String? _abilityAbbrev(String name) {
    switch (name.toLowerCase()) {
      case 'strength':
        return 'STR';
      case 'dexterity':
        return 'DEX';
      case 'constitution':
        return 'CON';
      case 'intelligence':
        return 'INT';
      case 'wisdom':
        return 'WIS';
      case 'charisma':
        return 'CHA';
    }
    return null;
  }
}
