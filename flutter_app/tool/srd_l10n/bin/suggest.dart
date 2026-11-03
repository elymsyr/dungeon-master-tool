// Free SRD Türkçe öneri aracı (docs/free-template/SRD-FREE-ALANLAR.md §8) —
// dönüştürücünün (`free_srd_pack.dart`) parçalardan kurduğu satırların
// Türkçesini, aynı parçaların mevcut çevirisinden kurar ve
// `assets/srd_l10n/tr/` tablolarında boş ("") kalan anahtara yazar. Dolu
// çeviriye dokunmaz. Öneriler gözden geçirilir; ardından check_pairs.
//
//   dart run tool/srd_l10n/bin/extract.dart    # yeni anahtarlar "" ile
//   dart run tool/srd_l10n/bin/suggest.dart    # boşları önerilerle doldurur
//
// Bugün yalnız büyünün dört başlık satırı (A2); kapanan her faz kendi
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

  var filled = 0;
  for (final MapEntry(:key, :value) in suggestions.entries) {
    if (spell[key] == '') {
      spell[key] = value;
      filled++;
      print('${jsonEncode(key)}\n  → ${jsonEncode(value)}');
    }
  }
  File('$_dir/spell.json')
      .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(spell)}\n');
  print('spell: $filled öneri yazıldı');
}
