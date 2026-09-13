import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/network/free_media_service.dart';
import '../../data/network/network_providers.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/media_kind.dart';

/// Dünya kartının kimliği — açıklama, etiketler, kapak resmi.
///
/// `worlds.meta_json` (migration 093) üzerinden taşınır: DM dünya ayarlarını
/// kaydettiğinde / dünyayı online yaptığında push edilir; oyuncu davet kodunu
/// kullanırken ([WorldJoinService]), dünyayı açarken ve `worlds` CDC
/// UPDATE'inde ([WorldMirrorApplier]) yerel `world_settings.metadata`'sına
/// uygulanır.
///
/// Neden kapak yüklenir: DM'in `cover_image_path`'i kendi diskindeki mutlak
/// yol. Oyuncuya olduğu gibi gitse çözülemez — önce ücretsiz free-media
/// havuzuna yüklenip `dmt-public://` ref'ine çevrilir (kapak kind'ı quota'ya
/// sayılmaz). DM'in kendi satırı yerel yolda kalır: çevrimdışı açılışta ve
/// LAN eşlemesinde asıl dosya lazım.
class WorldMetaSync {
  WorldMetaSync(this._client, this._free);

  final SupabaseClient _client;
  final FreeMediaService _free;

  /// Buluta giden anahtarlar. Metadata map'inin geri kalanı (varsa) DM'de
  /// kalır — paylaşılan şey kartın görünen yüzü, dünyanın tamamı değil.
  static const Set<String> keys = {'description', 'tags', 'cover_image_path'};

  /// DM: [metadata]'yı `worlds.meta_json`'a yazar. Best-effort — atmaz,
  /// yerel kaydı bloklamaz. Non-DM çağrısını RLS reddeder.
  Future<void> push({
    required String worldId,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final cover = (metadata['cover_image_path'] as String?) ?? '';
      final out = <String, dynamic>{
        'description': (metadata['description'] as String?) ?? '',
        'tags': ((metadata['tags'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        'cover_image_path':
            cover.isEmpty ? '' : (await _remoteCoverRef(cover, worldId) ?? ''),
      };
      await _client
          .from('worlds')
          .update({'meta_json': jsonEncode(out)}).eq('id', worldId);
    } catch (e, st) {
      debugPrint('pushWorldMeta error: $e\n$st');
    }
  }

  /// Yerel yolu çözülebilir bir ref'e çevirir. Zaten ref ise (dmt-public,
  /// dmt-art, …) dokunmaz; dosya yoksa / yükleme patlarsa null.
  Future<String?> _remoteCoverRef(String cover, String worldId) async {
    if (!AssetRef(cover).isLocal) return cover;
    final file = File(cover);
    if (!await file.exists()) return null;
    try {
      final uri = await _free.uploadFreeMedia(
        file,
        kind: MediaKind.worldCover,
        scopeId: worldId,
      );
      return uri.toString();
    } catch (e) {
      debugPrint('world cover upload error: $e');
      return null;
    }
  }
}

/// `worlds.meta_json` → yerel `metadata` yaması. Boş/bozuk blob'da null.
Map<String, dynamic>? decodeWorldMeta(Object? raw) {
  Object? decoded = raw;
  if (raw is String) {
    if (raw.isEmpty) return null;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
  if (decoded is! Map) return null;
  final out = <String, dynamic>{};
  for (final k in WorldMetaSync.keys) {
    if (decoded.containsKey(k)) out[k] = decoded[k];
  }
  return out.isEmpty ? null : out;
}

/// Supabase konfigüre değilse null — çağıran sessizce atlar.
final worldMetaSyncProvider = Provider<WorldMetaSync?>((ref) {
  final free = ref.watch(freeMediaServiceProvider);
  if (free == null) return null;
  try {
    return WorldMetaSync(Supabase.instance.client, free);
  } catch (_) {
    return null;
  }
});
