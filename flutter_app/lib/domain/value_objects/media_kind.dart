/// Bir medya öğesinin mantıksal türü — depolama hedefini (ücretsiz Supabase
/// Storage vs sayılan Cloudflare R2) ve per-öğe boyut limitini belirler.
///
/// Tek doğruluk kaynağı: hem client pre-check hem Cloudflare Worker ([wireName]
/// `X-Asset-Kind` header'ı üzerinden) aynı limitleri uygular. Worker'daki
/// `KIND_MAX_BYTES` map'i bu enum ile senkron tutulmalıdır.
library;

const int _kLimit4mb = 4 * 1024 * 1024;
const int _kLimit5mb = 5 * 1024 * 1024;
const int _kLimit10mb = 10 * 1024 * 1024;
const int _kLimit20mb = 20 * 1024 * 1024;

enum MediaKind {
  /// Karakterin ana portresi (`entity.imagePath`). Ücretsiz — quota'ya sayılmaz.
  characterPortrait(
    counted: false,
    maxBytes: _kLimit4mb,
    wireName: 'character_portrait',
  ),

  /// Online dünya kapak/kart resmi. Ücretsiz — quota'ya sayılmaz.
  worldCover(
    counted: false,
    maxBytes: _kLimit4mb,
    wireName: 'world_cover',
  ),

  /// Online package kapak/kart resmi. Ücretsiz — quota'ya sayılmaz.
  packageCover(
    counted: false,
    maxBytes: _kLimit4mb,
    wireName: 'package_cover',
  ),

  /// Dünya entity kartına atanan resim. Dünya medyasında (Faz 5d) harita
  /// olmayan her dosyanın sınıfı — `world_media_max_bytes` ile aynı sayı.
  worldEntityImage(
    counted: true,
    maxBytes: _kLimit5mb,
    wireName: 'world_entity_image',
  ),

  /// Package entity kartına atanan resim. Quota'ya sayılır.
  packageEntityImage(
    counted: true,
    maxBytes: _kLimit5mb,
    wireName: 'package_entity_image',
  ),

  /// Karakterin portre dışındaki ek resimleri (`entity.images[]`). Sayılır.
  characterExtraImage(
    counted: true,
    maxBytes: _kLimit5mb,
    wireName: 'character_extra_image',
  ),

  /// Battle map arkaplan resmi. Dünya medyasında (Faz 5d) dünya haritası ve
  /// savaş haritası bu sınıfta. Quota'ya sayılır.
  battleMap(
    counted: true,
    maxBytes: _kLimit10mb,
    wireName: 'battle_map',
  ),

  /// Mind map node resmi (kendi veya katılınan dünyada). Quota'ya sayılır.
  mindMapImage(
    counted: true,
    maxBytes: _kLimit5mb,
    wireName: 'mind_map_image',
  ),

  /// Dünyadaki ses dosyası (Faz 5d dünya medyası).
  worldAudio(
    counted: true,
    maxBytes: _kLimit10mb,
    wireName: 'world_audio',
  ),

  /// Dünyanın PDF kütüphanesindeki bir doküman; world online yapıldığında
  /// oyuncularla paylaşılır. 20 MB — tüm kind'lar içindeki en yüksek tavan.
  worldPdf(
    counted: true,
    maxBytes: _kLimit20mb,
    wireName: 'world_pdf',
  );

  const MediaKind({
    required this.counted,
    required this.maxBytes,
    required this.wireName,
  });

  /// `true` → Cloudflare R2 (`AssetService`); kullanıcının storage quota'sından
  /// düşülür. `false` → Supabase Storage `free-media` bucket
  /// (`FreeMediaService`); quota'ya sayılmaz.
  final bool counted;

  /// Per-öğe upload boyut limiti (byte) — upload'ın tek yetkili sınırı.
  /// Worker `KIND_MAX_BYTES` map'i bu değerlerle senkron tutulmalıdır.
  final int maxBytes;

  /// `X-Asset-Kind` HTTP header'ında, `free_media_assets.kind` kolonunda ve
  /// Worker `KIND_MAX_BYTES` map'inde kullanılan stabil string.
  final String wireName;

  /// [wireName]'den `MediaKind` çözer; bilinmeyen değer için `null`.
  static MediaKind? fromWireName(String name) {
    for (final kind in MediaKind.values) {
      if (kind.wireName == name) return kind;
    }
    return null;
  }
}
