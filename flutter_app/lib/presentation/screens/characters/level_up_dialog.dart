import 'dart:math';

import 'package:flutter/material.dart';

import '../../../application/character_creation/caster_progression.dart';
import '../../../application/character_creation/level_up_planner.dart';
import '../../../domain/entities/entity.dart';
import '../../theme/dm_tool_colors.dart';

/// Outcome of the level-up dialog. Captures every interactive choice the
/// player made so the editor can write them back atomically: HP delta (auto
/// or manually rolled), ASI bumps, feat / fighting-style id additions. The
/// editor still owns the actual mutation — the dialog is a pure picker.
class LevelUpResult {
  final bool applied;
  final int hpDelta;
  final int newProfBonus;
  final Map<String, int> abilityBumps;
  final String? newFeatId;
  final String? newFightingStyleId;

  const LevelUpResult({
    required this.applied,
    required this.hpDelta,
    required this.newProfBonus,
    this.abilityBumps = const {},
    this.newFeatId,
    this.newFightingStyleId,
  });

  static const LevelUpResult skipped = LevelUpResult(
    applied: false,
    hpDelta: 0,
    newProfBonus: 0,
  );
}

/// Stateful modal that surfaces the level transition encoded in [plan] and
/// resolves every interactive sub-choice in one dialog: HP mode (average
/// vs. dice roll), ASI/Feat split at ASI levels, Fighting Style at the
/// class's grant level. Caller is responsible for writing the returned
/// [LevelUpResult] back onto the character.
class LevelUpDialog extends StatefulWidget {
  final LevelUpPlan plan;

  /// Active campaign's entity map — needed for ASI ability scores (read
  /// from the character) and feat catalogs. Pass `null` (or empty) when
  /// running headlessly; the dialog gracefully falls back to text-only
  /// notices.
  final Map<String, Entity> entities;

  /// Current ability scores keyed by 'STR'…'CHA'. The ASI picker enforces
  /// the SRD's max-20 cap against these.
  final Map<String, int> abilityScores;

  /// Feat ids the character already has, so the picker can hide repeats
  /// (unless the feat declares `repeatable: true`).
  final Set<String> existingFeatIds;

  const LevelUpDialog({
    super.key,
    required this.plan,
    this.entities = const {},
    this.abilityScores = const {},
    this.existingFeatIds = const {},
  });

  static Future<LevelUpResult?> show(
    BuildContext context,
    LevelUpPlan plan, {
    Map<String, Entity> entities = const {},
    Map<String, int> abilityScores = const {},
    Set<String> existingFeatIds = const {},
  }) {
    return showDialog<LevelUpResult>(
      context: context,
      builder: (_) => LevelUpDialog(
        plan: plan,
        entities: entities,
        abilityScores: abilityScores,
        existingFeatIds: existingFeatIds,
      ),
    );
  }

  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

enum _HpMode { average, manual }
enum _AsiChoice { asiSingle, asiSplit, feat }

class _LevelUpDialogState extends State<LevelUpDialog> {
  static const _abilityKeys = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];
  static const _abilityLabels = {
    'STR': 'Strength',
    'DEX': 'Dexterity',
    'CON': 'Constitution',
    'INT': 'Intelligence',
    'WIS': 'Wisdom',
    'CHA': 'Charisma',
  };
  static const _abilityCap = 20;
  final _rng = Random();

  late _HpMode _hpMode;
  late int _hpRollTotal;
  late List<int> _rollFaces;

  _AsiChoice _asiChoice = _AsiChoice.asiSingle;
  String? _asiSingleKey;
  String? _asiSplitA;
  String? _asiSplitB;
  String? _featId;
  String? _fightingStyleId;

  @override
  void initState() {
    super.initState();
    _hpMode = _HpMode.average;
    _hpRollTotal = widget.plan.hpDelta;
    _rollFaces = const [];
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

  /// Constitution modifier after folding in any ASI bump the player has
  /// chosen *in this dialog* (so picking +2 CON immediately bumps the HP
  /// shown). Floor division matches the SRD modifier formula for both
  /// positive and negative scores (`((score - 10) / 2).floor()`).
  int get _conMod {
    final base = widget.abilityScores['CON'] ?? 10;
    final bump = _abilityBumps['CON'] ?? 0;
    return ((base + bump - 10) / 2).floor();
  }

  /// CON contribution to the HP delta: one CON mod per level gained.
  int get _conBonus => widget.plan.levelsGained * _conMod;

  int get _hpDelta => effectiveHpDelta(
        plan: widget.plan,
        conModifier: _conMod,
        rolledTotal: _hpMode == _HpMode.manual ? _hpRollTotal : null,
      );

  Map<String, int> get _abilityBumps {
    if (!widget.plan.isAsiOrFeatLevel) return const {};
    if (_asiChoice == _AsiChoice.feat) return const {};
    final out = <String, int>{};
    if (_asiChoice == _AsiChoice.asiSingle) {
      final key = _asiSingleKey;
      if (key != null) out[key] = 2;
    } else {
      final a = _asiSplitA;
      final b = _asiSplitB;
      if (a != null && b != null && a != b) {
        out[a] = 1;
        out[b] = 1;
      }
    }
    return out;
  }

  bool get _isComplete {
    if (widget.plan.isAsiOrFeatLevel) {
      switch (_asiChoice) {
        case _AsiChoice.asiSingle:
          if (_asiSingleKey == null) return false;
          if (!_canBump(_asiSingleKey!, 2)) return false;
        case _AsiChoice.asiSplit:
          final a = _asiSplitA;
          final b = _asiSplitB;
          if (a == null || b == null || a == b) return false;
          if (!_canBump(a, 1) || !_canBump(b, 1)) return false;
        case _AsiChoice.feat:
          if (_featId == null) return false;
      }
    }
    if (widget.plan.isFightingStyleLevel && _fightingStyleFeats().isNotEmpty) {
      if (_fightingStyleId == null) return false;
    }
    return true;
  }

  bool _canBump(String key, int by) {
    final cur = widget.abilityScores[key] ?? 10;
    return (cur + by) <= _abilityCap;
  }

  List<Entity> _eligibleFeats() {
    if (widget.entities.isEmpty) return const [];
    final out = <Entity>[];
    for (final e in widget.entities.values) {
      if (e.categorySlug != 'feat') continue;
      final fields = e.fields;
      if (fields['chooseable'] == false) continue;
      // Class-feature / subclass-feature feats are auto-granted; filter
      // them out — only player-pickable feats belong in this list.
      final auto = fields['auto_granted_by'];
      if (auto is List && auto.isNotEmpty) continue;
      // Skip Fighting Style category — it has its own picker below.
      if (_isFightingStyleFeat(e)) continue;
      final minLvl = fields['prereq_min_character_level'];
      if (minLvl is int && minLvl > widget.plan.toLevel) continue;
      final repeatable = fields['repeatable'] == true;
      if (!repeatable && widget.existingFeatIds.contains(e.id)) continue;
      out.add(e);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  List<Entity> _fightingStyleFeats() {
    if (widget.entities.isEmpty) return const [];
    final out = <Entity>[];
    for (final e in widget.entities.values) {
      if (e.categorySlug != 'feat') continue;
      if (!_isFightingStyleFeat(e)) continue;
      if (widget.existingFeatIds.contains(e.id)) continue;
      out.add(e);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  bool _isFightingStyleFeat(Entity e) {
    final catRef = e.fields['category_ref'];
    if (catRef is! String) return false;
    final cat = widget.entities[catRef];
    return cat?.name == 'Fighting Style';
  }

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
              if (plan.isAsiOrFeatLevel) ...[
                const SizedBox(height: 12),
                _asiSection(hint),
              ],
              if (plan.isFightingStyleLevel) ...[
                const SizedBox(height: 12),
                _fightingStyleSection(hint),
              ],
              if (plan.isExtraAttackLevel)
                _notice(
                  icon: Icons.bolt,
                  text:
                      'Extra Attack — you can now attack twice per Attack action.',
                ),
              if (plan.casterKind != CasterKind.none) _casterBlock(hint),
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
          onPressed: _isComplete
              ? () => Navigator.of(context).pop(LevelUpResult(
                    applied: true,
                    hpDelta: _hpDelta,
                    newProfBonus: widget.plan.newProfBonus,
                    abilityBumps: _abilityBumps,
                    newFeatId: _asiChoice == _AsiChoice.feat ? _featId : null,
                    newFightingStyleId: _fightingStyleId,
                  ))
              : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  // ───────── HP section (Average vs Manual roll) ─────────────────────────

  /// Human-readable HP delta breakdown shown beside the section header,
  /// e.g. `+12  (avg d8 × 2 + 2 CON)`. The roll-mode variant substitutes
  /// the rolled total. CON term is suppressed when the modifier is zero
  /// so the line stays terse for low-CON characters.
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

  // ───────── ASI / Feat section ──────────────────────────────────────────

  Widget _asiSection(Color hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ability Score Improvement or Feat',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            _segmentButton(
              label: '+2 to one',
              selected: _asiChoice == _AsiChoice.asiSingle,
              onTap: () =>
                  setState(() => _asiChoice = _AsiChoice.asiSingle),
            ),
            _segmentButton(
              label: '+1 to two',
              selected: _asiChoice == _AsiChoice.asiSplit,
              onTap: () => setState(() => _asiChoice = _AsiChoice.asiSplit),
            ),
            _segmentButton(
              label: 'Take a feat',
              selected: _asiChoice == _AsiChoice.feat,
              onTap: () => setState(() => _asiChoice = _AsiChoice.feat),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_asiChoice == _AsiChoice.asiSingle)
          _abilityChips(
            selected: _asiSingleKey,
            disabledIf: (k) => !_canBump(k, 2),
            onSelect: (k) => setState(() => _asiSingleKey = k),
            hint: hint,
          )
        else if (_asiChoice == _AsiChoice.asiSplit)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('First ability', style: TextStyle(fontSize: 11, color: hint)),
              _abilityChips(
                selected: _asiSplitA,
                disabledIf: (k) => !_canBump(k, 1) || k == _asiSplitB,
                onSelect: (k) => setState(() => _asiSplitA = k),
                hint: hint,
              ),
              const SizedBox(height: 4),
              Text('Second ability', style: TextStyle(fontSize: 11, color: hint)),
              _abilityChips(
                selected: _asiSplitB,
                disabledIf: (k) => !_canBump(k, 1) || k == _asiSplitA,
                onSelect: (k) => setState(() => _asiSplitB = k),
                hint: hint,
              ),
            ],
          )
        else
          _featPicker(hint),
      ],
    );
  }

  Widget _abilityChips({
    required String? selected,
    required bool Function(String) disabledIf,
    required ValueChanged<String> onSelect,
    required Color hint,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final k in _abilityKeys)
          _chip(
            label:
                '${_abilityLabels[k]} (${widget.abilityScores[k] ?? '—'})',
            selected: selected == k,
            disabled: disabledIf(k),
            onTap: () => onSelect(k),
          ),
      ],
    );
  }

  Widget _featPicker(Color hint) {
    final feats = _eligibleFeats();
    if (feats.isEmpty) {
      return Text(
        'No eligible feats in the active campaign — pick an ASI instead.',
        style:
            TextStyle(fontSize: 11, color: hint, fontStyle: FontStyle.italic),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final e in feats)
              _chip(
                label: e.name,
                selected: _featId == e.id,
                disabled: false,
                onTap: () => setState(() => _featId = e.id),
              ),
          ],
        ),
      ),
    );
  }

  // ───────── Fighting Style section ──────────────────────────────────────

  Widget _fightingStyleSection(Color hint) {
    final styles = _fightingStyleFeats();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fighting Style',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        if (styles.isEmpty)
          Text(
            'No Fighting Style feats in the active campaign yet — pick one '
            'later from the feats catalog.',
            style: TextStyle(
                fontSize: 11, color: hint, fontStyle: FontStyle.italic),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final e in styles)
                _chip(
                  label: e.name,
                  selected: _fightingStyleId == e.id,
                  disabled: false,
                  onTap: () =>
                      setState(() => _fightingStyleId = e.id),
                ),
            ],
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

  Widget _chip({
    required String label,
    required bool selected,
    required bool disabled,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: disabled ? null : (_) => onTap(),
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
}
