import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/database_provider.dart';
import '../../data/datasources/local/custom_template_store.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/world_schema.dart';

final customTemplateStoreProvider = Provider<CustomTemplateStore>(
  (ref) => CustomTemplateStore(ref.watch(appDatabaseProvider)),
);

/// Uygulamadaki tüm template'ler: built-in (koddan, read-only) + kullanıcının
/// `custom_templates` tablosundaki kopyaları/yarattıkları.
///
/// **Built-in dışındaki hiçbir template'te otomatik mekanik çalışmaz** —
/// bkz. `templateIdHasMechanics`.
final allTemplatesProvider = FutureProvider<List<WorldSchema>>((ref) async {
  final custom = await ref.watch(customTemplateStoreProvider).list();
  return [generateBuiltinDnd5eV2Schema().schema, ...custom];
});

/// Yalnız kullanıcı template'leri — düzenlenebilir olanlar.
final customTemplatesProvider = FutureProvider<List<WorldSchema>>(
  (ref) => ref.watch(customTemplateStoreProvider).list(),
);

/// Template kütüphanesi yazma işlemleri. Hepsi `allTemplatesProvider`'ı
/// invalidate eder; UI otomatik tazelenir.
class TemplateLibrary {
  TemplateLibrary(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  CustomTemplateStore get _store => _ref.read(customTemplateStoreProvider);

  void _invalidate() {
    _ref.invalidate(customTemplatesProvider);
    _ref.invalidate(allTemplatesProvider);
  }

  /// Boş template — tek bir başlangıç kategorisi ile.
  Future<WorldSchema> createBlank(String name) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final schemaId = 'custom-${_uuid.v4()}';
    final schema = WorldSchema(
      schemaId: schemaId,
      name: name,
      description: '',
      categories: [
        EntityCategorySchema(
          categoryId: _uuid.v4(),
          schemaId: schemaId,
          name: 'Notes',
          slug: 'notes',
          color: '#808080',
          allowedInSections: const ['mindmap', 'worldmap'],
          createdAt: now,
          updatedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    await _store.upsert(schema);
    _invalidate();
    return schema;
  }

  /// [source]'un düzenlenebilir kopyası. Built-in'in kopyası da alınabilir —
  /// ama kopya **mekaniksizdir**: yeni `schemaId` built-in'inki değildir.
  Future<WorldSchema> copyFrom(WorldSchema source, String name) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final schemaId = 'custom-${_uuid.v4()}';
    final copy = source.copyWith(
      schemaId: schemaId,
      name: name,
      categories: [
        for (final c in source.categories) c.copyWith(schemaId: schemaId),
      ],
      // Yeni soy: lineage kırılır, drift kontrolü kaynak template'e bağlanmaz.
      originalHash: null,
      createdAt: now,
      updatedAt: now,
    );
    await _store.upsert(copy);
    _invalidate();
    return copy;
  }

  Future<void> save(WorldSchema schema) async {
    await _store.upsert(schema.copyWith(
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    ));
    _invalidate();
  }

  Future<void> rename(WorldSchema schema, String name) =>
      save(schema.copyWith(name: name));

  Future<void> delete(String schemaId) async {
    await _store.delete(schemaId);
    _invalidate();
  }
}

final templateLibraryProvider =
    Provider<TemplateLibrary>((ref) => TemplateLibrary(ref));
