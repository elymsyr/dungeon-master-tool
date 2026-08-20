import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'lan_device_store.dart';
import 'lan_sync_protocol.dart';

/// Eşleşmiş bir cihaza yapılan imzalı çağrılar.
///
/// v2'de "keşif" yok: istemci her zaman **kalıcı bir eşleşme kaydından**
/// (`shared_secret` + son bilinen adres) kurulur. Adres presence beacon'ı ile
/// güncel tutulur, o yüzden DHCP IP değiştirse de çağrı yerini bulur.
class LanSyncClient {
  LanSyncClient({
    required this.host,
    required this.port,
    required LanAuth auth,
    required this.myDeviceId,
    required this.myPort,
  }) : _auth = auth;

  /// Saklı eşleşme kaydından istemci kurar. Kayıtta adres yoksa null.
  static LanSyncClient? forDevice(
    PairedDevice device, {
    required String myDeviceId,
    required int myPort,
  }) {
    final addr = device.address;
    if (addr == null) return null;
    return LanSyncClient(
      host: addr.host,
      port: addr.port,
      auth: LanAuth.fromSharedSecret(device.sharedSecret),
      myDeviceId: myDeviceId,
      myPort: myPort,
    );
  }

  final String host;
  final int port;
  final LanAuth _auth;

  /// Karşı tarafın bizi tanıması için gönderilen kimlik.
  final String myDeviceId;

  /// Karşı taraf presence adresimizi doğru kaydetsin diye kendi portumuz.
  final int myPort;

  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6);

  void close() => _http.close(force: true);

  // ── Alt seviye ────────────────────────────────────────────────────────

  /// [path] zaten kodlanmış bileşenler içerebilir; `Uri(path:)` onları bir kez
  /// daha kodlar, o yüzden dizeden parse ediliyor.
  Uri _uri(String path) => Uri.parse('http://$host:$port$path');

  Future<HttpClientResponse> _send(
    String method,
    String path, {
    List<int> body = const [],
  }) async {
    final request = await _http.openUrl(method, _uri(path));
    // İmza `method + path + body` üzerinden. Protokolde query string yok —
    // parametreler gövdede taşınır, böylece iki taraf kodlama farkı yüzünden
    // farklı bir dize imzalayamaz.
    request.headers
      ..set(HttpHeaders.authorizationHeader,
          _auth.buildHeader(method: method, path: path, body: body))
      ..set('X-DMT-Device', myDeviceId)
      ..set('X-DMT-Port', '$myPort');
    if (body.isNotEmpty) {
      request.headers.contentType = ContentType.json;
      request.headers.contentLength = body.length;
      request.add(body);
    }
    return request.close();
  }

  Future<String> _text(HttpClientResponse response) =>
      response.transform(utf8.decoder).join();

  Future<Never> _fail(HttpClientResponse response) async {
    throw LanSyncException(response.statusCode, await _text(response));
  }

  // ── Uçlar ─────────────────────────────────────────────────────────────

  /// Cihaz ayakta mı — presence'in UDP'siz yedeği.
  Future<bool> ping() async {
    try {
      final response = await _send('GET', '/ping');
      await _text(response);
      return response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    }
  }

  /// Karşı tarafa "beni listenden sil" der. Best-effort.
  Future<void> unpair() async {
    final response = await _send('POST', '/unpair');
    await _text(response);
  }

  Future<List<LanItemRef>> fetchManifest() async {
    final response = await _send('GET', '/manifest');
    if (response.statusCode != HttpStatus.ok) await _fail(response);
    final body = jsonDecode(await _text(response));
    final items = (body as Map)['items'] as List? ?? const [];
    return [
      for (final raw in items)
        if (raw is Map) ?LanItemRef.fromJson(raw.cast<String, dynamic>()),
    ];
  }

  Future<LanItemPayload> fetchItem(LanItemRef ref) async {
    final response = await _send(
      'GET',
      '/item/${lanItemTypeToWire(ref.type)}/${Uri.encodeComponent(ref.id)}',
    );
    if (response.statusCode != HttpStatus.ok) await _fail(response);
    final body = jsonDecode(await _text(response));
    final item = LanItemPayload.fromJson((body as Map).cast<String, dynamic>());
    if (item == null) {
      throw LanSyncException(HttpStatus.badRequest, 'bozuk item payload');
    }
    return item;
  }

  Future<void> pushItem(LanItemPayload item) async {
    final response = await _send(
      'POST',
      '/item/${lanItemTypeToWire(item.ref.type)}/'
          '${Uri.encodeComponent(item.ref.id)}',
      body: utf8.encode(jsonEncode(item.toJson())),
    );
    if (response.statusCode != HttpStatus.ok) await _fail(response);
    await _text(response);
  }

  /// Peer'da hangi medya dosyaları eksik — yalnız onları yüklemek için.
  Future<Set<String>> missingMediaOnPeer(List<LanMediaEntry> entries) async {
    if (entries.isEmpty) return const {};
    final response = await _send(
      'POST',
      '/media/have',
      body: utf8.encode(jsonEncode({
        'entries': [for (final e in entries) e.toJson()],
      })),
    );
    if (response.statusCode != HttpStatus.ok) await _fail(response);
    final body = jsonDecode(await _text(response));
    return {
      for (final p in ((body as Map)['missing'] as List? ?? const [])) '$p',
    };
  }

  /// Tek bir medya dosyasını peer'a yükler.
  ///
  /// ponytail: gövde base64 — %33 şişme, LAN hızında sorun değil ve tek kod
  /// yolu bırakıyor. Büyük harita dosyalarında darboğaz olursa multipart ya da
  /// ham gövde + imzalı başlık yoluna geçilir.
  Future<void> uploadMedia(LanMediaEntry entry, List<int> bytes) async {
    final response = await _send(
      'POST',
      '/media/put',
      body: utf8.encode(jsonEncode({
        ...entry.toJson(),
        'data': base64Encode(bytes),
      })),
    );
    if (response.statusCode != HttpStatus.ok) await _fail(response);
    await _text(response);
  }

  Future<List<int>> fetchMedia(String relativePath) async {
    final response = await _send(
      'POST',
      '/media',
      body: utf8.encode(jsonEncode({'path': relativePath})),
    );
    if (response.statusCode != HttpStatus.ok) await _fail(response);
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    return bytes;
  }
}

// ── Eşleşme ─────────────────────────────────────────────────────────────

/// Başarılı `/pair` el sıkışmasının sonucu.
class LanPairOutcome {
  const LanPairOutcome({
    required this.deviceId,
    required this.deviceName,
    required this.address,
    required this.sharedSecret,
  });

  final String deviceId;
  final String deviceName;
  final String address;
  final String sharedSecret;
}

/// QR ve PIN yollarının ortak el sıkışması.
///
/// İki yol da aynı `/pair` ucuna gider; tek fark geçici anahtarın nereden
/// geldiği — QR'da token, elle girişte PIN + `/hello`'dan alınan nonce.
class LanPairing {
  const LanPairing._();

  /// QR okundu → davetteki adresleri sırayla dener.
  static Future<LanPairOutcome> viaInvite(
    LanPairInvite invite, {
    required String myDeviceId,
    required String myDeviceName,
    required String myUid,
    required int myPort,
  }) async {
    Object? lastError;
    for (final host in [...invite.addresses, '127.0.0.1']) {
      try {
        return await _handshake(
          host: host,
          port: invite.port,
          pairSecret: invite.pairToken,
          pairNonce: (await _hello(host, invite.port))?.nonce ?? '',
          myDeviceId: myDeviceId,
          myDeviceName: myDeviceName,
          myUid: myUid,
          myPort: myPort,
        );
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? LanSyncException(0, 'unreachable');
  }

  /// Elle `IP:port` + PIN.
  static Future<LanPairOutcome> viaPin({
    required String host,
    required int port,
    required String pin,
    required String myDeviceId,
    required String myDeviceName,
    required String myUid,
    required int myPort,
  }) async {
    final hello = await _hello(host, port);
    if (hello == null) {
      throw LanSyncException(HttpStatus.notFound, 'no_host_there');
    }
    if (!hello.pairing) {
      // Karşı taraf ayakta ama paneli kapalı — "cihaz yok" demek yanıltıcı
      // olurdu, kullanıcıya "orada Yerel Eşleme'yi aç" demek gerekiyor.
      throw LanSyncException(HttpStatus.forbidden, 'pairing_closed');
    }
    return _handshake(
      host: host,
      port: port,
      pairSecret: pin,
      pairNonce: hello.nonce,
      myDeviceId: myDeviceId,
      myDeviceName: myDeviceName,
      myUid: myUid,
      myPort: myPort,
    );
  }

  /// İmzasız `GET /hello` — eşleşme anahtarını türetmek için gereken nonce +
  /// karşı tarafın eşleşmeye açık olup olmadığı. Nonce tek başına hiçbir şey
  /// açmaz; sır hâlâ QR token'ı ya da PIN.
  static Future<({String nonce, bool pairing})?> _hello(
    String host,
    int port,
  ) async {
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await http.getUrl(Uri.parse('http://$host:$port/hello'));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return null;
      final body = jsonDecode(await response.transform(utf8.decoder).join());
      if (body is! Map) return null;
      return (
        nonce: '${body['nonce'] ?? ''}',
        pairing: body['pairing'] == true,
      );
    } catch (e) {
      debugPrint('[LanSync] hello başarısız $host:$port — $e');
      return null;
    } finally {
      http.close(force: true);
    }
  }

  static Future<LanPairOutcome> _handshake({
    required String host,
    required int port,
    required String pairSecret,
    required String pairNonce,
    required String myDeviceId,
    required String myDeviceName,
    required String myUid,
    required int myPort,
  }) async {
    final auth = LanAuth(
      sessionKey: LanAuth.deriveSessionKey(pairSecret, pairNonce),
    );
    final myHalf = LanDeviceStore.newSecretHalf();
    final body = utf8.encode(jsonEncode(LanPairRequest(
      deviceId: myDeviceId,
      deviceName: myDeviceName,
      uid: myUid,
      half: myHalf,
    ).toJson()));

    final http = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request =
          await http.postUrl(Uri.parse('http://$host:$port/pair'));
      request.headers
        ..set(HttpHeaders.authorizationHeader,
            auth.buildHeader(method: 'POST', path: '/pair', body: body))
        ..set('X-DMT-Port', '$myPort')
        ..contentType = ContentType.json;
      request.headers.contentLength = body.length;
      request.add(body);
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw LanSyncException(response.statusCode, text);
      }
      final decoded = jsonDecode(text);
      final res = decoded is Map
          ? LanPairResponse.fromJson(decoded.cast<String, dynamic>())
          : null;
      if (res == null) {
        throw LanSyncException(HttpStatus.badRequest, 'bad_pair_response');
      }
      return LanPairOutcome(
        deviceId: res.deviceId,
        deviceName: res.deviceName,
        address: '$host:$port',
        sharedSecret:
            deriveSharedSecret(clientHalf: myHalf, hostHalf: res.half),
      );
    } finally {
      http.close(force: true);
    }
  }
}

// ── Presence ────────────────────────────────────────────────────────────

/// Arka planda UDP duyurularını dinler ve eşleşmiş cihazların adres/son
/// görülme bilgisini tazeler.
///
/// Kullanıcıya "ara" diye bir şey sunmaz — listede kimin ● olduğu buradan
/// gelir. Eşleşmemiş cihazların paketleri sessizce yok sayılır.
class LanPresenceListener {
  LanPresenceListener(this._store);

  final LanDeviceStore _store;

  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _sub;

  /// Her tazelemeden sonra tetiklenir — UI listeyi yeniler.
  final ValueNotifier<int> tick = ValueNotifier(0);

  Future<void> start() async {
    if (_socket != null) return;
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        LanAnnounce.discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
    } catch (_) {
      // reusePort her platformda yok (Windows, bazı Android sürümleri).
      try {
        socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          LanAnnounce.discoveryPort,
          reuseAddress: true,
        );
      } catch (e) {
        debugPrint('[LanSync] presence dinlenemedi: $e');
        return;
      }
    }
    _socket = socket;
    _sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket?.receive();
      if (datagram == null) return;
      final announce = LanAnnounce.decode(datagram.data);
      if (announce == null) return;
      unawaited(_onAnnounce(announce, datagram.address.address));
    });
  }

  Future<void> _onAnnounce(LanAnnounce announce, String fromHost) async {
    try {
      if (await _store.byId(announce.deviceId) == null) return;
      await _store.touchSeen(
        announce.deviceId,
        '$fromHost:${announce.port}',
      );
      tick.value++;
    } catch (e) {
      debugPrint('[LanSync] presence güncellenemedi: $e');
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    unawaited(stop());
    tick.dispose();
  }
}

class LanSyncException implements Exception {
  LanSyncException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  /// Eşleşme yok / sır tutmuyor.
  bool get isAuthFailure =>
      statusCode == HttpStatus.unauthorized ||
      statusCode == HttpStatus.tooManyRequests;

  /// Karşı taraf başka bir hesapta.
  bool get isAccountMismatch =>
      statusCode == HttpStatus.forbidden && body.contains('account_mismatch');

  /// Karşı tarafta eşleşme paneli kapalı.
  bool get isPairingClosed =>
      statusCode == HttpStatus.forbidden && body.contains('pairing_closed');

  @override
  String toString() => 'LanSyncException($statusCode): $body';
}

/// `"192.168.1.5:45456"` → `(host, port)`. Port yoksa null.
({String host, int port})? parseLanAddress(String raw) {
  final trimmed = raw.trim();
  final idx = trimmed.lastIndexOf(':');
  if (idx <= 0 || idx == trimmed.length - 1) return null;
  final port = int.tryParse(trimmed.substring(idx + 1));
  if (port == null || port <= 0 || port > 65535) return null;
  return (host: trimmed.substring(0, idx), port: port);
}
