import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/services/free_template.dart';
import 'campaign_provider.dart';
import 'character_provider.dart';
import 'entity_provider.dart';
import 'template_provider.dart';

/// [worldId]'s own schema copy (`world_settings._world_schema`), read
/// without opening the world; null when it has none or it can't be read.
Future<WorldSchema?> readWorldSchema(AppDatabase db, String worldId) async {
  final row = await db.worldSettingsDao.get(worldId);
  final raw = row?.settingsJson;
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    final schema = decoded is Map ? decoded['_world_schema'] : null;
    return schema is Map
        ? WorldSchema.fromJson(Map<String, dynamic>.from(schema))
        : null;
  } catch (_) {
    return null;
  }
}

/// The schema a free character is drawn with (docs/free-template/DESIGN.md
/// §18): its world's own copy — live when that world is open — else, for a
/// worldless character, its free template. Null for a built-in character.
final freeCharacterSchemaProvider = FutureProvider.autoDispose
    .family<WorldSchema?, ({String? worldId, String templateId})>((
      ref,
      key,
    ) async {
      final worldId = key.worldId;
      if (worldId != null) {
        final WorldSchema? schema;
        if (ref.watch(activeCampaignProvider) == worldId) {
          schema = ref.watch(worldSchemaProvider);
        } else {
          schema = await readWorldSchema(
            ref.watch(appDatabaseProvider),
            worldId,
          );
        }
        return schema != null && isFreeTemplate(schema) ? schema : null;
      }
      final templates = await ref.watch(userTemplatesProvider.future);
      return templates.where((t) => t.schemaId == key.templateId).firstOrNull;
    });

/// The open free character's reached levels by card id (DESIGN §11.8): a
/// card opened while the sheet is open marks the Level table rows its
/// character has reached. The sheet writes it and clears it on close.
final freeReachedLevelsProvider = StateProvider<Map<String, int>>(
  (_) => const {},
);

/// A blank free character on [schema] (DESIGN §10.2, D24): no wizard,
/// level 1 (D35). [worldId] null: a worldless character of the template.
Future<Character> createFreeCharacter(
  CharacterListNotifier characters, {
  required WorldSchema schema,
  required String name,
  String? worldId,
}) {
  final playerCard = freePlayerCard(schema)!;
  return characters.create(
    name: name,
    template: schema,
    worldId: worldId,
    seedFields: freeCharacterSeed(playerCard),
  );
}
