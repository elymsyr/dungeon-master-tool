import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dungeon_master_tool/application/providers/installed_packages_provider.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<void> seed({
    required String id,
    required String name,
    String version = '1.0.0',
    String authorName = 'Author',
    String sourceLicense = 'CC BY 4.0',
    String? description,
  }) async {
    await db.into(db.installedPackages).insert(
          InstalledPackagesCompanion.insert(
            id: id,
            sourcePackageId: 'src-$id',
            packageIdSlug: id,
            name: name,
            version: version,
            gameSystemId: 'dnd5e',
            authorName: Value(authorName),
            sourceLicense: Value(sourceLicense),
            description: Value(description),
          ),
        );
  }

  test('returns empty list when no packages installed', () async {
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);

    final rows = await c.read(installedAttributionsProvider.future);
    expect(rows, isEmpty);
  });

  test('returns rows sorted by name with attribution fields populated',
      () async {
    await seed(
      id: 'srd',
      name: 'SRD Core',
      authorName: 'Wizards of the Coast',
      sourceLicense: 'CC BY 4.0',
      description: 'SRD content.',
    );
    await seed(
      id: 'homebrew',
      name: 'Aurora Homebrew',
      authorName: 'Aurora',
      sourceLicense: 'MIT',
      description: null,
    );

    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);

    final rows = await c.read(installedAttributionsProvider.future);
    expect(rows.map((r) => r.name).toList(),
        ['Aurora Homebrew', 'SRD Core']);

    final srd = rows.firstWhere((r) => r.packageIdSlug == 'srd');
    expect(srd.authorName, 'Wizards of the Coast');
    expect(srd.sourceLicense, 'CC BY 4.0');
    expect(srd.description, 'SRD content.');

    final hb = rows.firstWhere((r) => r.packageIdSlug == 'homebrew');
    expect(hb.description, isNull);
  });
}
