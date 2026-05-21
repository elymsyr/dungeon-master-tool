/// Stable cross-device reference to an image/asset.
///
/// Dört somut form aynı `String` slot'unu paylaşır (entity images, manifests,
/// kapak resimleri vb.) — local data fırsatçı olarak migrate olur:
///
/// - **Cloud (sayılan)**: `dmt-asset://{uploader_id}/{campaign_id}/{sha256}.{ext}`
///   — `AssetService.uploadAsset` çıktısı. Cloudflare R2; kullanıcının storage
///   quota'sına sayılır. R2 cache üzerinden çözülür.
/// - **Public (ücretsiz)**: `dmt-public://{uploader_id}/{sha256}.{ext}` —
///   `FreeMediaService.uploadFreeMedia` çıktısı. Supabase Storage `free-media`
///   public bucket; quota'ya SAYILMAZ (karakter portresi, world/package kapak).
/// - **Transient (geçici)**: `dmt-transient://{sha256}.{ext}` — storage dolu
///   iken oyunculara content-addressed paylaşım. Uploader id KASITLI olarak
///   ref'te yok; oyuncu SHA ile local cache'i kontrol eder, uploader id
///   `transient_shares` realtime event'inden gelir.
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

  final String raw;

  bool get isCloud => raw.startsWith(scheme);
  bool get isPublic => raw.startsWith(publicScheme);
  bool get isTransient => raw.startsWith(transientScheme);

  /// Bilinen hiçbir şemaya uymayan, boş olmayan ref → local filesystem path.
  bool get isLocal => raw.isNotEmpty && !isCloud && !isPublic && !isTransient;

  /// R2 object key — `{uploader_id}/{campaign_id}/{sha256}.{ext}`.
  /// Yalnızca `dmt-asset://` ref'ler için; aksi halde null.
  String? get r2Key => isCloud ? raw.substring(scheme.length) : null;

  /// Supabase Storage object path — `{uploader_id}/{sha256}.{ext}`.
  /// Yalnızca `dmt-public://` ref'ler için; aksi halde null.
  String? get publicPath => isPublic ? raw.substring(publicScheme.length) : null;

  /// Transient ref'in SHA-256 hex'i; aksi halde null.
  String? get transientSha {
    if (!isTransient) return null;
    final body = raw.substring(transientScheme.length);
    final dot = body.indexOf('.');
    return dot >= 0 ? body.substring(0, dot) : body;
  }

  /// Transient ref'in uzantısı (nokta dahil, ör. `.png`); yoksa boş string.
  String get transientExt {
    if (!isTransient) return '';
    final body = raw.substring(transientScheme.length);
    final dot = body.indexOf('.');
    return dot >= 0 ? body.substring(dot) : '';
  }

  /// Filesystem path for local refs; null for the scheme'd forms.
  String? get localPath => isLocal ? raw : null;

  /// Wrap an R2 object key into the canonical `dmt-asset://…` string.
  static String formatCloudUri(String r2Key) => '$scheme$r2Key';

  /// Wrap a Supabase Storage path into a `dmt-public://…` string.
  static String formatPublicUri(String storagePath) =>
      '$publicScheme$storagePath';

  /// `dmt-transient://{sha}{ext}` string'i üretir. [ext] nokta dahil (`.png`).
  static String formatTransientUri(String sha256, String ext) =>
      '$transientScheme$sha256$ext';

  @override
  String toString() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AssetRef && other.raw == raw);

  @override
  int get hashCode => raw.hashCode;
}
