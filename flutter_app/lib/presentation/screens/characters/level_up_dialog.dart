import 'dart:math';

import 'package:flutter/material.dart';

import '../../../application/character_creation/caster_progression.dart';
import '../../../application/character_creation/level_up_planner.dart';
import '../../../application/character_creation/pending_choices.dart';
import '../../theme/dm_tool_colors.dart';

/// Outcome of the level-up dialog. The dialog no longer captures interactive
/// picks (ASI / Feat / Fighting Style / spell selection); those are queued
/// onto the character as [pendingChoices] and resolved later via the
/// editor's pending-choices panel. The HP roll mode stays here because it
/// is dice-state at the moment of leveling — deferring it makes no sense.
class LevelUpResult {
  final bool applied;
  final int hpDelta;
  final int newProfBonus;

  /// Decisions the player must make at some point but didn't make in the
  /// dialog. Editor appends these to `pending_choices` on the character.
  final List<PendingChoice> pendingChoices;

  const LevelUpResult({
    required this.applied,
    required this.hpDelta,
    required this.newProfBonus,
    this.pendingChoices = const [],
  });

  static const LevelUpResult skipped = LevelUpResult(
    applied: false,
    hpDelta: 0,
    newProfBonus: 0,
  );
}

/// Stateful modal that confirms a level transition. Auto-applies every
/// non-interactive delta (HP, PB, hit dice, slots, resource pools, feature
/// rows) and *queues* every interactive decision (ASI / Feat / Fighting
/// Style / Spell pick) onto the character — the player resolves them
/// whenever they want from the editor's pending-choices panel.
class LevelUpDialog extends StatefulWidget {
  final LevelUpPlan plan;
  final String? classId;
  final String? classLabel;

  /// Current Constitution score — needed so the auto HP delta folds in the
  /// CON modifier exactly the same way the old picker did.
  final int currentCon;

  /// True when the character already has a subclass attached — suppresses
  /// the subclass pending-choice that would otherwise queue at L3.
  final bool hasSubclass;

  const LevelUpDialog({
    super.key,
    required this.plan,
    this.classId,
    this.classLabel,
    this.currentCon = 10,
    this.hasSubclass = false,
  });

  static Future<LevelUpResult?> show(
    BuildContext context,
    LevelUpPlan plan, {
    String? classId,
    String? classLabel,
    int currentCon = 10,
    bool hasSubclass = false,
  }) {
    return showDialog<LevelUpResult>(
      context: context,
      builder: (_) => LevelUpDialog(
        plan: plan,
        classId: classId,
        classLabel: classLabel,
        currentCon: currentCon,
        hasSubclass: hasSubclass,
      ),
    );
  }

  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

enum _HpMode { average, manual }

class _LevelUpDialogState extends State<LevelUpDialog> {
  final _rng = Random();

  late _HpMode _hpMode;
  late int _hpRollTotal;
  late List<int> _rollFaces;

  late final List<PendingChoice> _pending;

  @override
  void initState() {
    super.initState();
    _hpMode = _HpMode.average;
    _hpRollTotal = widget.plan.hpDelta;
    _rollFaces = const [];
    _pending = pendingChoicesFromPlan(
      plan: widget.plan,
      classId: widget.classId,
      classLabel: widget.classLabel,
      hasSubclass: widget.hasSubclass,
    );
  }

  void _rollHp() {
    final faces = widget.plan.hitDieFaces;
    final n = widget.plan.levelsGained;
    if (faces <= 0 || n <= 0) return;
    final rolls = [for (var i = 0; i < n; i++) 1 + _rng.nextInt(faces)];
    setState(() {
      _rollFaces = rolls;
      _hpRollTotal = rolls.fold<int>(0, (a, b) => a + b);
    });
  }

  int get _conMod => ((widget.currentCon - 10) / 2).floor();
  int get _conBonus => widget.plan.levelsGained * _conMod;

  int get _hpDelta => effectiveHpDelta(
        plan: widget.plan,
        conModifier: _conMod,
        rolledTotal: _hpMode == _HpMode.manual ? _hpRollTotal : null,
      );

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>();
    final hint = palette?.sidebarLabelSecondary ?? Theme.of(context).hintColor;
    final plan = widget.plan;

    return AlertDialog(
      title: Text('Level Up: ${plan.fromLevel} → ${plan.toLevel}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _hpSection(hint),
              const SizedBox(height: 10),
              _stat(
                label: 'Proficiency Bonus',
                value: plan.pbDelta == 0
                    ? '+${plan.newProfBonus} (unchanged)'
                    : '+${plan.prevProfBonus} → +${plan.newProfBonus}',
                hint: hint,
              ),
              if (plan.hitDieFaces > 0 && plan.levelsGained > 0) ...[
                const SizedBox(height: 6),
                _stat(
                  label: 'Hit Dice',
                  value:
                      '${plan.fromLevel}${plan.hitDie} → ${plan.toLevel}${plan.hitDie}',
                  hint: hint,
                ),
              ],
              if (plan.isExtraAttackLevel)
                _notice(
                  icon: Icons.bolt,
                  text: _extraAttackText(plan),
                ),
              if (plan.casterKind != CasterKind.none) _casterBlock(hint),
              _resourcePoolBlock(hint),
              const SizedBox(height: 12),
              const Text(
                'New Features',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              if (plan.newFeatures.isEmpty)
                Text(
                  'No new features at this level.',
                  style: TextStyle(fontSize: 12, color: hint),
                )
              else
                for (final f in plan.newFeatures)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'L${f.level} · ${f.source} · ${f.name}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        if (f.description.isNotEmpty)
                          Text(
                            f.description,
                            style: TextStyle(fontSize: 11, color: hint),
                          ),
                        if (f.grantedSaveProficiencyNames.isNotEmpty)
                          Text(
                            'You gain proficiency in '
                            '${f.grantedSaveProficiencyNames.join(", ")} '
                            'saving throws.',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(LevelUpResult.skipped),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(LevelUpResult(
            applied: true,
            hpDelta: _hpDelta,
            newProfBonus: widget.plan.newProfBonus,
            pendingChoices: _pending,
          )),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  // ───────── HP section (Average vs Manual roll) ─────────────────────────

  String _hpBreakdown(LevelUpPlan plan) {
    final n = plan.levelsGained;
    final dieLabel = plan.hitDie ?? '—';
    final raw = _hpMode == _HpMode.average ? plan.hpDelta : _hpRollTotal;
    final mode = _hpMode == _HpMode.average
        ? (n > 1 ? 'avg $dieLabel × $n' : 'avg $dieLabel')
        : 'rolled';
    final conPart = _conMod == 0
        ? ''
        : (n > 1
            ? ' + ${_conBonus.toString()} CON ($_conMod × $n)'
            : ' + $_conMod CON');
    return '+$_hpDelta  ($raw $mode$conPart)';
  }

  Widget _hpSection(Color hint) {
    final plan = widget.plan;
    final faces = plan.hitDieFaces;
    final canRoll = faces > 0 && plan.levelsGained > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 132,
              child: Text(
                'Hit Points',
                style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Text(
                _hpBreakdown(plan),
                style: TextStyle(fontSize: 12, color: hint),
              ),
            ),
          ],
        ),
        if (canRoll)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 132),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _segmentButton(
                  label: 'Average',
                  selected: _hpMode == _HpMode.average,
                  onTap: () => setState(() => _hpMode = _HpMode.average),
                ),
                _segmentButton(
                  label: 'Roll',
                  selected: _hpMode == _HpMode.manual,
                  onTap: () {
                    setState(() {
                      _hpMode = _HpMode.manual;
                      if (_rollFaces.isEmpty) _rollHp();
                    });
                  },
                ),
                if (_hpMode == _HpMode.manual) ...[
                  TextButton.icon(
                    onPressed: _rollHp,
                    icon: const Icon(Icons.casino, size: 14),
                    label: const Text('Re-roll'),
                  ),
                  if (_rollFaces.isNotEmpty)
                    Text(
                      _rollFaces.join(' + '),
                      style: TextStyle(fontSize: 11, color: hint),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // ───────── shared widgets ──────────────────────────────────────────────

  Widget _segmentButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: const TextStyle(fontSize: 11),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _stat({
    required String label,
    required String value,
    required Color hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: hint),
            ),
          ),
        ],
      ),
    );
  }

  String _extraAttackText(LevelUpPlan plan) {
    const words = {2: 'twice', 3: 'three times', 4: 'four times'};
    final count = plan.newExtraAttackCount;
    final phrase = words[count];
    if (count <= 0) {
      return 'Extra Attack — you can now attack twice per Attack action.';
    }
    if (plan.prevExtraAttackCount == 0) {
      return 'Extra Attack — you can now attack ${phrase ?? '$count times'} '
          'per Attack action.';
    }
    return 'Extra Attack improves — you can now attack '
        '${phrase ?? '$count times'} per Attack action '
        '(was ${plan.prevExtraAttackCount}).';
  }

  Widget _notice({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _casterBlock(Color hint) {
    final plan = widget.plan;
    final lines = <String>[];
    if (plan.cantripsKnownAtNewLevel != null) {
      lines.add('Cantrips known: ${plan.cantripsKnownAtNewLevel}');
    }
    if (plan.preparedSpellsAtNewLevel != null) {
      lines.add('Prepared spells: ${plan.preparedSpellsAtNewLevel}');
    }
    if (plan.maxSpellLevelAtNewLevel != null &&
        plan.maxSpellLevelAtNewLevel! > 0) {
      lines.add('Max spell level: ${plan.maxSpellLevelAtNewLevel}');
    }
    final newSlots = plan.newSpellSlots;
    final prevSlots = plan.prevSpellSlots;
    if (newSlots != null && newSlots.isNotEmpty) {
      final keys = newSlots.keys.toList()..sort();
      final cells = keys.map((k) {
        final prev = prevSlots?[k] ?? 0;
        final now = newSlots[k]!;
        return prev == now ? 'L$k:$now' : 'L$k:$prev→$now';
      }).join('  ');
      lines.add('Slots — $cells');
      final delta = plan.spellSlotsDelta;
      if (delta.isNotEmpty) {
        final gain = (delta.keys.toList()..sort())
            .map((k) => '+${delta[k]} at L$k')
            .join(', ');
        lines.add('New: $gain');
      }
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spellcasting',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          for (final l in lines)
            Text('• $l', style: TextStyle(fontSize: 12, color: hint)),
        ],
      ),
    );
  }

  Widget _resourcePoolBlock(Color hint) {
    final newPools = widget.plan.newResourcePools;
    final prevPools = widget.plan.prevResourcePools;
    if (newPools.isEmpty && prevPools.isEmpty) {
      return const SizedBox.shrink();
    }
    final keys = {...prevPools.keys, ...newPools.keys}.toList()..sort();
    final rows = <String>[];
    for (final k in keys) {
      final prev = prevPools[k] ?? 0;
      final now = newPools[k] ?? 0;
      if (prev == now && prev == 0) continue;
      final label = _prettyPoolName(k);
      rows.add(prev == now ? '$label: $now' : '$label: $prev → $now');
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Class Resources',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          for (final r in rows)
            Text('• $r', style: TextStyle(fontSize: 12, color: hint)),
        ],
      ),
    );
  }

  String _prettyPoolName(String key) {
    var s = key;
    if (s.startsWith('pool:')) s = s.substring(5);
    s = s.replaceAll('_', ' ');
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
