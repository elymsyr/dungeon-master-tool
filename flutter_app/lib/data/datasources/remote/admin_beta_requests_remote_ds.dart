import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/parse_utils.dart';

class BetaRequestEntry {
  final String userId;
  final String? email;
  final String? username;
  final String? message;
  final DateTime requestedAt;

  const BetaRequestEntry({
    required this.userId,
    required this.email,
    required this.username,
    required this.message,
    required this.requestedAt,
  });

  factory BetaRequestEntry.fromRow(Map<String, dynamic> row) => BetaRequestEntry(
        userId: row['user_id'] as String,
        email: row['email'] as String?,
        username: row['username'] as String?,
        message: row['message'] as String?,
        requestedAt: parseIsoOrNow(row['requested_at']),
      );
}

class BetaParticipantEntry {
  final String userId;
  final String? email;
  final String? username;
  final int? slotNumber;
  final DateTime joinedAt;
  final DateTime lastActiveAt;
  final int usedBytes;
  final int quotaBytes;
  final String? appVersion;
  final String? platform;
  final DateTime? profileLastActiveAt;

  const BetaParticipantEntry({
    required this.userId,
    required this.email,
    required this.username,
    required this.slotNumber,
    required this.joinedAt,
    required this.lastActiveAt,
    required this.usedBytes,
    required this.quotaBytes,
    required this.appVersion,
    required this.platform,
    required this.profileLastActiveAt,
  });

  factory BetaParticipantEntry.fromRow(Map<String, dynamic> row) =>
      BetaParticipantEntry(
        userId: row['user_id'] as String,
        email: row['email'] as String?,
        username: row['username'] as String?,
        slotNumber: (row['slot_number'] as num?)?.toInt(),
        joinedAt: parseIsoOrNow(row['joined_at']),
        lastActiveAt: parseIsoOrNow(row['last_active_at']),
        usedBytes: (row['used_bytes'] as num?)?.toInt() ?? 0,
        quotaBytes: (row['quota_bytes'] as num?)?.toInt() ?? 0,
        appVersion: row['app_version'] as String?,
        platform: row['platform'] as String?,
        profileLastActiveAt: row['profile_last_active_at'] == null
            ? null
            : DateTime.tryParse(row['profile_last_active_at'].toString()),
      );
}

enum BetaApproveStatus { granted, already, full, notPending, invalidUser, error }

class BetaApproveResult {
  final BetaApproveStatus status;
  final int? assignedSlot;
  final int slotsRemaining;
  const BetaApproveResult({
    required this.status,
    this.assignedSlot,
    this.slotsRemaining = 0,
  });
}

class AdminBetaRequestsRemoteDataSource {
  SupabaseClient get _sb => Supabase.instance.client;

  Future<List<BetaRequestEntry>> list() async {
    final rows = await _sb.rpc('admin_list_beta_requests');
    if (rows is! List) return const [];
    return rows
        .map((r) => BetaRequestEntry.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<BetaApproveResult> approve(String userId) async {
    final res = await _sb.rpc('admin_approve_beta_request',
        params: {'p_user': userId});
    final row = (res is List && res.isNotEmpty)
        ? res.first as Map<String, dynamic>
        : (res is Map ? res as Map<String, dynamic> : null);
    if (row == null) {
      return const BetaApproveResult(status: BetaApproveStatus.error);
    }
    return BetaApproveResult(
      status: _parse(row['status'] as String? ?? 'error'),
      assignedSlot: (row['assigned_slot'] as num?)?.toInt(),
      slotsRemaining: (row['slots_remaining'] as num?)?.toInt() ?? 0,
    );
  }

  Future<bool> reject(String userId) async {
    final res = await _sb.rpc('admin_reject_beta_request',
        params: {'p_user': userId});
    return res == true || (res is List && res.isNotEmpty && res.first == true);
  }

  Future<List<BetaParticipantEntry>> listParticipants() async {
    final rows = await _sb.rpc('admin_list_beta_participants');
    if (rows is! List) return const [];
    return rows
        .map((r) => BetaParticipantEntry.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Admin revoke — `beta_purge_with_cleanup` Edge Function üzerinden
  /// orkestre edilir: DB satırları (admin_revoke_beta RPC) + Supabase
  /// Storage `{userId}/` + R2 `{userId}/` + `transient/{userId}/`. Önceden
  /// yalnızca RPC çağrılıyordu, Storage/R2 öksüz kalıyordu.
  Future<bool> revoke(String userId) async {
    try {
      final res = await _sb.functions.invoke(
        'beta_purge_with_cleanup',
        body: {'user_id': userId},
      );
      // Edge Function 200 + body.ok döner; status diğer hatalarda fail.
      final data = res.data;
      if (data is Map && data['ok'] == true) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  BetaApproveStatus _parse(String s) {
    switch (s) {
      case 'granted':
        return BetaApproveStatus.granted;
      case 'already':
        return BetaApproveStatus.already;
      case 'full':
        return BetaApproveStatus.full;
      case 'not_pending':
        return BetaApproveStatus.notPending;
      case 'invalid_user':
        return BetaApproveStatus.invalidUser;
      default:
        return BetaApproveStatus.error;
    }
  }
}
