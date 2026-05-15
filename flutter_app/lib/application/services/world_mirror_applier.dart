import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/online/world_role.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/character_provider.dart';
import '../providers/entity_share_provider.dart';
import '../providers/online_worlds_provider.dart';
import '../providers/role_provider.dart';
import '../providers/world_characters_provider.dart';
import '../providers/world_membership_provider.dart';
import 'world_mirror_service.dart';
import 'world_sync_service.dart';

/// CDC event'lerini local state'e uygular.
///
/// Sorumluluk:
///   - world_entities event → active campaign data['entities'] patch
///   - world_characters event → characterListProvider invalidate
///   - worlds event → campaign state_json reload
///
/// Self-echo (kendi push'umuzun event'i) `WorldMirrorService.isEchoOf`
/// ile filtrelenir.
class WorldMirrorApplier {
  final Ref ref;
  final WorldMirrorService mirror;
  final WorldSyncService sync;

  StreamSubscription<WorldSyncEvent>? _sub;

  WorldMirrorApplier({
    required this.ref,
    required this.mirror,
    required this.sync,
  });

  void start() {
    _sub ??= sync.events.listen(_onEvent);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Subscribe sonrası remote state'i local'a seed eder. Update event'i
  /// gibi davranır — fakat liste olarak gelir, tek transaction'da uygular.
  Future<void> applyInitialState(String worldId) async {
    final snapshot = await mirror.fetchInitialState(worldId);
    if (snapshot.entities.isEmpty && snapshot.characters.isEmpty) return;

    final activeCampaign = ref.read(activeCampaignProvider.notifier);
    final data = activeCampaign.data;
    if (data == null) return;

    if (snapshot.entities.isNotEmpty) {
      final raw = data['entities'];
      final Map<String, dynamic> entities;
      if (raw is Map<String, dynamic>) {
        entities = raw;
      } else {
        entities = <String, dynamic>{};
        data['entities'] = entities;
      }
      for (final row in snapshot.entities) {
        final id = row['id'] as String?;
        if (id == null) continue;
        entities[id] = _entityRowToBlob(row);
      }
    }

    if (snapshot.characters.isNotEmpty) {
      final notifier =
          ref.read(worldCharactersProvider(worldId).notifier);
      for (final row in snapshot.characters) {
        final mapped = _charRowFromCdc(row, fallbackWorldId: worldId);
        if (mapped != null) notifier.applyMirror(mapped);
      }
    }
    _bumpRevision();
  }

  Future<void> _onEvent(WorldSyncEvent e) async {
    if (mirror.isEchoOf(e)) return;
    try {
      switch (e.table) {
        case 'world_entities':
          _applyEntityEvent(e);
        case 'world_characters':
          _applyCharacterEvent(e);
        case 'worlds':
          _applyWorldsEvent(e);
        case 'entity_shares':
          ref.invalidate(worldEntitySharesProvider(e.worldId));
        case 'world_members':
          await _applyMembersEvent(e);
        // mind_map_*: PR-O8'de dedicated invalidations.
      }
    } catch (err, st) {
      debugPrint('WorldMirrorApplier error: $err\n$st');
    }
  }

  void _applyEntityEvent(WorldSyncEvent e) {
    final activeCampaign = ref.read(activeCampaignProvider.notifier);
    final data = activeCampaign.data;
    if (data == null) return;

    final raw = data['entities'];
    final Map<String, dynamic> entities;
    if (raw is Map<String, dynamic>) {
      entities = raw;
    } else {
      entities = <String, dynamic>{};
      data['entities'] = entities;
    }

    switch (e.eventType) {
      case PostgresChangeEvent.delete:
        final id = e.oldRecord['id'] as String?;
        if (id == null) return;
        if (entities.remove(id) != null) {
          _bumpRevision();
        }
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final id = e.newRecord['id'] as String?;
        if (id == null) return;
        entities[id] = _entityRowToBlob(e.newRecord);
        _bumpRevision();
      default:
        return;
    }
  }

  void _applyCharacterEvent(WorldSyncEvent e) {
    final notifier =
        ref.read(worldCharactersProvider(e.worldId).notifier);
    switch (e.eventType) {
      case PostgresChangeEvent.delete:
        final id = e.oldRecord['id'] as String?;
        if (id == null) return;
        notifier.removeMirror(id);
        // 039 model: DELETE = canonical row gone. RPC'ler `(NULL,NULL)`
        // CHECK violation olurdu yerine row'u siler. Hub-level local
        // Character da silinmeli (cross-device DELETE echo).
        // ignore: discarded_futures
        ref.read(characterListProvider.notifier).removeMirror(id);
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final row = _charRowFromCdc(e.newRecord, fallbackWorldId: e.worldId);
        if (row != null) notifier.applyMirror(row);
        // Note: hub-level Character mirror update (cross-device UPDATE
        // echo'su owner'ın diğer cihazına worldId/owner patch'ini akıtsın)
        // PR4'te eklenecek — şu an personal_characters CDC bu sorumluluğu
        // taşıyor; sadece self-owned chars için.
      default:
        return;
    }
  }

  WorldCharacterRow? _charRowFromCdc(
    Map<String, dynamic> row, {
    required String fallbackWorldId,
  }) {
    final id = row['id'] as String?;
    if (id == null) return null;
    final updatedRaw = row['updated_at'] as String?;
    return WorldCharacterRow(
      id: id,
      worldId: (row['world_id'] as String?) ?? fallbackWorldId,
      ownerId: row['owner_id'] as String?,
      templateId: (row['template_id'] as String?) ?? '',
      templateName: (row['template_name'] as String?) ?? '',
      payloadJson: (row['payload_json'] as String?) ?? '{}',
      updatedAt: updatedRaw == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.tryParse(updatedRaw) ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// world_members CDC: roster always refreshes. Role + hub world-list
  /// caches only refresh when the event is about *this* user — other-user
  /// joins/leaves don't change my role or my world list, so the previous
  /// unconditional invalidate cascade was wasted work that fanned out into
  /// `visibleEntityProvider` / sidebar rebuilds on every players-tab
  /// activity. Personal channel covers self-on-other-device events.
  Future<void> _applyMembersEvent(WorldSyncEvent e) async {
    // world_members PK is (world_id, user_id) — so DELETE oldRecord carries
    // user_id under default REPLICA IDENTITY.
    final eventUid =
        (e.newRecord['user_id'] ?? e.oldRecord['user_id']) as String?;
    final notifier =
        ref.read(worldMembersProvider(e.worldId).notifier);
    switch (e.eventType) {
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        // ignore: discarded_futures
        notifier.applyJoin(e.newRecord);
      case PostgresChangeEvent.delete:
        if (eventUid != null) notifier.applyLeave(eventUid);
      default:
        break;
    }
    final selfUid = ref.read(authProvider)?.uid;
    final isSelf = selfUid != null && eventUid == selfUid;
    if (isSelf) {
      ref.invalidate(worldRoleProvider(e.worldId));
      ref.invalidate(currentWorldRoleProvider);
      ref.invalidate(campaignInfoListProvider);
      ref.invalidate(campaignListProvider);
    }
    if (e.eventType != PostgresChangeEvent.delete) return;
    if (!isSelf) return;
    try {
      final role = await ref.read(worldRoleProvider(e.worldId).future);
      if (role == WorldRole.none) {
        await purgeLocalWorld(e.worldId);
      }
    } catch (err, st) {
      debugPrint('_applyMembersEvent role re-check error: $err\n$st');
    }
  }

  /// Public so the per-user sync applier can purge a world when the
  /// `world_members` DELETE event arrives via the personal channel (e.g.
  /// the user is logged in on another device and got kicked there).
  Future<void> purgeLocalWorld(String worldId) async {
    final list = ref.read(campaignInfoListProvider).valueOrNull;
    if (list == null) return;
    final match = list.where((c) => c.id == worldId).firstOrNull;
    if (match == null) return;
    final notifier = ref.read(activeCampaignProvider.notifier);
    await notifier.purge(match.name);
    ref.read(onlineWorldIdsProvider.notifier).remove(worldId);
    ref.invalidate(campaignListProvider);
    ref.invalidate(campaignInfoListProvider);
  }

  void _applyWorldsEvent(WorldSyncEvent e) {
    if (e.eventType != PostgresChangeEvent.update &&
        e.eventType != PostgresChangeEvent.insert) {
      return;
    }
    final activeCampaign = ref.read(activeCampaignProvider.notifier);
    final data = activeCampaign.data;
    if (data == null) return;
    final newState = e.newRecord['state_json'];
    if (newState is! String) return;
    try {
      final decoded = jsonDecode(newState);
      if (decoded is! Map<String, dynamic>) return;
      // entities alt-map'i normalde world_entities'ten patch'leniyor;
      // worlds.state_json sadece üst-düzey alanları (sessions, combat, vs.)
      // taşır. Bu sebeple entities'i koruyup geri kalanı ezerek replace.
      final entities = data['entities'];
      data
        ..clear()
        ..addAll(decoded);
      if (entities is Map<String, dynamic>) {
        data['entities'] = entities;
      }
      _bumpRevision();
    } catch (err) {
      debugPrint('_applyWorldsEvent decode error: $err');
    }
  }

  Map<String, dynamic> _entityRowToBlob(Map<String, dynamic> row) {
    Object? decode(dynamic raw, Object? fallback) {
      if (raw is String && raw.isNotEmpty) {
        try {
          return jsonDecode(raw);
        } catch (_) {
          return fallback;
        }
      }
      return fallback ?? raw;
    }

    final blob = <String, dynamic>{
      'name': row['name'],
      'type': row['category_slug'],
      'source': row['source'] ?? '',
      'description': row['description'] ?? '',
      'images': decode(row['images_json'], const []),
      'image_path': row['image_path'] ?? '',
      'tags': decode(row['tags_json'], const []),
      'dm_notes': row['dm_notes'] ?? '',
      'pdfs': decode(row['pdfs_json'], const []),
      'location_id': row['location_id'],
      'attributes': decode(row['fields_json'], const <String, dynamic>{}),
    };
    if (row['package_id'] != null) blob['package_id'] = row['package_id'];
    if (row['package_entity_id'] != null) {
      blob['package_entity_id'] = row['package_entity_id'];
    }
    if (row['linked'] == true) blob['linked'] = true;
    return blob;
  }

  void _bumpRevision() {
    final n = ref.read(campaignRevisionProvider.notifier);
    n.state = n.state + 1;
  }
}
