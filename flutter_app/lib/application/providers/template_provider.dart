import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/world_schema.dart';

/// All templates available in the app. Read-only — only the built-in
/// D&D 5e schema ships now. Templates are no longer user-editable.
final allTemplatesProvider = FutureProvider<List<WorldSchema>>((ref) async {
  return [generateBuiltinDnd5eV2Schema().schema];
});

/// Alias for callers still written around the old built-in / custom split.
final customTemplatesProvider = allTemplatesProvider;
