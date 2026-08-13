import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/application/character_creation/character_draft.dart';
import 'package:dungeon_master_tool/application/character_creation/wizard_options.dart';
import 'package:dungeon_master_tool/application/providers/character_provider.dart';
import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/application/services/package_import_service.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:dungeon_master_tool/domain/services/entity_ref.dart';
import 'package:dungeon_master_tool/presentation/screens/characters/wizard/character_creation_wizard_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// **U2 — her paket ailesi için wizard seviyesinde test.**
///
/// `bundled_pack_resolve_test` bir mekaniğin karakter sayfasına indiğini
/// kanıtlar. Bu dosya bir adım öncesini kanıtlar: paketi kuran oyuncu wizard'da
/// o satırı **görebiliyor mu**. İkisi ayrı sorular — bir alt sınıf mükemmel
/// çözülüp, `parent_class_ref` softRef'i okunamadığı için listede hiç
/// çıkmayabilir (U1 öncesi tam olarak bu oluyordu).
///
/// Test veriye bakarak yürür: `assets/open5e_packs/` altındaki her paket
/// taranır, chargen kategorisi (class/subclass/species/subspecies/background/
/// feat/spell) taşıyanlar için o kategorinin wizard okuyucusu çağrılır. Yeni
/// bir paket eklendiğinde test dosyasına dokunmadan kapsama girer.
void main() {
  final srd = buildBuiltinSrdEntities();
  final playerCat = findPlayerCategory(generateBuiltinDnd5eV2Schema().schema)!;

  final tier0 = <String, Map<String, String>>{};
  for (final e in srd.values) {
    tier0.putIfAbsent(e.categorySlug, () => <String, String>{})[e.name] = e.id;
  }

  /// Paketi kurulmuş gibi yükle (bkz. `bundled_pack_resolve_test`).
  Map<String, Entity> installPack(File file) {
    final root = jsonDecode(file.readAsStringSync()) as Map;
    final entities = root['entities'] as Map;
    final out = <String, Entity>{};
    entities.forEach((id, raw) {
      final row = raw as Map;
      final attrs = Map<String, dynamic>.from(
          (row['attributes'] as Map?) ?? const <String, dynamic>{});
      out['$id'] = Entity(
        id: '$id',
        categorySlug: row['type']?.toString() ?? '?',
        name: row['name']?.toString() ?? '',
        description: row['description']?.toString() ?? '',
        tags: [
          for (final t in (row['tags'] as List?) ?? const []) '$t',
        ],
        fields: {
          for (final e in attrs.entries)
            e.key: PackageImportService.resolveLookupPlaceholder(e.value, tier0),
        },
      );
    });
    return out;
  }

  const chargenSlugs = {
    'class',
    'subclass',
    'species',
    'subspecies',
    'background',
    'feat',
    'spell',
  };

  final packs = Directory('assets/open5e_packs')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.pkg.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('bundled paketler bulundu', () => expect(packs, isNotEmpty));

  for (final file in packs) {
    final packName =
        file.uri.pathSegments.last.replaceAll('.pkg.json', '');
    final pack = installPack(file);
    final byCat = <String, List<Entity>>{};
    for (final e in pack.values) {
      if (chargenSlugs.contains(e.categorySlug)) {
        byCat.putIfAbsent(e.categorySlug, () => []).add(e);
      }
    }
    // Yalnız canavar taşıyan paketlerin wizard'da işi yok.
    if (byCat.isEmpty) continue;

    group(packName, () {
      final world = {...srd, ...pack};

      Entity? classOf(Entity subclass) {
        final id = resolveEntityRef(subclass.fields['parent_class_ref'], world);
        return id == null ? null : world[id];
      }

      if (byCat.containsKey('subclass')) {
        test('subclass adımı her paket alt sınıfını sınıfının altında listeler',
            () {
          final orphans = <String>[];
          for (final sub in byCat['subclass']!) {
            final parent = classOf(sub);
            if (parent == null) {
              orphans.add('${sub.name}: parent_class_ref '
                  '${jsonEncode(sub.fields['parent_class_ref'])} çözülmedi');
              continue;
            }
            if (!subclassesForClass(parent.id, world).contains(sub)) {
              orphans.add('${sub.name}: ${parent.name} listesinde yok');
            }
          }
          expect(orphans, isEmpty);
        });

        // B1'in wizard tarafı: `granted_at_level` dolu olmalı, yoksa adım her
        // alt sınıfı 1. seviyede açık gösterir.
        test('granted_at_level 1–20 aralığında ve varsayılana düşmüyor', () {
          final missing = [
            for (final sub in byCat['subclass']!)
              if (sub.fields['granted_at_level'] == null) sub.name,
          ];
          final bad = [
            for (final sub in byCat['subclass']!)
              if (subclassGrantedAtLevel(sub) < 1 ||
                  subclassGrantedAtLevel(sub) > 20)
                sub.name,
          ];
          expect(bad, isEmpty);
          // toh'ta bir satırın üst kaynağı yok (§5.2); tolerans tek satır.
          expect(missing.length, lessThanOrEqualTo(1),
              reason: 'granted_at_level boş: $missing');
        });
      }

      if (byCat.containsKey('subspecies')) {
        test('subspecies adımı her paket alt türünü türünün altında listeler',
            () {
          final orphans = <String>[];
          for (final sub in byCat['subspecies']!) {
            final parentId =
                resolveEntityRef(sub.fields['parent_species_ref'], world);
            if (parentId == null) {
              orphans.add('${sub.name}: parent_species_ref çözülmedi');
              continue;
            }
            if (!subspeciesForSpecies(parentId, world).contains(sub)) {
              orphans.add('${sub.name}: tür listesinde yok');
            }
          }
          expect(orphans, isEmpty);
        });
      }

      if (byCat.containsKey('spell')) {
        test('spell adımı paket büyülerini bir sınıfın altında gösterir', () {
          final classes = world.values.where((e) => e.categorySlug == 'class');
          final visible = <String, int>{};
          for (final c in classes) {
            final n = byCat['spell']!
                .where((s) => spellMatchesClass(s, c, world))
                .length;
            if (n > 0) visible[c.name] = n;
          }
          expect(visible, isNotEmpty,
              reason: 'paketin hiçbir büyüsü hiçbir sınıfın listesine düşmüyor '
                  '— adım boş render eder');
          // Bugünkü görünürlük tamamen `tags` üzerinden; L3 `class_refs`'e
          // geçerken bu sayının altına inmemeli.
          final total = visible.values.fold<int>(0, (a, b) => a + b);
          expect(total, greaterThan(0));
        });
      }

      if (byCat.containsKey('background')) {
        test('background origin_feat_ref çözülür (varsa)', () {
          final broken = [
            for (final bg in byCat['background']!)
              if (bg.fields['origin_feat_ref'] != null &&
                  resolveEntityRef(bg.fields['origin_feat_ref'], world) == null)
                bg.name,
          ];
          expect(broken, isEmpty);
        });
      }

      test('paket seçimleriyle taslak commit edilir', () {
        // Identity → Class → Subclass: paket ne sunuyorsa onu seç, kalanı
        // gömülü SRD'den tamamla (paketlerin çoğu sadece bir kategori taşıyor).
        final race = byCat['species']?.first ??
            srd.values.firstWhere((e) => e.categorySlug == 'species');
        final klass = byCat['class']?.first ??
            srd.values.firstWhere((e) => e.categorySlug == 'class');
        final subclass = byCat['subclass']
            ?.where((s) => classOf(s)?.id == klass.id)
            .firstOrNull;
        final bg = byCat['background']?.first;
        final subspecies = byCat['subspecies']
            ?.where((s) =>
                resolveEntityRef(s.fields['parent_species_ref'], world) ==
                race.id)
            .firstOrNull;

        final draft = CharacterDraft(
          level: subclass == null ? 1 : subclassGrantedAtLevel(subclass),
          raceId: race.id,
          classId: klass.id,
          subclassId: subclass?.id,
          subspeciesId: subspecies?.id,
          backgroundId: bg?.id,
          featIds: [
            if (byCat['feat'] != null) byCat['feat']!.first.id,
          ],
          baseAbilities: const {
            'STR': 10, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 10, 'CHA': 10, //
          },
        );

        final seed = buildSeedFields(
          draft: draft,
          playerCat: playerCat,
          race: race,
          characterClass: klass,
          background: bg,
          entities: world,
        );
        expect(seed, isNotEmpty);

        final eff = CharacterResolver.resolve(
          Character(
            id: 'pc',
            templateId: 'tpl',
            templateName: 'Tpl',
            worldId: 'w',
            createdAt: '0',
            updatedAt: '0',
            entity: Entity(id: 'pc_e', categorySlug: 'player', fields: seed),
          ),
          world,
        );
        // Seçilen satırlar sayfaya taşındı mı — id'ler seed'e yazıldıysa
        // resolver de aynı satırları görmüş olmalı.
        expect(eff.effectiveAbilities.keys, hasLength(6));
        expect(eff.warnings.where((w) => w.contains('null')), isEmpty);
      });
    });
  }
}
