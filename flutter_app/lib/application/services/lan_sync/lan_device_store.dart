import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';

/// Bir kez eşleşilmiş, kalıcı olarak hatırlanan cihaz.
@immutable
class PairedDevice {
  const PairedDevice({
    required this.deviceId,
    required this.name,
    required this.lastAddress,
    required this.sharedSecret,
    required this.pairedAt,
    required this.lastSeenAt,
  });

  final String deviceId;
  final String name;

  /// `"192.168.1.5:45456"`. Presence beacon'ı ile tazelenir.
  final String lastAddress;

  /// base64, iki cihazda aynı. Bütün istekler bununla imzalanır.
  final String sharedSecret;

  final DateTime pairedAt;
  final DateTime lastSeenAt;

  /// Son [onlineWindow] içinde duyulduysa çevrimiçi say.
  static const Duration onlineWindow = Duration(seconds: 15);

  bool get isOnline =>
      DateTime.now().difference(lastSeenAt) <= onlineWindow;

  ({String host, int port})? get address {
    final idx = lastAddress.lastIndexOf(':');
    if (idx <= 0) return null;
    final port = int.tryParse(lastAddress.substring(idx + 1));
    if (port == null) return null;
    return (host: lastAddress.substring(0, idx), port: port);
  }

  PairedDevice copyWith({String? name, String? lastAddress, DateTime? lastSeenAt}) =>
      PairedDevice(
        deviceId: deviceId,
        name: name ?? this.name,
        lastAddress: lastAddress ?? this.lastAddress,
        sharedSecret: sharedSecret,
        pairedAt: pairedAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );
}

/// Bu cihazın kalıcı kimliği + eşleşmiş cihaz kayıtları.
///
/// Kayıtlar `lan_paired_devices` yan tablosunda tutulur — şema
/// [AppDatabase] `beforeOpen`'daki raw DDL ile idempotent kurulur, codegen
/// ve schemaVersion bump'ı yok. Tablo per-user DB'de olduğu için eşleşmeler
/// **hesap başına** izole; başka hesaba girildiğinde liste boş gelir.
///
/// Cihaz kimliği (`deviceId`) hesaptan bağımsızdır — `shared_preferences`'ta
/// durur, böylece kullanıcı çıkış yapıp girse de karşı taraf aynı cihazı görür.
class LanDeviceStore {
  LanDeviceStore(this._db);

  final AppDatabase _db;

  static const _kDeviceIdKey = 'lan_sync_device_id';
  static const _uuid = Uuid();

  String? _cachedDeviceId;

  /// Bu kurulumun kalıcı kimliği. İlk çağrıda üretilip saklanır.
  Future<String> deviceId() async {
    final cached = _cachedDeviceId;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceIdKey);
    if (id == null || id.isEmpty) {
      id = _uuid.v4();
      await prefs.setString(_kDeviceIdKey, id);
    }
    _cachedDeviceId = id;
    return id;
  }

  /// Kullanıcıya ve karşı cihaza gösterilen ad.
  String get deviceName {
    try {
      final host = Platform.localHostname.trim();
      if (host.isNotEmpty) return host;
    } catch (_) {
      // Bazı sandbox'larda hostname okunamaz.
    }
    return Platform.operatingSystem;
  }

  // ── Eşleşmiş cihazlar ─────────────────────────────────────────────────

  Future<List<PairedDevice>> list() async {
    final rows = await _db.customSelect(
      'SELECT device_id, name, last_address, shared_secret, paired_at, '
      'last_seen_at FROM lan_paired_devices ORDER BY name COLLATE NOCASE',
    ).get();
    return rows.map(_fromRow).toList();
  }

  Future<PairedDevice?> byId(String deviceId) async {
    final rows = await _db.customSelect(
      'SELECT device_id, name, last_address, shared_secret, paired_at, '
      'last_seen_at FROM lan_paired_devices WHERE device_id = ?',
      variables: [Variable<String>(deviceId)],
    ).get();
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<int> count() async {
    final rows = await _db
        .customSelect('SELECT COUNT(*) AS c FROM lan_paired_devices')
        .get();
    return rows.isEmpty ? 0 : rows.first.read<int>('c');
  }

  /// Eşleşmeyi yazar/günceller. `shared_secret` yalnız eşleşme anında verilir;
  /// sonraki güncellemeler (ad, adres) onu korur.
  Future<void> upsert({
    required String deviceId,
    required String name,
    required String lastAddress,
    required String sharedSecret,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customStatement(
      'INSERT INTO lan_paired_devices '
      '(device_id, name, last_address, shared_secret, paired_at, last_seen_at) '
      'VALUES (?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(device_id) DO UPDATE SET '
      'name = excluded.name, '
      'last_address = excluded.last_address, '
      'shared_secret = excluded.shared_secret, '
      'last_seen_at = excluded.last_seen_at',
      [deviceId, name, lastAddress, sharedSecret, now, now],
    );
  }

  /// Presence: cihaz duyuldu — adresi ve son görülme anını tazele.
  Future<void> touchSeen(String deviceId, String address) async {
    await _db.customStatement(
      'UPDATE lan_paired_devices SET last_address = ?, last_seen_at = ? '
      'WHERE device_id = ?',
      [address, DateTime.now().millisecondsSinceEpoch, deviceId],
    );
  }

  Future<void> remove(String deviceId) async {
    await _db.customStatement(
      'DELETE FROM lan_paired_devices WHERE device_id = ?',
      [deviceId],
    );
  }

  static PairedDevice _fromRow(QueryRow r) => PairedDevice(
        deviceId: r.read<String>('device_id'),
        name: r.read<String>('name'),
        lastAddress: r.read<String>('last_address'),
        sharedSecret: r.read<String>('shared_secret'),
        pairedAt:
            DateTime.fromMillisecondsSinceEpoch(r.read<int>('paired_at')),
        lastSeenAt:
            DateTime.fromMillisecondsSinceEpoch(r.read<int>('last_seen_at')),
      );

  // ── Ortak sır üretimi ─────────────────────────────────────────────────

  static final Random _rng = Random.secure();

  /// El sıkışmada tarafların ürettiği 32 baytlık yarım.
  static String newSecretHalf() =>
      base64.encode(List<int>.generate(32, (_) => _rng.nextInt(256)));
}

final lanDeviceStoreProvider = Provider<LanDeviceStore>(
  (ref) => LanDeviceStore(ref.watch(appDatabaseProvider)),
);
