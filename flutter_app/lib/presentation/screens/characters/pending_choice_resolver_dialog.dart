import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../application/character_creation/pending_choices.dart';
import '../../../domain/entities/entity.dart';
import '../../theme/dm_tool_colors.dart';

/// Payload the editor mutates onto the character when the player resolves
/// one pending choice. Only the fields relevant to the resolved kind are
/// populated; everything else stays at its default empty value.
class PendingChoiceResolution {
  final Map<String, int> abilityBumps;
  final String? featId;
  final List<String> spellIds;

  /// Subclass entity ID — populated only when resolving
  /// `PendingChoiceKind.subclass`. Editor writes to `subclass_refs`.
  final String? subclassId;

  /// Weapon entity IDs — populated only when resolving
  /// `PendingChoiceKind.weaponMastery`. Editor writes to `weapon_masteries`.
  final List<String> weaponMasteryIds;

  const PendingChoiceResolution({
    this.abilityBumps = const {},
    this.featId,
    this.spellIds = const [],
    this.subclassId,
    this.weaponMasteryIds = const [],
  });

  bool get isEmpty =>
      abilityBumps.isEmpty &&
      featId == null &&
      spellIds.isEmpty &&
      subclassId == null &&
      weaponMasteryIds.isEmpty;
}

/// Open the picker UI for a single deferred level-up decision. Returns
/// `null` when the player closes without committing, or a populated
/// [PendingChoiceResolution] when they tap Apply. Empty payloads are
/// possible — the editor still removes the choice from the pending list
/// (treating it as "I'll skip this one entirely").
Future<PendingChoiceResolution?> showPendingChoiceResolver(
  BuildContext context, {
  required PendingChoice choice,
  required Map<String, Entity> entities,
  required Map<String, int> abilityScores,
  required Set<String> existingFeatIds,
  required Set<String> existingSpellIds,
}) {
  return showDialog<PendingChoiceResolution>(
    context: context,
    builder: (_) => _ResolverDialog(
      choice: choice,
      entities: entities,
      abilityScores: abilityScores,
      existingFeatIds: existingFeatIds,
      existingSpellIds: existingSpellIds,
    ),
  );
}

class _ResolverDialog extends StatefulWidget {
  final PendingChoice choice;
  final Map<String, Entity> entities;
  final Map<String, int> abilityScores;
  final Set<String> existingFeatIds;
  final Set<String> existingSpellIds;

  const _ResolverDialog({
    required this.choice,
    required this.entities,
    required this.abilityScores,
    required this.existingFeatIds,
    required this.existingSpellIds,
  });

  @override
  State<_ResolverDialog> createState() => _ResolverDialogState();
}

enum _AsiChoice { asiSingle, asiSplit, feat }

class _ResolverDialogState extends State<_ResolverDialog> {
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

  // ASI/Feat state
  _AsiChoice _asiChoice = _AsiChoice.asiSingle;
  String? _asiSingleKey;
  String? _asiSplitA;
  String? _asiSplitB;
  String? _featId;

  // Fighting Style state
  String? _fightingStyleId;

  // Spell picker state (used by cantrip + leveled spell kinds)
  final Set<String> _pickedSpells = <String>{};

  // Subclass state — single id when kind == subclass.
  String? _pickedSubclassId;

  // Weapon mastery state — set of weapon entity ids when kind == weaponMastery.
  final Set<String> _pickedWeaponMasteries = <String>{};

  List<Entity> _eligibleFeats = const [];
  List<Entity> _fightingStyleFeats = const [];
  List<Entity> _eligibleSpells = const [];
  List<Entity> _eligibleSubclasses = const [];
  List<Entity> _eligibleWeapons = const [];

  @override
  void initState() {
    super.initState();
    switch (widget.choice.kind) {
      case PendingChoiceKind.asiOrFeat:
        _eligibleFeats = _computeEligibleFeats();
      case PendingChoiceKind.fightingStyle:
        _fightingStyleFeats = _computeFightingStyleFeats();
      case PendingChoiceKind.cantrips:
        _eligibleSpells = _computeEligibleSpells(cantripOnly: true);
      case PendingChoiceKind.spells:
        _eligibleSpells = _computeEligibleSpells(cantripOnly: false);
      case PendingChoiceKind.subclass:
        _eligibleSubclasses = _computeEligibleSubclasses();
      case PendingChoiceKind.weaponMastery:
        _eligibleWeapons = _computeEligibleWeapons();
      case PendingChoiceKind.skillProficiency:
        // Not yet wired — falls through with empty pickers.
        break;
    }
  }

  bool _canBump(String key, int by) {
    final cur = widget.abilityScores[key] ?? 10;
    return (cur + by) <= _abilityCap;
  }

  Map<String, int> get _abilityBumps {
    if (_asiChoice == _AsiChoice.feat) return const {};
    final out = <String, int>{};
    if (_asiChoice == _AsiChoice.asiSingle) {
      final k = _asiSingleKey;
      if (k != null) out[k] = 2;
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

  bool get _asiValid {
    switch (_asiChoice) {
      case _AsiChoice.asiSingle:
        if (_asiSingleKey != null && !_canBump(_asiSingleKey!, 2)) {
          return false;
        }
      case _AsiChoice.asiSplit:
        final a = _asiSplitA;
        final b = _asiSplitB;
        if (a != null && b != null && a == b) return false;
        if (a != null && !_canBump(a, 1)) return false;
        if (b != null && !_canBump(b, 1)) return false;
      case _AsiChoice.feat:
        break;
    }
    return true;
  }

  List<Entity> _computeEligibleFeats() {
    if (widget.entities.isEmpty) return const [];
    final out = <Entity>[];
    for (final e in widget.entities.values) {
      if (e.categorySlug != 'feat') continue;
      final fields = e.fields;
      if (fields['chooseable'] == false) continue;
      final auto = fields['auto_granted_by'];
      if (auto is List && auto.isNotEmpty) continue;
      if (_isFightingStyleFeat(e)) continue;
      final minLvl = fields['prereq_min_character_level'];
      if (minLvl is int && minLvl > widget.choice.level) continue;
      final repeatable = fields['repeatable'] == true;
      if (!repeatable && widget.existingFeatIds.contains(e.id)) continue;
      out.add(e);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List<Entity>.unmodifiable(out);
  }

  List<Entity> _computeFightingStyleFeats() {
    if (widget.entities.isEmpty) return const [];
    final out = <Entity>[];
    for (final e in widget.entities.values) {
      if (e.categorySlug != 'feat') continue;
      if (!_isFightingStyleFeat(e)) continue;
      if (widget.existingFeatIds.contains(e.id)) continue;
      out.add(e);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List<Entity>.unmodifiable(out);
  }

  bool _isFightingStyleFeat(Entity e) {
    final catRef = e.fields['category_ref'];
    if (catRef is! String) return false;
    final cat = widget.entities[catRef];
    return cat?.name == 'Fighting Style';
  }

  /// All subclass entities whose `parent_class_ref` matches the choice's
  /// `classId`. When `classId` is null we fall back to listing every
  /// subclass in the campaign so the player can still pick something
  /// instead of being blocked by missing wiring.
  List<Entity> _computeEligibleSubclasses() {
    if (widget.entities.isEmpty) return const [];
    final classId = widget.choice.classId;
    final out = <Entity>[];
    for (final e in widget.entities.values) {
      if (e.categorySlug != 'subclass') continue;
      if (classId != null && classId.isNotEmpty) {
        final parent = e.fields['parent_class_ref'];
        final parentId =
            parent is String ? parent : (parent is Map ? parent['id']?.toString() : null);
        if (parentId != null && parentId != classId) continue;
      }
      out.add(e);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List<Entity>.unmodifiable(out);
  }

  /// Weapons available for Weapon Mastery selection. SRD 2024 limits the
  /// martial classes to weapons they're proficient in, but until proficiency
  /// resolution is wired here we list every weapon entity in the campaign
  /// that has a mastery property — the player can self-police.
  List<Entity> _computeEligibleWeapons() {
    if (widget.entities.isEmpty) return const [];
    final out = <Entity>[];
    for (final e in widget.entities.values) {
      if (e.categorySlug != 'weapon') continue;
      // Filter to weapons with an authored mastery_ref — otherwise the pick
      // is meaningless.
      final mastery = e.fields['mastery_ref'];
      final hasMastery = mastery is String
          ? mastery.isNotEmpty
          : (mastery is Map ? (mastery['id']?.toString().isNotEmpty ?? false) : false);
      if (!hasMastery) continue;
      out.add(e);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List<Entity>.unmodifiable(out);
  }

  List<Entity> _computeEligibleSpells({required bool cantripOnly}) {
    if (widget.entities.isEmpty) return const [];
    final classId = widget.choice.classId;
    if (classId == null || classId.isEmpty) return const [];
    final maxLvl = widget.choice.maxSpellLevel;
    final out = <Entity>[];
    for (final e in widget.entities.values) {
      if (e.categorySlug != 'spell') continue;
      final f = e.fields;
      final lvlRaw = f['level'];
      final lvl = lvlRaw is int ? lvlRaw : int.tryParse('$lvlRaw');
      if (lvl == null) continue;
      if (cantripOnly && lvl != 0) continue;
      if (!cantripOnly && (lvl < 1 || lvl > maxLvl)) continue;
      final refs = f['class_refs'];
      if (refs is! List) continue;
      if (!refs.contains(classId)) continue;
      if (widget.existingSpellIds.contains(e.id)) continue;
      out.add(e);
    }
    out.sort((a, b) {
      final aLvl = a.fields['level'] is int ? a.fields['level'] as int : 0;
      final bLvl = b.fields['level'] is int ? b.fields['level'] as int : 0;
      final byLevel = aLvl.compareTo(bLvl);
      if (byLevel != 0) return byLevel;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return List<Entity>.unmodifiable(out);
  }

  bool get _isValid {
    switch (widget.choice.kind) {
      case PendingChoiceKind.asiOrFeat:
        return _asiValid;
      case PendingChoiceKind.fightingStyle:
        return true;
      case PendingChoiceKind.cantrips:
      case PendingChoiceKind.spells:
        return _pickedSpells.length <= widget.choice.count;
      case PendingChoiceKind.subclass:
        return _pickedSubclassId != null;
      case PendingChoiceKind.weaponMastery:
        return _pickedWeaponMasteries.length <= widget.choice.count;
      case PendingChoiceKind.skillProficiency:
        return true;
    }
  }

  PendingChoiceResolution _buildResolution() {
    switch (widget.choice.kind) {
      case PendingChoiceKind.asiOrFeat:
        return PendingChoiceResolution(
          abilityBumps: _abilityBumps,
          featId: _asiChoice == _AsiChoice.feat ? _featId : null,
        );
      case PendingChoiceKind.fightingStyle:
        return PendingChoiceResolution(featId: _fightingStyleId);
      case PendingChoiceKind.cantrips:
      case PendingChoiceKind.spells:
        return PendingChoiceResolution(
          spellIds: _pickedSpells.toList(growable: false),
        );
      case PendingChoiceKind.subclass:
        return PendingChoiceResolution(subclassId: _pickedSubclassId);
      case PendingChoiceKind.weaponMastery:
        return PendingChoiceResolution(
          weaponMasteryIds: _pickedWeaponMasteries.toList(growable: false),
        );
      case PendingChoiceKind.skillProficiency:
        return const PendingChoiceResolution();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>();
    final hint = palette?.sidebarLabelSecondary ?? Theme.of(context).hintColor;
    return AlertDialog(
      title: Text(pendingChoiceLabel(widget.choice)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_body(hint)],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(const PendingChoiceResolution()),
          child: const Text('Dismiss'),
        ),
        FilledButton(
          onPressed: _isValid ? () => Navigator.of(context).pop(_buildResolution()) : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _body(Color hint) {
    switch (widget.choice.kind) {
      case PendingChoiceKind.asiOrFeat:
        return _asiBody(hint);
      case PendingChoiceKind.fightingStyle:
        return _fightingStyleBody(hint);
      case PendingChoiceKind.cantrips:
        return _spellPickerBody(hint, cantripOnly: true);
      case PendingChoiceKind.spells:
        return _spellPickerBody(hint, cantripOnly: false);
      case PendingChoiceKind.subclass:
        return _subclassBody(hint);
      case PendingChoiceKind.weaponMastery:
        return _weaponMasteryBody(hint);
      case PendingChoiceKind.skillProficiency:
        return Text(
          'Skill proficiency picker is not yet implemented — Dismiss to clear this badge.',
          style: TextStyle(fontSize: 11, color: hint),
        );
    }
  }

  Widget _subclassBody(Color hint) {
    if (_eligibleSubclasses.isEmpty) {
      return Text(
        'No subclasses for this class in the active campaign.',
        style:
            TextStyle(fontSize: 11, color: hint, fontStyle: FontStyle.italic),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in _eligibleSubclasses)
              _descOption(
                name: e.name,
                description: e.description,
                selected: _pickedSubclassId == e.id,
                onTap: () => setState(() => _pickedSubclassId = e.id),
                hint: hint,
              ),
          ],
        ),
      ),
    );
  }

  Widget _weaponMasteryBody(Color hint) {
    if (_eligibleWeapons.isEmpty) {
      return Text(
        'No weapons with mastery property in the active campaign.',
        style:
            TextStyle(fontSize: 11, color: hint, fontStyle: FontStyle.italic),
      );
    }
    final cap = widget.choice.count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick up to $cap (selected ${_pickedWeaponMasteries.length}).',
          style: TextStyle(fontSize: 11, color: hint),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in _eligibleWeapons)
                  _descOption(
                    name: _weaponMasteryLabel(e),
                    description: e.description,
                    selected: _pickedWeaponMasteries.contains(e.id),
                    onTap: () {
                      setState(() {
                        if (_pickedWeaponMasteries.contains(e.id)) {
                          _pickedWeaponMasteries.remove(e.id);
                        } else if (_pickedWeaponMasteries.length < cap) {
                          _pickedWeaponMasteries.add(e.id);
                        }
                      });
                    },
                    hint: hint,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _weaponMasteryLabel(Entity weapon) {
    final mastery = weapon.fields['mastery_ref'];
    String? masteryId;
    if (mastery is String) masteryId = mastery;
    if (mastery is Map) masteryId = mastery['id']?.toString();
    if (masteryId == null || masteryId.isEmpty) return weapon.name;
    final m = widget.entities[masteryId];
    if (m == null) return weapon.name;
    return '${weapon.name} · ${m.name}';
  }

  // ───────── ASI / Feat body ─────────────────────────────────────────────

  Widget _asiBody(Color hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            _segmentButton(
              label: '+2 to one',
              selected: _asiChoice == _AsiChoice.asiSingle,
              onTap: () => setState(() => _asiChoice = _AsiChoice.asiSingle),
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
        const SizedBox(height: 8),
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
          _featList(_eligibleFeats, hint, (id) => _featId = id, () => _featId),
      ],
    );
  }

  // ───────── Fighting Style body ─────────────────────────────────────────

  Widget _fightingStyleBody(Color hint) {
    if (_fightingStyleFeats.isEmpty) {
      return Text(
        'No Fighting Style feats in the active campaign yet.',
        style:
            TextStyle(fontSize: 11, color: hint, fontStyle: FontStyle.italic),
      );
    }
    return _featList(
      _fightingStyleFeats,
      hint,
      (id) => _fightingStyleId = id,
      () => _fightingStyleId,
    );
  }

  Widget _featList(
    List<Entity> feats,
    Color hint,
    void Function(String id) write,
    String? Function() read,
  ) {
    if (feats.isEmpty) {
      return Text(
        'No eligible feats in the active campaign.',
        style:
            TextStyle(fontSize: 11, color: hint, fontStyle: FontStyle.italic),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in feats)
              _descOption(
                name: e.name,
                description: e.description,
                selected: read() == e.id,
                onTap: () => setState(() => write(e.id)),
                hint: hint,
              ),
          ],
        ),
      ),
    );
  }

  // ───────── Spell picker body ───────────────────────────────────────────

  Widget _spellPickerBody(Color hint, {required bool cantripOnly}) {
    final spells = _eligibleSpells;
    if (spells.isEmpty) {
      return Text(
        cantripOnly
            ? 'No eligible cantrips in this campaign.'
            : 'No eligible spells in this campaign.',
        style: TextStyle(fontSize: 11, color: hint),
      );
    }
    final cap = widget.choice.count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick up to $cap (selected ${_pickedSpells.length}).',
          style: TextStyle(fontSize: 11, color: hint),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in spells)
                  _descOption(
                    name: cantripOnly
                        ? e.name
                        : 'L${e.fields['level']} · ${e.name}',
                    description: e.description,
                    selected: _pickedSpells.contains(e.id),
                    onTap: () {
                      setState(() {
                        if (_pickedSpells.contains(e.id)) {
                          _pickedSpells.remove(e.id);
                        } else if (_pickedSpells.length < cap) {
                          _pickedSpells.add(e.id);
                        }
                      });
                    },
                    hint: hint,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ───────── shared widgets ──────────────────────────────────────────────

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

  Widget _descOption({
    required String name,
    required String description,
    required bool selected,
    required VoidCallback onTap,
    required Color hint,
  }) {
    final palette = Theme.of(context).extension<DmToolColors>();
    final borderColor = selected
        ? (palette?.featureCardAccent ??
            Theme.of(context).colorScheme.primary)
        : (palette?.featureCardBorder ??
            Theme.of(context).colorScheme.outline);
    final radius = palette?.cbr ?? BorderRadius.circular(4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: borderColor,
                width: selected ? 2 : 1,
              ),
              borderRadius: radius,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: selected ? borderColor : hint,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        MarkdownBody(
                          data: description,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(Theme.of(context))
                                  .copyWith(
                            p: TextStyle(fontSize: 11, color: hint),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
