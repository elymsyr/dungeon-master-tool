import '../../application/character_creation/caster_progression.dart'
    show CasterKind, defaultSpellSlotsByLevel, parseCasterKind, slotsByLevelOverride;
import '../entities/entity.dart';
import '../entities/schema/builtin/lookups.dart' show kResourcePoolLabels;
import 'entity_ref.dart';

/// The SRD copy's Level tables and Grants, read from the SRD shapes they
/// replaced (docs/free-template/DESIGN.md §16.3). The SRD pack never
/// changes (ROADMAP K1): a free field whose `styleConfig` names a kind
/// below under `srd_read` shows what is built here until the card is
/// edited, then it stores its own rows. The output is the free value shape
/// (`free_grants.dart`); nothing here computes a sheet value (D2).

/// A class / subclass `features` table → Level table rows; the granted
/// feats' level-bound pools and the caster kind's slots join them.
const srdClassFeatures = 'class_features';

/// `granted_spells_at_level` → Level table rows (V24), plus the card's own
/// pools that follow the main level (`pb`).
const srdSpellsAtLevel = 'spells_at_level';

/// `resource_pool_grants` → the card's own Grants (fixed counts, stat
/// formulas).
const srdResourcePools = 'resource_pools';

const srdLevelReads = {srdClassFeatures, srdSpellsAtLevel, srdResourcePools};

/// Whether [v] is still SRD data (or nothing): free rows and items carry an
/// `_id`, SRD rows never do.
bool isSrdLevelShape(Object? v) =>
    v is! List || v.every((r) => r is! Map || !r.containsKey('_id'));

/// [kind]'s free value for [card], whose field holds the SRD [stored].
Object? srdLevelValue(
  String kind,
  Object? stored,
  Map<String, dynamic> card,
  Map<String, Entity> byId,
) => switch (kind) {
  srdClassFeatures => _classRows(stored, card, byId),
  srdSpellsAtLevel => _spellRows(stored, card, byId),
  srdResourcePools => _ownPoolItems(stored, byId),
  _ => stored,
};

/// Where each SRD feature-row list goes on the copy's player card (§16.3).
const srdFeatureTargets = {
  'granted_feat_refs': 'feats',
  'granted_trait_refs': 'trait_refs',
  'granted_action_refs': 'action_refs',
  'granted_bonus_action_refs': 'bonus_action_refs',
  'granted_reaction_refs': 'reaction_refs',
  'always_prepared_spell_refs': 'spells_known',
  'granted_senses': 'senses',
  'granted_languages': 'languages',
  'granted_damage_resistances': 'resistance_refs',
  'granted_damage_immunities': 'damage_immunity_refs',
  'granted_condition_immunities': 'condition_immunity_refs',
};

const _player = 'player-character';

int? _int(Object? v) => switch (v) {
  int i => i,
  num n => n.toInt(),
  String s => int.tryParse(s.trim()),
  _ => null,
};

List<Map<String, dynamic>> _maps(Object? v) => [
  if (v is List)
    for (final r in v)
      if (r is Map) Map<String, dynamic>.from(r),
];

Map<String, dynamic> _card(String id, Object? ref, String list) => {
  '_id': id,
  'kind': 'card',
  'card': ref,
  'targets': {_player: list},
};

/// A resource item (D39): `short_rest` pools refill on both rests.
Map<String, dynamic> _resource(String name, int? max, {bool short = false}) =>
    {
      'kind': 'resource',
      'name': name,
      'max': ?max,
      'short': short ? 'fill' : 'keep',
      'long': 'fill',
    };

// ------------------------------------------------------------------ pools

/// Pool counts SRD calls level-bound: the class's level, or the main level
/// for `pb` without a class.
const _classFormulas = {'monk_level', 'sorcerer_level', 'paladin_level_x5'};
const _statFormulas = {'cha_mod_min_1': 'CHA', 'wis_mod_min_1': 'WIS'};

/// SRD writes "unlimited" (Rage at 20) as 99; boxes can't show it.
const _unlimited = 99;

enum _Scope { own, giver, table }

/// Where a pool lands (§16.3): a level-bound one in the giving card's rows
/// (it follows the class level) or, without a class, in the card's own
/// table (main level); a fixed or stat count in the card's own Grants.
_Scope _scope(Map<String, dynamic> p) {
  final byLevel = p['count_by_level'];
  final formula = p['count_formula'];
  final levelled =
      (byLevel is Map && byLevel.isNotEmpty) ||
      _classFormulas.contains(formula) ||
      formula == 'pb';
  if (!levelled) return _Scope.own;
  return p['class_ref'] != null || _classFormulas.contains(formula)
      ? _Scope.giver
      : _Scope.table;
}

/// A level-bound pool's count at [level]; `count_by_level` wins over the
/// formula (the built-in order).
int? _poolMax(Map<String, dynamic> p, int level) {
  final byLevel = p['count_by_level'];
  if (byLevel is Map && byLevel.isNotEmpty) {
    int? out;
    var at = 0;
    for (final e in byLevel.entries) {
      final k = _int(e.key);
      if (k != null && k <= level && k >= at) {
        at = k;
        out = _int(e.value);
      }
    }
    return out;
  }
  return switch (p['count_formula']) {
    'monk_level' || 'sorcerer_level' => level,
    'paladin_level_x5' => level * 5,
    'pb' => 2 + (level - 1) ~/ 4,
    _ => null,
  };
}

/// A pool's name: the Resource Pool card's display name.
String _poolName(Object? raw, Map<String, Entity> byId) {
  final e = byId[resolveEntityRef(raw, byId)];
  final label = e?.fields['display_name'];
  if (label is String && label.trim().isNotEmpty) return label.trim();
  final key = e?.name ?? (raw is Map ? raw['name'] : null);
  return key is String ? (kResourcePoolLabels[key] ?? key) : '';
}

/// [p]'s count from [from] up as resource items, one wherever it changes;
/// the same name from the same card replaces the last (D39).
void _levelled(
  Map<String, dynamic> p,
  int from,
  Map<String, Entity> byId,
  Map<int, List<Map<String, dynamic>>> into,
) {
  final name = _poolName(p['pool_ref'], byId);
  if (name.isEmpty) return;
  int? last;
  for (var l = from; l <= 20; l++) {
    final n = _poolMax(p, l);
    if (n == null || n == last || n >= _unlimited) continue;
    last = n;
    (into[l] ??= []).add(
      _resource(name, n, short: p['recharge'] == 'short_rest'),
    );
  }
}

/// A card's own pools as Grants: a fixed count, or a stat formula as an
/// empty max (the player enters it, D30) and a text saying how.
List<Map<String, dynamic>> _ownPoolItems(
  Object? pools,
  Map<String, Entity> byId,
) {
  final out = <Map<String, dynamic>>[];
  void add(Map<String, dynamic> item) =>
      out.add({'_id': 'srd${out.length + 1}', ...item});
  for (final p in _maps(pools)) {
    if (_scope(p) != _Scope.own) continue;
    final name = _poolName(p['pool_ref'], byId);
    if (name.isEmpty) continue;
    final formula = p['count_formula'];
    final hasFormula = formula is String && formula.isNotEmpty;
    add(
      _resource(
        name,
        hasFormula ? null : _int(p['count']),
        short: p['recharge'] == 'short_rest',
      ),
    );
    if (_statFormulas[formula] case final stat?) {
      add({
        'kind': 'style',
        'style': 'markdown',
        'label': name,
        'value': 'Max = $stat modifier (min. 1)',
      });
    }
  }
  return out;
}

// ------------------------------------------------------------------- rows

/// Rows for what [extra] holds, after a level's own rows.
void _addExtra(
  List<Map<String, dynamic>> rows,
  Map<int, List<Map<String, dynamic>>> extra,
) {
  for (final l in extra.keys.toList()..sort()) {
    rows.add({
      '_id': 'srd-l$l',
      'level': l,
      'items': [
        for (final (j, item) in extra[l]!.indexed)
          {'_id': 'srd-l$l-${j + 1}', ...item},
      ],
    });
  }
}

/// The caster kind's slots (§16.3): "Level N Slots" wherever a count
/// changes, a Warlock's one "Pact Slots" that a short rest refills too.
void _slots(
  Map<String, dynamic> card,
  Map<int, List<Map<String, dynamic>>> into,
) {
  final kind = parseCasterKind(card['caster_kind']);
  final pact = kind == CasterKind.pact;
  var last = <String, int>{};
  for (var l = 1; l <= 20; l++) {
    final slots =
        slotsByLevelOverride(card['spell_slots_by_level'], l) ??
        defaultSpellSlotsByLevel(kind, l);
    final named = pact
        ? {if (slots.isNotEmpty) 'Pact Slots': slots.values.first}
        : {for (final e in slots.entries) 'Level ${e.key} Slots': e.value};
    for (final e in named.entries) {
      if (last[e.key] != e.value) {
        (into[l] ??= []).add(_resource(e.key, e.value, short: pact));
      }
    }
    last = named;
  }
}

/// A class / subclass card's rows: one per SRD feature (name and text, its
/// granted lists as card items), then each level's slots and the granted
/// feats' level-bound pools.
List<Map<String, dynamic>> _classRows(
  Object? features,
  Map<String, dynamic> card,
  Map<String, Entity> byId,
) {
  final rows = <Map<String, dynamic>>[];
  final extra = <int, List<Map<String, dynamic>>>{};
  for (final (i, r) in _maps(features).indexed) {
    final level = _int(r['level']) ?? 1;
    final id = 'srd$i';
    final items = <Map<String, dynamic>>[];
    for (final MapEntry(key: from, value: list) in srdFeatureTargets.entries) {
      final refs = r[from];
      if (refs is! List) continue;
      for (final ref in refs) {
        items.add(_card('$id-${items.length + 1}', ref, list));
      }
    }
    for (final ref in (r['granted_feat_refs'] as List?) ?? const []) {
      final feat = byId[resolveEntityRef(ref, byId)];
      for (final p in _maps(feat?.fields['resource_pool_grants'])) {
        if (_scope(p) == _Scope.giver) _levelled(p, level, byId, extra);
      }
    }
    final name = '${r['name'] ?? ''}'.trim();
    final text = '${r['description'] ?? ''}'.trim();
    rows.add({
      '_id': id,
      'level': level,
      'text': [if (name.isNotEmpty) '**$name.**', if (text.isNotEmpty) text]
          .join(' '),
      if (items.isNotEmpty) 'items': items,
    });
  }
  _slots(card, extra);
  _addExtra(rows, extra);
  return rows;
}

/// A species / feat / trait card's rows: each spell at its level (and its
/// daily uses as a resource), then its own main-level pools.
List<Map<String, dynamic>> _spellRows(
  Object? spells,
  Map<String, dynamic> card,
  Map<String, Entity> byId,
) {
  final rows = <Map<String, dynamic>>[];
  for (final (i, s) in _maps(spells).indexed) {
    final id = 'srd$i';
    final uses = _int(s['uses_per_long_rest']);
    final spell = byId[resolveEntityRef(s['spell_ref'], byId)];
    rows.add({
      '_id': id,
      'level': _int(s['at_level']) ?? 1,
      'items': [
        _card('$id-1', s['spell_ref'], 'spells_known'),
        if (uses != null && uses > 0 && spell != null)
          {'_id': '$id-2', ..._resource(spell.name, uses)},
      ],
    });
  }
  final extra = <int, List<Map<String, dynamic>>>{};
  for (final p in _maps(card['resource_pool_grants'])) {
    if (_scope(p) == _Scope.table) _levelled(p, 1, byId, extra);
  }
  _addExtra(rows, extra);
  return rows;
}
