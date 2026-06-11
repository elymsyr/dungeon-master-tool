import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/template_editor_provider.dart';
import '../../../../domain/entities/schema/entity_category_schema.dart';
import '../../../../domain/entities/schema/field_schema.dart';
import '../../../theme/dm_tool_colors.dart';
import 'field_type_meta.dart';

/// Right-hand inspector of the Template Editor (roadmap §1.5).
///
/// Read-only in PR-1.5: shows the selected field's full definition, or — when
/// no field is selected — the active category's metadata. Phase 2.1/2.2 swap
/// the read-only rows for the label/key/type/typeConfig editing forms; this is
/// the mount point.
class TemplateFieldInspector extends ConsumerWidget {
  /// When true (phone edit page), only the field detail is shown — no category
  /// fallback (the phone has a dedicated category surface upstream).
  final bool fieldOnly;

  const TemplateFieldInspector({super.key, this.fieldOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final state = ref.watch(templateEditorProvider);
    final field = state.selectedField;
    final category = state.selectedCategory;

    Widget body;
    if (field != null) {
      body = _FieldDetail(field: field, palette: palette);
    } else if (!fieldOnly && category != null) {
      body = _CategoryDetail(category: category, palette: palette);
    } else {
      body = _Placeholder(
        text: fieldOnly
            ? 'No field selected.'
            : 'Select a field to inspect it.',
        palette: palette,
      );
    }

    return Container(
      color: palette.featureCardBg,
      child: body,
    );
  }
}

class _FieldDetail extends StatelessWidget {
  final FieldSchema field;
  final DmToolColors palette;

  const _FieldDetail({required this.field, required this.palette});

  @override
  Widget build(BuildContext context) {
    final meta = FieldTypeMeta.of(field.fieldType);
    final rules = field.rules ?? const [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(meta.icon, size: 22, color: palette.featureCardAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  field.label.isEmpty ? field.fieldKey : field.label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: palette.tabActiveText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            meta.summary,
            style: TextStyle(
              fontSize: 12,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _Section(title: 'Definition', palette: palette, children: [
            _Row(label: 'Key', value: field.fieldKey, mono: true, palette: palette),
            _Row(label: 'Type', value: meta.label, palette: palette),
            if (meta.ruleCapable)
              _Row(label: 'Rule-capable', value: 'Yes', palette: palette),
            _Row(
              label: 'Required',
              value: field.isRequired ? 'Yes' : 'No',
              palette: palette,
            ),
            _Row(
              label: 'List',
              value: field.isList ? 'Yes' : 'No',
              palette: palette,
            ),
            if (field.hasEquip)
              _Row(label: 'Equippable', value: 'Yes', palette: palette),
            _Row(
              label: 'Visibility',
              value: _visibilityLabel(field.visibility),
              palette: palette,
            ),
            if (field.groupId != null && field.groupId!.isNotEmpty)
              _Row(label: 'Group', value: field.groupId!, mono: true, palette: palette),
            if (field.gridColumnSpan != 1)
              _Row(
                label: 'Column span',
                value: '${field.gridColumnSpan}',
                palette: palette,
              ),
          ]),
          if (field.placeholder.isNotEmpty || field.helpText.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Section(title: 'Guidance', palette: palette, children: [
              if (field.placeholder.isNotEmpty)
                _Row(
                  label: 'Placeholder',
                  value: field.placeholder,
                  palette: palette,
                ),
              if (field.helpText.isNotEmpty)
                _Row(label: 'Help', value: field.helpText, palette: palette),
            ]),
          ],
          if (_hasValidation(field.validation)) ...[
            const SizedBox(height: 14),
            _Section(title: 'Validation', palette: palette, children: [
              if (field.validation.minValue != null)
                _Row(label: 'Min', value: '${field.validation.minValue}', palette: palette),
              if (field.validation.maxValue != null)
                _Row(label: 'Max', value: '${field.validation.maxValue}', palette: palette),
              if (field.validation.minLength != null)
                _Row(label: 'Min length', value: '${field.validation.minLength}', palette: palette),
              if (field.validation.maxLength != null)
                _Row(label: 'Max length', value: '${field.validation.maxLength}', palette: palette),
              if (field.validation.allowedValues != null &&
                  field.validation.allowedValues!.isNotEmpty)
                _Row(
                  label: 'Allowed',
                  value: field.validation.allowedValues!.join(', '),
                  palette: palette,
                ),
              if (field.validation.allowedTypes != null &&
                  field.validation.allowedTypes!.isNotEmpty)
                _Row(
                  label: 'Allowed types',
                  value: field.validation.allowedTypes!.join(', '),
                  palette: palette,
                ),
            ]),
          ],
          if (field.typeConfig != null && field.typeConfig!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _JsonSection(
              title: 'Type configuration',
              data: field.typeConfig!,
              palette: palette,
            ),
          ],
          const SizedBox(height: 14),
          _RulesSection(rules: rules, palette: palette),
        ],
      ),
    );
  }
}

class _RulesSection extends StatelessWidget {
  final List<Map<String, dynamic>> rules;
  final DmToolColors palette;

  const _RulesSection({required this.rules, required this.palette});

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) {
      return _Section(title: 'Rules', palette: palette, children: [
        Text(
          'No rules attached. Mechanics for this template are authored in '
          'Phase 3 (Just-In-Time evolution); until then every card resolves '
          'rule-free.',
          style: TextStyle(
            fontSize: 12,
            color: palette.sidebarLabelSecondary,
            height: 1.4,
          ),
        ),
      ]);
    }
    return _JsonSection(
      title: 'Rules (${rules.length})',
      data: {'rules': rules},
      palette: palette,
    );
  }
}

class _CategoryDetail extends StatelessWidget {
  final EntityCategorySchema category;
  final DmToolColors palette;

  const _CategoryDetail({required this.category, required this.palette});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: palette.tabActiveText,
            ),
          ),
          const SizedBox(height: 12),
          _Section(title: 'Category', palette: palette, children: [
            _Row(label: 'Slug', value: category.slug, mono: true, palette: palette),
            _Row(label: 'Fields', value: '${category.fields.length}', palette: palette),
            if (category.icon.isNotEmpty)
              _Row(label: 'Icon', value: category.icon, palette: palette),
            _Row(label: 'Color', value: category.color, mono: true, palette: palette),
            if (category.isArchived)
              _Row(label: 'Archived', value: 'Yes', palette: palette),
            if (category.allowedInSections.isNotEmpty)
              _Row(
                label: 'Sections',
                value: category.allowedInSections.join(', '),
                palette: palette,
              ),
          ]),
          if (category.fieldGroups.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Section(
              title: 'Groups (${category.fieldGroups.length})',
              palette: palette,
              children: [
                for (final g in category.fieldGroups)
                  _Row(
                    label: g.name.isEmpty ? '(unnamed)' : g.name,
                    value: '${g.gridColumns} col',
                    palette: palette,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Select a field on the left to inspect it.',
            style: TextStyle(
              fontSize: 12,
              color: palette.sidebarLabelSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final DmToolColors palette;

  const _Section({
    required this.title,
    required this.children,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final DmToolColors palette;

  const _Row({
    required this.label,
    required this.value,
    required this.palette,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: palette.tabActiveText,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonSection extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;
  final DmToolColors palette;

  const _JsonSection({
    required this.title,
    required this.data,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    String pretty;
    try {
      pretty = const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      pretty = data.toString();
    }
    return _Section(title: title, palette: palette, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.htmlCodeBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: SelectableText(
          pretty,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.4,
            fontFamily: 'monospace',
            color: palette.tabActiveText,
          ),
        ),
      ),
    ]);
  }
}

class _Placeholder extends StatelessWidget {
  final String text;
  final DmToolColors palette;

  const _Placeholder({required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: palette.sidebarLabelSecondary),
        ),
      ),
    );
  }
}

String _visibilityLabel(FieldVisibility v) {
  switch (v) {
    case FieldVisibility.shared:
      return 'Shared';
    case FieldVisibility.dmOnly:
      return 'DM only';
    case FieldVisibility.private_:
      return 'Private';
  }
}

bool _hasValidation(FieldValidation v) {
  return v.minValue != null ||
      v.maxValue != null ||
      v.minLength != null ||
      v.maxLength != null ||
      (v.allowedValues?.isNotEmpty ?? false) ||
      (v.allowedTypes?.isNotEmpty ?? false);
}
