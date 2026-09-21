import '../entities/schema/world_schema.dart';

/// World persistence interface.
/// Lokal: Drift (SQLite) implementasyonu.
/// Online: Supabase implementasyonu (future).
///
/// **Kimlik `worldId`'dir, isim değil.** `worldName` salt etiket: değişebilir,
/// benzersiz değil ve hiçbir şeyi anahtarlamaz. İsimle anahtarlamak çoklu
/// cihazda aynı dünyayı iki ayrı dünya gibi gösteriyordu (bir cihazda
/// "Fırtına Vadisi", ötekinde "Fırtına Vadisi (2)").
abstract class CampaignRepository {
  /// Yereldeki bütün dünyalar — (id, etiket). İsim listesi yerine çift
  /// döner: aynı adı taşıyan iki dünya artık mümkün, salt isim belirsiz.
  Future<List<({String id, String name})>> listWorlds();

  /// World verisini yükle.
  Future<Map<String, dynamic>> load(String worldId);

  /// Yalnız `metadata` bloğunu oku (cover / description / tags).
  ///
  /// [load] ile aynı sonucu verir ama entity satırlarını okumaz ve built-in
  /// SRD pack'ini sentezlemez — hub listesi world başına bunu çağırdığı için
  /// tam yükleme oradaki en büyük donma kaynağıydı. World yoksa boş map.
  Future<Map<String, dynamic>> loadMetadata(String worldId);

  /// [worldId]'ye import edilmiş paketler (id, name, version). World'ün
  /// yoksa boş döner. Yayınlanan bir world'ün marketplace kartında import
  /// edilen paketleri özetlemek için kullanılır.
  Future<List<Map<String, String>>> installedPackages(String worldId);

  /// World verisini kaydet.
  Future<void> save(String worldId, Map<String, dynamic> data);

  /// Row-level entity upsert. Tek satır world_entities yazımı; settings/diğer
  /// entityler dokunulmaz. F0 additive — bulk [save] hala çağrılabilir.
  Future<void> saveEntity(
    String worldId,
    String entityId,
    Map<String, dynamic> row,
  );

  /// Row-level entity delete. Yalnız belirtilen satırı kaldırır.
  Future<void> deleteEntity(String worldId, String entityId);

  /// world_settings.settings_json içinde verilen key'leri merge eder.
  /// Read-merge-write Drift transaction içinde; diğer key'ler korunur.
  ///
  /// [touchWorld] false ise `worlds.updated_at` / `world_settings.updated_at`
  /// ileri atılmaz — motion-class (viewport pan/zoom) yazımları için. Bunlar
  /// dünyayı "değişti" göstermemeli, yoksa hiçbir içerik düzenlemesi yapmamış
  /// bir cihaz LWW'yi kazanıp karşı taraftaki gerçek düzenlemeleri eziyor.
  Future<void> saveSettingsPatch(
    String worldId,
    Map<String, dynamic> patch, {
    bool touchWorld,
  });

  /// Granular `world_map_data` row write — yerel kalıcılık için.
  /// `settings_json` blob'una bağımlı kalmadan map_data (image_path, pins,
  /// epochs, …) app close/reopen sonrası yerel Drift'ten okunabilsin.
  Future<void> saveMapData(
    String worldId,
    Map<String, dynamic> mapData,
  );

  /// Granular `world_sessions` rows yazımı — bir kerede birden çok session
  /// upsert (CDC catch-up + initial sync için). Var olan diğer satırları
  /// silmez; sadece verilen id'leri yazıp/günceller.
  Future<void> saveSessions(
    String worldId,
    List<Map<String, dynamic>> sessions,
  );

  /// Tek bir session upsert — single-row CDC apply için.
  Future<void> saveSession(
    String worldId,
    Map<String, dynamic> session,
  );

  /// Tek bir session sil — DELETE CDC için.
  Future<void> deleteSession(String worldId, String sessionId);

  /// World'ü sil (soft delete — `.trash/`'a taşır).
  Future<void> delete(String worldId);

  /// World'ü kalıcı olarak sil — trash'a taşımaz, doğrudan siler.
  /// Online world leave/kick akışı tarafından kullanılır: oyuncu cihazından
  /// world'ün lokal kopyasını anında temizler.
  Future<void> purge(String worldId);

  /// Yeni world oluştur, template ile. **Yeni world'ün id'sini** döndürür.
  ///
  /// [worldName] yalnız etiket — aynı isimde başka bir dünya varsa yenisi
  /// yine de oluşur.
  ///
  /// [includeSrd] false ise D&D 5e template'inde built-in SRD paketi
  /// bağlanmaz ve dünya `_srdCoreOptOut` ile işaretlenir (load()'daki
  /// self-heal de bu bayrağa saygı duyar).
  Future<String> create(String worldName,
      {WorldSchema? template, bool includeSrd = true});

  /// PR-D4: restore a soft-deleted world from `trash_items` by its trash
  /// row id. Returns false on conflict / corrupt payload.
  Future<bool> restoreFromTrash(String trashId);

  /// PR-D4: hard-delete a trash row.
  Future<void> permanentlyDelete(String trashId);

  /// World'ün bir kopyasını oluştur (deep copy). **Kopyanın id'sini** döndürür.
  Future<String> copy({
    required String sourceId,
    required String destinationName,
  });

  /// World'ün etiketini değiştir. Hiçbir anahtar değişmediği için tek
  /// UPDATE: medya klasörü id ile anahtarlı, taşınmıyor.
  Future<void> renameWorld(String worldId, String newName);
}
