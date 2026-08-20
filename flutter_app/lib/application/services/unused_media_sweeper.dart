import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import 'local_media_localizer.dart';

/// Dünyanın `media/` ve `files/` klasörlerinde **hiçbir yerden referans
/// verilmeyen** dosyaları siler.
///
/// Neden gerekli: [LocalMediaLocalizer] seçilen her dosyayı dünyanın kendi
/// klasörüne kopyalıyor, ama resmi kaldırma yolları (`cleanupMapImageRef`,
/// `cleanupRemovedEntityImageRef`) yalnız **bulut** nesnesini siliyor —
/// yereldeki kopya sahipsiz kalıyordu. Üstelik LAN eşlemesi dünya klasörünün
/// tamamını taşıdığı için o çöp her cihaza gidip orada da kalıyordu.
///
/// Neden silme anında değil de süpürge: `AssetImporter` ad + boyut ile dedupe
/// ediyor, yani aynı dosyayı iki yere koyduğunda **tek kopya** paylaşılıyor.
/// Silme anında silmek diğer referansı kırardı. Süpürge bütün ağacı gördüğü
/// için bu sorunu yaşamıyor ve daha önce birikmiş çöpü de temizliyor.
///
/// Üç güvenlik katmanı:
///   1. Yalnız [_sweptSubDirs] altına dokunulur — kullanıcının kendi
///      orijinal dosyasına ya da `pdfs/` kütüphanesine asla.
///   2. Çöp kutusundaki (`trash_items`) payload'lar da referans sayılır;
///      silinen bir entity geri alındığında resmi yerinde duruyor.
///   3. [graceWindow] içinde değiştirilmiş dosyalar atlanır — yeni gelmiş ama
///      henüz payload'a yazılmamış bir dosya (LAN eşlemesi, bekleyen debounce
///      yazımı) yanlışlıkla silinmesin.
class UnusedMediaSweeper {
  UnusedMediaSweeper(this._db);

  final AppDatabase _db;

  /// Bu süre içinde değiştirilmiş dosyalara dokunulmaz.
  static const Duration graceWindow = Duration(minutes: 10);

  /// Süpürülen alt klasörler — ikisi de tamamen [LocalMediaLocalizer]
  /// tarafından üretiliyor, içlerinde kullanıcının orijinal dosyası olmaz.
  static const List<String> _sweptSubDirs = [
    LocalMediaLocalizer.mediaSubDir,
    LocalMediaLocalizer.filesSubDir,
  ];

  /// [payload] verilen dünyanın süpürülmesi. Silinen dosya sayısını döndürür.
  ///
  /// Çağırmadan önce bekleyen yazımlar boşaltılmalı ([PendingWriteBuffer]),
  /// yoksa henüz diske inmemiş bir seçim referanssız görünür.
  Future<int> sweepWorld({
    required String worldName,
    required Map<String, dynamic> payload,
  }) async {
    if (worldName.isEmpty) return 0;
    try {
      final referenced = <String>{};
      _collect(payload, referenced);
      await _collectTrash(referenced);

      final now = DateTime.now();
      var removed = 0;
      for (final subDir in _sweptSubDirs) {
        final dir = Directory(
          p.join(LocalMediaLocalizer.worldDir(worldName), subDir),
        );
        if (!await dir.exists()) continue;
        await for (final entry in dir.list(recursive: true)) {
          if (entry is! File) continue;
          if (referenced.contains(p.canonicalize(entry.path))) continue;
          if (now.difference(await entry.lastModified()) < graceWindow) {
            continue;
          }
          try {
            await entry.delete();
            removed++;
          } catch (e) {
            debugPrint('UnusedMediaSweeper delete ${entry.path}: $e');
          }
        }
      }
      if (removed > 0) {
        debugPrint('UnusedMediaSweeper: $worldName — $removed dosya silindi');
      }
      return removed;
    } catch (e, st) {
      // Best-effort: süpürge hiçbir zaman dünya açılışını/kapanışını bozmasın.
      debugPrint('UnusedMediaSweeper error: $e\n$st');
      return 0;
    }
  }

  /// Çöp kutusundaki her şey referans sayılır — hangi dünyaya ait olduğuna
  /// bakmadan, çünkü snapshot'lar serbest JSON ve kayıt küçük.
  Future<void> _collectTrash(Set<String> out) async {
    for (final kind in const ['entity', 'character', 'world', 'package']) {
      for (final row in await _db.trashDao.getByKind(kind)) {
        _collectJsonString(row.payloadJson, out);
      }
    }
  }

  void _collectJsonString(String raw, Set<String> out) {
    // Payload'ı decode etmeye gerek yok: yol string'leri JSON içinde de
    // aynen duruyor, tek fark kaçış karakterleri. Ters bölü çiftlerini
    // düzeltip ham metni tarıyoruz — false positive zararsız (dosya
    // korunur), false negative tehlikeli olurdu.
    _collect(raw.replaceAll(r'\\', r'\'), out);
  }

  void _collect(Object? node, Set<String> out) {
    if (node is String) {
      if (node.isEmpty) return;
      // JSON gövdesi tek parça geldiğinde yolu içinden ayıklayamayız; bu
      // yüzden hem tam string'i hem de tırnak içindeki parçaları ekliyoruz.
      for (final piece in node.split('"')) {
        final trimmed = piece.trim();
        if (trimmed.isEmpty || !p.isAbsolute(trimmed)) continue;
        out.add(p.canonicalize(trimmed));
      }
      return;
    }
    if (node is Map) {
      for (final v in node.values) {
        _collect(v, out);
      }
      return;
    }
    if (node is List) {
      for (final v in node) {
        _collect(v, out);
      }
    }
  }
}

final unusedMediaSweeperProvider = Provider<UnusedMediaSweeper>(
  (ref) => UnusedMediaSweeper(ref.watch(appDatabaseProvider)),
);
