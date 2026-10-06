import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/combat_provider.dart';
import '../../../application/providers/locale_provider.dart';
import '../../../application/providers/profile_provider.dart';
import '../../../application/providers/role_provider.dart';
import '../../../application/providers/world_membership_provider.dart';
import '../../../application/providers/world_sync_provider.dart';
import '../../../core/config/supabase_config.dart';
import '../../../domain/entities/online/world_role.dart';
import '../../l10n/app_localizations.dart';

/// What a roll was for; names it in the session log.
enum DiceRollKind { roll, skill, save }

/// One session log line for a roll, e.g.
/// "elymsyr (Thorin) — Stealth check: 17 (d20: 12 + 5)".
String diceLogLine(
  L10n l10n, {
  String? user,
  String? character,
  required DiceRollKind kind,
  String? label,
  required int total,
  required String detail,
}) {
  final who = [?user, if (character != null) '($character)'].join(' ');
  final what = switch (kind) {
    DiceRollKind.skill => l10n.diceLogCheck(label ?? ''),
    DiceRollKind.save => l10n.diceLogSave(label ?? ''),
    DiceRollKind.roll => label ?? l10n.diceLogRoll,
  };
  return '${who.isEmpty ? '' : '$who — '}$what: $total ($detail)';
}

/// Writes a landed roll to the session log of the open world. The DM's own
/// rolls (and an offline user's) go straight into it; a player's go through
/// `log_dice_roll` (migration 106) and land in [dmDiceLogProvider].
final diceLoggerProvider = Provider<DiceLogger>((ref) => DiceLogger(ref));

class DiceLogger {
  DiceLogger(this._ref);
  final Ref _ref;

  Future<void> log({
    required DiceRollKind kind,
    String? label,
    String? character,
    required int total,
    required String detail,
  }) async {
    final worldId = _ref.read(activeCampaignIdProvider).valueOrNull;
    if (worldId == null) return;
    final role = _ref.read(currentWorldRoleProvider).valueOrNull;
    if (role == WorldRole.player) {
      if (!SupabaseConfig.isConfigured) return;
      // A free roll is the player's own character's.
      final uid = _ref.read(authProvider)?.uid;
      character ??= _ref
          .read(combatCharactersProvider)
          .where((c) => c.worldId == worldId && c.ownerId == uid)
          .firstOrNull
          ?.entity
          .name;
      try {
        await Supabase.instance.client.rpc('log_dice_roll', params: {
          'p_world_id': worldId,
          'p_character': character,
          'p_kind': kind.name,
          'p_label': label,
          'p_total': total,
          'p_detail': detail,
        });
      } catch (e) {
        debugPrint('DiceLogger: $e');
      }
      return;
    }
    _ref.read(combatProvider.notifier).addLog(diceLogLine(
          lookupL10n(_ref.read(localeProvider)),
          user: _ref.read(currentProfileProvider).valueOrNull?.username,
          character: character,
          kind: kind,
          label: label,
          total: total,
          detail: detail,
        ));
  }
}

/// DM side, installed by the main screen: players' rolls (`world_dice_rolls`
/// INSERTs) into the session log, under the player's username.
final dmDiceLogProvider = Provider<void>((ref) {
  if (!SupabaseConfig.isConfigured) return;
  final worldId = ref.watch(activeCampaignIdProvider).valueOrNull;
  final isDm = ref.watch(currentWorldRoleProvider).valueOrNull == WorldRole.dm;
  final sync = ref.watch(worldSyncServiceProvider);
  if (worldId == null || !isDm || sync == null) return;

  final sub = sync.events
      .where((e) =>
          e.worldId == worldId &&
          e.table == 'world_dice_rolls' &&
          e.eventType == PostgresChangeEvent.insert)
      .listen((e) {
    final r = e.newRecord;
    final total = r['total'], detail = r['detail'];
    if (total is! num || detail is! String) return;
    final member = (ref.read(worldMembersProvider(worldId)).valueOrNull ?? const [])
        .where((m) => m.userId == r['user_id'])
        .firstOrNull;
    ref.read(combatProvider.notifier).addLog(diceLogLine(
          lookupL10n(ref.read(localeProvider)),
          user: member?.username ?? member?.displayName,
          character: r['character'] as String?,
          kind: DiceRollKind.values.asNameMap()[r['kind']] ?? DiceRollKind.roll,
          label: r['label'] as String?,
          total: total.toInt(),
          detail: detail,
        ));
  });
  ref.onDispose(() => unawaited(sub.cancel()));
});
