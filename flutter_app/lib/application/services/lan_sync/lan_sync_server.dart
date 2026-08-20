import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'lan_device_store.dart';
import 'lan_sync_protocol.dart';
import 'lan_sync_session.dart';

/// LAN sync host'u — uygulama açıkken yaşayan sunucu.
///
/// v2'de yaşam döngüsü dialog'a değil **oturuma** bağlı: giriş yapılmış ve
/// en az bir eşleşmiş cihaz varsa (ya da eşleşme paneli açıksa) dinler.
/// Eşleşmesi olmayan kullanıcıda hiç soket açılmaz.
///
/// İki iş yapar:
///   1. **Presence** — 5 sn'de bir UDP broadcast: "bu cihaz şu portta ayakta".
///      Paket ne PIN ne token ne de ham `uid` taşır.
///   2. **HTTP** — içerik servisi + eşleşme uçları.
///
/// Kimlik doğrulama iki katmanlı:
///   - `/pair` → yalnız [openForPairing] açıkken, QR token'ı veya PIN'den
///     türeyen **geçici** anahtarla.
///   - Diğer her uç → `X-DMT-Device` başlığındaki cihazın saklı kalıcı
///     `shared_secret`'ı ile. Eşleşmemiş cihaz hiçbir şey göremez.
///
/// Ortak savunmalar: private olmayan kaynak IP reddi, saat sapması, nonce
/// replay, `/pair` için IP başına deneme sayacı.
class LanSyncServer {
  LanSyncServer({
    required LanSyncSession session,
    required LanDeviceStore store,
    required Future<String?> Function() currentUid,
  })  : _session = session,
        _store = store,
        _currentUid = currentUid;

  final LanSyncSession _session;
  final LanDeviceStore _store;
  final Future<String?> Function() _currentUid;

  /// Sabit port — saklı adresler cihaz yeniden başlasa da geçerli kalsın.
  /// Doluysa (aynı makinede ikinci instance) ephemeral'a düşülür ve doğru
  /// adres presence beacon'ı ile yayılır.
  static const int defaultPort = 45456;

  static const Duration _announceInterval = Duration(seconds: 5);
  static const Duration _pairTokenTtl = Duration(minutes: 3);
  static const Duration _blockWindow = Duration(seconds: 30);
  static const int _maxPairAttempts = 3;

  HttpServer? _http;
  RawDatagramSocket? _announceSocket;
  Timer? _announceTimer;
  Timer? _pairTokenTimer;

  String? _deviceId;
  String? _uidFingerprint;

  /// Eşleşme paneli açıkken dolu; kapalıyken null → `/pair` kapalı.
  String? _pairToken;
  String? _pairNonce;
  String? _pairPin;

  final Map<String, int> _pairFailures = {};
  final Map<String, DateTime> _blocked = {};

  int get port => _http?.port ?? 0;
  bool get isRunning => _http != null;
  String? get pairPin => _pairPin;
  String? get pairNonce => _pairNonce;
  bool get isOpenForPairing => _pairToken != null;

  /// QR'a basılacak davet. Eşleşme kapalıysa null.
  Future<LanPairInvite?> pairInvite() async {
    final token = _pairToken;
    final id = _deviceId;
    if (token == null || id == null) return null;
    return LanPairInvite(
      deviceId: id,
      deviceName: _store.deviceName,
      addresses: await localAddresses(),
      port: port,
      pairToken: token,
      uid: await _currentUid() ?? '',
    );
  }

  /// Bu cihazın LAN adresleri — kullanıcı diğer cihaza elle yazabilsin diye.
  /// Loopback ve private olmayan adresler elenir.
  static Future<List<String>> localAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      return [
        for (final i in interfaces)
          for (final a in i.addresses)
            if (isPrivateAddress(a)) a.address,
      ];
    } catch (e) {
      debugPrint('[LanSync] arayüz listesi alınamadı: $e');
      return const [];
    }
  }

  // ── Yaşam döngüsü ─────────────────────────────────────────────────────

  Future<void> start() async {
    if (_http != null) return;
    _deviceId = await _store.deviceId();
    final uid = await _currentUid();
    _uidFingerprint = uid == null ? '' : uidFingerprint(uid);

    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, defaultPort);
    } on SocketException {
      // Port dolu — aynı makinedeki ikinci instance ya da başka bir tüketici.
      server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _http = server;
    server.listen(_handle, onError: (Object e) {
      debugPrint('[LanSync] sunucu hatası: $e');
    });
    await _startAnnounce();
    debugPrint('[LanSync] host dinliyor :${server.port}');
  }

  Future<void> stop() async {
    closeForPairing();
    _announceTimer?.cancel();
    _announceTimer = null;
    _announceSocket?.close();
    _announceSocket = null;
    await _http?.close(force: true);
    _http = null;
    _pairFailures.clear();
    _blocked.clear();
  }

  /// Panel açıldı: `/pair` ucunu aç, QR/PIN üret, TTL dolunca yenile.
  void openForPairing() {
    if (_pairToken != null) return;
    _rollPairToken();
    _pairTokenTimer =
        Timer.periodic(_pairTokenTtl, (_) => _rollPairToken());
  }

  /// Panel kapandı: `/pair` kapanır. Kurulmuş eşleşmeler etkilenmez.
  void closeForPairing() {
    _pairTokenTimer?.cancel();
    _pairTokenTimer = null;
    _pairToken = null;
    _pairNonce = null;
    _pairPin = null;
  }

  void _rollPairToken() {
    _pairToken = LanDeviceStore.newSecretHalf();
    _pairNonce = LanAuth.generateHostNonce();
    _pairPin = LanAuth.generatePin();
  }

  /// Tek uç, iki anahtar: QR token'ı ve PIN aynı `/pair` ucunu açar.
  /// Hangisi tutarsa geçer.
  List<LanAuth> _pairingAuths() {
    final nonce = _pairNonce;
    final token = _pairToken;
    final pin = _pairPin;
    if (nonce == null || token == null || pin == null) return const [];
    return [
      LanAuth(sessionKey: LanAuth.deriveSessionKey(token, nonce)),
      LanAuth(sessionKey: LanAuth.deriveSessionKey(pin, nonce)),
    ];
  }

  // ── Presence duyurusu ─────────────────────────────────────────────────

  Future<void> _startAnnounce() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      _announceSocket = socket;
      void send() {
        final id = _deviceId;
        if (id == null) return;
        try {
          socket.send(
            utf8.encode(LanAnnounce(
              deviceId: id,
              port: port,
              uidFingerprint: _uidFingerprint ?? '',
            ).encode()),
            InternetAddress('255.255.255.255'),
            LanAnnounce.discoveryPort,
          );
        } catch (e) {
          debugPrint('[LanSync] duyuru gönderilemedi: $e');
        }
      }

      send();
      _announceTimer = Timer.periodic(_announceInterval, (_) => send());
    } catch (e) {
      // Broadcast engelliyse `/ping` yolu ve elle adres hâlâ çalışır.
      debugPrint('[LanSync] presence duyurusu kapalı: $e');
    }
  }

  // ── HTTP ──────────────────────────────────────────────────────────────

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final remote = request.connectionInfo?.remoteAddress;
      if (remote == null || !isPrivateAddress(remote)) {
        await _reject(response, HttpStatus.forbidden, 'non-local peer');
        return;
      }

      final body = await _readBody(request);
      final path = request.uri.path;
      final method = request.method;

      // Elle `IP:port` ile bağlanan peer PIN'den anahtar türetmek için
      // nonce'a ihtiyaç duyar. Nonce tek başına hiçbir şey açmaz.
      if (method == 'GET' && path == '/hello') {
        await _sendJson(response, {
          'device': _store.deviceName,
          'device_id': _deviceId ?? '',
          'nonce': _pairNonce ?? '',
          'port': port,
          'pairing': isOpenForPairing,
        });
        return;
      }

      if (method == 'POST' && path == '/pair') {
        await _handlePair(request, response, body, remote.address);
        return;
      }

      // Buradan sonrası kalıcı eşleşme ister.
      final device = await _authenticate(request, body, path);
      if (device == null) {
        await _reject(response, HttpStatus.unauthorized, 'not paired');
        return;
      }
      // İstek geldi = cihaz ayakta; presence'i tazele.
      await _store.touchSeen(device.deviceId, '${remote.address}:${_peerPort(request, device)}');

      switch ('$method $path') {
        case 'GET /ping':
          await _sendJson(response, {'ok': true, 'device': _store.deviceName});
          return;
        case 'POST /unpair':
          await _store.remove(device.deviceId);
          await _sendJson(response, {'ok': true});
          return;
        case 'GET /manifest':
          await _sendJson(response, {
            'items': [for (final r in await _session.buildManifest()) r.toJson()],
          });
          return;
        case 'POST /media':
          final decoded = jsonDecode(utf8.decode(body));
          await _sendMedia(
            response,
            decoded is Map ? '${decoded['path'] ?? ''}' : '',
          );
          return;
        case 'POST /media/have':
          await _sendMissingMedia(response, body);
          return;
        case 'POST /media/put':
          await _receiveMedia(response, body);
          return;
      }

      final itemRef = _parseItemPath(path);
      if (itemRef != null && method == 'GET') {
        await _sendItem(response, itemRef);
        return;
      }
      if (itemRef != null && method == 'POST') {
        await _receiveItem(response, body);
        return;
      }

      await _reject(response, HttpStatus.notFound, 'no route');
    } catch (e, st) {
      debugPrint('[LanSync] istek hatası: $e\n$st');
      try {
        await _reject(response, HttpStatus.internalServerError, '$e');
      } catch (_) {
        // Yanıt zaten kapanmış olabilir.
      }
    }
  }

  /// Karşı tarafın dinlediği port — presence adresi için. Başlıkta gelmezse
  /// varsayılan porta düşülür.
  int _peerPort(HttpRequest request, PairedDevice device) {
    final raw = request.headers.value('X-DMT-Port');
    return int.tryParse(raw ?? '') ?? device.address?.port ?? defaultPort;
  }

  /// `X-DMT-Device` başlığındaki cihazı bulup imzayı onun kalıcı sırrıyla
  /// doğrular. Eşleşmemiş cihaz ya da bozuk imza → null.
  Future<PairedDevice?> _authenticate(
    HttpRequest request,
    List<int> body,
    String path,
  ) async {
    final deviceId = request.headers.value('X-DMT-Device');
    if (deviceId == null || deviceId.isEmpty) return null;
    final device = await _store.byId(deviceId);
    if (device == null) return null;
    final auth = _authFor(device);
    final ok = auth.verify(
      header: request.headers.value(HttpHeaders.authorizationHeader),
      method: request.method,
      path: path,
      body: body,
    );
    return ok ? device : null;
  }

  /// Cihaz başına [LanAuth] — nonce replay cache'i cihaz ömrü boyunca yaşasın
  /// diye önbelleklenir.
  final Map<String, LanAuth> _deviceAuths = {};
  LanAuth _authFor(PairedDevice device) => _deviceAuths.putIfAbsent(
        device.deviceId,
        () => LanAuth.fromSharedSecret(device.sharedSecret),
      );

  // ── Eşleşme ───────────────────────────────────────────────────────────

  Future<void> _handlePair(
    HttpRequest request,
    HttpResponse response,
    List<int> body,
    String remoteKey,
  ) async {
    if (!isOpenForPairing) {
      await _reject(response, HttpStatus.forbidden, 'pairing_closed');
      return;
    }
    final blockedUntil = _blocked[remoteKey];
    if (blockedUntil != null && DateTime.now().isBefore(blockedUntil)) {
      await _reject(response, HttpStatus.tooManyRequests, 'blocked');
      return;
    }

    final header = request.headers.value(HttpHeaders.authorizationHeader);
    final authorized = _pairingAuths().any((a) => a.verify(
          header: header,
          method: 'POST',
          path: '/pair',
          body: body,
        ));
    if (!authorized) {
      _notePairFailure(remoteKey);
      await _reject(response, HttpStatus.unauthorized, 'bad_pairing_secret');
      return;
    }
    _pairFailures.remove(remoteKey);

    final decoded = jsonDecode(utf8.decode(body));
    final req = decoded is Map
        ? LanPairRequest.fromJson(decoded.cast<String, dynamic>())
        : null;
    if (req == null) {
      await _reject(response, HttpStatus.badRequest, 'bad_pair_request');
      return;
    }

    // Aynı hesap zorunlu — başka bir hesabın cihazı eşleşemez.
    final myUid = await _currentUid();
    if (myUid == null || myUid.isEmpty || req.uid != myUid) {
      await _reject(response, HttpStatus.forbidden, 'account_mismatch');
      return;
    }

    final hostHalf = LanDeviceStore.newSecretHalf();
    final shared =
        deriveSharedSecret(clientHalf: req.half, hostHalf: hostHalf);
    final peerPort = int.tryParse(request.headers.value('X-DMT-Port') ?? '') ??
        defaultPort;
    await _store.upsert(
      deviceId: req.deviceId,
      name: req.deviceName,
      lastAddress: '$remoteKey:$peerPort',
      sharedSecret: shared,
    );
    _deviceAuths.remove(req.deviceId);

    await _sendJson(
      response,
      LanPairResponse(
        deviceId: _deviceId ?? '',
        deviceName: _store.deviceName,
        half: hostHalf,
      ).toJson(),
    );
    debugPrint('[LanSync] eşleşti: ${req.deviceName} (${req.deviceId})');
  }

  void _notePairFailure(String key) {
    final count = (_pairFailures[key] ?? 0) + 1;
    _pairFailures[key] = count;
    if (count >= _maxPairAttempts) {
      _blocked[key] = DateTime.now().add(_blockWindow);
      _pairFailures.remove(key);
      // Brute-force denemesi görüldü — QR ve PIN yakılır, kullanıcı ekranda
      // yenisini görür. Kurulmuş eşleşmeler etkilenmez.
      _rollPairToken();
      debugPrint('[LanSync] $key bloklandı, eşleşme sırrı yenilendi');
    }
  }

  // ── İçerik uçları ─────────────────────────────────────────────────────

  static Future<List<int>> _readBody(HttpRequest request) async {
    final chunks = <int>[];
    await for (final chunk in request) {
      chunks.addAll(chunk);
    }
    return chunks;
  }

  static ({LanItemType type, String id})? _parseItemPath(String path) {
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length != 3 || parts[0] != 'item') return null;
    final type = lanItemTypeFromWire(parts[1]);
    if (type == null) return null;
    return (type: type, id: Uri.decodeComponent(parts[2]));
  }

  Future<void> _sendItem(
    HttpResponse response,
    ({LanItemType type, String id}) target,
  ) async {
    final ref = (await _session.buildManifest())
        .firstWhereOrNull((r) => r.type == target.type && r.id == target.id);
    if (ref == null) {
      await _reject(response, HttpStatus.notFound, 'unknown item');
      return;
    }
    final payload = await _session.loadItem(ref);
    if (payload == null) {
      await _reject(response, HttpStatus.notFound, 'item vanished');
      return;
    }
    await _sendJson(response, payload.toJson());
  }

  Future<void> _receiveItem(HttpResponse response, List<int> body) async {
    final decoded = jsonDecode(utf8.decode(body));
    if (decoded is! Map) {
      await _reject(response, HttpStatus.badRequest, 'bad payload');
      return;
    }
    final item = LanItemPayload.fromJson(decoded.cast<String, dynamic>());
    if (item == null) {
      await _reject(response, HttpStatus.badRequest, 'bad item');
      return;
    }
    await _session.applyItem(item);
    await _sendJson(response, {'ok': true});
  }

  Future<void> _sendMissingMedia(
    HttpResponse response,
    List<int> body,
  ) async {
    final decoded = jsonDecode(utf8.decode(body));
    final raw = decoded is Map ? decoded['entries'] as List? : null;
    final missing = <String>[];
    for (final e in raw ?? const []) {
      if (e is! Map) continue;
      final entry = LanMediaEntry.fromJson(e.cast<String, dynamic>());
      if (entry == null) continue;
      if (!await _session.hasMedia(entry)) missing.add(entry.path);
    }
    await _sendJson(response, {'missing': missing});
  }

  Future<void> _receiveMedia(HttpResponse response, List<int> body) async {
    final decoded = jsonDecode(utf8.decode(body));
    if (decoded is! Map) {
      await _reject(response, HttpStatus.badRequest, 'bad media');
      return;
    }
    final entry = LanMediaEntry.fromJson(decoded.cast<String, dynamic>());
    final data = decoded['data'];
    if (entry == null || data is! String) {
      await _reject(response, HttpStatus.badRequest, 'bad media');
      return;
    }
    final bytes = base64Decode(data);
    // Bildirilen hash tutmuyorsa yazma — bozuk aktarım sessizce diske inmesin.
    if (sha256.convert(bytes).toString() != entry.sha256) {
      await _reject(response, HttpStatus.badRequest, 'sha mismatch');
      return;
    }
    await _session.writeMedia(entry, bytes);
    await _sendJson(response, {'ok': true});
  }

  Future<void> _sendMedia(HttpResponse response, String relativePath) async {
    final file = await _session.openMedia(relativePath);
    if (file == null) {
      await _reject(response, HttpStatus.notFound, 'no media');
      return;
    }
    response.headers.contentType = ContentType.binary;
    response.headers.contentLength = await file.length();
    await response.addStream(file.openRead());
    await response.close();
  }

  static Future<void> _sendJson(
    HttpResponse response,
    Map<String, dynamic> body,
  ) async {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  static Future<void> _reject(
    HttpResponse response,
    int status,
    String reason,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode({'error': reason}));
    await response.close();
  }
}

/// Yalnız yerel ağdan gelen bağlantılar kabul edilir. LAN sync'in tanımı bu —
/// internetten erişilebilen bir uç bırakmaz.
bool isPrivateAddress(InternetAddress address) {
  if (address.isLoopback) return true;
  if (address.type == InternetAddressType.IPv4) {
    final o = address.rawAddress;
    if (o.length != 4) return false;
    if (o[0] == 10) return true;
    if (o[0] == 172 && o[1] >= 16 && o[1] <= 31) return true;
    if (o[0] == 192 && o[1] == 168) return true;
    if (o[0] == 169 && o[1] == 254) return true; // link-local
    return false;
  }
  if (address.type == InternetAddressType.IPv6) {
    final o = address.rawAddress;
    if (o.length != 16) return false;
    if ((o[0] & 0xFE) == 0xFC) return true; // fc00::/7 unique-local
    if (o[0] == 0xFE && (o[1] & 0xC0) == 0x80) return true; // fe80::/10
    // IPv4-mapped (::ffff:a.b.c.d)
    if (o.take(10).every((b) => b == 0) && o[10] == 0xFF && o[11] == 0xFF) {
      return isPrivateAddress(
        InternetAddress.fromRawAddress(Uint8List.fromList(o.sublist(12))),
      );
    }
    return false;
  }
  return false;
}
