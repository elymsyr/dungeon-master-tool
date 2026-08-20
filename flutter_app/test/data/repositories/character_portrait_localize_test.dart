// Karakter portresi kaydedilirken veri kökü içine alınıyor mu?
//
// `CharacterRepository.save` tek çıkış kapısı — editör, oluşturma sihirbazı ve
// içe aktarma yollarının hepsi buradan geçiyor. Ham seçici yolu kaydedilirse
// portre ne LAN eşlemesinde taşınır (`LanSyncSession._mediaFor` karakter
// dosyalarını `{id}_` önekiyle süzüyor) ne de kullanıcı dosyayı taşıdığında
// açılır.
//
//   cd flutter_app && flutter test test/data/repositories/character_portrait_localize_test.dart

import 'dart:io';

import 'package:dungeon_master_tool/core/config/app_paths.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/repositories/character_repository.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/test_database.dart';

Character _char(String portrait) => Character(
      id: 'char-1',
      templateId: 't',
      templateName: 'PC',
      worldId: 'w1',
      entity: Entity(
        id: 'char-1',
        categorySlug: 'player_character',
        name: 'Vex',
        fields: const {},
        imagePath: portrait,
      ),
      createdAt: '',
      updatedAt: '',
    );

void main() {
  late AppDatabase db;
  late CharacterRepository repo;
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('character_portrait');
    AppPaths.dataRoot = tmp.path;
    await AppPaths.setUser(null);
    db = openTestDatabase();
    repo = CharacterRepository(db);
  });

  tearDown(() async {
    await db.close();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {
      // Windows'ta açık handle kalabiliyor.
    }
  });

  Future<String?> savedPortrait() async {
    final chars = await repo.loadAll();
    return chars.single.entity.imagePath;
  }

  test('ham portre yolu characters klasörüne alınır', () async {
    final src = File(p.join(tmp.path, 'Downloads', 'portre.png'));
    await src.create(recursive: true);
    await src.writeAsString('x');

    await repo.save(_char(src.path));

    final stored = await savedPortrait();
    expect(stored, p.join(AppPaths.charactersDir, 'char-1_portre.png'));
    expect(await File(stored!).exists(), isTrue);
  });

  test('bulut ref ve boş yol dokunulmadan kalır', () async {
    await repo.save(_char('dmt-public://x/y.png'));
    expect(await savedPortrait(), 'dmt-public://x/y.png');

    await repo.save(_char(''));
    expect(await savedPortrait(), '');
  });

  test('ikinci kayıt yeni kopya üretmez', () async {
    final src = File(p.join(tmp.path, 'Downloads', 'portre.png'));
    await src.create(recursive: true);
    await src.writeAsString('x');

    await repo.save(_char(src.path));
    final first = await savedPortrait();
    await repo.save(_char(first!));

    expect(await savedPortrait(), first);
    final files = await Directory(AppPaths.charactersDir).list().toList();
    expect(files.length, 1);
  });
}
