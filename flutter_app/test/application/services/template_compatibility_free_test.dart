// Anahtar bazlı uyumluluk (docs/free-template/ROADMAP.md Faz 5, DESIGN §15.2):
// taraflardan biri free ise kategori slug'la, alan anahtarla eşleşir;
// yerleşik ↔ yerleşik bugünkü yolda kalır (Y4).
//
//   cd flutter_app && flutter test test/application/services/template_compatibility_free_test.dart

import 'package:dungeon_master_tool/application/services/template_compatibility_service.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/template_compatibility.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-10-12T00:00:00.000Z';

void main() {
  final svc = TemplateCompatibilityService();
  final builtin = generateBuiltinDnd5eV2Schema().schema;
  final srd = copyAsFreeTemplate(builtin, id: 'free-srd', name: 'SRD', now: _now);

  WorldSchema mapCat(
    WorldSchema s,
    String slug,
    EntityCategorySchema Function(EntityCategorySchema) f,
  ) =>
      s.copyWith(categories: [
        for (final c in s.categories) c.slug == slug ? f(c) : c,
      ]);

  test('aynı template: uyarı yok', () {
    final r = svc.check(srd, srd);
    expect(r.byKey, isTrue);
    expect(r.level, CompatibilityLevel.perfect);
  });

  test('etiketi değişen alan anahtarıyla eşleşir (E5.6)', () {
    final world = mapCat(srd, 'npc', (c) => c.copyWith(fields: [
          for (final f in c.fields) f.copyWith(label: '${f.label} (yeni)'),
        ]));
    expect(svc.check(srd, world).level, CompatibilityLevel.perfect);
  });

  test('eksik kategori ve alan listelenir; kartsız kategori sayılmaz', () {
    final npc = srd.categories.firstWhere((c) => c.slug == 'npc');
    final dropped = npc.fields.first;
    var world = mapCat(srd, 'npc', (c) => c.copyWith(fields: c.fields.skip(1).toList()));
    world = world.copyWith(categories: [
      for (final c in world.categories)
        if (c.slug != 'quest' && c.slug != 'spell') c,
    ]);

    final r = svc.check(srd, world, usedCategorySlugs: {'npc', 'quest'});
    expect(r.level, CompatibilityLevel.compatible);
    expect(r.removedCategories, [
      srd.categories.firstWhere((c) => c.slug == 'quest').name,
    ]);
    expect(r.removedFields, ['${npc.name}: ${dropped.label}']);
  });

  test('yerleşik paket → free dünya da anahtarla', () {
    final r = svc.check(builtin, srd);
    expect(r.byKey, isTrue);
  });

  test('yerleşik ↔ yerleşik bugünkü yolda', () {
    final r = svc.check(builtin, builtin);
    expect(r.byKey, isFalse);
    expect(r.level, CompatibilityLevel.perfect);
  });
}
