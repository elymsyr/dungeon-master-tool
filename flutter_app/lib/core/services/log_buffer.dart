import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Debug çıktılarını ring buffer'da tutar — bug report'ta kullanılır.
///
/// Kullanım:
/// 1. main.dart'ta `LogBuffer.install()` çağır.
/// 2. Tüm `debugPrint` çıktıları otomatik buffer'a yazılır.
/// 3. Bug report dialog'ta `LogBuffer.instance.dump()` ile son N satırı al.
class LogBuffer {
  LogBuffer._();

  static final LogBuffer instance = LogBuffer._();

  /// Buffer'da tutulacak max satır sayısı.
  static const int maxLines = 500;
  final Queue<String> _lines = Queue<String>();
  DebugPrintCallback? _originalDebugPrint;

  /// Global debugPrint'i override eder. main.dart'ta runApp'ten önce çağrılmalı.
  static void install() {
    final inst = LogBuffer.instance;
    if (inst._originalDebugPrint != null) return; // already installed
    inst._originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        inst._add(message);
      }
      // Orijinal davranışı koru (console'a yazsın)
      inst._originalDebugPrint!(message, wrapWidth: wrapWidth);
    };
  }

  /// Hata/exception kaydı (FlutterError.onError ve runZonedGuarded için).
  void recordError(Object error, StackTrace? stack, {String? context}) {
    final ts = DateTime.now().toIso8601String();
    _add('[$ts] ERROR${context != null ? ' ($context)' : ''}: $error');
    if (stack != null) {
      final stackStr = stack.toString();
      // Stack'i de buffer'a ekle (uzun olabilir, satır satır)
      for (final line in stackStr.split('\n').take(20)) {
        _add('  $line');
      }
    }
  }

  void _add(String message) {
    // Çok uzun satırları kırp
    final trimmed = message.length > 500 ? '${message.substring(0, 500)}…' : message;
    _lines.addLast(trimmed);
    while (_lines.length > maxLines) {
      _lines.removeFirst();
    }
  }

  /// Tüm buffer'ı string olarak döndürür.
  String dump() => _lines.join('\n');

  /// Buffer'ı temizle.
  void clear() => _lines.clear();

  /// Son N satırı al.
  String tail(int n) {
    if (_lines.length <= n) return dump();
    return _lines.toList().sublist(_lines.length - n).join('\n');
  }
}
