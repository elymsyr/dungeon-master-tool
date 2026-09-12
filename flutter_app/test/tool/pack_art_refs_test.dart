import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `tool/art_gen/stamp_art_refs.py --check`'in Dart karşılığı — tek farkı
/// **normal test koşusunda** çalışması.
///
/// `dmt-art://` ref'leri `build_packs.dart`'ın ürettiği şey değil: build'den
/// SONRA stamper basıyor. Dolayısıyla paketleri yeniden üretmek her seferinde
/// hepsini siliyor ve bunu hatırlatan hiçbir şey yoktu — `b664fe83`'te
/// (packVersion 2.0.0 → 2.1.0) 19 Open5e paketinden **5527 ref** öyle düştü ve
/// mağazadan inen her paket kartsız kuruldu. Stamper'ın `--check` modu bunu
/// görüyordu ama hiçbir CI adımı onu çağırmıyor.
///
/// Kural: `art_jobs.jsonl` bir uuid için görsel ürettiğini söylüyorsa ve o uuid
/// bir pakette entity ise, o entity'nin `image_path`'i o görseli göstermeli.
/// Elle konmuş (boş olmayan, art olmayan) bir yol kasıtlıdır, ona dokunulmaz.
void main() {
  final root = Directory.current.path; // flutter_app/
  final jobs = File('$root/../tool/art_gen/art_jobs.jsonl');
  final packDir = Directory('$root/assets/open5e_packs');

  test('every generated card image is stamped into its pack entity', () {
    if (!jobs.existsSync() || !packDir.existsSync()) {
      markTestSkipped('art_gen kaynakları bu checkout\'ta yok');
      return;
    }

    final arted = <String>{
      for (final line in jobs.readAsLinesSync())
        if (line.trim().isNotEmpty) jsonDecode(line)['uuid'] as String,
    };
    expect(arted, isNotEmpty, reason: 'art_jobs.jsonl boş okundu');

    final missing = <String, int>{};
    for (final f in packDir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.pkg.json')) continue;
      final data = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final entities = data['entities'];
      if (entities is! Map) continue;

      var gaps = 0;
      entities.forEach((uuid, row) {
        if (!arted.contains(uuid) || row is! Map) return;
        final path = (row['image_path'] as String?) ?? '';
        // Elle konmuş bir görsel kasıtlı — stamper da onu korur.
        if (path.isNotEmpty) return;
        gaps++;
      });
      if (gaps > 0) missing[f.uri.pathSegments.last] = gaps;
    }

    expect(
      missing,
      isEmpty,
      reason: 'Bu paketlerin kart görselleri üretilmiş ama ref basılmamış — '
          'paketler build_packs ile yeniden üretilip '
          '`python3 tool/art_gen/stamp_art_refs.py` koşulmamış olabilir. '
          'Eksikler: $missing',
    );
  });
}
