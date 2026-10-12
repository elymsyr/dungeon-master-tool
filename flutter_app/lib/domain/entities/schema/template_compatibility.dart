/// Template uyumluluk seviyesi.
enum CompatibilityLevel {
  /// Birebir aynı template — doğrudan import.
  perfect,

  /// Uyumlu ama farklılıklar var — uyarı ile import.
  compatible,

  /// Uyumsuz — import yapılamaz.
  incompatible,
}

/// İki template arasındaki uyumluluk sonucu.
class TemplateCompatibility {
  final CompatibilityLevel level;

  /// İnsan okunabilir değişiklik listesi (computeWorldSchemaDiff çıktısı).
  final List<String> warnings;

  /// Dünyada var ama pakette yok — import sonrası default değer alacak.
  final List<String> addedFields;

  /// Pakette var ama dünyada yok — import sırasında atlanacak.
  final List<String> removedFields;

  /// Dünyada var ama pakette yok kategoriler.
  final List<String> addedCategories;

  /// Pakette var ama dünyada yok kategoriler.
  final List<String> removedCategories;

  /// Free template eşleştirmesi (DESIGN §15.2, D11): kategori slug'la, alan
  /// anahtarla eşleşti. Eşleşmeyen varsa kurmadan önce sorulur; veri pakette
  /// kalır, sadece bu dünyada görünmez.
  final bool byKey;

  const TemplateCompatibility({
    required this.level,
    this.byKey = false,
    this.warnings = const [],
    this.addedFields = const [],
    this.removedFields = const [],
    this.addedCategories = const [],
    this.removedCategories = const [],
  });
}
