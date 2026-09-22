import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../../domain/value_objects/asset_ref.dart';

/// `dmt-content://{sha}{ext}` ile bu cihazdaki özgün dosya arasındaki köprü.
///
/// Ref tier adı taşımaz ("şu baytlar, her neredeyse"), dolayısıyla onu çözmek
/// her cihazda farklı bir iş: baytları yerelde olan DM dosyayı diskinde bulur,
/// olmayan (oyuncu ya da DM'in ikinci cihazı) transient havuzdan indirir. Bu
/// sınıf birinci yolu kurar — `content_paths` yan tablosu sha ↔ yol eşlemesini
/// kalıcı tutar.
///
/// Neden bellekte değil: eşleme oturumdan uzun yaşamak zorunda. Kalıcı
/// satırdaki bir ref uygulama yeniden başladıktan sonra da çözülebilmeli,
/// yoksa DM kendi kartının resmini göremez hâle gelir.
///
/// Neden [ReferenceGraph] / `asset_refs` değil: o graf ham yolları **kasten**
/// indekslemiyor (`ReferenceIndexer._isAssetRef` yalnızca `dmt-*` şemalarını
/// alır; silinen bir yol false-orphan üretirdi). Orada yerel dosya diye bir
/// satır hiç yok.
class ContentRefIndex {
  ContentRefIndex(this._db);

  /// Tembel erişim: provider gövdesinde DB açmak, veritabanı hiç kurulmayan
  /// alt-izolatlarda (player sub-window) çözücüyü patlatırdı.
  final AppDatabase Function() _db;

  /// [localPath] için `dmt-content://{sha}{ext}` üretir ve eşlemeyi kaydeder.
  /// Dosya okunamıyorsa null.
  Future<String?> refFor(String localPath) async {
    final sha = await shaFor(localPath);
    if (sha == null) return null;
    return AssetRef.formatContentUri(
      sha,
      p.extension(localPath).toLowerCase(),
    );
  }

  /// [localPath]'in sha256'sı. Tabloda size+mtime'ı tutan bir satır varsa
  /// dosya yeniden hash'lenmez. Okunamıyorsa null.
  Future<String?> shaFor(String localPath) async {
    final stat = await _statOf(localPath);
    if (stat == null) return null;

    final cached = await _rowsWhere('path = ?', [localPath]);
    for (final row in cached) {
      if (row.matches(stat)) return row.sha;
    }
    // Yol aynı, baytlar değişmiş — eski satır artık yanlış eşleme.
    if (cached.isNotEmpty) await _forget('path = ?', [localPath]);

    final sha = await shaOfFile(localPath);
    if (sha == null) return null;
    await _remember(sha, localPath, stat);
    return sha;
  }

  /// [sha]'nın baytlarını taşıyan yerel dosya; yoksa null.
  ///
  /// Satır bayatlamış olabilir (dosya silinmiş ya da üzerine yazılmış), o
  /// yüzden her okumada size+mtime doğrulanır — doğrulamayan satır atılır.
  /// Aksi halde oyuncuya YANLIŞ baytlar servis edilirdi.
  Future<File?> fileForSha(String sha) async {
    if (sha.length != 64) return null;
    final rows = await _rowsWhere('sha = ?', [sha.toLowerCase()]);
    for (final row in rows) {
      final stat = await _statOf(row.path);
      if (stat != null && row.matches(stat)) return File(row.path);
      await _forget('sha = ? AND path = ?', [row.sha, row.path]);
    }
    return null;
  }

  /// Eşlemeyi elle kaydet — sha'yı zaten hesaplamış çağıranlar için.
  Future<void> remember(String sha, String localPath) async =>
      _remember(sha, localPath, await _statOf(localPath));

  Future<void> _remember(String sha, String localPath, _Stat? stat) async {
    final s = stat;
    if (s == null) return;
    try {
      await _db().customStatement(
        'INSERT INTO content_paths (sha, path, size, mtime, updated_at) '
        'VALUES (?, ?, ?, ?, ?) ON CONFLICT(sha, path) DO UPDATE SET '
        'size = excluded.size, mtime = excluded.mtime, '
        'updated_at = excluded.updated_at',
        [
          sha.toLowerCase(),
          localPath,
          s.size,
          s.mtime,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
    } catch (e) {
      debugPrint('ContentRefIndex.remember($sha): $e');
    }
  }

  Future<List<_Row>> _rowsWhere(String where, List<Object?> args) async {
    try {
      final rows = await _db().customSelect(
        'SELECT sha, path, size, mtime FROM content_paths WHERE $where',
        variables: [for (final a in args) Variable<String>(a as String)],
      ).get();
      return [
        for (final r in rows)
          _Row(
            sha: r.read<String>('sha'),
            path: r.read<String>('path'),
            size: r.read<int>('size'),
            mtime: r.read<int>('mtime'),
          ),
      ];
    } catch (e) {
      debugPrint('ContentRefIndex query failed: $e');
      return const [];
    }
  }

  Future<void> _forget(String where, List<Object?> args) async {
    try {
      await _db().customStatement(
        'DELETE FROM content_paths WHERE $where',
        args,
      );
    } catch (e) {
      debugPrint('ContentRefIndex._forget: $e');
    }
  }

  Future<_Stat?> _statOf(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final stat = await file.stat();
      return _Stat(stat.size, stat.modified.millisecondsSinceEpoch);
    } catch (_) {
      return null;
    }
  }
}

class _Stat {
  const _Stat(this.size, this.mtime);
  final int size;
  final int mtime;
}

class _Row {
  const _Row({
    required this.sha,
    required this.path,
    required this.size,
    required this.mtime,
  });

  final String sha;
  final String path;
  final int size;
  final int mtime;

  bool matches(_Stat stat) => size == stat.size && mtime == stat.mtime;
}

/// Dosyanın sha256 hex'i; okunamıyorsa null. Akış üzerinden hash'lenir —
/// 100 MB'lık bir handout belleğe alınmasın.
Future<String?> shaOfFile(String path) async {
  final file = File(path);
  try {
    if (!await file.exists()) return null;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  } catch (_) {
    return null;
  }
}

final contentRefIndexProvider = Provider<ContentRefIndex>(
  (ref) => ContentRefIndex(() => ref.read(appDatabaseProvider)),
);
