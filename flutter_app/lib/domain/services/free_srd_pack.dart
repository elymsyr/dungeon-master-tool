import '../entities/entity.dart';
import '../entities/schema/entity_category_schema.dart';
import '../entities/schema/field_schema.dart';
import 'entity_ref.dart';
import 'free_field_styles.dart';
import 'free_srd_levels.dart' show srdCardItem, srdFeatureTargets;
import 'free_srd_texts.dart';
import 'free_template.dart' show srdFreeTemplate;

/// The free SRD package's data (docs/free-template/SRD-FREE-ALANLAR.md §8):
/// the core pack's cards in [srdFreeTemplate]'s shape, built once when the
/// package is seeded, so the package needs no read-time conversion. The
/// core pack itself never changes (ROADMAP K1).

/// Bumped whenever [freeSrdFields] writes something new: the free package
/// re-seeds on a change (`SrdCorePackageBootstrap._ensureFree`).
const freeSrdPackVersion = 6;

/// The categories finished so far (SRD-FREE-ALANLAR §11): their cards hold
/// only the copy's fields and no description of their own (S1). One more
/// with each phase; A10 closes them all.
const freeSrdClosed = {
  'spell',
  'feat',
  'trait',
  'species',
  'subspecies',
  'class',
  'subclass',
  'background',
  'monster',
  'animal',
  'creature-action',
};

final Map<String, EntityCategorySchema> _categories = {
  for (final c in srdFreeTemplate.categories) c.slug: c,
};

/// Whether the free package carries [slug]'s cards: the copy drops some
/// categories (§5.14).
bool inFreeSrd(String slug) => _categories.containsKey(slug);

/// [card]'s fields as the free template shows them: what
/// `freeFieldValue` reads out of the SRD shapes (Level tables, Grants,
/// the Combat stats block) and the SRD lists a markdown field shows as
/// text, written into the data (A1); a closed category's lines in the
/// SRD's own words, and nothing the copy does not declare. An SRD value
/// that reads as nothing (a level-bound pool, granted from the class rows)
/// is emptied, not left in its SRD shape. [byId] holds every pack card.
/// Refs and `_lookup` placeholders stay; the world resolves them when it
/// synthesises the card.
Map<String, dynamic> freeSrdFields(Entity card, Map<String, Entity> byId) {
  final cat = _categories[card.categorySlug];
  if (cat == null) return card.fields;
  final closed = freeSrdClosed.contains(card.categorySlug);
  final src = {
    ...card.fields,
    if (card.categorySlug == 'spell') ..._spellLines(card.fields, byId),
    if (card.categorySlug == 'species') ..._speciesLines(card, byId),
    if (card.categorySlug == 'class') ..._classLines(card, byId),
    if (card.categorySlug == 'background') ..._backgroundLines(card, byId),
    if (card.categorySlug == 'monster' || card.categorySlug == 'animal')
      ..._statBlockLines(card.fields),
    if (card.categorySlug == 'creature-action')
      'description': _actionText(card.fields, byId),
  };
  final out = closed
      ? <String, dynamic>{}
      : Map<String, dynamic>.from(card.fields);
  for (final f in cat.fields) {
    var v = freeFieldValue(f, src, byId: byId);
    if (closed && f.fieldType == FieldType.grantHolder) {
      final items = [
        ...?(v as List?),
        ..._grantItems(
          src,
          // A lineage's cantrips are its Level 1 row; its sense is the
          // species' own, farther (§5.5).
          skip: card.categorySlug == 'subspecies'
              ? const {'granted_cantrip_refs', 'granted_senses'}
              : const {},
        ),
      ];
      if (card.categorySlug == 'feat') {
        for (final i in _featRowItems(card, byId)) {
          final to = resolveEntityRef(i['card'], byId);
          if (!items.any((x) => resolveEntityRef(x['card'], byId) == to)) {
            items.add(i);
          }
        }
      }
      v = items;
    }
    if (card.categorySlug == 'subspecies' &&
        f.fieldType == FieldType.progressionTable) {
      v = [?_lineageRow(card, byId), ...?(v as List?)];
    }
    if (closed && f.fieldKey == 'features' && v is List) {
      v = _featureRows(v, card.fields, byId);
    }
    if (f.fieldType == FieldType.markdown && v is List) {
      v = structuredListAsMarkdown(v, (r) => entityRefName(r, byId));
    }
    if (!_blank(v) || !_blank(out[f.fieldKey])) out[f.fieldKey] = v;
  }
  return out;
}

/// Where the grant block's card lists go on the copy's player card (§4,
/// R5); the rest of the block stays in the card's text (R6).
const _grantTargets = {
  ...srdFeatureTargets,
  'granted_damage_vulnerabilities': 'vulnerability_refs',
  'granted_tool_proficiencies': 'tool_proficiencies',
  'granted_weapon_proficiencies': 'weapon_proficiency_categories',
  'granted_armor_proficiencies': 'armor_trainings',
  'granted_spell_refs': 'spells_known',
  'granted_cantrip_refs': 'spells_known',
  'trait_refs': 'trait_refs',
};

/// A grant block's cards as Grants items (§4, R5). A card that grants only
/// while a state holds (Rage's resistances) grants nothing for good (R6).
List<Map<String, dynamic>> _grantItems(
  Map<String, dynamic> f, {
  Set<String> skip = const {},
}) {
  if (!_blank(f['active_while_state_ref'])) return const [];
  final out = <Map<String, dynamic>>[];
  for (final MapEntry(key: from, value: list) in _grantTargets.entries) {
    if (skip.contains(from)) continue;
    for (final r in f[from] as List? ?? const []) {
      // A sense row's range is in the text ("Truesight 60 ft").
      final ref = r is Map && r.containsKey('sense_ref') ? r['sense_ref'] : r;
      out.add(srdCardItem('srd-g${out.length + 1}', ref, list));
    }
  }
  return out;
}

/// S3: a class / subclass row that grants a feat grants only the feat (the
/// row's other cards are the feat's Grants, `_featRowItems`); a class's
/// languages are cards in the row of their name (§5.2).
List<Map<String, dynamic>> _featureRows(
  List rows,
  Map<String, dynamic> f,
  Map<String, Entity> byId,
) {
  Object? to(Object? item) => switch (item) {
    {'targets': final Map t} => t['player-character'],
    _ => null,
  };
  final out = [
    for (final r in rows.cast<Map>())
      if ((r['items'] as List?)?.any((i) => to(i) == 'feats') ?? false)
        {
          ...Map<String, dynamic>.from(r),
          'items': [for (final i in r['items'] as List) if (to(i) == 'feats') i],
        }
      else
        Map<String, dynamic>.from(r),
  ];
  for (final ref in f['granted_languages'] as List? ?? const []) {
    final name = entityRefName(ref, byId);
    final row =
        out.where((r) => '${r['text']}'.startsWith('**$name.**')).firstOrNull ??
        out.first;
    final items = [...?(row['items'] as List?)];
    row['items'] = [
      ...items,
      srdCardItem('${row['_id']}-${items.length + 1}', ref, 'languages'),
    ];
  }
  return out;
}

/// S3: the cards a class / subclass row grants beside [feat]: the feat's
/// own Grants now, each with the row's feat of its name (Monk's Focus
/// gives four) or the first. A trait of a feat's name is that feat again.
List<Map<String, dynamic>> _featRowItems(
  Entity feat,
  Map<String, Entity> byId,
) {
  String key(String n) =>
      n.replaceFirst(RegExp(r' \(.*\)$'), '').toLowerCase();
  final out = <Map<String, dynamic>>[];
  for (final c in byId.values) {
    if (c.categorySlug != 'class' && c.categorySlug != 'subclass') continue;
    for (final r in c.fields['features'] as List? ?? const []) {
      if (r is! Map) continue;
      final feats = [
        for (final ref in r['granted_feat_refs'] as List? ?? const [])
          ?byId[resolveEntityRef(ref, byId)],
      ];
      if (!feats.any((x) => x.id == feat.id)) continue;
      for (final MapEntry(key: from, value: list)
          in srdFeatureTargets.entries) {
        if (from == 'granted_feat_refs') continue;
        for (final ref in r[from] as List? ?? const []) {
          final n = key(entityRefName(ref, byId));
          final named = feats.where((x) => key(x.name) == n).firstOrNull;
          if (named != null && from == 'granted_trait_refs') continue;
          if ((named ?? feats.first).id != feat.id) continue;
          out.add(srdCardItem('srd-r${out.length + 1}', ref, list));
        }
      }
    }
  }
  return out;
}

/// A class's Core Traits lines and its "Becoming a …" box as the SRD
/// writes them (§5.2): "Choose 2: Animal Handling, …, or Survival",
/// "Choose A or B: (A) Greataxe, …, and 15 GP; or (B) 75 GP".
Map<String, String> _classLines(Entity card, Map<String, Entity> byId) {
  final f = card.fields;
  List<String> names(Object? refs) => [
    for (final r in refs is List ? refs : [?refs]) entityRefName(r, byId),
  ];
  final c = card.name;
  final own = srdClassLines[c] ?? const {};
  final features =
      'Gain the $c’s level 1 features, which are listed in the $c Features '
      'table.';
  final multiclass = srdClassMulticlass[c];
  return {
    'primary_ability':
        own['primary_ability'] ??
        _series(
          names([f['primary_ability_ref'], ?f['secondary_ability_ref']]),
          'and',
        ),
    'skill_proficiencies':
        own['skill_proficiencies'] ??
        'Choose ${f['skill_proficiency_choice_count']}: '
            '${_series(names(f['skill_proficiency_options']), 'or')}',
    'weapon_proficiencies':
        '${_series(names(f['weapon_proficiency_categories']), 'and')} weapons',
    'tool_proficiencies':
        own['tool_proficiencies'] ??
        _series(names(f['granted_tool_refs']), 'and'),
    'equipment_choice_groups': _equipment(f['equipment_choice_groups'], 'and'),
    if (multiclass != null)
      'becoming': [
        '**As a Level 1 Character**',
        '- Gain all the traits in the Core $c Traits table.\n- $features',
        '**As a Multiclass Character**',
        '- $multiclass\n- $features'
            '${{null, 'None'}.contains(f['caster_kind']) ? '' : ' See the '
                      'multiclassing rules in “Character Creation” to '
                      'determine your available spell slots.'}',
      ].join('\n\n'),
  };
}

/// A background's Tool Proficiency and Equipment lines as the SRD writes
/// them, and its feat and tool as the grant block's cards (§5.6).
Map<String, Object?> _backgroundLines(Entity card, Map<String, Entity> byId) {
  final f = card.fields;
  return {
    'tool_proficiency':
        srdBackgroundTools[card.name] ??
        _series([
          for (final r in f['granted_tool_refs'] as List? ?? const [])
            entityRefName(r, byId),
        ], 'and'),
    'equipment_choice_groups': _equipment(f['equipment_choice_groups'], null),
    'granted_feat_refs': [?f['origin_feat_ref']],
    'granted_tool_proficiencies': f['granted_tool_refs'],
  };
}

/// Starting equipment as the SRD writes it: "Choose A or B: (A) …; or (B)
/// 50 GP"; a class's options end with [last] ("…, and 15 GP").
String _equipment(Object? groups, String? last) {
  final options = [
    for (final g in groups as List? ?? const [])
      for (final o in (g as Map)['options'] as List? ?? const []) o as Map,
  ];
  if (options.isEmpty) return '';
  final parts = [
    for (final o in options)
      '(${o['option_id']}) '
          '${last == null ? o['label'] : _series('${o['label']}'.split(', '), last)}',
  ];
  return 'Choose ${_series([for (final o in options) '${o['option_id']}'], 'or')}: '
      '${parts.take(parts.length - 1).join('; ')}; or ${parts.last}';
}

/// "A", "A and B", "A, B, and C".
String _series(List<String> items, String conj) => switch (items.length) {
  0 => '',
  1 => items.single,
  2 => '${items.first} $conj ${items.last}',
  _ => '${items.take(items.length - 1).join(', ')}, $conj ${items.last}',
};

/// A species' Size line and its Traits as the SRD writes them (§5.4):
/// "As a Dwarf, you have these special traits." and a paragraph for each
/// sense, trait and action it grants, by name as in the SRD.
Map<String, String> _speciesLines(Entity card, Map<String, Entity> byId) {
  final f = card.fields;
  String text(Object? ref) =>
      '${byId[resolveEntityRef(ref, byId)]?.fields['description'] ?? ''}'
          .trim();
  final paragraphs = <(String, String)>[
    for (final r in f['granted_senses'] as List? ?? const [])
      if (r is Map)
        (
          entityRefName(r['sense_ref'], byId),
          'You have ${entityRefName(r['sense_ref'], byId)} with a range of '
              '${_num(r['range_ft'] as num? ?? 0)} feet.',
        ),
    for (final key in const [
      'trait_refs',
      'granted_action_refs',
      'granted_bonus_action_refs',
      'granted_reaction_refs',
    ])
      for (final r in f[key] as List? ?? const [])
        // "Keen Senses (Elf)" is the SRD's Keen Senses.
        (entityRefName(r, byId).replaceFirst(RegExp(r' \(.*\)$'), ''), text(r)),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  final name = card.name;
  final article = RegExp('^[AEIOU]').hasMatch(name) ? 'an' : 'a';
  return {
    'size': srdSpeciesSizes[name] ?? entityRefName(f['size_ref'], byId),
    'traits': [
      srdSpeciesTraitsIntros[name] ??
          'As $article $name, you have these special traits.',
      for (final (n, t) in paragraphs) '**$n.** $t',
      if (f['mechanical_notes'] case final String n when n.trim().isNotEmpty)
        n.trim(),
    ].join('\n\n'),
  };
}

/// A lineage's Level 1 row (§5.5): the SRD table's cell, or for a lineage
/// in no table what its data grants, in the SRD's words; its cantrips as
/// cards for the Spells.
Map<String, dynamic>? _lineageRow(Entity card, Map<String, Entity> byId) {
  final f = card.fields;
  String names(Object? refs) {
    final n = [for (final r in refs as List? ?? const []) entityRefName(r, byId)];
    return n.length < 2
        ? n.join()
        : '${n.take(n.length - 1).join(', ')} and ${n.last}';
  }

  final cantrips = f['granted_cantrip_refs'] as List? ?? const [];
  final bonuses = <num, List<String>>{};
  for (final MapEntry(:key, :value)
      in (f['ability_bonuses'] as Map? ?? const {}).entries) {
    if (value is num && value != 0) {
      (bonuses[value] ??= []).add(_abilities[key] ?? '$key');
    }
  }
  final perLevel = f['hp_bonus_per_level'], flat = f['hp_bonus_flat'];
  final text =
      srdLineageLevel1[card.name] ??
      [
        if (names(f['granted_damage_resistances']) case final d
            when d.isNotEmpty)
          'You have Resistance to $d damage.',
        if (names(f['granted_skill_proficiencies']) case final s
            when s.isNotEmpty)
          'You gain proficiency in the $s skill.',
        if (perLevel is num && perLevel > 0)
          'Your Hit Point maximum increases by ${_num(perLevel)}, and it '
              'increases by ${_num(perLevel)} again whenever you gain a level.',
        if (flat is num && flat > 0)
          'Your Hit Point maximum increases by ${_num(flat)}.',
        for (final MapEntry(key: n, value: a) in bonuses.entries)
          a.length == 1
              ? 'Your ${a.single} score increases by ${_num(n)}.'
              : 'Your ${a.take(a.length - 1).join(', ')}, and ${a.last} '
                    'scores each increase by ${_num(n)}.',
        if (cantrips.isNotEmpty)
          'You know the ${names(cantrips)} '
              'cantrip${cantrips.length == 1 ? '' : 's'}.',
      ].join(' ');
  if (text.isEmpty && cantrips.isEmpty) return null;
  return {
    '_id': 'srd-lineage',
    'level': 1,
    if (text.isNotEmpty) 'text': text,
    if (cantrips.isNotEmpty)
      'items': [
        for (final (i, r) in cantrips.indexed)
          srdCardItem('srd-lineage-${i + 1}', r, 'spells_known'),
      ],
  };
}

const _abilities = {
  'STR': 'Strength',
  'DEX': 'Dexterity',
  'CON': 'Constitution',
  'INT': 'Intelligence',
  'WIS': 'Wisdom',
  'CHA': 'Charisma',
};

/// A monster's Speed line as the SRD writes it (§5.10): "40 ft., Climb 40
/// ft., Fly 80 ft."; its XP moves into the Combat stats block, which reads
/// AC, HP and Initiative from the flat fields.
Map<String, Object> _statBlockLines(Map<String, dynamic> f) => {
  'speed': [
    '${f['speed_walk_ft'] ?? 0} ft.',
    for (final (key, name) in const [
      ('speed_burrow_ft', 'Burrow'),
      ('speed_climb_ft', 'Climb'),
      ('speed_fly_ft', 'Fly'),
      ('speed_swim_ft', 'Swim'),
    ])
      if (f[key] case final num ft when ft > 0)
        '$name $ft ft.${key == 'speed_fly_ft' && f['can_hover'] == true ? ' (hover)' : ''}',
  ].join(', '),
  if (f['xp'] case final num xp) 'combat_stats': {'xp': xp},
};

/// An action's text with what the SRD writes in its heading first,
/// "(Recharge 5–6).", "(3/Day).", and the DC a save's text lacks (§5.11).
/// Commanding Presence's DC is its Spellcasting's.
String _actionText(Map<String, dynamic> f, Map<String, Entity> byId) {
  var text = f['description'] as String? ?? '';
  if (f['save_dc'] case final num dc
      when !text.contains('DC ') && !text.contains('Spellcasting')) {
    const head = 'Saving Throw:* ';
    text = text.contains(head)
        ? text.replaceFirst(head, '${head}DC $dc, ')
        : '*${entityRefName(f['save_ability_ref'], byId)} Saving Throw:* '
              'DC $dc. $text';
  }
  final limits = [
    if (!text.contains('Recharge'))
      switch ((f['recharge_kind'], f['recharge_min_roll'])) {
        ('Roll' || 'Recharge', 6) => 'Recharge 6',
        ('Roll' || 'Recharge', final num n) => 'Recharge $n–6',
        // The SRD's X/Day is "until a Long Rest".
        ('Long Rest', _) => '1/Day',
        ('Short Rest' || 'Short or Long Rest', _) =>
          'Recharge after a Short or Long Rest',
        _ => null,
      },
    if (f['uses_per_day'] case final num n
        when !text.contains('/Day') && !text.contains('Once per'))
      '$n/Day',
  ].nonNulls;
  return limits.isEmpty ? text : '(${limits.join(', ')}). $text';
}

/// [card]'s description in the free package. A closed category's rules
/// text is its own text field, so the description above it goes, but for
/// the line the SRD writes under a subclass's name (S1).
String freeSrdDescription(Entity card) =>
    !freeSrdClosed.contains(card.categorySlug)
    ? card.description
    : card.categorySlug == 'subclass'
    ? srdSubclassIntros[card.name] ?? ''
    : '';

/// A spell's header lines as the SRD writes them (§5.1): "1 minute or
/// Ritual", "150 feet", "V, S, M (a diamond worth 500+ GP, which the spell
/// consumes)", "Concentration, up to 1 minute".
Map<String, String> _spellLines(
  Map<String, dynamic> f,
  Map<String, Entity> byId,
) {
  String name(Object? r) => entityRefName(r, byId);

  final castUnit = name(f['casting_time_unit_ref']);
  var cast = castUnit == 'Minute' || castUnit == 'Hour'
      ? _count(f['casting_time_amount'] as num? ?? 1, castUnit)
      : castUnit;
  if (f['reaction_trigger'] case final String t when t.isNotEmpty) {
    cast += ', which you take ${_lower(t).replaceFirst(RegExp(r'\.$'), '')}';
  }
  if (f['is_ritual'] == true) cast += ' or Ritual';

  final range = switch ((f['range_type'], f['range_ft'])) {
    ('Ranged', final num ft) => '${_num(ft)} feet',
    // The builder stores a range it cannot type ("Special") as bare Ranged.
    ('Ranged', _) => 'Special',
    (final String t, _) => t,
    _ => '',
  };

  var material = _lower(f['material_description'] as String? ?? '');
  if (material.isNotEmpty) {
    // Find Familiar's 10 GP is in no text.
    final gp = f['material_cost_gp'];
    if (gp is num && !material.contains('GP')) {
      material += ', worth ${_num(gp)}+ GP';
    }
    if (f['material_consumed'] == true && !material.contains('consume')) {
      material += ', which the spell consumes';
    }
  }
  const abbrev = {'Verbal': 'V', 'Somatic': 'S', 'Material': 'M'};
  final components = [
    for (final c in f['components'] as List? ?? const [])
      switch (abbrev[name(c)] ?? name(c)) {
        'M' when material.isNotEmpty => 'M ($material)',
        final a => a,
      },
  ].join(', ');

  final durUnit = name(f['duration_unit_ref']);
  var duration = switch (f['duration_amount']) {
    final num n => _count(n, durUnit),
    _ => durUnit == 'Until Dispelled' ? 'Until dispelled' : durUnit,
  };
  if (f['requires_concentration'] == true) {
    duration = 'Concentration, up to $duration';
  }

  return {
    'casting_time': cast,
    'range': range,
    'components': components,
    'duration': duration,
  };
}

/// "1 minute", "10 minutes" from a unit name either way ("Minute",
/// "Minutes").
String _count(num n, String unit) =>
    '${_num(n)} ${unit.toLowerCase().replaceFirst(RegExp(r's$'), '')}'
    '${n == 1 ? '' : 's'}';

/// The SRD's numbers: "1,000".
String _num(num n) =>
    '$n'.replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');

String _lower(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

bool _blank(Object? v) =>
    v == null ||
    (v is String && v.isEmpty) ||
    (v is List && v.isEmpty) ||
    (v is Map && v.isEmpty);
