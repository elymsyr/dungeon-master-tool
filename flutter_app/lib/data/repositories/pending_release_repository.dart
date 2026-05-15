import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';

/// `{charactersDir}/.pending_releases.json` üzerinde tutulan ID listesi.
/// Offline char tab "Release" akışı: server'a `release_character` çağrısı
/// yapılamadığında ID buraya eklenir, kullanıcı online olunca
/// `CharacterListNotifier.drainPendingReleases` çağırarak server'a iletir.
class PendingReleaseRepository {
  static const _fileName = '.pending_releases.json';

  String _filePath() => p.join(AppPaths.charactersDir, _fileName);

  Future<List<String>> load() async {
    final file = File(_filePath());
    if (!await file.exists()) return const [];
    try {
      final text = await file.readAsString();
      if (text.trim().isEmpty) return const [];
      final decoded = jsonDecode(text);
      if (decoded is! List) return const [];
      return decoded.whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeAtomic(List<String> ids) async {
    final dir = Directory(AppPaths.charactersDir);
    await dir.create(recursive: true);
    final tmp = File(p.join(dir.path, '$_fileName.tmp'));
    await tmp.writeAsString(jsonEncode(ids));
    await tmp.rename(_filePath());
  }

  Future<void> add(String id) async {
    final ids = await load();
    if (ids.contains(id)) return;
    await _writeAtomic([...ids, id]);
  }

  Future<void> remove(String id) async {
    final ids = await load();
    if (!ids.contains(id)) return;
    await _writeAtomic(ids.where((x) => x != id).toList());
  }

  Future<void> clear() async {
    final file = File(_filePath());
    if (await file.exists()) await file.delete();
  }
}
