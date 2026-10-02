// Oyuncunun gri kartı (§2.5): paylaşımı geri çekilen ya da DM'in sildiği
// (paylaşım satırı duruyor, son doğrulamanın listesinde yok) homebrew kart.
//
//   flutter test test/application/providers/revoked_shared_ids_test.dart

import 'package:dungeon_master_tool/application/providers/visible_entity_provider.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cards = {
    'canli': Entity(id: 'canli', categorySlug: 'npc'),
    'geri': Entity(id: 'geri', categorySlug: 'npc'),
    'silindi': Entity(id: 'silindi', categorySlug: 'npc'),
    'paket': Entity(id: 'paket', categorySlug: 'npc', linked: true),
  };

  test('doğrulama yokken yalnız paylaşım listesi', () {
    expect(revokedSharedIds(cards, {'canli', 'silindi'}, null), {'geri'});
  });

  test('DM sildi: satır duruyor ama doğrulamada yok → gri', () {
    expect(
      revokedSharedIds(cards, {'canli', 'silindi'}, {'canli', 'paket'}),
      {'geri', 'silindi'},
    );
  });

  test('linked kart hiç gri değil', () {
    expect(revokedSharedIds(cards, const {}, const {}),
        {'canli', 'geri', 'silindi'});
  });
}
