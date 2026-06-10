import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/entities/schema/builtin/builtin_dnd5e_template_v3.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/entities/schema/world_schema_hash.dart';

/// Loads the built-in D&D 5e v3 template from its bundled JSON asset
/// (`assets/templates/dnd5e_srd.template.json`, [builtinDnd5eTemplateAssetPath])
/// and caches it for the session.
///
/// The built-in template is an ASSET, not a `templates`-table row
/// (the-template-system §5.1): `allTemplatesProvider` will become
/// `[builtin] + tableRows` once the library lands (PR-1.4). This loader is the
/// asset side of that pair.
///
/// **Hash-equality guard (debug-only).** When the asset is present, the loader
/// asserts in debug builds that the asset's `computeWorldSchemaContentHash`
/// equals the in-code generator's ([generateBuiltinDnd5eTemplateV3]). The
/// exporter and the generator share one source of truth, so a mismatch means
/// the committed asset is stale — the developer forgot to re-run
/// `dart run tool/export_builtin_template.dart` after editing the schema (or a
/// Phase 3 wave). Release builds skip the check (the generator may be deleted
/// in a later PR once the asset is authoritative).
///
/// **Graceful fallback.** If the asset is absent (e.g. the exporter has not yet
/// been run to materialize it in a fresh checkout), the loader falls back to
/// the generator so the app still functions. In debug this logs a loud hint to
/// run the exporter; in release it is silent.
///
/// NOTE (PR-1.3 scope): this loader is wired into the app's template call sites
/// in PR-1.4 (library) / PR-2.x. It ships now as the asset-loading scaffold so
/// the exporter, asset, and runtime contract are all in place and reviewable.
class BuiltinTemplateLoader {
  BuiltinTemplateLoader._();

  /// Process-wide singleton — the built-in template is immutable for the
  /// session, so one cached parse is reused everywhere.
  static final BuiltinTemplateLoader instance = BuiltinTemplateLoader._();

  WorldSchema? _cached;
  Future<WorldSchema>? _inFlight;

  /// Returns the built-in v3 template, loading + parsing the asset on first
  /// call and caching the result. Concurrent callers share a single in-flight
  /// load (no duplicate asset reads / parses).
  Future<WorldSchema> load() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _inFlight ??= _load().then((schema) {
      _cached = schema;
      _inFlight = null;
      return schema;
    });
  }

  /// Synchronously returns the cached template if already loaded, else null.
  /// For call sites that must stay sync (the generator remains the source of
  /// truth there until they are migrated to the async [load]).
  WorldSchema? get cachedOrNull => _cached;

  /// Clears the cache — for tests / hot-reload of the asset.
  @visibleForTesting
  void resetCache() {
    _cached = null;
    _inFlight = null;
  }

  Future<WorldSchema> _load() async {
    final raw = await _tryLoadAsset();
    if (raw == null) {
      // Asset not bundled yet — fall back to the in-code generator so the app
      // keeps working. The exporter materializes the asset in a Flutter env.
      if (kDebugMode) {
        debugPrint(
          '[BuiltinTemplateLoader] $builtinDnd5eTemplateAssetPath not found in '
          'the asset bundle — falling back to generateBuiltinDnd5eTemplateV3(). '
          'Run `dart run tool/export_builtin_template.dart` to materialize the '
          'asset and remove this fallback.',
        );
      }
      return generateBuiltinDnd5eTemplateV3();
    }

    final schema = WorldSchema.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );

    assert(() {
      final assetHash = computeWorldSchemaContentHash(schema);
      final generatorHash =
          computeWorldSchemaContentHash(generateBuiltinDnd5eTemplateV3());
      if (assetHash != generatorHash) {
        throw FlutterError(
          'Built-in template asset is STALE.\n'
          '  asset    : $assetHash\n'
          '  generator: $generatorHash\n'
          'Re-run `dart run tool/export_builtin_template.dart` to regenerate '
          '$builtinDnd5eTemplateAssetPath.',
        );
      }
      return true;
    }());

    return schema;
  }

  Future<String?> _tryLoadAsset() async {
    try {
      return await rootBundle.loadString(builtinDnd5eTemplateAssetPath);
    } catch (_) {
      // Not in the bundle (not yet exported, or excluded build) — caller falls
      // back to the generator.
      return null;
    }
  }
}
