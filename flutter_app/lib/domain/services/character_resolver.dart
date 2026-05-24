import '../entities/character.dart';
import '../entities/character/effective_character.dart';
import '../entities/entity.dart';

/// Pure-function read-time resolver. Walks a [Character]'s raw choices
/// (`class_levels`, `subclass_id`, `feat_ids`, `equipment_choices`) and the
/// referenced source entities, then folds them into an [EffectiveCharacter]
/// that the editor / sheet can read for derived stats.
///
/// Stateless. Safe to call on every read. Not memoized at this layer; wrap
/// with a Riverpod `Provider.family` for caching.
class CharacterResolver {
  /// Resolve [pc] against the campaign-wide entity map [entitiesById].
  ///
  /// Missing references are silently dropped and surfaced in
  /// [EffectiveCharacter.warnings] for debug display.
  static EffectiveCharacter resolve(
    Character pc,
    Map<String, Entity> entitiesById,
  ) {
    final fields = pc.entity.fields;
    final warnings = <String>[];

    // ── 1. Raw choice reads ─────────────────────────────────────────────
    final featIds = _readStringList(fields['feat_ids']);
    final equipmentChoices = _readStringMap(fields['equipment_choices']);
    final subclassId = _readNullableString(fields['subclass_id']);
    var classLevels = _readIntMap(fields['class_levels']);
    final raceId = _readNullableString(fields['race_id']);
    final subspeciesId = _readNullableString(fields['subspecies_id']);
    final backgroundId = _readNullableString(fields['background_id']);
    final baseAbilities = _readIntMap(fields['base_abilities']);

    // ── 2. Pass 1: feat class_level_grant (one pass per feat occurrence).
    // Each feat in `feat_ids` is applied exactly once. Repeatable feats
    // surface multiple ids in the list, so duplicates apply additively.
    final appliedLevelGrants = <String>{};
    for (final fid in featIds) {
      if (!appliedLevelGrants.add(fid)) {
        // duplicate id — still apply for repeatable feats; remove this guard
        // if we ever decide to dedupe by entity id.
      }
      final feat = entitiesById[fid];
      if (feat == null) continue;
      final effects = _readMapList(feat.fields['effects']);
      for (final eff in effects) {
        if (eff['kind'] != 'class_level_grant') continue;
        final targetRef = eff['target_ref'];
        if (targetRef is! Map) continue;
        final tname = targetRef['name'];
        if (tname is! String) continue;
        final classId = _findEntityIdByName(entitiesById, 'class', tname);
        if (classId == null) continue;
        final addAmount = (eff['value'] is int) ? eff['value'] as int : 1;
        classLevels = {
          ...classLevels,
          classId: (classLevels[classId] ?? 0) + addAmount,
        };
      }
    }

    // ── 3. Pass 2: class + subclass features by level ──────────────────
    final activeFeatures = <ResolvedFeatureRow>[];
    // Per row: the effect map plus a display source like
    // `class:Barbarian` or `subclass:Berserker`. Pass 4 applies these via
    // applyEffect so source-tagging flows through `noteSource`.
    final pendingFeatureEffects = <({Map<String, dynamic> eff, String source})>[];

    for (final entry in classLevels.entries) {
      final classEntity = entitiesById[entry.key];
      if (classEntity == null) {
        warnings.add('Missing class entity ${entry.key}');
        continue;
      }
      _collectFeaturesByLevel(
        classEntity,
        entry.value,
        activeFeatures,
        pendingFeatureEffects,
      );
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
          _collectFeaturesByLevel(
            sub,
            gateLevel,
            activeFeatures,
            pendingFeatureEffects,
          );
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
    final tempHpGrants = <Map<String, dynamic>>[];
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
    // Strip the `kind:` prefix that `applyEffect`-style call sites use
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

    // Predicate evaluator. Closed-enum predicate kinds are AND-combined per
    // effect row. Unknown kinds return false (conservative — better to skip
    // than mis-apply). State predicates always return false at resolve time
    // (states are runtime); the resolver re-runs when state flips.
    bool evalPredicate(Map<String, dynamic> p) {
      final kind = p['kind'];
      final args = p['args'];
      final argMap = (args is Map) ? Map<String, dynamic>.from(args) : const <String, dynamic>{};
      switch (kind) {
        case 'class_level_at_least':
          // args: {class_ref: {_ref: 'class', name: 'Barbarian'}, level: int}
          // OR args: {class_ref: '<class id>', level: int}
          final ref = argMap['class_ref'];
          final needLvl = _intOf(argMap['level']);
          final classId = (ref is String) ? ref : _resolveRef(ref, entitiesById);
          if (classId == null) return false;
          return (classLevels[classId] ?? 0) >= needLvl;
        case 'equipped_armor_kind':
          // args: {value: 'none'|'light'|'medium'|'heavy'|'not_heavy'|'not_none'}
          // Walk the PC's inventory for an equipped armor entity (non-shield).
          // 'none' is true iff no armor is equipped; 'not_heavy' is true
          // unless the equipped armor resolves to heavy. 'not_none' is true
          // iff any armor is equipped. Light/medium/heavy each require an
          // equipped armor of the matching category.
          final want = argMap['value']?.toString() ?? '';
          final armor = _equippedArmor(fields, entitiesById);
          if (armor == null) return want == 'none' || want == 'not_heavy';
          final catRef = armor.fields['category_ref'];
          final catId = _resolveRef(catRef, entitiesById);
          final cat = (catId != null) ? entitiesById[catId]?.name.toLowerCase() ?? '' : '';
          if (want == 'none') return false;
          if (want == 'not_none') return true;
          if (want == 'not_heavy') return !cat.contains('heavy');
          return cat.contains(want);
        case 'equipped_shield':
          final want = argMap['value']?.toString() ?? 'any';
          final has = _hasEquippedShield(fields, entitiesById);
          if (want == 'any') return true;
          if (want == 'true') return has;
          if (want == 'false') return !has;
          return false;
        case 'has_state':
        case 'has_condition':
        case 'target_has_condition':
          // Runtime state — at resolve time we don't gate on these. The
          // resolver attaches the predicate to the resulting accumulator
          // entry (e.g. conditionalResistances) so the runtime can apply at
          // combat time. For now, return false to avoid premature application.
          return false;
        case 'not_incapacitated':
          return true;
        default:
          return false;
      }
    }

    bool predicatesPass(Object? rawPredicates) {
      if (rawPredicates is! List) return true;
      for (final p in rawPredicates) {
        if (p is Map) {
          if (!evalPredicate(Map<String, dynamic>.from(p))) return false;
        }
      }
      return true;
    }

    /// Split a predicate list into state-gated refs vs non-state predicates.
    /// Returns null when no state predicate is present, otherwise the unique
    /// state refs and the residual non-state predicate list. State predicates
    /// always fail at resolve time but the resolver can still surface the
    /// effect as a conditional grant when the non-state predicates pass.
    ({List<String> stateRefs, List<Map<String, dynamic>> rest})? splitStatePredicates(
        Object? rawPredicates) {
      if (rawPredicates is! List) return null;
      final states = <String>[];
      final rest = <Map<String, dynamic>>[];
      for (final p in rawPredicates) {
        if (p is! Map) continue;
        final map = Map<String, dynamic>.from(p);
        final kind = map['kind'];
        if (kind == 'has_state' ||
            kind == 'has_condition' ||
            kind == 'target_has_condition') {
          final args = map['args'];
          final ref = (args is Map)
              ? (args['ref'] ?? args['state_ref'] ?? args['condition_ref'])
              : null;
          final tag = ref?.toString();
          if (tag != null && tag.isNotEmpty && !states.contains(tag)) {
            states.add(tag);
          }
        } else {
          rest.add(map);
        }
      }
      if (states.isEmpty) return null;
      return (stateRefs: states, rest: rest);
    }

    /// Resolve a `scales_with` table down to a single value for the current
    /// character context. Returns null if the table doesn't apply.
    Object? evalScalesWith(Object? rawScales) {
      if (rawScales is! Map) return null;
      final s = Map<String, dynamic>.from(rawScales);
      final kind = s['kind']?.toString();
      final tableRaw = s['table'];
      if (tableRaw is! List) return null;
      int lookupLvl = 0;
      if (kind == 'class_level' || kind == 'class_level_table') {
        final ref = s['class_ref'];
        final classId = (ref is String) ? ref : _resolveRef(ref, entitiesById);
        if (classId != null) lookupLvl = classLevels[classId] ?? 0;
      } else if (kind == 'character_level') {
        lookupLvl = classLevels.values.fold<int>(0, (a, b) => a + b);
      }
      Object? best;
      var bestLvl = -1;
      for (final row in tableRaw) {
        if (row is! Map) continue;
        final lvl = _intOf(row['lvl']);
        if (lvl <= lookupLvl && lvl > bestLvl) {
          bestLvl = lvl;
          best = row['v'];
        }
      }
      return best;
    }

    /// Subset of effect kinds that can meaningfully surface as a conditional
    /// grant when state-gated. Roll-time kinds (advantage_on, extra damage)
    /// are excluded — they live in the combat tracker layer.
    const conditionalKinds = <String>{
      'damage_resistance',
      'damage_immunity',
      'damage_vulnerability',
      'condition_immunity_grant',
    };

    void applyEffect(Map<String, dynamic> eff, String source) {
      // Split state predicates out before the main predicate gate. If a
      // `has_state` predicate is present and the non-state predicates all
      // pass, route eligible effect kinds to `conditionalGrants` so the
      // sheet can render them as gated chips. Otherwise the regular
      // predicate gate runs (state predicates always fail at resolve time,
      // so the effect drops if any remain in that path).
      final split = splitStatePredicates(eff['predicates']);
      if (split != null) {
        final kind = eff['kind']?.toString() ?? '';
        if (conditionalKinds.contains(kind)) {
          // All non-state predicates must pass for the gated grant to apply.
          for (final p in split.rest) {
            if (!evalPredicate(p)) return;
          }
          final id = _refIdFor(eff, entitiesById);
          if (id == null) return;
          conditionalGrants.add(<String, dynamic>{
            'state': split.stateRefs.first,
            'kind': kind,
            'ids': <String>[id],
            'source': source,
          });
          return;
        }
        // Fall through to default gate — non-conditional kinds drop.
      }
      // Row-level predicate gate.
      if (!predicatesPass(eff['predicates'])) return;
      switch (eff['kind']) {
        case 'class_level_grant':
          break; // already applied in pass 1
        case 'ability_score_bonus':
          // Species/subspecies/feat ASI grant. `ability` accepts full names
          // ("Constitution") or abbreviations ("CON"). `max` caps the post-
          // grant score; defaults to 20.
          final raw = (eff['ability'] ?? eff['target_kind'] ?? '').toString();
          final abbrev = _abilityAbbrev(raw) ?? raw.toUpperCase();
          const valid = {'STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'};
          if (!valid.contains(abbrev)) break;
          final amt = _intOf(eff['value']);
          if (amt == 0) break;
          final cap = (eff['max'] is int) ? eff['max'] as int : 20;
          final cur = abilities[abbrev] ?? 10;
          final next = cur + amt;
          abilities[abbrev] = next > cap ? cap : next;
        case 'ac_bonus':
          acBonus += _intOf(eff['value']);
        case 'speed_bonus':
          speedBonus += _intOf(eff['value']);
        case 'hp_bonus_per_level':
          hpBonusPerLevel += _intOf(eff['value']);
        case 'hp_bonus_flat':
        case 'hp_max_bonus_total':
          hpBonusFlat += _intOf(eff['value']);
        case 'initiative_bonus':
          initiativeBonus += _intOf(eff['value']);
        case 'proficiency_grant':
          final id = _refIdFor(eff, entitiesById);
          if (id == null) break;
          final tk = eff['target_kind'];
          switch (tk) {
            case 'skill':
              if (!skills.contains(id)) skills.add(id);
            case 'tool':
              if (!tools.contains(id)) tools.add(id);
            case 'saving_throw':
            case 'ability':
              if (!saves.contains(id)) saves.add(id);
            case 'armor_category':
              if (!armorCats.contains(id)) armorCats.add(id);
            case 'weapon_category':
              if (!weaponCats.contains(id)) weaponCats.add(id);
          }
        case 'language_grant':
          final id = _refIdFor(eff, entitiesById);
          if (id != null && !languages.contains(id)) languages.add(id);
        case 'spell_grant':
          final id = _refIdFor(eff, entitiesById);
          if (id != null && !grantedSpellIds.contains(id)) {
            grantedSpellIds.add(id);
          }
        case 'cantrip_grant':
          final id = _refIdFor(eff, entitiesById);
          if (id != null && !grantedCantripIds.contains(id)) {
            grantedCantripIds.add(id);
          }
        case 'spell_always_prepared':
          final id = _refIdFor(eff, entitiesById);
          if (id != null && !alwaysPreparedSpells.contains(id)) {
            alwaysPreparedSpells.add(id);
          }
        case 'damage_resistance':
          final id = _refIdFor(eff, entitiesById);
          if (id != null) {
            if (!damageRes.contains(id)) damageRes.add(id);
            noteSource(id, source);
          }
        case 'damage_immunity':
          final id = _refIdFor(eff, entitiesById);
          if (id != null) {
            if (!damageImmunities.contains(id)) damageImmunities.add(id);
            noteSource(id, source);
          }
        case 'damage_vulnerability':
          final id = _refIdFor(eff, entitiesById);
          if (id != null) {
            if (!damageVulnerabilities.contains(id)) {
              damageVulnerabilities.add(id);
            }
            noteSource(id, source);
          }
        case 'condition_immunity_grant':
          final id = _refIdFor(eff, entitiesById);
          if (id != null) {
            if (!conditionImmunities.contains(id)) {
              conditionImmunities.add(id);
            }
            noteSource(id, source);
          }
        case 'sense_grant':
        case 'truesight_grant':
        case 'blindsight_grant':
          final id = _refIdFor(eff, entitiesById);
          if (id != null) {
            if (!senses.contains(id)) senses.add(id);
            noteSource(id, source);
            // Optional range_ft payload — when present, keep the max range per
            // sense id. Drow Superior Darkvision = 120 overrides base 60.
            final payload = eff['payload'];
            int? range;
            if (payload is Map && payload['range_ft'] is int) {
              range = payload['range_ft'] as int;
            } else if (eff['range_ft'] is int) {
              range = eff['range_ft'] as int;
            }
            if (range != null && range > 0) {
              final prior = senseRanges[id] ?? 0;
              if (range > prior) senseRanges[id] = range;
            }
          }
        case 'expertise_grant':
          final id = _refIdFor(eff, entitiesById);
          if (id != null && !expertiseSkills.contains(id)) {
            expertiseSkills.add(id);
          }
        case 'temp_hp_grant':
          // Surface the grant for the sheet to render — actual write to PC
          // `temp_hp` is a runtime trigger (rest, kill, attack hit), not a
          // resolve-time decision.
          tempHpGrants.add(<String, dynamic>{
            'source': source,
            'formula': eff['payload'] is Map ? (eff['payload'] as Map)['formula'] : eff['formula'],
            'trigger': eff['payload'] is Map ? (eff['payload'] as Map)['trigger'] : eff['trigger'],
            'activation': eff['activation'],
          });
        case 'granted_action_grant':
          final id = _refIdFor(eff, entitiesById);
          if (id != null && !grantedActionIds.contains(id)) {
            grantedActionIds.add(id);
            noteSource(id, source);
          }
        case 'granted_bonus_action_grant':
          final id = _refIdFor(eff, entitiesById);
          if (id != null && !grantedBonusActionIds.contains(id)) {
            grantedBonusActionIds.add(id);
            noteSource(id, source);
          }
        case 'granted_reaction_grant':
          final id = _refIdFor(eff, entitiesById);
          if (id != null && !grantedReactionIds.contains(id)) {
            grantedReactionIds.add(id);
            noteSource(id, source);
          }
        case 'unarmored_ac_formula':
          unarmoredFormulas.add(Map<String, dynamic>.from(eff));
        case 'extra_attack_count':
        case 'extra_attack_bump':
          final v = _intOf(eff['value']);
          if (v > extraAttackCount) extraAttackCount = v;
        case 'crit_range_extend':
          final payload = eff['payload'];
          final t = (payload is Map) ? _intOf(payload['threshold']) : _intOf(eff['value']);
          if (t > 0 && t < critRangeMin) critRangeMin = t;
        case 'resource_pool_grant':
          // Compute pool max from count_formula + scales_with; runtime tracks current.
          final payload = (eff['payload'] is Map)
              ? Map<String, dynamic>.from(eff['payload'] as Map)
              : <String, dynamic>{};
          final scaledMax = evalScalesWith(eff['scales_with']);
          final formulaMax = _evalCountFormula(
            payload['count_formula']?.toString(),
            abilities: abilities,
            classLevels: classLevels,
            entitiesById: entitiesById,
          );
          final entry = <String, dynamic>{
            'pool_ref': payload['pool_ref'] ?? eff['target_ref'],
            'max': scaledMax ?? formulaMax ?? payload['count'] ?? eff['value'],
            'recharge': payload['recharge'] ?? eff['recharge'],
          };
          resourcePools.add(entry);
        case 'state_grant':
        case 'recovery_grant':
        case 'slot_recovery_short_rest':
        case 'concentration_advantage':
        case 'concentration_immune_to_damage_break':
        case 'reaction_attack_grant':
        case 'reaction_damage_reduction':
        case 'reaction_negate_via_save':
        case 'opportunity_attack_immunity_when_disengage_redundant':
        case 'enemy_cant_disengage_oa':
        case 'oa_stops_movement':
        case 'damage_reduction_flat':
        case 'ignore_cover':
        case 'ignore_long_range_disadvantage':
        case 'advantage_on':
        case 'disadvantage_on':
        case 'extra_damage_on_attack':
        case 'reroll_damage':
        case 'reroll_d20':
        case 'attack_bonus_typed':
        case 'damage_bonus_typed':
        case 'half_proficiency_to_unproficient_checks':
        case 'passive_score_bonus':
        case 'reliable_talent':
        case 'min_die_value':
        case 'swim_speed_equals_speed':
          // Marker — resolved post-pass to walking speed.
          extraSpeeds['swim'] = -1;
        case 'climb_speed_equals_speed':
          extraSpeeds['climb'] = -1;
        case 'fly_speed':
          // payload: {value_ft: int} for explicit speeds, otherwise equals walk.
          final payload = eff['payload'];
          final v = (payload is Map) ? _intOf(payload['value_ft']) : _intOf(eff['value']);
          if (v > 0) {
            final cur = extraSpeeds['fly'] ?? 0;
            if (v > cur) extraSpeeds['fly'] = v;
          } else {
            extraSpeeds['fly'] = -1;
          }
        case 'walk_on_liquid':
        case 'magical_unarmed_strikes':
        case 'damage_type_override':
        case 'spellcasting_ability_to_damage':
        case 'cantrip_count_bonus':
        case 'spell_cast_from_item':
        case 'weapon_mastery_grant':
        case 'weapon_mastery_count_bonus':
        case 'expertise_count':
        case 'choice_group':
          // Recognized kinds reserved for later passes (combat tracker, choice
          // resolution, weapon-specific attack pipeline). Silently accept here
          // so authoring data with these kinds doesn't spam warnings.
          break;
        default:
          warnings.add('Unhandled effect kind "${eff['kind']}" from $source');
      }
    }

    // ── 4b. Auto-grant walker. Scan every feat AND trait in the entity map;
    // if its `auto_granted_by` list matches the character's current
    // class+level / subclass / species / background, add it to the working
    // set. Feats also have their `effects` applied below; traits are
    // narrative-only and only surface on the sheet for display.
    final autoGrantedFeatIds = <String>[];
    final autoGrantedTraitIds = <String>[];
    bool matchesAutoGrant(List<Map<String, dynamic>> autoSources) {
      for (final src in autoSources) {
        final source = src['source']?.toString();
        final ref = src['source_ref'];
        final at = src['at_level'];
        final atLevel = (at is int) ? at : _intOf(at);
        switch (source) {
          case 'class':
            final classId = _resolveRef(ref, entitiesById);
            final lvl = (classId != null) ? (classLevels[classId] ?? 0) : 0;
            if (classId != null && lvl >= (atLevel == 0 ? 1 : atLevel)) {
              return true;
            }
          case 'subclass':
            final subId = _resolveRef(ref, entitiesById);
            if (subId == null || subId != subclassId) break;
            // Gate by the parent class's level so subclass L6/L10/L14
            // features don't auto-grant the moment the L3 subclass is
            // picked. Falls back to total character level when the
            // subclass doesn't declare a parent_class_ref.
            final minLevel = atLevel == 0 ? 1 : atLevel;
            final subEntity = entitiesById[subId];
            final parentClassId =
                _resolveRef(subEntity?.fields['parent_class_ref'], entitiesById);
            final levelHere = parentClassId != null
                ? (classLevels[parentClassId] ?? 0)
                : classLevels.values.fold<int>(0, (a, b) => a + b);
            if (levelHere >= minLevel) return true;
          case 'species':
            final spId = _resolveRef(ref, entitiesById);
            if (spId != null && spId == raceId) return true;
          case 'background':
            final bgId = _resolveRef(ref, entitiesById);
            if (bgId != null && bgId == backgroundId) return true;
        }
      }
      return false;
    }

    for (final e in entitiesById.values) {
      final autoSources = _readMapList(e.fields['auto_granted_by']);
      if (autoSources.isEmpty) continue;
      if (!matchesAutoGrant(autoSources)) continue;
      switch (e.categorySlug) {
        case 'feat':
          if (!featIds.contains(e.id) && !autoGrantedFeatIds.contains(e.id)) {
            autoGrantedFeatIds.add(e.id);
          }
        case 'trait':
          if (!autoGrantedTraitIds.contains(e.id)) {
            autoGrantedTraitIds.add(e.id);
          }
      }
    }

    // ── 5. Pass 3: feat effects (excluding level grants) ───────────────
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
        // Heuristic: bump first option ability that isn't already capped.
        final opts = _readMapList(feat.fields['asi_ability_options']);
        for (final opt in opts) {
          final name = opt['name'];
          if (name is! String) continue;
          final abbrev = _abilityAbbrev(name);
          if (abbrev == null) continue;
          final cur = abilities[abbrev] ?? 10;
          if (cur + asiAmount <= asiMax) {
            abilities[abbrev] = cur + asiAmount;
            break;
          }
        }
      }
      final effects = _readMapList(feat.fields['effects']);
      for (final eff in effects) {
        applyEffect(eff, 'feat:${feat.name}');
      }
      // Legacy granted_modifiers DSL — apply if present.
      final modifiers = _readMapList(feat.fields['granted_modifiers']);
      for (final m in modifiers) {
        applyEffect(_modifierAsEffect(m), 'feat:${feat.name}');
      }
    }

    // ── 6. Pass 4: feature-row effects (from class/subclass walk) ──────
    for (final row in pendingFeatureEffects) {
      applyEffect(row.eff, row.source);
    }

    // ── 7. Pass 5: species + background grants ─────────────────────────
    if (raceId != null) {
      final sp = entitiesById[raceId];
      if (sp != null) {
        speedBonus += 0; // species speed_ft is the BASE speed, not a bonus
        final speciesSource = 'species:${sp.name}';
        final modifiers = _readMapList(sp.fields['granted_modifiers']);
        for (final m in modifiers) {
          applyEffect(_modifierAsEffect(m), speciesSource);
        }
        for (final s in _readRefList(sp.fields['granted_senses'], entitiesById)) {
          if (!senses.contains(s)) senses.add(s);
          noteSource(s, speciesSource);
        }
        for (final r in _readRefList(sp.fields['granted_damage_resistances'], entitiesById)) {
          if (!damageRes.contains(r)) damageRes.add(r);
          noteSource(r, speciesSource);
        }
        for (final r in _readRefList(sp.fields['granted_damage_immunities'], entitiesById)) {
          if (!damageImmunities.contains(r)) damageImmunities.add(r);
          noteSource(r, speciesSource);
        }
        for (final r in _readRefList(sp.fields['granted_damage_vulnerabilities'], entitiesById)) {
          if (!damageVulnerabilities.contains(r)) damageVulnerabilities.add(r);
          noteSource(r, speciesSource);
        }
        for (final r in _readRefList(sp.fields['granted_condition_immunities'], entitiesById)) {
          if (!conditionImmunities.contains(r)) conditionImmunities.add(r);
          noteSource(r, speciesSource);
        }
        for (final l in _readRefList(sp.fields['granted_languages'], entitiesById)) {
          if (!languages.contains(l)) languages.add(l);
        }
        for (final sk in _readRefList(sp.fields['granted_skill_proficiencies'], entitiesById)) {
          if (!skills.contains(sk)) skills.add(sk);
        }
        for (final t in _readRefList(sp.fields['trait_refs'], entitiesById)) {
          if (!autoGrantedTraitIds.contains(t)) autoGrantedTraitIds.add(t);
          noteSource(t, speciesSource);
        }
        for (final a in _readRefList(sp.fields['granted_action_refs'], entitiesById)) {
          if (!grantedActionIds.contains(a)) grantedActionIds.add(a);
          noteSource(a, speciesSource);
        }
        for (final a in _readRefList(sp.fields['granted_bonus_action_refs'], entitiesById)) {
          if (!grantedBonusActionIds.contains(a)) grantedBonusActionIds.add(a);
          noteSource(a, speciesSource);
        }
        for (final a in _readRefList(sp.fields['granted_reaction_refs'], entitiesById)) {
          if (!grantedReactionIds.contains(a)) grantedReactionIds.add(a);
          noteSource(a, speciesSource);
        }
        for (final sp_ in _readRefList(sp.fields['granted_spell_refs'], entitiesById)) {
          if (!grantedSpellIds.contains(sp_)) grantedSpellIds.add(sp_);
          noteSource(sp_, speciesSource);
        }
        for (final sp_ in _readRefList(sp.fields['granted_cantrip_refs'], entitiesById)) {
          if (!grantedCantripIds.contains(sp_)) grantedCantripIds.add(sp_);
          noteSource(sp_, speciesSource);
        }
        _applyLevelGatedSpells(
          rows: _readMapList(sp.fields['granted_spells_at_level']),
          totalLevel: classLevels.values.fold<int>(0, (a, b) => a + b),
          entitiesById: entitiesById,
          grantedSpellIds: grantedSpellIds,
          grantedCantripIds: grantedCantripIds,
          resourcePools: resourcePools,
          noteSource: (id) => noteSource(id, speciesSource),
        );

        // Subspecies / lineage row — fold the matching entry's grants in
        // the same way as the top-level species fields. Looks up by name
        // because subspecies rows are scoped to the species entity and
        // don't have stable global IDs.
        if (subspeciesId != null && subspeciesId.isNotEmpty) {
          final options = _readMapList(sp.fields['subspecies_options']);
          for (final row in options) {
            if (row['name']?.toString() != subspeciesId) continue;
            final subSource = 'subspecies:${sp.name}/$subspeciesId';
            final subMods = _readMapList(row['granted_modifiers']);
            for (final m in subMods) {
              applyEffect(_modifierAsEffect(m), subSource);
            }
            for (final s in _readRefList(row['granted_senses'], entitiesById)) {
              if (!senses.contains(s)) senses.add(s);
              noteSource(s, subSource);
            }
            for (final r in _readRefList(
                row['granted_damage_resistances'], entitiesById)) {
              if (!damageRes.contains(r)) damageRes.add(r);
              noteSource(r, subSource);
            }
            for (final r in _readRefList(
                row['granted_damage_immunities'], entitiesById)) {
              if (!damageImmunities.contains(r)) damageImmunities.add(r);
              noteSource(r, subSource);
            }
            for (final r in _readRefList(
                row['granted_damage_vulnerabilities'], entitiesById)) {
              if (!damageVulnerabilities.contains(r)) {
                damageVulnerabilities.add(r);
              }
              noteSource(r, subSource);
            }
            for (final r in _readRefList(
                row['granted_condition_immunities'], entitiesById)) {
              if (!conditionImmunities.contains(r)) {
                conditionImmunities.add(r);
              }
              noteSource(r, subSource);
            }
            for (final l in _readRefList(row['granted_languages'], entitiesById)) {
              if (!languages.contains(l)) languages.add(l);
            }
            for (final sk in _readRefList(
                row['granted_skill_proficiencies'], entitiesById)) {
              if (!skills.contains(sk)) skills.add(sk);
            }
            for (final t in _readRefList(row['trait_refs'], entitiesById)) {
              if (!autoGrantedTraitIds.contains(t)) autoGrantedTraitIds.add(t);
              noteSource(t, subSource);
            }
            for (final a in _readRefList(
                row['granted_action_refs'], entitiesById)) {
              if (!grantedActionIds.contains(a)) grantedActionIds.add(a);
              noteSource(a, subSource);
            }
            for (final a in _readRefList(
                row['granted_bonus_action_refs'], entitiesById)) {
              if (!grantedBonusActionIds.contains(a)) {
                grantedBonusActionIds.add(a);
              }
              noteSource(a, subSource);
            }
            for (final a in _readRefList(
                row['granted_reaction_refs'], entitiesById)) {
              if (!grantedReactionIds.contains(a)) grantedReactionIds.add(a);
              noteSource(a, subSource);
            }
            for (final sp_ in _readRefList(
                row['granted_spell_refs'], entitiesById)) {
              if (!grantedSpellIds.contains(sp_)) grantedSpellIds.add(sp_);
              noteSource(sp_, subSource);
            }
            for (final sp_ in _readRefList(
                row['granted_cantrip_refs'], entitiesById)) {
              if (!grantedCantripIds.contains(sp_)) grantedCantripIds.add(sp_);
              noteSource(sp_, subSource);
            }
            _applyLevelGatedSpells(
              rows: _readMapList(row['granted_spells_at_level']),
              totalLevel:
                  classLevels.values.fold<int>(0, (a, b) => a + b),
              entitiesById: entitiesById,
              grantedSpellIds: grantedSpellIds,
              grantedCantripIds: grantedCantripIds,
              resourcePools: resourcePools,
              noteSource: (id) => noteSource(id, subSource),
            );
            break;
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
        // SRD 2024 p.83: each background allows either +2/+1 to two abilities
        // or +1/+1/+1 to three. PC stores the chosen distribution as
        // `background_asi: {STR: 2, CON: 1}` — resolver bumps the abilities
        // here. Total must be 3; resolver applies whatever is stored without
        // re-validating, so the wizard/editor enforces the distribution rule.
        // Bumps gated by ability_score_options when present; out-of-list
        // entries are dropped with a warning. Cap at 20.
        final asi = _readIntMap(fields['background_asi']);
        if (asi.isNotEmpty) {
          final allowed = <String>{};
          for (final r in _readRefList(
              bg.fields['ability_score_options'], entitiesById)) {
            final name = entitiesById[r]?.name ?? '';
            final abbrev = _abilityAbbrev(name);
            if (abbrev != null) allowed.add(abbrev);
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

    // ── 8. Class proficiency grants (saves + weapon/armor categories) ──
    for (final classId in classLevels.keys) {
      final cls = entitiesById[classId];
      if (cls == null) continue;
      for (final s in _readRefList(cls.fields['saving_throw_refs'], entitiesById)) {
        if (!saves.contains(s)) saves.add(s);
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
        final pickedOption = equipmentChoices[groupId];
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
      tempHpGrants: tempHpGrants,
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
    List<({Map<String, dynamic> eff, String source})> pendingEffects,
  ) {
    // `kind` mirrors the tags `applyEffect` callers already use elsewhere
    // (`class:`, `subclass:`) so `cleanSource` strips them uniformly.
    final kind = src.categorySlug == 'subclass' ? 'subclass' : 'class';
    final source = '$kind:${src.name}';
    final rows = _readMapList(src.fields['features']);
    for (final r in rows) {
      final lvl = (r['level'] is int) ? r['level'] as int : 1;
      if (lvl > level) continue;
      out.add(ResolvedFeatureRow(
        level: lvl,
        description: (r['description'] ?? '').toString(),
        sourceEntityId: src.id,
      ));
      // Legacy inline effects on the row still applied for backwards compat
      // during migration; new content delegates to `auto_granted_by` on the
      // ref'd feat/trait entity, picked up in Pass 4b.
      final effs = _readMapList(r['effects']);
      for (final e in effs) {
        pendingEffects.add((eff: e, source: source));
      }
    }
  }

  static String? _findEntityIdByName(
    Map<String, Entity> all,
    String slug,
    String name,
  ) {
    for (final e in all.values) {
      if (e.categorySlug == slug && e.name == name) return e.id;
    }
    return null;
  }

  /// Compute the PC's armor class from equipped armor + Dex (capped by
  /// armor row), shield bonus, generic `ac_bonus` effects, and any
  /// `unarmored_ac_formula` effects whose predicates already resolved.
  /// Mirrors SRD §1 Armor Class rules. Surfaced on EffectiveCharacter so
  /// the sheet's AC chip refreshes whenever inventory equip flags change
  /// without forcing the player to retype the value into combat_stats.
  static int _computeArmorClass({
    required Map<String, dynamic> fields,
    required Map<String, Entity> entitiesById,
    required Map<String, int> abilities,
    required int acBonus,
    required List<Map<String, dynamic>> unarmoredFormulas,
  }) {
    final dex = ((abilities['DEX'] ?? 10) - 10) >> 1;
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
      return base + dexContrib + (hasShield ? 2 : 0) + acBonus;
    }
    // Unarmored: SRD default 10 + Dex; replaced by the highest matching
    // unarmored_ac_formula (Barbarian, Monk, Draconic Sorcerer). Shield is
    // additive when the formula allows it (Barbarian yes, Monk no).
    var best = 10 + dex + (hasShield ? 2 : 0);
    for (final f in unarmoredFormulas) {
      final payload = f['payload'];
      if (payload is! Map) continue;
      final baseRaw = payload['base'];
      final base = baseRaw is int ? baseRaw : 10;
      final mods = payload['ability_mods'];
      var sum = base;
      if (mods is List) {
        for (final m in mods) {
          if (m is String) {
            sum += ((abilities[m] ?? 10) - 10) >> 1;
          }
        }
      }
      final shieldAllowed = payload['shield_allowed'] == true;
      final withShield = sum + (hasShield && shieldAllowed ? 2 : 0);
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
        if (row['equipped'] == true) yield row['id'];
      }
    }
  }

  static String? _resolveRef(Object? raw, Map<String, Entity> all) {
    if (raw is String) return all.containsKey(raw) ? raw : null;
    if (raw is Map) {
      final slug = raw['_ref'] ?? raw['slug'];
      final name = raw['name'];
      if (slug is String && name is String) {
        return _findEntityIdByName(all, slug, name);
      }
    }
    return null;
  }

  static String? _refIdFor(Map<String, dynamic> eff, Map<String, Entity> all) {
    return _resolveRef(eff['target_ref'], all);
  }

  /// Resolve a `count_formula` token (e.g. `wis_mod_min_1`, `monk_level`,
  /// `paladin_level_x5`) to an integer using the PC's abilities and class
  /// levels. Returns null when the token is unknown so the caller can fall
  /// back to other count sources (scaled tables, raw payload count).
  static int? _evalCountFormula(
    String? token, {
    required Map<String, int> abilities,
    required Map<String, int> classLevels,
    required Map<String, Entity> entitiesById,
  }) {
    if (token == null || token.isEmpty) return null;
    int mod(String ab) => ((abilities[ab] ?? 10) - 10) >> 1;
    int classLevel(String name) {
      for (final entry in classLevels.entries) {
        final e = entitiesById[entry.key];
        if (e == null) continue;
        if (e.name.toLowerCase() == name.toLowerCase()) return entry.value;
      }
      return 0;
    }

    switch (token.toLowerCase()) {
      case 'str_mod':
        return mod('STR');
      case 'dex_mod':
        return mod('DEX');
      case 'con_mod':
        return mod('CON');
      case 'int_mod':
        return mod('INT');
      case 'wis_mod':
        return mod('WIS');
      case 'cha_mod':
        return mod('CHA');
      case 'str_mod_min_1':
        return mod('STR') < 1 ? 1 : mod('STR');
      case 'dex_mod_min_1':
        return mod('DEX') < 1 ? 1 : mod('DEX');
      case 'con_mod_min_1':
        return mod('CON') < 1 ? 1 : mod('CON');
      case 'int_mod_min_1':
        return mod('INT') < 1 ? 1 : mod('INT');
      case 'wis_mod_min_1':
        return mod('WIS') < 1 ? 1 : mod('WIS');
      case 'cha_mod_min_1':
        return mod('CHA') < 1 ? 1 : mod('CHA');
      case 'barbarian_level':
        return classLevel('Barbarian');
      case 'bard_level':
        return classLevel('Bard');
      case 'cleric_level':
        return classLevel('Cleric');
      case 'druid_level':
        return classLevel('Druid');
      case 'fighter_level':
        return classLevel('Fighter');
      case 'monk_level':
        return classLevel('Monk');
      case 'paladin_level':
        return classLevel('Paladin');
      case 'paladin_level_x5':
        return classLevel('Paladin') * 5;
      case 'ranger_level':
        return classLevel('Ranger');
      case 'rogue_level':
        return classLevel('Rogue');
      case 'sorcerer_level':
        return classLevel('Sorcerer');
      case 'warlock_level':
        return classLevel('Warlock');
      case 'wizard_level':
        return classLevel('Wizard');
      case 'character_level':
        return classLevels.values.fold<int>(0, (a, b) => a + b);
      case 'pb':
      case 'proficiency_bonus':
        final lvl = classLevels.values.fold<int>(0, (a, b) => a + b);
        if (lvl >= 17) return 6;
        if (lvl >= 13) return 5;
        if (lvl >= 9) return 4;
        if (lvl >= 5) return 3;
        return 2;
    }
    return null;
  }

  static Map<String, dynamic> _modifierAsEffect(Map<String, dynamic> m) {
    // Re-shape grantedModifiers row into effect kinds the resolver knows.
    final kind = (m['kind'] ?? '').toString();
    final mapped = <String, dynamic>{...m};
    switch (kind) {
      case 'ac_bonus':
      case 'speed_bonus':
      case 'hp_bonus_flat':
      case 'hp_bonus_per_level':
      case 'initiative_bonus':
      case 'proficiency_grant':
      case 'language_grant':
      case 'spell_grant':
      case 'cantrip_grant':
      case 'ability_score_bonus':
        // already same kind name
        break;
      default:
        // Unknown legacy kinds get a synthetic "unhandled" tag; resolver warns.
        mapped['kind'] = kind;
    }
    return mapped;
  }

  static List<String> _readStringList(Object? raw) {
    if (raw is List) return [for (final v in raw) if (v is String) v];
    return const [];
  }

  static String? _readNullableString(Object? raw) =>
      raw is String && raw.isNotEmpty ? raw : null;

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
