import 'package:freezed_annotation/freezed_annotation.dart';

import 'applied_effect.dart';
import 'choice_state.dart';
import 'resource_state.dart';
import 'turn_state.dart';

part 'entity.freezed.dart';
part 'entity.g.dart';

/// Schema-driven entity. Tüm tip-spesifik veriler [fields] map'inde saklanır.
///
/// V3 alanları (`resources`, `choices`, `turnState`, `activeEffects`) default'ları
/// boş/null olduğundan V2 JSON'ları otomatik olarak yeni modele deserialize olur.
@freezed
abstract class Entity with _$Entity {
  const factory Entity({
    required String id,
    @Default('New Record') String name,
    required String categorySlug,
    @Default('') String source,
    @Default('') String description,
    @Default([]) List<String> images,
    @Default('') String imagePath,
    @Default([]) List<String> tags,
    @Default('') String dmNotes,
    @Default([]) List<String> pdfs,
    String? locationId,
    @Default({}) Map<String, dynamic> fields,

    // ── V3: Rule Engine State ─────────────────────────────────────────────────

    /// Resource pool'ları (spell slots, hit dice, rage uses, concentration, ...).
    /// Key = resourceKey (örn. 'spell_slot_1', 'hit_dice_d10').
    @Default(<String, ResourceState>{}) Map<String, ResourceState> resources,

    /// Kullanıcı seçimleri (species_lineage, fighting_style, expertise, ...).
    /// Key = choiceKey.
    @Default(<String, ChoiceState>{}) Map<String, ChoiceState> choices,

    /// Encounter içi turn state. Encounter dışında null.
    TurnState? turnState,

    /// Aktif buff/debuff/condition listesi.
    @Default(<AppliedEffect>[]) List<AppliedEffect> activeEffects,
  }) = _Entity;

  factory Entity.fromJson(Map<String, dynamic> json) =>
      _$EntityFromJson(json);
}
