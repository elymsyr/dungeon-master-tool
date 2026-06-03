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

  /// Skill entity IDs — populated only when resolving
  /// `PendingChoiceKind.skillProficiency`. Editor flips the matching
  /// `skills.rows[i].proficient` cells to true.
  final List<String> skillIds;

  /// Skill entity IDs — populated only when resolving
  /// `PendingChoiceKind.expertise`. Editor flips the matching
  /// `skills.rows[i].expertise` cells to true.
  final List<String> expertiseSkillIds;

  /// Saving-throw ability abbreviations the editor should flip to proficient
  /// (e.g. `{'CON'}`). Used by `featAsi` resolution when the source feat
  /// declares `grants_save_prof_from_asi: true` (Resilient).
  final Set<String> saveProfAbilityAbbrevs;

  /// Tool entity IDs — populated for `toolProficiency` and for `featChoice`
  /// when the underlying choice routes to tools (`tool_category` /
  /// `skill_or_tool`). Editor appends to `tool_proficiencies`.
  final List<String> toolIds;

  /// Language entity IDs — populated for `languages`. Editor appends to
  /// `language_refs` / `languages`.
  final List<String> languageIds;

  /// `feat_choices[$featChoiceKey] = $featChoiceValue` write. Populated when
  /// resolving a `featChoice` pending so the picks become part of the
  /// character's persisted feat sub-pick state.
  final String? featChoiceKey;
  final String? featChoiceValue;

  /// Marks cantrip-leveled spell picks so the editor flags them prepared+
  /// auto-source when writing into `spells_known` (matches the wizard's
  /// commit-time spell add path).
  final List<String> cantripIds;

  const PendingChoiceResolution({
    this.abilityBumps = const {},
    this.featId,
    this.spellIds = const [],
    this.subclassId,
    this.weaponMasteryIds = const [],
    this.skillIds = const [],
    this.expertiseSkillIds = const [],
    this.saveProfAbilityAbbrevs = const {},
    this.toolIds = const [],
    this.languageIds = const [],
    this.featChoiceKey,
    this.featChoiceValue,
    this.cantripIds = const [],
  });

  bool get isEmpty =>
      abilityBumps.isEmpty &&
      featId == null &&
      spellIds.isEmpty &&
      subclassId == null &&
      weaponMasteryIds.isEmpty &&
      skillIds.isEmpty &&
      expertiseSkillIds.isEmpty &&
      saveProfAbilityAbbrevs.isEmpty &&
      toolIds.isEmpty &&
      languageIds.isEmpty &&
      featChoiceKey == null &&
      cantripIds.isEmpty;
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
  Set<String> existingSkillNames = const {},
  Set<String> expertiseSkillNames = const {},
  Set<String> existingToolIds = const {},
  Set<String> existingLanguageIds = const {},
  Map<String, String> featChoices = const {},
}) {
  return showDialog<PendingChoiceResolution>(
    context: context,
    builder: (_) => _ResolverDialog(
      choice: choice,
      entities: entities,
      abilityScores: abilityScores,
      existingFeatIds: existingFeatIds,
      existingSpellIds: existingSpellIds,
      existingSkillNames: existingSkillNames,
      expertiseSkillNames: expertiseSkillNames,
      existingToolIds: existingToolIds,
      existingLanguageIds: existingLanguageIds,
      featChoices: featChoices,
    ),
  );
}

class _ResolverDialog extends StatefulWidget {
  final PendingChoice choice;
  final Map<String, Entity> entities;
  final Map<String, int> abilityScores;
  final Set<String> existingFeatIds;
  final Set<String> existingSpellIds;
  final Set<String> existingSkillNames;
  final Set<String> expertiseSkillNames;
  final Set<String> existingToolIds;
  final Set<String> existingLanguageIds;
  final Map<String, String> featChoices;

  const _ResolverDialog({
    required this.choice,
    required this.entities,
    required this.abilityScores,
    required this.existingFeatIds,
    required this.existingSpellIds,
    required this.existingSkillNames,
    required this.expertiseSkillNames,
    required this.existingToolIds,
    required this.existingLanguageIds,
    required this.featChoices,
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

  // Divine Order state — mutex pick between Protector and Thaumaturge.
  String? _divineOrderId;

  // Feature-option state — generic single-feat pick for subclass features
  // (Hunter's Prey, Defensive Tactics, etc.). Filter category derived from
  // `widget.choice.featureName` at runtime.
  String? _featureOptionId;

  // Spell picker state (used by cantrip + leveled spell kinds)
  final Set<String> _pickedSpells = <String>{};

  // Subclass state — single id when kind == subclass.
  String? _pickedSubclassId;

  // Weapon mastery state — set of weapon entity ids when kind == weaponMastery.
  final Set<String> _pickedWeaponMasteries = <String>{};

  // Skill proficiency state — set of skill entity ids when kind ==
  // skillProficiency.
  final Set<String> _pickedSkills = <String>{};

  // Expertise state — set of skill entity ids when kind == expertise.
  final Set<String> _pickedExpertise = <String>{};

  // Tool proficiency state — set of tool entity ids when kind ==
  // toolProficiency.
  final Set<String> _pickedTools = <String>{};

  // Language state — set of language entity ids when kind == languages.
  final Set<String> _pickedLanguages = <String>{};

  // Feat-choice state — set of option ids picked for the underlying choice
  // group. Stored once on Apply as `feat_choices[<key>] = <comma-joined>`.
  final Set<String> _pickedFeatChoice = <String>{};
  Map<String, dynamic>? _featChoiceGroup;
  String _featChoiceStorageKey = '';

  List<Entity> _eligibleFeats = const [];
  List<Entity> _fightingStyleFeats = const [];
  List<Entity> _divineOrderFeats = const [];
  List<Entity> _featureOptionFeats = const [];
  List<Entity> _eligibleSpells = const [];
  List<Entity> _eligibleSubclasses = const [];
  List<Entity> _eligibleWeapons = const [];
  List<Entity> _eligibleSkills = const [];
  List<Entity> _eligibleExpertise = const [];
  List<Entity> _eligibleTools = const [];
  List<Entity> _eligibleLanguages = const [];

  @override
  void initState() {
    super.initState();
    switch (widget.choice.kind) {
      case PendingChoiceKind.asiOrFeat:
        _eligibleFeats = _computeEligibleFeats();
      case PendingChoiceKind.fightingStyle:
        _fightingStyleFeats = _computeFightingStyleFeats();
      case PendingChoiceKind.divineOrder:
        _divineOrderFeats = _computeDivineOrderFeats();
      case PendingChoiceKind.featureOption:
        _featureOptionFeats = _computeFeatureOptionFeats();
      case PendingChoiceKind.cantrips:
        _eligibleSpells = _computeEligibleSpells(cantripOnly: true);
      case PendingChoiceKind.spells:
        _eligibleSpells = _computeEligibleSpells(cantripOnly: false);
      case PendingChoiceKind.subclass:
        _eligibleSubclasses = _computeEligibleSubclasses();
      case PendingChoiceKind.weaponMastery:
        _eligibleWeapons = _computeEligibleWeapons();
      case PendingChoiceKind.skillProficiency:
        _eligibleSkills = _computeEligibleSkills();
      case PendingChoiceKind.expertise:
        _eligibleExpertise = _computeEligibleExpertise();
      case PendingChoiceKind.toolProficiency:
        _eligibleTools = _computeEligibleTools();
      case PendingChoiceKind.languages:
        _eligibleLanguages = _computeEligibleLanguages();
      case PendingChoiceKind.featChoice:
        _initFeatChoice();
      case PendingChoiceKind.featAsi:
        _initFeatAsi();
    }
  }

  /// Tools defined on the class entity's `tool_proficiency_options`, minus
  /// the ones the PC already has.
  List<Entity> _computeEligibleTools() {
    final classId = widget.choice.classId;
    if (classId == null || classId.isEmpty) return const [];
    final classEntity = widget.entities[classId];
    if (classEntity == null) return const [];
    final optionsRaw = classEntity.fields['tool_proficiency_options'];
    if (optionsRaw is! List) return const [];
    final out = <Entity>[];
    for (final id in optionsRaw.whereType<String>()) {
      if (widget.existingToolIds.contains(id)) continue;
      final e = widget.entities[id];
      if (e == null) continue;
      out.add(e);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List<Entity>.unmodifiable(out);
  }

  /// All language entities in the campaign minus the ones the PC already
  /// knows.
  List<Entity> _computeEligibleLanguages() {
    if (widget.entities.isEmpty) return const [];
    final out = <Entity>[];
    for (final e in widget.entities.values) {
      if (e.categorySlug != 'language') continue;
      if (widget.existingLanguageIds.contains(e.id)) continue;
      out.add(e);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List<Entity>.unmodifiable(out);
  }

  /// Locate the feat + group_id whose label matches `choice.featureName`.
  /// The wizard stores the group's human-readable `label` so badges read
  /// nicely; the resolver does the reverse lookup to find the machine
  /// `group_id` for the storage key.
  void _initFeatChoice() {
    final featId = widget.choice.sourceEntityId;
    if (featId == null) return;
    final feat = widget.entities[featId];
    if (feat == null) return;
    final effects = feat.fields['effects'];
    if (effects is! List) return;
    final targetLabel = widget.choice.featureName;
    for (final row in effects) {
      if (row is! Map) continue;
      if (row['kind'] != 'choice_group') continue;
      final payload = row['payload'];
      if (payload is! Map) continue;
      final label = payload['label']?.toString() ?? '';
      final groupId = payload['group_id']?.toString() ?? '';
      if (label != targetLabel) continue;
      _featChoiceGroup = Map<String, dynamic>.from(payload);
      _featChoiceStorageKey = '$featId:$groupId';
      // Pre-populate from any partial picks already in feat_choices so the
      // user only needs to add the remaining ones.
      final raw = widget.featChoices[_featChoiceStorageKey] ?? '';
      if (raw.isNotEmpty) {
        _pickedFeatChoice.addAll(
          raw.split(',').where((s) => s.isNotEmpty),
        );
      }
      return;
    }
  }

  // ───────── featAsi (Resilient, Epic Boon, etc.) ─────────

  /// Feat that triggered this ASI follow-on. Read once from `sourceEntityId`.
  Entity? _featAsiSource;
  List<String> _featAsiAbilityOptions = const [];
  int _featAsiAmount = 1;
  int _featAsiMaxScore = 20;
  String? _featAsiPickedAbility;

  void _initFeatAsi() {
    final srcId = widget.choice.sourceEntityId;
    if (srcId == null) return;
    final e = widget.entities[srcId];
    if (e == null) return;
    _featAsiSource = e;
    final opts = e.fields['asi_ability_options'];
    if (opts is List) {
      _featAsiAbilityOptions = [
        for (final o in opts)
          if (_asiOptionToAbbrev(o, widget.entities) case final a? when a.isNotEmpty)
            a,
      ];
    }
    if (_featAsiAbilityOptions.isEmpty) {
      _featAsiAbilityOptions = const ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];
    }
    final amt = e.fields['asi_amount'];
    if (amt is int && amt > 0) _featAsiAmount = amt;
    final max = e.fields['asi_max_score'];
    if (max is int && max > 0) _featAsiMaxScore = max;
  }

  /// Accept either a full ability name ("Strength"), an abbreviation
  /// ("STR"), or an entity ref map / id pointing at an ability entity.
  static String? _asiOptionToAbbrev(Object? o, Map<String, Entity> entities) {
    if (o is String) {
      // Could be abbreviation or entity id.
      final e = entities[o];
      if (e != null) return _abilityNameToAbbrev(e.name);
      return _abilityNameToAbbrev(o);
    }
    if (o is Map) {
      final id = o['id']?.toString();
      if (id != null) {
        final e = entities[id];
        if (e != null) return _abilityNameToAbbrev(e.name);
      }
      final name = o['name']?.toString();
      if (name != null) return _abilityNameToAbbrev(name);
    }
    return null;
  }

  static String? _abilityNameToAbbrev(String raw) {
    final s = raw.toUpperCase();
    const valid = {'STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'};
    if (valid.contains(s)) return s;
    switch (raw.toLowerCase()) {
      case 'strength':
        return 'STR';
      case 'dexterity':
        return 'DEX';
      case 'constitution':
        return 'CON';
      case 'intelligence':
        return 'INT';
      case 'wisdom':
        return 'WIS';
      case 'charisma':
        return 'CHA';
    }
    return null;
  }

  /// Skills the PC is currently proficient in but doesn't yet have expertise
  /// in. Source set passed from the editor.
  List<Entity> _computeEligibleExpertise() {
    if (widget.entities.isEmpty) return const [];
    final out = <Entity>[];
    for (final e in widget.entities.values) {
      if (e.categorySlug != 'skill') continue;
      if (!widget.existingSkillNames.contains(e.name)) continue;
      if (widget.expertiseSkillNames.contains(e.name)) continue;
      out.add(e);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List<Entity>.unmodifiable(out);
  }

  /// All skill entities in the campaign that the PC isn't already proficient
  /// in. Existing-proficiency filter uses skill *names* because the PC stores
  /// proficiency in the `skills` structured field keyed by name, not by id.
  List<Entity> _computeEligibleSkills() {
    if (widget.entities.isEmpty) return const [];
    final out = <Entity>[];
    for (final e in widget.entities.values) {
      if (e.categorySlug != 'skill') continue;
      if (widget.existingSkillNames.contains(e.name)) continue;
      out.add(e);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List<Entity>.unmodifiable(out);
  }

  bool _canBump(String key, int by, {int? cap}) {
    final cur = widget.abilityScores[key] ?? 10;
    return (cur + by) <= (cap ?? _abilityCap);
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

  /// Feats authored under category `Feature Option: <featureName>`. The
  /// feature name comes from the pending choice itself so the same dialog
  /// state handles every subclass-feature picker (Hunter's Prey, Defensive
  /// Tactics, etc.) without a per-feature switch.
  List<Entity> _computeFeatureOptionFeats() {
    if (widget.entities.isEmpty) return const [];
    final featureName = widget.choice.featureName;
    if (featureName == null || featureName.isEmpty) return const [];
    final targetCategory = 'Feature Option: $featureName';
    final out = <Entity>[];
    for (final e in widget.entities.values) {
      if (e.categorySlug != 'feat') continue;
      final catRef = e.fields['category_ref'];
      if (catRef is! String) continue;
      final cat = widget.entities[catRef];
      if (cat?.name != targetCategory) continue;
      if (widget.existingFeatIds.contains(e.id)) continue;
      out.add(e);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List<Entity>.unmodifiable(out);
  }

  List<Entity> _computeDivineOrderFeats() {
    if (widget.entities.isEmpty) return const [];
    final out = <Entity>[];
    for (final e in widget.entities.values) {
      if (e.categorySlug != 'feat') continue;
      final catRef = e.fields['category_ref'];
      if (catRef is! String) continue;
      final cat = widget.entities[catRef];
      if (cat?.name != 'Divine Order') continue;
      if (widget.existingFeatIds.contains(e.id)) continue;
      out.add(e);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List<Entity>.unmodifiable(out);
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
    final className = widget.entities[classId]?.name.toLowerCase();
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
      // SRD spells link by UUID (`class_refs`); imported packs carry the bare
      // class name in `tags`. Accept either so packaged spells appear on level-up.
      final refs = f['class_refs'];
      final byRef = refs is List && refs.contains(classId);
      final byTag = className != null &&
          e.tags.any((t) => t.toLowerCase() == className);
      if (!byRef && !byTag) continue;
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
      case PendingChoiceKind.divineOrder:
        return _divineOrderId != null;
      case PendingChoiceKind.featureOption:
        return _featureOptionId != null;
      case PendingChoiceKind.cantrips:
      case PendingChoiceKind.spells:
        return _pickedSpells.length <= widget.choice.count;
      case PendingChoiceKind.subclass:
        return _pickedSubclassId != null;
      case PendingChoiceKind.weaponMastery:
        return _pickedWeaponMasteries.length <= widget.choice.count;
      case PendingChoiceKind.skillProficiency:
        return _pickedSkills.length <= widget.choice.count;
      case PendingChoiceKind.expertise:
        return _pickedExpertise.length <= widget.choice.count;
      case PendingChoiceKind.toolProficiency:
        return _pickedTools.length <= widget.choice.count;
      case PendingChoiceKind.languages:
        return _pickedLanguages.length <= widget.choice.count;
      case PendingChoiceKind.featChoice:
        if (_featChoiceGroup == null) return false;
        final pick = _featChoiceGroup!['pick'] is int
            ? _featChoiceGroup!['pick'] as int
            : 1;
        return _pickedFeatChoice.length <= pick;
      case PendingChoiceKind.featAsi:
        return _featAsiPickedAbility != null &&
            _canBump(_featAsiPickedAbility!, _featAsiAmount, cap: _featAsiMaxScore);
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
      case PendingChoiceKind.divineOrder:
        return PendingChoiceResolution(featId: _divineOrderId);
      case PendingChoiceKind.featureOption:
        return PendingChoiceResolution(featId: _featureOptionId);
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
        return PendingChoiceResolution(
          skillIds: _pickedSkills.toList(growable: false),
        );
      case PendingChoiceKind.expertise:
        return PendingChoiceResolution(
          expertiseSkillIds: _pickedExpertise.toList(growable: false),
        );
      case PendingChoiceKind.toolProficiency:
        return PendingChoiceResolution(
          toolIds: _pickedTools.toList(growable: false),
        );
      case PendingChoiceKind.languages:
        return PendingChoiceResolution(
          languageIds: _pickedLanguages.toList(growable: false),
        );
      case PendingChoiceKind.featChoice:
        return _buildFeatChoiceResolution();
      case PendingChoiceKind.featAsi:
        final picked = _featAsiPickedAbility;
        if (picked == null) return const PendingChoiceResolution();
        final saveProf =
            _featAsiSource?.fields['grants_save_prof_from_asi'] == true;
        return PendingChoiceResolution(
          abilityBumps: {picked: _featAsiAmount},
          saveProfAbilityAbbrevs: saveProf ? {picked} : const {},
        );
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
      case PendingChoiceKind.divineOrder:
        return _divineOrderBody(hint);
      case PendingChoiceKind.featureOption:
        return _featureOptionBody(hint);
      case PendingChoiceKind.cantrips:
        return _spellPickerBody(hint, cantripOnly: true);
      case PendingChoiceKind.spells:
        return _spellPickerBody(hint, cantripOnly: false);
      case PendingChoiceKind.subclass:
        return _subclassBody(hint);
      case PendingChoiceKind.weaponMastery:
        return _weaponMasteryBody(hint);
      case PendingChoiceKind.skillProficiency:
        return _skillProficiencyBody(hint);
      case PendingChoiceKind.expertise:
        return _expertiseBody(hint);
      case PendingChoiceKind.toolProficiency:
        return _toolProficiencyBody(hint);
      case PendingChoiceKind.languages:
        return _languagesBody(hint);
      case PendingChoiceKind.featChoice:
        return _featChoiceBody(hint);
      case PendingChoiceKind.featAsi:
        return _featAsiBody(hint);
    }
  }

  Widget _toolProficiencyBody(Color hint) {
    if (_eligibleTools.isEmpty) {
      return Text(
        'No class tool options available (or all already proficient).',
        style:
            TextStyle(fontSize: 11, color: hint, fontStyle: FontStyle.italic),
      );
    }
    final cap = widget.choice.count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick up to $cap (selected ${_pickedTools.length}).',
          style: TextStyle(fontSize: 11, color: hint),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in _eligibleTools)
                  _descOption(
                    name: e.name,
                    description: e.description,
                    selected: _pickedTools.contains(e.id),
                    onTap: () {
                      setState(() {
                        if (_pickedTools.contains(e.id)) {
                          _pickedTools.remove(e.id);
                        } else if (_pickedTools.length < cap) {
                          _pickedTools.add(e.id);
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

  Widget _languagesBody(Color hint) {
    if (_eligibleLanguages.isEmpty) {
      return Text(
        'No languages available — PC already knows every language in the campaign.',
        style:
            TextStyle(fontSize: 11, color: hint, fontStyle: FontStyle.italic),
      );
    }
    final cap = widget.choice.count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick up to $cap (selected ${_pickedLanguages.length}).',
          style: TextStyle(fontSize: 11, color: hint),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in _eligibleLanguages)
                  _descOption(
                    name: e.name,
                    description: e.description,
                    selected: _pickedLanguages.contains(e.id),
                    onTap: () {
                      setState(() {
                        if (_pickedLanguages.contains(e.id)) {
                          _pickedLanguages.remove(e.id);
                        } else if (_pickedLanguages.length < cap) {
                          _pickedLanguages.add(e.id);
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

  Widget _featChoiceBody(Color hint) {
    final group = _featChoiceGroup;
    if (group == null) {
      return Text(
        'Source feat / choice group not found.',
        style:
            TextStyle(fontSize: 11, color: hint, fontStyle: FontStyle.italic),
      );
    }
    final pickKind = group['pick_kind']?.toString() ?? 'enum';
    final pick = group['pick'] is int ? group['pick'] as int : 1;
    final prompt = group['prompt']?.toString() ?? '';

    final options = _featChoiceOptions(group, pickKind);
    if (options == null) {
      // `null` means "blocked by an upstream choice" (spell_from_list whose
      // list pick hasn't been made yet).
      return Text(
        'Pick the spell list first (resolve its pending choice).',
        style:
            TextStyle(fontSize: 11, color: hint, fontStyle: FontStyle.italic),
      );
    }
    if (options.isEmpty) {
      return Text(
        'No eligible options in the active campaign.',
        style:
            TextStyle(fontSize: 11, color: hint, fontStyle: FontStyle.italic),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prompt.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(prompt, style: TextStyle(fontSize: 11, color: hint)),
          ),
        Text(
          'Pick up to $pick (selected ${_pickedFeatChoice.length}).',
          style: TextStyle(fontSize: 11, color: hint),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final o in options)
                  _descOption(
                    name: o.label,
                    description: o.description,
                    selected: _pickedFeatChoice.contains(o.id),
                    onTap: () {
                      setState(() {
                        if (_pickedFeatChoice.contains(o.id)) {
                          _pickedFeatChoice.remove(o.id);
                        } else if (pick == 1) {
                          _pickedFeatChoice
                            ..clear()
                            ..add(o.id);
                        } else if (_pickedFeatChoice.length < pick) {
                          _pickedFeatChoice.add(o.id);
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

  /// Build the list of selectable options for the active feat-choice group.
  /// Returns `null` when the group depends on an upstream pick (e.g.
  /// spell_from_list whose list isn't picked yet); returns an empty list
  /// when the campaign just lacks matching entities.
  List<_FeatChoiceOption>? _featChoiceOptions(
    Map<String, dynamic> group,
    String pickKind,
  ) {
    switch (pickKind) {
      case 'enum':
        final raw = group['options'];
        if (raw is! List) return const [];
        final out = <_FeatChoiceOption>[];
        for (final row in raw) {
          if (row is! Map) continue;
          final id = row['id']?.toString() ?? '';
          final label = row['label']?.toString() ?? id;
          if (id.isEmpty) continue;
          out.add(_FeatChoiceOption(id: id, label: label));
        }
        return out;
      case 'tool_category':
        final catName = group['tool_category_name']?.toString() ?? '';
        if (catName.isEmpty) return const [];
        final out = <_FeatChoiceOption>[];
        for (final e in widget.entities.values) {
          if (e.categorySlug != 'tool') continue;
          final catRef = e.fields['category_ref'];
          if (catRef is! String) continue;
          final cat = widget.entities[catRef];
          if (cat?.name != catName) continue;
          out.add(_FeatChoiceOption(
              id: e.id, label: e.name, description: e.description));
        }
        out.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
        return out;
      case 'skill_or_tool':
        final out = <_FeatChoiceOption>[];
        for (final e in widget.entities.values) {
          final slug = e.categorySlug;
          if (slug != 'skill' && slug != 'tool') continue;
          out.add(_FeatChoiceOption(
              id: e.id,
              label: '${slug == 'skill' ? '[Skill] ' : '[Tool] '}${e.name}',
              description: e.description));
        }
        out.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
        return out;
      case 'spell_from_list':
        final featId = widget.choice.sourceEntityId;
        if (featId == null) return const [];
        final listGroupId = group['list_group_id']?.toString() ?? '';
        if (listGroupId.isEmpty) return const [];
        final listKey = '$featId:$listGroupId';
        final listValue = (widget.featChoices[listKey] ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .firstOrNull;
        if (listValue == null || listValue.isEmpty) return null;
        // listValue is the class name (e.g. "Cleric"). Resolve to its
        // entity id, then filter spells by class_refs + level.
        String? classId;
        for (final e in widget.entities.values) {
          if (e.categorySlug == 'class' && e.name == listValue) {
            classId = e.id;
            break;
          }
        }
        if (classId == null) return const [];
        final level = group['spell_level'] is int
            ? group['spell_level'] as int
            : 0;
        final out = <_FeatChoiceOption>[];
        for (final e in widget.entities.values) {
          if (e.categorySlug != 'spell') continue;
          final lvl = e.fields['level'];
          if (lvl is! int || lvl != level) continue;
          // SRD spells link by UUID (`class_refs`); imported packs carry the
          // bare class name in `tags`. Accept either so packaged spells appear
          // in feat spell-list choices (e.g. Magic Initiate).
          final refs = e.fields['class_refs'];
          final byRef = refs is List && refs.contains(classId);
          final byTag =
              e.tags.any((t) => t.toLowerCase() == listValue.toLowerCase());
          if (!byRef && !byTag) continue;
          out.add(_FeatChoiceOption(
              id: e.id, label: e.name, description: e.description));
        }
        out.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
        return out;
      default:
        return const [];
    }
  }

  PendingChoiceResolution _buildFeatChoiceResolution() {
    final group = _featChoiceGroup;
    if (group == null) return const PendingChoiceResolution();
    final ids = _pickedFeatChoice.toList(growable: false);
    final value = ids.join(',');
    final pickKind = group['pick_kind']?.toString() ?? 'enum';

    // Route picks into the right downstream bucket so the editor folds them
    // onto the character (skills.rows, tool_proficiencies, spells_known,
    // ability bumps, etc.) — mirrors deriveFeatChoiceContributions.
    final skillIds = <String>[];
    final toolIds = <String>[];
    final cantripIds = <String>[];
    final spellIds = <String>[];
    switch (pickKind) {
      case 'tool_category':
        for (final id in ids) {
          if (widget.entities[id]?.categorySlug == 'tool') {
            toolIds.add(id);
          }
        }
      case 'skill_or_tool':
        for (final id in ids) {
          final slug = widget.entities[id]?.categorySlug;
          if (slug == 'skill') {
            skillIds.add(id);
          } else if (slug == 'tool') {
            toolIds.add(id);
          }
        }
      case 'spell_from_list':
        final level = group['spell_level'] is int
            ? group['spell_level'] as int
            : 0;
        for (final id in ids) {
          if (widget.entities[id]?.categorySlug != 'spell') continue;
          if (level == 0) {
            cantripIds.add(id);
          } else {
            spellIds.add(id);
          }
        }
      case 'enum':
      default:
        // No downstream side-effect — feat_choices write is enough.
        break;
    }

    return PendingChoiceResolution(
      featChoiceKey: _featChoiceStorageKey,
      featChoiceValue: value,
      skillIds: skillIds,
      toolIds: toolIds,
      cantripIds: cantripIds,
      spellIds: spellIds,
    );
  }

  Widget _featAsiBody(Color hint) {
    if (_featAsiSource == null) {
      return Text(
        'Source feat not found in this campaign.',
        style:
            TextStyle(fontSize: 11, color: hint, fontStyle: FontStyle.italic),
      );
    }
    final keys = _featAsiAbilityOptions;
    final saveProf =
        _featAsiSource!.fields['grants_save_prof_from_asi'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '+$_featAsiAmount to chosen ability (cap $_featAsiMaxScore).'
          '${saveProf ? ' Also grants saving-throw proficiency for the chosen ability.' : ''}',
          style: TextStyle(fontSize: 11, color: hint),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final k in keys)
              _chip(
                label:
                    '${_abilityLabels[k] ?? k} (${widget.abilityScores[k] ?? '—'})',
                selected: _featAsiPickedAbility == k,
                disabled: !_canBump(k, _featAsiAmount, cap: _featAsiMaxScore),
                onTap: () => setState(() => _featAsiPickedAbility = k),
              ),
          ],
        ),
      ],
    );
  }

  Widget _expertiseBody(Color hint) {
    if (_eligibleExpertise.isEmpty) {
      return Text(
        'No eligible skills — PC has no proficient skills without expertise.',
        style:
            TextStyle(fontSize: 11, color: hint, fontStyle: FontStyle.italic),
      );
    }
    final cap = widget.choice.count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick up to $cap (selected ${_pickedExpertise.length}). Eligible skills are ones you\'re already proficient in.',
          style: TextStyle(fontSize: 11, color: hint),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in _eligibleExpertise)
                  _descOption(
                    name: e.name,
                    description: e.description,
                    selected: _pickedExpertise.contains(e.id),
                    onTap: () {
                      setState(() {
                        if (_pickedExpertise.contains(e.id)) {
                          _pickedExpertise.remove(e.id);
                        } else if (_pickedExpertise.length < cap) {
                          _pickedExpertise.add(e.id);
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

  Widget _skillProficiencyBody(Color hint) {
    if (_eligibleSkills.isEmpty) {
      return Text(
        'No skills available — PC already proficient in every skill in the campaign.',
        style:
            TextStyle(fontSize: 11, color: hint, fontStyle: FontStyle.italic),
      );
    }
    final cap = widget.choice.count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick up to $cap (selected ${_pickedSkills.length}).',
          style: TextStyle(fontSize: 11, color: hint),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in _eligibleSkills)
                  _descOption(
                    name: e.name,
                    description: e.description,
                    selected: _pickedSkills.contains(e.id),
                    onTap: () {
                      setState(() {
                        if (_pickedSkills.contains(e.id)) {
                          _pickedSkills.remove(e.id);
                        } else if (_pickedSkills.length < cap) {
                          _pickedSkills.add(e.id);
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

  Widget _divineOrderBody(Color hint) {
    if (_divineOrderFeats.isEmpty) {
      return Text(
        'No Divine Order feats in the active campaign yet.',
        style:
            TextStyle(fontSize: 11, color: hint, fontStyle: FontStyle.italic),
      );
    }
    return _featList(
      _divineOrderFeats,
      hint,
      (id) => _divineOrderId = id,
      () => _divineOrderId,
    );
  }

  Widget _featureOptionBody(Color hint) {
    final name = widget.choice.featureName ?? 'this feature';
    if (_featureOptionFeats.isEmpty) {
      return Text(
        'No options authored for $name in the active campaign yet.',
        style:
            TextStyle(fontSize: 11, color: hint, fontStyle: FontStyle.italic),
      );
    }
    return _featList(
      _featureOptionFeats,
      hint,
      (id) => _featureOptionId = id,
      () => _featureOptionId,
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

class _FeatChoiceOption {
  final String id;
  final String label;
  final String description;
  const _FeatChoiceOption({
    required this.id,
    required this.label,
    this.description = '',
  });
}
