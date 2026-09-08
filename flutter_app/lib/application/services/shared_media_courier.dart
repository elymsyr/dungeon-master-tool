import 'dart:io';

import 'package:crypto/crypto.dart';
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

/// DM tarafı: paylaşılan kartların medyasını **talep üzerine** transient
/// havuza taşır.
///
/// Kart paylaşımı artık hiçbir şey yüklemez. Paylaşım payload'ındaki yerel
/// yollar yalnızca içerik-adresli `dmt-transient://{sha}{ext}` ref'lerine
/// çevrilir ([refFor]); baytlar DM'in diskinde kalır. Oyuncu çözemediği
/// SHA'ları `world_members.missing_shas`'e yazdığında applier [serve]'i
/// çağırır ve **yalnızca istenen** baytlar buluta çıkar.
///
/// Neden ref'ler DM'in kendi entity'sine YAZILMAZ: transient obje sunucu
/// tarafında LRU ile atılabilir; kalıcı bir satırda ölü ref bırakmak DM'in
/// kendi resmini kaybetmesi demek olurdu. Aynı gerekçe
/// `prepareEntityImagesForProjection`'da da geçerli.
class SharedMediaCourier {
  SharedMediaCourier(this._ref);

  final Ref _ref;

  /// sha256 → yerel dosya yolu. Yalnızca bellekte: uygulama yeniden
  /// başladığında [_reindex] ile dünyanın kartlarından yeniden kurulur.
  final Map<String, String> _pathForSha = {};

  /// Bu oturumda zaten yüklenmiş SHA'lar — aynı talep tekrar gelirse
  /// (oyuncu listesini yeniden yazar) ikinci kez PUT atmayalım.
  final Set<String> _served = {};

  bool _reindexed = false;

  /// [localPath]'i içerik-adresli transient ref'e çevirir ve sha → yol
  /// eşlemesini kaydeder. Dosya okunamıyorsa null.
  Future<String?> refFor(String localPath) async {
    final sha = await shaOfFile(localPath);
    if (sha == null) return null;
    _pathForSha[sha] = localPath;
    return AssetRef.formatTransientUri(sha, p.extension(localPath).toLowerCase());
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

  /// Aktif dünyanın bütün kartlarındaki yerel medyayı hash'leyip eşlemeyi
  /// yeniden kurar — uygulama yeniden başladıktan sonra gelen ilk talep için.
  ///
  /// ponytail: dünyanın TÜM yerel medyasını hash'ler ve oturum başına bir kez
  /// çalışır. Yüzlerce MB'lık dünyalarda ölçülür bir gecikme olursa, sha'yı
  /// paylaşım anında `asset_refs` yan tablosuna yazıp buradan okumak yükseltme
  /// yolu.
  Future<void> _reindex() async {
    if (_reindexed) return;
    _reindexed = true;
    final entities = _ref.read(entityProvider);
    final keys = imageFieldKeysBySlug(_ref.read(worldSchemaProvider));
    for (final e in entities.values) {
      if (e.linked) continue;
      for (final path in localMediaPathsOf(e, keys[e.categorySlug] ?? const [])) {
        final sha = await shaOfFile(path);
        if (sha != null) _pathForSha[sha] = path;
      }
    }
  }
}

/// Dosyanın sha256 hex'i; okunamıyorsa null. Akış üzerinden hash'lenir —
/// 100 MB'lık bir handout belleğe alınmasın.
Future<String?> shaOfFile(String path) async {
  final file = File(path);
  try {
    if (!await file.exists()) return null;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  } catch (_) {
    return null;
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
