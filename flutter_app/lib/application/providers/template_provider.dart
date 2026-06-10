import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_provider.dart';
import '../../data/repositories/template_repository_impl.dart';
import '../../data/templates/builtin_template_loader.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/repositories/template_repository.dart';

/// Templates offered to **world / character creation** call sites.
///
/// Still the v2 built-in embedded schema on purpose: per-world dual-stack
/// authority (roadmap §1.4) keeps new worlds on the frozen v2 engine until the
/// new resolver lands (Phase 2.4 / 3). The v3 Template library below is a
/// separate surface — editing/copying templates does not yet change what world
/// creation binds. The authority flip to v3 happens in Phase 3.11.
final allTemplatesProvider = FutureProvider<List<WorldSchema>>((ref) async {
  return [generateBuiltinDnd5eV2Schema().schema];
});

/// Alias for callers still written around the old built-in / custom split.
final customTemplatesProvider = allTemplatesProvider;

/// User-owned Template library persistence (PR-1.4). The built-in template is
/// NOT routed through here — it is the read-only asset served by
/// [BuiltinTemplateLoader].
final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => TemplateRepositoryImpl(ref.watch(appDatabaseProvider)),
);

/// The full Template library the editor / templates tab lists:
/// `[built-in asset] + user templates`, in that order. The built-in always
/// sorts first and is read-only; user copies follow, newest-edited first.
///
/// This is the v3 surface (roadmap §1.4) and is intentionally distinct from
/// [allTemplatesProvider] (which still hands the v2 schema to world creation).
final templateLibraryProvider = FutureProvider<List<WorldSchema>>((ref) async {
  final repo = ref.watch(templateRepositoryProvider);
  final builtin = await BuiltinTemplateLoader.instance.load();
  final userTemplates = await repo.listUserTemplates();
  return [builtin, ...userTemplates];
});
