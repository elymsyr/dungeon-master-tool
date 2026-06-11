import 'package:flutter/material.dart';

import '../../../../domain/entities/schema/field_schema.dart';

/// Presentation metadata for a [FieldType] — a human label, an icon, and a
/// one-line semantic summary. Drives the read-only field list/inspector
/// (PR-1.5) and, later, the field type picker (Phase 2.2). Mirrors the field
/// catalog in docs/new_system master-roadmap §2.1 / the-template-system §2.
class FieldTypeMeta {
  final String label;
  final IconData icon;
  final String summary;

  /// True for types that can carry rule attachments (master-roadmap §2.1
  /// "Rule capability" column). Scalars are aspect sources only and are not
  /// rule-capable; these get a badge in the type picker.
  final bool ruleCapable;

  const FieldTypeMeta({
    required this.label,
    required this.icon,
    required this.summary,
    this.ruleCapable = false,
  });

  static FieldTypeMeta of(FieldType type) => _meta[type] ?? _fallback;

  static const FieldTypeMeta _fallback = FieldTypeMeta(
    label: 'Field',
    icon: Icons.help_outline,
    summary: 'Custom field type',
  );

  static const Map<FieldType, FieldTypeMeta> _meta = {
    // ── Scalars (aspect source only) ──────────────────────────────────────
    FieldType.text: FieldTypeMeta(
      label: 'Text',
      icon: Icons.short_text,
      summary: 'Single-line text',
    ),
    FieldType.textarea: FieldTypeMeta(
      label: 'Text area',
      icon: Icons.notes,
      summary: 'Multi-line plain text',
    ),
    FieldType.markdown: FieldTypeMeta(
      label: 'Markdown',
      icon: Icons.article_outlined,
      summary: 'Rich player-facing description',
    ),
    FieldType.integer: FieldTypeMeta(
      label: 'Integer',
      icon: Icons.pin,
      summary: 'Whole number; may publish an aspect',
    ),
    FieldType.float_: FieldTypeMeta(
      label: 'Decimal',
      icon: Icons.percent,
      summary: 'Decimal number',
    ),
    FieldType.boolean_: FieldTypeMeta(
      label: 'Boolean',
      icon: Icons.toggle_on_outlined,
      summary: 'Yes / no toggle',
    ),
    FieldType.enum_: FieldTypeMeta(
      label: 'Choice',
      icon: Icons.arrow_drop_down_circle_outlined,
      summary: 'Pick one of a fixed list',
    ),
    FieldType.date: FieldTypeMeta(
      label: 'Date',
      icon: Icons.event_outlined,
      summary: 'Calendar date',
    ),
    FieldType.dice: FieldTypeMeta(
      label: 'Dice',
      icon: Icons.casino_outlined,
      summary: 'Dice notation, e.g. 2d6+3',
    ),
    FieldType.tagList: FieldTypeMeta(
      label: 'Tags',
      icon: Icons.sell_outlined,
      summary: 'Free-form tag chips',
    ),
    // ── Media ─────────────────────────────────────────────────────────────
    FieldType.image: FieldTypeMeta(
      label: 'Image',
      icon: Icons.image_outlined,
      summary: 'Single image upload',
    ),
    FieldType.imagePerEra: FieldTypeMeta(
      label: 'Image per era',
      icon: Icons.collections_outlined,
      summary: 'Per-era image variants',
    ),
    FieldType.file: FieldTypeMeta(
      label: 'File',
      icon: Icons.attach_file,
      summary: 'Arbitrary file attachment',
    ),
    FieldType.pdf: FieldTypeMeta(
      label: 'PDF',
      icon: Icons.picture_as_pdf_outlined,
      summary: 'PDF document',
    ),
    // ── Relations / records ───────────────────────────────────────────────
    FieldType.relation: FieldTypeMeta(
      label: 'Relation',
      icon: Icons.link,
      summary: 'Reference to other entities',
      ruleCapable: true,
    ),
    FieldType.recordList: FieldTypeMeta(
      label: 'Record list',
      icon: Icons.table_rows_outlined,
      summary: 'Typed rows; choose / check-clauses source',
      ruleCapable: true,
    ),
    // ── Pouches / resources ───────────────────────────────────────────────
    FieldType.intPouch: FieldTypeMeta(
      label: 'Int pouch',
      icon: Icons.battery_charging_full_outlined,
      summary: 'current / max resource pair',
      ruleCapable: true,
    ),
    FieldType.checkboxPouch: FieldTypeMeta(
      label: 'Checkbox pouch',
      icon: Icons.check_box_outlined,
      summary: 'count + states (slots, charges, hit dice)',
      ruleCapable: true,
    ),
    FieldType.pouchMatrix: FieldTypeMeta(
      label: 'Pouch matrix',
      icon: Icons.grid_on_outlined,
      summary: 'Per-row max/remaining (spell slots)',
      ruleCapable: true,
    ),
    // ── Tables ────────────────────────────────────────────────────────────
    FieldType.abilityScoreTable: FieldTypeMeta(
      label: 'Ability scores',
      icon: Icons.fitness_center_outlined,
      summary: 'Score columns + published modifiers',
      ruleCapable: true,
    ),
    FieldType.combatStatsTable: FieldTypeMeta(
      label: 'Combat stats',
      icon: Icons.shield_outlined,
      summary: 'HP / AC / speed / level (fixed keys)',
      ruleCapable: true,
    ),
    FieldType.skillTree: FieldTypeMeta(
      label: 'Skill tree',
      icon: Icons.account_tree_outlined,
      summary: 'Skills & saving throws; proficiency target',
      ruleCapable: true,
    ),
    FieldType.levelMatrix: FieldTypeMeta(
      label: 'Level matrix',
      icon: Icons.grid_view_outlined,
      summary: 'Level-keyed progression values',
      ruleCapable: true,
    ),
    FieldType.levelTable: FieldTypeMeta(
      label: 'Level table',
      icon: Icons.trending_up,
      summary: 'level → value progression',
      ruleCapable: true,
    ),
    FieldType.levelTextTable: FieldTypeMeta(
      label: 'Level text table',
      icon: Icons.format_list_numbered,
      summary: 'level → narrative text',
      ruleCapable: true,
    ),
    FieldType.levelUpTable: FieldTypeMeta(
      label: 'Level-up table',
      icon: Icons.upgrade,
      summary: 'Per-level grants & choices',
      ruleCapable: true,
    ),
    FieldType.actionButton: FieldTypeMeta(
      label: 'Action button',
      icon: Icons.smart_button_outlined,
      summary: 'Level-up / rest trigger button',
      ruleCapable: true,
    ),
    FieldType.crCalculator: FieldTypeMeta(
      label: 'CR calculator',
      icon: Icons.calculate_outlined,
      summary: 'Challenge-rating estimator',
    ),
    // ── Legacy v2 types (aliased; PR-2.3 swaps renderers) ─────────────────
    FieldType.statBlock: FieldTypeMeta(
      label: 'Ability scores (legacy)',
      icon: Icons.fitness_center_outlined,
      summary: 'Legacy stat block → abilityScoreTable',
      ruleCapable: true,
    ),
    FieldType.combatStats: FieldTypeMeta(
      label: 'Combat stats (legacy)',
      icon: Icons.shield_outlined,
      summary: 'Legacy combat stats → combatStatsTable',
      ruleCapable: true,
    ),
    FieldType.conditionStats: FieldTypeMeta(
      label: 'Condition stats',
      icon: Icons.coronavirus_outlined,
      summary: 'Monster/NPC stat display',
    ),
    FieldType.slot: FieldTypeMeta(
      label: 'Slot (legacy)',
      icon: Icons.check_box_outlined,
      summary: 'Legacy slot → checkboxPouch',
      ruleCapable: true,
    ),
    FieldType.proficiencyTable: FieldTypeMeta(
      label: 'Proficiency table (legacy)',
      icon: Icons.account_tree_outlined,
      summary: 'Legacy proficiencies → skillTree',
      ruleCapable: true,
    ),
    FieldType.spellSlotGrid: FieldTypeMeta(
      label: 'Spell slot grid (legacy)',
      icon: Icons.grid_on_outlined,
      summary: 'Legacy spell slots → pouchMatrix',
      ruleCapable: true,
    ),
    FieldType.spellSlotProgression: FieldTypeMeta(
      label: 'Spell slot progression',
      icon: Icons.trending_up,
      summary: 'Per-level slot progression override',
    ),
    FieldType.classFeatures: FieldTypeMeta(
      label: 'Class features',
      icon: Icons.menu_book_outlined,
      summary: 'Per-level feature summary lines',
    ),
    FieldType.spellEffectList: FieldTypeMeta(
      label: 'Spell effects (legacy)',
      icon: Icons.auto_awesome_outlined,
      summary: 'Legacy spell effect rows',
    ),
    FieldType.rangedSenseList: FieldTypeMeta(
      label: 'Senses',
      icon: Icons.visibility_outlined,
      summary: 'Sense + range pairs',
    ),
    FieldType.grantedModifiers: FieldTypeMeta(
      label: 'Granted modifiers (legacy)',
      icon: Icons.bolt_outlined,
      summary: 'Legacy typed-bonus rows',
    ),
    FieldType.equipmentChoiceGroups: FieldTypeMeta(
      label: 'Equipment choices',
      icon: Icons.checklist_outlined,
      summary: 'Starting equipment "choose A or B"',
    ),
    FieldType.featEffectList: FieldTypeMeta(
      label: 'Feat effects (legacy)',
      icon: Icons.bolt_outlined,
      summary: 'Legacy feat/feature effect rows',
    ),
    FieldType.autoGrantSources: FieldTypeMeta(
      label: 'Auto-grant sources (legacy)',
      icon: Icons.alt_route_outlined,
      summary: 'Legacy auto-grant edges',
    ),
    FieldType.subspeciesOptions: FieldTypeMeta(
      label: 'Subspecies options',
      icon: Icons.diversity_3_outlined,
      summary: 'Species lineage option rows',
    ),
    FieldType.prereqClauses: FieldTypeMeta(
      label: 'Prerequisites (legacy)',
      icon: Icons.rule_outlined,
      summary: 'Legacy prerequisite clauses',
    ),
  };
}
