import 'dart:math';

import 'level_up_planner.dart';

/// Categories of interactive level-up decisions that can be deferred.
/// Each kind is rendered inline by [PendingChoicesPanel] with its own
/// resolver dialog. The string values double as the on-disk discriminator
/// stored in the character's `pending_choices` field.
enum PendingChoiceKind {
  asiOrFeat('asi_or_feat'),
  fightingStyle('fighting_style'),
  cantrips('cantrips'),
  spells('spells'),
  subclass('subclass'),
  weaponMastery('weapon_mastery'),
  skillProficiency('skill_proficiency');

  final String wire;
  const PendingChoiceKind(this.wire);

  static PendingChoiceKind? fromWire(String? raw) {
    if (raw == null) return null;
    for (final k in values) {
      if (k.wire == raw) return k;
    }
    return null;
  }
}

/// One deferred level-up decision sitting on the character sheet. The
/// player resolves it whenever they want — the editor's pending panel
/// renders a `!` badge next to the affected field and a Resolve button
/// that opens the picker UI for this single decision.
class PendingChoice {
  final String id;
  final PendingChoiceKind kind;
  final int level;
  final String? classId;
  final String? classLabel;

  /// Spells/cantrips only — how many the player still needs to pick.
  final int count;

  /// Spells only — SRD cap on spell level at the new character level.
  final int maxSpellLevel;

  const PendingChoice({
    required this.id,
    required this.kind,
    required this.level,
    this.classId,
    this.classLabel,
    this.count = 1,
    this.maxSpellLevel = 0,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'kind': kind.wire,
        'level': level,
        if (classId != null) 'class_id': classId,
        if (classLabel != null) 'class_label': classLabel,
        if (count != 1) 'count': count,
        if (maxSpellLevel != 0) 'max_spell_level': maxSpellLevel,
      };

  static PendingChoice? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final kind = PendingChoiceKind.fromWire(raw['kind']?.toString());
    if (kind == null) return null;
    final id = raw['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final level = raw['level'];
    if (level is! int) return null;
    final countRaw = raw['count'];
    final maxSpellRaw = raw['max_spell_level'];
    return PendingChoice(
      id: id,
      kind: kind,
      level: level,
      classId: raw['class_id']?.toString(),
      classLabel: raw['class_label']?.toString(),
      count: countRaw is int ? countRaw : 1,
      maxSpellLevel: maxSpellRaw is int ? maxSpellRaw : 0,
    );
  }
}

/// Decode the character's `pending_choices` field into a typed list.
/// Malformed entries are dropped silently — we'd rather lose one badge
/// than fail the whole editor.
List<PendingChoice> readPendingChoices(Object? raw) {
  if (raw is! List) return const [];
  final out = <PendingChoice>[];
  for (final entry in raw) {
    final p = PendingChoice.fromMap(entry);
    if (p != null) out.add(p);
  }
  return out;
}

List<Map<String, dynamic>> encodePendingChoices(List<PendingChoice> list) =>
    list.map((p) => p.toMap()).toList();

final _rng = Random();

String _newId() {
  final n = _rng.nextInt(1 << 32);
  final t = DateTime.now().microsecondsSinceEpoch;
  return 'pc_${t.toRadixString(36)}_${n.toRadixString(36)}';
}

/// Translate a level-up [plan] into the set of pending decisions the
/// player will need to make later. Callers pass [classId]/[classLabel]
/// so the editor panel can label each badge ("Wizard L4: ASI or Feat").
List<PendingChoice> pendingChoicesFromPlan({
  required LevelUpPlan plan,
  String? classId,
  String? classLabel,
  bool hasSubclass = false,
}) {
  final out = <PendingChoice>[];
  final lvl = plan.toLevel;
  if (plan.isSubclassLevel && !hasSubclass) {
    out.add(PendingChoice(
      id: _newId(),
      kind: PendingChoiceKind.subclass,
      level: lvl,
      classId: classId,
      classLabel: classLabel,
    ));
  }
  if (plan.isAsiOrFeatLevel) {
    out.add(PendingChoice(
      id: _newId(),
      kind: PendingChoiceKind.asiOrFeat,
      level: lvl,
      classId: classId,
      classLabel: classLabel,
    ));
  }
  if (plan.isFightingStyleLevel) {
    out.add(PendingChoice(
      id: _newId(),
      kind: PendingChoiceKind.fightingStyle,
      level: lvl,
      classId: classId,
      classLabel: classLabel,
    ));
  }
  final cantripDelta = plan.cantripsKnownDelta;
  if (cantripDelta > 0) {
    out.add(PendingChoice(
      id: _newId(),
      kind: PendingChoiceKind.cantrips,
      level: lvl,
      classId: classId,
      classLabel: classLabel,
      count: cantripDelta,
    ));
  }
  final spellDelta = plan.preparedSpellsDelta;
  if (spellDelta > 0) {
    out.add(PendingChoice(
      id: _newId(),
      kind: PendingChoiceKind.spells,
      level: lvl,
      classId: classId,
      classLabel: classLabel,
      count: spellDelta,
      maxSpellLevel: plan.maxSpellLevelAtNewLevel ?? 0,
    ));
  }
  final masteryDelta = plan.weaponMasteryCountDelta;
  if (masteryDelta > 0) {
    out.add(PendingChoice(
      id: _newId(),
      kind: PendingChoiceKind.weaponMastery,
      level: lvl,
      classId: classId,
      classLabel: classLabel,
      count: masteryDelta,
    ));
  }
  return out;
}

String pendingChoiceLabel(PendingChoice p) {
  final cls = p.classLabel ?? (p.classId ?? '');
  final prefix = cls.isEmpty ? 'L${p.level}' : '$cls L${p.level}';
  switch (p.kind) {
    case PendingChoiceKind.asiOrFeat:
      return '$prefix · Ability Score Improvement or Feat';
    case PendingChoiceKind.fightingStyle:
      return '$prefix · Fighting Style';
    case PendingChoiceKind.cantrips:
      return '$prefix · Pick ${p.count} cantrip${p.count == 1 ? '' : 's'}';
    case PendingChoiceKind.spells:
      final max = p.maxSpellLevel > 0 ? ' (up to L${p.maxSpellLevel})' : '';
      return '$prefix · Pick ${p.count} spell${p.count == 1 ? '' : 's'}$max';
    case PendingChoiceKind.subclass:
      return '$prefix · Choose a subclass';
    case PendingChoiceKind.weaponMastery:
      return '$prefix · Pick ${p.count} weapon master${p.count == 1 ? 'y' : 'ies'}';
    case PendingChoiceKind.skillProficiency:
      return '$prefix · Pick ${p.count} skill proficienc${p.count == 1 ? 'y' : 'ies'}';
  }
}

/// Schema field keys whose editor tile should display the `!` resolve badge
/// for this pending kind. asiOrFeat lights up both the ability-scores tile
/// (ASI path) and the feats tile (Feat path) so the player can resolve it
/// from whichever list they conceptually associate with the upgrade.
Set<String> pendingChoiceFieldHints(PendingChoiceKind kind) {
  switch (kind) {
    case PendingChoiceKind.asiOrFeat:
      return const {'stat_block', 'feats'};
    case PendingChoiceKind.fightingStyle:
      return const {'feats'};
    case PendingChoiceKind.cantrips:
    case PendingChoiceKind.spells:
      return const {'spells_known'};
    case PendingChoiceKind.subclass:
      return const {'subclass_refs'};
    case PendingChoiceKind.weaponMastery:
      return const {'weapon_masteries'};
    case PendingChoiceKind.skillProficiency:
      return const {'skills'};
  }
}
