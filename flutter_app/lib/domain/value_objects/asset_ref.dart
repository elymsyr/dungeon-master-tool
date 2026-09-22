/// Stable cross-device reference to an image/asset.
///
/// Beş şema'lı form + ham yol aynı `String` slot'unu paylaşır (entity images, manifests,
/// kapak resimleri vb.) — local data fırsatçı olarak migrate olur:
///
/// - **Cloud (sayılan)**: `dmt-asset://{uploader_id}/{campaign_id}/{sha256}.{ext}`
///   — `AssetService.uploadAsset` çıktısı. Cloudflare R2; kullanıcının storage
///   quota'sına sayılır. R2 cache üzerinden çözülür.
/// - **Public (ücretsiz)**: `dmt-public://{uploader_id}/{sha256}.{ext}` —
///   `FreeMediaService.uploadFreeMedia` çıktısı. Supabase Storage `free-media`
///   public bucket; quota'ya SAYILMAZ (karakter portresi, world/package kapak).
/// - **Content (taşınabilir)**: `dmt-content://{sha256}.{ext}` — hiçbir
///   depolama katmanı adlandırmaz, yalnızca "şu bayt yığını". Her cihaz kendi
///   yolundan çözer: baytları yerelde olan (DM) `content_paths` yan tablosundan
///   dosyayı bulur, olmayan (oyuncu / DM'in ikinci cihazı) transient havuzdan
///   indirir. Tier adı taşımadığı için transient LRU'su ref'i öldürmez —
///   kalıcı satırda durabilen tek içerik-adresli biçim budur.
/// - **Transient (geçici)**: `dmt-transient://{sha256}.{ext}` — storage dolu
///   iken oyunculara content-addressed paylaşım. Uploader id KASITLI olarak
///   ref'te yok; oyuncu SHA ile local cache'i kontrol eder, uploader id
///   `transient_shares` realtime event'inden gelir.
/// - **First-party art**: `dmt-art://{uuid}.webp` — `tool/art_gen` üretimi,
///   built-in/resmî paketlerin kart görselleri. Önce app bundle'ında
///   (`assets/art/srd/`), yoksa R2 catalog'unda (`{worker}/catalog/art/…`,
///   public, hesap gerekmez) aranır. Hangi görselin bundle'da olduğu ref'e
///   KASITLI olarak gömülmez — bundle kapsamı değişince veri migrasyonu
///   gerekmesin diye.
/// - **Local**: mutlak filesystem path. Henüz migrate edilmemiş legacy
///   entity'ler + quota-exceeded fallback upload'ları için.
///
/// Uygulamanın çoğu raw string taşır. `AssetRef`, her call-site'ın `startsWith`
/// kontrolünü tekrar yazmaması için ince bir parser.
class AssetRef {
  AssetRef(this.raw);

  static const String scheme = 'dmt-asset://';
  static const String publicScheme = 'dmt-public://';
  static const String transientScheme = 'dmt-transient://';
  static const String contentScheme = 'dmt-content://';
  static const String artScheme = 'dmt-art://';

  final String raw;

  bool get isCloud => raw.startsWith(scheme);
  bool get isPublic => raw.startsWith(publicScheme);
  bool get isTransient => raw.startsWith(transientScheme);
  bool get isContent => raw.startsWith(contentScheme);
  bool get isArt => raw.startsWith(artScheme);

  /// Bilinen hiçbir şemaya uymayan, boş olmayan ref → local filesystem path.
  bool get isLocal =>
      raw.isNotEmpty &&
      !isCloud &&
      !isPublic &&
      !isTransient &&
      !isContent &&
      !isArt;

  /// R2 object key — `{uploader_id}/{campaign_id}/{sha256}.{ext}`.
  /// Yalnızca `dmt-asset://` ref'ler için; aksi halde null.
  String? get r2Key => isCloud ? raw.substring(scheme.length) : null;

  /// Supabase Storage object path — `{uploader_id}/{sha256}.{ext}`.
  /// Yalnızca `dmt-public://` ref'ler için; aksi halde null.
  String? get publicPath => isPublic ? raw.substring(publicScheme.length) : null;

  /// Transient ref'in SHA-256 hex'i; aksi halde null.
  String? get transientSha =>
      isTransient ? _bodyPart(transientScheme, ext: false) : null;

  /// Transient ref'in uzantısı (nokta dahil, ör. `.png`); yoksa boş string.
  String get transientExt =>
      isTransient ? _bodyPart(transientScheme, ext: true) : '';

  /// `dmt-content://` / `dmt-transient://` ref'in uzantısı (nokta dahil);
  /// diğer biçimlerde boş string. İkisi de `{sha}{ext}` gövdesi taşır.
  String get contentExt {
    if (isContent) return _bodyPart(contentScheme, ext: true);
    if (isTransient) return _bodyPart(transientScheme, ext: true);
    return '';
  }

  String _bodyPart(String scheme, {required bool ext}) {
    final body = raw.substring(scheme.length);
    final dot = body.indexOf('.');
    if (dot < 0) return ext ? '' : body;
    return ext ? body.substring(dot) : body.substring(0, dot);
  }

  /// Şema'lı ref'lerin içerik hash'i (`dmt-asset://`, `dmt-public://`,
  /// `dmt-transient://`, `dmt-content://` — hepsinde son segmentin adı
  /// sha256'dır). Local path'lerde ve hash gibi görünmeyen ref'lerde null.
  ///
  /// `ContentStore` bu sha ile adreslendiği için, ref'i çözmeden "bu asset'in
  /// baytları bende var mı" sorusunu cevaplamaya yarar (LAN sync bunu
  /// kullanıyor).
  String? get contentSha {
    final schemeEnd = raw.indexOf('://');
    if (!isCloud && !isPublic && !isTransient && !isContent) return null;
    final body = raw.substring(schemeEnd + 3);
    final lastSlash = body.lastIndexOf('/');
    final fileName = lastSlash >= 0 ? body.substring(lastSlash + 1) : body;
    final dot = fileName.indexOf('.');
    final base = dot >= 0 ? fileName.substring(0, dot) : fileName;
    return RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(base)
        ? base.toLowerCase()
        : null;
  }

  /// First-party art ref'in dosya adı (`{uuid}.webp`); aksi halde null.
  /// Bundle'da `assets/art/srd/{ad}`, R2'de `catalog/art/{ad}` olarak aranır.
  String? get artName => isArt ? raw.substring(artScheme.length) : null;

  /// Filesystem path for local refs; null for the scheme'd forms.
  String? get localPath => isLocal ? raw : null;

  /// Wrap an R2 object key into the canonical `dmt-asset://…` string.
  static String formatCloudUri(String r2Key) => '$scheme$r2Key';

  /// Wrap a Supabase Storage path into a `dmt-public://…` string.
  static String formatPublicUri(String storagePath) =>
      '$publicScheme$storagePath';

  /// `dmt-art://{uuid}.webp` string'i üretir.
  static String formatArtUri(String uuid) => '$artScheme$uuid.webp';

  /// `dmt-transient://{sha}{ext}` string'i üretir. [ext] nokta dahil (`.png`).
  static String formatTransientUri(String sha256, String ext) =>
      '$transientScheme$sha256$ext';

  /// `dmt-content://{sha}{ext}` string'i üretir. [ext] nokta dahil (`.png`).
  static String formatContentUri(String sha256, String ext) =>
      '$contentScheme$sha256$ext';

  @override
  String toString() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AssetRef && other.raw == raw);

  @override
  int get hashCode => raw.hashCode;
}
