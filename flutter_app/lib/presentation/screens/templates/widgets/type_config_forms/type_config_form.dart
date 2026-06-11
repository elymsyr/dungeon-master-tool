import 'package:flutter/material.dart';

import '../../../../../domain/entities/schema/field_schema.dart';
import '../../../../theme/dm_tool_colors.dart';
import 'ability_score_table_form.dart';
import 'action_button_form.dart';
import 'combat_stats_form.dart';
import 'level_up_table_form.dart';
import 'pouch_config_form.dart';
import 'record_list_columns_form.dart';
import 'skill_tree_form.dart';

/// Dispatches a field to its per-type `typeConfig` sub-form (PR-2.2b). Mounted
/// by the inspector's `_FieldEditForm` in place of the read-only config JSON.
/// Returns an empty box for non-parametric types (scalars, media, relation,
/// levelMatrix, level tables, CR calculator) — they have no parametric payload.
///
/// Legacy v2 aliases (`statBlock`, `combatStats`, `slot`, `proficiencyTable`,
/// `spellSlotGrid`) route to their v3 form so a copied built-in stays editable
/// before the PR-2.3 renderer swap.
class TypeConfigForm extends StatelessWidget {
  final FieldSchema field;
  final DmToolColors palette;

  const TypeConfigForm({super.key, required this.field, required this.palette});

  /// Whether [type] has a dedicated config form — lets the inspector decide
  /// whether to render the "Type configuration" heading.
  static bool hasFormFor(FieldType type) {
    switch (type) {
      case FieldType.abilityScoreTable:
      case FieldType.statBlock:
      case FieldType.combatStatsTable:
      case FieldType.combatStats:
      case FieldType.intPouch:
      case FieldType.checkboxPouch:
      case FieldType.slot:
      case FieldType.pouchMatrix:
      case FieldType.spellSlotGrid:
      case FieldType.skillTree:
      case FieldType.proficiencyTable:
      case FieldType.recordList:
      case FieldType.levelUpTable:
      case FieldType.actionButton:
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (field.fieldType) {
      case FieldType.abilityScoreTable:
      case FieldType.statBlock:
        return AbilityScoreTableForm(field: field, palette: palette);
      case FieldType.combatStatsTable:
      case FieldType.combatStats:
        return CombatStatsForm(field: field, palette: palette);
      case FieldType.intPouch:
      case FieldType.checkboxPouch:
      case FieldType.slot:
      case FieldType.pouchMatrix:
      case FieldType.spellSlotGrid:
        return PouchConfigForm(field: field, palette: palette);
      case FieldType.skillTree:
      case FieldType.proficiencyTable:
        return SkillTreeForm(field: field, palette: palette);
      case FieldType.recordList:
        return RecordListColumnsForm(field: field, palette: palette);
      case FieldType.levelUpTable:
        return LevelUpTableForm(field: field, palette: palette);
      case FieldType.actionButton:
        return ActionButtonForm(field: field, palette: palette);
      default:
        return const SizedBox.shrink();
    }
  }
}
