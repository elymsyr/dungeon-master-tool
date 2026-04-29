import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../application/character_creation/character_draft.dart';
import '../../../../../application/character_creation/character_draft_notifier.dart';
import '../../../../../application/providers/entity_provider.dart';
import '../../../../../domain/entities/entity.dart';

/// Subclass picker. Always shown when the chosen class has at least one
/// subclass entity referencing it via `parent_class_ref`. Selection is
/// stored on [CharacterDraft.subclassId]; the resolver gates feature
/// application by `granted_at_level`.
class SubclassStep extends ConsumerWidget {
  final CharacterDraft draft;
  final CharacterDraftNotifier notifier;

  const SubclassStep({
    super.key,
    required this.draft,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (draft.classId == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Pick a class first.'),
      );
    }
    final entities = ref.watch(entityProvider);
    final subclasses = <Entity>[
      for (final e in entities.values)
        if (e.categorySlug == 'subclass' &&
            _parentClassId(e) == draft.classId)
          e,
    ];
    if (subclasses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No subclasses available for this class.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in subclasses)
          RadioListTile<String>(
            value: s.id,
            groupValue: draft.subclassId,
            onChanged: (v) => notifier.setSubclass(v),
            title: Text(s.name),
            subtitle: s.description.isEmpty ? null : Text(s.description),
            dense: true,
          ),
        if (draft.subclassId != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear selection'),
              onPressed: () => notifier.setSubclass(null),
            ),
          ),
      ],
    );
  }

  static String? _parentClassId(Entity e) {
    final v = e.fields['parent_class_ref'];
    if (v is String && v.isNotEmpty) return v;
    return null;
  }
}
