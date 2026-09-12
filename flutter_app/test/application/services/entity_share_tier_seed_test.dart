import 'package:dungeon_master_tool/application/services/entity_share_prepare.dart';
import 'package:dungeon_master_tool/application/providers/entity_provider.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/content.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/lookups.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dünya online'a alındığında DM'in homebrew kural içeriği tek seferde
/// oyunculara açılıyor. Bu seçim bozulursa iki yönde de sessiz hasar var:
/// eksik seçim → oyuncu karakterini yaratamaz, fazla seçim → canavar/loot
/// spoiler'ı oyuncunun database'ine düşer.
void main() {
  Entity card(String id, String slug, {bool linked = false}) =>
      Entity(id: id, categorySlug: slug, linked: linked);

  Map<String, Entity> world(List<Entity> es) => {for (final e in es) e.id: e};

  group('seed kapsamı', () {
    test('tüm Tier 0 + Tier 1 eksi dört kategori', () {
      expect(seedAllowedSlugs, containsAll(tier0Slugs));
      expect(
        seedAllowedSlugs.where(tier1Slugs.contains).length,
        tier1Slugs.length - seedExcludedSlugs.length,
      );
    });

    test('canavar ve loot hiçbir zaman kapsamda değil', () {
      expect(seedExcludedSlugs,
          {'monster', 'animal', 'creature-action', 'magic-item'});
      for (final s in seedExcludedSlugs) {
        expect(seedAllowedSlugs.contains(s), isFalse, reason: s);
      }
    });
  });

  group('seedShareIds', () {
    test('homebrew Tier 0/1 seçilir', () {
      final ids = seedShareIds(world([
        card('a', 'class'),
        card('b', 'spell'),
        card('c', 'damage-type'),
        card('d', 'starter-bundle'),
      ]));
      expect(ids, {'a', 'b', 'c', 'd'});
    });

    test('linked kart seçilmez — oyuncuda kurulu paketten zaten var', () {
      final ids = seedShareIds(world([
        card('srd', 'spell', linked: true),
        card('mine', 'spell'),
      ]));
      expect(ids, {'mine'});
    });

    test('dışlanan dört kategori seçilmez', () {
      final ids = seedShareIds(world([
        for (final s in seedExcludedSlugs) card('x-$s', s),
        card('ok', 'feat'),
      ]));
      expect(ids, {'ok'});
    });

    test('Tier 2 seçilmez', () {
      final ids = seedShareIds(world([
        card('n', 'npc'),
        card('s', 'scene'),
        card('q', 'quest'),
      ]));
      expect(ids, isEmpty);
    });
  });

  group('entitiesFromCampaignData', () {
    // Hub'daki ayar diyaloğu aktif olmayan bir dünyayı publish edebiliyor;
    // tohum orada provider'lardan değil dünyanın kendi blob'undan okur.
    test('blob → seçim, bozuk satır tüm tohumu düşürmez', () {
      final parsed = entitiesFromCampaignData({
        'entities': {
          'a': entityToRaw(card('a', 'class')),
          'bad': 'not a map',
          'm': entityToRaw(card('m', 'monster')),
          'srd': entityToRaw(card('srd', 'spell', linked: true)),
        },
      });
      expect(parsed.keys, {'a', 'm', 'srd'});
      expect(seedShareIds(parsed), {'a'});
    });

    test('entities anahtarı yoksa boş döner', () {
      expect(entitiesFromCampaignData(const {}), isEmpty);
    });
  });
}
