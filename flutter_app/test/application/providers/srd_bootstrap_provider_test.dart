import 'dart:convert';

import 'package:drift/native.dart';
import 'package:dungeon_master_tool/application/dnd5e/bootstrap/srd_bootstrap_service.dart';
import 'package:dungeon_master_tool/application/providers/custom_effect_registry_provider.dart';
import 'package:dungeon_master_tool/application/providers/srd_bootstrap_provider.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/database/database_provider.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/custom_effect_registry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/content_hash.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/dnd5e_package.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/dnd5e_package_codec.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Dnd5ePackage _miniPkg() => Dnd5ePackage(
      id: 'srd-core-1',
      packageIdSlug: 'srd',
      name: 'D&D 5e SRD Core Rules',
      version: '1.0.0',
      authorId: 'wizards',
      authorName: 'Wizards of the Coast',
      sourceLicense: 'CC BY 4.0',
      conditions: const [
        CatalogEntry(id: 'stunned', name: 'Stunned', bodyJson: '{}'),
      ],
    );

String _monolithJson() {
  final ns = _miniPkg().namespaced();
  final env = const Dnd5ePackageCodec().encode(ns);
  env['contentHash'] = computeContentHash(ns);
  return jsonEncode(env);
}

/// Trigger provider — captures a `Ref` and exposes a callable that runs
/// [runSrdBootstrap] on demand. Lets tests fire the bootstrap multiple
/// times against the same container without re-instantiating overrides.
final _triggerProvider =
    Provider<Future<SrdBootstrapOutcome> Function()>(
        (ref) => () => runSrdBootstrap(ref));

ProviderContainer _buildContainer({
  required AppDatabase db,
  required String monolith,
}) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      srdBootstrapServiceProvider.overrideWith((ref) => SrdBootstrapService(
            db: db,
            registry: ref.watch(customEffectRegistryProvider),
            loadAsset: (_) async => monolith,
          )),
    ],
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  group('customEffectRegistryProvider', () {
    test('singleton has all 9 SRD impls registered', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final reg = c.read(customEffectRegistryProvider);
      expect(reg.contains('srd:wish'), isTrue);
      expect(reg.contains('srd:wild_shape'), isTrue);
      expect(reg.contains('srd:glyph_of_warding'), isTrue);
      expect(reg.ids.toList().length, 9);
    });

    test('returns same instance across reads', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final a = c.read(customEffectRegistryProvider);
      final b = c.read(customEffectRegistryProvider);
      expect(identical(a, b), isTrue);
    });
  });

  group('runSrdBootstrap', () {
    test('first call installs and writes outcome to state provider',
        () async {
      final c = _buildContainer(db: db, monolith: _monolithJson());
      addTearDown(c.dispose);

      expect(c.read(srdBootstrapOutcomeProvider), isNull);

      final outcome = await c.read(_triggerProvider).call();
      expect(outcome, isA<SrdBootstrapInstalled>());

      final stored = c.read(srdBootstrapOutcomeProvider);
      expect(stored, isA<SrdBootstrapInstalled>());
      expect((stored as SrdBootstrapInstalled).version, '1.0.0');

      final conds = await db.select(db.conditions).get();
      expect(conds.single.id, 'srd:stunned');
    });

    test('second call short-circuits with AlreadyInstalled', () async {
      final c = _buildContainer(db: db, monolith: _monolithJson());
      addTearDown(c.dispose);

      await c.read(_triggerProvider).call();
      final outcome = await c.read(_triggerProvider).call();

      expect(outcome, isA<SrdBootstrapAlreadyInstalled>());
      final stored = c.read(srdBootstrapOutcomeProvider);
      expect(stored, isA<SrdBootstrapAlreadyInstalled>());
    });

    test('asset failure stores SrdBootstrapError without throwing',
        () async {
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          srdBootstrapServiceProvider.overrideWith(
            (ref) => SrdBootstrapService(
              db: db,
              registry: ref.watch(customEffectRegistryProvider),
              loadAsset: (_) async => throw StateError('asset missing'),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);

      final outcome = await c.read(_triggerProvider).call();
      expect(outcome, isA<SrdBootstrapError>());

      final stored = c.read(srdBootstrapOutcomeProvider);
      expect(stored, isA<SrdBootstrapError>());
      expect((stored as SrdBootstrapError).message, contains('asset missing'));
    });
  });

  group('srdBootstrapServiceProvider', () {
    test('default wiring uses appDatabaseProvider + customEffectRegistry',
        () {
      final c = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);

      final svc = c.read(srdBootstrapServiceProvider);
      expect(svc.db, same(db));
      expect(svc.registry, isA<CustomEffectRegistry>());
      expect(svc.assetPath, defaultSrdAssetPath);
    });
  });
}
