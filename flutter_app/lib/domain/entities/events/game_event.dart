// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../schema/event_kind.dart';

part 'game_event.freezed.dart';
part 'game_event.g.dart';

/// Rule engine V3'ün EventKind tabanlı event tipi.
///
/// Mevcut [AppEventBus] generic EventEnvelope kullanır (mind-map/encounter
/// notification'ları için). `GameEvent` rule-engine spesifik — `EventKind`
/// enum üzerinden trigger'lanır, payload event tipine göre şekillendirilir.
@freezed
abstract class GameEvent with _$GameEvent {
  const factory GameEvent({
    required EventKind kind,

    /// Event kaynağı entity id (spell caster, damaged creature, vb.).
    required String sourceEntityId,

    /// Hedef entity (attackHit için defender, heal için recipient) — opsiyonel.
    String? targetEntityId,

    /// Event-specific veri (slot_level, damage_amount, spell_id, vb.).
    @Default({}) Map<String, dynamic> payload,

    /// ISO-8601 timestamp — audit ve EventLog sırası için.
    String? timestamp,

    /// Cascade'den üretilen event'in derinliği (emit yaparken engine set eder).
    @Default(0) int cascadeDepth,
  }) = _GameEvent;

  factory GameEvent.fromJson(Map<String, dynamic> json) =>
      _$GameEventFromJson(json);
}
