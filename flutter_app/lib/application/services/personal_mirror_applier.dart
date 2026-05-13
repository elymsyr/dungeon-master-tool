import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/character.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/character_provider.dart';
import '../providers/online_worlds_provider.dart';
import '../providers/package_provider.dart';
import '../providers/personal_online_provider.dart';
import '../providers/role_provider.dart';
import 'personal_sync_service.dart';
import 'world_mirror_applier.dart';
import 'world_mirror_service.dart';

/// `PersonalSyncService.events` stream'ini local state'e uygular.
///
/// Sorumluluk:
///   - `personal_characters` INSERT/UPDATE → local JSON dosyaya yaz +
///     `characterListProvider` invalidate. DELETE → local dosyayı kaldır.
///   - `personal_packages` INSERT/UPDATE → `PackageRepository.save` +
///     listeleri invalidate; aktif paketse data'yı in-memory replace.
///   - `world_members` INSERT (self) → `onlineWorldIdsProvider.add` +
///     hub world list refresh. DELETE (self) → karşılığı yoksa local
///     world'ü purge et (DM-kick on başka cihaz senaryosu).
///
/// Echo'ları `WorldMirrorService._lastPushedAt` map'i üzerinden filtreler;
/// böylece push → CDC → reapply döngüsü olmaz.
class PersonalMirrorApplier {
  final Ref ref;
  final PersonalSyncService service;
  final WorldMirrorService mirror;
  final WorldMirrorApplier? worldApplier;

  StreamSubscription<PersonalSyncEvent>? _sub;
  String? _bootstrappedFor;

  PersonalMirrorApplier({
    required this.ref,
    required this.service,
    required this.mirror,
    this.worldApplier,
  });

  void start() {
    _sub ??= service.events.listen(_onEvent);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _bootstrappedFor = null;
  }

  /// Subscribe sonrası local state'i sunucu ile aynı hizaya getirir.
  /// `personal_characters` / `personal_packages` satırlarını full pull eder
  /// — yeni cihaza ilk giriş için bootstrap. Aynı uid için idempotent;
  /// auth değişmediği sürece tekrar SELECT yapmaz.
  Future<void> bootstrap() async {
    final auth = ref.read(authProvider);
    if (auth == null) return;
    if (_bootstrappedFor == auth.uid) return;
    _bootstrappedFor = auth.uid;
    final client = Supabase.instance.client;
    try {
      final rows = await client
          .from('personal_characters')
          .select('id, payload_json')
          .eq('owner_id', auth.uid);
      final list = rows as List;
      for (final raw in list) {
        final row = raw as Map;
        final id = row['id'] as String?;
        if (id == null) continue;
        final payload = row['payload_json'];
        if (payload is String && payload.isNotEmpty) {
          // _writeCharacterFromPayload now applies granularly (no full reload).
          await _writeCharacterFromPayload(payload);
        }
      }
    } catch (e) {
      debugPrint('PersonalMirrorApplier bootstrap chars error: $e');
    }

    try {
      final rows = await client
          .from('personal_packages')
          .select('package_name, state_json')
          .eq('owner_id', auth.uid);
      final list = rows as List;
      var any = false;
      for (final raw in list) {
        final row = raw as Map;
        final name = row['package_name'] as String?;
        final state = row['state_json'];
        if (name == null || state is! String) continue;
        await _writePackageFromState(name, state);
        any = true;
      }
      if (any) {
        ref.invalidate(packageListProvider);
      }
    } catch (e) {
      debugPrint('PersonalMirrorApplier bootstrap packages error: $e');
    }
  }

  Future<void> _onEvent(PersonalSyncEvent e) async {
    try {
      switch (e.table) {
        case 'personal_characters':
          await _applyCharacterEvent(e);
        case 'personal_packages':
          await _applyPackageEvent(e);
        case 'world_members':
          await _applyMembersEvent(e);
      }
    } catch (err, st) {
      debugPrint('PersonalMirrorApplier error: $err\n$st');
    }
  }

  Future<void> _applyCharacterEvent(PersonalSyncEvent e) async {
    switch (e.eventType) {
      case PostgresChangeEvent.delete:
        final id = e.oldRecord['id'] as String?;
        if (id == null) return;
        if (mirror.isEchoOfId(id)) return;
        ref
            .read(personalOnlineCharIdsProvider.notifier)
            .remove(id);
        // Granular delete — repo + state in one notifier call, no full reload.
        await ref.read(characterListProvider.notifier).removeMirror(id);
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final id = e.newRecord['id'] as String?;
        if (id == null) return;
        if (mirror.isEchoOfId(id)) return;
        ref.read(personalOnlineCharIdsProvider.notifier).add(id);
        final payload = e.newRecord['payload_json'];
        if (payload is! String || payload.isEmpty) return;
        await _writeCharacterFromPayload(payload);
      default:
        return;
    }
  }

  Future<void> _writeCharacterFromPayload(String payload) async {
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final character = Character.fromJson(map);
      // applyMirror persists to disk AND patches the in-memory state in
      // place, replacing the previous `repo.save + invalidate` pattern that
      // forced a full `loadAll()` from disk per CDC event.
      await ref.read(characterListProvider.notifier).applyMirror(character);
    } catch (e) {
      debugPrint('_writeCharacterFromPayload error: $e');
    }
  }

  Future<void> _applyPackageEvent(PersonalSyncEvent e) async {
    switch (e.eventType) {
      case PostgresChangeEvent.delete:
        final name = e.oldRecord['package_name'] as String?;
        if (name == null) return;
        if (mirror.isEchoOfPackage(name)) return;
        ref
            .read(personalOnlinePackageNamesProvider.notifier)
            .remove(name);
        try {
          final repo = ref.read(packageRepositoryProvider);
          await repo.delete(name);
        } catch (err) {
          debugPrint('personal_package delete local error: $err');
        }
        ref.invalidate(packageListProvider);
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final name = e.newRecord['package_name'] as String?;
        if (name == null) return;
        if (mirror.isEchoOfPackage(name)) return;
        ref
            .read(personalOnlinePackageNamesProvider.notifier)
            .add(name);
        final state = e.newRecord['state_json'];
        if (state is! String) return;
        await _writePackageFromState(name, state);
        ref.invalidate(packageListProvider);
      default:
        return;
    }
  }

  Future<void> _writePackageFromState(String name, String stateJson) async {
    try {
      final decoded = jsonDecode(stateJson);
      if (decoded is! Map<String, dynamic>) return;
      final repo = ref.read(packageRepositoryProvider);
      await repo.save(name, decoded);
      // If this package is currently open in the editor, swap in the
      // new data so the user sees the change without a manual reopen.
      final active = ref.read(activePackageProvider);
      if (active == name) {
        await ref
            .read(activePackageProvider.notifier)
            .replaceWithData(decoded);
      }
    } catch (e) {
      debugPrint('_writePackageFromState error: $e');
    }
  }

  /// `world_members` CDC kullanıcının kendi user_id'si üzerinden filtreli
  /// gelir; INSERT → bu cihaz başka cihazda yapılan join'i öğrenir,
  /// DELETE → kick edildi veya başka cihazda leave yapıldı.
  Future<void> _applyMembersEvent(PersonalSyncEvent e) async {
    final worldId =
        (e.newRecord['world_id'] ?? e.oldRecord['world_id']) as String?;
    if (worldId == null) return;
    switch (e.eventType) {
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        ref.read(onlineWorldIdsProvider.notifier).add(worldId);
        ref.invalidate(worldRoleProvider(worldId));
        ref.invalidate(currentWorldRoleProvider);
        ref.invalidate(campaignInfoListProvider);
        ref.invalidate(campaignListProvider);
      case PostgresChangeEvent.delete:
        ref.read(onlineWorldIdsProvider.notifier).remove(worldId);
        ref.invalidate(worldRoleProvider(worldId));
        ref.invalidate(currentWorldRoleProvider);
        ref.invalidate(campaignInfoListProvider);
        ref.invalidate(campaignListProvider);
        // Local mirror'ı temizle — başka cihazda leave/kick edildikse bu
        // cihazda ölü dünya kalmasın.
        try {
          await worldApplier?.purgeLocalWorld(worldId);
        } catch (err) {
          debugPrint('personal_members purgeLocalWorld error: $err');
        }
      default:
        return;
    }
  }
}
