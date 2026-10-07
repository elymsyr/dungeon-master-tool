// SRD Türkçeleştirme (docs/srd-tr/ROADMAP.md Faz 2) — yerleşik şemadaki ve
// SRD paketindeki ekranda görünen İngilizce metinleri scope başına toplayıp
// `assets/srd_l10n/tr/<scope>.json` iskeletine yazar. Kaynağa dokunmaz.
//
//   dart run tool/srd_l10n/bin/extract.dart [--out assets/srd_l10n/tr]
//
// Mevcut çeviriler korunur: kaynakta hâlâ olan anahtarın değeri aynen kalır,
// yeni anahtar "" ile eklenir, kaynakta artık olmayan anahtar silinmez
// (bayat diye raporlanır — çeviri emeği kaybolmasın).
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/services/content_translator.dart';

/// Satır adları makine anahtarı olan kategoriler (`pool:rage_uses`,
/// `state:raging`); `resource-pool`'un görünen adı `display_name` alanındadır,
/// `character-state`'in görünen metni yoktur.
const _machineNameSlugs = {'resource-pool', 'character-state'};

final _hasLetters = RegExp(r'[A-Za-z]{2,}');
final _snakeKey = RegExp(r'^[a-z0-9_+/.\-]+$');
final _diceOnly = RegExp(r'^[\d\s+×x*/\-−d]+$');

/// Çevrilecek metin mi, yoksa makine değeri mi (snake_case anahtar, zar,
/// sayı)?
bool _isProse(String s) {
  final t = s.trim();
  if (t.isEmpty || !_hasLetters.hasMatch(t)) return false;
  if (_snakeKey.hasMatch(t)) return false;
  if (_diceOnly.hasMatch(t)) return false;
  return true;
}

void main(List<String> args) {
  final outDir = args.length >= 2 && args[0] == '--out'
      ? args[1]
      : 'assets/srd_l10n/tr';

  final build = generateBuiltinDnd5eV2Schema();
  final scopes = <String, List<String>>{}; // scope → sıralı benzersiz metin
  final seen = <String, Set<String>>{};
  void add(String scope, Object? v) {
    if (v is! String || !_isProse(v)) return;
    if (seen.putIfAbsent(scope, () => {}).add(v)) {
      scopes.putIfAbsent(scope, () => []).add(v);
    }
  }

  // _schema: kategori adları, alan etiketleri, yardım metinleri, enum seçenekleri.
  final fieldsBySlug = <String, List<FieldSchema>>{};
  for (final c in build.schema.categories) {
    fieldsBySlug[c.slug] = c.fields;
    add('_schema', c.name);
    for (final g in c.fieldGroups) {
      add('_schema', g.name);
    }
    for (final f in c.fields) {
      add('_schema', f.label);
      add('_schema', f.placeholder);
      add('_schema', f.helpText);
      for (final sf in f.subFields) {
        add('_schema', sf['label']);
      }
      if (f.fieldType == FieldType.enum_) {
        for (final o in f.validation.allowedValues ?? const <String>[]) {
          add('_schema', o);
        }
      }
    }
  }

  void addRow(String slug, String? name, String? description, Map fields) {
    if (!_machineNameSlugs.contains(slug)) add(slug, name);
    add(slug, description);
    for (final f in fieldsBySlug[slug] ?? const <FieldSchema>[]) {
      if (srdL10nMachineTextKeys.contains(f.fieldKey)) continue;
      final v = fields[f.fieldKey];
      switch (f.fieldType) {
        case FieldType.text:
        case FieldType.textarea:
        case FieldType.markdown:
          add(slug, v);
        case FieldType.enum_:
          // Değer şemanın seçeneğiyse _schema'dadır; değilse burada yakala.
          final opts = f.validation.allowedValues ?? const <String>[];
          for (final s in v is List ? v : [v]) {
            if (s is String && !opts.contains(s)) add('_schema', s);
          }
        case FieldType.levelTextTable:
          for (final t in v is Map ? v.values : const []) {
            add(slug, t);
          }
        case FieldType.classFeatures:
        case FieldType.subspeciesOptions:
          for (final r in v is List ? v : const []) {
            if (r is Map) {
              add(slug, r['name']);
              add(slug, r['description']);
            }
          }
        case FieldType.equipmentChoiceGroups:
        case FieldType.playerChoices:
          for (final g in v is List ? v : const []) {
            if (g is! Map) continue;
            add(slug, g['label']);
            add(slug, g['prompt']);
            for (final o in g['options'] is List ? g['options'] as List : const []) {
              if (o is Map) add(slug, o['label']);
            }
          }
        default:
          // relation / sayı / zar / proficiencyTable (adları ability-skill
          // scope'undan çevrilir) — makine değeri.
          break;
      }
    }
  }

  // Tier-0 seed satırları.
  for (final e in build.seedRows.entries) {
    for (final row in e.value) {
      addRow(e.key, row['name'] as String?, row['description'] as String?,
          (row['fields'] as Map?) ?? const {});
    }
  }
  // Tier-1 SRD paketi (DB'ye giden haliyle).
  for (final raw in buildSrdCorePack().entities.values) {
    final m = raw as Map;
    addRow(m['type'] as String, m['name'] as String?,
        m['description'] as String?, (m['attributes'] as Map?) ?? const {});
  }

  Directory(outDir).createSync(recursive: true);
  const enc = JsonEncoder.withIndent('  ');
  final names = scopes.keys.toList()..sort();
  print('| scope | metin | kelime | çevrili | bayat |');
  print('|---|---:|---:|---:|---:|');
  var tText = 0, tWords = 0, tDone = 0, tStale = 0;
  for (final scope in names) {
    final file = File('$outDir/$scope.json');
    final old = file.existsSync()
        ? (jsonDecode(file.readAsStringSync()) as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final texts = scopes[scope]!;
    final out = <String, String>{
      for (final t in texts) t: (old[t] as String?) ?? '',
    };
    final stale = old.keys.where((k) => !out.containsKey(k)).toList();
    for (final k in stale) {
      out[k] = old[k] as String;
    }
    file.writeAsStringSync('${enc.convert(out)}\n');

    final words = texts.fold<int>(
        0, (n, t) => n + t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length);
    final done = texts.where((t) => out[t]!.isNotEmpty).length;
    print('| $scope | ${texts.length} | $words | $done | ${stale.length} |');
    tText += texts.length;
    tWords += words;
    tDone += done;
    tStale += stale.length;
  }
  print('| **toplam** | **$tText** | **$tWords** | **$tDone** | **$tStale** |');
}
