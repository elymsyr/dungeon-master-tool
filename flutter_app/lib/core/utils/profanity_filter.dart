/// Çoklu dil küfür filtresi. Sözcük listeleri Shutterstock'un
/// [LDNOOBW](https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words)
/// projesinden gelir; `assets/profanity/<lang>.txt` altında bundlanır
/// ve ilk kullanımda lazy yüklenir. Uygulamanın aktif diline bakılmaksızın
/// tüm diller aynı anda taranır.
///
/// Kullanım:
///   await ProfanityFilter.ensureLoaded();
///   if (ProfanityFilter.contains(text)) { ... }
library;

import 'package:flutter/services.dart' show rootBundle;

class ProfanityRejectedException implements Exception {
  final String message;
  const ProfanityRejectedException([
    this.message = 'Postunuz uygunsuz dil içerdiği için gönderilemedi.',
  ]);
  @override
  String toString() => message;
}

class ProfanityFilter {
  static const String rejectionMessage =
      'Postunuz uygunsuz dil içerdiği için gönderilemedi.';

  /// LDNOOBW asset dosya isimleri (uzantısız diller `<lang>.txt` olarak
  /// renamelendi). Yeni dil için sadece `assets/profanity/` altına dosya
  /// koy + bu listeye ekle.
  static const List<String> _languages = [
    'ar', 'cs', 'da', 'de', 'en', 'eo', 'es', 'fa', 'fi', 'fil',
    'fr', 'hi', 'hu', 'it', 'ja', 'kab', 'ko', 'nl', 'no', 'pl',
    'pt', 'ru', 'sv', 'th', 'tr', 'zh',
  ];

  static Set<String>? _wordSet;
  static Set<String>? _phraseSet;
  static Future<void>? _loading;

  /// Asset listelerini bir kez okur ve cache'ler. Tekrar çağrı no-op.
  static Future<void> ensureLoaded() async {
    if (_wordSet != null) return;
    _loading ??= _load();
    return _loading;
  }

  static Future<void> _load() async {
    final words = <String>{};
    final phrases = <String>{};
    for (final lang in _languages) {
      try {
        final raw = await rootBundle.loadString('assets/profanity/$lang.txt');
        for (final line in raw.split('\n')) {
          final entry = line.trim().toLowerCase();
          if (entry.isEmpty || entry.startsWith('#')) continue;
          if (entry.contains(' ')) {
            phrases.add(entry);
          } else {
            words.add(entry);
          }
        }
      } catch (_) {
        // Asset bulunamazsa o dil sessizce atlanır.
      }
    }
    _wordSet = words;
    _phraseSet = phrases;
  }

  /// Leet → harf normalizasyonu (4→a, 0→o, 1→i, 3→e, 5→s, 7→t, @→a, $→s).
  static String _normalize(String input) {
    final lower = input.toLowerCase();
    final buf = StringBuffer();
    for (final r in lower.runes) {
      switch (r) {
        case 0x40: // @
          buf.write('a');
          break;
        case 0x24: // $
          buf.write('s');
          break;
        case 0x30: // 0
          buf.write('o');
          break;
        case 0x31: // 1
          buf.write('i');
          break;
        case 0x33: // 3
          buf.write('e');
          break;
        case 0x34: // 4
          buf.write('a');
          break;
        case 0x35: // 5
          buf.write('s');
          break;
        case 0x37: // 7
          buf.write('t');
          break;
        default:
          buf.writeCharCode(r);
      }
    }
    return buf.toString();
  }

  static final RegExp _wordRe = RegExp(r"[\p{L}\p{N}_]+", unicode: true);

  /// Metinde küfür var mı? `ensureLoaded()` çağrılmadıysa filtre boş kabul
  /// edilir (false döner) — submit'ten önce mutlaka load edilmeli.
  static bool contains(String text) {
    if (text.isEmpty) return false;
    final words = _wordSet;
    final phrases = _phraseSet;
    if (words == null) return false;

    for (final s in [text.toLowerCase(), _normalize(text)]) {
      // Tek-kelime eşleşme: whole-word, scunthorpe-safe.
      for (final m in _wordRe.allMatches(s)) {
        if (words.contains(m.group(0))) return true;
      }
      // Çoklu-kelime ifadeler: substring olarak ara.
      if (phrases != null && phrases.isNotEmpty) {
        for (final phrase in phrases) {
          if (s.contains(phrase)) return true;
        }
      }
    }
    return false;
  }

  /// Bulunan ilk küfürlü token'ı döner; temizse null. Test/diagnostik için.
  static String? firstHit(String text) {
    if (text.isEmpty) return null;
    final words = _wordSet;
    final phrases = _phraseSet;
    if (words == null) return null;
    for (final s in [text.toLowerCase(), _normalize(text)]) {
      for (final m in _wordRe.allMatches(s)) {
        if (words.contains(m.group(0))) return m.group(0);
      }
      if (phrases != null) {
        for (final phrase in phrases) {
          if (s.contains(phrase)) return phrase;
        }
      }
    }
    return null;
  }
}
