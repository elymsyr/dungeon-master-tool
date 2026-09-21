/// İçerik aktarımının veri sözleşmesi — saf Dart, hiçbir taşıma katmanına
/// bağlı değil.
///
/// Aynı üç tip hem LAN telinde hem `.dmtz` zip'inde geçiyor: kimlik satırı
/// ([ContentItemRef]), taşınan blob ([ContentItemPayload]) ve yanındaki medya
/// dosyaları ([ContentMediaEntry]). Bir zamanlar `lan_sync_protocol.dart`
/// içindeydiler; LAN kalkarken codec'in kalması gerektiği için buraya
/// taşındılar.
library;

// ── Item kimliği ────────────────────────────────────────────────────────

/// Senkronize edilebilir içerik türleri.
///
/// Template yok: `allTemplatesProvider` yalnız built-in şemayı döndürüyor,
/// kullanıcının taşıyabileceği bir template kaydı bulunmuyor.
enum ContentItemType { world, package, character }

ContentItemType? contentItemTypeFromWire(String s) => switch (s) {
      'world' => ContentItemType.world,
      'package' => ContentItemType.package,
      'character' => ContentItemType.character,
      _ => null,
    };

String contentItemTypeToWire(ContentItemType t) => t.name;

/// Manifest satırı: bir içeriğin kimliği + son değişme zamanı.
///
/// [updatedAt] milisaniyeye yuvarlanır — JSON round-trip'te mikrosaniye
/// farkı iki tarafın "aynı" içeriği farklı sanmasına yol açardı.
class ContentItemRef {
  ContentItemRef({
    required this.type,
    required this.id,
    required this.name,
    required DateTime updatedAt,
    DateTime? viewUpdatedAt,
    DateTime? renamedAt,
  })  : updatedAt = _toMs(updatedAt),
        viewUpdatedAt =
            viewUpdatedAt == null ? null : _toMs(viewUpdatedAt),
        renamedAt = renamedAt == null ? null : _toMs(renamedAt);

  static DateTime _toMs(DateTime t) => DateTime.fromMillisecondsSinceEpoch(
        t.toUtc().millisecondsSinceEpoch,
        isUtc: true,
      );

  final ContentItemType type;
  final String id;
  final String name;
  final DateTime updatedAt;

  /// Yalnızca world için: "o an ne açıktı" görünümünün (açık kartlar, PDF
  /// sekmeleri, sağ sidebar) son değişme anı. İçerik hiç değişmeden sadece
  /// görünüm değiştiğinde de eşleme tetiklensin diye ayrı taşınır; alıcı
  /// tarafta world satırının içerik zaman damgasını kirletmez.
  final DateTime? viewUpdatedAt;

  /// World, package ve character için: son yeniden adlandırma zamanı. Alıcı
  /// tarafta peer'ın `renamedAt`'i local'den daha yeniyse isim güncellenir.
  final DateTime? renamedAt;

  /// LWW karşılaştırmasında kullanılan zaman: içerik ve görünümün yenisi.
  DateTime get effectiveUpdatedAt =>
      (viewUpdatedAt != null && viewUpdatedAt!.isAfter(updatedAt))
          ? viewUpdatedAt!
          : updatedAt;

  String get key => '${contentItemTypeToWire(type)}:$id';

  Map<String, dynamic> toJson() => {
        'type': contentItemTypeToWire(type),
        'id': id,
        'name': name,
        'updated_at': updatedAt.toIso8601String(),
        if (viewUpdatedAt != null)
          'view_updated_at': viewUpdatedAt!.toIso8601String(),
        if (renamedAt != null) 'renamed_at': renamedAt!.toIso8601String(),
      };

  static ContentItemRef? fromJson(Map<String, dynamic> j) {
    final type = contentItemTypeFromWire('${j['type']}');
    final id = j['id'];
    if (type == null || id is! String || id.isEmpty) return null;
    final ts = DateTime.tryParse('${j['updated_at']}');
    if (ts == null) return null;
    return ContentItemRef(
      type: type,
      id: id,
      name: '${j['name'] ?? ''}',
      updatedAt: ts,
      viewUpdatedAt: j['view_updated_at'] == null
          ? null
          : DateTime.tryParse('${j['view_updated_at']}'),
      renamedAt: j['renamed_at'] == null
          ? null
          : DateTime.tryParse('${j['renamed_at']}'),
    );
  }

  @override
  String toString() => '$key(${name.isEmpty ? '-' : name}@$effectiveUpdatedAt)';
}

/// Bir item'ın medya dosyası: veri köküne göre relatif yol + içerik hash'i.
class ContentMediaEntry {
  const ContentMediaEntry({
    required this.path,
    required this.sha256,
    required this.size,
  });

  /// `AppPaths.dataRoot`'a göre relatif, POSIX ayırıcılı yol.
  final String path;
  final String sha256;
  final int size;

  Map<String, dynamic> toJson() => {
        'path': path,
        'sha256': sha256,
        'size': size,
      };

  static ContentMediaEntry? fromJson(Map<String, dynamic> j) {
    final path = j['path'];
    final sha = j['sha256'];
    if (path is! String || path.isEmpty || sha is! String) return null;
    return ContentMediaEntry(
      path: path,
      sha256: sha,
      size: (j['size'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Tel üzerinden geçen tam item: kimlik + blob + medya listesi.
///
/// [dataRoot] gönderenin `AppPaths.dataRoot`'u. Alıcı, payload içindeki
/// mutlak yollarda bu prefix'i kendi köküyle değiştirir — böylece medya
/// referansları alan adı bilmeden taşınır.
class ContentItemPayload {
  const ContentItemPayload({
    required this.ref,
    required this.payload,
    required this.dataRoot,
    this.media = const [],
    this.extras = const {},
  });

  final ContentItemRef ref;
  final Map<String, dynamic> payload;
  final String dataRoot;
  final List<ContentMediaEntry> media;

  /// `repository.load` blob'unun **dışında** kalan, ama dünyaya ait olan
  /// parçalar: paket kurulum bağlantıları ve UI görünümü (açık kartlar, açık
  /// PDF sekmeleri, sağ sidebar durumu). Blob cloud-backup kontratı olduğu
  /// için genişletilmedi; bunlar yanına ayrı bir bölüm olarak takılıyor.
  /// [dataRoot] yeniden yazımı payload ile aynı şekilde buna da uygulanır.
  final Map<String, dynamic> extras;

  Map<String, dynamic> toJson() => {
        'ref': ref.toJson(),
        'payload': payload,
        'data_root': dataRoot,
        'media': [for (final m in media) m.toJson()],
        if (extras.isNotEmpty) 'extras': extras,
      };

  static ContentItemPayload? fromJson(Map<String, dynamic> j) {
    final rawRef = j['ref'];
    final rawPayload = j['payload'];
    if (rawRef is! Map || rawPayload is! Map) return null;
    final ref = ContentItemRef.fromJson(rawRef.cast<String, dynamic>());
    if (ref == null) return null;
    final rawExtras = j['extras'];
    return ContentItemPayload(
      ref: ref,
      payload: rawPayload.cast<String, dynamic>(),
      dataRoot: '${j['data_root'] ?? ''}',
      extras: rawExtras is Map
          ? rawExtras.cast<String, dynamic>()
          : const <String, dynamic>{},
      media: [
        for (final m in (j['media'] as List? ?? const []))
          if (m is Map)
            ?ContentMediaEntry.fromJson(m.cast<String, dynamic>()),
      ],
    );
  }
}
