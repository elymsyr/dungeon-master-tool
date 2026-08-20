// `saveSettingsPatch`'in `worlds.updated_at`'e dokunup dokunmadığı.
//
// Regresyon: viewport pan/zoom yazımları (`saveSettingsPatchLocalOnly`) aynı
// repository metodunu çağırdığı için dünyayı "değişti" gösteriyordu. LAN
// eşlemesinde bu, mindmap'te sadece kaydırma yapan cihazı LWW kazananı yapıp
// karşı taraftaki gerçek düzenlemeleri eziyordu.
//
//   cd flutter_app && flutter test test/data/repositories/world_settings_touch_test.dart

import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/repositories/world_repository_impl.dart';
import 'package:dungeon_master_tool/domain/value_objects/world_section_stamps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late WorldRepositoryImpl repo;

  setUp(() async {
    db = openTestDatabase();
    repo = WorldRepositoryImpl(db);
    await repo.save('Barovia', {'entities': <String, dynamic>{}});
  });

  tearDown(() => db.close());

  Future<DateTime> worldUpdatedAt() async =>
      (await db.worldsDao.getByName('Barovia'))!.updatedAt;

  test('normal patch dünyayı damgalar', () async {
    final before = await worldUpdatedAt();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await repo.saveSettingsPatch('Barovia', {'mind_maps': 1});
    expect((await worldUpdatedAt()).isAfter(before), isTrue);
  });

  test('touchWorld: false dünyayı damgalamaz', () async {
    final before = await worldUpdatedAt();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await repo.saveSettingsPatch(
      'Barovia',
      {'mind_map_views': 1},
      touchWorld: false,
    );
    expect(await worldUpdatedAt(), before);
    // Veri yine de yazılmış olmalı — yalnız damga atlanıyor.
    expect((await repo.load('Barovia'))['mind_map_views'], 1);
  });

  test('normal patch bölüm damgası bırakır, local-only bırakmaz', () async {
    await repo.saveSettingsPatch('Barovia', {'combat_state': 1});
    await repo.saveSettingsPatch(
      'Barovia',
      {'mind_map_views': 2},
      touchWorld: false,
    );
    final stamps = readSectionStamps(await repo.load('Barovia'));
    expect(stamps.keys, ['combat_state']);
  });
}
