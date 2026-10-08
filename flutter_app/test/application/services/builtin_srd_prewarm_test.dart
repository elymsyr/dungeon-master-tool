import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('arka planda kurulan SRD haritası provider\'a aynen gelir', () async {
    await prewarmBuiltinSrdEntities();

    final a = ProviderContainer();
    final b = ProviderContainer();
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    // Senkron yedek her container'da yeni harita kurardı; aynı nesne =
    // isolate'ten gelen harita kullanılıyor.
    final prewarmed = a.read(builtinSrdEntitiesProvider);
    expect(identical(prewarmed, b.read(builtinSrdEntitiesProvider)), isTrue);
    expect(prewarmed, equals(buildBuiltinSrdEntities()));
  });
}
