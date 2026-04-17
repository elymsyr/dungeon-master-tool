import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Metadata map'lerindeki cover_image_path'i cloud backup sırasında base64
/// olarak envelope'a gömüp, restore sırasında local dosyaya geri yazan
/// yardımcı. Worlds / Packages / Templates / Characters için ortak.
///
/// Beklenen schema:
///   metadata['cover_image_path'] — local file path (upload öncesi)
///   metadata['cover_image_data'] — base64 (cloud envelope)
///   metadata['cover_image_ext']  — '.png' / '.jpg'
class CoverImageBundler {
  /// Local path → base64. Upload akışı öncesi `metadata` mutate edilir.
  static Future<void> bundle(Map<String, dynamic> metadata) async {
    final path = metadata['cover_image_path'];
    if (path is! String || path.isEmpty) return;
    try {
      final file = File(path);
      if (!await file.exists()) return;
      metadata['cover_image_data'] = base64Encode(await file.readAsBytes());
      metadata['cover_image_ext'] = p.extension(path);
    } catch (_) {
      // Best-effort — cover bundling asla ana backup'ı bozmamalı.
    }
  }

  /// Base64 → local path. Restore akışında decode edilip yeni dosyaya yazılır.
  /// Başarılı olursa metadata güncellenir ve yeni path döner; yoksa null.
  static Future<String?> restore({
    required Map<String, dynamic> metadata,
    required String destDir,
    required String itemId,
  }) async {
    final b64 = metadata['cover_image_data'];
    if (b64 is! String || b64.isEmpty) return null;
    final ext = (metadata['cover_image_ext'] as String?) ?? '.png';
    try {
      final dir = Directory(destDir);
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, '${itemId}_cover$ext'));
      await file.writeAsBytes(base64Decode(b64));
      metadata.remove('cover_image_data');
      metadata.remove('cover_image_ext');
      metadata['cover_image_path'] = file.path;
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
