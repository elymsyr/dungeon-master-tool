/// Tag moderation — basit deny-list tabanlı NSFW/hate filter.
/// Global tag sistemi için yazılırken saflığı bozan içerikleri engeller.
///
/// Liste deliberately compact — kapsamlı bir çözüm için dışsal servis
/// gerekir. Bu minimum güvenlik katmanıdır: yaygın Türkçe + İngilizce
/// küfür/ırkçı/NSFW köklerini yakalar. Unicode-safe substring match.
class TagModeration {
  /// Normalize: lowercase + Turkish-specific letters + whitespace strip.
  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ğ', 'g')
        .trim();
  }

  /// Kök/substring bazlı match — "siktir" gibi variantları yakalar.
  static const List<String> _blockedRoots = [
    // Turkish profanity/slur roots
    'amk', 'ank', 'amcik', 'amcık', 'amcig',
    'sik', 'sikt', 'sike', 'siki', 'sikis',
    'orosp', 'orsp', 'piç', 'pic', 'gotver', 'gotveren',
    'ibne', 'ibn',
    // Hate-speech roots (common targets)
    'nazi', 'hitler', 'soyk',
    // English NSFW roots
    'fuck', 'shit', 'dick', 'pussy', 'cock', 'cunt',
    'nigg', 'faggot', 'retard',
    // Sexual explicit
    'porn', 'xxx', 'sex', 'nude', 'naked',
    'rape', 'rapist', 'pedo', 'pedophile', 'loli',
    // Hate
    'kill', 'murder', 'terror',
  ];

  /// Ayrıca boş/çok kısa/çok uzun tag'ları reddet.
  static const int _minLength = 2;
  static const int _maxLength = 40;

  /// Tag geçerli mi? Reason null ise valid, string ise sebep.
  static String? validate(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Empty tag';
    if (t.length < _minLength) return 'Too short (min $_minLength chars)';
    if (t.length > _maxLength) return 'Too long (max $_maxLength chars)';

    final norm = _normalize(t);
    for (final root in _blockedRoots) {
      if (norm.contains(root)) {
        return 'Inappropriate content';
      }
    }
    return null;
  }

  /// True → tag güvenli. Yaygın kısayol.
  static bool isAllowed(String raw) => validate(raw) == null;
}
