/// Markdown description-completion engine (master-roadmap §4.1; roadmap PR-3.0).
///
/// Phase 3 of the template migration completes every converted card's
/// **`description`** into standalone, player-facing Markdown: the text is the
/// contract with the player, while the template's rule fields keep the sheet in
/// sync with it (master-roadmap §4 / §4.1, content-convert §6). The
/// `rules_text` side-field from content-convert.md is **rescinded** — generated
/// rule text is appended *into* `description` (roadmap override note).
///
/// This module is the home of that engine. It is **pure Dart** (no
/// `package:flutter` import) so the SAME code runs in all three converter call
/// sites (content-convert §Tooling) AND the offline CLI / harness via
/// `dart run`:
///
///   1. the offline pack CLI (`tool/convert_packs_v3.dart`),
///   2. the on-open shim for user personal packages,
///   3. the world-entity migration during the v3 upgrade prompt.
///
/// It is a sibling of [legacy_content_converter] (the per-field *value*
/// migrator) and [template_validator] — three single-responsibility modules in
/// the `template_migration` library family. (master-roadmap §4.1 names
/// `legacy_content_converter.dart` as the home of the per-kind text templates;
/// they live here instead, in their own module, so value-migration and
/// description-generation stay separately reviewable. The wave converter
/// (`convert_packs_v3.dart`, a later slice) composes both.)
///
/// Two responsibilities, both **deterministic** (pure functions of their
/// inputs, so re-running yields byte-identical output — content-convert
/// §Verification):
///
///   * [renderEffect] / [renderPrereqClause] — one human-readable text template
///     per legacy effect/clause kind. The ~25 parametric kinds (content-convert
///     §6) get bespoke **bold-led paragraphs** ("**Title.** sentence."); the
///     ~40 combat/VTT kinds (advantage, rerolls, crit range, reactions, …) that
///     are intentionally out of mechanical scope (the-template-system §2 closed
///     set / master-roadmap §3) render to a humanized paragraph so **nothing is
///     ever deleted silently** (content-convert §6).
///   * [assembleDescription] — orders the rendered sections in the fixed
///     per-category order of the §4.1 section table (`###` subheads; the card
///     name is the implicit title), dropping empty sections.
///
/// **Formatting rules (master-roadmap §4.1):** max heading depth `###`; **bold**
/// for keyed terms; `-` bullets for enumerations; no Markdown tables (cards
/// render in narrow phone columns); no HTML; dice plain inline (`2d8`).
library;

// ─────────────────────────────────────────────────────────────────────────
// Section ordering (master-roadmap §4.1 canonical section table)
// ─────────────────────────────────────────────────────────────────────────

/// The canonical `###` section order per category slug (master-roadmap §4.1).
/// [assembleDescription] emits the sections a caller supplies in this order and
/// drops the rest; a section a caller supplies that is NOT listed here is
/// appended after the canonical ones (forward-compatible — never dropped).
const Map<String, List<String>> categorySectionOrder = {
  'feat': ['Prerequisites', 'Effects', 'When You Gain This Feat'],
  'class': [
    'Hit Points',
    'Proficiencies',
    'Starting Equipment',
    'Level Progression',
    'Class Features',
  ],
  'subclass': ['Features by Level'],
  'species': ['Traits', 'Choices'],
  'subspecies': ['Traits', 'Choices'],
  'background': ['Ability Scores', 'Feat', 'Proficiencies', 'Equipment'],
  // item family — gear/armor/weapon/magic-item share the §4.1 "item" row.
  'adventuring-gear': _itemSections,
  'tool': _itemSections,
  'pack': _itemSections,
  'ammunition': _itemSections,
  'trinket': _itemSections,
  'mount': _itemSections,
  'vehicle': _itemSections,
  'armor': _itemSections,
  'weapon': _itemSections,
  'magic-item': _itemSections,
  'curse': _itemSections,
  'poison': _itemSections,
  'spell': ['Casting', 'Effect', 'At Higher Levels'],
  'monster': ['Traits', 'Actions'],
  'npc': ['Traits', 'Actions'],
  'animal': ['Traits', 'Actions'],
  'creature-action': ['Traits', 'Actions'],
};

const List<String> _itemSections = [
  'Properties',
  'When Equipped',
  'Attunement',
];

/// The section order for [categorySlug], or an empty list for an unknown
/// category (its sections are still emitted — in caller order — by
/// [assembleDescription], so an unmapped category never loses content).
List<String> sectionOrderFor(String categorySlug) =>
    categorySectionOrder[categorySlug] ?? const <String>[];

// ─────────────────────────────────────────────────────────────────────────
// Assembly
// ─────────────────────────────────────────────────────────────────────────

/// Assembles a card's complete Markdown [description] from its [intro] (the
/// original/old description prose, kept verbatim as the implicit pre-heading
/// paragraph) and a map of `### Heading → rendered body` [sections].
///
/// Sections are emitted in [categorySectionOrder] for [categorySlug]; any
/// supplied section not in that order is appended afterward in insertion order
/// (forward-compatible). Empty/whitespace-only bodies are dropped — so a feat
/// with no prerequisites simply has no `### Prerequisites` heading. Blocks are
/// separated by a blank line (`\n\n`), matching the §4.2 worked example.
///
/// **Deterministic:** a pure function of its inputs (Dart `Map` literals
/// preserve insertion order), so re-running the wave converter on the same card
/// produces byte-identical text (content-convert §Verification idempotency).
String assembleDescription({
  required String categorySlug,
  String intro = '',
  Map<String, String> sections = const {},
}) {
  final order = sectionOrderFor(categorySlug);
  final buf = StringBuffer();

  void writeBlock(String block) {
    if (buf.isNotEmpty) buf.write('\n\n');
    buf.write(block);
  }

  final introTrim = intro.trim();
  if (introTrim.isNotEmpty) writeBlock(introTrim);

  void writeSection(String heading) {
    final body = (sections[heading] ?? '').trim();
    if (body.isEmpty) return;
    writeBlock('### $heading\n$body');
  }

  for (final heading in order) {
    writeSection(heading);
  }
  // Forward-compat: emit any caller-supplied section not in the canonical
  // order (e.g. a custom-template category) after the known ones — never drop.
  for (final heading in sections.keys) {
    if (order.contains(heading)) continue;
    writeSection(heading);
  }

  return buf.toString();
}

/// Renders a list of legacy effect rows into a section body: one [renderEffect]
/// **bold-led paragraph** per row, blank-line separated. Rows that render empty
/// are skipped. Use this for the `### Effects` / `### Traits` / `### Features`
/// section bodies fed to [assembleDescription].
String renderEffectsBody(Iterable<Map<String, dynamic>> effects) => effects
    .map(renderEffect)
    .where((s) => s.isNotEmpty)
    .join('\n\n');

/// Renders a list of legacy prerequisite clauses into a `-` bulleted section
/// body for the `### Prerequisites` section. One [renderPrereqClause] per line.
String renderPrerequisitesBody(Iterable<Map<String, dynamic>> clauses) =>
    clauses
        .map(renderPrereqClause)
        .where((s) => s.isNotEmpty)
        .map((s) => '- $s')
        .join('\n');

// ─────────────────────────────────────────────────────────────────────────
// Per-kind effect text templates (content-convert §6)
// ─────────────────────────────────────────────────────────────────────────

/// Renders one legacy effect/modifier row (`{kind, value, target_kind,
/// target_ref, ability, payload, …}`) to a player-facing **bold-led paragraph**
/// ("**Title.** sentence.").
///
/// An explicit human text on the row wins over the generated template (so
/// authored prose is never overwritten): the row's `text` / `note` /
/// `description` is used verbatim if present and non-empty. Otherwise the ~25
/// parametric kinds (content-convert §6) get a bespoke template; every other
/// recognised kind — the ~40 combat/VTT kinds out of mechanical scope — and any
/// unrecognised kind fall through to [_humanizeUnknown], so **nothing is ever
/// deleted silently**. Returns `''` only for a null/empty row.
String renderEffect(Map<String, dynamic>? effect) {
  if (effect == null || effect.isEmpty) return '';
  // Authored human text wins — never overwrite hand-written prose.
  final authored = _firstNonEmpty([
    effect['text'],
    effect['note'],
    effect['description'],
  ]);
  if (authored != null) {
    return _ensureBoldLead(authored, _defaultEffectTitle(effect));
  }

  final kind = _str(effect['kind']);
  switch (kind) {
    case 'ability_score_bonus':
      final ability = _abilityName(effect['ability'] ?? effect['target_kind']);
      final n = _signed(_num(effect['value'], 1));
      return '**Ability Score Increase.** Your $ability score increases by $n.';
    case 'ac_bonus':
      return '**Armor Class.** Your Armor Class increases by '
          '${_signed(_num(effect['value'], 1))}.';
    case 'speed_bonus':
      return '**Speed.** Your walking speed increases by '
          '${_num(effect['value'], 5)} feet.';
    case 'hp_bonus_flat':
    case 'hp_max_bonus_total':
      return '**Hit Points.** Your hit point maximum increases by '
          '${_num(effect['value'], 1)}.';
    case 'hp_bonus_per_level':
      return '**Hit Points.** Your hit point maximum increases by '
          '${_num(effect['value'], 1)} for each level you have.';
    case 'initiative_bonus':
      return '**Initiative.** You gain a ${_signed(_num(effect['value'], 1))} '
          'bonus to Initiative.';
    case 'temp_hp_grant':
      final amt = _refOrValue(effect);
      return '**Temporary Hit Points.** You gain '
          '${amt.isEmpty ? 'temporary hit points' : '$amt temporary hit points'}.';
    case 'proficiency_grant':
    case 'proficiency_grant_raw':
      return '**Proficiency.** You gain proficiency '
          '${_proficiencyTail(effect)}.';
    case 'expertise_grant':
      return '**Expertise.** You gain expertise '
          '${_proficiencyTail(effect)} — your proficiency '
          'bonus is doubled for any ability check it applies to.';
    case 'language_grant':
      return '**Language.** You can speak, read, and write '
          '${_targetPhrase(effect, fallback: 'an additional language')}.';
    case 'spell_grant':
      return '**Spell.** You learn the '
          '${_targetPhrase(effect, fallback: 'spell')} spell.';
    case 'spell_always_prepared':
      return '**Always Prepared.** The '
          '${_targetPhrase(effect, fallback: 'spell')} spell is always prepared '
          'for you and doesn\'t count against the number of spells you can '
          'prepare.';
    case 'cantrip_grant':
      return '**Cantrip.** You learn the '
          '${_targetPhrase(effect, fallback: 'cantrip')} cantrip.';
    case 'damage_resistance':
    case 'damage_resistance_grant':
      return '**Resistance.** You have resistance to '
          '${_targetPhrase(effect, fallback: 'damage')} damage.';
    case 'damage_immunity':
    case 'damage_immunity_grant':
      return '**Immunity.** You are immune to '
          '${_targetPhrase(effect, fallback: 'damage')} damage.';
    case 'damage_vulnerability':
    case 'damage_vulnerability_grant':
      return '**Vulnerability.** You are vulnerable to '
          '${_targetPhrase(effect, fallback: 'damage')} damage.';
    case 'condition_immunity_grant':
      return '**Condition Immunity.** You are immune to the '
          '${_targetPhrase(effect, fallback: 'condition')} condition.';
    case 'sense_grant':
      return '**Sense.** You gain '
          '${_senseTail(effect, 'a special sense')}.';
    case 'truesight_grant':
      return '**Truesight.** You have truesight '
          '${_rangeTail(effect)}.';
    case 'blindsight_grant':
      return '**Blindsight.** You have blindsight '
          '${_rangeTail(effect)}.';
    case 'unarmored_ac_formula':
      return '**Unarmored Defense.** While you aren\'t wearing armor, your '
          'Armor Class equals ${_formulaText(effect)}.';
    case 'resource_pool_grant':
      return '**Resource.** ${_resourcePoolText(effect)}';
    case 'recovery_grant':
    case 'slot_recovery_short_rest':
      return '**Recovery.** ${_recoveryText(effect, kind)}';
    case 'granted_action_grant':
      return '**Action.** You gain a new action: '
          '${_targetPhrase(effect, fallback: 'a special action')}.';
    case 'granted_bonus_action_grant':
      return '**Bonus Action.** You gain a new bonus action: '
          '${_targetPhrase(effect, fallback: 'a special bonus action')}.';
    case 'granted_reaction_grant':
      return '**Reaction.** You gain a new reaction: '
          '${_targetPhrase(effect, fallback: 'a special reaction')}.';
    case 'extra_attack_count':
    case 'extra_attack_bump':
      final n = _num(effect['value'], 1);
      return '**Extra Attack.** You can attack '
          '${n == 1 ? 'one additional time' : '$n additional times'} whenever '
          'you take the Attack action on your turn.';
    case 'class_level_grant':
      return '**Class Level.** You gain '
          '${_targetPhrase(effect, fallback: 'a class level')}.';
    case 'choice_group':
      return '**Choice.** ${_choiceText(effect)}';
    default:
      return _humanizeUnknown(kind, effect);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Effect-row disposition classifier (content-convert §6 / §8 report counts)
// ─────────────────────────────────────────────────────────────────────────

/// The ~25 **parametric** effect/modifier kinds (content-convert §6) — the
/// closed set that [renderEffect] gives a bespoke bold-led template AND that the
/// wave converter maps into a v3 **data field** (the standing template field
/// rules read them). Kept in lock-step with the bespoke `case` labels in
/// [renderEffect]; it is the single source of truth the offline CLI
/// (`convert_packs_v3.dart`) uses to tally the `mapped` count, and the per-kind
/// field mapping (a later slice) will dispatch over the same set.
const Set<String> parametricEffectKinds = {
  'ability_score_bonus',
  'ac_bonus',
  'speed_bonus',
  'hp_bonus_flat',
  'hp_max_bonus_total',
  'hp_bonus_per_level',
  'initiative_bonus',
  'temp_hp_grant',
  'proficiency_grant',
  'proficiency_grant_raw',
  'expertise_grant',
  'language_grant',
  'spell_grant',
  'spell_always_prepared',
  'cantrip_grant',
  'damage_resistance',
  'damage_resistance_grant',
  'damage_immunity',
  'damage_immunity_grant',
  'damage_vulnerability',
  'damage_vulnerability_grant',
  'condition_immunity_grant',
  'sense_grant',
  'truesight_grant',
  'blindsight_grant',
  'unarmored_ac_formula',
  'resource_pool_grant',
  'recovery_grant',
  'slot_recovery_short_rest',
  'granted_action_grant',
  'granted_bonus_action_grant',
  'granted_reaction_grant',
  'extra_attack_count',
  'extra_attack_bump',
  'class_level_grant',
  'choice_group',
};

/// The §6 disposition of a single legacy effect/modifier row, used for the
/// per-pack `conversion_report.json` counts (content-convert §8):
///
///   * [mapped] — a parametric kind ([parametricEffectKinds]); its mechanics are
///     written into a v3 data field by the wave converter (and it is also
///     described in the card text).
///   * [noted] — an out-of-mechanical-scope combat/VTT kind, or any other
///     recognised/unknown kind that renders to text only: it is preserved as
///     player-facing rules text in the `description` (content-convert §6
///     "nothing is deleted silently"; §Verification "every noted row must be
///     visible as rules text").
///   * [dropped] — a null/empty row that renders to nothing. This should be 0
///     for real content; a non-zero count flags malformed source data.
enum EffectDisposition { mapped, noted, dropped }

/// Classifies one legacy effect/modifier [row] by its §6 disposition (see
/// [EffectDisposition]). A row whose [renderEffect] is empty is [dropped];
/// a row whose `kind` is in [parametricEffectKinds] is [mapped]; everything
/// else that renders is [noted]. Deterministic and side-effect-free.
EffectDisposition classifyEffectRow(Map<String, dynamic>? row) {
  if (row == null || row.isEmpty) return EffectDisposition.dropped;
  if (renderEffect(row).isEmpty) return EffectDisposition.dropped;
  if (parametricEffectKinds.contains(_str(row['kind']))) {
    return EffectDisposition.mapped;
  }
  return EffectDisposition.noted;
}

/// Renders one legacy prerequisite clause (`{kind, value, ability, args, …}`) to
/// a single player-facing line for the `### Prerequisites` bullet list. An
/// authored `text` / `name` wins; otherwise the closed clause vocabulary
/// (mirrored from `character_resolver` predicate kinds + the §4.2 example) gets
/// a bespoke phrase, and an unknown clause is humanized so it is never dropped.
String renderPrereqClause(Map<String, dynamic>? clause) {
  if (clause == null || clause.isEmpty) return '';
  final authored = _firstNonEmpty([clause['text'], clause['name']]);
  if (authored != null) return authored;

  final kind = _str(clause['kind']);
  final args = clause['args'] is Map
      ? Map<String, dynamic>.from(clause['args'] as Map)
      : const <String, dynamic>{};
  switch (kind) {
    case 'min_character_level':
    case 'min_level':
      return 'Character level ${_num(clause['value'] ?? args['level'], 1)}+';
    case 'min_ability_score':
      final ability = _abilityName(clause['ability'] ?? args['ability']);
      return '$ability ${_num(clause['value'] ?? args['value'], 13)}+';
    case 'class_level_at_least':
      final cls = _refName(args['class_ref'] ?? clause['target_ref'],
          fallback: 'a class');
      return '$cls level ${_num(args['level'] ?? clause['value'], 1)}+';
    case 'equipped_armor_kind':
      return _armorPrereq(_str(args['value']?.toString()));
    case 'equipped_shield':
      final want = _str(args['value']?.toString() ?? 'any');
      return want == 'false' ? 'Not wielding a shield' : 'Wielding a shield';
    case 'proficiency':
    case 'proficiency_required':
      return 'Proficiency with '
          '${_targetPhrase(clause, fallback: 'the required item')}';
    case 'spellcasting':
    case 'can_cast_spell':
      return 'The ability to cast at least one spell';
    default:
      final humanized = _humanLabel(kind);
      final v = _refOrValue(clause);
      return v.isEmpty ? humanized : '$humanized: $v';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Kind-specific tail builders
// ─────────────────────────────────────────────────────────────────────────

String _proficiencyTail(Map<String, dynamic> effect) {
  final tk = _str(effect['target_kind']);
  final what = _targetPhrase(effect, fallback: '');
  final scope = switch (tk) {
    'skill' => what.isEmpty ? 'a skill' : 'in the $what skill',
    'tool' => what.isEmpty ? 'with a tool' : 'with $what',
    'saving_throw' => what.isEmpty ? 'in a saving throw' : 'in $what saving throws',
    'ability' => what.isEmpty ? 'in an ability' : 'in $what',
    'armor_category' => what.isEmpty ? 'with armor' : 'with $what armor',
    'weapon_category' => what.isEmpty ? 'with weapons' : 'with $what',
    'language' => what.isEmpty ? 'in a language' : 'in $what',
    _ => what.isEmpty ? '' : 'in $what',
  };
  return scope.isEmpty ? 'in the listed proficiency' : scope;
}

String _senseTail(Map<String, dynamic> effect, String fallback) {
  final name = _firstNonEmpty([effect['sense'], effect['name']]);
  final range = _rangeFeet(effect);
  if (name == null) {
    return range == null ? fallback : '$fallback out to $range feet';
  }
  return range == null ? name : '$name out to $range feet';
}

String _rangeTail(Map<String, dynamic> effect) {
  final range = _rangeFeet(effect);
  return range == null ? 'within your line of sight' : 'out to $range feet';
}

int? _rangeFeet(Map<String, dynamic> effect) {
  final payload = effect['payload'];
  final raw = (payload is Map)
      ? (payload['range_ft'] ?? payload['range'] ?? payload['value_ft'])
      : (effect['range_ft'] ?? effect['range'] ?? effect['value']);
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}

String _formulaText(Map<String, dynamic> effect) {
  final payload = effect['payload'];
  final formula = (payload is Map ? payload['formula'] : null) ??
      effect['formula'] ??
      effect['value'];
  final f = _str(formula?.toString());
  return f.isEmpty ? 'the formula on this feature' : f;
}

String _resourcePoolText(Map<String, dynamic> effect) {
  final payload = effect['payload'] is Map
      ? Map<String, dynamic>.from(effect['payload'] as Map)
      : const <String, dynamic>{};
  final name = _firstNonEmpty([
        effect['name'],
        payload['name'],
        _refName(effect['target_ref'] ?? payload['pool_ref'], fallback: ''),
      ]) ??
      'a pool of points';
  final maxRaw = payload['count'] ?? effect['value'] ?? payload['max'];
  final recovers = _str(
      (payload['recovery'] ?? payload['refill_on'] ?? effect['refill_on'])
          ?.toString());
  final maxText = (maxRaw is num)
      ? ' with ${maxRaw.toInt()} ${maxRaw.toInt() == 1 ? 'use' : 'uses'}'
      : '';
  final recoverText =
      recovers.isEmpty ? '' : ', regained after ${_restPhrase(recovers)}';
  return 'You gain $name$maxText$recoverText.';
}

String _recoveryText(Map<String, dynamic> effect, String kind) {
  final what = _targetPhrase(effect, fallback: 'the listed resource');
  if (kind == 'slot_recovery_short_rest') {
    return 'You recover $what when you finish a Short Rest.';
  }
  final on = _str(
      (effect['on'] ?? effect['rest'] ?? effect['refill_on'])?.toString());
  return on.isEmpty
      ? 'You recover $what when you rest.'
      : 'You recover $what after ${_restPhrase(on)}.';
}

String _choiceText(Map<String, dynamic> effect) {
  final pick = _num(effect['pick'] ?? effect['choice_count'] ?? effect['count'], 1);
  final prompt = _firstNonEmpty([effect['prompt'], effect['name']]);
  final base = 'Choose $pick of the listed options';
  return prompt == null ? '$base.' : '$prompt — choose $pick.';
}

String _armorPrereq(String value) => switch (value) {
      'none' => 'Not wearing armor',
      'light' => 'Wearing light armor',
      'medium' => 'Wearing medium armor',
      'heavy' => 'Wearing heavy armor',
      'not_heavy' => 'Not wearing heavy armor',
      'not_none' => 'Wearing armor',
      _ => value.isEmpty ? 'A specific armor type' : 'Wearing $value armor',
    };

/// Last-resort renderer for the ~40 out-of-mechanical-scope combat/VTT kinds
/// and any unrecognised kind. Produces a **bold-led paragraph** from a
/// humanized title plus any scalar payload — so the mechanic is always visible
/// to the player as text even though no rule field automates it
/// (content-convert §6: "Nothing is deleted silently").
String _humanizeUnknown(String kind, Map<String, dynamic> effect) {
  if (kind.isEmpty) return '';
  final title = _humanLabel(kind);
  final detail = _refOrValue(effect);
  return detail.isEmpty
      ? '**$title.** See the rules for this feature.'
      : '**$title.** $detail.';
}

// ─────────────────────────────────────────────────────────────────────────
// Small shared helpers (pure, no external deps)
// ─────────────────────────────────────────────────────────────────────────

/// The phrase for a row's target: a human `name` on the row, else a resolved
/// `target_ref`/`ref` name, else the [fallback].
String _targetPhrase(Map<String, dynamic> effect, {required String fallback}) {
  final name = _firstNonEmpty([
    effect['name'],
    effect['display_name'],
    _refName(effect['target_ref'] ?? effect['ref'] ?? effect['value'],
        fallback: ''),
  ]);
  return name ?? fallback;
}

/// A best-effort human name for a ref value, which may be a plain id String, a
/// `{lookup: 'cat/Name'}` legacy ref, a `{_ref, name}` typed ref, or a `{ref}`.
String _refName(dynamic ref, {required String fallback}) {
  if (ref == null) return fallback;
  if (ref is String) {
    // A `cat/Name` lookup string → "Name"; a bare uuid → fallback.
    final slash = ref.lastIndexOf('/');
    if (slash >= 0 && slash < ref.length - 1) return ref.substring(slash + 1);
    return _looksLikeId(ref) ? fallback : ref;
  }
  if (ref is Map) {
    final named = _firstNonEmpty([ref['name'], ref['display_name']]);
    if (named != null) return named;
    final lookup = _str(ref['lookup']?.toString());
    if (lookup.isNotEmpty) {
      final slash = lookup.lastIndexOf('/');
      return slash >= 0 ? lookup.substring(slash + 1) : lookup;
    }
  }
  return fallback;
}

/// True for an opaque identifier (uuid-ish / long hex) we should not surface to
/// a player as prose.
bool _looksLikeId(String s) {
  if (s.contains('-') && s.length >= 32) return true; // uuid
  return false;
}

/// A short scalar rendering of a row's `value`/`target_ref` for the unknown /
/// generic templates. Empty when there is nothing presentable.
String _refOrValue(Map<String, dynamic> effect) {
  final v = effect['value'];
  if (v is num) return v.toString();
  if (v is String && v.trim().isNotEmpty && !_looksLikeId(v)) return v.trim();
  final name = _refName(effect['target_ref'] ?? effect['ref'], fallback: '');
  return name;
}

/// "a long rest" / "a short rest" / "a long or short rest" for a rest token.
String _restPhrase(String token) => switch (token) {
      'long_rest' || 'long' => 'a Long Rest',
      'short_rest' || 'short' => 'a Short Rest',
      'short_or_long_rest' || 'any_rest' => 'a Short or Long Rest',
      'level_up' => 'you gain a level',
      'dawn' => 'dawn',
      _ => token.replaceAll('_', ' '),
    };

/// Full ability name for an abbreviation/word/ref.
String _abilityName(dynamic raw) {
  final s = _refName(raw, fallback: _str(raw?.toString())).toLowerCase().trim();
  return switch (s) {
    'str' || 'strength' => 'Strength',
    'dex' || 'dexterity' => 'Dexterity',
    'con' || 'constitution' => 'Constitution',
    'int' || 'intelligence' => 'Intelligence',
    'wis' || 'wisdom' => 'Wisdom',
    'cha' || 'charisma' => 'Charisma',
    '' => 'an ability',
    _ => _humanLabel(s),
  };
}

/// "snake_case_kind" → "Snake Case Kind", trimming a trailing "_grant".
String _humanLabel(String kind) {
  var k = kind;
  if (k.endsWith('_grant')) k = k.substring(0, k.length - '_grant'.length);
  if (k.isEmpty) return 'Feature';
  return k
      .split(RegExp(r'[_\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// A default `**Title.**` for an authored row missing its own lead.
String _defaultEffectTitle(Map<String, dynamic> effect) {
  final name = _firstNonEmpty([effect['name'], effect['display_name']]);
  if (name != null) return name;
  final kind = _str(effect['kind']);
  return kind.isEmpty ? 'Feature' : _humanLabel(kind);
}

/// Ensures authored prose [text] leads with a `**bold**` term; if it already
/// starts with `**`, it is returned verbatim, else prefixed with `**[title].**`.
String _ensureBoldLead(String text, String title) {
  final t = text.trim();
  if (t.startsWith('**') || t.startsWith('###')) return t;
  return '**$title.** $t';
}

/// First trimmed non-empty string in [candidates], or `null`.
String? _firstNonEmpty(List<dynamic> candidates) {
  for (final c in candidates) {
    if (c is String) {
      final t = c.trim();
      if (t.isNotEmpty) return t;
    }
  }
  return null;
}

String _str(dynamic v) => v == null ? '' : v.toString();

int _num(dynamic v, int fallback) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

/// "+N" / "-N" for a signed modifier.
String _signed(int n) => n >= 0 ? '+$n' : '$n';
