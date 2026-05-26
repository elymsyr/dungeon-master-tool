import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/character_creation/caster_progression.dart';
import '../../../application/character_creation/cr_calculator.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../application/services/entity_image_upload.dart';
import '../../../core/utils/screen_type.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/map_data.dart';
import '../../../domain/entities/schema/dnd5e_constants.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/value_objects/asset_ref.dart';
import '../../../domain/value_objects/media_kind.dart';
import '../../dialogs/entity_selector_dialog.dart';
import '../../screens/map/world_map_notifier.dart';
import '../../theme/dm_tool_colors.dart';
import '../asset_ref_image.dart';
import '../markdown_text_area.dart';
import '../perf/image_cache_size.dart';
import '../quota_snackbar.dart';
import 'structured_list_field_widgets.dart';

/// Resolve a relation field value to an entity UUID. Handles three formats
/// stored in `fields`:
///   * String UUID (normal resolved relation).
///   * `{_lookup: <slug>, name: <row>}` — Tier-0 placeholder that escaped
///     import-time resolution (stale data from earlier app version).
///   * `{_ref: <slug>, name: <row>}` — Tier-1 placeholder, treated the same.
/// Returns the matching entity's UUID or '' when nothing fits.
String resolveRelationId(dynamic value, Map<String, Entity>? entities) {
  if (value is String) return value;
  if (value is Map) {
    final slug = (value['_lookup'] ?? value['_ref']);
    final name = value['name'];
    if (slug is String && name is String && entities != null) {
      for (final e in entities.values) {
        if (e.categorySlug == slug && e.name == name) return e.id;
      }
    }
    return '';
  }
  return '';
}

/// Short subtitle for a related entity, surfaced under the chip name in
/// relation list fields. Lets readers scan a relation without opening
/// the linked card. Slug-specific — falls back to category label / null.
String? _relationSubtitle(Entity e) {
  final f = e.fields;
  switch (e.categorySlug) {
    case 'spell':
      final lvl = f['level'];
      final lvlStr = lvl is int ? (lvl == 0 ? 'Cantrip' : 'Level $lvl') : null;
      // school_ref is a Tier-0 UUID; resolving needs the entity map. Skip
      // — keep subtitle lightweight; the level is the load-bearing bit.
      return lvlStr;
    case 'monster':
    case 'animal':
      final cr = f['cr'];
      return cr == null || cr == '' ? null : 'CR $cr';
    case 'magic-item':
      // rarity_ref → UUID; can't resolve here without entity map. Skip.
      return null;
    case 'class':
    case 'subclass':
      return e.categorySlug == 'class' ? 'Class' : 'Subclass';
    case 'weapon':
      final dmg = f['damage_dice'];
      return dmg == null || dmg == '' ? null : '$dmg';
    case 'armor':
      final ac = f['base_ac'];
      return ac == null ? null : 'AC $ac';
    case 'feat':
      return 'Feat';
    case 'species':
      return 'Species';
    case 'background':
      return 'Background';
    default:
      return null;
  }
}

/// Set the entity-navigation provider so the database screen opens [id]
/// in the OPPOSITE panel from [sourcePanel]. Call site (relation chip
/// tap) supplies the source panel; null source → default routing.
void _navigateToEntity(WidgetRef ref, String id, String? sourcePanel) {
  final target = switch (sourcePanel) {
    'left' => 'right',
    'right' => 'left',
    _ => null,
  };
  ref.read(entityNavigationTargetPanelProvider.notifier).state = target;
  ref.read(entityNavigationProvider.notifier).state = id;
}

/// Schema-driven field widget factory.
/// Her FieldType için uygun widget döndürür.
class FieldWidgetFactory {
  static Widget create({
    required FieldSchema schema,
    required dynamic value,
    required bool readOnly,
    required ValueChanged<dynamic> onChanged,
    Map<String, Entity>? entities,
    WidgetRef? ref,

    /// Aynı entity'deki diğer field değerleri — proficiencyTable gibi
    /// cross-field lookup (stat_block, proficiency_bonus) gereksinimleri için.
    Map<String, dynamic>? entityFields,

    /// Inline-list rendering: relation lists collapse to a single comma-separated
    /// row instead of a Card with per-row entries. Used in grouped multi-column
    /// layouts where the tall Card breaks row alignment.
    bool compact = false,

    /// Panel ('left'/'right') the host card lives in. Relation widgets use
    /// it so a tap on a referenced entity opens the target in the OPPOSITE
    /// panel rather than replacing the source card.
    String? panelId,

    /// Derived overrides for the `combat_stats` grid — the character's root
    /// `level` and resolver-computed armor class. When supplied the matching
    /// cell renders read-only off the live value instead of the stale
    /// manually-stored entry.
    int? combatStatsLevel,
    int? combatStatsAc,

    /// SRD armor consequences for the `combat_stats` warning banner
    /// (untrained penalty, STR speed cut, Stealth disadvantage).
    List<String> combatStatsArmorNotes = const [],

    /// Multi-field patch callback. Used by side-effect widgets (e.g.
    /// `extra_hp` adjusts its own value AND combat_stats.{hp,max_hp}
    /// atomically). Editor merges the patch into the entity fields.
    void Function(Map<String, dynamic> patch)? onPatchFields,
  }) {
    // Special-case top-level extra_hp field (signed delta input that also
    // mutates combat_stats.hp/max_hp). Must precede the type switch since
    // it's a plain int field that needs side-effect write access.
    if (schema.fieldKey == 'extra_hp' &&
        schema.fieldType == FieldType.integer &&
        !schema.isList) {
      return _ExtraHpFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        entityFields: entityFields,
        onPatchFields: onPatchFields,
      );
    }
    // isList → genel liste widget'ı
    if (schema.isList) {
      if (schema.fieldType == FieldType.relation) {
        if (compact) {
          return _InlineRelationListFieldWidget(
            schema: schema,
            value: value,
            readOnly: readOnly,
            onChanged: onChanged,
            entities: entities,
            ref: ref,
            panelId: panelId,
          );
        }
        return _ReferenceListFieldWidget(
          schema: schema,
          value: value,
          readOnly: readOnly,
          onChanged: onChanged,
          entities: entities,
          ref: ref,
          panelId: panelId,
        );
      }
      if (schema.fieldType == FieldType.image) {
        return _ImageFieldWidget(
          schema: schema,
          value: value,
          readOnly: readOnly,
          onChanged: onChanged,
        );
      }
      if (schema.fieldType == FieldType.enum_) {
        return _EnumListFieldWidget(
          schema: schema,
          value: value,
          readOnly: readOnly,
          onChanged: onChanged,
        );
      }
      return _GenericListFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
      );
    }

    return switch (schema.fieldType) {
      FieldType.text => _TextFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
      ),
      FieldType.textarea => _TextAreaFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        entities: entities,
      ),
      FieldType.markdown => _MarkdownFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        entities: entities,
        ref: ref,
      ),
      FieldType.integer => _IntegerFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
      ),
      FieldType.enum_ => _EnumFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
      ),
      FieldType.relation => _RelationFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        entities: entities,
        ref: ref,
        panelId: panelId,
      ),
      FieldType.statBlock => _StatBlockFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
      ),
      FieldType.combatStats => _CombatStatsFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        levelOverride: combatStatsLevel,
        acOverride: combatStatsAc,
        armorNotes: combatStatsArmorNotes,
      ),
      FieldType.conditionStats => _CombatStatsFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
      ),
      FieldType.dice => _DiceFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
      ),
      FieldType.boolean_ => _BooleanFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
      ),
      FieldType.slot => _SlotFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        entityFields: entityFields,
      ),
      FieldType.spellSlotGrid => _SpellSlotGridFieldWidget(
        schema: schema,
        value: value,
        onChanged: onChanged,
      ),
      FieldType.spellSlotProgression => _SpellSlotProgressionFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        entityFields: entityFields,
      ),
      FieldType.levelTable => _LevelTableFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
      ),
      FieldType.levelTextTable => _LevelTextTableFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
      ),
      FieldType.proficiencyTable => _ProficiencyTableFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        entityFields: entityFields,
      ),
      FieldType.tagList => _TagListFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
      ),
      FieldType.date => _DateFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
      ),
      FieldType.image => _ImageFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
      ),
      FieldType.imagePerEra => _ImagePerEraFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
      ),
      FieldType.file => _FileFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
      ),
      FieldType.pdf => _PdfFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        ref: ref,
      ),
      FieldType.classFeatures => ClassFeaturesFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        entities: entities,
        ref: ref,
        entityFields: entityFields,
      ),
      FieldType.spellEffectList => SpellEffectListFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        entities: entities,
        ref: ref,
      ),
      FieldType.rangedSenseList => RangedSenseListFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        entities: entities,
        ref: ref,
      ),
      FieldType.grantedModifiers => GrantedModifiersFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        entities: entities,
        ref: ref,
      ),
      FieldType.equipmentChoiceGroups => EquipmentChoiceGroupsFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        entities: entities,
        ref: ref,
      ),
      FieldType.subspeciesOptions => SubspeciesOptionsFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        entities: entities,
        ref: ref,
      ),
      FieldType.crCalculator => _CrCalculatorFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        entityFields: entityFields,
      ),
      FieldType.featEffectList => FeatEffectListFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        entities: entities,
        ref: ref,
      ),
      FieldType.autoGrantSources => AutoGrantSourcesFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
        entities: entities,
        ref: ref,
      ),
      _ => _TextFieldWidget(
        schema: schema,
        value: value,
        readOnly: readOnly,
        onChanged: onChanged,
      ),
    };
  }
}

/// Unified field row: fixed-width bold label on left, value/input on right.
/// Keeps every scalar field aligned at the same baseline. Always renders even
/// when the value is empty.
class _LabeledFieldRow extends StatelessWidget {
  final String label;
  final Widget child;
  final CrossAxisAlignment alignment;

  static const double labelWidth = 140;

  const _LabeledFieldRow({
    required this.label,
    required this.child,
    this.alignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>();
    // Telefonda 140px label dar ekranda input'a az yer bırakıyor — kıs.
    final w = isPhone(context) ? 104.0 : labelWidth;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: alignment,
        children: [
          SizedBox(
            width: w,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 1),
              child: Text(
                '$label:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                      palette?.srdInk ??
                      Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

TextStyle _fieldValueStyle(BuildContext context) {
  final palette = Theme.of(context).extension<DmToolColors>();
  return TextStyle(
    fontSize: 13,
    color: palette?.srdInk ?? Theme.of(context).colorScheme.onSurface,
  );
}

TextStyle _fieldEmptyStyle(BuildContext context) {
  return TextStyle(
    fontSize: 13,
    fontStyle: FontStyle.italic,
    color: Theme.of(context).colorScheme.outline,
  );
}

/// Stepper visibility policy per field key.
/// - [always]: +/- visible in both view and edit modes (mid-session adjustments like HP).
/// - [editOnly]: +/- visible only when not readOnly (level, AC — set during build, not combat).
/// - [none]: no stepper.
enum _StepperMode { none, editOnly, always }

_StepperMode _stepperModeForKey(String key) {
  switch (key) {
    case 'level':
    case 'ac':
      return _StepperMode.editOnly;
    default:
      return _StepperMode.none;
  }
}

bool _alwaysEditableIntKey(String key) =>
    key == 'hp' || key == 'max_hp' || key == 'temp_hp';

/// Two-button column (+ on top, − on bottom) sitting on the right of a value.
/// HP-style fields use the dedicated red/green theme tokens; other fields
/// fall back to the neutral default button palette so the stepper inherits
/// the active theme without screaming "HP" in every context.
class _QuickStepper extends StatelessWidget {
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool hp;

  const _QuickStepper({
    required this.onIncrement,
    required this.onDecrement,
    this.hp = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>();
    final incBg = hp
        ? (palette?.hpBtnIncreaseBg ?? Colors.green)
        : (palette?.buttonDefaultBg ?? Colors.grey.shade700);
    final decBg = hp
        ? (palette?.hpBtnDecreaseBg ?? Colors.red)
        : (palette?.buttonDefaultBg ?? Colors.grey.shade700);
    final fg = hp
        ? (palette?.hpBtnText ?? Colors.white)
        : (palette?.buttonDefaultText ?? Colors.white);
    final radius = palette?.borderRadius ?? 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.add, incBg, fg, radius, onIncrement),
        const SizedBox(height: 2),
        _btn(Icons.remove, decBg, fg, radius, onDecrement),
      ],
    );
  }

  Widget _btn(
    IconData icon,
    Color bg,
    Color fg,
    double radius,
    VoidCallback onTap,
  ) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: 22,
          height: 16,
          child: Icon(icon, size: 12, color: fg),
        ),
      ),
    );
  }
}

int _clampInt(int v, num? min, num? max) {
  if (min != null && v < min) return min.toInt();
  if (max != null && v > max) return max.toInt();
  return v;
}

/// Int fields that render as a row of N checkbox pips rather than a textbox.
/// Death saves and heroic inspiration are 0..3 counters that read more
/// naturally as pips on a character sheet.
bool _isPipCounterKey(String key) =>
    key == 'death_saves_successes' ||
    key == 'death_saves_failures' ||
    key == 'heroic_inspiration';

/// Row of [max] tappable pips. Tap pip i to set count to i+1; tap the
/// currently-filled top pip to decrement by one.
class _PipCounter extends StatelessWidget {
  final int count;
  final int max;
  final ValueChanged<int> onChanged;

  const _PipCounter({
    required this.count,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>();
    final fillColor = palette?.featureCardAccent ??
        Theme.of(context).colorScheme.primary;
    final emptyColor =
        palette?.featureCardBorder ?? Theme.of(context).colorScheme.outline;
    final borderRadius = palette?.cbr ?? BorderRadius.circular(4);
    final clamped = count.clamp(0, max);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: InkWell(
              // Pip counters drive death saves, inspiration etc. — tappable
              // independent of edit mode.
              onTap: () {
                final tapped = i + 1;
                final next = tapped == clamped ? clamped - 1 : tapped;
                onChanged(next.clamp(0, max));
              },
              borderRadius: borderRadius,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: i < clamped ? fillColor : Colors.transparent,
                  border: Border.all(
                    color: i < clamped ? fillColor : emptyColor,
                    width: 1.5,
                  ),
                  borderRadius: borderRadius,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// --- TEXT ---
class _TextFieldWidget extends StatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _TextFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  State<_TextFieldWidget> createState() => _TextFieldWidgetState();
}

class _TextFieldWidgetState extends State<_TextFieldWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _TextFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = widget.value?.toString() ?? '';
    if (_controller.text != newText && oldWidget.value != widget.value) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.value?.toString() ?? '';
    if (widget.readOnly && text.isEmpty) return const SizedBox.shrink();
    return _LabeledFieldRow(
      label: widget.schema.label,
      child: widget.readOnly
          ? Text(text, style: _fieldValueStyle(context))
          : TextFormField(
              key: ValueKey('${widget.schema.fieldKey}_text'),
              controller: _controller,
              style: _fieldValueStyle(context),
              decoration: InputDecoration(
                hintText: widget.schema.placeholder.isNotEmpty
                    ? widget.schema.placeholder
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
              ),
              onChanged: (v) => widget.onChanged(v),
            ),
    );
  }
}

// --- TEXTAREA (with markdown view + @mention) ---
class _TextAreaFieldWidget extends ConsumerStatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;

  const _TextAreaFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entities,
  });

  @override
  ConsumerState<_TextAreaFieldWidget> createState() =>
      _TextAreaFieldWidgetState();
}

class _TextAreaFieldWidgetState extends ConsumerState<_TextAreaFieldWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _TextAreaFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = widget.value?.toString() ?? '';
    if (_controller.text != newText && oldWidget.value != widget.value) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>();
    final inkColor = palette?.srdInk ?? Theme.of(context).colorScheme.onSurface;
    final headingColor =
        palette?.srdHeadingRed ?? Theme.of(context).colorScheme.primary;
    final text = widget.value?.toString() ?? '';
    if (widget.readOnly && text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.schema.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: headingColor,
            ),
          ),
          const SizedBox(height: 4),
          MarkdownTextArea(
            key: ValueKey('${widget.schema.fieldKey}_area'),
            controller: _controller,
            readOnly: widget.readOnly,
            maxLines: widget.readOnly ? null : 4,
            textStyle: TextStyle(fontSize: 13, color: inkColor),
            decoration: InputDecoration(
              hintText: 'Markdown supported (@ to mention)',
              hintStyle: TextStyle(
                color: palette?.srdSubtitle,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              isDense: true,
            ),
            onChanged: (v) => widget.onChanged(v),
          ),
        ],
      ),
    );
  }
}

// --- MARKDOWN (with edit/preview toggle + @mention) ---
class _MarkdownFieldWidget extends ConsumerStatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  const _MarkdownFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entities,
    this.ref,
  });

  @override
  ConsumerState<_MarkdownFieldWidget> createState() =>
      _MarkdownFieldWidgetState();
}

class _MarkdownFieldWidgetState extends ConsumerState<_MarkdownFieldWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _MarkdownFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final newText = widget.value?.toString() ?? '';
      if (_controller.text != newText) {
        _controller.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>();
    final inkColor = palette?.srdInk ?? Theme.of(context).colorScheme.onSurface;
    final headingColor =
        palette?.srdHeadingRed ?? Theme.of(context).colorScheme.primary;

    if (widget.readOnly) {
      final text = widget.value?.toString() ?? '';
      if (text.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.schema.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: headingColor,
              ),
            ),
            const SizedBox(height: 4),
            MarkdownTextArea(
              controller: _controller,
              readOnly: true,
              textStyle: TextStyle(fontSize: 13, color: inkColor),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.schema.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: headingColor,
            ),
          ),
          const SizedBox(height: 4),
          MarkdownTextArea(
            controller: _controller,
            minLines: 4,
            textStyle: TextStyle(fontSize: 13, color: inkColor),
            decoration: InputDecoration(
              hintText: 'Markdown supported. Use @ to mention entities.',
              hintStyle: TextStyle(
                color: palette?.srdSubtitle,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              isDense: true,
            ),
            onChanged: (v) => widget.onChanged(v),
          ),
        ],
      ),
    );
  }
}

// --- INTEGER ---
class _IntegerFieldWidget extends StatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _IntegerFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  State<_IntegerFieldWidget> createState() => _IntegerFieldWidgetState();
}

class _IntegerFieldWidgetState extends State<_IntegerFieldWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _IntegerFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = widget.value?.toString() ?? '';
    if (_controller.text != newText && oldWidget.value != widget.value) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _bump(int delta) {
    final cur = int.tryParse(widget.value?.toString() ?? '') ?? 0;
    final clamped = _clampInt(
      cur + delta,
      widget.schema.validation.minValue,
      widget.schema.validation.maxValue,
    );
    if (clamped == cur) return;
    _controller.text = clamped.toString();
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.value;
    final hasValue = raw != null && raw.toString().isNotEmpty;
    final mode = _stepperModeForKey(widget.schema.fieldKey);
    final forceEditable = _alwaysEditableIntKey(widget.schema.fieldKey);
    final effectiveReadOnly = widget.readOnly && !forceEditable;
    final showStepper =
        mode == _StepperMode.always ||
        (mode == _StepperMode.editOnly && !widget.readOnly);
    if (effectiveReadOnly && !hasValue && !showStepper) {
      return const SizedBox.shrink();
    }

    // Counter-style int fields: render N pips instead of a textbox. The pip
    // count is the field's max validation (default 3). Tap toggles to that
    // index; tapping the currently-filled top pip clears one. Always
    // tappable — view-mode taps are valid mid-session updates (death
    // saves, inspiration charges).
    if (_isPipCounterKey(widget.schema.fieldKey)) {
      final maxPips =
          widget.schema.validation.maxValue?.toInt() ?? 3;
      final current = int.tryParse(raw?.toString() ?? '') ?? 0;
      return _LabeledFieldRow(
        label: widget.schema.label,
        child: _PipCounter(
          count: current,
          max: maxPips,
          onChanged: (v) => widget.onChanged(v),
        ),
      );
    }

    final valueChild = effectiveReadOnly
        ? Text(
            hasValue ? raw.toString() : '—',
            style: _fieldValueStyle(context),
          )
        : TextFormField(
            key: ValueKey('${widget.schema.fieldKey}_int'),
            controller: _controller,
            keyboardType: TextInputType.number,
            style: _fieldValueStyle(context),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            ),
            onChanged: (v) => widget.onChanged(int.tryParse(v) ?? 0),
          );

    final Widget child = showStepper
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: valueChild),
              const SizedBox(width: 6),
              _QuickStepper(
                hp: mode == _StepperMode.always,
                onIncrement: () => _bump(1),
                onDecrement: () => _bump(-1),
              ),
            ],
          )
        : valueChild;

    return _LabeledFieldRow(label: widget.schema.label, child: child);
  }
}

// --- EXTRA HP (signed delta input, mirrors to combat_stats) ---
// Sticky-cumulative bonus to max HP. Input accepts "+n" / "n" / "-n";
// on commit Δ is applied to combat_stats.{hp,max_hp} alongside this field.
// max_hp stays the single source of truth for current effective max; this
// field is the audit trail of manual adjustments only.
class _ExtraHpFieldWidget extends StatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, dynamic>? entityFields;
  final void Function(Map<String, dynamic> patch)? onPatchFields;

  const _ExtraHpFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    required this.entityFields,
    required this.onPatchFields,
  });

  @override
  State<_ExtraHpFieldWidget> createState() => _ExtraHpFieldWidgetState();
}

class _ExtraHpFieldWidgetState extends State<_ExtraHpFieldWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final t = v.trim();
      if (t.isEmpty) return 0;
      return int.tryParse(t) ?? 0;
    }
    return 0;
  }

  // Resolves committed text to the new absolute extra HP value.
  // "+5"/"5" → 5; "-3" → -3; "0" → 0. Null for invalid/empty.
  int? _resolveNewExtra(String text, int oldExtra) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final body = t.startsWith('+') ? t.substring(1) : t;
    return int.tryParse(body);
  }

  String _formatSigned(int n) {
    if (n > 0) return '+$n';
    if (n < 0) return '$n';
    return '0';
  }

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: _formatSigned(_asInt(widget.value)));
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // Pre-select cumulative text so typed input replaces it instead of
      // concatenating ("+5" + typing "+3" otherwise becomes "+5+3" → no-op).
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    } else {
      _applyDelta(_controller.text);
    }
  }

  @override
  void didUpdateWidget(covariant _ExtraHpFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      final newText = _formatSigned(_asInt(widget.value));
      if (_controller.text != newText) _controller.text = newText;
    }
  }

  @override
  void deactivate() {
    // Save buton / mode toggle widget tree'den çıkmadan delta uygula.
    if (_focusNode.hasFocus) {
      _applyDelta(_controller.text);
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _applyDelta(String text) {
    final oldExtra = _asInt(widget.value);
    final newExtra = _resolveNewExtra(text, oldExtra);
    if (newExtra == null) {
      _controller.text = _formatSigned(oldExtra);
      return;
    }
    final delta = newExtra - oldExtra;
    if (delta == 0) {
      _controller.text = _formatSigned(oldExtra);
      return;
    }
    final stats = widget.entityFields?['combat_stats'];
    final statsMap = stats is Map
        ? Map<String, dynamic>.from(stats)
        : <String, dynamic>{};
    final oldMax = _asInt(statsMap['max_hp']);
    final oldHp = _asInt(statsMap['hp']);
    final newMax = (oldMax + delta).clamp(0, 9999).toInt();
    final newHp = (oldHp + delta).clamp(0, newMax).toInt();
    statsMap['max_hp'] = newMax;
    statsMap['hp'] = newHp;
    final patch = widget.onPatchFields;
    if (patch != null) {
      patch({'extra_hp': newExtra, 'combat_stats': statsMap});
    } else {
      widget.onChanged(newExtra);
    }
    _controller.text = _formatSigned(newExtra);
  }

  @override
  Widget build(BuildContext context) {
    final current = _asInt(widget.value);
    final Widget child = widget.readOnly
        ? Text(_formatSigned(current), style: _fieldValueStyle(context))
        : TextFormField(
            key: const ValueKey('extra_hp_input'),
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            style: _fieldValueStyle(context),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              helperText: '+/-',
              helperStyle: TextStyle(fontSize: 9),
            ),
            onFieldSubmitted: _applyDelta,
          );
    return _LabeledFieldRow(label: widget.schema.label, child: child);
  }
}

// --- ENUM (Dropdown) ---
class _EnumFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _EnumFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = schema.validation.allowedValues ?? [];
    final currentVal = value?.toString();
    final hasValue = currentVal != null && currentVal.isNotEmpty;

    if (readOnly && !hasValue) return const SizedBox.shrink();

    return _LabeledFieldRow(
      label: schema.label,
      child: readOnly
          ? Text(currentVal!, style: _fieldValueStyle(context))
          : DropdownButtonFormField<String>(
              initialValue: options.contains(currentVal) ? currentVal : null,
              isDense: true,
              isExpanded: true,
              iconSize: 18,
              style: _fieldValueStyle(context),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
              ),
              items: options
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(o, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => onChanged(v),
            ),
    );
  }
}

/// Multi-select enum list. Read-only renders as comma-separated inline
/// values; editable shows FilterChip wrap so the user can toggle members.
class _EnumListFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _EnumListFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  List<String> _parse(dynamic v) {
    if (v is! List) return const [];
    return v.whereType<String>().where((s) => s.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final options = schema.validation.allowedValues ?? const <String>[];
    final selected = _parse(value);

    if (readOnly) {
      if (selected.isEmpty) return const SizedBox.shrink();
      return _LabeledFieldRow(
        label: schema.label,
        child: Text(selected.join(', '), style: _fieldValueStyle(context)),
      );
    }

    return _LabeledFieldRow(
      label: schema.label,
      alignment: CrossAxisAlignment.start,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: options.map((opt) {
          final on = selected.contains(opt);
          return FilterChip(
            label: Text(opt, style: const TextStyle(fontSize: 11)),
            selected: on,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (sel) {
              final next = List<String>.from(selected);
              if (sel) {
                if (!next.contains(opt)) next.add(opt);
              } else {
                next.remove(opt);
              }
              onChanged(next);
            },
          );
        }).toList(),
      ),
    );
  }
}

// --- RELATION (Entity Reference) ---
// --- SINGLE RELATION — entity adı gösteren + selector dialog ---
class _RelationFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;
  final String? panelId;

  const _RelationFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entities,
    this.ref,
    this.panelId,
  });

  @override
  Widget build(BuildContext context) {
    final linkedId = resolveRelationId(value, entities);
    final linkedEntity = (linkedId.isNotEmpty && entities != null)
        ? entities![linkedId]
        : null;
    final linkedName =
        linkedEntity?.name ?? (linkedId.isNotEmpty ? linkedId : '');
    final subtitle = linkedEntity == null
        ? null
        : _relationSubtitle(linkedEntity);
    final hasValue = linkedId.isNotEmpty;

    // Read-only surface (e.g. player viewing a shared card): never render a
    // raw entity id — hide the row when the linked entity isn't present.
    if (readOnly && linkedEntity == null) return const SizedBox.shrink();

    return _LabeledFieldRow(
      label: schema.label,
      child: Row(
        children: [
          Expanded(
            child: hasValue
                ? InkWell(
                    onTap: ref == null || linkedEntity == null
                        ? null
                        : () => _navigateToEntity(ref!, linkedId, panelId),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            linkedName,
                            style: _fieldValueStyle(context).copyWith(
                              decoration: linkedEntity != null
                                  ? TextDecoration.underline
                                  : null,
                              decorationStyle: TextDecorationStyle.dotted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(width: 6),
                          Text('· $subtitle', style: _fieldEmptyStyle(context)),
                        ],
                      ],
                    ),
                  )
                : Text('—', style: _fieldEmptyStyle(context)),
          ),
          if (!readOnly && hasValue)
            InkWell(
              onTap: () => onChanged(''),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 14),
              ),
            ),
          if (!readOnly)
            InkWell(
              onTap: () async {
                if (ref == null) return;
                final result = await showEntitySelectorDialog(
                  context: context,
                  ref: ref!,
                  allowedTypes: schema.validation.allowedTypes,
                  includeBuiltinSrd: true,
                );
                if (result != null && result.isNotEmpty) {
                  onChanged(result.first);
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.search, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}

// --- STAT BLOCK (STR/DEX/CON/INT/WIS/CHA) ---
class _StatBlockFieldWidget extends StatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _StatBlockFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  State<_StatBlockFieldWidget> createState() => _StatBlockFieldWidgetState();
}

class _StatBlockFieldWidgetState extends State<_StatBlockFieldWidget> {
  static const _keys = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];
  final Map<String, TextEditingController> _controllers = {};

  Map<String, dynamic> get _stats => (widget.value is Map)
      ? Map<String, dynamic>.from(widget.value as Map)
      : <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    final stats = _stats;
    for (final key in _keys) {
      _controllers[key] = TextEditingController(
        text: (stats[key] ?? 10).toString(),
      );
    }
  }

  @override
  void didUpdateWidget(covariant _StatBlockFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final stats = _stats;
      for (final key in _keys) {
        final newText = (stats[key] ?? 10).toString();
        final ctrl = _controllers[key]!;
        if (ctrl.text != newText) {
          ctrl.text = newText;
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.schema.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: _keys.map((key) {
                final val = stats[key] ?? 10;
                final mod = ((val is int ? val : 10) - 10) ~/ 2;
                final modStr = mod >= 0 ? '+$mod' : '$mod';

                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        key,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 44,
                        child: TextFormField(
                          key: ValueKey('sb_$key'),
                          controller: _controllers[key],
                          readOnly: widget.readOnly,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (v) {
                            final updated = Map<String, dynamic>.from(stats);
                            updated[key] = int.tryParse(v) ?? 10;
                            widget.onChanged(updated);
                          },
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        modStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- COMBAT STATS (HP, AC, Speed, etc.) ---
class _CombatStatsFieldWidget extends StatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  /// Derived overrides — when supplied, the matching grid cell shows the
  /// computed value read-only instead of the manually stored `combat_stats`
  /// entry. `levelOverride` mirrors the entity's root `level` field (kept in
  /// sync by level-up); `acOverride` is the resolver-computed armor class
  /// (armor + Dex + shield). Null = fall back to the editable stored value
  /// (monsters / NPCs have no root level or resolver AC).
  final int? levelOverride;
  final int? acOverride;

  /// SRD 5.2.1 consequences of the currently equipped armor (untrained
  /// penalty, STR speed cut, Stealth disadvantage). Rendered as a warning
  /// banner above the stats grid. Empty = no banner.
  final List<String> armorNotes;

  const _CombatStatsFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.levelOverride,
    this.acOverride,
    this.armorNotes = const [],
  });

  @override
  State<_CombatStatsFieldWidget> createState() =>
      _CombatStatsFieldWidgetState();
}

class _CombatStatsFieldWidgetState extends State<_CombatStatsFieldWidget> {
  final Map<String, TextEditingController> _controllers = {};

  Map<String, dynamic> get _stats => (widget.value is Map)
      ? Map<String, dynamic>.from(widget.value as Map)
      : <String, dynamic>{};

  List<(String, String, String)> get _fields =>
      widget.schema.subFields.isNotEmpty
      ? widget.schema.subFields
            .map(
              (sf) => (
                sf['key'] ?? '',
                sf['label'] ?? sf['key'] ?? '',
                sf['type'] ?? 'text',
              ),
            )
            .toList()
      : const [
          ('hp', 'HP', 'integer'),
          ('max_hp', 'Max HP', 'integer'),
          ('ac', 'AC', 'integer'),
          ('speed', 'Speed', 'text'),
          ('initiative', 'Init', 'integer'),
          ('cr', 'CR', 'text'),
          ('xp', 'XP', 'integer'),
        ];

  /// Resolved override for a sub-field key, or null when the cell stays a
  /// plain editable stored value.
  int? _overrideFor(String key) {
    if (key == 'level') return widget.levelOverride;
    if (key == 'ac') return widget.acOverride;
    return null;
  }

  /// Display text for [key]: the derived override when present, else the
  /// stored `combat_stats` entry.
  String _textFor(String key, Map<String, dynamic> stats) {
    final ov = _overrideFor(key);
    if (ov != null) return '$ov';
    return stats[key]?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    final stats = _stats;
    for (final f in _fields) {
      _controllers[f.$1] = TextEditingController(text: _textFor(f.$1, stats));
    }
  }

  @override
  void didUpdateWidget(covariant _CombatStatsFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-sync when the stored map OR a derived override (level-up / equipped
    // armor) changed — both can shift the text a cell should display.
    if (oldWidget.value != widget.value ||
        oldWidget.levelOverride != widget.levelOverride ||
        oldWidget.acOverride != widget.acOverride) {
      final stats = _stats;
      for (final f in _fields) {
        final newText = _textFor(f.$1, stats);
        final ctrl = _controllers[f.$1];
        if (ctrl != null && ctrl.text != newText) {
          ctrl.text = newText;
        } else if (ctrl == null) {
          _controllers[f.$1] = TextEditingController(text: newText);
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Amber warning banner listing the SRD armor consequences in
  /// [_CombatStatsFieldWidget.armorNotes] (untrained penalty, STR speed cut,
  /// Stealth disadvantage).
  Widget _armorNotesBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final note in widget.armorNotes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      note,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final fields = _fields;
    final gridFields = fields.where((f) => f.$3 != 'textarea').toList();
    final textareaFields = fields.where((f) => f.$3 == 'textarea').toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.schema.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (widget.armorNotes.isNotEmpty) ...[
              _armorNotesBanner(context),
              const SizedBox(height: 8),
            ],
            if (gridFields.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = (constraints.maxWidth / 88).floor().clamp(
                    1,
                    gridFields.length,
                  );
                  final rows = <Widget>[];
                  for (var i = 0; i < gridFields.length; i += cols) {
                    final rowFields = gridFields.sublist(
                      i,
                      (i + cols).clamp(0, gridFields.length),
                    );
                    rows.add(
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i + cols < gridFields.length ? 8 : 0,
                        ),
                        child: Row(
                          children: rowFields.map((f) {
                            // hp/max_hp locked everywhere: damage/heal flows
                            // through rest buttons + combat tracker (not this
                            // widget). Manual edit removed to prevent mis-edit
                            // vs level-up math. Bonus adjustments go through
                            // the top-level `extra_hp` field.
                            final lockedHp =
                                f.$1 == 'hp' || f.$1 == 'max_hp';
                            // `level` / `ac` are derived (root level field +
                            // resolver AC) — always read-only, never write the
                            // stale stored value back via onChanged.
                            final isDerived = _overrideFor(f.$1) != null;
                            final field = TextFormField(
                              key: ValueKey('cs_${f.$1}'),
                              controller: _controllers[f.$1],
                              readOnly:
                                  isDerived || lockedHp || widget.readOnly,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                labelText: f.$2,
                                // Keep the floating label centred over the
                                // centred input text instead of snapping to
                                // the top-left on focus.
                                floatingLabelAlignment:
                                    FloatingLabelAlignment.center,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 4,
                                ),
                              ),
                              onChanged: (v) {
                                final updated =
                                    Map<String, dynamic>.from(stats);
                                updated[f.$1] = v;
                                widget.onChanged(updated);
                              },
                            );
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: f != rowFields.last ? 8 : 0,
                                ),
                                child: field,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }
                  return Column(children: rows);
                },
              ),
            // Textarea sub-fields rendered full-width below the grid (markdown + @mention)
            ...textareaFields.map((f) {
              final ctrl = _controllers[f.$1];
              final p = Theme.of(context).extension<DmToolColors>();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p?.tabText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    MarkdownTextArea(
                      key: ValueKey('cs_${f.$1}'),
                      controller: ctrl!,
                      readOnly: widget.readOnly,
                      maxLines: widget.readOnly ? null : 3,
                      textStyle: TextStyle(fontSize: 13, color: p?.htmlText),
                      decoration: const InputDecoration(
                        hintText: '@ to mention entities',
                        isDense: true,
                        alignLabelWithHint: true,
                      ),
                      onChanged: (v) {
                        final updated = Map<String, dynamic>.from(stats);
                        updated[f.$1] = v;
                        widget.onChanged(updated);
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// --- GENERIC LIST — herhangi tipin listesi (text list, integer list, image list...) ---
class _GenericListFieldWidget extends StatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _GenericListFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  State<_GenericListFieldWidget> createState() =>
      _GenericListFieldWidgetState();
}

class _GenericListFieldWidgetState extends State<_GenericListFieldWidget> {
  final List<TextEditingController> _controllers = [];

  List<String> get _items => (widget.value is List)
      ? List<String>.from((widget.value as List).map((e) => e.toString()))
      : <String>[];

  @override
  void initState() {
    super.initState();
    _syncControllers(_items);
  }

  @override
  void didUpdateWidget(covariant _GenericListFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _syncControllers(_items);
    }
  }

  void _syncControllers(List<String> items) {
    // Adjust controller list length
    while (_controllers.length < items.length) {
      _controllers.add(TextEditingController());
    }
    while (_controllers.length > items.length) {
      _controllers.removeLast().dispose();
    }
    // Update text for controllers whose text differs
    for (var i = 0; i < items.length; i++) {
      if (_controllers[i].text != items[i]) {
        _controllers[i].text = items[i];
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final typeName = widget.schema.fieldType.name;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.schema.label} (${items.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  typeName,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                if (!widget.readOnly)
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () {
                      final updated = List<String>.from(items)..add('');
                      widget.onChanged(updated);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No items',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
              ),
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text(
                      '${i + 1}.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('${widget.schema.fieldKey}_list_$i'),
                        controller: _controllers.length > i
                            ? _controllers[i]
                            : null,
                        readOnly: widget.readOnly,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                        ),
                        keyboardType:
                            widget.schema.fieldType == FieldType.integer
                            ? TextInputType.number
                            : null,
                        onChanged: (v) {
                          final updated = List<String>.from(items);
                          updated[i] = v;
                          widget.onChanged(updated);
                        },
                      ),
                    ),
                    if (!widget.readOnly)
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () {
                          final updated = List<String>.from(items)..removeAt(i);
                          widget.onChanged(updated);
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// --- REFERENCE LIST — equip destekli kategori referans listesi ---
class _ReferenceListFieldWidget extends StatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;
  final String? panelId;

  const _ReferenceListFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entities,
    this.ref,
    this.panelId,
  });

  @override
  State<_ReferenceListFieldWidget> createState() =>
      _ReferenceListFieldWidgetState();
}

class _ReferenceListFieldWidgetState extends State<_ReferenceListFieldWidget> {
  FieldSchema get schema => widget.schema;
  dynamic get value => widget.value;
  bool get readOnly => widget.readOnly;
  ValueChanged<dynamic> get onChanged => widget.onChanged;
  Map<String, Entity>? get entities => widget.entities;
  WidgetRef? get ref => widget.ref;
  String? get panelId => widget.panelId;

  /// Armor slot for an inventory entity: `'shield'` or `'body'` for an armor
  /// entity, else null. Used to enforce SRD "one suit + one shield at a time"
  /// — equipping an armor auto-unequips any other equipped armor in the same
  /// slot. Returns null for non-armor (weapons, spells) so the toggle stays
  /// generic.
  String? _armorSlot(String itemId) {
    final all = entities;
    if (all == null) return null;
    final e = all[itemId];
    if (e == null || e.categorySlug != 'armor') return null;
    final catRef = e.fields['category_ref'];
    final catId = catRef is String ? catRef : null;
    final cat = catId != null ? all[catId] : null;
    final name = cat?.name.toLowerCase() ?? '';
    return name.contains('shield') ? 'shield' : 'body';
  }

  @override
  Widget build(BuildContext context) {
    // Değer iki formatta olabilir:
    // 1) List<String> — basit ID listesi (equip yok)
    // 2) List<Map> — [{id: 'xxx', equipped: true}, ...]
    final items = _parseItems(value);
    final targetTypes = schema.validation.allowedTypes?.join(', ') ?? 'any';
    final showEquip = schema.hasEquip;

    // Read-only mode collapses identical rows into a single entry with an
    // "(×N)" suffix. Edit mode keeps each row separate so the close/equip
    // buttons stay 1:1 with the underlying list. Grouping key is
    // (id, equipped) — different equip state means different rows.
    final List<({Map<String, dynamic> item, int count, int origIndex})>
        displayEntries;
    if (readOnly) {
      final groups = <String, ({Map<String, dynamic> item, int count, int origIndex})>{};
      final order = <String>[];
      for (var i = 0; i < items.length; i++) {
        final it = items[i];
        final key = '${it['id']}|${it['equipped'] == true}';
        final existing = groups[key];
        if (existing == null) {
          groups[key] = (item: it, count: 1, origIndex: i);
          order.add(key);
        } else {
          groups[key] = (item: existing.item, count: existing.count + 1, origIndex: existing.origIndex);
        }
      }
      displayEntries = [for (final k in order) groups[k]!];
    } else {
      displayEntries = [
        for (var i = 0; i < items.length; i++)
          (item: items[i], count: 1, origIndex: i),
      ];
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${schema.label} (${items.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                // Category hint + add button cling to the right edge.
                Text(
                  '→ $targetTypes',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (!readOnly)
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () async {
                      if (ref == null) return;
                      final existingIds = items
                          .map((e) => e['id']?.toString() ?? '')
                          .toList();
                      final result = await showEntitySelectorDialog(
                        context: context,
                        ref: ref!,
                        allowedTypes: schema.validation.allowedTypes,
                        multiSelect: true,
                        excludeIds: existingIds,
                        includeBuiltinSrd: true,
                      );
                      if (result != null) {
                        for (final id in result) {
                          items.add({
                            'id': id,
                            'equipped': false,
                            'source': 'manual',
                          });
                        }
                        onChanged(_serializeItems(items, showEquip));
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No items linked',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
              ),
            ...displayEntries.map((entry) {
              final i = entry.origIndex;
              final item = entry.item;
              final count = entry.count;
              final isEquipped = item['equipped'] == true;
              final itemId = item['id']?.toString() ?? '';

              final linkedEntity = entities?[itemId];
              final description = linkedEntity?.description ?? '';
              // Indent description to align with the entity name (past the
              // equip toggle only — name leads the row now that the link
              // icon is gone).
              final descIndent = showEquip ? 28.0 : 0.0;

              // Read-only surface (e.g. player viewing a shared card): never
              // render a raw entity id — skip the row when unresolvable.
              if (readOnly && linkedEntity == null) {
                return const SizedBox.shrink();
              }

              Widget itemRow = Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Equip toggle — for spells the toggle marks the row
                        // as "prepared" instead of "equipped".
                        if (showEquip) ...[
                          SizedBox(
                            width: 28,
                            child: IconButton(
                              icon: Icon(
                                schema.fieldKey == 'spells_known'
                                    ? (isEquipped
                                        ? Icons.auto_stories
                                        : Icons.auto_stories_outlined)
                                    : (isEquipped
                                        ? Icons.shield
                                        : Icons.shield_outlined),
                                size: 16,
                                color: isEquipped
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                              ),
                              tooltip: schema.fieldKey == 'spells_known'
                                  ? (isEquipped ? 'Prepared' : 'Not prepared')
                                  : (isEquipped ? 'Equipped' : 'Not equipped'),
                              // Equip/prepare flag toggles independent of edit
                              // mode — players juggle these mid-session.
                              onPressed: () {
                                // SRD: one suit of armor + one shield at a
                                // time. Equipping an armor auto-unequips any
                                // other equipped armor in the same slot.
                                if (!isEquipped) {
                                  final slot = _armorSlot(itemId);
                                  if (slot != null) {
                                    for (var j = 0; j < items.length; j++) {
                                      if (j == i) continue;
                                      if (items[j]['equipped'] == true &&
                                          _armorSlot(
                                                items[j]['id']?.toString() ??
                                                    '',
                                              ) ==
                                              slot) {
                                        items[j] = {
                                          ...items[j],
                                          'equipped': false,
                                        };
                                      }
                                    }
                                  }
                                }
                                items[i] = {
                                  ...item,
                                  'equipped': !isEquipped,
                                };
                                onChanged(
                                  _serializeItems(items, showEquip),
                                );
                              },
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                        Expanded(
                          child: InkWell(
                            onTap: ref == null || linkedEntity == null
                                ? null
                                : () =>
                                      _navigateToEntity(ref!, itemId, panelId),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    count > 1
                                        ? '${_resolveEntityName(itemId)} (×$count)'
                                        : _resolveEntityName(itemId),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      decoration: linkedEntity != null
                                          ? TextDecoration.underline
                                          : null,
                                      decorationStyle:
                                          TextDecorationStyle.dotted,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (linkedEntity != null) ...[
                                  const SizedBox(width: 6),
                                  Builder(
                                    builder: (ctx) {
                                      final sub = _relationSubtitle(
                                        linkedEntity,
                                      );
                                      if (sub == null) {
                                        return const SizedBox.shrink();
                                      }
                                      return Text(
                                        '· $sub',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (!readOnly)
                          IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            onPressed: () {
                              items.removeAt(i);
                              onChanged(_serializeItems(items, showEquip));
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    if (description.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          left: descIndent,
                          top: 2,
                          right: 4,
                        ),
                        child: MarkdownBody(
                          data: description,
                          // Touch: selection swallows drag → no scroll.
                          selectable: !isTouchPlatform,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(
                                Theme.of(context),
                              ).copyWith(
                                p: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.85),
                                ),
                                listBullet: const TextStyle(fontSize: 12),
                              ),
                        ),
                      ),
                  ],
                ),
              );

              return itemRow;
            }),
          ],
        ),
      ),
    );
  }

  String _resolveEntityName(String id) {
    if (id.isEmpty) return '';
    return entities?[id]?.name ?? id;
  }

  /// Değeri [{id, equipped}] formatına parse et.
  List<Map<String, dynamic>> _parseItems(dynamic value) {
    if (value is! List) return [];
    return value.map<Map<String, dynamic>>((e) {
      if (e is Map) {
        if (e['_lookup'] != null || e['_ref'] != null) {
          return {'id': resolveRelationId(e, entities), 'equipped': false};
        }
        return Map<String, dynamic>.from(e);
      }
      if (e is String) return {'id': e, 'equipped': false};
      return {'id': e.toString(), 'equipped': false};
    }).toList();
  }

  /// Kaydetme formatına çevir — equip yoksa basit ID listesi, varsa map listesi.
  dynamic _serializeItems(List<Map<String, dynamic>> items, bool withEquip) {
    if (!withEquip) return items.map((e) => e['id']).toList();
    return items;
  }
}

/// Inline relation-list — single-row "Label: name1, name2, name3" rendering
/// for grouped multi-column layouts where the full Card form breaks alignment.
/// Edit mode shows compact chips with × + a "+" add button.
class _InlineRelationListFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;
  final String? panelId;

  const _InlineRelationListFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entities,
    this.ref,
    this.panelId,
  });

  List<String> _parseIds(dynamic v) {
    if (v is! List) return const [];
    return v
        .map<String>((e) {
          if (e is String) return e;
          if (e is Map) {
            if (e['_lookup'] != null || e['_ref'] != null) {
              return resolveRelationId(e, entities);
            }
            return (e['id']?.toString() ?? '');
          }
          return e.toString();
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String _name(String id) => entities?[id]?.name ?? id;
  String? _subtitle(String id) {
    final e = entities?[id];
    return e == null ? null : _relationSubtitle(e);
  }

  Widget _chipLabel(String id) {
    final name = _name(id);
    final sub = _subtitle(id);
    if (sub == null) {
      return Text(
        name,
        style: const TextStyle(fontSize: 11),
        overflow: TextOverflow.ellipsis,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '· $sub',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ids = _parseIds(value);

    if (readOnly) {
      final visible = ids.where((id) => entities?[id] != null).toList();
      if (visible.isEmpty && ids.every((id) => entities?[id] == null)) {
        // Fall back to raw ids when nothing resolves so debugging remains
        // possible (rather than showing an empty value).
        if (ids.isEmpty) return const SizedBox.shrink();
      }
      return _LabeledFieldRow(
        label: schema.label,
        alignment: CrossAxisAlignment.start,
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final id in ids)
              InkWell(
                onTap: ref == null || entities?[id] == null
                    ? null
                    : () => _navigateToEntity(ref!, id, panelId),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondaryContainer.withValues(alpha: 0.4),
                    borderRadius:
                        Theme.of(context).extension<DmToolColors>()?.chr ??
                        BorderRadius.circular(6),
                  ),
                  child: _chipLabel(id),
                ),
              ),
          ],
        ),
      );
    }

    return _LabeledFieldRow(
      label: schema.label,
      alignment: CrossAxisAlignment.start,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final id in ids)
            InputChip(
              label: _chipLabel(id),
              onPressed: ref == null || entities?[id] == null
                  ? null
                  : () => _navigateToEntity(ref!, id, panelId),
              onDeleted: () {
                final next = List<String>.from(ids)..remove(id);
                onChanged(next);
              },
              deleteIcon: const Icon(Icons.close, size: 14),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: 'Add',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            onPressed: () async {
              if (ref == null) return;
              final result = await showEntitySelectorDialog(
                context: context,
                ref: ref!,
                allowedTypes: schema.validation.allowedTypes,
                multiSelect: true,
                excludeIds: ids,
                includeBuiltinSrd: true,
              );
              if (result != null && result.isNotEmpty) {
                onChanged([...ids, ...result]);
              }
            },
          ),
        ],
      ),
    );
  }
}

// --- BOOLEAN ---
class _BooleanFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _BooleanFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final checked = value == true;
    if (readOnly && !checked) return const SizedBox.shrink();
    return _LabeledFieldRow(
      label: schema.label,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: checked,
            onChanged: readOnly ? null : (v) => onChanged(v == true),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

// --- SLOT ---
/// Row of checkbox "pips" for spell slots, ammo, charges, hit dice, etc.
/// Value is stored as `{count, filled}` so it round-trips cleanly through
/// the entity's `Map<String, dynamic> fields`. Users can resize the row at
/// any time via the +/- buttons; a refill button in the corner clears every
/// filled pip in one tap.
class _SlotFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, dynamic>? entityFields;

  const _SlotFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entityFields,
  });

  ({int count, List<bool> states}) get _parsed {
    if (value is Map) {
      final m = value as Map;
      final count = (m['count'] as num?)?.toInt().clamp(0, 99) ?? 0;
      if (m.containsKey('states') && m['states'] is List) {
        final raw = (m['states'] as List).map((e) => e == true).toList();
        final states = List.generate(count, (i) => i < raw.length && raw[i]);
        return (count: count, states: states);
      }
      final filled = (m['filled'] as num?)?.toInt().clamp(0, count) ?? 0;
      return (count: count, states: List.generate(count, (i) => i < filled));
    }
    return (count: 0, states: []);
  }

  void _write({required int count, required List<bool> states}) {
    onChanged({'count': count, 'states': states});
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final state = _parsed;
    final count = state.count;
    final states = state.states;
    final anyFilled = states.any((s) => s);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  schema.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!readOnly) ...[
                IconButton(
                  tooltip: 'Remove slot',
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: count == 0
                      ? null
                      : () => _write(
                          count: count - 1,
                          states: states.sublist(0, count - 1),
                        ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
                IconButton(
                  tooltip: 'Add slot',
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  onPressed: count >= 99
                      ? null
                      : () => _write(
                          count: count + 1,
                          states: [...states, false],
                        ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
                IconButton(
                  tooltip: 'Refill',
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: anyFilled
                      ? null
                      : () => _write(
                          count: count,
                          states: List.filled(count, true),
                        ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (count == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No slots — tap + to add',
                style: TextStyle(fontSize: 11, color: palette.srdSubtitle),
              ),
            )
          else
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                for (var i = 0; i < count; i++)
                  _SlotPip(
                    filled: states[i],
                    color: palette.featureCardAccent,
                    borderRadius: palette.br,
                    onTap: () {
                      final newStates = [...states];
                      newStates[i] = !newStates[i];
                      _write(count: count, states: newStates);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Per-spell-level slot grid for PCs. Storage shape:
///   `{max: {1: 4, 2: 3, ...}, remaining: {1: 4, 2: 2, ...}}`
/// Maxes are auto-seeded by the wizard (caster_kind + level) and the
/// level-up dialog. The user can only tap pips to expend/recover slots —
/// not add/remove rows.
class _SpellSlotGridFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  const _SpellSlotGridFieldWidget({
    required this.schema,
    required this.value,
    required this.onChanged,
  });

  ({Map<int, int> max, Map<int, int> remaining}) _parse() {
    final maxOut = <int, int>{};
    final remOut = <int, int>{};
    if (value is Map) {
      final m = value as Map;
      void readMap(Object? raw, Map<int, int> target) {
        if (raw is! Map) return;
        for (final entry in raw.entries) {
          final k = entry.key;
          final kInt = k is int ? k : int.tryParse(k.toString());
          if (kInt == null) continue;
          final v = entry.value;
          final vInt = v is int ? v : int.tryParse(v.toString());
          if (vInt == null) continue;
          target[kInt] = vInt;
        }
      }

      readMap(m['max'], maxOut);
      readMap(m['remaining'], remOut);
    }
    return (max: maxOut, remaining: remOut);
  }

  void _toggle(Map<int, int> max, Map<int, int> remaining, int level, int i) {
    final cap = max[level] ?? 0;
    final cur = (remaining[level] ?? 0).clamp(0, cap);
    final isFilled = i < cur;
    final next = isFilled ? i : i + 1;
    final newRemaining = <int, int>{...remaining, level: next.clamp(0, cap)};
    onChanged({
      'max': {for (final e in max.entries) e.key.toString(): e.value},
      'remaining': {
        for (final e in newRemaining.entries) e.key.toString(): e.value,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final state = _parse();
    final levels = state.max.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            schema.label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          if (levels.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No slots — non-caster or sub-progression level.',
                style: TextStyle(fontSize: 11, color: palette.srdSubtitle),
              ),
            )
          else
            for (final lvl in levels)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        'L$lvl',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.srdInk,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (var i = 0; i < (state.max[lvl] ?? 0); i++)
                            _SlotPip(
                              filled: i < (state.remaining[lvl] ?? 0),
                              color: palette.featureCardAccent,
                              borderRadius: palette.cbr,
                              // Tappable independent of edit mode — slots
                              // get burned mid-encounter.
                              onTap: () => _toggle(
                                        state.max,
                                        state.remaining,
                                        lvl,
                                        i,
                                      ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${state.remaining[lvl] ?? 0}/${state.max[lvl] ?? 0}',
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.srdSubtitle,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _SlotPip extends StatelessWidget {
  final bool filled;
  final Color color;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  const _SlotPip({
    required this.filled,
    required this.color,
    required this.borderRadius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: borderRadius,
          border: Border.all(color: color, width: 1.5),
        ),
      ),
    );
  }
}

// --- LEVEL TABLE — level → value progression tablosu ---
/// Satır satır (level, value) editörü. Storage: `Map<String, num>`
/// (int key'ler JSON uyumu için string olarak saklanır).
class _LevelTableFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _LevelTableFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  List<MapEntry<int, num>> get _rows {
    if (value is! Map) return [];
    final m = value as Map;
    final entries = <MapEntry<int, num>>[];
    for (final e in m.entries) {
      final k = int.tryParse(e.key.toString());
      if (k == null) continue;
      final v = e.value is num
          ? e.value as num
          : num.tryParse(e.value.toString());
      if (v == null) continue;
      entries.add(MapEntry(k, v));
    }
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  void _write(List<MapEntry<int, num>> rows) {
    final out = <String, num>{};
    for (final r in rows) {
      out[r.key.toString()] = r.value;
    }
    onChanged(out);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    schema.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!readOnly)
                  IconButton(
                    tooltip: 'Add row',
                    icon: const Icon(Icons.add, size: 16),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      final nextLevel = rows.isEmpty ? 1 : rows.last.key + 1;
                      _write([...rows, MapEntry(nextLevel, 0)]);
                    },
                  ),
              ],
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'No levels — tap + to add',
                  style: TextStyle(fontSize: 11, color: palette.srdSubtitle),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4, top: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        'Level',
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.srdSubtitle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Value',
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.srdSubtitle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...rows.asMap().entries.map((entry) {
                final i = entry.key;
                final row = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          key: ValueKey('${schema.fieldKey}_lvl_${row.key}_$i'),
                          initialValue: row.key.toString(),
                          readOnly: readOnly,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                          ),
                          onChanged: (v) {
                            final newLevel = int.tryParse(v);
                            if (newLevel == null) return;
                            final updated = [...rows];
                            updated[i] = MapEntry(newLevel, row.value);
                            _write(updated);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('${schema.fieldKey}_val_${row.key}_$i'),
                          initialValue: row.value.toString(),
                          readOnly: readOnly,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                          ),
                          onChanged: (v) {
                            final newVal = num.tryParse(v);
                            if (newVal == null) return;
                            final updated = [...rows];
                            updated[i] = MapEntry(row.key, newVal);
                            _write(updated);
                          },
                        ),
                      ),
                      if (!readOnly)
                        IconButton(
                          icon: const Icon(Icons.close, size: 14),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            final updated = [...rows]..removeAt(i);
                            _write(updated);
                          },
                        ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// --- LEVEL TEXT TABLE ---
class _LevelTextTableFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _LevelTextTableFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  List<MapEntry<int, String>> get _rows {
    if (value is! Map) return [];
    final m = value as Map;
    final entries = <MapEntry<int, String>>[];
    for (final e in m.entries) {
      final k = int.tryParse(e.key.toString());
      if (k == null) continue;
      entries.add(MapEntry(k, e.value?.toString() ?? ''));
    }
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  void _write(List<MapEntry<int, String>> rows) {
    final out = <String, String>{};
    for (final r in rows) {
      out[r.key.toString()] = r.value;
    }
    onChanged(out);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    schema.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!readOnly)
                  IconButton(
                    tooltip: 'Add row',
                    icon: const Icon(Icons.add, size: 16),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      final nextLevel = rows.isEmpty ? 1 : rows.last.key + 1;
                      _write([...rows, MapEntry(nextLevel, '')]);
                    },
                  ),
              ],
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'No rows — tap + to add',
                  style: TextStyle(fontSize: 11, color: palette.srdSubtitle),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4, top: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        'Level',
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.srdSubtitle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.srdSubtitle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...rows.asMap().entries.map((entry) {
                final i = entry.key;
                final row = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          key: ValueKey('${schema.fieldKey}_lvl_${row.key}_$i'),
                          initialValue: row.key.toString(),
                          readOnly: readOnly,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                          ),
                          onChanged: (v) {
                            final newLevel = int.tryParse(v);
                            if (newLevel == null) return;
                            final updated = [...rows];
                            updated[i] = MapEntry(newLevel, row.value);
                            _write(updated);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('${schema.fieldKey}_txt_${row.key}_$i'),
                          initialValue: row.value,
                          readOnly: readOnly,
                          maxLines: null,
                          minLines: 1,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 6,
                            ),
                          ),
                          onChanged: (v) {
                            final updated = [...rows];
                            updated[i] = MapEntry(row.key, v);
                            _write(updated);
                          },
                        ),
                      ),
                      if (!readOnly)
                        IconButton(
                          icon: const Icon(Icons.close, size: 14),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            final updated = [...rows]..removeAt(i);
                            _write(updated);
                          },
                        ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// --- IMAGE GALLERY ---
class _ImageFieldWidget extends ConsumerStatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _ImageFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  ConsumerState<_ImageFieldWidget> createState() => _ImageFieldWidgetState();
}

class _ImageFieldWidgetState extends ConsumerState<_ImageFieldWidget> {
  int _currentIndex = 0;

  List<String> get _images {
    if (widget.value is List) return List<String>.from(widget.value as List);
    if (widget.value is String && (widget.value as String).isNotEmpty) {
      return [widget.value as String];
    }
    return [];
  }

  Future<void> _pickImages() async {
    // Single-image fields cap at 1; list fields share kMaxEntityImages.
    final cap = widget.schema.isList ? kMaxEntityImages : 1;
    final fieldKind = widget.schema.mediaKindWire != null
        ? MediaKind.fromWireName(widget.schema.mediaKindWire!)
        : null;
    final remaining = cap - _images.length;
    if (remaining <= 0) {
      showImageLimitSnackbar(context, cap);
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: widget.schema.isList,
    );
    if (result == null || result.files.isEmpty) return;
    var newPaths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .toList();
    if (newPaths.isEmpty) return;
    // Trim selection to the free slots; warn if extras were dropped.
    final overflow = newPaths.length > remaining;
    if (overflow) newPaths = newPaths.sublist(0, remaining);

    // Eager cloud upload — mirrors the entity portrait flow: online + signed
    // in → push to R2 now; offline / quota-full → keep the local path.
    final (:refs, :quotaExceeded, :tooLarge, :tooLargeActualBytes, pushWorldId: _) =
        await eagerUploadEntityImages(ref, newPaths, overrideKind: fieldKind);
    if (!mounted) return;
    widget.onChanged([..._images, ...refs]);
    if (quotaExceeded) showQuotaFullSnackbar(context);
    if (tooLarge) {
      showImageTooLargeSnackbar(
        context,
        maxBytes: (fieldKind ?? MediaKind.worldEntityImage).maxBytes,
        actualBytes: tooLargeActualBytes,
      );
    }
    if (overflow) showImageLimitSnackbar(context, cap);
  }

  void _removeImage(int index) {
    final removedRef = _images[index];
    final updated = List<String>.from(_images)..removeAt(index);
    if (_currentIndex >= updated.length && updated.isNotEmpty) {
      _currentIndex = updated.length - 1;
    }
    widget.onChanged(updated);
    // Orphan cloud cleanup — best-effort, fire-and-forget.
    unawaited(cleanupRemovedEntityImageRef(
      ref,
      removedRef,
      readOnly: widget.readOnly,
      remaining: updated,
    ));
  }

  void _showFullScreen(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              // U3: ekran genişliğinin 2x'i kadar decode — 4x zoom'da
              // makul keskinlik, ama full-res photo'nun unbounded RGBA
              // RAM'i (4000px → ~64MB) önlenir.
              child: AssetRefImage(
                ref: AssetRef(imagePath),
                fit: BoxFit.contain,
                cacheWidth:
                    cachePxFromLogical(ctx, MediaQuery.sizeOf(ctx).width * 2),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    if (_currentIndex >= images.length) {
      _currentIndex = images.isEmpty ? 0 : images.length - 1;
    }

    final palette = Theme.of(context).extension<DmToolColors>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.schema.label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        child: Column(
          children: [
            if (images.isNotEmpty) ...[
              // Image display with navigation
              SizedBox(
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: () =>
                          _showFullScreen(context, images[_currentIndex]),
                      child: ClipRRect(
                        borderRadius: palette?.cbr ?? BorderRadius.circular(4),
                        child: AssetRefImage(
                          ref: AssetRef(images[_currentIndex]),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          cacheWidth: 600,
                          errorWidget: Container(
                            color: palette?.canvasBg ?? Colors.grey.shade800,
                            child: Center(
                              child: Icon(
                                Icons.broken_image,
                                color: palette?.srdSubtitle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Navigation arrows
                    if (images.length > 1) ...[
                      Positioned(
                        left: 4,
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white70,
                          ),
                          onPressed: () => setState(
                            () => _currentIndex = (_currentIndex - 1).clamp(
                              0,
                              images.length - 1,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.white70,
                          ),
                          onPressed: () => setState(
                            () => _currentIndex = (_currentIndex + 1).clamp(
                              0,
                              images.length - 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                    // Counter badge
                    if (images.length > 1)
                      Positioned(
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius:
                                palette?.chr ?? BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_currentIndex + 1}/${images.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
            // Action buttons
            if (!widget.readOnly)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (images.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _removeImage(_currentIndex),
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text(
                        'Remove',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  if (images.length < kMaxEntityImages)
                    TextButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate, size: 16),
                      label: const Text(
                        'Add Image',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// --- IMAGE PER ERA ---
class _ImagePerEraFieldWidget extends ConsumerStatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _ImagePerEraFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  ConsumerState<_ImagePerEraFieldWidget> createState() =>
      _ImagePerEraFieldWidgetState();
}

class _ImagePerEraFieldWidgetState
    extends ConsumerState<_ImagePerEraFieldWidget> {
  Map<String, String> get _map {
    final v = widget.value;
    if (v is! Map) return const {};
    return {
      for (final entry in v.entries)
        if (entry.value is String && (entry.value as String).isNotEmpty)
          entry.key.toString(): entry.value as String,
    };
  }

  Future<void> _pickFor(String eraId) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    final kind = widget.schema.mediaKindWire != null
        ? MediaKind.fromWireName(widget.schema.mediaKindWire!)
        : null;
    final (:refs, :quotaExceeded, :tooLarge, :tooLargeActualBytes, pushWorldId: _) =
        await eagerUploadEntityImages(ref, [path], overrideKind: kind);
    if (!mounted || refs.isEmpty) return;
    final updated = Map<String, String>.from(_map);
    final oldRef = updated[eraId];
    updated[eraId] = refs.first;
    widget.onChanged(updated);
    if (quotaExceeded) showQuotaFullSnackbar(context);
    if (tooLarge) {
      showImageTooLargeSnackbar(
        context,
        maxBytes: (kind ?? MediaKind.worldEntityImage).maxBytes,
        actualBytes: tooLargeActualBytes,
      );
    }
    if (oldRef != null && oldRef != refs.first) {
      unawaited(cleanupRemovedEntityImageRef(
        ref,
        oldRef,
        readOnly: widget.readOnly,
        remaining: updated.values.toList(),
      ));
    }
  }

  void _removeFor(String eraId) {
    final updated = Map<String, String>.from(_map);
    final removed = updated.remove(eraId);
    widget.onChanged(updated);
    if (removed != null) {
      unawaited(cleanupRemovedEntityImageRef(
        ref,
        removed,
        readOnly: widget.readOnly,
        remaining: updated.values.toList(),
      ));
    }
  }

  String _eraLabel(WorldMapNotifier notifier, int index, MapEra era) {
    final names = notifier.eraNames;
    if (index < names.length) return names[index];
    return 'Era ${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>();
    final eras = ref.watch(worldMapProvider.select((s) => s.eras));
    final notifier = ref.read(worldMapProvider.notifier);
    final map = _map;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.schema.label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        child: eras.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'No eras defined yet. Add eras from the Map tab to set per-era images.',
                  style: TextStyle(
                    fontSize: 12,
                    color: palette?.srdSubtitle,
                  ),
                ),
              )
            : Column(
                children: [
                  for (var i = 0; i < eras.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 96,
                            height: 64,
                            child: map[eras[i].id] != null
                                ? GestureDetector(
                                    onTap: widget.readOnly
                                        ? null
                                        : () => _pickFor(eras[i].id),
                                    child: ClipRRect(
                                      borderRadius: palette?.cbr ??
                                          BorderRadius.circular(4),
                                      child: AssetRefImage(
                                        ref: AssetRef(map[eras[i].id]!),
                                        fit: BoxFit.cover,
                                        cacheWidth: 192,
                                        errorWidget: Container(
                                          color: palette?.canvasBg ??
                                              Colors.grey.shade800,
                                          child: const Center(
                                            child: Icon(Icons.broken_image,
                                                size: 18),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : OutlinedButton(
                                    onPressed: widget.readOnly
                                        ? null
                                        : () => _pickFor(eras[i].id),
                                    child: const Icon(
                                      Icons.add_photo_alternate,
                                      size: 18,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _eraLabel(notifier, i, eras[i]),
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (map[eras[i].id] != null && !widget.readOnly)
                            IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.delete, size: 18),
                              onPressed: () => _removeFor(eras[i].id),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

// --- FILE (PDF) ---
class _FileFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _FileFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final files = (value is List)
        ? List<String>.from(value as List)
        : <String>[];
    final palette = Theme.of(context).extension<DmToolColors>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: schema.label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        child: Column(
          children: [
            if (files.isNotEmpty)
              ...files.asMap().entries.map((entry) {
                final i = entry.key;
                final path = entry.value;
                final fileName = path.split('/').last.split('\\').last;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.picture_as_pdf,
                    size: 20,
                    color: palette?.tokenBorderHostile ?? Colors.red,
                  ),
                  title: Text(
                    fileName,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: readOnly
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            final updated = List<String>.from(files)
                              ..removeAt(i);
                            onChanged(updated);
                          },
                        ),
                );
              }),
            if (!readOnly)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final allowed = schema.validation.allowedExtensions;
                    final result = await FilePicker.platform.pickFiles(
                      type: allowed != null && allowed.isNotEmpty
                          ? FileType.custom
                          : FileType.any,
                      allowedExtensions: allowed != null && allowed.isNotEmpty
                          ? allowed
                          : null,
                      allowMultiple: true,
                    );
                    if (result == null || result.files.isEmpty) return;
                    final newPaths = result.files
                        .where((f) => f.path != null)
                        .map((f) => f.path!)
                        .toList();
                    onChanged([...files, ...newPaths]);
                  },
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: const Text('Add File', style: TextStyle(fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- PDF ---
class _PdfFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final WidgetRef? ref;

  const _PdfFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final files = (value is List)
        ? List<String>.from(value as List)
        : <String>[];
    final palette = Theme.of(context).extension<DmToolColors>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: schema.label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        child: Column(
          children: [
            if (files.isNotEmpty)
              ...files.asMap().entries.map((entry) {
                final i = entry.key;
                final path = entry.value;
                final fileName = path.split('/').last.split('\\').last;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.picture_as_pdf,
                    size: 20,
                    color: palette?.tokenBorderHostile ?? Colors.red,
                  ),
                  title: Text(
                    fileName,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    if (ref != null) {
                      ref!.read(pdfNavigationProvider.notifier).state = path;
                    } else {
                      Process.run('xdg-open', [path]);
                    }
                  },
                  onLongPress: () => Process.run('xdg-open', [path]),
                  trailing: readOnly
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            final updated = List<String>.from(files)
                              ..removeAt(i);
                            onChanged(updated);
                          },
                        ),
                );
              }),
            if (!readOnly)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                      allowMultiple: true,
                    );
                    if (result == null || result.files.isEmpty) return;
                    final newPaths = result.files
                        .where((f) => f.path != null)
                        .map((f) => f.path!)
                        .toList();
                    onChanged([...files, ...newPaths]);
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('Add PDF', style: TextStyle(fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- TAG LIST ---
class _TagListFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _TagListFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tags = (value is List)
        ? List<String>.from(value as List)
        : <String>[];

    if (readOnly && tags.isEmpty) return const SizedBox.shrink();

    return _LabeledFieldRow(
      label: schema.label,
      alignment: CrossAxisAlignment.start,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          ...tags.map(
            (tag) => Chip(
              label: Text(tag, style: const TextStyle(fontSize: 11)),
              deleteIcon: readOnly ? null : const Icon(Icons.close, size: 14),
              onDeleted: readOnly
                  ? null
                  : () {
                      tags.remove(tag);
                      onChanged(List<String>.from(tags));
                    },
              visualDensity: VisualDensity.compact,
            ),
          ),
          if (!readOnly)
            ActionChip(
              label: const Icon(Icons.add, size: 14),
              onPressed: () async {
                final controller = TextEditingController();
                final result = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Add Tag'),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Tag name (comma separated)',
                      ),
                      onSubmitted: (v) => Navigator.of(ctx).pop(v),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(controller.text),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ).whenComplete(controller.dispose);
                if (result != null && result.trim().isNotEmpty) {
                  final newTags = result
                      .split(',')
                      .map((t) => t.trim())
                      .where((t) => t.isNotEmpty)
                      .toList();
                  onChanged([...tags, ...newTags]);
                }
              },
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

// --- DATE ---
class _DateFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _DateFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = value?.toString() ?? '';
    DateTime? parsed;
    try {
      if (dateStr.isNotEmpty) parsed = DateTime.parse(dateStr);
    } catch (_) {}
    final display = parsed != null
        ? '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}'
        : dateStr;
    final hasValue = display.isNotEmpty;

    if (readOnly && !hasValue) return const SizedBox.shrink();

    return _LabeledFieldRow(
      label: schema.label,
      child: Row(
        children: [
          Expanded(
            child: Text(
              hasValue ? display : '—',
              style: hasValue
                  ? _fieldValueStyle(context)
                  : _fieldEmptyStyle(context),
            ),
          ),
          if (!readOnly)
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: parsed ?? DateTime.now(),
                  firstDate: DateTime(1000),
                  lastDate: DateTime(9999),
                );
                if (picked != null) {
                  onChanged(picked.toIso8601String().split('T').first);
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.calendar_today, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}

// --- PROFICIENCY TABLE (skills / saving throws) ---
/// Her satır `{name, ability, proficient, expertise, misc}`.
/// Toplam bonus `entityFields` varsa runtime'da hesaplanır:
///   `ability_mod + PB * (proficient ? 1 : 0) + PB * (expertise ? 1 : 0) + misc`
/// `stat_block` ve `proficiency_bonus` diğer field'lardan okunur.
class _ProficiencyTableFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, dynamic>? entityFields;

  const _ProficiencyTableFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entityFields,
  });

  List<Map<String, dynamic>> get _rows {
    if (value is Map && (value as Map)['rows'] is List) {
      final list = (value as Map)['rows'] as List;
      if (list.isNotEmpty) {
        return list
            .map<Map<String, dynamic>>(
              (r) => Map<String, dynamic>.from(r as Map),
            )
            .toList();
      }
    }
    // Fallback: schema-provided default rows (preset skills / saves) when
    // the entity's stored value is missing/empty. Lets cards filled before
    // defaults landed still render the canonical row list.
    final dv = schema.defaultValue;
    if (dv is Map && dv['rows'] is List) {
      return (dv['rows'] as List)
          .map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    }
    return const [];
  }

  int? _abilityScore(String ability) {
    final sb = entityFields?['stat_block'];
    if (sb is! Map) return null;
    final v = sb[ability];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  int _proficiencyBonus() {
    final pb = entityFields?['proficiency_bonus'];
    if (pb is int) return pb;
    if (pb is num) return pb.toInt();
    final parsed = int.tryParse(pb?.toString() ?? '');
    if (parsed != null) return parsed;
    // Fallback: level'dan türet.
    final cs = entityFields?['combat_stats'];
    int level = 1;
    if (cs is Map) {
      final lv = cs['level'];
      level = (lv is int) ? lv : int.tryParse(lv?.toString() ?? '') ?? 1;
    }
    return proficiencyBonusForLevel(level);
  }

  void _updateRow(int index, Map<String, dynamic> patch) {
    final rows = _rows;
    rows[index] = {...rows[index], ...patch};
    onChanged({'rows': rows});
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final pb = _proficiencyBonus();
    final outline = Theme.of(context).colorScheme.outline;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    schema.label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (entityFields != null)
                  Text(
                    'PB +$pb',
                    style: TextStyle(fontSize: 11, color: outline),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Header
            Row(
              children: [
                const SizedBox(width: 24), // prof
                const SizedBox(width: 24), // exp
                Expanded(
                  flex: 4,
                  child: Text(
                    'Skill',
                    style: TextStyle(fontSize: 10, color: outline),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    'Abil',
                    style: TextStyle(fontSize: 10, color: outline),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    'Misc',
                    style: TextStyle(fontSize: 10, color: outline),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    'Total',
                    style: TextStyle(fontSize: 10, color: outline),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const Divider(height: 8),
            if (rows.isEmpty)
              Text('No rows', style: TextStyle(color: outline, fontSize: 12))
            else
              ...rows.asMap().entries.map((e) {
                final i = e.key;
                final row = e.value;
                final name = row['name']?.toString() ?? '';
                final ability = row['ability']?.toString() ?? '';
                final proficient = row['proficient'] == true;
                final expertise = row['expertise'] == true;
                final misc = (row['misc'] is int)
                    ? row['misc'] as int
                    : int.tryParse(row['misc']?.toString() ?? '') ?? 0;

                final score = _abilityScore(ability);
                final mod = score != null ? abilityModifier(score) : null;
                final total =
                    (mod ?? 0) +
                    (proficient ? pb : 0) +
                    (expertise ? pb : 0) +
                    misc;
                final totalStr = entityFields != null && mod != null
                    ? (total >= 0 ? '+$total' : '$total')
                    : '—';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      _ProfDot(
                        active: proficient,
                        tooltip: 'Proficient',
                        onTap: readOnly
                            ? null
                            : () => _updateRow(i, {'proficient': !proficient}),
                      ),
                      _ProfDot(
                        active: expertise,
                        doubled: true,
                        tooltip: 'Expertise',
                        onTap: readOnly
                            ? null
                            : () => _updateRow(i, {'expertise': !expertise}),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(name, style: const TextStyle(fontSize: 12)),
                      ),
                      SizedBox(
                        width: 34,
                        child: Text(
                          ability,
                          style: TextStyle(fontSize: 10, color: outline),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: TextFormField(
                          key: ValueKey('pt_${schema.fieldKey}_${i}_misc'),
                          initialValue: misc == 0 ? '' : misc.toString(),
                          readOnly: readOnly,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            border: InputBorder.none,
                            hintText: '0',
                          ),
                          onChanged: (v) =>
                              _updateRow(i, {'misc': int.tryParse(v) ?? 0}),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          totalStr,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: proficient || expertise
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ProfDot extends StatelessWidget {
  final bool active;
  final bool doubled;
  final String tooltip;
  final VoidCallback? onTap;

  const _ProfDot({
    required this.active,
    required this.tooltip,
    this.doubled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: Container(
              width: doubled ? 14 : 12,
              height: doubled ? 14 : 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? color : Colors.transparent,
                border: Border.all(
                  color: active ? color : Theme.of(context).colorScheme.outline,
                  width: doubled ? 2 : 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- DICE (zar notasyonu: 2d6, 1d20+5, 3d8+2) ---
class _DiceFieldWidget extends StatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _DiceFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  State<_DiceFieldWidget> createState() => _DiceFieldWidgetState();
}

class _DiceFieldWidgetState extends State<_DiceFieldWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _DiceFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = widget.value?.toString() ?? '';
    if (_controller.text != newText && oldWidget.value != widget.value) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        key: ValueKey('${widget.schema.fieldKey}_dice'),
        controller: _controller,
        readOnly: widget.readOnly,
        decoration: InputDecoration(
          labelText: widget.schema.label,
          hintText: 'e.g. 2d6+3',
          isDense: true,
          prefixIcon: const Icon(Icons.casino, size: 18),
        ),
        onChanged: (v) => widget.onChanged(v),
      ),
    );
  }
}

// --- SPELL SLOT PROGRESSION — Class authored per-level override table ---
/// 2D grid of slot counts indexed by `[characterLevel][spellLevel]`.
/// Renders as a sparse 20-row table where the author can paste in a
/// homebrew progression that differs from the SRD `caster_kind` preset.
/// When the field is empty the runtime falls back to the SRD table
/// (handled in `spellSlotsForClass`). An "Auto-fill from caster_kind"
/// button seeds the grid with the SRD preset so the author can tweak
/// just the rows that differ instead of typing 180 cells from scratch.
///
/// Storage shape: `Map<String level, Map<String spellLevel, int count>>`
/// — keys stringified so the JSON round-trip preserves int semantics
/// without falling back to `_$identityFromJson` casts.
class _SpellSlotProgressionFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, dynamic>? entityFields;

  const _SpellSlotProgressionFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    required this.entityFields,
  });

  static const int _kMaxLevel = 20;
  static const int _kMaxSpellLevel = 9;

  Map<int, Map<int, int>> _parse() {
    final out = <int, Map<int, int>>{};
    if (value is! Map) return out;
    final m = value as Map;
    for (final entry in m.entries) {
      final lvl = entry.key is int
          ? entry.key as int
          : int.tryParse('${entry.key}');
      if (lvl == null) continue;
      final row = entry.value;
      if (row is! Map) continue;
      final cells = <int, int>{};
      for (final cell in row.entries) {
        final sl = cell.key is int
            ? cell.key as int
            : int.tryParse('${cell.key}');
        if (sl == null) continue;
        final n = cell.value;
        final count = n is int
            ? n
            : (n is num ? n.toInt() : int.tryParse('${n ?? ''}'));
        if (count == null) continue;
        cells[sl] = count;
      }
      out[lvl] = cells;
    }
    return out;
  }

  void _write(Map<int, Map<int, int>> table) {
    final out = <String, Map<String, int>>{};
    for (final entry in table.entries) {
      final row = <String, int>{};
      for (final cell in entry.value.entries) {
        if (cell.value <= 0) continue;
        row[cell.key.toString()] = cell.value;
      }
      if (row.isNotEmpty) out[entry.key.toString()] = row;
    }
    onChanged(out);
  }

  Map<int, Map<int, int>> _srdPreset() {
    final kind = parseCasterKind(entityFields?['caster_kind']);
    final out = <int, Map<int, int>>{};
    for (var lvl = 1; lvl <= _kMaxLevel; lvl++) {
      final slots = defaultSpellSlotsByLevel(kind, lvl);
      if (slots.isNotEmpty) out[lvl] = Map<int, int>.from(slots);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final table = _parse();
    final preset = _srdPreset();
    final kind = parseCasterKind(entityFields?['caster_kind']);
    final hasOverride = table.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    schema.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!readOnly) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 14),
                    label: const Text('Auto-fill SRD', style: TextStyle(fontSize: 11)),
                    onPressed: kind == CasterKind.none
                        ? null
                        : () => _write(preset),
                  ),
                  if (hasOverride)
                    TextButton.icon(
                      icon: const Icon(Icons.clear_all, size: 14),
                      label: const Text('Clear', style: TextStyle(fontSize: 11)),
                      onPressed: () => _write(const {}),
                    ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                hasOverride
                    ? 'Override active — runtime uses these counts; empty rows fall back to caster_kind preset.'
                    : 'No override — runtime uses caster_kind="${entityFields?['caster_kind'] ?? 'None'}" SRD preset (shown as placeholder).',
                style: TextStyle(fontSize: 10, color: palette.srdSubtitle),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 28,
                dataRowMinHeight: 28,
                dataRowMaxHeight: 32,
                columnSpacing: 12,
                horizontalMargin: 8,
                columns: [
                  const DataColumn(label: Text('Lvl', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                  for (var sl = 1; sl <= _kMaxSpellLevel; sl++)
                    DataColumn(
                      label: Text(
                        '$sl',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                      numeric: true,
                    ),
                ],
                rows: [
                  for (var lvl = 1; lvl <= _kMaxLevel; lvl++)
                    DataRow(
                      cells: [
                        DataCell(Text(
                          '$lvl',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: palette.srdInk,
                          ),
                        )),
                        for (var sl = 1; sl <= _kMaxSpellLevel; sl++)
                          DataCell(
                            _SlotCell(
                              value: table[lvl]?[sl] ?? 0,
                              hint: preset[lvl]?[sl] ?? 0,
                              readOnly: readOnly,
                              onChanged: (v) {
                                final next = Map<int, Map<int, int>>.from(table);
                                final row = Map<int, int>.from(next[lvl] ?? const {});
                                if (v <= 0) {
                                  row.remove(sl);
                                } else {
                                  row[sl] = v;
                                }
                                if (row.isEmpty) {
                                  next.remove(lvl);
                                } else {
                                  next[lvl] = row;
                                }
                                _write(next);
                              },
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotCell extends StatefulWidget {
  final int value;
  final int hint;
  final bool readOnly;
  final ValueChanged<int> onChanged;

  const _SlotCell({
    required this.value,
    required this.hint,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  State<_SlotCell> createState() => _SlotCellState();
}

class _SlotCellState extends State<_SlotCell> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value > 0 ? '${widget.value}' : '');
  }

  @override
  void didUpdateWidget(covariant _SlotCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final desired = widget.value > 0 ? '${widget.value}' : '';
    if (_ctrl.text != desired) _ctrl.text = desired;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final hintText = widget.hint > 0 ? '${widget.hint}' : '·';
    return SizedBox(
      width: 28,
      child: TextField(
        controller: _ctrl,
        readOnly: widget.readOnly,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          border: const OutlineInputBorder(),
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 11,
            color: palette.srdSubtitle.withValues(alpha: 0.5),
          ),
        ),
        onChanged: (v) {
          final n = int.tryParse(v) ?? 0;
          widget.onChanged(n);
        },
      ),
    );
  }
}

// --- CR CALCULATOR — Monster Challenge Rating estimator panel ---
/// Reads `ac` + `hp_average` from sibling fields (via `entityFields`) and
/// stores `{atk_bonus, dpr_avg, save_dc}` as its own value. Renders
/// defensive / offensive / suggested CR + XP. Authors copy the suggestion
/// into the `cr` + `xp` fields by hand — field widgets don't write to
/// sibling keys, so the helper is advisory rather than autoritative.
class _CrCalculatorFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, dynamic>? entityFields;

  const _CrCalculatorFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    required this.entityFields,
  });

  int _asInt(Object? raw, [int fallback = 0]) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? fallback;
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context);
    final inputs = value is Map ? Map<String, dynamic>.from(value as Map) : <String, dynamic>{};
    final atkBonus = _asInt(inputs['atk_bonus']);
    final dprAvg = _asInt(inputs['dpr_avg']);

    final ac = _asInt(entityFields?['ac']);
    final hp = _asInt(entityFields?['hp_average']);

    final defCr = (ac > 0 && hp > 0) ? defensiveCrFromAcHp(ac, hp) : '—';
    final offCr = (dprAvg > 0) ? offensiveCrFromAtkDpr(atkBonus, dprAvg) : '—';
    final suggested = (defCr != '—' && offCr != '—') ? combinedCr(defCr, offCr) : '—';
    final xp = suggested == '—' ? 0 : xpForCr(suggested);

    void write(String key, int? v) {
      final next = Map<String, dynamic>.from(inputs);
      if (v == null || v == 0) {
        next.remove(key);
      } else {
        next[key] = v;
      }
      onChanged(next);
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              schema.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'AC $ac · HP $hp · DMG p.273-275 estimate. Copy the suggestion into CR + XP fields manually.',
              style: TextStyle(fontSize: 10, color: palette.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    initialValue: atkBonus == 0 ? '' : '$atkBonus',
                    readOnly: readOnly,
                    style: const TextStyle(fontSize: 12),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Attack Bonus',
                      isDense: true,
                      labelStyle: TextStyle(fontSize: 11),
                    ),
                    onChanged: (s) => write('atk_bonus', int.tryParse(s.trim())),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    initialValue: dprAvg == 0 ? '' : '$dprAvg',
                    readOnly: readOnly,
                    style: const TextStyle(fontSize: 12),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'DPR (avg)',
                      isDense: true,
                      labelStyle: TextStyle(fontSize: 11),
                    ),
                    onChanged: (s) => write('dpr_avg', int.tryParse(s.trim())),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: inputs['save_dc'] == null
                        ? ''
                        : '${inputs['save_dc']}',
                    readOnly: readOnly,
                    style: const TextStyle(fontSize: 12),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Save DC',
                      isDense: true,
                      labelStyle: TextStyle(fontSize: 11),
                    ),
                    onChanged: (s) => write('save_dc', int.tryParse(s.trim())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  _crBadge('Defensive', defCr, Colors.blue),
                  const SizedBox(width: 10),
                  _crBadge('Offensive', offCr, Colors.deepOrange),
                  const SizedBox(width: 10),
                  _crBadge('Suggested', suggested, Colors.green, bold: true),
                  const SizedBox(width: 16),
                  Text(
                    'XP: $xp',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _crBadge(String label, String cr, Color color, {bool bold = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        Text(
          'CR $cr',
          style: TextStyle(
            fontSize: bold ? 14 : 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
