/// Faz 4/5 — ayna tablosu bildirimleri. Bkz. `cloud_push_service.dart`
/// (giden yön) ve `cloud_pull_service.dart` (gelen yön).
library;

/// Yerel Drift tablosu ↔ bulut ayna tablosu eşlemesi — push ve pull'un
/// **ortak** bildirimi.
///
/// Tek bir liste iki yönü de tarif ediyor: `CloudPushService` soldan sağa,
/// `CloudPullService` sağdan sola okuyor. İki ayrı harita tutmak, birine kolon
/// eklenip ötekine unutulduğunda sessizce veri kaybettiren tam da o hata.
class MirrorTable {
  const MirrorTable(
    this.local,
    this.cloud, {
    required this.cols,
    this.dateCols = const ['updated_at'],
    this.mediaCols = const [],
    this.boolCols = const [],
    this.jsonCols = const [],
    this.rename = const {},
    this.scope = 'world_id',
    this.owner = MirrorOwner.own,
    this.sinceAll = false,
    this.key = const ['id'],
  });

  final String local;
  final String cloud;
  final List<String> cols;
  final List<String> dateCols;

  /// Yerel yol taşıyabilen kolonlar — gönderilirken içerik ref'ine çevrilir.
  final List<String> mediaCols;

  /// SQLite'ta 0/1 int, Postgres'te `boolean` olan kolonlar.
  final List<String> boolCols;

  /// Yerelde TEXT, bulutta `jsonb` olan kolonlar.
  final List<String> jsonCols;

  /// Yerel kolon adı → bulut kolon adı; ikisi ayrıştığında.
  final Map<String, String> rename;

  /// Taramanın kapsam kolonu: dünya tablolarında `world_id`, paket
  /// çocuklarında `package_id`, paketin kendi satırında `id`.
  final String scope;

  /// `owner_id` nereden geliyor.
  final MirrorOwner owner;

  /// Damga yok sayılsın mı — FK hedefi olan tek satırlık ebeveyn tablo.
  final bool sinceAll;

  /// Yerel birincil anahtar. Pull gelen satırı bununla buluyor: çoğu tabloda
  /// `id`, 1:1 tablolarda `world_id`, `installed_packages`'ta bileşik.
  final List<String> key;
}

/// `owner_id` kolonunun kaynağı.
enum MirrorOwner {
  /// Yerel satırda zaten var, ya da bulut tablosunda kolon yok.
  own,

  /// Buluta NULL yazılır — mind map'te "DM'in nüshası" demek.
  nul,

  /// Oturumdaki kullanıcı.
  self,
}

/// Bulut tablosu → yerel tablo. Tombstone'un yalan söyleyip söylemediğini
/// (satır geri geldi mi) sormak için gerekiyor.
final Map<String, String> localTableOf = {
  for (final t in mirrorTables) t.cloud: t.local,
  for (final t in packageTables) t.cloud: t.local,
  'world_combatants': 'combatants',
};

/// Paketin ayna tabloları (§2.2 BÖLÜM D). Ebeveyn **önce** gider: çocukların
/// FK'sı `user_packages`'a bakıyor.
const List<MirrorTable> packageTables = [
  MirrorTable(
    'packages',
    'user_packages',
    cols: ['id', 'name', 'state_json'],
    dateCols: ['created_at', 'updated_at'],
    mediaCols: ['state_json'],
    scope: 'id',
    owner: MirrorOwner.self,
    sinceAll: true,
  ),
  MirrorTable(
    'package_schemas',
    'user_package_schemas',
    cols: [
      'id', 'package_id', 'name', 'version', 'base_system', 'description',
      'categories_json', 'encounter_config_json', 'encounter_layouts_json',
      'metadata_json', 'template_id', 'template_hash',
      'template_original_hash',
    ],
    dateCols: ['created_at', 'updated_at'],
    scope: 'package_id',
    owner: MirrorOwner.self,
  ),
  MirrorTable(
    'package_entities',
    'user_package_entities',
    cols: [
      'id', 'package_id', 'category_slug', 'name', 'source', 'description',
      'image_path', 'images_json', 'tags_json', 'dm_notes', 'pdfs_json',
      'location_id', 'fields_json',
    ],
    dateCols: ['created_at', 'updated_at'],
    mediaCols: ['image_path', 'images_json', 'fields_json'],
    scope: 'package_id',
    owner: MirrorOwner.self,
  ),
];

const List<MirrorTable> mirrorTables = [
  MirrorTable(
    'world_entities',
    'world_entities',
    cols: [
      'id', 'world_id', 'category_slug', 'name', 'source', 'description',
      'image_path', 'images_json', 'tags_json', 'dm_notes', 'pdfs_json',
      'location_id', 'fields_json', 'package_id', 'package_entity_id',
      'linked',
    ],
    dateCols: ['created_at', 'updated_at'],
    mediaCols: ['image_path', 'images_json', 'fields_json'],
    boolCols: ['linked'],
  ),
  MirrorTable('world_settings', 'world_settings',
      cols: ['world_id', 'settings_json'],
      mediaCols: ['settings_json'],
      key: ['world_id']),
  MirrorTable('world_map_data', 'world_map_data',
      cols: ['world_id', 'data_json'],
      mediaCols: ['data_json'],
      key: ['world_id']),
  MirrorTable('world_sessions', 'world_sessions',
      cols: ['id', 'world_id', 'name', 'data_json', 'is_active', 'sort_order'],
      mediaCols: ['data_json'],
      boolCols: ['is_active']),
  MirrorTable(
    'world_mind_map_nodes',
    'world_mind_map_nodes',
    cols: [
      'id', 'world_id', 'map_id', 'label', 'node_type', 'x', 'y', 'width',
      'height', 'entity_id', 'image_url', 'content', 'style_json', 'color',
    ],
    mediaCols: ['image_url'],
    owner: MirrorOwner.nul,
  ),
  MirrorTable(
    'world_mind_map_edges',
    'world_mind_map_edges',
    cols: ['id', 'world_id', 'map_id', 'source_id', 'target_id', 'label',
        'style_json'],
    owner: MirrorOwner.nul,
  ),
  MirrorTable(
    'encounters',
    'world_encounters',
    cols: [
      'id', 'world_id', 'session_id', 'name', 'map_path', 'token_size',
      'grid_size', 'grid_visible', 'grid_snap', 'feet_per_cell', 'fog_data',
      'annotation_data', 'encounter_layout_id', 'turn_index', 'round',
      'token_positions_json', 'token_size_multipliers_json', 'sort_order',
    ],
    dateCols: ['created_at', 'updated_at'],
    mediaCols: ['map_path'],
    boolCols: ['grid_visible', 'grid_snap'],
  ),
  MirrorTable('map_pins', 'world_map_pins',
      cols: ['id', 'world_id', 'x', 'y', 'label', 'pin_type', 'entity_id',
          'note', 'color', 'style_json']),
  MirrorTable('timeline_pins', 'world_timeline_pins',
      cols: ['id', 'world_id', 'x', 'y', 'day', 'note', 'entity_ids_json',
          'session_id', 'parent_ids_json', 'color']),
  // Karakterler: bugün `WorldMirrorService.pushCharacter` anında yazıyor,
  // ama o yol tek atış — çevrimdışı yapılan düzenleme buluta hiç çıkmıyordu.
  // Tur bunu kapatıyor; iki yol da aynı satıra idempotent upsert yapıyor.
  // `payload_json` **medya çevirisine girmiyor**: blob'un byte-for-byte
  // korunması kuralı (world_characters_dao) jsonDecode/encode turundan ağır
  // basıyor; karakter görselleri bugünkü gibi mutlak yolla gidiyor.
  MirrorTable(
    'world_characters',
    'world_characters',
    cols: [
      'id', 'world_id', 'owner_id', 'template_id', 'template_name',
      'payload_json', 'referenced_entity_ids_json',
    ],
    dateCols: ['created_at', 'updated_at'],
    jsonCols: ['referenced_entity_ids_json'],
    rename: {'referenced_entity_ids_json': 'referenced_entity_ids'},
  ),
  MirrorTable('installed_packages', 'world_installed_packages',
      cols: ['world_id', 'package_id', 'package_name', 'package_version'],
      dateCols: ['installed_at', 'last_synced_at', 'updated_at'],
      key: ['world_id', 'package_id']),
];
