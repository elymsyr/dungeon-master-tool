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
