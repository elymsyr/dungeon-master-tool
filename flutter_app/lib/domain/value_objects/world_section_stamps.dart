/// Dünyanın **bölüm bazlı** son-değişim damgaları.
///
/// Neden: LAN eşlemesi item (dünya) seviyesinde last-write-wins çalışıyordu;
/// aynı dünya iki cihazda düzenlendiğinde kazanan tarafın payload'ı diğerini
/// tamamen eziyordu (A'da savaş notu, B'de mindmap → biri kayboluyor).
/// Bölüm damgaları sayesinde `mergeWorldPayloads` her bölümü ayrı ayrı
/// karşılaştırıp ikisini de koruyabiliyor.
///
/// Damgaların kaynağı:
/// - `entities` / `sessions` / `mapData` → ilgili Drift tablolarının kendi
///   `updated_at` sütunları (zaten vardı).
/// - `settings` → `world_settings.settings_json` **içindeki** üst anahtarların
///   ([kSectionStampsKey] altında tutulan) damgaları. Blob'un içinde
///   durdukları için şema migration'ı gerektirmiyor ve payload ile
///   kendiliğinden taşınıyorlar.
library;

/// `settings_json` içinde bölüm damgalarının tutulduğu ayrılmış anahtar.
/// Alt çizgi öneki UI'ın bunu bir ayar zannetmemesi için.
const String kSectionStampsKey = '_section_updated_at';

/// [settings] blob'unda [keys] anahtarlarını [at] (varsayılan: şimdi) ile
/// damgalar. Blob'u yerinde günceller.
void stampSections(
  Map<String, dynamic> settings,
  Iterable<String> keys, {
  DateTime? at,
}) {
  final stamp = (at ?? DateTime.now()).toUtc().toIso8601String();
  final current = Map<String, dynamic>.from(
    settings[kSectionStampsKey] as Map? ?? const <String, dynamic>{},
  );
  for (final key in keys) {
    if (key == kSectionStampsKey) continue;
    current[key] = stamp;
  }
  settings[kSectionStampsKey] = current;
}

/// [settings] blob'undaki damga haritasını okur. Bozuk/eksik girdiler atlanır.
Map<String, DateTime> readSectionStamps(Map<String, dynamic> settings) =>
    _parseStampMap(settings[kSectionStampsKey]);

Map<String, DateTime> _parseStampMap(Object? raw) {
  if (raw is! Map) return const {};
  final out = <String, DateTime>{};
  raw.forEach((key, value) {
    final ts = _parseStamp(value);
    if (ts != null) out['$key'] = ts;
  });
  return out;
}

DateTime? _parseStamp(Object? value) {
  if (value is DateTime) return value.toUtc();
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}

/// Bir dünyanın bütün bölüm damgaları — LAN `extras` ile tel üzerinden taşınır.
class WorldSectionStamps {
  const WorldSectionStamps({
    this.entities = const {},
    this.sessions = const {},
    this.mapData,
    this.settings = const {},
  });

  /// Damga taşımayan taraf (eski sürüm eş, ya da hiç damgalanmamış dünya).
  /// Bu durumda `mergeWorldPayloads` item seviyesindeki `updatedAt`'e düşer.
  static const WorldSectionStamps empty = WorldSectionStamps();

  /// entityId → son değişim.
  final Map<String, DateTime> entities;

  /// sessionId → son değişim.
  final Map<String, DateTime> sessions;

  /// `world_map_data` satırının damgası.
  final DateTime? mapData;

  /// `settings_json` üst anahtarı → son değişim.
  final Map<String, DateTime> settings;

  bool get isEmpty =>
      entities.isEmpty &&
      sessions.isEmpty &&
      settings.isEmpty &&
      mapData == null;

  Map<String, dynamic> toJson() => {
        'entities': {
          for (final e in entities.entries) e.key: e.value.toIso8601String(),
        },
        'sessions': {
          for (final e in sessions.entries) e.key: e.value.toIso8601String(),
        },
        if (mapData != null) 'map_data': mapData!.toIso8601String(),
        'settings': {
          for (final e in settings.entries) e.key: e.value.toIso8601String(),
        },
      };

  factory WorldSectionStamps.fromJson(Object? json) {
    if (json is! Map) return empty;
    return WorldSectionStamps(
      entities: _parseStampMap(json['entities']),
      sessions: _parseStampMap(json['sessions']),
      mapData: _parseStamp(json['map_data']),
      settings: _parseStampMap(json['settings']),
    );
  }
}
