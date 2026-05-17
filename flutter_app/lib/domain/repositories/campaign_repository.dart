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
