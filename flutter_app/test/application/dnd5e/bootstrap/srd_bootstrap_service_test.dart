import 'dart:convert';

import 'package:drift/native.dart';
import 'package:dungeon_master_tool/application/dnd5e/bootstrap/srd_bootstrap_service.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/custom_effect_registry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/content_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/content_hash.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/dnd5e_package.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/dnd5e_package_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _assetPath = 'assets/packages/srd_core.dnd5e-pkg.json';
const _flag = defaultSrdInstalledVersionFlag;

Dnd5ePackage _miniPkg({String version = '1.0.0'}) => Dnd5ePackage(
      id: 'srd-core-1',
      packageIdSlug: 'srd',
      name: 'D&D 5e SRD Core Rules',
      version: version,
      authorId: 'wizards',
      authorName: 'Wizards of the Coast',
      sourceLicense: 'CC BY 4.0',
      conditions: const [
        CatalogEntry(id: 'stunned', name: 'Stunned', bodyJson: '{}'),
      ],
      damageTypes: const [
        CatalogEntry(id: 'fire', name: 'Fire', bodyJson: '{}'),
      ],
      spellSchools: const [
        CatalogEntry(id: 'evocation', name: 'Evocation', bodyJson: '{}'),
      ],
      spells: const [
        SpellEntry(
          id: 'fireball',
          name: 'Fireball',
          level: 3,
          schoolId: 'evocation',
          bodyJson: '{}',
        ),
      ],
    );

String _monolithJson(Dnd5ePackage pkg, {String? overrideHash}) {
  final namespaced = pkg.namespaced();
  final envelope = const Dnd5ePackageCodec().encode(namespaced);
  envelope['contentHash'] = overrideHash ?? computeContentHash(namespaced);
  return jsonEncode(envelope);
}

Future<String> _loader(String json) async => json;

void main() {
  late AppDatabase db;
  late CustomEffectRegistry registry;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    registry = CustomEffectRegistry();
  });

  tearDown(() async => db.close());

  SrdBootstrapService build(String json) => SrdBootstrapService(
        db: db,
        registry: registry,
        assetPath: _assetPath,
        loadAsset: (_) => _loader(json),
      );

  group('SrdBootstrapService.runIfNeeded', () {
    test('first launch: installs and stamps version flag', () async {
      final pkg = _miniPkg();
      final out = await build(_monolithJson(pkg)).runIfNeeded();

      expect(out, isA<SrdBootstrapInstalled>());
      final installed = out as SrdBootstrapInstalled;
      expect(installed.version, '1.0.0');
      expect(installed.report.count('conditions'), 1);
      expect(installed.report.count('spells'), 1);
      expect(installed.contentHash, startsWith('sha256:'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_flag), '1.0.0');

      final conds = await db.select(db.conditions).get();
      expect(conds.single.id, 'srd:stunned');
      final spells = await db.select(db.spells).get();
      expect(spells.single.id, 'srd:fireball');
    });

    test('second launch with same version short-circuits', () async {
      final pkg = _miniPkg();
      final json = _monolithJson(pkg);
      await build(json).runIfNeeded();

      final out = await build(json).runIfNeeded();
      expect(out, isA<SrdBootstrapAlreadyInstalled>());
      expect((out as SrdBootstrapAlreadyInstalled).version, '1.0.0');
    });

    test('version bump re-runs the importer', () async {
      await build(_monolithJson(_miniPkg(version: '1.0.0'))).runIfNeeded();
      final out =
          await build(_monolithJson(_miniPkg(version: '1.1.0'))).runIfNeeded();

      expect(out, isA<SrdBootstrapInstalled>());
      expect((out as SrdBootstrapInstalled).version, '1.1.0');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_flag), '1.1.0');
    });

    test('content-hash mismatch fails import and leaves flag unset', () async {
      final json =
          _monolithJson(_miniPkg(), overrideHash: 'sha256:tampered');
      final out = await build(json).runIfNeeded();

      expect(out, isA<SrdBootstrapError>());
      expect((out as SrdBootstrapError).message,
          contains('Content hash mismatch'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_flag), isNull);
    });

    test('asset load failure surfaces as SrdBootstrapError', () async {
      final svc = SrdBootstrapService(
        db: db,
        registry: registry,
        assetPath: _assetPath,
        loadAsset: (_) async => throw StateError('asset missing'),
      );
      final out = await svc.runIfNeeded();
      expect(out, isA<SrdBootstrapError>());
      expect((out as SrdBootstrapError).message, contains('asset missing'));
    });

    test('malformed JSON surfaces as SrdBootstrapError', () async {
      final out = await build('not valid json').runIfNeeded();
      expect(out, isA<SrdBootstrapError>());
    });

    test('outcome.summary is human-readable for all variants', () {
      const a = SrdBootstrapAlreadyInstalled('1.0.0');
      expect(a.summary, contains('1.0.0'));
      const e = SrdBootstrapError('boom');
      expect(e.summary, contains('boom'));
    });
  });
}
