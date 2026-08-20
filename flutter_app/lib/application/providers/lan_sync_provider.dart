import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/lan_sync/lan_device_store.dart';
import '../services/lan_sync/lan_sync_client.dart';
import '../services/lan_sync/lan_sync_protocol.dart';
import '../services/lan_sync/lan_sync_server.dart';
import '../services/lan_sync/lan_sync_session.dart';
import 'auth_provider.dart';

enum LanSyncPhase { idle, syncing, done, error }

/// Eşleşme denemesinin sonucu — UI'ın gösterdiği mesajı seçer.
enum LanPairResult {
  ok,
  badQr,
  badAddress,
  noHostThere,
  badPin,
  accountMismatch,
  pairingClosed,
  notSignedIn,
  failed,
}

@immutable
class LanSyncState {
  const LanSyncState({
    this.phase = LanSyncPhase.idle,
    this.devices = const [],
    this.invite,
    this.pin,
    this.port = 0,
    this.addresses = const [],
    this.progressLabel,
    this.itemsSynced = 0,
    this.devicesSynced = 0,
    this.failures = const [],
    this.error,
  });

  final LanSyncPhase phase;

  /// Eşleşmiş cihazlar — `isOnline` presence'ten gelir.
  final List<PairedDevice> devices;

  /// Bu cihazın QR daveti. Panel açıkken dolu.
  final LanPairInvite? invite;

  /// QR okuyamayan cihazlar için elle giriş yedeği.
  final String? pin;
  final int port;
  final List<String> addresses;

  /// Sync sürerken "Barovia → Pixel-7" gibi tek satırlık ilerleme.
  final String? progressLabel;

  final int itemsSynced;
  final int devicesSynced;

  /// Ulaşılamayan ya da hata veren cihaz adları.
  final List<String> failures;

  final String? error;

  /// Elle girilecek adresler; hiç arayüz yoksa loopback en azından aynı
  /// makinede test için işe yarar.
  List<String> get manualAddresses => addresses.isEmpty
      ? ['127.0.0.1:$port']
      : [for (final a in addresses) '$a:$port'];

  LanSyncState copyWith({
    LanSyncPhase? phase,
    List<PairedDevice>? devices,
    LanPairInvite? invite,
    String? pin,
    int? port,
    List<String>? addresses,
    String? progressLabel,
    int? itemsSynced,
    int? devicesSynced,
    List<String>? failures,
    String? error,
  }) =>
      LanSyncState(
        phase: phase ?? this.phase,
        devices: devices ?? this.devices,
        invite: invite ?? this.invite,
        pin: pin ?? this.pin,
        port: port ?? this.port,
        addresses: addresses ?? this.addresses,
        progressLabel: progressLabel ?? this.progressLabel,
        itemsSynced: itemsSynced ?? this.itemsSynced,
        devicesSynced: devicesSynced ?? this.devicesSynced,
        failures: failures ?? this.failures,
        error: error ?? this.error,
      );
}

/// LAN sync v2 kontrolcüsü.
///
/// Üç sorumluluk:
///   1. **Host yaşam döngüsü** — giriş yapılmış ve eşleşme varsa (ya da panel
///      açıksa) sunucu + presence dinleyicisi ayakta.
///   2. **Eşleşme** — QR okundu / IP+PIN girildi → `/pair` el sıkışması →
///      iki tarafta da kalıcı kayıt.
///   3. **Sync** — tek tuşla **tüm** eşleşmiş cihazlarla sırayla eşleme.
class LanSyncController extends StateNotifier<LanSyncState> {
  LanSyncController(this._ref) : super(const LanSyncState());

  final Ref _ref;

  LanSyncServer? _server;
  LanPresenceListener? _presence;
  VoidCallback? _presenceListener;

  /// Panel açık mı — kapanınca eşleşme uçları da kapanır.
  bool _panelOpen = false;

  LanSyncSession get _session => _ref.read(lanSyncSessionProvider);
  LanDeviceStore get _store => _ref.read(lanDeviceStoreProvider);

  String? get _uid => _ref.read(authProvider)?.uid;

  // ── Host yaşam döngüsü ────────────────────────────────────────────────

  /// Oturum açılışında ve eşleşme değişimlerinde çağrılır.
  /// Giriş yoksa ya da hiç eşleşme yoksa (ve panel kapalıysa) sunucu kapanır —
  /// eşleşmesi olmayan kullanıcıda hiç soket açılmaz.
  Future<void> syncHostLifecycle() async {
    final signedIn = _uid != null;
    final shouldRun =
        signedIn && (_panelOpen || await _store.count() > 0);
    if (shouldRun) {
      await _startHost();
    } else {
      await _stopHost();
    }
  }

  Future<void> _startHost() async {
    if (_server != null) return;
    try {
      final server = LanSyncServer(
        session: _session,
        store: _store,
        currentUid: () async => _uid,
      );
      await server.start();
      _server = server;

      final presence = LanPresenceListener(_store);
      await presence.start();
      _presence = presence;
      _presenceListener = () => unawaited(refreshDevices());
      presence.tick.addListener(_presenceListener!);

      state = state.copyWith(port: server.port, error: '');
    } catch (e) {
      debugPrint('[LanSync] host başlatılamadı: $e');
      state = state.copyWith(phase: LanSyncPhase.error, error: '$e');
    }
  }

  Future<void> _stopHost() async {
    final listener = _presenceListener;
    if (listener != null) _presence?.tick.removeListener(listener);
    _presenceListener = null;
    await _presence?.stop();
    _presence = null;
    await _server?.stop();
    _server = null;
  }

  // ── Panel ─────────────────────────────────────────────────────────────

  /// Panel açıldı: sunucu ayağa kalkar, `/pair` açılır, QR üretilir.
  Future<void> openPanel() async {
    _panelOpen = true;
    await syncHostLifecycle();
    _server?.openForPairing();
    await refreshInvite();
    await refreshDevices();
    await pingAll();
  }

  /// Panel kapandı: `/pair` kapanır. Eşleşme varsa sunucu ayakta kalır.
  Future<void> closePanel() async {
    _panelOpen = false;
    _server?.closeForPairing();
    state = state.copyWith(phase: LanSyncPhase.idle);
    await syncHostLifecycle();
  }

  /// QR + PIN'i tazeler (token TTL'i dolduğunda UI bunu çağırır).
  Future<void> refreshInvite() async {
    final server = _server;
    if (server == null) return;
    state = state.copyWith(
      invite: await server.pairInvite(),
      pin: server.pairPin,
      port: server.port,
      addresses: await LanSyncServer.localAddresses(),
    );
  }

  Future<void> refreshDevices() async {
    state = state.copyWith(devices: await _store.list());
  }

  /// UDP engelliyse listenin ● göstergesi ölü kalırdı; panel açılışında saklı
  /// adreslere doğrudan `/ping` atarak ikinci bir yol bırakıyoruz.
  Future<void> pingAll() async {
    final devices = await _store.list();
    if (devices.isEmpty) return;
    final myDeviceId = await _store.deviceId();
    final myPort = _server?.port ?? LanSyncServer.defaultPort;
    for (final device in devices) {
      final client = LanSyncClient.forDevice(
        device,
        myDeviceId: myDeviceId,
        myPort: myPort,
      );
      if (client == null) continue;
      try {
        if (await client.ping()) {
          await _store.touchSeen(device.deviceId, device.lastAddress);
        }
      } finally {
        client.close();
      }
    }
    await refreshDevices();
  }

  // ── Eşleşme ───────────────────────────────────────────────────────────

  /// Kamera bir QR okudu. Sonuç + eşleşilen cihazın adı.
  Future<(LanPairResult, String)> pairWithQr(String? rawQrText) async {
    final invite = LanPairInvite.fromQrText(rawQrText);
    if (invite == null) return (LanPairResult.badQr, '');
    final uid = _uid;
    if (uid == null) return (LanPairResult.notSignedIn, '');
    // Karşı taraf başka hesapsa ağa hiç çıkma — QR zaten uid taşıyor.
    if (invite.uid != uid) return (LanPairResult.accountMismatch, '');
    return _pair(() async => LanPairing.viaInvite(
          invite,
          myDeviceId: await _store.deviceId(),
          myDeviceName: _store.deviceName,
          myUid: uid,
          myPort: _server?.port ?? LanSyncServer.defaultPort,
        ));
  }

  /// Elle `IP:port` + 6 haneli PIN.
  Future<(LanPairResult, String)> pairWithPin({
    required String address,
    required String pin,
  }) async {
    final parsed = parseLanAddress(address);
    if (parsed == null) return (LanPairResult.badAddress, '');
    final uid = _uid;
    if (uid == null) return (LanPairResult.notSignedIn, '');
    return _pair(() async => LanPairing.viaPin(
          host: parsed.host,
          port: parsed.port,
          pin: pin,
          myDeviceId: await _store.deviceId(),
          myDeviceName: _store.deviceName,
          myUid: uid,
          myPort: _server?.port ?? LanSyncServer.defaultPort,
        ));
  }

  Future<(LanPairResult, String)> _pair(
    Future<LanPairOutcome> Function() handshake,
  ) async {
    try {
      final outcome = await handshake();
      await _store.upsert(
        deviceId: outcome.deviceId,
        name: outcome.deviceName,
        lastAddress: outcome.address,
        sharedSecret: outcome.sharedSecret,
      );
      await syncHostLifecycle();
      await refreshDevices();
      return (LanPairResult.ok, outcome.deviceName);
    } on LanSyncException catch (e) {
      debugPrint('[LanSync] eşleşme reddedildi: $e');
      if (e.isAccountMismatch) return (LanPairResult.accountMismatch, '');
      if (e.isPairingClosed) return (LanPairResult.pairingClosed, '');
      if (e.isAuthFailure) return (LanPairResult.badPin, '');
      return (LanPairResult.noHostThere, '');
    } catch (e) {
      debugPrint('[LanSync] eşleşme hatası: $e');
      return (LanPairResult.failed, '');
    }
  }

  /// Çarpı: yerelden sil + karşı tarafa best-effort haber ver.
  Future<void> removeDevice(PairedDevice device) async {
    final myDeviceId = await _store.deviceId();
    final client = LanSyncClient.forDevice(
      device,
      myDeviceId: myDeviceId,
      myPort: _server?.port ?? LanSyncServer.defaultPort,
    );
    if (client != null) {
      try {
        await client.unpair();
      } catch (e) {
        // Karşı taraf kapalıysa kendi listesinde kalır; ilk imza hatasında
        // temizlenir. Yerel silme her hâlükârda yapılır.
        debugPrint('[LanSync] unpair bildirilemedi: $e');
      } finally {
        client.close();
      }
    }
    await _store.remove(device.deviceId);
    await refreshDevices();
    await syncHostLifecycle();
  }

  // ── Sync ──────────────────────────────────────────────────────────────

  /// Tek tuş: **tüm** eşleşmiş cihazlarla sırayla eşle.
  ///
  /// Ulaşılamayan cihaz akışı durdurmaz — sonunda listelenir. Presence'e
  /// güvenip offline görünenleri atlamıyoruz; UDP engelli ağlarda yanlış
  /// "offline" yüzünden sync hiç çalışmasın istemiyoruz.
  Future<void> syncAll() async {
    final devices = await _store.list();
    if (devices.isEmpty) return;

    final myDeviceId = await _store.deviceId();
    final myPort = _server?.port ?? LanSyncServer.defaultPort;

    state = state.copyWith(
      phase: LanSyncPhase.syncing,
      itemsSynced: 0,
      devicesSynced: 0,
      failures: const [],
      progressLabel: '',
      error: '',
    );

    final failures = <String>[];
    var itemsSynced = 0;
    var devicesSynced = 0;

    for (final device in devices) {
      final client = LanSyncClient.forDevice(
        device,
        myDeviceId: myDeviceId,
        myPort: myPort,
      );
      if (client == null) {
        failures.add(device.name);
        continue;
      }
      try {
        itemsSynced += await _syncWith(client, device);
        devicesSynced++;
        await _store.touchSeen(device.deviceId, device.lastAddress);
      } catch (e) {
        debugPrint('[LanSync] ${device.name} eşlenemedi: $e');
        failures.add(device.name);
      } finally {
        client.close();
      }
      state = state.copyWith(
        itemsSynced: itemsSynced,
        devicesSynced: devicesSynced,
        failures: failures,
      );
    }

    await refreshDevices();
    state = state.copyWith(
      phase: LanSyncPhase.done,
      progressLabel: '',
      itemsSynced: itemsSynced,
      devicesSynced: devicesSynced,
      failures: failures,
    );
  }

  /// Tek cihazla eşleme — v1'in plan/yürüt mantığı, önizleme adımı olmadan.
  Future<int> _syncWith(LanSyncClient client, PairedDevice device) async {
    final plan = diffManifests(
      local: await _session.buildManifest(),
      peer: await client.fetchManifest(),
    );
    var done = 0;

    for (final ref in plan.pull) {
      state = state.copyWith(progressLabel: '${ref.name} ← ${device.name}');
      await _pullOne(client, ref);
      done++;
    }
    for (final ref in plan.push) {
      state = state.copyWith(progressLabel: '${ref.name} → ${device.name}');
      await _pushOne(client, ref);
      done++;
    }
    return done;
  }

  Future<void> _pullOne(LanSyncClient client, LanItemRef ref) async {
    final item = await client.fetchItem(ref);
    for (final media in item.media) {
      if (await _session.hasMedia(media)) continue;
      await _session.writeMedia(media, await client.fetchMedia(media.path));
    }
    await _session.applyItem(item);
  }

  Future<void> _pushOne(LanSyncClient client, LanItemRef ref) async {
    final item = await _session.loadItem(ref);
    if (item == null) return;
    final missing = await client.missingMediaOnPeer(item.media);
    for (final media in item.media) {
      if (!missing.contains(media.path)) continue;
      final file = LanSyncSession.resolveMedia(media.path);
      if (file == null || !await file.exists()) continue;
      await client.uploadMedia(media, await file.readAsBytes());
    }
    await client.pushItem(item);
  }

  @override
  void dispose() {
    unawaited(_stopHost());
    super.dispose();
  }
}

final lanSyncControllerProvider =
    StateNotifierProvider<LanSyncController, LanSyncState>(
  LanSyncController.new,
);
