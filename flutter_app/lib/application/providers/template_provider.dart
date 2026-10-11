import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/daos/user_templates_dao.dart';
import '../../data/database/database_provider.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/services/free_template.dart';
import '../services/local_media_localizer.dart';

/// Templates the built-in flows may offer: only the built-in D&D 5e schema.
/// Free templates are deliberately NOT here — the wizard, world and package
/// creation opt into [userTemplatesProvider] in their own phases
/// (docs/free-template/ROADMAP.md B3).
final allTemplatesProvider = FutureProvider<List<WorldSchema>>((ref) async {
  return [generateBuiltinDnd5eV2Schema().schema];
});

/// Alias for callers still written around the old built-in / custom split.
final customTemplatesProvider = allTemplatesProvider;

/// The user's free templates (`user_templates`), oldest first. Follows the
/// per-user database, so switching accounts reloads it.
final userTemplatesProvider =
    AsyncNotifierProvider<UserTemplatesNotifier, List<WorldSchema>>(
      UserTemplatesNotifier.new,
    );

class UserTemplatesNotifier extends AsyncNotifier<List<WorldSchema>> {
  static const _uuid = Uuid();

  UserTemplatesDao get _dao => UserTemplatesDao(ref.read(appDatabaseProvider));

  @override
  Future<List<WorldSchema>> build() async {
    final dao = UserTemplatesDao(ref.watch(appDatabaseProvider));
    final out = <WorldSchema>[];
    for (final json in await dao.allJson()) {
      try {
        out.add(WorldSchema.fromJson(jsonDecode(json) as Map<String, dynamic>));
      } catch (e) {
        // A bad row stays in the table (no data loss); it just isn't listed.
        debugPrint('user_templates: unreadable row skipped: $e');
      }
    }
    return out;
  }

  /// Copies [source] (built-in or free) as a new free template.
  Future<WorldSchema> copy(WorldSchema source, String name) =>
      _add(copyAsFreeTemplate(source, id: _uuid.v4(), name: name, now: _now()));

  /// Creates a template holding only the player card.
  Future<WorldSchema> createEmpty(
    String name, {
    required String playerCardName,
  }) => _add(
    emptyFreeTemplate(
      id: _uuid.v4(),
      name: name,
      playerCardName: playerCardName,
      now: _now(),
    ),
  );

  /// Saves the settings dialog: name, description, and the `tags` /
  /// `cover_image_path` metadata keys (the same keys worlds and packages use).
  Future<void> saveInfo(
    String id, {
    required String name,
    required String description,
    required List<String> tags,
    required String coverImagePath,
  }) async {
    final t = (await future).firstWhere((t) => t.schemaId == id);
    await save(
      t.copyWith(
        name: name,
        description: description,
        metadata: {
          ...t.metadata,
          'tags': tags,
          'cover_image_path': coverImagePath,
        },
      ),
    );
  }

  /// Stores an edited template (the editor's autosave, V26).
  Future<void> save(WorldSchema t) async {
    final current = await future;
    final saved = t.copyWith(updatedAt: _now());
    await _dao.upsert(saved.schemaId, jsonEncode(saved.toJson()));
    state = AsyncData([
      for (final x in current) x.schemaId == saved.schemaId ? saved : x,
    ]);
  }

  Future<void> delete(String id) async {
    final current = await future;
    await _dao.remove(id);
    // Its cover folder, best effort: the template is already gone, a locked
    // file must not turn that into an error. Worlds keep their own copy.
    try {
      final dir = Directory(LocalMediaLocalizer.templateDir(id));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('user_templates: cover folder of $id not removed: $e');
    }
    state = AsyncData([
      for (final x in current)
        if (x.schemaId != id) x,
    ]);
  }

  Future<WorldSchema> _add(WorldSchema t) async {
    final current = await future;
    await _dao.upsert(t.schemaId, jsonEncode(t.toJson()));
    state = AsyncData([...current, t]);
    return t;
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();
}
