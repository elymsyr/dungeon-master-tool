import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/datasources/local/template_local_ds.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../config/app_paths.dart';
import '../services/log_buffer.dart';

/// Writes the v2 built-in D&D 5e template to the active templates cache
/// so it appears in the template list. Re-seeds when the on-disk version
/// is older than the bundled generator's version (so field additions ship
/// to existing installs without manual deletion).
///
/// Designed to run on every cold launch AND after every user-session
/// activation, since [AppPaths.setUser] switches [AppPaths.cacheDir] to
/// a per-user directory that may not yet contain the template.
///
/// Returns true if a fresh template file was written, false otherwise.
Future<bool> seedBuiltinDnd5eV2TemplateIfNeeded() async {
  try {
    return await _writeTemplateIfStale();
  } catch (e, st) {
    LogBuffer.instance.recordError(e, st, context: 'seedBuiltinDnd5eV2');
    return false;
  }
}

Future<bool> _writeTemplateIfStale() async {
  final targetDir = Directory(p.join(AppPaths.cacheDir, 'templates'));
  await targetDir.create(recursive: true);
  final targetFile = File(p.join(targetDir.path, '$builtinDnd5eV2SchemaId.json'));

  final build = generateBuiltinDnd5eV2Schema();

  if (await targetFile.exists()) {
    final onDisk = _readVersion(targetFile);
    if (onDisk != null &&
        _compareVersions(onDisk, build.schema.version) >= 0) {
      return false;
    }
  }

  await TemplateLocalDataSource().save(build.schema);
  return true;
}

String? _readVersion(File f) {
  try {
    final raw = f.readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final v = json['version'];
    return v is String ? v : null;
  } catch (_) {
    return null;
  }
}

/// Returns negative if [a] < [b], 0 if equal, positive if [a] > [b].
/// Compares numeric segments (e.g. "2.1.0" vs "2.0.5"); non-numeric
/// segments are treated as 0.
int _compareVersions(String a, String b) {
  final ap = a.split('.');
  final bp = b.split('.');
  final n = ap.length > bp.length ? ap.length : bp.length;
  for (var i = 0; i < n; i++) {
    final ai = i < ap.length ? int.tryParse(ap[i]) ?? 0 : 0;
    final bi = i < bp.length ? int.tryParse(bp[i]) ?? 0 : 0;
    if (ai != bi) return ai - bi;
  }
  return 0;
}
