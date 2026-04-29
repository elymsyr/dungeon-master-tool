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
    final pendingFeatureEffects = <Map<String, dynamic>>[];

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
        // Subclass-grant level lives on the parent class; assume player chose
        // a subclass that's reached by the largest class level. Resolver picks
        // max class level as the gate — refine if multi-class subclasses exist.
        final maxClassLevel = classLevels.values.fold<int>(0, (a, b) => a > b ? a : b);
        final grantedAt = (sub.fields['granted_at_level'] is int)
            ? sub.fields['granted_at_level'] as int
            : 1;
        if (maxClassLevel >= grantedAt) {
          _collectFeaturesByLevel(
            sub,
            maxClassLevel,
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
    var hpBonusFlat = 0;
    var hpBonusPerLevel = 0;
    var initiativeBonus = 0;
    final grantedSpellIds = <String>[];
    final grantedCantripIds = <String>[];
    final senses = <String>[];
    final damageRes = <String>[];
    final skills = <String>[];
    final tools = <String>[];
    final saves = <String>[];
    final languages = <String>[];
    final weaponCats = <String>[];
    final armorCats = <String>[];

    void applyEffect(Map<String, dynamic> eff, String source) {
      switch (eff['kind']) {
        case 'class_level_grant':
          break; // already applied in pass 1
        case 'ac_bonus':
          acBonus += _intOf(eff['value']);
        case 'speed_bonus':
          speedBonus += _intOf(eff['value']);
        case 'hp_bonus_per_level':
          hpBonusPerLevel += _intOf(eff['value']);
        case 'hp_bonus_flat':
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
        default:
          warnings.add('Unhandled effect kind "${eff['kind']}" from $source');
      }
    }

    // ── 5. Pass 3: feat effects (excluding level grants) ───────────────
    for (final fid in featIds) {
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
    for (final eff in pendingFeatureEffects) {
      applyEffect(eff, 'feature');
    }

    // ── 7. Pass 5: species + background grants ─────────────────────────
    if (raceId != null) {
      final sp = entitiesById[raceId];
      if (sp != null) {
        speedBonus += 0; // species speed_ft is the BASE speed, not a bonus
        final modifiers = _readMapList(sp.fields['granted_modifiers']);
        for (final m in modifiers) {
          applyEffect(_modifierAsEffect(m), 'species:${sp.name}');
        }
        for (final s in _readRefList(sp.fields['granted_senses'], entitiesById)) {
          if (!senses.contains(s)) senses.add(s);
        }
        for (final r in _readRefList(sp.fields['granted_damage_resistances'], entitiesById)) {
          if (!damageRes.contains(r)) damageRes.add(r);
        }
        for (final l in _readRefList(sp.fields['granted_languages'], entitiesById)) {
          if (!languages.contains(l)) languages.add(l);
        }
        for (final sk in _readRefList(sp.fields['granted_skill_proficiencies'], entitiesById)) {
          if (!skills.contains(sk)) skills.add(sk);
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
      speedBonus: speedBonus,
      hpBonusFlat: hpBonusFlat,
      hpBonusPerLevel: hpBonusPerLevel,
      initiativeBonus: initiativeBonus,
      grantedSpellIds: grantedSpellIds,
      grantedCantripIds: grantedCantripIds,
      activeFeatures: activeFeatures,
      inventory: inventory,
      senseEntityIds: senses,
      damageResistanceIds: damageRes,
      warnings: warnings,
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────

  static void _collectFeaturesByLevel(
    Entity src,
    int level,
    List<ResolvedFeatureRow> out,
    List<Map<String, dynamic>> pendingEffects,
  ) {
    final rows = _readMapList(src.fields['features']);
    for (final r in rows) {
      final lvl = (r['level'] is int) ? r['level'] as int : 1;
      if (lvl > level) continue;
      out.add(ResolvedFeatureRow(
        level: lvl,
        name: (r['name'] ?? '').toString(),
        kind: (r['kind'] ?? '').toString(),
        description: (r['description'] ?? '').toString(),
        sourceEntityId: src.id,
      ));
      final effs = _readMapList(r['effects']);
      pendingEffects.addAll(effs);
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
