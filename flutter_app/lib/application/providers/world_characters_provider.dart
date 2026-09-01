import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/network/character_claim_service.dart';
import '../../data/repositories/character_repository.dart';
import 'character_claim_provider.dart';
import 'character_provider.dart';

/// public.world_characters projeksiyonu — UI'ya yetecek minimum bilgi.
/// `payloadJson` lazy decode için ham bırakılır; UI bunu ihtiyaç anında
/// `Character.fromJson` ile parse eder.
@immutable
class WorldCharacterRow {
  final String id;
  final String worldId;
  final String? ownerId;
  final String templateId;
  final String templateName;
  final String payloadJson;
  final DateTime updatedAt;

  const WorldCharacterRow({
    required this.id,
    required this.worldId,
    required this.ownerId,
    required this.templateId,
    required this.templateName,
    required this.payloadJson,
    required this.updatedAt,
  });

  WorldCharacterRow copyWith({
    String? ownerId,
    bool clearOwner = false,
    String? templateId,
    String? templateName,
    String? payloadJson,
    DateTime? updatedAt,
  }) {
    return WorldCharacterRow(
      id: id,
      worldId: worldId,
      ownerId: clearOwner ? null : (ownerId ?? this.ownerId),
      templateId: templateId ?? this.templateId,
      templateName: templateName ?? this.templateName,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorldCharacterRow &&
        other.id == id &&
        other.worldId == worldId &&
        other.ownerId == ownerId &&
        other.templateId == templateId &&
        other.templateName == templateName &&
        other.payloadJson == payloadJson &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        worldId,
        ownerId,
        templateId,
        templateName,
        payloadJson,
        updatedAt,
      );
}

/// `WorldCharactersNotifier` — bir world'ün tüm karakterlerini (RLS gereği
/// tüm üyeler okur) bellekte tutar. Bootstrap'te bir kez Supabase'i çekip,
/// sonrasında CDC event'lerini `applyMirror`/`removeMirror` ile granular
/// patch'ler. `characterListProvider`'ın yaptığı gibi full `loadAll()`
/// yapmaz — tek event tek diff.
class WorldCharactersNotifier
    extends StateNotifier<AsyncValue<List<WorldCharacterRow>>> {
  final CharacterClaimService? _service;
  final CharacterRepository _repo;
  final String worldId;

  WorldCharactersNotifier(this._service, this._repo, this.worldId)
      : super(const AsyncValue.loading());

  bool _bootstrapped = false;

  /// Bootstrap fetch uçarken `applyMirror` ile gelen id'ler. Publish anında
  /// [CharacterListNotifier.pushOwnedCharacters] iyimser satırları koyar ama
  /// bulut yazması henüz inmemiştir; merge etmezsek fetch sonucu bunları
  /// siler ve multiplayer'a geçince karakterler kaybolur.
  Set<String> _localDuringFetch = {};

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    // Yerel satırlar her zaman taban: paketlenmiş/katalogdan kurulan dünyanın
    // sahipsiz PC'leri sadece Drift'te duruyor, buluta hiç gitmiyor. Sadece
    // Supabase'i okursak offline'da (ve kurulumdan hemen sonra) liste boş
    // çıkıyordu.
    final local = await _localRows();
    state = AsyncValue.data(local);
    if (_service == null) return;
    try {
      _localDuringFetch = {};
      final rows = await _service.listWorldCharacters(worldId);
      final byId = {for (final r in local) r.id: r};
      for (final r in rows) {
        byId[r.id] = r;
      }
      for (final r in state.valueOrNull ?? const <WorldCharacterRow>[]) {
        if (_localDuringFetch.contains(r.id)) byId[r.id] = r;
      }
      final merged = byId.values.toList();
      merged.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      state = AsyncValue.data(rows);
    } catch (e, st) {
      debugPrint('WorldCharactersNotifier bootstrap error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Drift'teki `world_characters` satırları → UI satırı.
  Future<List<WorldCharacterRow>> _localRows() async {
    try {
      final chars = await _repo.loadAll();
      return [
        for (final c in chars)
          if (c.worldId == worldId)
            WorldCharacterRow(
              id: c.id,
              worldId: worldId,
              ownerId: c.ownerId,
              templateId: c.templateId,
              templateName: c.templateName,
              payloadJson: jsonEncode(c.toJson()),
              updatedAt: DateTime.tryParse(c.updatedAt) ??
                  DateTime.fromMillisecondsSinceEpoch(0),
            ),
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return const [];
    }
  }

  /// CDC INSERT/UPDATE veya manuel UI refresh'i için granular upsert.
  void applyMirror(WorldCharacterRow row) {
    if (row.worldId != worldId) return;
    _localDuringFetch.add(row.id);
    final list = [...(state.valueOrNull ?? const <WorldCharacterRow>[])];
    final idx = list.indexWhere((r) => r.id == row.id);
    if (idx >= 0) {
      // Byte-identical payload → no-op (echo de-dupe).
      if (list[idx] == row) return;
      list[idx] = row;
    } else {
      list.add(row);
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = AsyncValue.data(list);
  }

  /// CDC DELETE için granular remove.
  void removeMirror(String id) {
    final list = state.valueOrNull;
    if (list == null) return;
    final idx = list.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    state = AsyncValue.data(
      [for (var i = 0; i < list.length; i++) if (i != idx) list[i]],
    );
  }

  /// World purge edildiğinde (kick/leave) state'i temizlemek için.
  void clear() {
    _bootstrapped = false;
    state = const AsyncValue.data([]);
  }

  /// Manuel refresh — RLS değişimi, conflict resolution gibi durumlar için.
  Future<void> refresh() async {
    _bootstrapped = false;
    await bootstrap();
  }
}

/// `worldCharactersProvider(worldId)` — Player Character Tab + DM sidebar'ın
/// "bu world'deki tüm karakterler" görünümü için tek doğru kaynak. Personal
/// sync ile karışmaz; local Drift'e yazmaz. Otomatik bootstrap subscribe
/// anında tetiklenir.
final worldCharactersProvider = StateNotifierProvider.family<
    WorldCharactersNotifier,
    AsyncValue<List<WorldCharacterRow>>,
    String>((ref, worldId) {
  final svc = ref.watch(characterClaimServiceProvider);
  final notifier = WorldCharactersNotifier(
      svc, ref.watch(characterRepositoryProvider), worldId);
  // Subscribe sonrası bootstrap fire-and-forget.
  // ignore: discarded_futures
  notifier.bootstrap();
  return notifier;
});
