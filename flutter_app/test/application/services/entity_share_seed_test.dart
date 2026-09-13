import 'package:dungeon_master_tool/application/providers/pinned_entity_provider.dart';
import 'package:dungeon_master_tool/application/providers/shared_entity_provider.dart';
import 'package:dungeon_master_tool/application/services/entity_share_prepare.dart';
import 'package:dungeon_master_tool/application/providers/entity_provider.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dünya online'a alındığında oyunculara **yalnızca DM'in işaretledikleri**
/// açılır. Kategori/tier kuralı 2026-09-14'te kaldırıldı; bu dosya o sınırı
/// koruyor — seçim geri kategoriye kayarsa canavar/loot spoiler'ı oyuncunun
/// database'ine düşer.
void main() {
  Entity card(String id, String slug, {bool linked = false}) =>
      Entity(id: id, categorySlug: slug, linked: linked);

  Map<String, Entity> world(List<Entity> es) => {for (final e in es) e.id: e};

  group('seedShareIds', () {
    final cards = world([
      card('a', 'class'),
      card('m', 'monster'),
      card('n', 'npc'),
      card('srd', 'spell', linked: true),
    ]);

    test('yalnızca işaretliler seçilir — kategori hiç bakılmaz', () {
      expect(seedShareIds(cards, {'a', 'm', 'n'}), {'a', 'm', 'n'});
    });

    test('işaret yoksa hiçbir şey gitmez (eski tier tohumu kaldırıldı)', () {
      expect(seedShareIds(cards, const {}), isEmpty);
    });

    test('linked kart işaretliyse gider — DM bilinçli seçmiş', () {
      expect(seedShareIds(cards, {'srd'}), {'srd'});
    });

    test('silinmiş kartın artık işareti gövdesiz satır yazmaz', () {
      expect(seedShareIds(cards, {'a', 'ghost'}), {'a'});
    });
  });

  group('işaret seti blob round-trip', () {
    test('publish edilen dünya aktif değilse işaret blob\'dan okunur', () {
      final blob = <String, dynamic>{
        kSharedEntitiesKey: ['a', 'b'],
      };
      expect(parseEntityIdSet(blob[kSharedEntitiesKey]), {'a', 'b'});
      expect(parseEntityIdSet(null), isEmpty);
      expect(parseEntityIdSet([1, 'a']), {'a'});
    });
  });

  group('entitiesFromCampaignData', () {
    // Hub'daki ayar diyaloğu aktif olmayan bir dünyayı publish edebiliyor;
    // tohum orada provider'lardan değil dünyanın kendi blob'undan okur.
    test('blob → kartlar, bozuk satır tüm tohumu düşürmez', () {
      final parsed = entitiesFromCampaignData({
        'entities': {
          'a': entityToRaw(card('a', 'class')),
          'bad': 'not a map',
          'm': entityToRaw(card('m', 'monster')),
        },
      });
      expect(parsed.keys, {'a', 'm'});
      expect(seedShareIds(parsed, {'a'}), {'a'});
    });

    test('entities anahtarı yoksa boş döner', () {
      expect(entitiesFromCampaignData(const {}), isEmpty);
    });
  });
}
