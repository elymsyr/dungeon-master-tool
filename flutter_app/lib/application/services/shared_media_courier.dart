import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/network/network_providers.dart';
import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/media_kind.dart';
import '../providers/entity_provider.dart';
import 'content_ref_index.dart';

export 'content_ref_index.dart' show shaOfFile;

/// DM tarafı: paylaşılan kartların medyasını **talep üzerine** transient
/// havuza taşır.
///
/// Kart paylaşımı artık hiçbir şey yüklemez. Paylaşım payload'ındaki yerel
/// yollar yalnızca içerik-adresli `dmt-content://{sha}{ext}` ref'lerine
/// çevrilir ([refFor]); baytlar DM'in diskinde kalır. Oyuncu çözemediği
/// SHA'ları `world_members.missing_shas`'e yazdığında applier [serve]'i
/// çağırır ve **yalnızca istenen** baytlar buluta çıkar.
///
/// Ref biçimi Faz 3.5'te `dmt-transient://`'ten `dmt-content://`'e taşındı:
/// eski biçim baytların transient havuzda olduğunu iddia ediyordu, oysa
/// paylaşım anında havuzda hiçbir şey yok ve LRU her an atabilir. `content`
/// hiçbir katman adlandırmaz, bu yüzden kalıcı satırda da durabilir — Faz 4
/// push'u bunu gerektiriyor. Eski `dmt-transient://` ref'leri okunmaya devam
/// eder ([AssetRefResolver]); yalnızca yeni ref üretilmez.
class SharedMediaCourier {
  SharedMediaCourier(this._ref);

  final Ref _ref;

  /// sha256 → yerel dosya yolu, oturum içi hızlı yol. Kalıcı eşleme
  /// [ContentRefIndex]'te (`content_paths`); bu map yalnızca tekrar eden
  /// taleplerde DB'ye gitmemek için.
  final Map<String, String> _pathForSha = {};

  /// Bu oturumda zaten yüklenmiş SHA'lar — aynı talep tekrar gelirse
  /// (oyuncu listesini yeniden yazar) ikinci kez PUT atmayalım.
  final Set<String> _served = {};

  bool _reindexed = false;

  /// [localPath]'i içerik-adresli `dmt-content://` ref'ine çevirir ve
  /// sha → yol eşlemesini kalıcı olarak kaydeder. Dosya okunamıyorsa null.
  Future<String?> refFor(String localPath) async {
    final index = _ref.read(contentRefIndexProvider);
    final sha = await index.shaFor(localPath);
    if (sha == null) return null;
    _pathForSha[sha] = localPath;
    return AssetRef.formatContentUri(
      sha,
      p.extension(localPath).toLowerCase(),
    );
  }

  /// [shas]'ten bilinen ve henüz yüklenmemiş olanları transient havuza yükler.
  /// Tanınmayan SHA (başka bir dünyanın kartı, silinmiş dosya) sessizce atlanır
  /// — oyuncu listesini korur, DM dosyayı geri getirirse sonraki turda çıkar.
  Future<void> serve(String worldId, Iterable<String> shas) async {
    final want = {
      for (final s in shas)
        if (s.length == 64) s.toLowerCase(),
    }..removeAll(_served);
    if (want.isEmpty) return;

    final svc = _ref.read(assetServiceProvider);
    if (svc == null) return;

    // Kalıcı eşleme önce: önceki oturumda paylaşılmış bir kart için dünyayı
    // yeniden hash'lemeye gerek yok.
    final index = _ref.read(contentRefIndexProvider);
    for (final sha in want) {
      if (_pathForSha.containsKey(sha)) continue;
      final hit = await index.fileForSha(sha);
      if (hit != null) _pathForSha[sha] = hit.path;
    }
    // Hâlâ bilinmeyen sha varsa (indeks kurulmadan önce paylaşılmış kart)
    // dünyayı bir kez tara.
    if (want.any((s) => !_pathForSha.containsKey(s))) await _reindex();

    for (final sha in want) {
      final path = _pathForSha[sha];
      if (path == null) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      try {
        await svc.uploadTransientShare(
          file,
          kind: MediaKind.worldEntityImage,
          worldId: worldId,
        );
        _served.add(sha);
      } catch (e) {
        debugPrint('SharedMediaCourier.serve $sha failed: $e');
      }
    }
  }

  /// [localPath]'i şimdi transient havuza yükler ve ref'ini döndürür; upload
  /// başarısızsa null.
  ///
  /// Projeksiyon yolu için: oyuncu ekranı `world_projection` üzerinden geliyor,
  /// orada eksik-bildirme turu yok — baytlar önden çıkmak zorunda. Paylaşım
  /// yolu ([refFor] + [serve]) aksine talep üzerine çalışır.
  Future<String?> publish(String worldId, String localPath) async {
    final ref = await refFor(localPath);
    if (ref == null) return null;
    final sha = AssetRef(ref).contentSha;
    if (sha == null) return null;
    await serve(worldId, [sha]);
    return _served.contains(sha) ? ref : null;
  }

  /// Aktif dünyanın bütün kartlarındaki yerel medyayı hash'leyip eşlemeyi
  /// yeniden kurar — uygulama yeniden başladıktan sonra gelen ilk talep için.
  ///
  /// Faz 3.5'ten beri yalnızca **geri düşüş**: `content_paths` boşken (eski
  /// sürümde paylaşılmış kartlar, sıfırlanmış cache) istenen sha'yı bulmanın
  /// tek yolu. Hash'lediği her dosyayı indekse yazar, böylece bir daha
  /// çalışmasına gerek kalmaz.
  Future<void> _reindex() async {
    if (_reindexed) return;
    _reindexed = true;
    final index = _ref.read(contentRefIndexProvider);
    final entities = _ref.read(entityProvider);
    final keys = imageFieldKeysBySlug(_ref.read(worldSchemaProvider));
    for (final e in entities.values) {
      if (e.linked) continue;
      for (final path in localMediaPathsOf(e, keys[e.categorySlug] ?? const [])) {
        final sha = await index.shaFor(path);
        if (sha != null) _pathForSha[sha] = path;
      }
    }
  }
}

/// Kategori slug'ı → o kategorinin `image` tipli alan anahtarları.
Map<String, List<String>> imageFieldKeysBySlug(WorldSchema schema) => {
      for (final c in schema.categories)
        c.slug: [
          for (final f in c.fields)
            if (f.fieldType == FieldType.image) f.fieldKey,
        ],
    };

/// Entity'nin portre + galeri + `image` alanlarındaki **yerel** yolları
/// (tekilleştirilmiş, sırası korunmuş).
List<String> localMediaPathsOf(Entity e, List<String> imageFieldKeys) {
  final paths = <String>{};
  void scan(String s) {
    if (s.isNotEmpty && AssetRef(s).isLocal) paths.add(s);
  }

  scan(e.imagePath);
  e.images.forEach(scan);
  for (final k in imageFieldKeys) {
    final v = e.fields[k];
    if (v is List) {
      for (final x in v) {
        if (x is String) scan(x);
      }
    } else if (v is String) {
      scan(v);
    }
  }
  return paths.toList();
}

/// [e]'nin kopyasını, [remap]'teki yerel yollar ref'lerle değiştirilmiş olarak
/// döner. **Kaydedilmez** — yalnızca paylaşım payload'ı için.
Entity remapEntityMedia(
  Entity e,
  Map<String, String> remap,
  List<String> imageFieldKeys,
) {
  if (remap.isEmpty) return e;
  String repl(String s) => remap[s] ?? s;
  final fields = Map<String, dynamic>.from(e.fields);
  for (final k in imageFieldKeys) {
    final v = e.fields[k];
    if (v is List) {
      fields[k] = v.map((x) => x is String ? repl(x) : x).toList();
    } else if (v is String && v.isNotEmpty) {
      fields[k] = repl(v);
    }
  }
  return e.copyWith(
    imagePath: repl(e.imagePath),
    images: e.images.map(repl).toList(),
    fields: fields,
  );
}

final sharedMediaCourierProvider = Provider<SharedMediaCourier>(
  SharedMediaCourier.new,
);
