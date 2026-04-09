import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/template_local_ds.dart';
import '../../domain/entities/schema/default_dnd5e_schema.dart';
import '../../domain/entities/schema/world_schema.dart';

/// Fixed schema id of the built-in D&D 5e template. Anything saved under
/// this id is treated as "admin edits to the default" rather than as a
/// separate custom template — so editing + saving the built-in overwrites
/// the single card on disk and there's no ghost copy in the custom list.
const builtinTemplateId = 'builtin-dnd5e-default';

final templateLocalDsProvider = Provider((_) => TemplateLocalDataSource());

/// The built-in D&D 5e template. Loads from disk if admin edits have been
/// saved; otherwise falls back to the freshly generated code default so
/// fresh installs still pick up the latest hardcoded schema.
final builtinTemplateProvider = FutureProvider<WorldSchema>((ref) async {
  final ds = ref.read(templateLocalDsProvider);
  final saved = await ds.loadById(builtinTemplateId);
  return saved ?? generateDefaultDnd5eSchema();
});

/// Custom template listesi (disk'ten). Excludes the built-in id so the
/// saved built-in template never double-appears under "custom".
final customTemplatesProvider = FutureProvider<List<WorldSchema>>((ref) async {
  final all = await ref.read(templateLocalDsProvider).loadAll();
  return all.where((s) => s.schemaId != builtinTemplateId).toList();
});

/// Tüm template'ler: built-in + custom.
final allTemplatesProvider = FutureProvider<List<WorldSchema>>((ref) async {
  final builtin = await ref.watch(builtinTemplateProvider.future);
  final custom = await ref.watch(customTemplatesProvider.future);
  return [builtin, ...custom];
});
