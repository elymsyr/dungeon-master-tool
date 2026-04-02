import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/template_local_ds.dart';
import '../../domain/entities/schema/default_dnd5e_schema.dart';
import '../../domain/entities/schema/world_schema.dart';

final templateLocalDsProvider = Provider((_) => TemplateLocalDataSource());

/// Custom template listesi (disk'ten).
final customTemplatesProvider = FutureProvider<List<WorldSchema>>((ref) {
  return ref.read(templateLocalDsProvider).loadAll();
});

/// Tüm template'ler: default + custom.
final allTemplatesProvider = FutureProvider<List<WorldSchema>>((ref) async {
  final custom = await ref.watch(customTemplatesProvider.future);
  return [generateDefaultDnd5eSchema(), ...custom];
});
