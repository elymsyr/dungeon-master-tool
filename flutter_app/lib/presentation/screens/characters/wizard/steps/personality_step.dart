import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../application/character_creation/character_draft.dart';
import '../../../../../application/character_creation/character_draft_notifier.dart';
import '../../../../../application/character_creation/srd_trinkets.dart';
import '../../../../theme/dm_tool_colors.dart';

/// Wizard step that collects the SRD §1 "Imagine Your Past and Present"
/// flavor: four personality components (Traits/Ideals/Bonds/Flaws), a
/// free-form backstory prompt, and an optional Tiny trinket. Nothing on
/// this step gates progression — the wizard accepts blanks. Stored on
/// the draft so downstream tools (DM notes, NPC suggestions) can mine it.
class PersonalityStep extends StatelessWidget {
  final CharacterDraft draft;
  final CharacterDraftNotifier notifier;

  const PersonalityStep({
    super.key,
    required this.draft,
    required this.notifier,
  });

  static const List<String> _backstoryPrompts = [
    'Who raised you?',
    'Who was your dearest childhood friend?',
    'Did you grow up with a pet?',
    'Have you fallen in love? If so, with whom?',
    'Did you join an organization, such as a guild or religion?',
    'What elements of your past inspire you to go on adventures now?',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Optional — SRD §1 "Imagine Your Past and Present" flavor. '
          'Leave blank to skip.',
          style: TextStyle(
            fontSize: 12,
            color: palette.sidebarLabelSecondary,
          ),
        ),
        const SizedBox(height: 8),
        _Field(
          label: 'Personality Traits',
          hint:
              'e.g. "I am haunted by memories of war." (one or two short statements)',
          initialValue: draft.personalityTraits,
          onChanged: notifier.setPersonalityTraits,
        ),
        _Field(
          label: 'Ideals',
          hint:
              'e.g. "Greater Good. Our lot is to lay down our lives in defense of others."',
          initialValue: draft.ideals,
          onChanged: notifier.setIdeals,
        ),
        _Field(
          label: 'Bonds',
          hint:
              'e.g. "I will avenge the destruction of my homeland." — a connection to people, places, or events',
          initialValue: draft.bonds,
          onChanged: notifier.setBonds,
        ),
        _Field(
          label: 'Flaws',
          hint:
              'e.g. "I have a weakness for the vices of the city, especially hard drink." — one mortal trait',
          initialValue: draft.flaws,
          onChanged: notifier.setFlaws,
        ),
        const SizedBox(height: 4),
        Text(
          'Backstory prompts (answer the ones that spark something):',
          style: TextStyle(
            fontSize: 12,
            color: palette.sidebarLabelSecondary,
          ),
        ),
        const SizedBox(height: 4),
        for (final p in _backstoryPrompts)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '• $p',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _Field(
          label: 'Backstory',
          hint: 'A few sentences sketching your past and what drives you.',
          initialValue: draft.backstory,
          minLines: 3,
          maxLines: 6,
          onChanged: notifier.setBackstory,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Trinket',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.tabActiveText,
                ),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.casino, size: 14),
              label: const Text('Roll d100'),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => notifier.rollTrinket(kSrdTrinkets),
            ),
          ],
        ),
        _Field(
          label: '',
          hint:
              'A small item lightly touched by mystery — roll the SRD d100 above or write your own.',
          initialValue: draft.trinket,
          onChanged: notifier.setTrinket,
          // Re-key on draft.trinket so the random-roll button overwrites
          // the input's cached initialValue.
          fieldKey: ValueKey('trinket_${draft.trinket}'),
          maxLines: 2,
        ),
      ],
    );
  }
}

/// W3: text-field writes are debounced 250 ms before reaching the
/// notifier so typing doesn't fan out a full draft-graph rebuild per
/// keystroke. The Next-button validators still operate on the
/// notifier's current state; the debounce window is below human
/// perception (~250 ms) so by the time a user clicks Next, the buffered
/// write has flushed.
class _Field extends StatefulWidget {
  final String label;
  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final int minLines;
  final int maxLines;
  final Key? fieldKey;

  const _Field({
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines = 2,
    this.fieldKey,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      widget.onChanged(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        key: widget.fieldKey,
        initialValue: widget.initialValue,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          labelText: widget.label.isEmpty ? null : widget.label,
          hintText: widget.hint,
          isDense: true,
        ),
        onChanged: _onChanged,
      ),
    );
  }
}
