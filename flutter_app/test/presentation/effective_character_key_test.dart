import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `effectiveCharacterProvider` `Character.id` ile anahtarlanır; `create()`
/// entity'ye ayrı bir uuid bastığı için `entity.id` ile çağrılınca provider
/// sessizce null döner — grants kartı hiç çizilmez, rest/level-up yetenek
/// okuması all-10'a düşer. Sessiz bozulduğu için grep'le korunuyor.
void main() {
  test('effectiveCharacterProvider is never keyed by entity.id', () {
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      for (final m in RegExp(r'effectiveCharacterProvider\(([^)]*)\)')
          .allMatches(src)) {
        if (m.group(1)!.contains('entity.id')) {
          offenders.add('${f.path}: ${m.group(0)}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
