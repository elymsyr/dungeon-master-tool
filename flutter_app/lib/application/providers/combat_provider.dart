import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/character.dart';
import '../../domain/entities/entity.dart';
import '../../domain/entities/events/event_envelope.dart';
import '../../domain/entities/events/event_types.dart';
import '../../domain/entities/schema/encounter_config.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/entities/session.dart';
import '../services/event_bus.dart';
import '../services/pending_write_buffer.dart';
import '../services/undo_redo_mixin.dart';
import 'campaign_provider.dart';
import 'character_provider.dart';
import 'entity_provider.dart';
import 'event_bus_provider.dart';

const _uuid = Uuid();
final _rng = Random();

/// Combat state — aktif encounter + event log.
class CombatState {
  final List<Encounter> encounters;
  final String? activeEncounterId;
  final List<String> eventLog;

  const CombatState({
    this.encounters = const [],
    this.activeEncounterId,
    this.eventLog = const [],
  });

  Encounter? get activeEncounter {
    if (activeEncounterId == null) return null;
    for (final e in encounters) {
      if (e.id == activeEncounterId) return e;
    }
    return null;
  }

  CombatState copyWith({
    List<Encounter>? encounters,
    String? activeEncounterId,
    List<String>? eventLog,
  }) {
    return CombatState(
      encounters: encounters ?? this.encounters,
      activeEncounterId: activeEncounterId ?? this.activeEncounterId,
      eventLog: eventLog ?? this.eventLog,
    );
  }
}

class CombatNotifier extends StateNotifier<CombatState>
    with UndoRedoMixin<CombatState> {
  final Map<String, Entity> Function() _getEntities;
  final WorldSchema Function() _getSchema;
  final List<Character> Function() _getCharacters;

  final Map<String, dynamic>? Function() _getCampaignData;
  final AppEventBus _eventBus;
  // F3 row-level: writes `combat_state` key only in `world_settings.settings_json`.
  // Replaces the previous global markDirty path that triggered a full
  // `world_repository.save` (delete+insertAll on world_entities included).
  final Future<void> Function(Map<String, dynamic> patch) _saveSettingsPatch;
  // HP/ac write-back for characters (encounter ↔ character card sync).
  final Future<void> Function(Character) _saveCharacter;

  CombatNotifier(this._getEntities, this._getSchema, this._getCharacters,
      this._getCampaignData, this._eventBus, this._saveSettingsPatch,
      this._saveCharacter)
      : super(const CombatState()) {
    _loadFromCampaign();
  }

  Character? _characterByEntityId(String? entityId) {
    if (entityId == null) return null;
    for (final c in _getCharacters()) {
      if (c.entity.id == entityId) return c;
    }
    return null;
  }

  /// Mirror selected combat fields back onto the source character entity so
  /// the character card and encounter row stay in sync. Writes BOTH the
  /// flat top-level keys (header HP indicator reads these via
  /// EffectiveCharacter) AND the nested `combat_stats` sub-map (the
  /// in-card Combat Stats section reads these). Skipping the nested write
  /// caused the card's inner HP value to drift behind the header bar after
  /// encounter +/- edits.
  void _syncCharacterFields(String? entityId,
      {int? hp, int? maxHp, int? ac}) {
    final character = _characterByEntityId(entityId);
    if (character == null) return;
    final fields = Map<String, dynamic>.from(character.entity.fields);
    var changed = false;
    if (hp != null && fields['hp'] != hp) {
      fields['hp'] = hp;
      changed = true;
    }
    if (maxHp != null && fields['max_hp'] != maxHp) {
      fields['max_hp'] = maxHp;
      changed = true;
    }
    if (ac != null && fields['ac'] != ac) {
      fields['ac'] = ac;
      changed = true;
    }
    final csKey = _encounterConfig.combatStatsFieldKey;
    final rawCs = fields[csKey];
    if (rawCs is Map) {
      final cs = Map<String, dynamic>.from(rawCs);
      var csChanged = false;
      if (hp != null && cs['hp']?.toString() != hp.toString()) {
        cs['hp'] = hp.toString();
        csChanged = true;
      }
      if (maxHp != null && cs['max_hp']?.toString() != maxHp.toString()) {
        cs['max_hp'] = maxHp.toString();
        csChanged = true;
      }
      if (ac != null && cs['ac']?.toString() != ac.toString()) {
        cs['ac'] = ac.toString();
        csChanged = true;
      }
      if (csChanged) {
        fields[csKey] = cs;
        changed = true;
      }
    }
    if (!changed) return;
    final patched = character.copyWith(
      entity: character.entity.copyWith(fields: fields),
    );
    // ignore: discarded_futures
    _saveCharacter(patched);
  }

  String? get _campaignId => _getCampaignData()?['world_id'] as String?;

  void _loadFromCampaign() {
    final data = _getCampaignData();
    if (data == null) return;
    final combatData = data['combat_state'];
    if (combatData is Map) {
      loadSessionState(Map<String, dynamic>.from(combatData));
    }
    clearUndoRedo();
  }

  void undo() {
    final restored = popUndo(state);
    if (restored != null) {
      state = restored;
      _saveAndNotify();
    }
  }

  void redo() {
    final restored = popRedo(state);
    if (restored != null) {
      state = restored;
      _saveAndNotify();
    }
  }

  void _saveAndNotify() {
    final data = _getCampaignData();
    final session = getSessionState();
    if (data != null) {
      data['combat_state'] = session;
    }
    // F3 row-level: patch only `combat_state` in settings_json. No global
    // markDirty → autosave debounce skipped entirely; `world_entities`
    // delete+insertAll cycle no longer fires for combat ticks.
    // ignore: discarded_futures
    _saveSettingsPatch({'combat_state': session});
  }

  EncounterConfig get _encounterConfig => _getSchema().encounterConfig;

  // --- Encounter Management ---

  void createEncounter(String name) {
    pushUndo(state);
    final enc = Encounter(id: _uuid.v4(), name: name);
    state = state.copyWith(
      encounters: [...state.encounters, enc],
      activeEncounterId: enc.id,
    );
    _log('New encounter: $name');
    _saveAndNotify();
  }

  void switchEncounter(String eid) {
    state = state.copyWith(activeEncounterId: eid);
  }

  void deleteEncounter(String eid) {
    if (state.encounters.length <= 1) return;
    pushUndo(state);
    final updated = state.encounters.where((e) => e.id != eid).toList();
    final newActive = state.activeEncounterId == eid ? updated.first.id : state.activeEncounterId;
    state = state.copyWith(encounters: updated, activeEncounterId: newActive);
    _saveAndNotify();
  }

  // --- Helpers ---

  /// Encounter'a eklenebilen kategori slug'ları. v1 schema'da `combat_stats`
  /// map field'ı vardı; v2 schema (builtin_dnd5e_v2) flat field'lara geçti
  /// (ac, hp_average, initiative_modifier...). Tek doğru gate
  /// `allowedInSections.contains('encounter')` — schema-author intent'i de
  /// yansıtıyor.
  Set<String> get combatCapableSlugs {
    final schema = _getSchema();
    final slugs = <String>{};
    for (final cat in schema.categories) {
      if (cat.allowedInSections.contains('encounter')) {
        slugs.add(cat.slug);
      }
    }
    return slugs;
  }

  /// Entity'nin encounter'a eklenebilir olup olmadığını kontrol eder.
  /// Characters (oyuncu karakterleri) her zaman eklenebilir — kategori
  /// slug'ı schema'da encounter section'da listelenmese bile.
  bool canAddToEncounter(String entityId) {
    if (_characterByEntityId(entityId) != null) return true;
    final entities = _getEntities();
    final entity = entities[entityId];
    if (entity == null) return false;
    return combatCapableSlugs.contains(entity.categorySlug);
  }

  // --- Combatant Management ---

  void addCombatantFromEntity(String entityId) {
    final enc = state.activeEncounter;
    if (enc == null) return;
    if (!canAddToEncounter(entityId)) return;
    pushUndo(state);
    final entities = _getEntities();
    final entity = entities[entityId];
    if (entity == null) return;

    final cfg = _encounterConfig;
    final combatStats = entity.fields[cfg.combatStatsFieldKey];

    // Initiative — v1 reads dice spec from combatStats.initiative; v2 monster
    // /animal flat schema uses initiative_modifier (int) or initiative_score.
    String? initSpec;
    if (combatStats is Map) {
      initSpec = combatStats[cfg.initiativeSubField]?.toString();
    }
    initSpec ??= _flatInitSpec(entity.fields);
    final initRoll = _rollInitFromSpec(initSpec);

    // HP, AC — combatStats map > flat fields. Char (player) entity flat
    // schema stores `hp`/`max_hp` (current+max); monster/animal v2 uses
    // `hp_average` (single value) + `ac`. For characters we preserve the
    // live current HP; non-char entities start at full HP.
    final isCharacter = _characterByEntityId(entityId) != null;
    final int maxHp;
    final int currentHp;
    final int ac;
    if (combatStats is Map) {
      final fallback = _parseFlatInt(entity.fields, 'hp_average', 10);
      maxHp = _parseInt(combatStats, 'max_hp',
          _parseInt(combatStats, 'hp', fallback));
      currentHp = _parseInt(combatStats, 'hp', maxHp);
      ac = _parseInt(combatStats, 'ac', _parseFlatInt(entity.fields, 'ac', 10));
    } else if (isCharacter) {
      final flatMax = _parseFlatInt(entity.fields, 'max_hp', 0);
      final flatHp = _parseFlatInt(entity.fields, 'hp', flatMax);
      maxHp = flatMax > 0 ? flatMax : flatHp;
      currentHp = flatHp.clamp(0, maxHp == 0 ? flatHp : maxHp);
      ac = _parseFlatInt(entity.fields, 'ac', 10);
    } else {
      final avgHp = _parseFlatInt(entity.fields, 'hp_average', 10);
      maxHp = avgHp;
      currentHp = avgHp;
      ac = _parseFlatInt(entity.fields, 'ac', 10);
    }

    // Deep snapshot of source stats — encounter is a COPY, never reads
    // back from the live entity. v1 carries the combatStats map; v2 has
    // flat fields, so synthesize an equivalent map.
    final Map<String, dynamic> snapshotStats;
    if (combatStats is Map) {
      snapshotStats = Map<String, dynamic>.from(combatStats);
    } else {
      snapshotStats = <String, dynamic>{
        for (final k in const ['hp_average', 'ac', 'initiative_modifier',
            'initiative_score', 'speed', 'cr'])
          if (entity.fields[k] != null) k: entity.fields[k],
      };
    }
    snapshotStats['hp'] = currentHp.toString();
    snapshotStats['max_hp'] = maxHp.toString();
    snapshotStats['ac'] = ac.toString();

    final combatant = Combatant(
      id: _uuid.v4(),
      name: entity.name,
      init: initRoll,
      ac: ac,
      hp: currentHp,
      maxHp: maxHp,
      entityId: entityId,
      stats: snapshotStats,
    );

    _updateEncounter(enc.copyWith(combatants: [...enc.combatants, combatant]));
    _log('Added ${entity.name} (Init: $initRoll, AC: $ac, HP: $currentHp/$maxHp)');
    _sortByInitiative();
    _eventBus.emit(EventEnvelope.now(
      EventTypes.sessionCombatantAdded,
      {
        'session_id': enc.id,
        'combatant_id': combatant.id,
        'name': combatant.name,
      },
      campaignId: _campaignId,
    ));
  }

  void addDirectRow(String name, {Map<String, String> stats = const {}}) {
    final enc = state.activeEncounter;
    if (enc == null) return;
    pushUndo(state);
    final cfg = _encounterConfig;

    final init = int.tryParse(stats[cfg.initiativeSubField] ?? '') ?? 0;
    final hp = int.tryParse(stats['hp'] ?? '') ?? 10;
    final maxHp = int.tryParse(stats['max_hp'] ?? '') ?? hp;
    final ac = int.tryParse(stats['ac'] ?? '') ?? 10;

    final combatant = Combatant(
      id: _uuid.v4(),
      name: name,
      init: init,
      ac: ac,
      hp: hp,
      maxHp: maxHp,
    );

    _updateEncounter(enc.copyWith(combatants: [...enc.combatants, combatant]));
    _log('Added $name (Init: $init, AC: $ac, HP: $hp/$maxHp)');
    _sortByInitiative();
  }

  void addAllPlayers() {
    final enc = state.activeEncounter;
    if (enc == null) return;
    final existingIds = enc.combatants.map((c) => c.entityId).toSet();
    final worldId = _campaignId;
    // 039 unified character model: "player" entity kategorisi sabit değil;
    // owner'lı (claim edilmiş) karakterler oyuncu karakterleridir. World
    // bağlı olanları + worldless (orphan) ownerlı'ları al.
    for (final c in _getCharacters()) {
      if (c.ownerId == null || c.ownerId!.isEmpty) continue;
      if (worldId != null && c.worldId != null && c.worldId != worldId) continue;
      if (existingIds.contains(c.entity.id)) continue;
      addCombatantFromEntity(c.entity.id);
    }
  }

  void deleteCombatant(String combatantId) {
    final enc = state.activeEncounter;
    if (enc == null) return;
    pushUndo(state);
    final updated = enc.combatants.where((c) => c.id != combatantId).toList();
    _updateEncounter(enc.copyWith(combatants: updated));
    _saveAndNotify();
  }

  void clearAll() {
    final enc = state.activeEncounter;
    if (enc == null) return;
    pushUndo(state);
    _updateEncounter(enc.copyWith(combatants: [], turnIndex: -1, round: 1));
    _log('Combat cleared');
    _saveAndNotify();
  }

  // --- Turn & Round ---

  void nextTurn() {
    final enc = state.activeEncounter;
    if (enc == null || enc.combatants.isEmpty) return;
    pushUndo(state);

    var newIndex = enc.turnIndex + 1;
    var newRound = enc.round;

    if (newIndex >= enc.combatants.length) {
      newIndex = 0;
      newRound++;
    }

    // Condition süreleri düşür — sadece yeni round başında
    final isNewRound = newRound > enc.round;
    final updatedCombatants = isNewRound
        ? enc.combatants.map((c) {
            if (c.conditions.isEmpty) return c;
            final updatedConditions = c.conditions.map((cond) {
              if (cond.duration == null || cond.duration! <= 0) return cond;
              return cond.copyWith(duration: cond.duration! - 1);
            }).where((cond) => cond.duration == null || cond.duration! > 0).toList();
            return c.copyWith(conditions: updatedConditions);
          }).toList()
        : enc.combatants;

    _updateEncounter(enc.copyWith(
      combatants: updatedCombatants,
      turnIndex: newIndex,
      round: newRound,
    ));

    final current = updatedCombatants[newIndex];
    if (newIndex == 0 && newRound > enc.round) {
      _log('Round $newRound — ${current.name}\'s turn');
    } else {
      _log('${current.name}\'s turn');
    }
    _saveAndNotify();
    _eventBus.emit(EventEnvelope.now(
      EventTypes.sessionTurnAdvanced,
      {
        'session_id': enc.id,
        'new_active_combatant_id': current.id,
      },
      campaignId: _campaignId,
    ));
  }

  /// Reroll initiative for every combatant in the active encounter. [dSides]
  /// selects the base die (the user picks d4/d6/...d20 in the UI). Each
  /// combatant's roll = 1d[dSides] + eval(entity.combat_stats[initiative]).
  void rollInitiatives({int dSides = 20}) {
    final enc = state.activeEncounter;
    if (enc == null) return;
    pushUndo(state);

    final entities = _getEntities();
    final cfg = _encounterConfig;

    final rolled = enc.combatants.map((c) {
      String? spec;
      if (c.entityId != null) {
        final e = entities[c.entityId];
        final cs = e?.fields[cfg.combatStatsFieldKey];
        if (cs is Map) spec = cs[cfg.initiativeSubField]?.toString();
      }
      return c.copyWith(init: _rollInitFromSpec(spec, dSides: dSides));
    }).toList();

    _updateEncounter(enc.copyWith(combatants: rolled));
    _sortByInitiative();

    final summary = rolled.map((c) => '${c.name}(${c.init})').join(', ');
    _log('Initiative: $summary');
    _saveAndNotify();
  }

  /// Roll 1d[dSides] + the parsed dice spec for an initiative roll.
  /// Spec accepts an arbitrary mix of flat modifiers and dice rolls,
  /// e.g. `-2`, `+1d4`, `1d20+3`, `+2+1d6-1`. Empty / null → just 1d[dSides].
  int _rollInitFromSpec(String? spec, {int dSides = 20}) {
    final base = _rng.nextInt(dSides) + 1;
    return base + _evalDiceSpec(spec);
  }

  /// Evaluate a dice expression to an integer (rolls all `NdM` terms).
  /// Tokens: `[+|-]?(NdM|N)`. Whitespace is ignored. Unrecognized input → 0.
  static final RegExp _diceSpecRegex =
      RegExp(r'([+-])?(\d*)d(\d+)|([+-])?(\d+)', caseSensitive: false);

  static int _evalDiceSpec(String? spec) {
    if (spec == null) return 0;
    final s = spec.replaceAll(' ', '');
    if (s.isEmpty) return 0;
    var total = 0;
    for (final m in _diceSpecRegex.allMatches(s)) {
      if (m.group(3) != null) {
        // NdM term
        final sign = m.group(1) == '-' ? -1 : 1;
        final n = (m.group(2) == null || m.group(2)!.isEmpty)
            ? 1
            : int.parse(m.group(2)!);
        final sides = int.parse(m.group(3)!);
        if (sides <= 0 || n <= 0) continue;
        var sum = 0;
        for (var i = 0; i < n; i++) {
          sum += _rng.nextInt(sides) + 1;
        }
        total += sign * sum;
      } else if (m.group(5) != null) {
        // Flat integer term
        final sign = m.group(4) == '-' ? -1 : 1;
        total += sign * int.parse(m.group(5)!);
      }
    }
    return total;
  }

  // --- HP & Conditions ---

  void modifyHp(String combatantId, int delta) {
    final enc = state.activeEncounter;
    if (enc == null) return;
    pushUndo(state);

    final updated = enc.combatants.map((c) {
      if (c.id != combatantId) return c;
      final newHp = (c.hp + delta).clamp(0, c.maxHp);
      final newStats = Map<String, dynamic>.from(c.stats);
      newStats['hp'] = newHp.toString();
      return c.copyWith(hp: newHp, stats: newStats);
    }).toList();

    _updateEncounter(enc.copyWith(combatants: updated));

    final c = updated.firstWhere((c) => c.id == combatantId);
    _log('${c.name} HP ${delta > 0 ? '+' : ''}$delta (${c.hp}/${c.maxHp})');

    _syncCharacterFields(c.entityId, hp: c.hp, maxHp: c.maxHp);
    _saveAndNotify();
    _eventBus.emit(EventEnvelope.now(
      EventTypes.sessionCombatantUpdated,
      {
        'session_id': enc.id,
        'combatant_id': combatantId,
        'changes': {'hp': c.hp},
      },
      campaignId: _campaignId,
    ));
  }

  /// Update a single combat-stat subfield on the combatant's snapshot.
  /// Pure combatant mutation — never touches the source entity.
  void setStat(String combatantId, String subKey, String value) {
    final enc = state.activeEncounter;
    if (enc == null) return;
    pushUndo(state);

    final updated = enc.combatants.map((c) {
      if (c.id != combatantId) return c;
      final newStats = Map<String, dynamic>.from(c.stats);
      newStats[subKey] = value;

      // Mirror canonical fields so the rest of the codebase (UI badges,
      // sorting, condition logic) reads consistent values.
      int hp = c.hp;
      int maxHp = c.maxHp;
      int ac = c.ac;
      final asInt = int.tryParse(value);
      if (asInt != null) {
        if (subKey == 'hp') hp = asInt.clamp(0, maxHp);
        if (subKey == 'max_hp') {
          maxHp = asInt;
          if (hp > maxHp) hp = maxHp;
        }
        if (subKey == 'ac') ac = asInt;
      }
      return c.copyWith(stats: newStats, hp: hp, maxHp: maxHp, ac: ac);
    }).toList();

    _updateEncounter(enc.copyWith(combatants: updated));
    final c = updated.firstWhere((c) => c.id == combatantId);
    _syncCharacterFields(c.entityId, hp: c.hp, maxHp: c.maxHp, ac: c.ac);
    _saveAndNotify();
  }

  void addCondition(String combatantId, String condName, int? duration, {String? entityId}) {
    final enc = state.activeEncounter;
    if (enc == null) return;
    pushUndo(state);

    final updated = enc.combatants.map((c) {
      if (c.id != combatantId) return c;
      return c.copyWith(conditions: [
        ...c.conditions,
        CombatCondition(
          name: condName,
          duration: duration,
          initialDuration: duration,
          entityId: entityId,
        ),
      ]);
    }).toList();

    _updateEncounter(enc.copyWith(combatants: updated));
    _log('${updated.firstWhere((c) => c.id == combatantId).name} gains $condName${duration != null ? ' ($duration rounds)' : ''}');
    _saveAndNotify();
  }

  void removeCondition(String combatantId, String condName) {
    final enc = state.activeEncounter;
    if (enc == null) return;
    pushUndo(state);

    final updated = enc.combatants.map((c) {
      if (c.id != combatantId) return c;
      return c.copyWith(conditions: c.conditions.where((cond) => cond.name != condName).toList());
    }).toList();

    _updateEncounter(enc.copyWith(combatants: updated));
    _saveAndNotify();
  }

  void updateConditionDuration(String combatantId, String condName, int? newDuration) {
    final enc = state.activeEncounter;
    if (enc == null) return;
    pushUndo(state);

    final updated = enc.combatants.map((c) {
      if (c.id != combatantId) return c;
      return c.copyWith(conditions: c.conditions.map((cond) {
        if (cond.name != condName) return cond;
        return cond.copyWith(
          duration: newDuration,
          initialDuration: newDuration ?? cond.initialDuration,
        );
      }).toList());
    }).toList();

    _updateEncounter(enc.copyWith(combatants: updated));
    _saveAndNotify();
  }

  // --- Serialization ---

  Map<String, dynamic> getSessionState() {
    return {
      'encounters': state.encounters.map((e) => e.toJson()).toList(),
      'active_encounter_id': state.activeEncounterId,
      'event_log': state.eventLog,
    };
  }

  void loadSessionState(Map<String, dynamic> data) {
    final encList = (data['encounters'] as List?)?.map((e) =>
      Encounter.fromJson(Map<String, dynamic>.from(e as Map))
    ).toList() ?? [];

    final eventLog = (data['event_log'] as List?)?.cast<String>() ?? const [];

    state = state.copyWith(
      encounters: encList,
      activeEncounterId: data['active_encounter_id'] as String? ?? (encList.isNotEmpty ? encList.first.id : null),
      eventLog: eventLog,
    );
  }

  // --- Internal ---

  void _updateEncounter(Encounter updated) {
    final encounters = state.encounters.map((e) => e.id == updated.id ? updated : e).toList();
    state = state.copyWith(encounters: encounters);
  }

  void _sortByInitiative() {
    final enc = state.activeEncounter;
    if (enc == null) return;

    final sorted = List<Combatant>.from(enc.combatants)
      ..sort((a, b) => b.init.compareTo(a.init)); // desc

    _updateEncounter(enc.copyWith(combatants: sorted));
  }

  void addLog(String message) => _log(message);

  void _log(String message) {
    state = state.copyWith(eventLog: [...state.eventLog, message]);
  }

  // --- Battle Map ---

  void saveMapData({
    required String encounterId,
    String? mapPath,
    Map<String, dynamic>? tokenPositions,
    Map<String, double>? tokenSizeMultipliers,
    int? tokenSize,
  }) {
    final enc = state.encounters.firstWhere((e) => e.id == encounterId, orElse: () => throw StateError('Encounter not found'));
    _updateEncounter(enc.copyWith(
      mapPath: mapPath ?? enc.mapPath,
      tokenPositions: tokenPositions ?? enc.tokenPositions,
      tokenSizeMultipliers: tokenSizeMultipliers ?? enc.tokenSizeMultipliers,
      tokenSize: tokenSize ?? enc.tokenSize,
    ));
    _saveAndNotify();
  }

  void saveFogAndAnnotation({
    required String encounterId,
    String? fogData,
    String? annotationData,
  }) {
    final enc = state.encounters.firstWhere((e) => e.id == encounterId, orElse: () => throw StateError('Encounter not found'));
    _updateEncounter(enc.copyWith(
      fogData: fogData,
      annotationData: annotationData,
    ));
    _saveAndNotify();
  }

  void updateGridSettings({
    required String encounterId,
    required int gridSize,
    required bool gridVisible,
    required bool gridSnap,
    required int feetPerCell,
  }) {
    final enc = state.encounters.firstWhere((e) => e.id == encounterId, orElse: () => throw StateError('Encounter not found'));
    _updateEncounter(enc.copyWith(
      gridSize: gridSize,
      gridVisible: gridVisible,
      gridSnap: gridSnap,
      feetPerCell: feetPerCell,
    ));
    _saveAndNotify();
  }

  void renameEncounter(String encounterId, String name) {
    final enc = state.encounters.firstWhere((e) => e.id == encounterId, orElse: () => throw StateError('Encounter not found'));
    _updateEncounter(enc.copyWith(name: name));
    _saveAndNotify();
  }
}

int _parseInt(dynamic map, String key, int fallback) {
  if (map is! Map) return fallback;
  final v = map[key];
  if (v is int) return v;
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

/// Entity'nin flat field map'inden int al — v2 monster/animal schema'sı için.
int _parseFlatInt(Map<String, dynamic> fields, String key, int fallback) {
  final v = fields[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

/// Flat schema init için spec hesapla. v2 monster: `initiative_modifier`
/// (int). Eksikse `initiative_score - 10` ya da boş.
String? _flatInitSpec(Map<String, dynamic> fields) {
  final mod = fields['initiative_modifier'];
  if (mod is num) {
    final n = mod.toInt();
    return n >= 0 ? '+$n' : '$n';
  }
  if (mod is String && mod.isNotEmpty) return mod;
  return null;
}

final combatProvider = StateNotifierProvider<CombatNotifier, CombatState>((ref) {
  ref.watch(activeCampaignProvider); // rebuild when campaign changes
  return CombatNotifier(
    () => ref.read(entityProvider),
    () => ref.read(worldSchemaProvider),
    () => ref.read(characterListProvider).valueOrNull ?? const <Character>[],
    () => ref.read(activeCampaignProvider.notifier).data,
    ref.read(eventBusProvider),
    (patch) async {
      // Debounced via PendingWriteBuffer (combatTick = 500ms). Closure
      // captures the latest patch; aynı key'e ardışık tick'ler timer
      // reset eder → tek read-merge-write.
      final worldId = ref
              .read(activeCampaignProvider.notifier)
              .data?['world_id'] as String? ??
          'local';
      ref.read(pendingWriteBufferProvider).schedule(
            key: 'settings:$worldId:combat_state',
            kind: WriteKind.combatTick,
            action: () => ref
                .read(activeCampaignProvider.notifier)
                .saveSettingsPatch(patch),
          );
    },
    (character) => ref.read(characterListProvider.notifier).update(character),
  );
});
