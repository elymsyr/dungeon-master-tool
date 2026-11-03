// Free SRD Türkçe öneri aracı (docs/free-template/SRD-FREE-ALANLAR.md §8) —
// dönüştürücünün (`free_srd_pack.dart`) parçalardan kurduğu satırların
// Türkçesini, aynı parçaların mevcut çevirisinden kurar ve
// `assets/srd_l10n/tr/` tablolarında boş ("") kalan anahtara yazar. Dolu
// çeviriye dokunmaz. Öneriler gözden geçirilir; ardından check_pairs.
//
//   dart run tool/srd_l10n/bin/extract.dart    # yeni anahtarlar "" ile
//   dart run tool/srd_l10n/bin/suggest.dart    # boşları önerilerle doldurur
//
// Büyünün dört başlık satırı (A2); Seviye tablosu satırları ve türün
// Traits yazısı (A4); sınıfın Core Traits satırları, Becoming a… kutusu
// ve geçmişin satırları (A5); canavarın Speed satırı ve eylemin başlığa
// yazılan Recharge / X/Day'i ile DC'si (A6). Kapanan her faz kendi
// kurucusunu ekler.
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package:dungeon_master_tool/domain/services/entity_ref.dart';
import 'package:dungeon_master_tool/domain/services/free_srd_pack.dart';

const _dir = 'assets/srd_l10n/tr';

Map<String, String> _table(String scope) =>
    (jsonDecode(File('$_dir/$scope.json').readAsStringSync()) as Map)
        .cast<String, String>();

String _trLowerFirst(String s) => s.isEmpty
    ? s
    : switch (s[0]) {
        'I' => 'ı',
        'İ' => 'i',
        final c => c.toLowerCase(),
      } +
        s.substring(1);

/// Sayıdan sonra Türkçe birim (çoğul eki yok) ve "-e kadar" hali.
const _units = {
  'minute': ('dakika', 'dakikaya'),
  'hour': ('saat', 'saate'),
  'day': ('gün', 'güne'),
  'round': ('raunt', 'raunda'),
};

/// Büyünün dört satırı: İngilizcesi dönüştürücüden, Türkçesi aynı kartın
/// parçalarından ([spell] = büyü tablosu, [schema] = `_schema`).
Map<String, String> _spellPairs(
  Entity card,
  Map<String, Entity> byId,
  Map<String, String> spell,
  Map<String, String> schema,
) {
  final f = card.fields;
  final en = freeSrdFields(card, byId);
  String name(Object? r) => entityRefName(r, byId);
  String part(String en, Map<String, String> t) =>
      (t[en] ?? '').isEmpty ? en : t[en]!;
  // "10 minutes" → "10 dakika"; [upTo] → "10 dakikaya".
  String count(String line, {bool upTo = false}) {
    final m = RegExp(r'^([\d,]+) (\w+?)s?$').firstMatch(line);
    final u = m == null ? null : _units[m[2]];
    if (u == null) return line;
    return '${m![1]} ${upTo ? u.$2 : u.$1}';
  }

  final cast = en['casting_time'] as String;
  var castTr = switch (name(f['casting_time_unit_ref'])) {
    'Action' => 'Eylem',
    'Bonus Action' => 'Bonus Eylem',
    'Reaction' => 'Reaksiyon',
    _ => count(cast.replaceFirst(' or Ritual', '')),
  };
  if (f['reaction_trigger'] case final String t when t.isNotEmpty) {
    final when = _trLowerFirst(part(t, spell)).replaceFirst(RegExp(r'\.$'), '');
    castTr += ', $when alırsın';
  }
  if (f['is_ritual'] == true) castTr += ' ya da Ritüel';

  final range = en['range'] as String;
  final rangeTr = range.endsWith(' feet')
      ? range.replaceFirst(' feet', ' fit')
      : part(range, schema);

  final comps = en['components'] as String;
  final materialEn = f['material_description'] as String? ?? '';
  var material = _trLowerFirst(part(materialEn, spell));
  if (material.isNotEmpty) {
    final gp = f['material_cost_gp'];
    if (gp is num && comps.contains(', worth $gp+ GP')) {
      material += ', $gp+ GP değerinde';
    }
    // The converter's clause; the material's own one is in its translation.
    if (f['material_consumed'] == true && !materialEn.contains('consume')) {
      material = 'büyünün tükettiği, $material';
    }
  }
  final compsTr = comps
      .replaceFirst(RegExp(r' \(.*\)$'), '')
      .split(', ')
      .map((c) => switch (c) {
            'V' => 'S',
            'S' => 'B',
            'M' when material.isNotEmpty => 'M ($material)',
            _ => c,
          })
      .join(', ');

  final dur = en['duration'] as String;
  const conc = 'Concentration, up to ';
  final durTr = switch (dur) {
    'Instantaneous' => 'Anlık',
    'Until dispelled' => 'Defedilene kadar',
    'Special' => 'Özel',
    _ when dur.startsWith(conc) =>
      'Konsantrasyon, ${count(dur.substring(conc.length), upTo: true)} kadar',
    _ => count(dur),
  };

  return {cast: castTr, range: rangeTr, comps: compsTr, dur: durTr};
}

/// "**Rage.** You can…" → "**Öfke.** …": ad ve metin aynı tablodan
/// (sınıf / alt sınıf satırları, A4).
String? _rowTr(String en, Map<String, String> t) {
  final m = RegExp(r'^\*\*(.+?)\.\*\*(?: (.*))?$', dotAll: true).firstMatch(en);
  if (m == null) return null;
  final name = t[m[1]] ?? '';
  final text = m[2] == null ? '' : (t[m[2]] ?? '');
  if (name.isEmpty || (m[2] != null && text.isEmpty)) return null;
  return ['**$name.**', if (text.isNotEmpty) text].join(' ');
}

/// Türün açılış cümlesi (A4).
const _intros = {
  'Dragonborn': 'Bir Ejderdoğan olarak şu özel niteliklere sahipsin.',
  'Dwarf': 'Bir Cüce olarak şu özel niteliklere sahipsin.',
  'Elf': 'Bir Elf olarak şu özel niteliklere sahipsin.',
  'Gnome': 'Bir Gnom olarak şu özel niteliklere sahipsin.',
  'Goliath': 'Bir Goliath olarak şu özel niteliklere sahipsin.',
  'Half-Elf': 'Bir Yarı-Elf olarak şu özel niteliklere sahipsin.',
  'Halfling': 'Bir Buçukluk olarak şu özel niteliklere sahipsin.',
  'Human': 'Bir İnsan olarak şu özel niteliklere sahipsin.',
  'Orc': 'Bir Ork olarak şu özel niteliklere sahipsin.',
  'Tiefling': 'Bir Tiefling olarak aşağıdaki özel niteliklere sahipsin.',
};

/// Türün Traits yazısı: paragraf paragraf trait / eylem / duyu
/// tablolarından ([parts]); "Keen Senses (Elf)" ekiyle de aranır.
String? _traitsTr(
  String name,
  String en,
  List<Map<String, String>> parts,
  Map<String, String> species,
) {
  String? find(String en) {
    for (final t in parts) {
      if ((t[en] ?? '').isNotEmpty) return t[en];
    }
    return null;
  }

  String? findName(String en) {
    if (find(en) case final tr?) return tr;
    for (final t in parts) {
      for (final MapEntry(:key, :value) in t.entries) {
        if (key.startsWith('$en (') && value.isNotEmpty) {
          return value.replaceFirst(RegExp(r' \(.*\)$'), '');
        }
      }
    }
    return null;
  }

  final out = <String>[];
  for (final (i, p) in en.split('\n\n').indexed) {
    if (i == 0) {
      if (_intros[name] case final intro?) {
        out.add(intro);
        continue;
      }
      return null;
    }
    final m = RegExp(r'^\*\*(.+?)\.\*\* (.*)$', dotAll: true).firstMatch(p);
    if (m == null) {
      // mechanical_notes: türün kendi tablosunda.
      if ((species[p] ?? '').isEmpty) return null;
      out.add(species[p]!);
      continue;
    }
    final n = findName(m[1]!);
    final range = RegExp(r'^You have (\w+) with a range of ([\d,]+) feet\.$')
        .firstMatch(m[2]!);
    final text = range == null
        ? find(m[2]!)
        // "Gece Görüşü" → "60 fit menzilli Gece Görüşün vardır."
        : '${range[2]} fit menzilli ${findName(range[1]!)}n vardır.';
    if (n == null || text == null) return null;
    out.add('**$n.** $text');
  }
  return out.join('\n\n');
}

/// "A, B ya da C" (Türkçede son virgül yok).
String _seriesTr(List<String> items, String conj) => items.length < 2
    ? items.join()
    : '${items.take(items.length - 1).join(', ')} $conj ${items.last}';

/// "Choose A or B: (A) …; or (B) 75 GP" → "A'yı ya da B'yi seç: (A) …; ya
/// da (B) 75 GP"; şıklar seçenek etiketinin çevirisinden ([labels]), sınıfta
/// son parçadan önce "ve".
String? _equipmentTr(Object? groups, Map<String, String> labels, bool and) {
  const letters = {'A': "A'yı", 'B': "B'yi", 'C': "C'yi"};
  final options = [
    for (final g in groups as List? ?? const [])
      for (final o in (g as Map)['options'] as List? ?? const []) o as Map,
  ];
  final parts = <String>[];
  for (final o in options) {
    final tr = labels['${o['label']}'] ?? '';
    if (tr.isEmpty) return null;
    parts.add('(${o['option_id']}) ${and ? _seriesTr(tr.split(', '), 've') : tr}');
  }
  if (parts.isEmpty) return null;
  return '${_seriesTr([for (final o in options) letters[o['option_id']]!], 'ya da')} '
      'seç: ${parts.take(parts.length - 1).join('; ')}; ya da ${parts.last}';
}

/// Sınıf adı, -ın hali ve "Becoming a…" kutusunun çok sınıf satırı (A5).
const _classes = {
  'Barbarian': (
    'Barbar',
    'Barbarın',
    'Temel Barbar Nitelikleri tablosundan şu nitelikleri kazan: Can Zarı, '
        'Askeri silahlarla yetkinlik ve Kalkan eğitimi.',
  ),
  'Bard': (
    'Ozan',
    'Ozanın',
    'Temel Ozan Nitelikleri tablosundan şu nitelikleri kazan: Can Zarı, '
        'seçtiğin bir yetenekte yetkinlik, seçtiğin bir Müzik Enstrümanıyla '
        'yetkinlik ve Hafif zırh eğitimi.',
  ),
  'Cleric': (
    'Ruhban',
    'Ruhbanın',
    'Temel Ruhban Nitelikleri tablosundan şu nitelikleri kazan: Can Zarı '
        've Hafif ve Orta zırh ile Kalkan eğitimi.',
  ),
  'Druid': (
    'Druid',
    'Druidin',
    'Temel Druid Nitelikleri tablosundan şu nitelikleri kazan: Can Zarı ve '
        'Hafif zırh ile Kalkan eğitimi.',
  ),
  'Fighter': (
    'Dövüşçü',
    'Dövüşçünün',
    'Temel Dövüşçü Nitelikleri tablosundan şu nitelikleri kazan: Can Zarı, '
        'Askeri silahlarla yetkinlik ve Hafif ve Orta zırh ile Kalkan '
        'eğitimi.',
  ),
  'Monk': (
    'Keşiş',
    'Keşişin',
    'Temel Keşiş Nitelikleri tablosundan Can Zarı niteliğini kazan.',
  ),
  'Paladin': (
    'Paladin',
    'Paladinin',
    'Temel Paladin Nitelikleri tablosundan şu nitelikleri kazan: Can Zarı, '
        'Askeri silahlarla yetkinlik ve Hafif ve Orta zırh ile Kalkan '
        'eğitimi.',
  ),
  'Ranger': (
    'Kolcu',
    'Kolcunun',
    'Temel Kolcu Nitelikleri tablosundan şu nitelikleri kazan: Can Zarı, '
        'Askeri silahlarla yetkinlik, Kolcunun yetenek listesinden seçtiğin '
        'bir yetenekte yetkinlik ve Hafif ve Orta zırh ile Kalkan eğitimi.',
  ),
  'Rogue': (
    'Düzenbaz',
    'Düzenbazın',
    'Temel Düzenbaz Nitelikleri tablosundan şu nitelikleri kazan: Can '
        'Zarı, Düzenbazın yetenek listesinden seçtiğin bir yetenekte '
        'yetkinlik, Hırsızlık Aletleriyle yetkinlik ve Hafif zırh eğitimi.',
  ),
  'Sorcerer': (
    'Sihirbaz',
    'Sihirbazın',
    'Temel Sihirbaz Nitelikleri tablosundan Can Zarını kazan.',
  ),
  'Warlock': (
    'Sehhar',
    'Sehharın',
    'Temel Sehhar Nitelikleri tablosundan şu nitelikleri kazan: Can Zarı ve '
        'Hafif zırh eğitimi.',
  ),
  'Wizard': (
    'Büyücü',
    'Büyücünün',
    'Temel Büyücü Nitelikleri tablosundan Can Zarını kazan.',
  ),
};

/// `srdClassLines` / `srdBackgroundTools`'un PDF satırları (A5).
const _ownLines = {
  'Choose any 3 skills (see “Playing the Game”)':
      'Herhangi 3 yetenek seç (bkz. “Oyunu Oynamak”)',
  'Choose 3 Musical Instruments (see “Equipment”)':
      '3 Müzik Enstrümanı seç (bkz. “Ekipman”)',
  'Choose one type of Artisan’s Tools or Musical Instrument (see '
          '“Equipment”)':
      'Bir tür Zanaatkar Aletleri ya da Müzik Enstrümanı seç (bkz. '
      '“Ekipman”)',
  'Choose one kind of Gaming Set (see “Equipment”)':
      'Bir tür Oyun Seti seç (bkz. “Ekipman”)',
};

/// Sınıfın Core Traits satırları ve Becoming a… kutusu ([en] dönüştürücünün
/// çıktısı); parçalar [t] tablolarından.
Map<String, String> _classPairs(
  Entity c,
  Map<String, dynamic> en,
  Map<String, Entity> byId,
  Map<String, Map<String, String>> t,
) {
  final f = c.fields;
  String? name(Object? r, String scope) {
    final tr = t[scope]![entityRefName(r, byId)] ?? '';
    return tr.isEmpty ? null : tr;
  }

  List<String>? names(Object? refs, String scope) {
    final out = <String>[];
    for (final r in refs is List ? refs : [?refs]) {
      out.add(name(r, scope) ?? (throw StateError('$scope: $r')));
    }
    return out;
  }

  final (cls, gen, multiclass) = _classes[c.name]!;
  final features =
      '$gen 1. seviye özelliklerini kazan; bunlar $cls Özellikleri '
      'tablosunda listelenir.';
  final primary = en['primary_ability'] as String;
  return {
    primary:
        _ownLines[primary] ??
        primary
            .replaceAllMapped(RegExp(r'\w+'), (m) => t['ability']![m[0]] ?? m[0]!)
            .replaceAll(' and ', ' ve ')
            .replaceAll(' or ', ' ya da '),
    en['skill_proficiencies']:
        _ownLines[en['skill_proficiencies']] ??
        'Şunlardan ${f['skill_proficiency_choice_count']} tanesini seç: '
            '${_seriesTr(names(f['skill_proficiency_options'], 'skill')!, 'ya da')}',
    en['weapon_proficiencies']:
        '${_seriesTr(names(f['weapon_proficiency_categories'], 'weapon-category')!, 've')} '
        'silahlar',
    if (en['tool_proficiencies'] case final String tools)
      tools:
          _ownLines[tools] ??
          _seriesTr(names(f['granted_tool_refs'], 'tool')!, 've'),
    en['equipment_choice_groups']: ?_equipmentTr(
      f['equipment_choice_groups'],
      t['class']!,
      true,
    ),
    en['becoming']: [
      '**1. Seviye Karakter Olarak**',
      '- Temel $cls Nitelikleri tablosundaki tüm nitelikleri kazan.\n'
          '- $features',
      '**Çoklu Sınıf Karakteri Olarak**',
      '- $multiclass\n- $features'
          '${(en['becoming'] as String).endsWith('spell slots.') ? ' '
                    'Kullanabileceğin büyü yuvalarını belirlemek için '
                    '“Karakter Yaratma”daki çoklu sınıf kurallarına bak.' : ''}',
    ].join('\n\n'),
  };
}

/// Canavarın Speed satırı (A6): "40 ft., Climb 40 ft., Fly 80 ft. (hover)"
/// → "40 ft., Tırmanma 40 ft., Uçma 80 ft. (süzülme)"; sözcükler
/// `_schema`'daki "Climb (ft)", "Hover"… çevirisinden.
String? _speedTr(String en) {
  if (!RegExp(r'^\d+ ft\.').hasMatch(en)) return null;
  const words = {
    'Burrow': 'Kazma',
    'Climb': 'Tırmanma',
    'Fly': 'Uçma',
    'Swim': 'Yüzme',
    'hover': 'süzülme',
  };
  return en.replaceAllMapped(RegExp(r'[A-Za-z]{3,}'), (m) => words[m[0]] ?? m[0]!);
}

/// Eylemin metni (A6): dönüştürücü [orig]'in başına "(Recharge 5–6). "
/// ya da "(3/Day). ", eksik DC'yi de "*X Saving Throw:* DC n" olarak
/// yazar ([en]). Türkçesi [orig]'in çevirisine aynı eklerle.
String? _actionTr(
  String en,
  String orig,
  Map<String, String> t,
  Map<String, String> ability,
) {
  var tr = t[orig] ?? '';
  if (tr.isEmpty || en == orig) return null;
  var rest = en;
  String? limit;
  final head = RegExp(r'^\(([^)]*)\)\. ').firstMatch(en);
  if (head != null && !orig.startsWith(head[0]!)) {
    limit = head[1];
    rest = en.substring(head.end);
  }
  if (rest != orig) {
    final own = RegExp(r'^\*(\w+) Saving Throw:\* DC (\d+)\. ').firstMatch(rest);
    if (own != null) {
      tr = '*${ability[own[1]]} Kurtarma Zarı:* DC ${own[2]}. $tr';
    } else {
      final dc = RegExp(r'Saving Throw:\* DC (\d+), ').firstMatch(rest)![1];
      tr = tr.replaceFirst('Kurtarma Zarı:* ', 'Kurtarma Zarı:* DC $dc, ');
    }
  }
  if (limit == null) return tr;
  final limitTr = limit == 'Recharge after a Short or Long Rest'
      ? 'Kısa ya da Uzun Dinlenmeden sonra yenilenir'
      : limit
            .replaceFirstMapped(RegExp(r'^(\d+)/Day$'), (m) => 'Günde ${m[1]}')
            .replaceFirst('Recharge', 'Yenilenme');
  return '($limitTr). $tr';
}

void _write(String scope, Map<String, String> table, Map<String, String> s) {
  var filled = 0;
  for (final MapEntry(:key, :value) in s.entries) {
    if (table[key] == '') {
      table[key] = value;
      filled++;
      print('${jsonEncode(key)}\n  → ${jsonEncode(value)}');
    }
  }
  File('$_dir/$scope.json')
      .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(table)}\n');
  print('$scope: $filled öneri yazıldı');
}

void main() {
  final byId = <String, Entity>{
    for (final MapEntry(:key, :value) in buildSrdCorePack().entities.entries)
      key: Entity(
        id: key,
        name: (value as Map)['name'] as String,
        categorySlug: value['type'] as String,
        fields: Map<String, dynamic>.from((value['attributes'] as Map?) ?? {}),
      ),
  };
  final schema = _table('_schema');
  final spell = _table('spell');
  final suggestions = <String, String>{
    for (final c in byId.values)
      if (c.categorySlug == 'spell') ..._spellPairs(c, byId, spell, schema),
  };

  _write('spell', spell, suggestions);

  for (final scope in const ['class', 'subclass']) {
    final t = _table(scope);
    _write(scope, t, {
      for (final MapEntry(:key, :value) in t.entries)
        if (value.isEmpty) key: ?_rowTr(key, t),
    });
  }

  final t = {
    for (final s in const [
      'ability',
      'skill',
      'weapon-category',
      'tool',
      'class',
      'background',
    ])
      s: _table(s),
  };
  _write('class', t['class']!, {
    for (final c in byId.values)
      if (c.categorySlug == 'class')
        ..._classPairs(c, freeSrdFields(c, byId), byId, t),
  });
  _write('background', t['background']!, {
    for (final c in byId.values)
      if (c.categorySlug == 'background')
        if (freeSrdFields(c, byId) case final en) ...{
          en['tool_proficiency']:
              _ownLines[en['tool_proficiency']] ??
              t['tool']![en['tool_proficiency']] ??
              '',
          en['equipment_choice_groups']: ?_equipmentTr(
            c.fields['equipment_choice_groups'],
            t['background']!,
            false,
          ),
        },
  });

  final species = _table('species');
  final parts = [
    for (final s in const ['trait', 'creature-action', 'sense']) _table(s),
  ];
  _write('species', species, {
    for (final c in byId.values)
      if (c.categorySlug == 'species')
        if (freeSrdFields(c, byId)['traits'] case final String en)
          en: ?_traitsTr(c.name, en, parts, species),
  });

  for (final scope in const ['monster', 'animal']) {
    final t = _table(scope);
    _write(scope, t, {
      for (final MapEntry(:key, :value) in t.entries)
        if (value.isEmpty) key: ?_speedTr(key),
    });
  }

  final action = _table('creature-action');
  final ability = _table('ability');
  _write('creature-action', action, {
    for (final c in byId.values)
      if (c.categorySlug == 'creature-action')
        if (freeSrdFields(c, byId)['description'] case final String en)
          en: ?_actionTr(en, c.fields['description'] as String, action, ability),
  });
}
