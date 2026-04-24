import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/template_local_ds.dart';
import '../../domain/entities/schema/world_schema.dart';

final templateLocalDsProvider = Provider((_) => TemplateLocalDataSource());

/// All templates on disk. Sorted by name.
final allTemplatesProvider = FutureProvider<List<WorldSchema>>((ref) async {
  return ref.read(templateLocalDsProvider).loadAll();
});

/// Alias for callers still written around the old built-in / custom split.
/// Custom = all — there is no longer a code-shipped built-in template.
final customTemplatesProvider = allTemplatesProvider;

/// Aktif açık template — TemplateEditorScreen'de set edilir, save/sync
/// provider'ları bunu campaign/package ile aynı hizada kullanır.
/// state = schemaId (veya null), data = serialize edilmiş WorldSchema.
class ActiveTemplateNotifier extends StateNotifier<String?> {
  final TemplateLocalDataSource _ds;
  ActiveTemplateNotifier(this._ds) : super(null);

  WorldSchema? _schema;
  WorldSchema? get schema => _schema;
  Map<String, dynamic>? get data => _schema?.toJson();

  /// TemplateEditorScreen açıldığında çağrılır.
  void open(WorldSchema schema) {
    _schema = schema;
    state = schema.schemaId;
  }

  /// Dışarıdan şema güncellenince senkron tut.
  void update(WorldSchema schema) {
    _schema = schema;
    state = schema.schemaId;
  }

  /// Editor kapandığında çağrılır. Widget dispose() içinden çağrılabildiği
  /// için state mutation'ı microtask'a ertele — finalizeTree sırasında
  /// provider modify Riverpod tarafından yasaklı.
  void close() {
    _schema = null;
    Future.microtask(() {
      if (mounted) state = null;
    });
  }

  /// Cloud sync için: aktif template varsa disk'e save et.
  Future<void> save() async {
    if (_schema != null) {
      await _ds.save(_schema!);
    }
  }

  /// Cloud restore: local şemayı indirilen data ile değiştir.
  Future<void> replaceWithData(Map<String, dynamic> newData) async {
    final restored = WorldSchema.fromJson(newData);
    _schema = restored;
    state = restored.schemaId;
    await _ds.save(restored);
  }
}

final activeTemplateProvider =
    StateNotifierProvider<ActiveTemplateNotifier, String?>((ref) {
  return ActiveTemplateNotifier(ref.watch(templateLocalDsProvider));
});
