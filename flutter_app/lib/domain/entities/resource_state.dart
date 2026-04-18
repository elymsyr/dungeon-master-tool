// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'schema/event_kind.dart';

part 'resource_state.freezed.dart';
part 'resource_state.g.dart';

/// Resource havuzu — spell slot, hit dice, rage uses, channel divinity,
/// bardic inspiration, charges, concentration.
///
/// `current` kullanılmamış miktar, `max` tavan (genellikle rule-computed).
/// `expended = max - current` bilgi amaçlı (storage'da tutulmaz).
///
/// Örnekler:
/// - `spell_slot_1` max=4, current=2, refresh=longRest
/// - `hit_dice_d10` max=5, current=3, refresh=longRest (half recovery)
/// - `rage_uses` max=3 (Barbarian L3), refresh=longRest
/// - `concentration` max=1, current=0 or 1, refresh=never
@freezed
abstract class ResourceState with _$ResourceState {
  const factory ResourceState({
    required String resourceKey,
    @Default(0) int current,
    @Default(0) int max,
    @Default(RefreshRule.never) RefreshRule refreshRule,

    /// Serbest metadata — UI hint, custom refresh rule param, vb.
    @Default(<String, dynamic>{}) Map<String, dynamic> metadata,
  }) = _ResourceState;

  factory ResourceState.fromJson(Map<String, dynamic> json) =>
      _$ResourceStateFromJson(json);

  const ResourceState._();

  /// Kullanılmış miktar — derived.
  int get expended => max - current;

  /// Tamamen dolu mu.
  bool get isFull => current >= max;

  /// Tamamen boş mu.
  bool get isEmpty => current <= 0;
}
