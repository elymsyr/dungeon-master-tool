// Map v2 Open5e character-build documents — CharacterClass (+ ClassFeature),
// Species (+ SpeciesTrait), Background (+ BackgroundBenefit), Feat (+
// FeatBenefit) — onto the app's `class` / `subclass` / `species` / `background`
// / `feat` package entities.
//
// Child feature/benefit rows are folded into the parent's `description`
// markdown, and every typed schema field Open5e's data can support is filled —
// the `CharacterResolver` consumes most of them (damage resist/immunity,
// condition immunity, granted skills/senses/languages, alt speeds, ASI, subclass
// parent gating, innate spells), so these are not merely reference cards.
//
// References use three placeholders: `lookup()` for Tier-0 values (resolved at
// import), `ref()` for inter-entity refs that ship IN the same package (resolved
// at build — build fails if unresolved), and `softRef()` for cross-pack refs
// (subclass→built-in base class, species→spell, background→feat) that the build
// leaves intact and `CharacterResolver._resolveRef` name-resolves at runtime
// against installed content (a clean no-op if the target pack isn't installed).
//
// Honest source limits (left empty, not faked): leveled class `features`/subclass
// `granted_at_level` (Open5e `ClassFeature` rows have no level field), class
// `primary_ability` (empty in source), feat effect/ASI DSL, and any "of your
// choice" grant — all stay folded in the description.
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/_helpers.dart';

import '../loaders.dart';
import '../normalize.dart';
import '../refgraph.dart';

const _abilityAbbrev = {
  'str': 'Strength',
  'dex': 'Dexterity',
  'con': 'Constitution',
  'int': 'Intelligence',
  'wis': 'Wisdom',
  'cha': 'Charisma',
};

const _casterKind = {
  'FULL': 'Full',
  'HALF': 'Half',
  'PACT': 'Pact',
  'NONE': 'None',
};

/// Runtime-resolving name reference. Unlike `ref()`, it carries no `_ref` key,
/// so `PackBuilder.resolveRefs` leaves it intact (build stays 0-unresolved) and
/// the import `_lookup` pass ignores it; `CharacterResolver._resolveRef` reads
/// `raw['_ref'] ?? raw['slug']` and name-resolves it against all installed
/// content at resolve time (no-op when the referenced pack isn't installed).
/// Used for refs that point outside the package: subclass→built-in base class,
/// species→spell, background→origin feat.
Map<String, String> softRef(String slug, String name) =>
    {'slug': slug, 'name': name};

/// Map classes + subclasses. Base classes (`subclass_of == null`) become
/// `class` entities; the rest become `subclass` entities (descriptive — no
/// class_ref link).
void mapClasses({
  required PackBuilder pack,
  required Normalizer norm,
  required String source,
  required List<Fixture> classes,
  required List<Fixture> features,
}) {
  final featuresByParent = groupBy(features, 'parent');
  // Base-class pk → display name, so a subclass can link `parent_class_ref` to
  // its parent *when that parent ships in the same pack* (SRD docs carry both).
  // Subclasses whose base class lives in the built-in pack (toh/a5e/…) get no
  // ref — it would dangle — and fall back to the descriptive header + tag.
  final baseBySlug = <String, String>{
    for (final c in classes)
      if ((c['subclass_of'] as String?)?.trim().isEmpty ?? true)
        if ((c['name'] as String?)?.trim().isNotEmpty ?? false)
          c['_pk'].toString(): (c['name'] as String).trim(),
  };
  for (final c in classes) {
    final name = (c['name'] as String?)?.trim();
    if (name == null || name.isEmpty) continue;
    final pk = c['_pk'].toString();
    final kids = featuresByParent[pk] ?? const <Fixture>[];
    final subclassOf = (c['subclass_of'] as String?)?.trim();

    if (subclassOf != null && subclassOf.isNotEmpty) {
      // Subclass — descriptive card (+ parent ref when parent is in-pack).
      final parentName = baseBySlug[subclassOf];
      final parent = parentName ?? titleCase(_lastSegment(subclassOf));
      final desc = _fold(
        '*Subclass of $parent.*\n\n${(c['desc'] as String?)?.trim() ?? ''}',
        kids,
      );
      // Parent link: a hard in-pack `ref` when the base class ships here (SRD
      // docs carry both); otherwise a runtime-resolving `softRef` by name so the
      // link survives the build and resolves against the built-in/other-pack
      // base class at character-resolve time.
      final attrs = <String, dynamic>{
        'description': desc,
        'parent_class_ref':
            parentName != null ? ref('class', parentName) : softRef('class', parent),
      };
      _addUnique(pack, slug: 'subclass', name: name, source: source,
          description: desc, tags: [parent], attributes: attrs);
      continue;
    }

    final attrs = <String, dynamic>{};
    final hitDie = _hitDie(c['hit_dice']);
    if (hitDie != null) attrs['hit_die'] = hitDie;
    final saves = (c['saving_throws'] as List?)?.cast<String>() ?? const [];
    final saveRefs = <Map<String, String>>[];
    for (final s in saves) {
      final full = _abilityAbbrev[s.toLowerCase()];
      if (full != null) {
        final ref = norm.lookupRef('ability', full, context: name);
        if (ref != null) saveRefs.add(ref);
      }
    }
    if (saveRefs.isNotEmpty) attrs['saving_throw_refs'] = saveRefs;
    final primaries = (c['primary_abilities'] as List?)?.cast<String>() ?? const [];
    if (primaries.isNotEmpty) {
      final full = _abilityAbbrev[primaries.first.toLowerCase()];
      if (full != null) {
        final ref = norm.lookupRef('ability', full, context: name);
        if (ref != null) attrs['primary_ability_ref'] = ref;
      }
    }
    // Caster kind: trust Open5e's `caster_type` when set; else infer from the
    // class's own spellcasting features (Open5e leaves `caster_type` null for
    // the whole SRD-2014 set — Wizard/Cleric/… included — so a blind None would
    // be wrong). Inference reads feature rows only, no curated class table.
    final caster = _casterKind[(c['caster_type'] as String?)?.toUpperCase()] ??
        _inferCasterKind(kids);
    attrs['caster_kind'] = caster;

    // C7: armor / weapon proficiencies from the structured "Proficiencies"
    // feature (SRD format: `**Armor:** Light armor, medium armor, shields`).
    final profDesc = kids
        .where((k) =>
            (k['name'] as String?)?.trim().toLowerCase() == 'proficiencies')
        .map((k) => (k['desc'] as String?) ?? '')
        .firstWhere((d) => d.isNotEmpty, orElse: () => '');
    if (profDesc.isNotEmpty) {
      final armorLine = _profLine(profDesc, 'Armor');
      if (armorLine != null) {
        final refs = _matchCategories(norm, 'armor-category', armorLine);
        // "All armor" (Fighter/Paladin) → every body-armor category. Merge with
        // any explicit "shields" already matched, de-duping by name.
        if (RegExp(r'all armor', caseSensitive: false).hasMatch(armorLine)) {
          final have = refs.map((r) => r['name']).toSet();
          for (final cat in const ['Light', 'Medium', 'Heavy']) {
            if (!have.contains(cat)) refs.add(lookup('armor-category', cat));
          }
        }
        if (refs.isNotEmpty) attrs['armor_training_refs'] = refs;
      }
      final weaponLine = _profLine(profDesc, 'Weapons?');
      if (weaponLine != null) {
        final refs = _matchCategories(norm, 'weapon-category', weaponLine);
        if (refs.isNotEmpty) attrs['weapon_proficiency_categories'] = refs;
      }
      // D7: skill choice — "**Skills:** Choose two from Animal Handling, …".
      final skillLine = _profLine(profDesc, 'Skills');
      if (skillLine != null) {
        final count = _numberWord(skillLine);
        if (count != null) attrs['skill_proficiency_choice_count'] = count;
        final opts = _refListFromText(norm, 'skill', skillLine);
        if (opts.isNotEmpty) attrs['skill_proficiency_options'] = opts;
      }
    }

    final desc = _fold((c['desc'] as String?)?.trim() ?? '', kids);
    attrs['description'] = desc;
    pack.add(packEntity(
      slug: 'class', name: name, source: source,
      description: desc, attributes: attrs));
  }
}

/// Map species + subspecies. Descriptive (traits folded into description) plus
/// the typed stat fields the schema requires — `size_ref`, `speed_ft`,
/// `creature_type_ref` — parsed from the canonical `Size` / `Speed` trait rows.
/// Subspecies with no own Size/Speed trait inherit their parent's parsed value;
/// creature type defaults to Humanoid (the 5e default for playable species).
void mapSpecies({
  required PackBuilder pack,
  required Normalizer norm,
  required String source,
  required List<Fixture> species,
  required List<Fixture> traits,
}) {
  final traitsByParent = groupBy(traits, 'parent');

  // Pass 1 — parse each species' own size/speed from its trait rows.
  final stats = <String, ({String? size, int? speed})>{};
  for (final s in species) {
    final pk = s['_pk'].toString();
    final kids = traitsByParent[pk] ?? const <Fixture>[];
    String? size;
    int? speed;
    for (final t in kids) {
      final tn = (t['name'] as String?)?.trim().toLowerCase() ?? '';
      final d = (t['desc'] as String?) ?? '';
      if (tn == 'size') size ??= _parseSize(d);
      if (tn == 'speed') speed ??= _parseSpeed(d);
    }
    stats[pk] = (size: size, speed: speed);
  }
  // Pass 2 — subspecies inherit parent's parsed size/speed where absent.
  String? subParent(Fixture s) {
    final v = (s['subspecies_of'] as String?)?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }
  for (final s in species) {
    final p = subParent(s);
    if (p == null) continue;
    final cur = stats[s['_pk'].toString()]!;
    final par = stats[p];
    if (par == null) continue;
    stats[s['_pk'].toString()] =
        (size: cur.size ?? par.size, speed: cur.speed ?? par.speed);
  }

  // Pass 3 — emit.
  for (final s in species) {
    final name = (s['name'] as String?)?.trim();
    if (name == null || name.isEmpty) continue;
    final pk = s['_pk'].toString();
    final kids = traitsByParent[pk] ?? const <Fixture>[];
    final subOf = subParent(s);
    final tags = <String>[];
    var head = (s['desc'] as String?)?.trim() ?? '';
    String? parentSpecies;
    if (subOf != null) {
      parentSpecies = titleCase(_lastSegment(subOf));
      tags.add(parentSpecies);
      head = '*Subspecies of $parentSpecies.*\n\n$head';
    }
    final desc = _fold(head, kids);
    final attrs = <String, dynamic>{'description': desc};
    // Subspecies → first-class `subspecies` entity linked to its parent via a
    // cross-pack softRef (the base species may live in another pack).
    if (parentSpecies != null) {
      attrs['parent_species_ref'] = softRef('species', parentSpecies);
    }
    final ct = norm.lookupRef('creature-type', 'Humanoid', context: name);
    if (ct != null) attrs['creature_type_ref'] = ct;
    final st = stats[pk]!;
    if (st.size != null) {
      final sr = norm.lookupRef('size', st.size!, context: name);
      if (sr != null) attrs['size_ref'] = sr;
    }
    if (st.speed != null) attrs['speed_ft'] = st.speed;

    // Typed grants read from the trait rows. All but innate spells are consumed
    // by CharacterResolver (senses / languages / ASI / damage resist-immune-vuln
    // / condition immunity / skill prof / alt speeds); spells use an in-pack hard
    // ref when the spell ships here, else a runtime-resolving softRef.
    final senses = <Map<String, String>>[];
    final langs = <Map<String, String>>[];
    final modifiers = <Map<String, dynamic>>[];
    final dmgRes = <Map<String, String>>[];
    final dmgImm = <Map<String, String>>[];
    final dmgVuln = <Map<String, String>>[];
    final condImm = <Map<String, String>>[];
    final skillProf = <Map<String, String>>[];
    final spellRefs = <Map<String, String>>[];
    final cantripRefs = <Map<String, String>>[];
    final altSpeeds = <String, int>{};
    for (final t in kids) {
      final tn = (t['name'] as String?)?.trim().toLowerCase() ?? '';
      final d = (t['desc'] as String?) ?? '';
      if (tn == 'darkvision') {
        final s = norm.lookupRef('sense', 'Darkvision', context: name);
        if (s != null) senses.add(s);
      }
      if (tn == 'languages') langs.addAll(_refListFromText(norm, 'language', d));
      if (tn == 'ability score increase') modifiers.addAll(_parseAsi(d));
      // D1 — damage resistance / immunity / vulnerability (lowercase prose; the
      // "X damage" anchor avoids matching damage dealt by an action).
      for (final m in RegExp(r'resistan\w*\s+to\s+([^.;]*?)\s+damage',
          caseSensitive: false).allMatches(d)) {
        dmgRes.addAll(_refListFromText(norm, 'damage-type', m.group(1)!, ci: true));
      }
      for (final m in RegExp(r'immun\w*\s+to\s+([^.;]*?)\s+damage',
          caseSensitive: false).allMatches(d)) {
        dmgImm.addAll(_refListFromText(norm, 'damage-type', m.group(1)!, ci: true));
      }
      for (final m in RegExp(r'vulnerab\w*\s+to\s+([^.;]*?)\s+damage',
          caseSensitive: false).allMatches(d)) {
        dmgVuln.addAll(_refListFromText(norm, 'damage-type', m.group(1)!, ci: true));
      }
      // D2 — condition immunity (explicit immunity phrasing only; "advantage on
      // saves against X" is intentionally NOT a grant).
      for (final m in RegExp(
          r"(?:immun\w*\s+to|can'?t be|cannot be)\s+(?:the\s+|being\s+)?([a-z][a-z ]{0,24})",
          caseSensitive: false).allMatches(d)) {
        condImm.addAll(_refListFromText(norm, 'condition', m.group(1)!, ci: true));
      }
      // D3 — fixed skill proficiency ("gain/have proficiency in the X skill";
      // excludes the conditional "considered proficient in the X skill").
      for (final m in RegExp(r'proficiency\s+in\s+the\s+([A-Za-z ]+?)\s+skill',
          caseSensitive: false).allMatches(d)) {
        skillProf.addAll(_refListFromText(norm, 'skill', m.group(1)!, ci: true));
      }
      // D4 — innate alternate speeds (conditional/temporary grants skipped).
      _parseAltSpeeds(d, altSpeeds);
      // D9 — innate spells / cantrips.
      final sg = _parseSpellGrants(d);
      for (final n in sg.cantrips) {
        cantripRefs.add(pack.has('spell', n) ? ref('spell', n) : softRef('spell', n));
      }
      for (final n in sg.spells) {
        spellRefs.add(pack.has('spell', n) ? ref('spell', n) : softRef('spell', n));
      }
    }
    void put(String key, List<Map<String, String>> v) {
      final dd = _dedupeByName(v);
      if (dd.isNotEmpty) attrs[key] = dd;
    }
    put('granted_senses', senses);
    put('granted_languages', langs);
    if (modifiers.isNotEmpty) attrs['granted_modifiers'] = modifiers;
    put('granted_damage_resistances', dmgRes);
    put('granted_damage_immunities', dmgImm);
    put('granted_damage_vulnerabilities', dmgVuln);
    put('granted_condition_immunities', condImm);
    put('granted_skill_proficiencies', skillProf);
    put('granted_spell_refs', spellRefs);
    put('granted_cantrip_refs', cantripRefs);
    altSpeeds.forEach((k, v) => attrs[k] = v);

    _addUnique(pack, slug: subOf != null ? 'subspecies' : 'species', name: name,
        source: source, description: desc, tags: tags, attributes: attrs);
  }
}

const _sizeWords = ['Tiny', 'Small', 'Medium', 'Large', 'Huge', 'Gargantuan'];

/// Pull a canonical size from a `Size` trait. Prefers the explicit SRD phrasing
/// "Your size is X"; otherwise accepts a lone size keyword (skips when the text
/// names more than one size, e.g. "Small or Medium", to avoid a wrong guess).
String? _parseSize(String desc) {
  final m = RegExp(r'your size is (\w+)', caseSensitive: false).firstMatch(desc);
  if (m != null) {
    final w = titleCase(m.group(1)!);
    if (_sizeWords.contains(w)) return w;
  }
  final found = _sizeWords
      .where((s) => RegExp('\\b$s\\b').hasMatch(desc))
      .toSet();
  return found.length == 1 ? found.first : null;
}

/// First "N feet" / "N ft" measurement in a `Speed` trait → walking speed.
int? _parseSpeed(String desc) {
  final m = RegExp(r'(\d+)\s*(?:feet|ft)\b', caseSensitive: false)
      .firstMatch(desc);
  return m == null ? null : int.parse(m.group(1)!);
}

/// Every canonical name of [slug] that appears as a whole word in [text] →
/// `{_lookup}` placeholder. Used to lift an explicit comma/"and" list ("Insight,
/// Religion") out of benefit prose; "… of your choice" yields nothing (no
/// canonical names present), correctly leaving the choice to the folded text.
List<Map<String, String>> _refListFromText(
    Normalizer norm, String slug, String text, {bool ci = false}) {
  final out = <Map<String, String>>[];
  for (final n in norm.namesFor(slug)) {
    if (RegExp('\\b${RegExp.escape(n)}\\b', caseSensitive: !ci).hasMatch(text)) {
      out.add(lookup(slug, n));
    }
  }
  return out;
}

/// De-dupe a list of `{_lookup|slug, name}` placeholders by `name` (a grant may
/// be named across several trait rows).
List<Map<String, String>> _dedupeByName(List<Map<String, String>> v) {
  final seen = <String>{};
  final out = <Map<String, String>>[];
  for (final m in v) {
    final n = m['name'];
    if (n != null && seen.add(n)) out.add(m);
  }
  return out;
}

/// Caster kind inferred from a class's own feature rows when Open5e leaves
/// `caster_type` null (the entire SRD-2014 set). Source-derived, no class table:
/// Pact Magic → Pact; no spell feature → None; spellcasting + a "Cantrips Known"
/// feature → Full (Wizard/Cleric/…); spellcasting without cantrips → Half
/// (Paladin/Ranger).
String _inferCasterKind(List<Fixture> kids) {
  final names = [for (final k in kids) (k['name'] as String?)?.toLowerCase() ?? ''];
  bool has(String s) => names.any((n) => n.contains(s));
  if (has('pact magic')) return 'Pact';
  if (!has('spellcasting') && !has('spells known')) return 'None';
  return has('cantrips known') ? 'Full' : 'Half';
}

/// First number word (`no`/`one`/`two`/…) appearing whole-word in [text], or
/// null. Used for "Choose two from …" skill picks and language slot counts.
int? _numberWord(String text) {
  for (final e in _numberWords.entries) {
    if (RegExp('\\b${e.key}\\b', caseSensitive: false).hasMatch(text)) {
      return e.value;
    }
  }
  return null;
}

const _allAbilities = [
  'Strength',
  'Dexterity',
  'Constitution',
  'Intelligence',
  'Wisdom',
  'Charisma',
];
const _abilityAlt =
    'Strength|Dexterity|Constitution|Intelligence|Wisdom|Charisma';

/// Structured feat prerequisite gates parsed from the raw `prerequisite` text.
/// Keeps the legacy single-valued flat fields (`prereq_ability_ref`,
/// `prereq_min_score`, `prereq_min_character_level`, `prereq_requires_spellcasting`)
/// for back-compat AND emits a richer `prereq_clauses` list (ALL-of) the
/// resolver dialog validates: `ability_min` (with an `ability_options` LIST so
/// "Strength or Dexterity 13" keeps both), `character_level`, `spellcasting`,
/// `armor_proficiency`, `weapon_proficiency`. Unmodelable prose is left in the
/// raw `prerequisite` text (never blocks).
void _parseFeatPrereq(
    Normalizer norm, String prereq, String context, Map<String, dynamic> attrs) {
  final clauses = <Map<String, dynamic>>[];

  // Ability gate — capture an OR/AND/comma group sharing one minimum score
  // ("Strength or Dexterity 13+") and keep every option, not just the first.
  final abilGroup = RegExp(
    '((?:$_abilityAlt)(?:\\s*(?:,|or|/|and)\\s*(?:$_abilityAlt))*)\\s+(\\d+)',
    caseSensitive: false,
  ).firstMatch(prereq);
  if (abilGroup != null) {
    final names = RegExp(_abilityAlt, caseSensitive: false)
        .allMatches(abilGroup.group(1)!)
        .map((m) => titleCase(m.group(0)!))
        .toList();
    final score = int.parse(abilGroup.group(2)!);
    final options = [for (final n in names) lookup('ability', n)];
    if (options.isNotEmpty) {
      attrs['prereq_ability_ref'] = options.first; // legacy single-valued
      attrs['prereq_min_score'] = score;
      clauses.add({
        'type': 'ability_min',
        'ability_options': options,
        'min_score': score,
      });
    }
  }

  // Character level gate.
  final lm = RegExp(r'(?:character\s+)?level\s+(\d+)', caseSensitive: false)
          .firstMatch(prereq) ??
      RegExp(r'(\d+)(?:st|nd|rd|th)\s+level', caseSensitive: false)
          .firstMatch(prereq);
  if (lm != null) {
    final lvl = int.parse(lm.group(1)!);
    attrs['prereq_min_character_level'] = lvl;
    clauses.add({'type': 'character_level', 'min_level': lvl});
  }

  // Spellcasting gate ("Spellcasting Feature" / "the ability to cast at least
  // one spell").
  if (RegExp(
          r'spellcasting feature|ability to cast (?:at least one|a) spell|cast at least one spell',
          caseSensitive: false)
      .hasMatch(prereq)) {
    attrs['prereq_requires_spellcasting'] = true;
    clauses.add({'type': 'spellcasting'});
  }

  // Armor proficiency gate(s).
  for (final m in RegExp(r'proficiency with (Light|Medium|Heavy)\s+armor',
          caseSensitive: false)
      .allMatches(prereq)) {
    final cat = titleCase(m.group(1)!);
    clauses.add({
      'type': 'armor_proficiency',
      'category_ref': lookup('armor-category', cat),
      'category': cat,
    });
  }

  // Weapon proficiency gate.
  final wm = RegExp(
          r'proficiency with (?:a |at least one )?(martial|simple)\s+weapon',
          caseSensitive: false)
      .firstMatch(prereq);
  if (wm != null) {
    clauses.add({
      'type': 'weapon_proficiency',
      'weapon_class': wm.group(1)!.toLowerCase(),
    });
  }

  if (clauses.isNotEmpty) attrs['prereq_clauses'] = clauses;
}

/// Feat ASI benefit → `asi_amount` / `asi_max_score` / `asi_ability_options`
/// (each a `{_lookup: ability, name}` so the resolver's `opt['name']` read
/// works). Handles both SRD-2024 ("Increase your X or Y score by N, to a
/// maximum of M") and A5e ("Your X or Y score increases by N…") phrasings, plus
/// "increase one ability score of your choice by N" (all six abilities). "Of
/// your choice" within a named subset is rare in feats and folds to narrative.
({int amount, int maxScore, List<Map<String, String>> options})? _parseFeatAsi(
    String desc) {
  final named = RegExp(
    '(?:increase your|your)\\s+'
    '((?:$_abilityAlt)(?:\\s*(?:,|or|/|and)\\s*(?:$_abilityAlt))*)'
    '\\s+scores?\\s+(?:increases?\\s+)?by\\s+(\\d+)'
    '(?:[^.]*?maximum of\\s+(\\d+))?',
    caseSensitive: false,
  ).firstMatch(desc);
  if (named != null) {
    final names = RegExp(_abilityAlt, caseSensitive: false)
        .allMatches(named.group(1)!)
        .map((m) => titleCase(m.group(0)!))
        .toList();
    final options = [for (final n in names) lookup('ability', n)];
    if (options.isNotEmpty) {
      return (
        amount: int.parse(named.group(2)!),
        maxScore: named.group(3) != null ? int.parse(named.group(3)!) : 20,
        options: options,
      );
    }
  }
  final any = RegExp(
    r'increase one ability score (?:of your choice )?by\s+(\d+)'
    r'(?:[^.]*?maximum of\s+(\d+))?',
    caseSensitive: false,
  ).firstMatch(desc);
  if (any != null) {
    return (
      amount: int.parse(any.group(1)!),
      maxScore: any.group(2) != null ? int.parse(any.group(2)!) : 20,
      options: [for (final n in _allAbilities) lookup('ability', n)],
    );
  }
  return null;
}

/// Feat benefit grants → `effects` entries matching the resolver's known kinds
/// (see `CharacterResolver.knownEffectKinds`). Conservative: only emits the
/// high-confidence, unconditional grants — armor proficiency, flat speed bonus,
/// and Tough-style per-level HP. Conditional / PB-scaling / "of your choice"
/// benefits stay in the folded narrative (honest source limits).
List<Map<String, dynamic>> _parseFeatEffects(String desc) {
  final out = <Map<String, dynamic>>[];
  for (final m in RegExp(
          r'(?:training with|proficiency with|gain)\s+(Light|Medium|Heavy)\s+armor',
          caseSensitive: false)
      .allMatches(desc)) {
    out.add(effect('proficiency_grant',
        targetKind: 'armor_category',
        targetRef: lookup('armor-category', titleCase(m.group(1)!))));
  }
  if (RegExp(r'(?:training with|proficiency with|gain)\b[^.]{0,24}\bshields?\b',
          caseSensitive: false)
      .hasMatch(desc)) {
    out.add(effect('proficiency_grant',
        targetKind: 'armor_category',
        targetRef: lookup('armor-category', 'Shield')));
  }
  final sp = RegExp(r'\bspeed increases by\s+(\d+)\s*(?:feet|ft)\b',
          caseSensitive: false)
      .firstMatch(desc);
  if (sp != null) {
    out.add(effect('speed_bonus', value: int.parse(sp.group(1)!)));
  }
  if (RegExp(r'hit point maximum increases by[^.]*twice your[^.]*level',
          caseSensitive: false)
      .hasMatch(desc)) {
    out.add(effect('hp_bonus_per_level', value: 2));
  }
  return out;
}

/// Innate alternate speeds from a trait. Skips conditional/temporary grants
/// (bonus-action flight, level-gated, timed) and only takes an explicit
/// `fly|swim|climb|burrow speed of N feet`. Keeps the largest value per mode.
void _parseAltSpeeds(String desc, Map<String, int> out) {
  if (RegExp(r'bonus action|when you reach|for \d+ minute|until you|temporar',
          caseSensitive: false)
      .hasMatch(desc)) {
    return;
  }
  final re = RegExp(
      r'\b(fly|flying|swim|swimming|climb|climbing|burrow|burrowing)\s+speed\s+of\s+(\d+)\s*(?:feet|ft)\b',
      caseSensitive: false);
  for (final m in re.allMatches(desc)) {
    final kind = m.group(1)!.toLowerCase();
    final key = kind.startsWith('fly')
        ? 'speed_fly_ft'
        : kind.startsWith('swim')
            ? 'speed_swim_ft'
            : kind.startsWith('climb')
                ? 'speed_climb_ft'
                : 'speed_burrow_ft';
    final v = int.parse(m.group(2)!);
    out[key] = (out[key] == null || v > out[key]!) ? v : out[key]!;
  }
}

/// Innate spell/cantrip names named in a trait. Requires the "the" article to
/// avoid the generic "cast a spell" phrasing; names are titlecased for ref
/// matching. ("know the thaumaturgy cantrip" → cantrip Thaumaturgy; "cast the
/// hellish rebuke spell" → spell Hellish Rebuke.)
({List<String> cantrips, List<String> spells}) _parseSpellGrants(String desc) {
  final cantrips = <String>{};
  final spells = <String>{};
  for (final m in RegExp(r"\b(?:know|knows|learn)\s+the\s+([a-z][a-z' -]+?)\s+cantrip\b",
      caseSensitive: false).allMatches(desc)) {
    cantrips.add(titleCase(m.group(1)!));
  }
  for (final m in RegExp(r"\bcast\s+the\s+([a-z][a-z' -]+?)\s+spell\b",
      caseSensitive: false).allMatches(desc)) {
    spells.add(titleCase(m.group(1)!));
  }
  return (cantrips: cantrips.toList(), spells: spells.toList());
}

/// Parse an Open5e background `equipment` benefit row into structured
/// `equipment_choice_groups`. Only the SRD-2024 A/B choice format is handled —
/// `"*Choose A or B:* (A) <items>, N GP; or (B) 50 GP"` — so the wizard renders
/// a pickable card and the commit flow grants the picked items + gold. Legacy
/// fixed-kit prose (no A/B) returns null and stays in the description note.
///
/// Build-safety: only items that resolve to an in-pack entity become a hard
/// `ref` (an unresolved `_ref` would fail `build_packs`). Unresolved item names
/// remain visible in the option `label`; gold is always captured.
List<Map<String, dynamic>>? _parseEquipmentChoiceProse(
    PackBuilder pack, String desc) {
  final text = desc.trim();
  final hasAB = RegExp(r'\(A\)').hasMatch(text) && RegExp(r'\(B\)').hasMatch(text);
  if (!hasAB) return null;
  final options = <Map<String, dynamic>>[];
  final reOpt = RegExp(r'\(([A-Z])\)\s*(.*?)(?=;?\s*or\s+\([A-Z]\)|$)',
      caseSensitive: false, dotAll: true);
  for (final m in reOpt.allMatches(text)) {
    final id = m.group(1)!.toUpperCase();
    final body = m.group(2)!.trim().replaceAll(RegExp(r'[;.\s]+$'), '');
    if (body.isEmpty) continue;
    options.add(_equipOptionFromBody(pack, id, body));
  }
  if (options.length < 2) return null;
  return [
    eqGroup(
      groupId: 'bg-equipment',
      label: 'Starting Equipment',
      options: options,
    ),
  ];
}

/// One `eqOption` from a comma-separated equipment list: trailing `N GP` →
/// `gold_gp`; each item gets a leading quantity + parenthetical note stripped
/// and is emitted as a ref only when it resolves in-pack.
Map<String, dynamic> _equipOptionFromBody(
    PackBuilder pack, String id, String body) {
  int? gold;
  final gm = RegExp(r'(\d+)\s*gp\b', caseSensitive: false).firstMatch(body);
  if (gm != null) gold = int.parse(gm.group(1)!);
  final items = <Map<String, dynamic>>[];
  for (var part in body.split(RegExp(r',|\band\b', caseSensitive: false))) {
    part = part.trim();
    if (part.isEmpty) continue;
    if (RegExp(r'^\d+\s*gp$', caseSensitive: false).hasMatch(part)) continue;
    var qty = 1;
    final qm = RegExp(r'^(\d+)\s+(.*)$').firstMatch(part);
    if (qm != null) {
      qty = int.parse(qm.group(1)!);
      part = qm.group(2)!.trim();
    }
    final name = part.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    if (name.isEmpty) continue;
    final slug = _resolveItemSlug(pack, name);
    if (slug != null) items.add(eqItem(slug, name, qty: qty));
  }
  return eqOption(
    optionId: id,
    label: body.replaceAll(RegExp(r'\s+'), ' ').trim(),
    items: items,
    goldGp: gold,
  );
}

/// First content slug under which [name] exists in the pack, or null. Lets the
/// equipment parser emit a build-safe `ref` only for resolvable item names.
String? _resolveItemSlug(PackBuilder pack, String name) {
  for (final slug in const [
    'weapon',
    'armor',
    'tool',
    'adventuring-gear',
    'magic-item',
  ]) {
    if (pack.has(slug, name)) return slug;
  }
  return null;
}

/// Text of a `**Label:**` line in a class Proficiencies feature, or null.
/// [label] may be a small regex (e.g. `Weapons?`). Returns null for "None".
String? _profLine(String desc, String label) {
  final m = RegExp('\\*\\*$label:\\*\\*\\s*([^\\n]*)', caseSensitive: false)
      .firstMatch(desc);
  final line = m?.group(1)?.trim();
  if (line == null || line.isEmpty || line.toLowerCase() == 'none') return null;
  return line;
}

/// Canonical category names of [slug] present in [text], matched whole-word
/// with an optional trailing plural ("shields" → Shield, "Light armor" → Light).
List<Map<String, String>> _matchCategories(
    Normalizer norm, String slug, String text) {
  final out = <Map<String, String>>[];
  for (final n in norm.namesFor(slug)) {
    if (RegExp('\\b${RegExp.escape(n)}s?\\b', caseSensitive: false)
        .hasMatch(text)) {
      out.add(lookup(slug, n));
    }
  }
  return out;
}

const _numberWords = {
  'no': 0, 'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
};

/// Background language slot count: a leading number word ("Two of your
/// choice" → 2, "No additional languages" → 0), else the count of explicit
/// canonical languages named, else null (unknown).
int? _parseLanguageCount(Normalizer norm, String text) {
  final w = _numberWord(text);
  if (w != null) return w;
  final named = _refListFromText(norm, 'language', text).length;
  return named > 0 ? named : null;
}

const _abilityCode = {
  'strength': 'STR',
  'dexterity': 'DEX',
  'constitution': 'CON',
  'intelligence': 'INT',
  'wisdom': 'WIS',
  'charisma': 'CHA',
};

/// Typed fixed ability-score bonuses from an "Ability Score Increase" trait —
/// `{kind: ability_score_bonus, ability: STR, value: N}` (matches built-in
/// species). The "+N to ability scores each" wording grants all six; explicit
/// "X score increases by N" phrases grant that one. "of your choice" wording is
/// intentionally left to the folded narrative (no fixed typing possible).
List<Map<String, dynamic>> _parseAsi(String desc) {
  if (RegExp(r'ability scores?\s+each\s+increase\s+by\s+(\d+)',
              caseSensitive: false)
          .hasMatch(desc) ||
      RegExp(r'each of your ability scores?\s+increases?\s+by\s+(\d+)',
              caseSensitive: false)
          .hasMatch(desc)) {
    final v = int.parse(RegExp(r'by\s+(\d+)').firstMatch(desc)!.group(1)!);
    return [
      for (final code in _abilityCode.values)
        {'kind': 'ability_score_bonus', 'ability': code, 'value': v},
    ];
  }
  final out = <Map<String, dynamic>>[];
  final re = RegExp(
      r'(Strength|Dexterity|Constitution|Intelligence|Wisdom|Charisma)\s+score\s+increases?\s+by\s+(\d+)',
      caseSensitive: false);
  for (final m in re.allMatches(desc)) {
    out.add({
      'kind': 'ability_score_bonus',
      'ability': _abilityCode[m.group(1)!.toLowerCase()],
      'value': int.parse(m.group(2)!),
    });
  }
  return out;
}

/// Map backgrounds. Descriptive (benefits folded into description) plus the
/// typed grants Open5e carries as benefit rows keyed by `type`: skill
/// proficiencies (`skill_proficiency`) → `granted_skill_refs`, SRD-2024 ability
/// options (`ability_score`) → `ability_score_options` (+ `asi_distribution_options`
/// when three abilities are offered), and language slots (`language`) →
/// `granted_language_count`. Tool proficiencies and the origin feat are *not*
/// emitted — both are content-entity refs that would dangle outside the pack
/// (the SRD feat lives in the built-in pack), so they stay in the folded text.
void mapBackgrounds({
  required PackBuilder pack,
  required Normalizer norm,
  required String source,
  required List<Fixture> backgrounds,
  required List<Fixture> benefits,
}) {
  final byParent = groupBy(benefits, 'parent');
  for (final b in backgrounds) {
    final name = (b['name'] as String?)?.trim();
    if (name == null || name.isEmpty) continue;
    final kids = byParent[b['_pk'].toString()] ?? const <Fixture>[];
    final desc = _fold((b['desc'] as String?)?.trim() ?? '', kids);
    final attrs = <String, dynamic>{'description': desc};

    String? descOfType(String type) {
      for (final k in kids) {
        if ((k['type'] as String?)?.trim().toLowerCase() == type) {
          final d = (k['desc'] as String?)?.trim();
          if (d != null && d.isNotEmpty) return d;
        }
      }
      return null;
    }

    final skillText = descOfType('skill_proficiency');
    if (skillText != null) {
      final skills = _refListFromText(norm, 'skill', skillText);
      if (skills.isNotEmpty) attrs['granted_skill_refs'] = skills;
    }
    final abilText = descOfType('ability_score');
    if (abilText != null) {
      final abilities = _refListFromText(norm, 'ability', abilText);
      if (abilities.isNotEmpty) {
        attrs['ability_score_options'] = abilities;
        // SRD-2024 p.83: three offered abilities → player picks +2/+1 or +1/+1/+1.
        if (abilities.length >= 3) {
          attrs['asi_distribution_options'] = ['+2/+1', '+1/+1/+1'];
        }
      }
    }
    final langText = descOfType('language');
    if (langText != null) {
      final count = _parseLanguageCount(norm, langText);
      if (count != null) attrs['granted_language_count'] = count;
    }
    // D9: origin feat (SRD-2024) — the `feat` benefit row's desc is the feat
    // name. The feat lives in the same package but is mapped after backgrounds,
    // so use a softRef that name-resolves at runtime against the installed feat.
    final featText = descOfType('feat');
    if (featText != null && featText.isNotEmpty) {
      attrs['origin_feat_ref'] = softRef('feat', featText);
    }
    // Starting equipment — SRD-2024 backgrounds ship an A/B choice as prose;
    // parse it into structured groups so the wizard renders a pickable card and
    // the picked items + gold are granted (instead of lost to the prose note).
    final equipText = descOfType('equipment');
    if (equipText != null) {
      final groups = _parseEquipmentChoiceProse(pack, equipText);
      if (groups != null && groups.isNotEmpty) {
        attrs['equipment_choice_groups'] = groups;
      }
    }

    _addUnique(pack, slug: 'background', name: name, source: source,
        description: desc, tags: const [], attributes: attrs);
  }
}

/// Map feats (descriptive; prerequisite + benefits folded into description).
/// The single structured field Open5e carries — `type` (GENERAL / Origin /
/// Fighting Style / Epic Boon) — is mapped to the typed `category_ref`
/// (required `feat-category` lookup); the rest stays descriptive.
void mapFeats({
  required PackBuilder pack,
  required Normalizer norm,
  required String source,
  required List<Fixture> feats,
  required List<Fixture> benefits,
}) {
  final byParent = groupBy(benefits, 'parent');
  for (final f in feats) {
    final name = (f['name'] as String?)?.trim();
    if (name == null || name.isEmpty) continue;
    final prereq = (f['prerequisite'] as String?)?.trim() ?? '';
    final rawDesc = (f['desc'] as String?)?.trim() ?? '';
    var head = rawDesc;
    if (prereq.isNotEmpty) head = '**Prerequisite:** $prereq\n\n$head';
    final kids = byParent[f['_pk'].toString()] ?? const <Fixture>[];
    final desc = _fold(head, kids);
    // Benefit text WITHOUT the prerequisite line — grant parsers must not read
    // a prereq ("proficiency with Light Armor") as a granted proficiency.
    final benefitText = _fold(rawDesc, kids);
    final attrs = <String, dynamic>{'description': desc, 'repeatable': false};
    final type = (f['type'] as String?)?.trim();
    if (type != null && type.isNotEmpty) {
      final ref = norm.lookupRef('feat-category', type, context: name);
      if (ref != null) attrs['category_ref'] = ref;
    }
    // Prerequisite — keep the raw text and parse the structured gates
    // (`prereq_clauses` + legacy flat fields).
    if (prereq.isNotEmpty) {
      attrs['prerequisite'] = prereq;
      _parseFeatPrereq(norm, prereq, name, attrs);
    }
    // Auto-grants — ASI bumps + a conservative set of unconditional effects, so
    // the resolver applies them instead of leaving everything in prose.
    final asi = _parseFeatAsi(benefitText);
    if (asi != null) {
      attrs['asi_amount'] = asi.amount;
      attrs['asi_max_score'] = asi.maxScore;
      attrs['asi_ability_options'] = asi.options;
    }
    final effects = _parseFeatEffects(benefitText);
    if (effects.isNotEmpty) attrs['effects'] = effects;
    _addUnique(pack, slug: 'feat', name: name, source: source,
        description: desc, tags: const [], attributes: attrs);
  }
}

// ── helpers ──

/// Add an entity, disambiguating the name when a same-slug name already exists
/// (3rd-party docs reuse generic subclass/feat names) — otherwise `pack.add`
/// would silently merge the two. Prefers the parent tag as the suffix, then a
/// counter, mirroring the monster mapper's ` (Creature)` convention.
void _addUnique(
  PackBuilder pack, {
  required String slug,
  required String name,
  required String source,
  required String description,
  required List<String> tags,
  required Map<String, dynamic> attributes,
}) {
  var finalName = name;
  if (pack.has(slug, finalName)) {
    finalName = tags.isNotEmpty ? '$name (${tags.first})' : name;
    var i = 2;
    while (pack.has(slug, finalName)) {
      finalName = '$name ($i)';
      i++;
    }
  }
  pack.add(packEntity(
    slug: slug, name: finalName, source: source,
    description: description, tags: tags, attributes: attributes));
}

/// Parent desc + named child rows → markdown with one `### Name` block each.
String _fold(String parentDesc, List<Fixture> children) {
  final buf = StringBuffer(parentDesc.trim());
  for (final c in children) {
    final d = (c['desc'] as String?)?.trim() ?? '';
    if (d.isEmpty) continue;
    final n = (c['name'] as String?)?.trim() ?? '';
    buf.write('\n\n');
    if (n.isNotEmpty) buf.write('### $n\n\n');
    buf.write(d);
  }
  return buf.toString().trim();
}

/// `'D12'` / `'d8'` → `12` / `8`.
int? _hitDie(dynamic raw) {
  if (raw is! String) return null;
  final m = RegExp(r'(\d+)').firstMatch(raw);
  return m == null ? null : int.parse(m.group(1)!);
}

String _lastSegment(String slug) =>
    slug.contains('_') ? slug.substring(slug.lastIndexOf('_') + 1) : slug;
