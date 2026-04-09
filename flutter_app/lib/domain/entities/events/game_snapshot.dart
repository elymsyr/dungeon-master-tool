import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_snapshot.freezed.dart';
part 'game_snapshot.g.dart';

/// Tüm oyun state'inin tek bir serializable snapshot'ı.
/// "DM as Source of Truth" pattern: bağlantısı kopan oyuncu yeniden
/// bağlandığında DM bu snapshot'ı sync_request cevabı olarak yollar.
@freezed
abstract class GameSnapshot with _$GameSnapshot {
  const factory GameSnapshot({
    required String campaignId,
    required String snapshotId,
    required DateTime capturedAt,
    @Default(<String, dynamic>{}) Map<String, dynamic> entities,
    @Default(<String, dynamic>{}) Map<String, dynamic> combatState,
    @Default(<String, dynamic>{}) Map<String, dynamic> mapData,
    @Default(<String, dynamic>{}) Map<String, dynamic> mindMaps,
    @Default(<String, dynamic>{}) Map<String, dynamic> audioState,
  }) = _GameSnapshot;

  factory GameSnapshot.fromJson(Map<String, dynamic> json) =>
      _$GameSnapshotFromJson(json);
}
