import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/campaign_provider.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/session_repository.dart';

class SessionRepositoryImpl implements SessionRepository {
  final ActiveCampaignNotifier _campaign;

  SessionRepositoryImpl(this._campaign);

  @override
  Map<String, dynamic>? loadCombatState() {
    final data = _campaign.data;
    if (data == null) return null;
    final raw = data['combat_state'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  @override
  void saveCombatState(Map<String, dynamic> state) {
    final data = _campaign.data;
    if (data == null) return;
    data['combat_state'] = state;
  }

  @override
  List<Session> loadSessions() {
    final data = _campaign.data;
    if (data == null) return [];
    final raw = data['sessions'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) {
            try {
              return Session.fromJson(Map<String, dynamic>.from(m));
            } catch (_) {
              return null;
            }
          })
          .whereType<Session>()
          .toList();
    }
    return [];
  }

  @override
  void saveSession(Session session) {
    final data = _campaign.data;
    if (data == null) return;
    final sessions = data['sessions'] as List? ?? [];
    final index = sessions.indexWhere((s) => s is Map && s['id'] == session.id);
    final sessionJson = session.toJson();
    if (index >= 0) {
      sessions[index] = sessionJson;
    } else {
      sessions.add(sessionJson);
    }
    data['sessions'] = sessions;
  }

  @override
  void deleteSession(String sessionId) {
    final data = _campaign.data;
    if (data == null) return;
    final sessions = data['sessions'] as List? ?? [];
    sessions.removeWhere((s) => s is Map && s['id'] == sessionId);
    data['sessions'] = sessions;
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final campaign = ref.watch(activeCampaignProvider.notifier);
  return SessionRepositoryImpl(campaign);
});
