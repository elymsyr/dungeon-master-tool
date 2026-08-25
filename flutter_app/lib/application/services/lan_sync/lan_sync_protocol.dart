import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// LAN sync wire protocol — saf Dart, Flutter/Drift bağımlılığı yok.
///
/// İki cihaz aynı ağdayken, host tarafı kısa ömürlü bir HTTP sunucusu açar
/// ([LanSyncServer]) ve peer ona bağlanır ([LanSyncClient]). Taşınan şey
/// cloud-backup akışının payload'ının aynısıdır: `repository.load(name)`
/// çıktısı olan blob map. Yani merge mantığı yeniden yazılmaz — peer cihaz
/// aynı backup/restore kontratını konuşan ikinci bir "bulut"tur.
///
/// Bu dosya dört şeyi tanımlar:
///   1. Manifest/payload DTO'ları + JSON codec'leri.
///   2. [diffManifests] — LWW diff, saf fonksiyon (test edilebilir çekirdek).
///   3. [LanAuth] — HMAC imzası, replay/skew koruması. v2'de oturum anahtarı
///      kalıcı `shared_secret`'tan gelir; PIN/QR yalnız **eşleşme anında**
///      geçici anahtar üretir.
///   4. Eşleşme yükleri: [LanPairInvite] (QR), [LanPairRequest],
///      [LanPairResponse] ve presence duyurusu [LanAnnounce].

// ── Item kimliği ────────────────────────────────────────────────────────

/// Senkronize edilebilir içerik türleri.
///
/// Template yok: `allTemplatesProvider` yalnız built-in şemayı döndürüyor,
/// kullanıcının taşıyabileceği bir template kaydı bulunmuyor.
enum LanItemType { world, package, character }

LanItemType? lanItemTypeFromWire(String s) => switch (s) {
      'world' => LanItemType.world,
      'package' => LanItemType.package,
      'character' => LanItemType.character,
      _ => null,
    };

String lanItemTypeToWire(LanItemType t) => t.name;

/// Manifest satırı: bir içeriğin kimliği + son değişme zamanı.
///
/// [updatedAt] milisaniyeye yuvarlanır — JSON round-trip'te mikrosaniye
/// farkı iki tarafın "aynı" içeriği farklı sanmasına yol açardı.
class LanItemRef {
  LanItemRef({
    required this.type,
    required this.id,
    required this.name,
    required DateTime updatedAt,
    DateTime? viewUpdatedAt,
    DateTime? renamedAt,
  })  : updatedAt = _toMs(updatedAt),
        viewUpdatedAt =
            viewUpdatedAt == null ? null : _toMs(viewUpdatedAt),
        renamedAt = renamedAt == null ? null : _toMs(renamedAt);

  static DateTime _toMs(DateTime t) => DateTime.fromMillisecondsSinceEpoch(
        t.toUtc().millisecondsSinceEpoch,
        isUtc: true,
      );

  final LanItemType type;
  final String id;
  final String name;
  final DateTime updatedAt;

  /// Yalnızca world için: "o an ne açıktı" görünümünün (açık kartlar, PDF
  /// sekmeleri, sağ sidebar) son değişme anı. İçerik hiç değişmeden sadece
  /// görünüm değiştiğinde de eşleme tetiklensin diye ayrı taşınır; alıcı
  /// tarafta world satırının içerik zaman damgasını kirletmez.
  final DateTime? viewUpdatedAt;

  /// World, package ve character için: son yeniden adlandırma zamanı. Alıcı
  /// tarafta peer'ın `renamedAt`'i local'den daha yeniyse isim güncellenir.
  final DateTime? renamedAt;

  /// LWW karşılaştırmasında kullanılan zaman: içerik ve görünümün yenisi.
  DateTime get effectiveUpdatedAt =>
      (viewUpdatedAt != null && viewUpdatedAt!.isAfter(updatedAt))
          ? viewUpdatedAt!
          : updatedAt;

  String get key => '${lanItemTypeToWire(type)}:$id';

  Map<String, dynamic> toJson() => {
        'type': lanItemTypeToWire(type),
        'id': id,
        'name': name,
        'updated_at': updatedAt.toIso8601String(),
        if (viewUpdatedAt != null)
          'view_updated_at': viewUpdatedAt!.toIso8601String(),
        if (renamedAt != null) 'renamed_at': renamedAt!.toIso8601String(),
      };

  static LanItemRef? fromJson(Map<String, dynamic> j) {
    final type = lanItemTypeFromWire('${j['type']}');
    final id = j['id'];
    if (type == null || id is! String || id.isEmpty) return null;
    final ts = DateTime.tryParse('${j['updated_at']}');
    if (ts == null) return null;
    return LanItemRef(
      type: type,
      id: id,
      name: '${j['name'] ?? ''}',
      updatedAt: ts,
      viewUpdatedAt: j['view_updated_at'] == null
          ? null
          : DateTime.tryParse('${j['view_updated_at']}'),
      renamedAt: j['renamed_at'] == null
          ? null
          : DateTime.tryParse('${j['renamed_at']}'),
    );
  }

  @override
  String toString() => '$key(${name.isEmpty ? '-' : name}@$effectiveUpdatedAt)';
}

/// Bir item'ın medya dosyası: veri köküne göre relatif yol + içerik hash'i.
class LanMediaEntry {
  const LanMediaEntry({
    required this.path,
    required this.sha256,
    required this.size,
  });

  /// `AppPaths.dataRoot`'a göre relatif, POSIX ayırıcılı yol.
  final String path;
  final String sha256;
  final int size;

  Map<String, dynamic> toJson() => {
        'path': path,
        'sha256': sha256,
        'size': size,
      };

  static LanMediaEntry? fromJson(Map<String, dynamic> j) {
    final path = j['path'];
    final sha = j['sha256'];
    if (path is! String || path.isEmpty || sha is! String) return null;
    return LanMediaEntry(
      path: path,
      sha256: sha,
      size: (j['size'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Tel üzerinden geçen tam item: kimlik + blob + medya listesi.
///
/// [dataRoot] gönderenin `AppPaths.dataRoot`'u. Alıcı, payload içindeki
/// mutlak yollarda bu prefix'i kendi köküyle değiştirir — böylece medya
/// referansları alan adı bilmeden taşınır.
class LanItemPayload {
  const LanItemPayload({
    required this.ref,
    required this.payload,
    required this.dataRoot,
    this.media = const [],
    this.extras = const {},
  });

  final LanItemRef ref;
  final Map<String, dynamic> payload;
  final String dataRoot;
  final List<LanMediaEntry> media;

  /// `repository.load` blob'unun **dışında** kalan, ama dünyaya ait olan
  /// parçalar: paket kurulum bağlantıları ve UI görünümü (açık kartlar, açık
  /// PDF sekmeleri, sağ sidebar durumu). Blob cloud-backup kontratı olduğu
  /// için genişletilmedi; bunlar yanına ayrı bir bölüm olarak takılıyor.
  /// [dataRoot] yeniden yazımı payload ile aynı şekilde buna da uygulanır.
  final Map<String, dynamic> extras;

  Map<String, dynamic> toJson() => {
        'ref': ref.toJson(),
        'payload': payload,
        'data_root': dataRoot,
        'media': [for (final m in media) m.toJson()],
        if (extras.isNotEmpty) 'extras': extras,
      };

  static LanItemPayload? fromJson(Map<String, dynamic> j) {
    final rawRef = j['ref'];
    final rawPayload = j['payload'];
    if (rawRef is! Map || rawPayload is! Map) return null;
    final ref = LanItemRef.fromJson(rawRef.cast<String, dynamic>());
    if (ref == null) return null;
    final rawExtras = j['extras'];
    return LanItemPayload(
      ref: ref,
      payload: rawPayload.cast<String, dynamic>(),
      dataRoot: '${j['data_root'] ?? ''}',
      extras: rawExtras is Map
          ? rawExtras.cast<String, dynamic>()
          : const <String, dynamic>{},
      media: [
        for (final m in (j['media'] as List? ?? const []))
          if (m is Map)
            ?LanMediaEntry.fromJson(m.cast<String, dynamic>()),
      ],
    );
  }
}

// ── Diff ────────────────────────────────────────────────────────────────

/// [diffManifests] sonucu. `skipped` iki tarafta da aynı olan item sayısı —
/// "her şeyi tek seferde değil, sadece değişeni taşı" garantisi budur.
class LanSyncPlan {
  const LanSyncPlan({
    required this.pull,
    required this.push,
    required this.skipped,
  });

  /// Peer'dan çekilecekler (peer'da yok bizde ya da peer daha yeni).
  final List<LanItemRef> pull;

  /// Peer'a gönderilecekler (bizde var peer'da yok ya da biz daha yeniyiz).
  final List<LanItemRef> push;

  final int skipped;

  bool get isEmpty => pull.isEmpty && push.isEmpty;
  int get total => pull.length + push.length;
}

/// Çift yönlü LWW diff — online sync'teki kuralın aynısı, item granülünde.
///
/// Aynı `(type, id)` iki tarafta da varsa `updatedAt` yeni olan kazanır;
/// eşitse hiçbir şey taşınmaz.
///
/// ponytail: silme yayılmıyor — yalnız ekleme/güncelleme. Bir tarafta
/// silinen içerik diğerinden geri gelir. Tombstone tablosu gerekirse
/// `trash_items`'a `deleted_at` kolonu + manifest'e tombstone satırı eklenir.
LanSyncPlan diffManifests({
  required List<LanItemRef> local,
  required List<LanItemRef> peer,
}) {
  final localByKey = {for (final r in local) r.key: r};
  final peerByKey = {for (final r in peer) r.key: r};

  final pull = <LanItemRef>[];
  final push = <LanItemRef>[];
  var skipped = 0;

  for (final r in peer) {
    final mine = localByKey[r.key];
    if (mine == null) {
      pull.add(r);
    } else if (r.effectiveUpdatedAt.isAfter(mine.effectiveUpdatedAt)) {
      pull.add(r);
    } else if (mine.effectiveUpdatedAt.isAfter(r.effectiveUpdatedAt)) {
      push.add(mine);
    } else {
      skipped++;
    }
  }
  for (final r in local) {
    if (!peerByKey.containsKey(r.key)) push.add(r);
  }

  return LanSyncPlan(pull: pull, push: push, skipped: skipped);
}

// ── Kimlik doğrulama ────────────────────────────────────────────────────

/// İstek imzalama. Her istek `method|path|ts|nonce|sha256(body)` üzerinden
/// HMAC-SHA256 ile imzalanır.
///
/// İki anahtar kaynağı var:
/// - **Eşleşme anı** — QR'daki `pairToken` ya da `PIN + pairNonce`
///   ([deriveSessionKey]). Kısa ömürlü, yalnız `/pair` ucunu açar.
/// - **Eşleşme sonrası** — kalıcı `shared_secret` ([fromSharedSecret]).
///   Diğer bütün uçlar bunu ister.
///
/// ponytail: kimlik doğrulama var, şifreleme yok — LAN'da pasif dinleme için
/// saldırganın zaten Wi-Fi'da olması gerekir, gerçekçi tehdit (yetkisiz cihazın
/// kütüphaneyi çekmesi) imzayla kapanır. Üst yol: TLS ya da AES gövde
/// şifrelemesi; `crypto` paketi AES içermiyor, yeni bağımlılık gerekir.
class LanAuth {
  LanAuth({required this.sessionKey, this.clockSkew = _defaultSkew});

  static const Duration _defaultSkew = Duration(seconds: 60);
  static const String scheme = 'DMT-LAN';

  final List<int> sessionKey;
  final Duration clockSkew;

  /// Görülmüş nonce'lar → ilk görülme anı. [verify] her çağrıda budar.
  final Map<String, DateTime> _seenNonces = {};

  static final Random _rng = Random.secure();

  /// 6 haneli, baştaki sıfırları korunan PIN.
  static String generatePin() =>
      _rng.nextInt(1000000).toString().padLeft(6, '0');

  /// 16 hex karakterlik host nonce'u — PIN ile birlikte oturum anahtarını verir.
  static String generateHostNonce() {
    final bytes = List<int>.generate(8, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Eşleşme anahtarı: PIN/token + host nonce. İki taraf da aynı türetir.
  static List<int> deriveSessionKey(String secret, String hostNonce) =>
      sha256.convert(utf8.encode('dmt-lan:$secret:$hostNonce')).bytes;

  /// Eşleşme sonrası kalıcı anahtar. [sharedSecret] `lan_paired_devices`'te
  /// saklanan base64 dize.
  factory LanAuth.fromSharedSecret(String sharedSecret) =>
      LanAuth(sessionKey: base64.decode(sharedSecret));

  static String _bodySha(List<int> body) => sha256.convert(body).toString();

  String _sign({
    required String method,
    required String path,
    required int tsMs,
    required String nonce,
    required List<int> body,
  }) {
    final msg = '$method|$path|$tsMs|$nonce|${_bodySha(body)}';
    return base64Url.encode(
      Hmac(sha256, sessionKey).convert(utf8.encode(msg)).bytes,
    );
  }

  /// İstemci tarafı: `Authorization` başlığının değerini üretir.
  String buildHeader({
    required String method,
    required String path,
    required List<int> body,
    DateTime? now,
  }) {
    final tsMs = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final nonce = generateHostNonce();
    final sig = _sign(
      method: method,
      path: path,
      tsMs: tsMs,
      nonce: nonce,
      body: body,
    );
    return '$scheme $nonce.$tsMs.$sig';
  }

  /// Host tarafı: başlığı doğrular. Reddetme sebepleri — bozuk format, yanlış
  /// anahtar (PIN uyuşmazlığı), saat sapması, tekrarlanmış nonce.
  bool verify({
    required String? header,
    required String method,
    required String path,
    required List<int> body,
    DateTime? now,
  }) {
    if (header == null || !header.startsWith('$scheme ')) return false;
    final parts = header.substring(scheme.length + 1).split('.');
    if (parts.length != 3) return false;
    final nonce = parts[0];
    final tsMs = int.tryParse(parts[1]);
    final sig = parts[2];
    if (nonce.isEmpty || tsMs == null) return false;

    final current = (now ?? DateTime.now()).toUtc();
    _pruneNonces(current);

    final ts = DateTime.fromMillisecondsSinceEpoch(tsMs, isUtc: true);
    if (current.difference(ts).abs() > clockSkew) return false;
    if (_seenNonces.containsKey(nonce)) return false;

    final expected = _sign(
      method: method,
      path: path,
      tsMs: tsMs,
      nonce: nonce,
      body: body,
    );
    if (!_constantTimeEquals(expected, sig)) return false;

    _seenNonces[nonce] = current;
    return true;
  }

  void _pruneNonces(DateTime now) {
    _seenNonces.removeWhere((_, seen) => now.difference(seen) > clockSkew * 2);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

// ── Eşleşme yükleri ─────────────────────────────────────────────────────

/// QR koduna basılan davet. Kalıcı `shared_secret`'ı **taşımaz** — yalnız
/// kısa ömürlü [pairToken]'ı taşır; asıl sır `/pair` el sıkışmasında iki
/// tarafın ürettiği yarımlardan doğar.
class LanPairInvite {
  const LanPairInvite({
    required this.deviceId,
    required this.deviceName,
    required this.addresses,
    required this.port,
    required this.pairToken,
    required this.uid,
  });

  /// QR metninin ön eki. Kamera başka bir QR okursa hemen elenir.
  static const String qrPrefix = 'dmt2:';

  final String deviceId;
  final String deviceName;

  /// Host'un LAN IPv4 adresleri; istemci sırayla dener.
  final List<String> addresses;

  final int port;

  /// 32 baytlık base64 token. Panel açıkken periyodik olarak döner.
  final String pairToken;

  /// Supabase kullanıcı id'si — iki tarafın aynı hesapta olduğunu doğrular.
  final String uid;

  /// QR'a basılacak metin. Anahtarlar tek harfli: QR yoğunluğu düşük kalsın.
  String toQrText() => qrPrefix +
      base64Url.encode(utf8.encode(jsonEncode({
        'i': deviceId,
        'n': deviceName,
        'a': addresses,
        'p': port,
        't': pairToken,
        'u': uid,
      })));

  static LanPairInvite? fromQrText(String? raw) {
    if (raw == null || !raw.startsWith(qrPrefix)) return null;
    try {
      final json = jsonDecode(
        utf8.decode(base64Url.decode(raw.substring(qrPrefix.length))),
      );
      if (json is! Map) return null;
      final deviceId = json['i'];
      final token = json['t'];
      final port = (json['p'] as num?)?.toInt();
      if (deviceId is! String ||
          deviceId.isEmpty ||
          token is! String ||
          token.isEmpty ||
          port == null ||
          port <= 0) {
        return null;
      }
      return LanPairInvite(
        deviceId: deviceId,
        deviceName: '${json['n'] ?? ''}',
        addresses: [
          for (final a in (json['a'] as List? ?? const [])) '$a',
        ],
        port: port,
        pairToken: token,
        uid: '${json['u'] ?? ''}',
      );
    } catch (_) {
      return null;
    }
  }
}

/// İstemci → host: "beni tanı". [half] istemcinin ortak sır için ürettiği
/// 32 baytlık payı.
class LanPairRequest {
  const LanPairRequest({
    required this.deviceId,
    required this.deviceName,
    required this.uid,
    required this.half,
  });

  final String deviceId;
  final String deviceName;
  final String uid;
  final String half;

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'device_name': deviceName,
        'uid': uid,
        'half': half,
      };

  static LanPairRequest? fromJson(Map<String, dynamic> j) {
    final id = j['device_id'];
    final half = j['half'];
    if (id is! String || id.isEmpty || half is! String || half.isEmpty) {
      return null;
    }
    return LanPairRequest(
      deviceId: id,
      deviceName: '${j['device_name'] ?? ''}',
      uid: '${j['uid'] ?? ''}',
      half: half,
    );
  }
}

/// Host → istemci: kendi kimliği + kendi payı.
class LanPairResponse {
  const LanPairResponse({
    required this.deviceId,
    required this.deviceName,
    required this.half,
  });

  final String deviceId;
  final String deviceName;
  final String half;

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'device_name': deviceName,
        'half': half,
      };

  static LanPairResponse? fromJson(Map<String, dynamic> j) {
    final id = j['device_id'];
    final half = j['half'];
    if (id is! String || id.isEmpty || half is! String || half.isEmpty) {
      return null;
    }
    return LanPairResponse(
      deviceId: id,
      deviceName: '${j['device_name'] ?? ''}',
      half: half,
    );
  }
}

/// İki yarımdan simetrik ortak sır. Sıra **sabit**: önce istemcinin payı.
/// İki taraf da aynı sırayı kullandığı için sonuç aynı olur.
String deriveSharedSecret({
  required String clientHalf,
  required String hostHalf,
}) =>
    base64.encode(
      sha256.convert(utf8.encode('$clientHalf|$hostHalf')).bytes,
    );

/// Hesap kimliğinin tel üzerindeki kısa parmak izi. Ham `uid` broadcast'te
/// dolaşmasın diye presence paketinde bunun ilk 8 hex'i taşınır.
String uidFingerprint(String uid) =>
    sha256.convert(utf8.encode('dmt-lan-uid:$uid')).toString().substring(0, 8);

// ── Presence duyurusu ───────────────────────────────────────────────────

/// UDP broadcast paketi (v2). Yalnız "bu cihaz şu adreste ayakta" der.
/// Ne PIN ne token ne de ham `uid` taşır — cihaz adı bile yok, çünkü
/// alıcı zaten eşleşme kaydından adı biliyor.
class LanAnnounce {
  const LanAnnounce({
    required this.deviceId,
    required this.port,
    required this.uidFingerprint,
  });

  static const int discoveryPort = 45455;
  static const int protocolVersion = 2;

  final String deviceId;
  final int port;
  final String uidFingerprint;

  String encode() => jsonEncode({
        'dmt': protocolVersion,
        'id': deviceId,
        'p': port,
        'uh': uidFingerprint,
      });

  static LanAnnounce? decode(List<int> bytes) {
    try {
      final j = jsonDecode(utf8.decode(bytes));
      if (j is! Map || j['dmt'] != protocolVersion) return null;
      final id = j['id'];
      final port = (j['p'] as num?)?.toInt();
      if (id is! String || id.isEmpty || port == null || port <= 0) {
        return null;
      }
      return LanAnnounce(
        deviceId: id,
        port: port,
        uidFingerprint: '${j['uh'] ?? ''}',
      );
    } catch (_) {
      return null;
    }
  }
}
