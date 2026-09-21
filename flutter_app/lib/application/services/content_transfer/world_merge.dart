import '../../../core/utils/deep_copy.dart';
import '../../../domain/value_objects/world_section_stamps.dart';

/// Bir dünyanın iki kopyasını **bölüm bazında** birleştirir.
///
/// Neden gerekli: eşleme daha önce item seviyesinde last-write-wins'ti —
/// `_applyWorld` gelen payload'ı olduğu gibi `save()` ediyor, `_saveToDb` de
/// entity'leri silip yeniden yazıyordu. A cihazında savaş notu, B cihazında
/// mindmap düzenlendiyse yalnız biri hayatta kalıyor, diğerinin işi tamamen
/// siliniyordu. Burada her bölüm kendi damgasıyla ayrı yarışıyor, böylece iki
/// tarafın düzenlemesi de korunuyor.
///
/// Fonksiyon **saf**: I/O yok, girdileri mutate etmez, aynı girdi için hep
/// aynı çıktıyı verir. Determinizm bir gereklilik — iki cihaz da aynı
/// birleştirmeyi bağımsız çalıştırıp aynı sonuca yakınsıyor.
///
/// Damgası olmayan taraf (eski sürüm eş ya da hiç damgalanmamış bölüm) için
/// ilgili `*Fallback` — dünyanın item seviyesindeki `updatedAt`'i —
/// kullanılır; o durumda davranış eski tam-değiştirme mantığına düşer.
///
/// **Bilinçli sınır:** tombstone yok, dolayısıyla silmeler yayılmaz. A'da
/// silinmiş bir entity'yi B hâlâ tutuyorsa birleşimde geri gelir. Veri
/// kaybetmemeyi hayalet satıra tercih ediyoruz.
Map<String, dynamic> mergeWorldPayloads({
  required Map<String, dynamic> local,
  required Map<String, dynamic> remote,
  required WorldSectionStamps localStamps,
  required WorldSectionStamps remoteStamps,
  required DateTime localFallback,
  required DateTime remoteFallback,
}) {
  final remoteWinsItem = remoteFallback.isAfter(localFallback);
  // Item seviyesi taban: hangi taraf genel olarak yeniyse onun kopyası.
  // Şema / template gibi bölüm damgası olmayan alanlar buradan geliyor;
  // bölüm bazlı kararlar bunun üzerine yazılıyor.
  final out =
      deepCopyJson(remoteWinsItem ? remote : local) as Map<String, dynamic>;

  // -- entities ------------------------------------------------------------
  final localEntities = _mapOf(local['entities']);
  final remoteEntities = _mapOf(remote['entities']);
  if (local.containsKey('entities') || remote.containsKey('entities')) {
    final merged = <String, dynamic>{};
    for (final id in {...localEntities.keys, ...remoteEntities.keys}) {
      final hasLocal = localEntities.containsKey(id);
      final hasRemote = remoteEntities.containsKey(id);
      if (!hasRemote) {
        merged[id] = deepCopyJson(localEntities[id]);
      } else if (!hasLocal) {
        merged[id] = deepCopyJson(remoteEntities[id]);
      } else {
        final pickRemote = _remoteWins(
          localStamps.entities[id] ?? localFallback,
          remoteStamps.entities[id] ?? remoteFallback,
        );
        merged[id] =
            deepCopyJson(pickRemote ? remoteEntities[id] : localEntities[id]);
      }
    }
    out['entities'] = merged;
  }

  // -- sessions ------------------------------------------------------------
  if (local.containsKey('sessions') || remote.containsKey('sessions')) {
    out['sessions'] = _mergeSessions(
      localList: _listOf(local['sessions']),
      remoteList: _listOf(remote['sessions']),
      localStamps: localStamps,
      remoteStamps: remoteStamps,
      localFallback: localFallback,
      remoteFallback: remoteFallback,
    );
  }

  // -- map_data ------------------------------------------------------------
  if (local.containsKey('map_data') || remote.containsKey('map_data')) {
    final hasLocal = local['map_data'] != null;
    final hasRemote = remote['map_data'] != null;
    final pickRemote = hasLocal && hasRemote
        ? _remoteWins(
            localStamps.mapData ?? localFallback,
            remoteStamps.mapData ?? remoteFallback,
          )
        : hasRemote;
    out['map_data'] =
        deepCopyJson(pickRemote ? remote['map_data'] : local['map_data']);
  }

  // -- settings üst anahtarları (combat_state, mind_maps, map_view, ...) ----
  final stampsOut = <String, dynamic>{};
  for (final key in {...local.keys, ...remote.keys}) {
    if (_nonSettingsKeys.contains(key) || key == kSectionStampsKey) continue;
    final hasLocal = local.containsKey(key);
    final hasRemote = remote.containsKey(key);
    final localTs = localStamps.settings[key];
    final remoteTs = remoteStamps.settings[key];

    final bool pickRemote;
    if (!hasRemote) {
      pickRemote = false;
    } else if (!hasLocal) {
      pickRemote = true;
    } else {
      pickRemote =
          _remoteWins(localTs ?? localFallback, remoteTs ?? remoteFallback);
    }

    out[key] = deepCopyJson(pickRemote ? remote[key] : local[key]);
    final winnerTs = pickRemote ? remoteTs : localTs;
    if (winnerTs != null) stampsOut[key] = winnerTs.toIso8601String();
  }
  if (stampsOut.isNotEmpty) out[kSectionStampsKey] = stampsOut;

  // -- kimlik alanları -----------------------------------------------------
  // `world_id` çağıran tarafından sabitleniyor; `created_at`'te en eski
  // kazanır ki dünya "yeni oluşturulmuş" görünmesin.
  final createdAt = _oldest(local['created_at'], remote['created_at']);
  if (createdAt != null) out['created_at'] = createdAt;

  return out;
}

/// Birleştirme sonrası bölüm damgaları — çağıran bunları granüler tablolara
/// geri yazar. Yazmazsa bulk `save()` bütün satırları `now()` damgalar ve
/// "hangi cihaz neyi düzenledi" bilgisi silinir.
WorldSectionStamps mergeSectionStamps({
  required WorldSectionStamps local,
  required WorldSectionStamps remote,
}) =>
    WorldSectionStamps(
      entities: _laterOf(local.entities, remote.entities),
      sessions: _laterOf(local.sessions, remote.sessions),
      mapData: _laterNullable(local.mapData, remote.mapData),
      settings: _laterOf(local.settings, remote.settings),
    );

/// Bir dünya payload'ında settings blob'una **ait olmayan** üst anahtarlar:
/// ya kendi tipli tablosunda duruyorlar ya da yukarıda ayrıca ele alınıyorlar.
const _nonSettingsKeys = <String>{
  'world_id',
  'world_name',
  'created_at',
  'entities',
  'sessions',
  'map_data',
  'world_schema',
  'template_id',
  'template_hash',
  'template_original_hash',
};

List<dynamic> _mergeSessions({
  required List<dynamic> localList,
  required List<dynamic> remoteList,
  required WorldSectionStamps localStamps,
  required WorldSectionStamps remoteStamps,
  required DateTime localFallback,
  required DateTime remoteFallback,
}) {
  Map<String, Map<String, dynamic>> byId(List<dynamic> list) => {
        for (final e in list)
          if (e is Map && e['id'] is String)
            e['id'] as String: Map<String, dynamic>.from(e),
      };
  final localById = byId(localList);
  final remoteById = byId(remoteList);

  // Sıra: önce yerel liste (kullanıcının gördüğü düzen korunur), sonra yalnız
  // uzakta olan yeni oturumlar.
  final order = <String>[
    ...localById.keys,
    for (final id in remoteById.keys)
      if (!localById.containsKey(id)) id,
  ];

  return [
    for (final id in order)
      if (!remoteById.containsKey(id))
        deepCopyJson(localById[id]!)
      else if (!localById.containsKey(id))
        deepCopyJson(remoteById[id]!)
      else
        deepCopyJson(
          _remoteWins(
            localStamps.sessions[id] ?? localFallback,
            remoteStamps.sessions[id] ?? remoteFallback,
          )
              ? remoteById[id]!
              : localById[id]!,
        ),
  ];
}

/// Eşitlikte **yerel** kazanır: gereksiz yazımı ve iki cihaz arasında
/// ping-pong'u önler.
bool _remoteWins(DateTime local, DateTime remote) => remote.isAfter(local);

Map<String, DateTime> _laterOf(
  Map<String, DateTime> a,
  Map<String, DateTime> b,
) =>
    {
      for (final key in {...a.keys, ...b.keys})
        key: _laterNullable(a[key], b[key])!,
    };

DateTime? _laterNullable(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return b.isAfter(a) ? b : a;
}

String? _oldest(Object? a, Object? b) {
  final sa = a is String ? a : null;
  final sb = b is String ? b : null;
  if (sa == null) return sb;
  if (sb == null) return sa;
  final da = DateTime.tryParse(sa);
  final db = DateTime.tryParse(sb);
  if (da == null) return sb;
  if (db == null) return sa;
  return da.isBefore(db) ? sa : sb;
}

Map<String, dynamic> _mapOf(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : const {};

List<dynamic> _listOf(Object? raw) => raw is List ? raw : const [];
