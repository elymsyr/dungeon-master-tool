import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/schema/field_schema.dart';

const _uuid = Uuid();

/// Tek bir [FieldSchema] tanımlama/düzenleme diyaloğu.
///
/// İki yerden kullanılır: template editörü (şemaya alan ekleme) ve kart
/// üzerindeki serbest alan ("bu karta bir alan ekle"). İkisi de aynı
/// `FieldSchema` şeklini ürettiği için tek diyalog yeter.
///
/// [existingKeys] çakışan `field_key` yazılmasını engeller ([initial]'ın
/// kendi key'i hariç tutulmalıdır).
Future<FieldSchema?> showFieldSchemaDialog({
  required BuildContext context,
  required String categoryId,
  FieldSchema? initial,
  Set<String> existingKeys = const {},
  String title = 'Field',
}) {
  return showDialog<FieldSchema>(
    context: context,
    builder: (ctx) => _FieldSchemaDialog(
      categoryId: categoryId,
      initial: initial,
      existingKeys: existingKeys,
      title: title,
    ),
  );
}

/// "Hit Points" → "hit_points". Boş/çakışan girdiyi çağıran taraf doğrular.
String fieldKeyFromLabel(String label) {
  final slug = label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return slug.isEmpty ? 'field' : slug;
}

class _FieldSchemaDialog extends StatefulWidget {
  final String categoryId;
  final FieldSchema? initial;
  final Set<String> existingKeys;
  final String title;

  const _FieldSchemaDialog({
    required this.categoryId,
    required this.initial,
    required this.existingKeys,
    required this.title,
  });

  @override
  State<_FieldSchemaDialog> createState() => _FieldSchemaDialogState();
}

class _FieldSchemaDialogState extends State<_FieldSchemaDialog> {
  late final TextEditingController _label =
      TextEditingController(text: widget.initial?.label ?? '');
  late final TextEditingController _key =
      TextEditingController(text: widget.initial?.fieldKey ?? '');
  late final TextEditingController _help =
      TextEditingController(text: widget.initial?.helpText ?? '');
  late final TextEditingController _options = TextEditingController(
    text: (widget.initial?.validation.allowedValues ?? const []).join(', '),
  );
  late final TextEditingController _allowedTypes = TextEditingController(
    text: (widget.initial?.validation.allowedTypes ?? const []).join(', '),
  );

  late FieldType _type = widget.initial?.fieldType ?? FieldType.text;
  late bool _isList = widget.initial?.isList ?? false;
  late bool _isRequired = widget.initial?.isRequired ?? false;

  /// Kullanıcı key'i elle düzenlediyse label'dan türetmeyi bırak.
  bool _keyTouched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _keyTouched = widget.initial != null;
  }

  @override
  void dispose() {
    _label.dispose();
    _key.dispose();
    _help.dispose();
    _options.dispose();
    _allowedTypes.dispose();
    super.dispose();
  }

  List<String> _csv(TextEditingController c) => c.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  void _submit() {
    final label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Label is required.');
      return;
    }
    final key = (_keyTouched ? _key.text.trim() : fieldKeyFromLabel(label));
    if (key.isEmpty) {
      setState(() => _error = 'Key is required.');
      return;
    }
    if (widget.existingKeys.contains(key)) {
      setState(() => _error = 'A field with key "$key" already exists here.');
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final options = _csv(_options);
    final allowed = _csv(_allowedTypes);
    final base = widget.initial ??
        FieldSchema(
          fieldId: _uuid.v4(),
          categoryId: widget.categoryId,
          fieldKey: key,
          label: label,
          fieldType: _type,
          createdAt: now,
          updatedAt: now,
        );
    Navigator.pop(
      context,
      base.copyWith(
        categoryId: widget.categoryId,
        fieldKey: key,
        label: label,
        fieldType: _type,
        isList: _isList,
        isRequired: _isRequired,
        helpText: _help.text.trim(),
        validation: base.validation.copyWith(
          allowedValues: _type == FieldType.enum_ && options.isNotEmpty
              ? options
              : null,
          allowedTypes: _type == FieldType.relation && allowed.isNotEmpty
              ? allowed
              : null,
        ),
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _label,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Label'),
                onChanged: (v) {
                  if (!_keyTouched) {
                    _key.text = fieldKeyFromLabel(v);
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _key,
                decoration: const InputDecoration(
                  labelText: 'Key',
                  helperText: 'Storage key. Cannot collide with another field.',
                ),
                onChanged: (_) => _keyTouched = true,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<FieldType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  for (final t in FieldType.values)
                    DropdownMenuItem(value: t, child: Text(t.name)),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              if (_type == FieldType.enum_) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _options,
                  decoration: const InputDecoration(
                    labelText: 'Options',
                    helperText: 'Comma separated.',
                  ),
                ),
              ],
              if (_type == FieldType.relation) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _allowedTypes,
                  decoration: const InputDecoration(
                    labelText: 'Allowed category slugs',
                    helperText: 'Comma separated. Empty = any category.',
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _help,
                decoration: const InputDecoration(labelText: 'Help text'),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _isList,
                title: const Text('List'),
                onChanged: (v) => setState(() => _isList = v),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _isRequired,
                title: const Text('Required'),
                onChanged: (v) => setState(() => _isRequired = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
