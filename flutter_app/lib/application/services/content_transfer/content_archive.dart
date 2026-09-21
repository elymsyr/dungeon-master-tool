/// `.dmtz` — hesapsız, internetsiz içerik aktarımı. Bir dünya / paket /
/// karakter tek bir zip'e girer, başka bir kurulumda geri açılır.
///
/// Taşınan şey LAN telindekiyle **birebir aynı**: [ContentItemPayload].
/// Yol taşınabilirliği için yeni kod yok — manifest export eden makinenin
/// veri kökünü yazıyor, import [ContentCodec.rewriteRoots] ile onu kendi
/// köküne çeviriyor. LAN'ın iki cihaz arasında yaptığı şeyin aynısı, arada
/// zip var.
///
/// Zip düzeni:
/// ```
/// manifest.json   ref alanları + format / data_root / app_version / media
/// payload.json    repository.load() blob'u
/// extras.json     yalnız dünya — installed_packages, ui_view, section_stamps
/// media/<yol>     baytlar; manifest.data_root'a göreli
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants.dart';
import '../local_media_localizer.dart';
import 'content_codec.dart';
import 'content_item.dart';

/// Dosya uzantısı — `FilePicker` filtreleri bunu kullanır (noktasız).
const String kContentArchiveExtension = 'dmtz';

/// Zip düzeninin sürümü. Bilinmeyen bir sürüm sessizce kabul edilmez,
/// [ContentArchiveError.unsupportedFormat] ile reddedilir.
const int kContentArchiveFormat = 1;

enum ContentArchiveError {
  /// Zip açılamadı ya da içinde manifest/payload yok.
  unreadable,

  /// `manifest.format` bu sürümün tanımadığı bir numara.
  unsupportedFormat,
}

class ContentArchiveException implements Exception {
  const ContentArchiveException(this.error, [this.detail]);

  final ContentArchiveError error;
  final String? detail;

  @override
  String toString() => 'ContentArchiveException(${error.name}: $detail)';
}

/// Import sonucu — kullanıcıya ne olduğunu söylemek için.
class ContentArchiveImportResult {
  const ContentArchiveImportResult({
    required this.ref,
    required this.mediaWritten,
    required this.mediaSkipped,
  });

  final ContentItemRef ref;
  final int mediaWritten;

  /// Yazılamayan medya sayısı: sha tutmadı, zip'te yoktu ya da aynı yolda
  /// **farklı içerikli** yerel bir dosya duruyordu.
  final int mediaSkipped;
}

/// [item]'ı [path]'teki `.dmtz` dosyasına yazar.
///
/// Medya dosyaları diskten akıtılır (`ZipFileEncoder.addFile`), belleğe
/// alınmaz — bir dünyanın medyası yüzlerce MB olabiliyor.
Future<void> writeContentArchive({
  required ContentItemPayload item,
  required String path,
}) async {
  // Manifest yalnız gerçekten pakete giren medyayı listelesin; kaybolmuş bir
  // dosya import tarafında "eksik" diye sayılmasın.
  final present = <ContentMediaEntry, File>{};
  for (final m in item.media) {
    final f = ContentCodec.resolveMedia(m.path);
    if (f != null && await f.exists()) present[m] = f;
  }

  final encoder = ZipFileEncoder();
  encoder.create(path);
  try {
    encoder.addArchiveFile(ArchiveFile.string(
      'manifest.json',
      jsonEncode({
        ...item.ref.toJson(),
        'format': kContentArchiveFormat,
        'data_root': item.dataRoot,
        'app_version': appVersion,
        'media': [for (final m in present.keys) m.toJson()],
      }),
    ));
    encoder.addArchiveFile(
        ArchiveFile.string('payload.json', jsonEncode(item.payload)));
    if (item.extras.isNotEmpty) {
      encoder.addArchiveFile(
          ArchiveFile.string('extras.json', jsonEncode(item.extras)));
    }
    for (final e in present.entries) {
      await encoder.addFile(e.value, 'media/${e.key.path}');
    }
  } finally {
    await encoder.close();
  }
}

/// Seçili item'ı bulup `.dmtz` yazar. Item yoksa false.
///
/// [id] varsa onunla, yoksa [name] ile eşleşir — paket listesi (`PackageInfo`)
/// id taşımıyor, dünya ve paket isimleri ise benzersiz.
Future<bool> exportContentArchive({
  required ContentCodec codec,
  required ContentItemType type,
  required String path,
  String? id,
  String? name,
}) async {
  final ref = (await codec.buildManifest()).firstWhereOrNull((r) =>
      r.type == type && (id != null ? r.id == id : r.name == name));
  if (ref == null) return false;
  final item = await codec.loadItem(ref);
  if (item == null) return false;
  await writeContentArchive(item: item, path: path);
  return true;
}

/// Bir `.dmtz` dosyasının açık hâli.
///
/// [open] yalnız JSON girdilerini okur — medya baytları zip'te kalır, ancak
/// [applyTo] sırasında diske akıtılır. Kullanan taraf işi bitince [close]
/// çağırmak zorunda (dosya tanıtıcısı açık kalır).
class ContentArchive {
  ContentArchive._(this._archive, this.item);

  final Archive _archive;

  /// Zip'ten okunan item — LAN'dan gelmiş gibi, aynı DTO.
  final ContentItemPayload item;

  static Future<ContentArchive> open(String path) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(InputFileStream(path));
    } catch (e) {
      throw ContentArchiveException(ContentArchiveError.unreadable, '$e');
    }

    Map<String, dynamic>? readJson(String name) {
      final bytes = archive.findFile(name)?.readBytes();
      if (bytes == null) return null;
      final decoded = jsonDecode(utf8.decode(bytes));
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    }

    final Map<String, dynamic>? manifest;
    final Map<String, dynamic>? payload;
    final Map<String, dynamic>? extras;
    try {
      manifest = readJson('manifest.json');
      payload = readJson('payload.json');
      extras = readJson('extras.json');
    } catch (e) {
      await archive.clear();
      throw ContentArchiveException(ContentArchiveError.unreadable, '$e');
    }

    if (manifest == null || payload == null) {
      await archive.clear();
      throw const ContentArchiveException(
          ContentArchiveError.unreadable, 'manifest.json / payload.json yok');
    }
    if (manifest['format'] != kContentArchiveFormat) {
      await archive.clear();
      throw ContentArchiveException(ContentArchiveError.unsupportedFormat,
          '${manifest['format']}');
    }
    final ref = ContentItemRef.fromJson(manifest);
    if (ref == null) {
      await archive.clear();
      throw const ContentArchiveException(
          ContentArchiveError.unreadable, 'manifest.json bozuk');
    }

    return ContentArchive._(
      archive,
      ContentItemPayload(
        ref: ref,
        payload: payload,
        dataRoot: '${manifest['data_root'] ?? ''}',
        extras: extras ?? const {},
        media: [
          for (final m in (manifest['media'] as List? ?? const []))
            if (m is Map) ?ContentMediaEntry.fromJson(m.cast<String, dynamic>()),
        ],
      ),
    );
  }

  /// Medyayı diske açar, sonra item'ı LAN'la aynı yoldan uygular.
  ///
  /// Yerelde aynı id varsa [ContentCodec.applyItem] bölüm bazlı birleştirme
  /// yapıyor (silme yaymıyor), yani import yıkıcı değil. Aynı isimde **başka**
  /// bir içerik varsa isme `(2)` ekleniyor.
  Future<ContentArchiveImportResult> applyTo(ContentCodec codec) async {
    var written = 0;
    var skipped = 0;
    for (final m in item.media) {
      switch (await _extractMedia(codec, m)) {
        case true:
          written++;
        case false:
          skipped++;
        case null:
          break; // zaten aynı içerikle duruyor
      }
    }
    await codec.applyItem(item);
    return ContentArchiveImportResult(
      ref: item.ref,
      mediaWritten: written,
      mediaSkipped: skipped,
    );
  }

  /// true yazıldı, false atlandı (hata), null zaten vardı.
  Future<bool?> _extractMedia(ContentCodec codec, ContentMediaEntry m) async {
    final dst = ContentCodec.resolveMedia(m.path);
    if (dst == null) {
      debugPrint('[ContentArchive] veri kökü dışı yol: ${m.path}');
      return false;
    }
    if (await codec.hasMedia(m)) return null;
    // ponytail: aynı yolda farklı içerik varsa üzerine yazmıyoruz. Yol
    // `worlds/<isim>/media/...` olduğu için, import edilen dünya isim
    // çakışmasından ötürü `(2)` olarak açıldığında yolu hâlâ eski ismi
    // gösteriyor ve yerel dünyanın resmini ezerdi. Tavan: import edilen
    // kopyanın resmi yerelinkiyle aynı görünür. Gerçek çözüm, dünya klasörünü
    // de import sırasında yeniden adlandırmak (Faz 2.5 dünya kimliği işiyle
    // birlikte ucuzluyor).
    if (await dst.exists()) {
      debugPrint('[ContentArchive] farklı içerik var, atlandı: ${m.path}');
      return false;
    }
    final entry = _archive.findFile('media/${m.path}');
    if (entry == null) {
      debugPrint('[ContentArchive] zip\'te yok: ${m.path}');
      return false;
    }
    await dst.parent.create(recursive: true);
    final out = OutputFileStream(dst.path);
    try {
      entry.writeContent(out);
    } finally {
      await out.close();
    }
    if (await ContentCodec.fileSha256(dst) != m.sha256) {
      debugPrint('[ContentArchive] sha tutmadı, atıldı: ${m.path}');
      await dst.delete();
      return false;
    }
    return true;
  }

  Future<void> close() => _archive.clear();
}

/// `<isim>.dmtz` — kaydetme diyaloğuna önerilecek dosya adı.
String contentArchiveFileName(String itemName) {
  final base = LocalMediaLocalizer.dirSafe(itemName.trim());
  return '${base.isEmpty ? 'dmt' : base}.$kContentArchiveExtension';
}
