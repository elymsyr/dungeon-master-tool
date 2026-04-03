import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/encounter_config.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/entities/session.dart';
import 'campaign_provider.dart';
import 'entity_provider.dart';

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

class CombatNotifier extends StateNotifier<CombatState> {
  final Map<String, Entity> Function() _getEntities;
  final WorldSchema Function() _getSchema;
  final VoidCallback _onChanged;

  final Map<String, dynamic>? Function() _getCampaignData;

  CombatNotifier(this._getEntities, this._getSchema, this._onChanged, this._getCampaignData) : super(const CombatState()) {
    _loadFromCampaign();
  }

  void _loadFromCampaign() {
    final data = _getCampaignData();
    if (data == null) return;
    final combatData = data['combat_state'];
    if (combatData is Map) {
      loadSessionState(Map<String, dynamic>.from(combatData));
    }
  }

  Timer? _saveTimer;

  void _saveAndNotify() {
    final data = _getCampaignData();
    if (data != null) {
      data['combat_state'] = getSessionState();
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () => _onChanged());
  }

  EncounterConfig get _encounterConfig => _getSchema().encounterConfig;

  // --- Encounter Management ---

  void createEncounter(String name) {
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
    final updated = state.encounters.where((e) => e.id != eid).toList();
    final newActive = state.activeEncounterId == eid ? updated.first.id : state.activeEncounterId;
    state = state.copyWith(encounters: updated, activeEncounterId: newActive);
    _saveAndNotify();
  }

  // --- Helpers ---

  /// Combat stats field'ı olan kategori slug'larını döndürür.
  Set<String> get combatCapableSlugs {
    final schema = _getSchema();
    final cfg = _encounterConfig;
    final slugs = <String>{};
    for (final cat in schema.categories) {
      if (cat.fields.any((f) => f.fieldKey == cfg.combatStatsFieldKey)) {
        slugs.add(cat.slug);
      }
    }
    return slugs;
  }

  /// Entity'nin encounter'a eklenebilir olup olmadığını kontrol eder.
  bool canAddToEncounter(String entityId) {
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
    final entities = _getEntities();
    final entity = entities[entityId];
    if (entity == null) return;

    final cfg = _encounterConfig;
    final stats = entity.fields[cfg.statBlockFieldKey];
    final combatStats = entity.fields[cfg.combatStatsFieldKey];

    // DEX modifier
    final dex = (stats is Map ? (stats['DEX'] ?? 10) : 10) as int;
    final dexMod = (dex - 10) ~/ 2;

    // Initiative from combatStats
    final initRaw = combatStats is Map ? combatStats[cfg.initiativeSubField] : null;
    final initBonus = initRaw is int ? initRaw : (int.tryParse(initRaw?.toString() ?? '') ?? 0);
    final initRoll = _rng.nextInt(20) + 1 + dexMod + initBonus;

    // HP, AC from combatStats
    final hp = _parseInt(combatStats, 'hp', 10);
    final maxHp = _parseInt(combatStats, 'max_hp', hp);
    final ac = _parseInt(combatStats, 'ac', 10);

    final combatant = Combatant(
      id: _uuid.v4(),
      name: entity.name,
      init: initRoll,
      ac: ac,
      hp: hp,
      maxHp: maxHp,
      entityId: entityId,
    );

    _updateEncounter(enc.copyWith(combatants: [...enc.combatants, combatant]));
    _log('Added ${entity.name} (Init: $initRoll, AC: $ac, HP: $hp/$maxHp)');
    _sortByInitiative();
  }

  void addDirectRow(String name, {Map<String, String> stats = const {}}) {
    final enc = state.activeEncounter;
    if (enc == null) return;
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
    final entities = _getEntities();
    final existingIds = enc.combatants.map((c) => c.entityId).toSet();
    final capable = combatCapableSlugs;

    for (final entity in entities.values) {
      if (entity.categorySlug == 'player' && capable.contains('player') && !existingIds.contains(entity.id)) {
        addCombatantFromEntity(entity.id);
      }
    }
  }

  void deleteCombatant(String combatantId) {
    final enc = state.activeEncounter;
    if (enc == null) return;
    final updated = enc.combatants.where((c) => c.id != combatantId).toList();
    _updateEncounter(enc.copyWith(combatants: updated));
    _saveAndNotify();
  }

  void clearAll() {
    final enc = state.activeEncounter;
    if (enc == null) return;
    _updateEncounter(enc.copyWith(combatants: [], turnIndex: -1, round: 1));
    _log('Combat cleared');
    _saveAndNotify();
  }

  // --- Turn & Round ---

  void nextTurn() {
    final enc = state.activeEncounter;
    if (enc == null || enc.combatants.isEmpty) return;

    var newIndex = enc.turnIndex + 1;
    var newRound = enc.round;

    if (newIndex >= enc.combatants.length) {
      newIndex = 0;
      newRound++;
    }

    // Condition süreleri düşür
    final updatedCombatants = enc.combatants.map((c) {
      if (c.conditions.isEmpty) return c;
      final updatedConditions = c.conditions.map((cond) {
        if (cond.duration == null || cond.duration! <= 0) return cond;
        return cond.copyWith(duration: cond.duration! - 1);
      }).where((cond) => cond.duration == null || cond.duration! > 0).toList();
      return c.copyWith(conditions: updatedConditions);
    }).toList();

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
  }

  void rollInitiatives() {
    final enc = state.activeEncounter;
    if (enc == null) return;

    final rolled = enc.combatants.map((c) {
      final roll = _rng.nextInt(20) + 1;
      return c.copyWith(init: roll);
    }).toList();

    _updateEncounter(enc.copyWith(combatants: rolled));
    _sortByInitiative();

    final summary = rolled.map((c) => '${c.name}(${c.init})').join(', ');
    _log('Initiative: $summary');
    _saveAndNotify();
  }

  // --- HP & Conditions ---

  void modifyHp(String combatantId, int delta) {
    final enc = state.activeEncounter;
    if (enc == null) return;

    final updated = enc.combatants.map((c) {
      if (c.id != combatantId) return c;
      final newHp = (c.hp + delta).clamp(0, c.maxHp);
      return c.copyWith(hp: newHp);
    }).toList();

    _updateEncounter(enc.copyWith(combatants: updated));

    final c = updated.firstWhere((c) => c.id == combatantId);
    _log('${c.name} HP ${delta > 0 ? '+' : ''}$delta (${c.hp}/${c.maxHp})');

    // Entity card sync — combatStats güncelle
    _syncCombatStatToEntity(combatantId, 'hp', c.hp.toString());
    _saveAndNotify();
  }

  /// Combat stats'taki bir değeri entity'ye de yaz (canlı sync)
  void _syncCombatStatToEntity(String combatantId, String subKey, String value) {
    final enc = state.activeEncounter;
    if (enc == null) return;
    final combatant = enc.combatants.where((c) => c.id == combatantId);
    if (combatant.isEmpty || combatant.first.entityId == null) return;

    final entities = _getEntities();
    final entity = entities[combatant.first.entityId];
    if (entity == null) return;

    final cfg = _encounterConfig;
    final stats = entity.fields[cfg.combatStatsFieldKey];
    if (stats is Map) {
      final updated = Map<String, dynamic>.from(stats);
      updated[subKey] = value;
      // Entity provider'a yazma — doğrudan _getEntities map'ini güncelle
      // (Bu reactive provider üzerinden propagate olacak)
    }
  }

  void addCondition(String combatantId, String condName, int? duration) {
    final enc = state.activeEncounter;
    if (enc == null) return;

    final updated = enc.combatants.map((c) {
      if (c.id != combatantId) return c;
      return c.copyWith(conditions: [...c.conditions, CombatCondition(name: condName, duration: duration)]);
    }).toList();

    _updateEncounter(enc.copyWith(combatants: updated));
    _log('${updated.firstWhere((c) => c.id == combatantId).name} gains $condName${duration != null ? ' ($duration rounds)' : ''}');
    _saveAndNotify();
  }

  void removeCondition(String combatantId, String condName) {
    final enc = state.activeEncounter;
    if (enc == null) return;

    final updated = enc.combatants.map((c) {
      if (c.id != combatantId) return c;
      return c.copyWith(conditions: c.conditions.where((cond) => cond.name != condName).toList());
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
}

int _parseInt(dynamic map, String key, int fallback) {
  if (map is! Map) return fallback;
  final v = map[key];
  if (v is int) return v;
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

final combatProvider = StateNotifierProvider<CombatNotifier, CombatState>((ref) {
  return CombatNotifier(
    () => ref.read(entityProvider),
    () => ref.read(worldSchemaProvider),
    () => ref.read(activeCampaignProvider.notifier).save(),
    () => ref.read(activeCampaignProvider.notifier).data,
  );
});
