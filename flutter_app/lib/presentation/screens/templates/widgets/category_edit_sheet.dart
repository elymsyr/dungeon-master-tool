import 'package:flutter/material.dart';

import '../../../../application/providers/template_editor_provider.dart';
import '../../../../core/utils/screen_type.dart';
import '../../../../domain/entities/schema/entity_category_schema.dart';
import '../../../theme/dm_tool_colors.dart';

/// Result of the category add/edit form. Returned via `Navigator.pop` from
/// [showCategoryEditSheet]; `null` means the user cancelled.
class CategoryEditResult {
  final String name;
  final String slug;
  final String icon;
  final String color;

  const CategoryEditResult({
    required this.name,
    required this.slug,
    required this.icon,
    required this.color,
  });
}

/// Curated category color swatches (hex, as stored on `EntityCategorySchema.color`).
const List<String> kCategoryColorSwatches = [
  '#808080', '#E57373', '#F06292', '#BA68C8', '#9575CD',
  '#7986CB', '#64B5F6', '#4FC3F7', '#4DD0E1', '#4DB6AC',
  '#81C784', '#AED581', '#DCE775', '#FFD54F', '#FFB74D',
  '#FF8A65', '#A1887F', '#90A4AE',
];

/// Curated icon choices — every name here is resolvable by the shared
/// `_iconFromName` map used across the app, so a chosen icon renders correctly
/// on the world map and elsewhere. The empty option clears the icon.
const List<(String, IconData)> kCategoryIconChoices = [
  ('', Icons.block),
  ('person', Icons.person),
  ('person_pin', Icons.person_pin),
  ('pets', Icons.pets),
  ('shield', Icons.shield),
  ('auto_awesome', Icons.auto_awesome),
  ('auto_fix_high', Icons.auto_fix_high),
  ('stars', Icons.stars),
  ('diversity_3', Icons.diversity_3),
  ('history_edu', Icons.history_edu),
  ('backpack', Icons.backpack),
  ('inventory_2', Icons.inventory_2),
  ('build', Icons.build),
  ('diamond', Icons.diamond),
  ('album', Icons.album),
  ('directions_boat', Icons.directions_boat),
  ('flash_on', Icons.flash_on),
  ('fork_right', Icons.fork_right),
  ('workspaces', Icons.workspaces),
  ('location_on', Icons.location_on),
  ('castle', Icons.castle),
  ('forest', Icons.forest),
  ('flag', Icons.flag),
  ('event', Icons.event),
];

/// Opens the responsive category add/edit form: a bottom sheet on touch
/// platforms, a centered dialog on desktop/pointer (roadmap §1.5). Returns the
/// edited values, or `null` if cancelled.
///
/// [existing] non-null ⇒ edit mode (fields pre-filled, slug not auto-derived).
/// [siblingSlugs] are the slugs of the *other* categories, used for live
/// duplicate-slug feedback in the form (the notifier re-validates on commit).
Future<CategoryEditResult?> showCategoryEditSheet(
  BuildContext context, {
  EntityCategorySchema? existing,
  required List<String> siblingSlugs,
}) {
  final form = _CategoryEditForm(existing: existing, siblingSlugs: siblingSlugs);
  if (isTouchPlatform) {
    return showModalBottomSheet<CategoryEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: form,
      ),
    );
  }
  return showDialog<CategoryEditResult>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: form,
      ),
    ),
  );
}

class _CategoryEditForm extends StatefulWidget {
  final EntityCategorySchema? existing;
  final List<String> siblingSlugs;

  const _CategoryEditForm({required this.existing, required this.siblingSlugs});

  @override
  State<_CategoryEditForm> createState() => _CategoryEditFormState();
}

class _CategoryEditFormState extends State<_CategoryEditForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _slugCtrl;
  late String _icon;
  late String _color;

  /// While true (create mode, untouched slug), the slug tracks the name.
  bool _slugAutoFollows = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _slugCtrl = TextEditingController(text: e?.slug ?? '');
    _icon = e?.icon ?? '';
    _color = (e?.color.isNotEmpty ?? false) ? e!.color : '#808080';
    _slugAutoFollows = !_isEdit; // new categories derive slug from name
    _nameCtrl.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (!_slugAutoFollows) return;
    _slugCtrl.value = TextEditingValue(
      text: categorySlugify(_nameCtrl.text),
    );
    setState(() {});
  }

  String? get _slugError {
    final slug = _slugCtrl.text.trim();
    if (slug.isEmpty) return 'Slug is required.';
    if (!templateSlugPattern.hasMatch(slug)) {
      return 'Lowercase letters, numbers and single hyphens only.';
    }
    if (reservedCategorySlugs.contains(slug)) return 'This slug is reserved.';
    if (widget.siblingSlugs.contains(slug)) {
      return 'Another category already uses this slug.';
    }
    return null;
  }

  String? get _nameError =>
      _nameCtrl.text.trim().isEmpty ? 'Name is required.' : null;

  bool get _canSave => _nameError == null && _slugError == null;

  void _submit() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      CategoryEditResult(
        name: _nameCtrl.text.trim(),
        slug: categorySlugify(_slugCtrl.text),
        icon: _icon,
        color: _color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final slugError = _slugError;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'Edit category' : 'New category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: palette.tabActiveText,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Spell, Faction, Trinket',
                border: const OutlineInputBorder(),
                errorText:
                    _nameCtrl.text.isEmpty ? null : _nameError,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _slugCtrl,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Slug',
                helperText: 'Stable import key — keep it short and unique.',
                border: const OutlineInputBorder(),
                errorText: _slugCtrl.text.isEmpty ? null : slugError,
                prefixIcon: const Icon(Icons.tag, size: 18),
              ),
              onChanged: (v) {
                // First manual edit detaches the slug from the name.
                _slugAutoFollows = false;
                final normalized = categorySlugify(v);
                if (normalized != v) {
                  _slugCtrl.value = TextEditingValue(
                    text: normalized,
                    selection:
                        TextSelection.collapsed(offset: normalized.length),
                  );
                }
                setState(() {});
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            Text('Color', style: _labelStyle(palette)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hex in kCategoryColorSwatches)
                  _ColorSwatch(
                    hex: hex,
                    selected: hex.toUpperCase() == _color.toUpperCase(),
                    onTap: () => setState(() => _color = hex),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Icon', style: _labelStyle(palette)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in kCategoryIconChoices)
                  _IconChoice(
                    name: choice.$1,
                    icon: choice.$2,
                    selected: choice.$1 == _icon,
                    palette: palette,
                    onTap: () => setState(() => _icon = choice.$1),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _canSave ? _submit : null,
                  child: Text(_isEdit ? 'Save' : 'Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _labelStyle(DmToolColors palette) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: palette.sidebarLabelSecondary,
      );
}

class _ColorSwatch extends StatelessWidget {
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _parseHexColor(hex) ?? Colors.grey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.black26,
            width: selected ? 3 : 1,
          ),
          boxShadow: selected
              ? [const BoxShadow(color: Colors.black45, blurRadius: 4)]
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool selected;
  final DmToolColors palette;
  final VoidCallback onTap;

  const _IconChoice({
    required this.name,
    required this.icon,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: selected
              ? palette.featureCardAccent.withValues(alpha: 0.2)
              : palette.featureCardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? palette.featureCardAccent : palette.featureCardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: name.isEmpty
              ? palette.sidebarLabelSecondary
              : palette.tabActiveText,
        ),
      ),
    );
  }
}

Color? _parseHexColor(String hex) {
  var h = hex.trim();
  if (h.isEmpty) return null;
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  final value = int.tryParse(h, radix: 16);
  return value == null ? null : Color(value);
}
