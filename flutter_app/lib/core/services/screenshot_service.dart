import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Uygulama ekran görüntüsü alma servisi.
///
/// Kullanım:
/// 1. Yakalamak istediğin widget'ı `RepaintBoundary(key: globalKey, ...)` ile sar.
/// 2. `ScreenshotService.capture(globalKey)` çağır.
class ScreenshotService {
  /// RepaintBoundary'den PNG bytes alır.
  static Future<Uint8List?> capture(GlobalKey key,
      {double pixelRatio = 2.0}) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Screenshot capture failed: $e');
      return null;
    }
  }

  /// Screenshot'ı temp dosyaya kaydeder ve path döndürür.
  static Future<String?> captureToFile(GlobalKey key,
      {double pixelRatio = 2.0}) async {
    final bytes = await capture(key, pixelRatio: pixelRatio);
    if (bytes == null) return null;
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File(p.join(tempDir.path,
          'dmt_bugreport_${DateTime.now().millisecondsSinceEpoch}.png'));
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('Screenshot file write failed: $e');
      return null;
    }
  }
}
