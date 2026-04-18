import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/schema/default_dnd5e_schema.dart';
import '../../domain/entities/schema/world_schema.dart';

final allTemplatesProvider = FutureProvider<List<WorldSchema>>((ref) async {
  return [generateDefaultDnd5eSchema()];
});
