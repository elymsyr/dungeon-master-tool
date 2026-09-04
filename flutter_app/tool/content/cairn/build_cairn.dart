/// Cairn markdown → `world-blueprint.json` (iki paket).
///
/// Kullanım (flutter_app/ içinden):
/// ```
/// dart run tool/content/cairn/build_cairn.dart [--src <cairn klonu>] [--pack core|community|all]
/// ```
///
/// Çıktı `assets/worlds/cairn/<pack>/world-blueprint.json`. Oradan sonrası
/// standart boru hattı:
/// ```
/// dart run tool/content/convert_blueprint.dart --dir assets/worlds/cairn/<pack> --check
/// dart run tool/content/convert_blueprint.dart --dir assets/worlds/cairn/<pack>
/// ```
///
/// Bu araç **sadece** markdown'ı blueprint şekline sokar; şema/ref/medya
/// doğrulaması `convert_blueprint.dart`'ın işi — ayrı bir emitter yazılmadı.
library;

import 'dart:convert';
import 'dart:io';

import 'bp.dart';
import 'src/backgrounds.dart';
import 'src/equipment.dart';
import 'src/lore.dart';
import 'src/marketplace.dart';
import 'src/monsters.dart';
import 'src/relics.dart';
import 'src/spellbooks.dart';

const _outRoot = 'assets/worlds/cairn';

/// Parser adı → çıktısı. `--only` bu isimleri alır; tek bir parser'ı izole
/// doğrulamak için (`--only monsters --out /tmp/x`).
final _parsers =
    <String, Map<String, List<Bp>> Function(String)>{
  'monsters': parseMonsters,
  'backgrounds': parseBackgrounds,
  'marketplace': parseMarketplace,
  'reliquary': parseReliquary,
  'spellbooks': parseSpellbooks,
  'lore': parseLore,
  'more-relics': parseMoreRelics,
  'more-spellbooks': parseMoreSpellbooks,
  'more-equipment': parseMoreEquipment,
};

/// Sıra anlamlı: entity id'si isimden türüyor, yani aynı kategoride aynı ad
/// **hata**. `marketplace` önce gelir — fiyat listesi kanonik addır; sonraki
/// parser'lar (ör. background başlangıç ekipmanı) aynı eşyayı tekrar
/// tanımlarsa [_write] onu düşürür ve raporlar.
const _corePack = ['marketplace', 'monsters', 'backgrounds', 'reliquary', 'spellbooks', 'lore'];
const _communityPack = ['more-relics', 'more-spellbooks', 'more-equipment'];

void main(List<String> args) {
  var src = '../../cairn';
  var pack = 'all';
  String? only;
  String? out;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--src':
        if (i + 1 < args.length) src = args[++i];
      case '--pack':
        if (i + 1 < args.length) pack = args[++i];
      case '--only':
        if (i + 1 < args.length) only = args[++i];
      case '--out':
        if (i + 1 < args.length) out = args[++i];
    }
  }

  if (!Directory('$src/second-edition').existsSync()) {
    stderr.writeln('✗ cairn klonu bulunamadı: $src\n'
        '  --src ile yolu ver (ör. --src ~/GitHub/cairn)');
    exit(66);
  }

  if (only != null) {
    // Virgüllü liste: bir parser'ın ref verdiği entity'ler başka parser'da
    // tanımlıysa ikisini birlikte doğrulamak gerekir
    // (`--only marketplace,backgrounds`).
    final names = only.split(',').map((s) => s.trim()).toList();
    final unknown = names.where((n) => !_parsers.containsKey(n)).toList();
    if (unknown.isNotEmpty) {
      stderr.writeln('✗ bilinmeyen parser ${unknown.join(', ')} — '
          'seçenekler: ${_parsers.keys.join(', ')}');
      exit(64);
    }
    _write(out ?? '$_outRoot/_only-${names.join('-')}',
        [for (final n in names) _parsers[n]!(src)],
        scratch: out != null);
    return;
  }

  if (pack == 'core' || pack == 'all') {
    _write('$_outRoot/cairn-2e-core',
        [for (final n in _corePack) _parsers[n]!(src)]);
  }
  if (pack == 'community' || pack == 'all') {
    _write('$_outRoot/cairn-community',
        [for (final n in _communityPack) _parsers[n]!(src)]);
  }
}

void _write(String dir, List<Map<String, List<Bp>>> parts,
    {bool scratch = false}) {
  final categories = <String, List<Bp>>{};
  for (final part in parts) {
    mergeInto(categories, part);
  }
  final dropped = _dedupe(categories);
  categories.removeWhere((_, rows) => rows.isEmpty);
  final blueprint = <String, dynamic>{
    'version': '1.0.0',
    'source_system': 'cairn',
    'app_schema': 'builtin-dnd5e-default-v2',
    'categories': categories,
    'cross_references': const <dynamic>[],
  };
  final path = '$dir/world-blueprint.json';
  Directory(dir).createSync(recursive: true);
  if (scratch) {
    // `convert_blueprint.dart --dir` bir manifest bekliyor; izole doğrulama
    // dizini için asgarisini bas.
    File('$dir/manifest.json').writeAsStringSync(jsonEncode({
      'slug': 'cairn-scratch',
      'title': 'Cairn scratch',
      'system': 'cairn',
      'version': '0.0.0',
    }));
  }
  File(path).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(blueprint)}\n');
  final total = categories.values.fold<int>(0, (a, r) => a + r.length);
  final counts =
      categories.entries.map((e) => '${e.key}=${e.value.length}').join(', ');
  stdout.writeln('✓ $path — $total entity${counts.isEmpty ? '' : ' ($counts)'}');
  for (final d in dropped) {
    stdout.writeln('  · yinelenen ad düşürüldü: $d');
  }
}

/// Aynı kategoride aynı adı ikinci kez tanımlayan satırları atar; ilk yazan
/// kazanır. Converter bunu zaten **hata** sayıyor — burada düşürmek, iki
/// parser'ın aynı eşyayı (ör. "Rations (3 uses)") tanımlamasını build'i
/// kırmadan çözer. Düşen her ad rapor edilir, sessiz kayıp yok.
List<String> _dedupe(Map<String, List<Bp>> categories) {
  final dropped = <String>[];
  for (final entry in categories.entries) {
    final seen = <String>{};
    entry.value.retainWhere((row) {
      final name = '${(row['mapping'] as Map)['name']}';
      if (seen.add(name.toLowerCase().trim())) return true;
      dropped.add('${entry.key}/$name');
      return false;
    });
  }
  return dropped;
}

