import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/edit_mode_provider.dart';
import '../../../../domain/dnd5e/spell/casting_time.dart';
import '../../../../domain/dnd5e/spell/spell_components.dart';
import '../../../../domain/dnd5e/spell/spell_duration.dart';
import '../../../../domain/dnd5e/spell/spell_range.dart';
import '../../../theme/dm_tool_colors.dart';

/// Structured editors for the tagged-union spell subfields: casting time,
/// range, duration, components. Each widget renders the current value as
/// plain text in read-only mode and as a popup-driven compound editor in
/// edit mode (enum tag + typed value slot when the chosen tag needs one).

// ---------------------------------------------------------------------------
// Casting Time
// ---------------------------------------------------------------------------

enum _CtTag { action, bonusAction, reaction, minutes, hours }

_CtTag _tagFor(CastingTime c) => switch (c) {
      ActionCast() => _CtTag.action,
      BonusActionCast() => _CtTag.bonusAction,
      ReactionCast() => _CtTag.reaction,
      MinutesCast() => _CtTag.minutes,
      HoursCast() => _CtTag.hours,
    };

String _ctTagLabel(_CtTag t) => switch (t) {
      _CtTag.action => 'Action',
      _CtTag.bonusAction => 'Bonus Action',
      _CtTag.reaction => 'Reaction',
      _CtTag.minutes => 'Minutes',
      _CtTag.hours => 'Hours',
    };

String formatCastingTime(CastingTime c) => switch (c) {
      ActionCast() => '1 action',
      BonusActionCast() => '1 bonus action',
      ReactionCast(trigger: final t) => '1 reaction ($t)',
      MinutesCast(minutes: final m) => '$m minute${m == 1 ? '' : 's'}',
      HoursCast(hours: final h) => '$h hour${h == 1 ? '' : 's'}',
    };

class SpellCastingTimeEditor extends ConsumerWidget {
  final CastingTime value;
  final ValueChanged<CastingTime> onCommit;

  const SpellCastingTimeEditor({
    required this.value,
    required this.onCommit,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMode = ref.watch(editModeProvider);
    if (!editMode) return Text(formatCastingTime(value));

    final tag = _tagFor(value);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EnumPopup<_CtTag>(
          value: tag,
          options: _CtTag.values,
          labelOf: _ctTagLabel,
          onCommit: (t) => onCommit(_ctFromTag(t, value)),
        ),
        if (tag == _CtTag.minutes || tag == _CtTag.hours) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 60,
            child: _IntInlineField(
              value: tag == _CtTag.minutes
                  ? (value as MinutesCast).minutes
                  : (value as HoursCast).hours,
              onCommit: (n) {
                if (n <= 0) return;
                onCommit(tag == _CtTag.minutes
                    ? MinutesCast(n)
                    : HoursCast(n));
              },
            ),
          ),
        ],
        if (tag == _CtTag.reaction) ...[
          const SizedBox(width: 6),
          Expanded(
            child: _StringInlineField(
              value: (value as ReactionCast).trigger,
              placeholder: 'Trigger',
              onCommit: (s) {
                final t = s.trim();
                if (t.isEmpty) return;
                onCommit(ReactionCast(t));
              },
            ),
          ),
        ],
      ],
    );
  }
}

CastingTime _ctFromTag(_CtTag t, CastingTime old) => switch (t) {
      _CtTag.action => const ActionCast(),
      _CtTag.bonusAction => const BonusActionCast(),
      _CtTag.reaction =>
        ReactionCast(old is ReactionCast ? old.trigger : 'when triggered'),
      _CtTag.minutes =>
        MinutesCast(old is MinutesCast ? old.minutes : 1),
      _CtTag.hours => HoursCast(old is HoursCast ? old.hours : 1),
    };

// ---------------------------------------------------------------------------
// Range
// ---------------------------------------------------------------------------

enum _RgTag { self, touch, feet, miles, sight, unlimited }

_RgTag _rgTagFor(SpellRange r) => switch (r) {
      SelfRange() => _RgTag.self,
      TouchRange() => _RgTag.touch,
      FeetRange() => _RgTag.feet,
      MilesRange() => _RgTag.miles,
      SightRange() => _RgTag.sight,
      UnlimitedRange() => _RgTag.unlimited,
    };

String _rgTagLabel(_RgTag t) => switch (t) {
      _RgTag.self => 'Self',
      _RgTag.touch => 'Touch',
      _RgTag.feet => 'Feet',
      _RgTag.miles => 'Miles',
      _RgTag.sight => 'Sight',
      _RgTag.unlimited => 'Unlimited',
    };

String formatSpellRange(SpellRange r) => switch (r) {
      SelfRange() => 'Self',
      TouchRange() => 'Touch',
      SightRange() => 'Sight',
      UnlimitedRange() => 'Unlimited',
      FeetRange(feet: final f) => '${f.toStringAsFixed(0)} ft.',
      MilesRange(miles: final m) => '${m.toStringAsFixed(0)} mi.',
    };

class SpellRangeEditor extends ConsumerWidget {
  final SpellRange value;
  final ValueChanged<SpellRange> onCommit;

  const SpellRangeEditor({
    required this.value,
    required this.onCommit,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMode = ref.watch(editModeProvider);
    if (!editMode) return Text(formatSpellRange(value));

    final tag = _rgTagFor(value);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EnumPopup<_RgTag>(
          value: tag,
          options: _RgTag.values,
          labelOf: _rgTagLabel,
          onCommit: (t) => onCommit(_rgFromTag(t, value)),
        ),
        if (tag == _RgTag.feet || tag == _RgTag.miles) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 70,
            child: _IntInlineField(
              value: tag == _RgTag.feet
                  ? (value as FeetRange).feet.toInt()
                  : (value as MilesRange).miles.toInt(),
              onCommit: (n) {
                if (n <= 0) return;
                onCommit(tag == _RgTag.feet
                    ? FeetRange(n.toDouble())
                    : MilesRange(n.toDouble()));
              },
            ),
          ),
        ],
      ],
    );
  }
}

SpellRange _rgFromTag(_RgTag t, SpellRange old) => switch (t) {
      _RgTag.self => const SelfRange(),
      _RgTag.touch => const TouchRange(),
      _RgTag.feet =>
        FeetRange(old is FeetRange ? old.feet : 30),
      _RgTag.miles =>
        MilesRange(old is MilesRange ? old.miles : 1),
      _RgTag.sight => const SightRange(),
      _RgTag.unlimited => const UnlimitedRange(),
    };

// ---------------------------------------------------------------------------
// Duration
// ---------------------------------------------------------------------------

enum _DurTag {
  instantaneous,
  rounds,
  minutes,
  hours,
  days,
  untilDispelled,
  special,
}

_DurTag _durTagFor(SpellDuration d) => switch (d) {
      SpellInstantaneous() => _DurTag.instantaneous,
      SpellRounds() => _DurTag.rounds,
      SpellMinutes() => _DurTag.minutes,
      SpellHours() => _DurTag.hours,
      SpellDays() => _DurTag.days,
      SpellUntilDispelled() => _DurTag.untilDispelled,
      SpellSpecial() => _DurTag.special,
    };

String _durTagLabel(_DurTag t) => switch (t) {
      _DurTag.instantaneous => 'Instantaneous',
      _DurTag.rounds => 'Rounds',
      _DurTag.minutes => 'Minutes',
      _DurTag.hours => 'Hours',
      _DurTag.days => 'Days',
      _DurTag.untilDispelled => 'Until Dispelled',
      _DurTag.special => 'Special',
    };

bool _durHasConcentration(_DurTag t) =>
    t == _DurTag.rounds || t == _DurTag.minutes || t == _DurTag.hours;

bool _durHasValue(_DurTag t) =>
    t == _DurTag.rounds ||
    t == _DurTag.minutes ||
    t == _DurTag.hours ||
    t == _DurTag.days;

String formatSpellDuration(SpellDuration d) => switch (d) {
      SpellInstantaneous() => 'Instantaneous',
      SpellRounds(rounds: final r, concentration: final c) =>
        '${c ? 'Concentration, up to ' : ''}$r round${r == 1 ? '' : 's'}',
      SpellMinutes(minutes: final m, concentration: final c) =>
        '${c ? 'Concentration, up to ' : ''}$m minute${m == 1 ? '' : 's'}',
      SpellHours(hours: final h, concentration: final c) =>
        '${c ? 'Concentration, up to ' : ''}$h hour${h == 1 ? '' : 's'}',
      SpellDays(days: final d) => '$d day${d == 1 ? '' : 's'}',
      SpellUntilDispelled() => 'Until dispelled',
      SpellSpecial(description: final s) => 'Special ($s)',
    };

class SpellDurationEditor extends ConsumerWidget {
  final SpellDuration value;
  final ValueChanged<SpellDuration> onCommit;

  const SpellDurationEditor({
    required this.value,
    required this.onCommit,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMode = ref.watch(editModeProvider);
    if (!editMode) return Text(formatSpellDuration(value));

    final tag = _durTagFor(value);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _EnumPopup<_DurTag>(
          value: tag,
          options: _DurTag.values,
          labelOf: _durTagLabel,
          onCommit: (t) => onCommit(_durFromTag(t, value)),
        ),
        if (_durHasValue(tag))
          SizedBox(
            width: 60,
            child: _IntInlineField(
              value: _durValueOf(value),
              onCommit: (n) {
                if (n <= 0) return;
                onCommit(_durReplaceValue(value, n));
              },
            ),
          ),
        if (_durHasConcentration(tag))
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: _durConcentrationOf(value),
                visualDensity: VisualDensity.compact,
                onChanged: (v) => onCommit(
                    _durReplaceConcentration(value, v ?? false)),
              ),
              const Text('Concentration'),
            ],
          ),
        if (tag == _DurTag.special)
          SizedBox(
            width: 160,
            child: _StringInlineField(
              value: (value as SpellSpecial).description,
              placeholder: 'Describe…',
              onCommit: (s) {
                final t = s.trim();
                if (t.isEmpty) return;
                onCommit(SpellSpecial(t));
              },
            ),
          ),
      ],
    );
  }
}

int _durValueOf(SpellDuration d) => switch (d) {
      SpellRounds(rounds: final r) => r,
      SpellMinutes(minutes: final m) => m,
      SpellHours(hours: final h) => h,
      SpellDays(days: final x) => x,
      _ => 0,
    };

bool _durConcentrationOf(SpellDuration d) => switch (d) {
      SpellRounds(concentration: final c) => c,
      SpellMinutes(concentration: final c) => c,
      SpellHours(concentration: final c) => c,
      _ => false,
    };

SpellDuration _durReplaceValue(SpellDuration old, int n) => switch (old) {
      SpellRounds(concentration: final c) =>
        SpellRounds(rounds: n, concentration: c),
      SpellMinutes(concentration: final c) =>
        SpellMinutes(minutes: n, concentration: c),
      SpellHours(concentration: final c) =>
        SpellHours(hours: n, concentration: c),
      SpellDays() => SpellDays(n),
      _ => old,
    };

SpellDuration _durReplaceConcentration(SpellDuration old, bool c) =>
    switch (old) {
      SpellRounds(rounds: final r) =>
        SpellRounds(rounds: r, concentration: c),
      SpellMinutes(minutes: final m) =>
        SpellMinutes(minutes: m, concentration: c),
      SpellHours(hours: final h) =>
        SpellHours(hours: h, concentration: c),
      _ => old,
    };

SpellDuration _durFromTag(_DurTag t, SpellDuration old) => switch (t) {
      _DurTag.instantaneous => const SpellInstantaneous(),
      _DurTag.rounds => SpellRounds(
          rounds: old is SpellRounds ? old.rounds : 1,
          concentration: _durConcentrationOf(old)),
      _DurTag.minutes => SpellMinutes(
          minutes: old is SpellMinutes ? old.minutes : 1,
          concentration: _durConcentrationOf(old)),
      _DurTag.hours => SpellHours(
          hours: old is SpellHours ? old.hours : 1,
          concentration: _durConcentrationOf(old)),
      _DurTag.days => SpellDays(old is SpellDays ? old.days : 1),
      _DurTag.untilDispelled => const SpellUntilDispelled(),
      _DurTag.special =>
        SpellSpecial(old is SpellSpecial ? old.description : 'Special'),
    };

// ---------------------------------------------------------------------------
// Components
// ---------------------------------------------------------------------------

String formatSpellComponents(List<SpellComponent> cs) {
  final parts = <String>[];
  String? materials;
  for (final c in cs) {
    switch (c) {
      case VerbalComponent():
        parts.add('V');
      case SomaticComponent():
        parts.add('S');
      case MaterialComponent(description: final d):
        parts.add('M');
        materials = d;
    }
  }
  final base = parts.isEmpty ? '—' : parts.join(', ');
  return materials == null ? base : '$base ($materials)';
}

class SpellComponentsEditor extends ConsumerWidget {
  final List<SpellComponent> value;
  final ValueChanged<List<SpellComponent>> onCommit;

  const SpellComponentsEditor({
    required this.value,
    required this.onCommit,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMode = ref.watch(editModeProvider);
    if (!editMode) return Text(formatSpellComponents(value));

    final hasV = value.any((c) => c is VerbalComponent);
    final hasS = value.any((c) => c is SomaticComponent);
    final mat = value.whereType<MaterialComponent>().cast<MaterialComponent?>()
        .firstWhere((_) => true, orElse: () => null);

    void setFlag(bool v, bool s, MaterialComponent? m) {
      final next = <SpellComponent>[
        if (v) const VerbalComponent(),
        if (s) const SomaticComponent(),
        ?m,
      ];
      onCommit(next);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _FlagBox(
          label: 'V',
          value: hasV,
          onChanged: (v) => setFlag(v, hasS, mat),
        ),
        _FlagBox(
          label: 'S',
          value: hasS,
          onChanged: (v) => setFlag(hasV, v, mat),
        ),
        _FlagBox(
          label: 'M',
          value: mat != null,
          onChanged: (v) => setFlag(
            hasV,
            hasS,
            v ? MaterialComponent(description: mat?.description ?? 'a component') : null,
          ),
        ),
        if (mat != null)
          SizedBox(
            width: 220,
            child: _StringInlineField(
              value: mat.description,
              placeholder: 'Material component…',
              onCommit: (s) {
                final t = s.trim();
                if (t.isEmpty) return;
                setFlag(
                  hasV,
                  hasS,
                  MaterialComponent(
                    description: t,
                    costCp: mat.costCp,
                    consumed: mat.consumed,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _FlagBox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FlagBox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            visualDensity: VisualDensity.compact,
            onChanged: (v) => onChanged(v ?? false),
          ),
          Text(label),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

class _EnumPopup<T> extends StatelessWidget {
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onCommit;

  const _EnumPopup({
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onCommit,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return PopupMenuButton<T>(
      initialValue: value,
      tooltip: '',
      onSelected: onCommit,
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem(value: o, child: Text(labelOf(o))),
      ],
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: 6, vertical: palette.padXs),
        decoration: BoxDecoration(
          border: Border.all(color: palette.sidebarDivider),
          borderRadius: BorderRadius.circular(palette.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(labelOf(value)),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }
}

class _IntInlineField extends StatefulWidget {
  final int value;
  final ValueChanged<int> onCommit;

  const _IntInlineField({required this.value, required this.onCommit});

  @override
  State<_IntInlineField> createState() => _IntInlineFieldState();
}

class _IntInlineFieldState extends State<_IntInlineField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toString());
    _focus = FocusNode();
    _focus.addListener(_commitIfLostFocus);
  }

  @override
  void didUpdateWidget(covariant _IntInlineField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) {
      _ctrl.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_commitIfLostFocus);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _commitIfLostFocus() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    final parsed = int.tryParse(_ctrl.text.trim());
    if (parsed == null) {
      _ctrl.text = widget.value.toString();
      return;
    }
    if (parsed != widget.value) widget.onCommit(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: (_) => _commit(),
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      ),
    );
  }
}

class _StringInlineField extends StatefulWidget {
  final String value;
  final String placeholder;
  final ValueChanged<String> onCommit;

  const _StringInlineField({
    required this.value,
    required this.onCommit,
    this.placeholder = '',
  });

  @override
  State<_StringInlineField> createState() => _StringInlineFieldState();
}

class _StringInlineFieldState extends State<_StringInlineField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
    _focus = FocusNode();
    _focus.addListener(_commitIfLostFocus);
  }

  @override
  void didUpdateWidget(covariant _StringInlineField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_commitIfLostFocus);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _commitIfLostFocus() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    if (_ctrl.text != widget.value) widget.onCommit(_ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      onSubmitted: (_) => _commit(),
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.placeholder,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      ),
    );
  }
}
