import '../entities/schema/world_schema.dart';

/// Campaign persistence interface.
/// Lokal: Drift (SQLite) implementasyonu.
/// Online: Supabase implementasyonu (future).
abstract class CampaignRepository {
  /// Mevcut kampanya isimlerini getir.
  Future<List<String>> getAvailable();

  /// Kampanya verisini yükle (ID veya isim ile).
  Future<Map<String, dynamic>> load(String campaignName);

  /// Kampanya verisini kaydet.
  Future<void> save(String campaignName, Map<String, dynamic> data);

  /// Row-level entity upsert. Tek satır world_entities yazımı; settings/diğer
  /// entityler dokunulmaz. F0 additive — bulk [save] hala çağrılabilir.
  Future<void> saveEntity(
    String campaignName,
    String entityId,
    Map<String, dynamic> row,
  );

  /// Row-level entity delete. Yalnız belirtilen satırı kaldırır.
  Future<void> deleteEntity(String campaignName, String entityId);

  /// world_settings.settings_json içinde verilen key'leri merge eder.
  /// Read-merge-write Drift transaction içinde; diğer key'ler korunur.
  Future<void> saveSettingsPatch(
    String campaignName,
    Map<String, dynamic> patch,
  );

  /// Granular `world_map_data` row write — yerel kalıcılık için.
  /// `settings_json` blob'una bağımlı kalmadan map_data (image_path, pins,
  /// epochs, …) app close/reopen sonrası yerel Drift'ten okunabilsin.
  Future<void> saveMapData(
    String campaignName,
    Map<String, dynamic> mapData,
  );

  /// Granular `world_sessions` rows yazımı — bir kerede birden çok session
  /// upsert (CDC catch-up + initial sync için). Var olan diğer satırları
  /// silmez; sadece verilen id'leri yazıp/günceller.
  Future<void> saveSessions(
    String campaignName,
    List<Map<String, dynamic>> sessions,
  );

  /// Tek bir session upsert — single-row CDC apply için.
  Future<void> saveSession(
    String campaignName,
    Map<String, dynamic> session,
  );

  /// Tek bir session sil — DELETE CDC için.
  Future<void> deleteSession(String campaignName, String sessionId);

  /// Kampanyayı sil (soft delete — `.trash/`'a taşır).
  Future<void> delete(String campaignName);

  /// Kampanyayı kalıcı olarak sil — trash'a taşımaz, doğrudan siler.
  /// Online world leave/kick akışı tarafından kullanılır: oyuncu cihazından
  /// world'ün lokal kopyasını anında temizler.
  Future<void> purge(String campaignName);

  /// Yeni kampanya oluştur, template ile.
  Future<String> create(String worldName, {WorldSchema? template});

  /// PR-D4: restore a soft-deleted world from `trash_items` by its trash
  /// row id. Returns false on conflict / corrupt payload.
  Future<bool> restoreFromTrash(String trashId);

  /// PR-D4: hard-delete a trash row.
  Future<void> permanentlyDelete(String trashId);
}
