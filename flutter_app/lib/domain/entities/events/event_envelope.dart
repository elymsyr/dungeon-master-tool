import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'event_envelope.freezed.dart';
part 'event_envelope.g.dart';

const _uuid = Uuid();

/// Wire-format event envelope — Python core/network/events.py EventEnvelope
/// ile birebir uyumlu. NetworkBridge bu modeli serialize edip gönderir.
@freezed
abstract class EventEnvelope with _$EventEnvelope {
  const factory EventEnvelope({
    required String eventId,
    required String eventType,
    String? sessionId,
    String? campaignId,
    required DateTime emittedAt,
    @Default({}) Map<String, dynamic> payload,
  }) = _EventEnvelope;

  /// Convenience factory — eventId ve emittedAt otomatik doldurulur.
  factory EventEnvelope.now(
    String eventType,
    Map<String, dynamic> payload, {
    String? sessionId,
    String? campaignId,
  }) {
    return EventEnvelope(
      eventId: _uuid.v4(),
      eventType: eventType,
      sessionId: sessionId,
      campaignId: campaignId,
      emittedAt: DateTime.now().toUtc(),
      payload: payload,
    );
  }

  factory EventEnvelope.fromJson(Map<String, dynamic> json) =>
      _$EventEnvelopeFromJson(json);
}
