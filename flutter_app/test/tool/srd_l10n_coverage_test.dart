import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/srd_l10n/bin/extract.dart';

/// **SRD TR Faz 7.1 / 7.2.** Kaynaktaki her metnin Türkçesi var (eksik =
/// kırmızı); Türkçe tabloda kaynakta artık olmayan anahtar yok (bayat =
/// kırmızı). İngilizce metin değişince eski çeviri bayat kalır, yenisi eksik
/// düşer — ikisi birlikte çevirinin de güncellenmesini zorlar. Düzeltme:
/// `dart run tool/srd_l10n/bin/extract.dart` bayatı raporlar, yeniyi `""`
/// ile ekler.
void main() {
  final source = collectSrdTexts();
  final tables = <String, Map<String, String>>{
    for (final f in Directory('assets/srd_l10n/tr')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json')))
      f.uri.pathSegments.last.replaceAll('.json', ''):
          (jsonDecode(f.readAsStringSync()) as Map).cast<String, String>(),
  };

  test('7.1 kapsam: çevirisi eksik metin yok', () {
    final missing = [
      for (final MapEntry(key: scope, value: texts) in source.entries)
        for (final en in texts)
          if ((tables[scope]?[en] ?? '').trim().isEmpty)
            '$scope ${jsonEncode(en)}',
    ];
    expect(missing, isEmpty,
        reason: '${missing.length} eksik:\n${missing.take(20).join('\n')}');
  });

  test('7.2 bayat: kaynakta olmayan anahtar yok', () {
    final stale = [
      for (final MapEntry(key: scope, value: t) in tables.entries)
        for (final en in t.keys)
          if (!(source[scope]?.contains(en) ?? false))
            '$scope ${jsonEncode(en)}',
    ];
    expect(stale, isEmpty,
        reason: '${stale.length} bayat:\n${stale.take(20).join('\n')}');
  });
}
