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
// Known gaps, tracked in `docs/open5e_content_audit.md`:
//
//   * ~~Leveled class `features` and `subclass.granted_at_level` are empty.~~
//     **Fixed 2026-07-30 (audit B1)** — `ClassFeatureItem.json` is now loaded and
//     `_levelFeatures` turns it into the `classFeatures` level table plus
//     `granted_at_level`. Its `column_value` rows (the class table proper —
//     spell slots, proficiency bonus) are still unread: that is B2.
//   * ~~Species/background grants are matched by trait *name* here, while Open5e
//     tags every trait and benefit row with a `type` (`MODIFICATION_TYPES`).~~
//     **Reversed 2026-07-31 (audit B3).** `BackgroundBenefit.type` was already
//     the key `mapBackgrounds` matches on, and `SpeciesTrait.type` is **null on
//     100% of the rows we ship** — it is populated only in `srd-2024` (18 rows),
//     a document the publisher-wide SRD skip never builds. Name matching is not
//     a shortcut here, it is the only key the data has. What was really missing
//     was `granted_tool_refs`, now emitted; and `size_ref`'s 63% is an upstream
//     hole, not a matching failure. See audit §4.3-4.4.
//
// Genuine source limits (left empty, not faked): class `primary_ability` (empty
// in the shipped documents), feat effect DSL, and any "of your choice" grant —
// all stay folded in the description.
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/_helpers.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/tools.dart';

import '../gate.dart' show builtinNameIndex, nameKey;
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

// ── Background tool proficiencies (audit B3) ───────────────────────────────
//
// `BackgroundBenefit` rows of type `tool_proficiency` are one short prose line
// ("Disguise kit, forgery kit.", "One type of gaming set, thieves' tools").
// The 40 of them across the shipped documents are what `granted_tool_refs` sat
// at 0% for — not a missing `type` column, which these rows have always had.
//
// The canon is `srdTools()` itself rather than a hand-copied list, so a tool
// renamed in the built-in pack can never silently stop matching here.

/// Punctuation-insensitive match key: upstream writes `Cartographers’ tools`,
/// `Thieves’ tools` and `Navigator's tools` for three cards whose canonical
/// names put the apostrophe elsewhere or use the straight quote.
String _toolKey(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"['’`]"), '')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

/// The three tool families the wizard can offer a pick from
/// (`proficiencies_step._toolCategoryNameForGroup`). `Other Tools` is absent on
/// purpose: it is a catch-all bucket, not a "choose one of these" family.
const _toolGroupForCategory = {
  'Gaming Set': 'gaming_set',
  'Musical Instrument': 'musical_instrument',
  "Artisan's Tools": 'artisans_tools',
};

/// Phrase upstream uses for each family → the group token.
const _toolGroupPhrases = {
  'gaming set': 'gaming_set',
  'musical instrument': 'musical_instrument',
  'artisans tools': 'artisans_tools',
  'artisans supplies': 'artisans_tools',
};

/// Plain misspelling of an SRD card (`Herbalist kit` → `Herbalism Kit`, one row
/// in `tdcs`). Kept as an explicit, auditable list — never fuzzy matching.
const _toolAliases = {'herbalist kit': 'Herbalism Kit'};

/// `_toolKey(canonical name)` → `(canonical name, group token or null)`, built
/// once from the built-in SRD tool cards.
final Map<String, ({String name, String? group})> _toolIndex = () {
  final out = <String, ({String name, String? group})>{};
  for (final t in srdTools()) {
    final name = t['name'] as String;
    final cat = (t['attributes'] as Map)['category_ref'];
    final catName = cat is Map ? cat['name'] as String? : null;
    out[_toolKey(name)] = (name: name, group: _toolGroupForCategory[catName]);
  }
  for (final e in _toolAliases.entries) {
    final canon = out[_toolKey(e.value)];
    if (canon != null) out[e.key] = canon;
  }
  return out;
}();

/// Parse a `tool_proficiency` benefit line into the two typed fields the
/// background schema offers: outright grants (`granted_tool_refs`) and a single
/// "pick one of this family" slot (`granted_tool_variant_group`).
///
/// The rules are deliberately conservative, because both ways of being wrong
/// are silent: emitting an alternative as a grant hands the player a
/// proficiency they never chose, and emitting one family out of two quietly
/// deletes the other choice.
///
///   * **`or` makes every named tool an alternative, not a grant.** "Your
///     choice of one from Thieves' Tools, Forgery Kit, or Disguise Kit" names
///     three real cards and grants none of them. With an `or` present, only a
///     family survives — and only when the line names exactly one family and
///     every tool it names belongs to it ("one type of artisan's tools or
///     smith's tools" → `artisans_tools`, which already offers Smith's Tools).
///   * **Two families is not representable.** `granted_tool_variant_group` is a
///     single text field, so "one type of gaming set, one musical instrument"
///     (one row, `toh`) emits neither and stays in the folded prose. That is a
///     schema limit, recorded rather than papered over by picking the first.
///   * **A family absorbs its own members.** "Gaming set, thieves' tools" emits
///     the `gaming_set` group plus a ref to Thieves' Tools — not a ref to the
///     umbrella `Gaming Set` card, which would grant the family outright.
///   * Vehicles (`land vehicles`, `vehicles (water)`, `one vehicle`) match no
///     card and no family: the SRD ships no vehicle tools, so they are dropped
///     to prose rather than synthesised.
({List<Map<String, String>> refs, String? group}) parseToolProficiencies(
    String desc) {
  final key = _toolKey(desc);
  if (key.isEmpty) return (refs: const <Map<String, String>>[], group: null);

  final families = <String>{};
  for (final p in _toolGroupPhrases.entries) {
    if (RegExp('\\b${p.key}\\b').hasMatch(key)) families.add(p.value);
  }
  final hits = <String, ({String name, String? group})>{}; // match key -> card
  for (final e in _toolIndex.entries) {
    if (RegExp('\\b${RegExp.escape(e.key)}\\b').hasMatch(key)) {
      hits[e.key] = e.value;
    }
  }
  // Longest match wins: `Pan Flute` must not also register a bare `Flute`.
  final named = <String, String?>{}; // canonical name -> its group
  for (final e in hits.entries) {
    final shadowed = hits.keys.any((k) =>
        k != e.key && RegExp('\\b${RegExp.escape(e.key)}\\b').hasMatch(k));
    if (!shadowed) named[e.value.name] = e.value.group;
  }

  final hasOr = RegExp(r'\bor\b').hasMatch(key);
  if (families.length > 1) {
    return (refs: const <Map<String, String>>[], group: null);
  }
  final group = families.isEmpty ? null : families.first;

  if (hasOr) {
    // Only an unambiguous single-family choice survives an `or`.
    final ok = group != null && named.values.every((g) => g == group);
    return (
      refs: const <Map<String, String>>[],
      group: ok ? group : null,
    );
  }
  final refs = [
    for (final e in named.entries)
      if (group == null || e.value != group) softRef('tool', e.key),
  ];
  refs.sort((a, b) => a['name']!.compareTo(b['name']!));
  return (refs: refs, group: group);
}

/// Map classes + subclasses. Base classes (`subclass_of == null`) become
/// `class` entities; the rest become `subclass` entities (descriptive — no
/// class_ref link).
void mapClasses({
  required PackBuilder pack,
  required Normalizer norm,
  required String source,
  required List<Fixture> classes,
  required List<Fixture> features,
  List<Fixture> featureItems = const [],
}) {
  final featuresByParent = groupBy(features, 'parent');
  final itemsByFeature = groupBy(featureItems, 'parent');
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
      final desc = _appendTable(
        _fold(
          '*Subclass of $parent.*\n\n${(c['desc'] as String?)?.trim() ?? ''}',
          [for (final k in kids) if (!_isTableFeature(k, itemsByFeature)) k],
        ),
        _classTable(kids, itemsByFeature),
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
      // B1: the level table. `granted_at_level` is the lowest level any of the
      // subclass's own features arrives at — that *is* the level the subclass is
      // taken at, and the schema requires it. Left absent when the document
      // ships no levelled feature for it: inventing 3 would be a guess.
      final rows = _levelFeatures(kids, itemsByFeature);
      if (rows.isNotEmpty) {
        attrs['features'] = rows;
        attrs['granted_at_level'] = rows.first['level'];
      }
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

    // B2: table columns carry no prose of their own — folding them yields empty
    // `### Maneuvers Known` headings and `[Column data]` paragraphs — so they
    // are excluded from the fold and rendered as one markdown table instead.
    final desc = _appendTable(
      _fold((c['desc'] as String?)?.trim() ?? '',
          [for (final k in kids) if (!_isTableFeature(k, itemsByFeature)) k]),
      _classTable(kids, itemsByFeature),
    );
    attrs['description'] = desc;
    final rows = _levelFeatures(kids, itemsByFeature);
    if (rows.isNotEmpty) attrs['features'] = rows;
    pack.add(packEntity(
      slug: 'class', name: name, source: source,
      description: desc, attributes: attrs));
  }
}

/// v1 statblock fallback for species traits (audit **B3**): lowercased species
/// name → the `{name, desc}` rows reconstructed from v1 `Race.json`'s prose
/// columns. Built by `build_packs`; consulted only for a species v2 shipped
/// with zero `SpeciesTrait` rows.
typedef V1SpeciesIndex = Map<String, List<Map<String, String>>>;

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
  V1SpeciesIndex v1Traits = const {},
}) {
  final traitsByParent = groupBy(traits, 'parent');

  // B3 — a species upstream's v2 conversion left with **no** trait rows at all
  // gets them from v1 (`toh`'s Shade: 0 rows in v2, a full statblock in v1).
  // Same rule and same reason as B8's action backfill: only an entirely empty
  // set is filled, so a species v2 converted can never be overridden. The
  // recovered rows are `{name, desc}` shaped exactly like the v2 fixtures, so
  // every parser below — size, speed, ASI, languages, senses, D1–D9 — applies
  // to them unchanged.
  if (v1Traits.isNotEmpty) {
    for (final s in species) {
      final pk = s['_pk'].toString();
      if ((traitsByParent[pk] ?? const <Fixture>[]).isNotEmpty) continue;
      final name = (s['name'] as String?)?.trim().toLowerCase();
      final rows = name == null ? null : v1Traits[name];
      if (rows == null || rows.isEmpty) continue;
      traitsByParent[pk] = [
        for (final r in rows)
          <String, dynamic>{'parent': pk, 'name': r['name'], 'desc': r['desc']},
      ];
    }
  }

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
    final senseRanges = <String, int>{};
    final langs = <Map<String, String>>[];
    final abilityBonuses = <String, int>{};
    final dmgRes = <Map<String, String>>[];
    final dmgImm = <Map<String, String>>[];
    final dmgVuln = <Map<String, String>>[];
    final condImm = <Map<String, String>>[];
    final skillProf = <Map<String, String>>[];
    final spellRefs = <Map<String, String>>[];
    final cantripRefs = <Map<String, String>>[];
    final altSpeeds = <String, int>{};
    // B5 — every trait row none of the parsers below consumed becomes one
    // `mechanical_notes` line, so the rule reaches the sheet's "Other Effects"
    // instead of living only in the species description.
    final notes = <String>[];
    int grantCount() =>
        senses.length + langs.length + abilityBonuses.length + dmgRes.length +
        dmgImm.length + dmgVuln.length + condImm.length + skillProf.length +
        spellRefs.length + cantripRefs.length + altSpeeds.length;
    for (final t in kids) {
      final tn = (t['name'] as String?)?.trim().toLowerCase() ?? '';
      final d = (t['desc'] as String?) ?? '';
      final grantsBefore = grantCount();
      final sense = _senseWordIn(tn);
      if (sense != null) {
        final s = norm.lookupRef('sense', sense, context: name);
        if (s != null) {
          senses.add(s);
          final r = _senseRangeFt(d);
          final key = s['name'] ?? sense;
          if (r != null && r > (senseRanges[key] ?? 0)) senseRanges[key] = r;
        }
      }
      if (tn == 'languages') langs.addAll(_refListFromText(norm, 'language', d));
      if (tn == 'ability score increase') {
        _parseAsi(d).forEach((code, v) {
          abilityBonuses[code] = (abilityBonuses[code] ?? 0) + v;
        });
      }
      // D1 — damage resistance / immunity / vulnerability (lowercase prose; the
      // "X damage" anchor avoids matching damage dealt by an action). Scanned
      // over [dPerm], not [d]: a resistance that only holds for the minute an
      // activated trait lasts is not a species grant (audit B3).
      final dPerm = _permanentClauses(d);
      for (final m in RegExp(r'resistan\w*\s+to\s+([^.;]*?)\s+damage',
          caseSensitive: false).allMatches(dPerm)) {
        dmgRes.addAll(_refListFromText(norm, 'damage-type', m.group(1)!, ci: true));
      }
      for (final m in RegExp(r'immun\w*\s+to\s+([^.;]*?)\s+damage',
          caseSensitive: false).allMatches(dPerm)) {
        dmgImm.addAll(_refListFromText(norm, 'damage-type', m.group(1)!, ci: true));
      }
      for (final m in RegExp(r'vulnerab\w*\s+to\s+([^.;]*?)\s+damage',
          caseSensitive: false).allMatches(dPerm)) {
        dmgVuln.addAll(_refListFromText(norm, 'damage-type', m.group(1)!, ci: true));
      }
      // D2 — condition immunity (explicit immunity phrasing only; "advantage on
      // saves against X" is intentionally NOT a grant).
      for (final m in RegExp(
          r"(?:immun\w*\s+to|can'?t be|cannot be)\s+(?:the\s+|being\s+)?([a-z][a-z ]{0,24})",
          caseSensitive: false).allMatches(dPerm)) {
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
      if (grantCount() == grantsBefore && !_flavourTraitNames.contains(tn)) {
        final line = _noteLine((t['name'] as String?)?.trim() ?? '', d);
        if (line != null) notes.add(line);
      }
    }
    if (notes.isNotEmpty) attrs['mechanical_notes'] = notes.join('\n');
    void put(String key, List<Map<String, String>> v) {
      final dd = _dedupeByName(v);
      if (dd.isNotEmpty) attrs[key] = dd;
    }
    // `granted_senses` rows use the {sense_ref, range_ft} shape (audit B5).
    if (senses.isNotEmpty) {
      attrs['granted_senses'] = [
        for (final ref in _dedupeByName(senses))
          {
            'sense_ref': ref,
            if (senseRanges[ref['name']] != null)
              'range_ft': senseRanges[ref['name']]!,
          },
      ];
    }
    put('granted_languages', langs);
    if (abilityBonuses.isNotEmpty) attrs['ability_bonuses'] = abilityBonuses;
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

/// Species trait rows that are flavour or already have a typed home on the card
/// (`size_ref`, `speed_ft`, `creature_type_ref`), so they are not routed into
/// `mechanical_notes` even when no grant parser touches them.
const _flavourTraitNames = {
  'age', 'alignment', 'size', 'speed', 'creature type', 'type',
  'languages', 'language', 'ability score increase', 'ability scores',
};

// ── Species senses (audit B5) ──────────────────────────────────────────────
//
// The trait *name* is the key, not the prose: a monster-style "you have
// blindsight out to 30 feet" sentence inside some other trait is a conditional
// or an action, and the shipped species data has none of them anyway —
// measured on the pinned snapshot, all **9** sense-bearing SpeciesTrait rows in
// shipping documents are named `Darkvision` (7) or `Superior Darkvision` (2),
// and every one states its range. The old exact `name == 'darkvision'` test
// dropped both Superior rows on the floor (derro, drow — they had *no*
// darkvision at all) and never read a range, so 9 species shipped
// `{sense_ref}` with no `range_ft` while the built-in SRD cards next to them
// carry 60/120. `CharacterResolver.addSense` keeps the largest range per
// sense, so a subspecies' 120 correctly beats an inherited 60.

/// The canonical sense name a trait called [lowercaseName] grants, or null.
String? _senseWordIn(String lowercaseName) {
  for (final s in const ['Darkvision', 'Blindsight', 'Tremorsense', 'Truesight']) {
    if (lowercaseName.contains(s.toLowerCase())) return s;
  }
  return null;
}

/// The `within 60 feet` / `out to 30 feet` range in a sense trait's prose.
int? _senseRangeFt(String desc) => int.tryParse(
    RegExp(r'(?:within|out to|to a (?:range|distance) of)\s+(\d+)\s*(?:feet|foot|ft)',
                caseSensitive: false)
            .firstMatch(desc)
            ?.group(1) ??
        '');

/// One `mechanical_notes` line: `**Name.** text`, newlines collapsed because
/// the field is one rule per line. Empty text yields no line.
String? _noteLine(String name, String desc) {
  final text = desc.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return null;
  return name.isEmpty ? text : '**$name.** $text';
}

/// Sentences that scope a benefit to the duration of an activated trait, so a
/// resistance or immunity inside them is not something the species *has*.
///
/// Found by B3: `toh`'s Shade has "***Ghostly Flesh.*** … your transformation
/// lasts for 1 minute … **During it**, … you have resistance to bludgeoning,
/// piercing, and slashing damage …" — three permanent resistances at level 1
/// for a 1/long-rest, 3rd-level trait. Its unconditional necrotic resistance
/// (Spectral Resilience) is in a different sentence and still lands, which is
/// why the filter is per sentence rather than per trait.
final _temporaryClause = RegExp(
    r'\bduring (?:it|this|that|the transformation)\b'
    r'|\bwhile (?:it lasts|transformed)\b'
    r'|\bfor the duration\b',
    caseSensitive: false);

/// [desc] with every [_temporaryClause] sentence removed.
String _permanentClauses(String desc) {
  if (!_temporaryClause.hasMatch(desc)) return desc;
  return [
    for (final s in desc.split(RegExp(r'(?<=[.;])\s+')))
      if (!_temporaryClause.hasMatch(s)) s,
  ].join(' ');
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

  // Skill proficiency gate — "Proficiency in the X skill" or "Proficiency in one
  // of the following skills: A, B, C" (OR semantics: any one satisfies). Enforced
  // by the resolver dialog's `_passesPrereqClauses` skill_proficiency case.
  final skillNames = <Map<String, String>>[];
  for (final m in RegExp(r'proficiency in the\s+([A-Za-z ]+?)\s+skill',
          caseSensitive: false)
      .allMatches(prereq)) {
    skillNames.addAll(_refListFromText(norm, 'skill', m.group(1)!, ci: true));
  }
  final listSkill =
      RegExp(r'following skills?:\s*([A-Za-z ,]+)', caseSensitive: false)
          .firstMatch(prereq);
  if (listSkill != null) {
    skillNames
        .addAll(_refListFromText(norm, 'skill', listSkill.group(1)!, ci: true));
  }
  if (skillNames.isNotEmpty) {
    clauses.add({
      'type': 'skill_proficiency',
      'skill_options': _dedupeByName(skillNames),
    });
  }

  if (clauses.isNotEmpty) attrs['prereq_clauses'] = clauses;
}

/// A prerequisite string that carries no real gate ("*N/A*", "N/A", "-", "—",
/// "None", "*"). Punctuation/markup is stripped before the emptiness check.
bool _isJunkPrereq(String s) {
  final t = s.replaceAll(RegExp(r'[*_\s/.—–-]'), '').toLowerCase();
  return t.isEmpty || t == 'na' || t == 'none' || t == 'nil';
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
  // "An/one ability score of your choice increases by N" (Destiny's Call) — the
  // player picks which ability at the featAsi prompt; all six are options.
  final choiceIncr = RegExp(
    r'(?:an|one)\s+ability score\s+of your choice\s+increases?\s+by\s+(\d+)'
    r'(?:[^.]*?maximum of\s+(\d+))?',
    caseSensitive: false,
  ).firstMatch(desc);
  if (choiceIncr != null) {
    return (
      amount: int.parse(choiceIncr.group(1)!),
      maxScore:
          choiceIncr.group(2) != null ? int.parse(choiceIncr.group(2)!) : 20,
      options: [for (final n in _allAbilities) lookup('ability', n)],
    );
  }
  // "Choose one ability score. The chosen ability score increases by N…"
  // (Tenacious) — split across two sentences, so confirm the pick clause and the
  // increase clause separately before emitting the same all-six ASI.
  if (RegExp(r'choose\s+(?:one|an)\s+ability score\b', caseSensitive: false)
      .hasMatch(desc)) {
    final incr = RegExp(
      r'(?:chosen\s+ability\s+score|that\s+(?:ability\s+)?score|ability\s+score)'
      r'\s+increases?\s+by\s+(\d+)(?:[^.]*?maximum of\s+(\d+))?',
      caseSensitive: false,
    ).firstMatch(desc);
    if (incr != null) {
      return (
        amount: int.parse(incr.group(1)!),
        maxScore: incr.group(2) != null ? int.parse(incr.group(2)!) : 20,
        options: [for (final n in _allAbilities) lookup('ability', n)],
      );
    }
  }
  return null;
}

/// Feat benefit grants → grant-block fields written straight into [attrs]
/// (see `CharacterResolver.grantFieldKeys`). Conservative: only emits the
/// high-confidence, unconditional grants — armor proficiency, flat speed bonus,
/// and Tough-style per-level HP. Conditional / PB-scaling / "of your choice"
/// benefits stay in the folded narrative (honest source limits).
void _parseFeatGrants(String desc, Map<String, dynamic> attrs) {
  final armorProfs = <Map<String, String>>[];
  for (final m in RegExp(
          r'(?:training with|proficiency with|gain)\s+(Light|Medium|Heavy)\s+armor',
          caseSensitive: false)
      .allMatches(desc)) {
    armorProfs.add(lookup('armor-category', titleCase(m.group(1)!)));
  }
  if (RegExp(r'(?:training with|proficiency with|gain)\b[^.]{0,24}\bshields?\b',
          caseSensitive: false)
      .hasMatch(desc)) {
    armorProfs.add(lookup('armor-category', 'Shield'));
  }
  if (armorProfs.isNotEmpty) {
    attrs['granted_armor_proficiencies'] = _dedupeByName(armorProfs);
  }
  final sp = RegExp(r'\bspeed increases by\s+(\d+)\s*(?:feet|ft)\b',
          caseSensitive: false)
      .firstMatch(desc);
  if (sp != null) {
    attrs['speed_bonus_ft'] = int.parse(sp.group(1)!);
  }
  if (RegExp(r'hit point maximum increases by[^.]*twice your[^.]*level',
          caseSensitive: false)
      .hasMatch(desc)) {
    attrs['hp_bonus_per_level'] = 2;
  }
}

/// Feat benefit "choose N skills/tools of your choice" → a `player_choices`
/// row the resolver dialog renders as a skill/tool picker (matches the
/// built-in Skilled feat). Fires only on an explicit build grant — a number
/// word directly before `skills`/`tools`. Per-use "choose" (a die / a target /
/// to do X) never matches (no number+noun), and weapon/language picks have no
/// runtime `pick_kind`, so they stay in the folded prose.
List<Map<String, dynamic>> _parseFeatChoiceGroups(String desc) {
  final m = RegExp(
    r'(?:choose|gain proficiency (?:in|with)|proficiency (?:in|with)|gain)\s+'
    r'(\w+)\s+(?:skills?|tools?)\b'
    // Reject A5E subsystems that read as "<N> skill tricks / specialties / …"
    // (skill/tool followed by another noun) — those aren't proficiency picks.
    r'(?!\s+(?:trick|knack|tradition|specialt|lesson|die|dice))',
    caseSensitive: false,
  ).firstMatch(desc);
  if (m == null) return const [];
  final pick = _numberWord(m.group(1)!);
  if (pick == null || pick < 1) return const [];
  return [
    {
      'group_id': 'skills',
      'label': 'Skills & Tools',
      'prompt': 'Choose proficiencies',
      'pick_kind': 'skill_or_tool',
      'pick': pick,
    },
  ];
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
/// avoid the generic "cast a spell" phrasing; names go through [titleCaseName]
/// (not [titleCase]) because the resolver matches case-sensitively and no spell
/// name capitalises its articles. ("know the thaumaturgy cantrip" → cantrip Thaumaturgy; "cast the
/// hellish rebuke spell" → spell Hellish Rebuke.)
({List<String> cantrips, List<String> spells}) _parseSpellGrants(String desc) {
  final cantrips = <String>{};
  final spells = <String>{};
  for (final m in RegExp(r"\b(?:know|knows|learn)\s+the\s+([a-z][a-z' -]+?)\s+cantrip\b",
      caseSensitive: false).allMatches(desc)) {
    cantrips.add(titleCaseName(m.group(1)!));
  }
  for (final m in RegExp(r"\bcast\s+the\s+([a-z][a-z' -]+?)\s+spell\b",
      caseSensitive: false).allMatches(desc)) {
    spells.add(titleCaseName(m.group(1)!));
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

/// Fallback for non-A/B background equipment prose (A5E/Open5e fixed kits, e.g.
/// "Holy symbol, common clothes, robe, a prayer book"): wrap the whole kit as a
/// single-option `equipment_choice_group` so the wizard renders a pickable card
/// (replacing the dead "add these manually" note) AND the commit flow grants
/// every item to the PC's inventory — no manual adding.
///
/// A5E gear names mostly have no SRD catalog entity (153 distinct tokens, many
/// one-off flavor like "pet monkey"), and the cross-pack built-in names diverge
/// ("traveler's clothes" vs "Clothes, Traveler's"), so we can't ref existing
/// items reliably. Instead each kit item that doesn't already resolve in-pack is
/// **synthesised as a minimal `adventuring-gear` entity in this pack** and
/// hard-referenced — build-safe (in-pack ref) and grantable. Synthesis is
/// idempotent (PackBuilder.add dedupes by slug+name), so a token shared across
/// backgrounds ("Common Clothes") yields one entity reused by all.
List<Map<String, dynamic>>? _fixedEquipmentGroup(
    PackBuilder pack, String desc) {
  final body = desc.trim().replaceAll(RegExp(r'[;.\s]+$'), '');
  if (body.isEmpty) return null;
  int? gold;
  final gm = RegExp(r'(\d+)\s*gp\b', caseSensitive: false).firstMatch(body);
  if (gm != null) gold = int.parse(gm.group(1)!);
  final items = [
    for (final it in _kitItems(body))
      if (_gearRef(pack, it.name, it.qty) case final Map<String, dynamic> r) r,
  ];
  if (items.isEmpty && gold == null) return null;
  return [
    eqGroup(
      groupId: 'bg-equipment',
      label: 'Starting Equipment',
      prompt: "Your background's starting equipment",
      options: [
        eqOption(
          optionId: 'A',
          label: body.replaceAll(RegExp(r'\s+'), ' ').trim(),
          items: items,
          goldGp: gold,
        ),
      ],
    ),
  ];
}

/// Resolve a kit item to an `eqItem`-shaped entry. Audit **B6**: nothing is
/// synthesised any more. Three outcomes, in order:
///
///  * an item this pack genuinely ships → hard `ref`;
///  * a built-in catalog card → `softRef` under the **built-in's own** name, so
///    it name-resolves at commit and lands in the PC's inventory;
///  * neither → **no item row at all**. What falls through here is background
///    flavour — "pet monkey wearing a tiny fez", "stories you know", "memento of
///    your destiny" — which is not a catalog item in any pack; minting an empty
///    `adventuring-gear` stub for it was the bug (159 entities with no
///    description, cost or weight, 47 of them dupes), and shipping a knowingly
///    dangling soft ref instead would only move the lie into T3's gate. Nothing
///    is hidden: the option's `label` is the kit prose verbatim.
Map<String, dynamic>? _gearRef(PackBuilder pack, String name, int qty) {
  final existing = _resolveItemSlug(pack, name);
  if (existing != null) return eqItem(existing, name, qty: qty);
  final builtin = builtinItem(name);
  if (builtin == null) return null;
  return {'ref': softRef(builtin.slug, builtin.name), 'quantity': qty};
}

/// `name → (slug, name)` over every built-in item category a starting-equipment
/// line can land on. Indexed under three spellings, all mechanical: the catalog
/// name itself, the inverted form of its comma names ("Bullseye Lantern" for
/// "Lantern, Bullseye") and the parenthetical-free form ("Staff" for "Staff
/// (Arcane Focus)"). First writer wins, like the runtime's own name index.
final _builtinItems = () {
  final out = <String, ({String slug, String name})>{};
  final index = builtinNameIndex();
  for (final slug in const [
    'adventuring-gear',
    'tool',
    'weapon',
    'armor',
    'ammunition',
    'pack',
    'mount',
    'vehicle',
    'animal',
  ]) {
    final prefix = nameKey(slug, '');
    for (final key in index) {
      if (!key.startsWith(prefix)) continue;
      final name = key.substring(prefix.length);
      void put(String k) =>
          out.putIfAbsent(k.toLowerCase(), () => (slug: slug, name: name));
      put(name);
      final comma = name.split(', ');
      if (comma.length == 2) put('${comma[1]} ${comma[0]}');
      final bare = name.replaceFirst(RegExp(r'\s*\([^)]*\)$'), '').trim();
      if (bare.isNotEmpty) put(bare);
    }
  }
  return out;
}();

/// Built-in catalog entry for a kit token, or null. Three forgiving rules, all
/// mechanical, none of them guessing *which* card the prose meant:
///
///  * a plural ("Torches" → Torch, "Candles" → Candle);
///  * the tail after the last ` of `, because the measure is not the item
///    ("Bottle Of Ink" → Ink, "50 Sheets Of Parchment" → Parchment);
///  * a leading measure word ("Days Rations" → Rations, "Person Tent" → Tent).
///
/// Each rule only ever *lands* on a real catalog name, so a token whose tail is
/// not an item ("Collection Of Bones", "Memento Of Your Destiny") still misses —
/// which is the point. A wrong grant is worse than none.
({String slug, String name})? builtinItem(String raw) {
  final s = raw.trim().toLowerCase();
  final exact = _plural(s);
  if (exact != null) return exact;
  final of = s.lastIndexOf(' of ');
  if (of >= 0) {
    final tail = _plural(s.substring(of + 4));
    if (tail != null) return tail;
  }
  final space = s.indexOf(' ');
  if (space > 0 && _measureWords.contains(s.substring(0, space))) {
    return _plural(s.substring(space + 1));
  }
  return null;
}

({String slug, String name})? _plural(String s) =>
    _builtinItems[s] ??
    (s.endsWith('es') ? _builtinItems[s.substring(0, s.length - 2)] : null) ??
    (s.endsWith('s') ? _builtinItems[s.substring(0, s.length - 1)] : null);

/// Units a kit line counts an item in. None of them is itself a catalog card,
/// so dropping one can never hide a real item ("pouch" is deliberately absent —
/// the catalog ships one).
const _measureWords = <String>{
  'day', 'days', 'foot', 'feet', 'sheet', 'sheets', 'piece', 'pieces',
  'bottle', 'bottles', 'person', //
};

/// Tokenise a background equipment kit prose into `(name, qty)` item rows.
/// Splits on commas / "and" / "or" / ";", strips leading articles + quantity +
/// "set of"/"pair of" wrappers + parentheticals + trailing punctuation, drops
/// pure gold/number fragments, then title-cases. "X or Y" alternatives are all
/// emitted (granted) — the parser has no notion of an intra-kit choice. Deduped.
List<({String name, int qty})> _kitItems(String body) {
  // Keep "1,000" intact across the comma split; normalise curly apostrophes.
  var s = body.replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}${m[2]}');
  s = s.replaceAll('’', "'");
  // Drop parentheticals up-front — "(amulet or reliquary)" must not fragment on
  // the comma/or split below — and strip embedded gold ("with 10 gp",
  // "containing 5 gp", a bare "10 gp") so it never becomes a phantom item.
  s = s.replaceAll(RegExp(r'\([^)]*\)'), ' ');
  s = s.replaceAll(
      RegExp(r'\b(?:with|containing)\b[^,;]*?\bgp\b', caseSensitive: false), ' ');
  s = s.replaceAll(RegExp(r'\b\d+\s*gp\b', caseSensitive: false), ' ');
  final out = <({String name, int qty})>[];
  final seen = <String>{};
  for (var seg in s.split(RegExp(r',|\band\b|\bor\b|;', caseSensitive: false))) {
    seg = seg.replaceAll(RegExp(r'[.;:,]+\s*$'), '').trim();
    if (seg.isEmpty) continue;
    var qty = 1;
    final qm = RegExp(r'^(\d+)\s+(.*)$').firstMatch(seg);
    if (qm != null) {
      qty = int.parse(qm.group(1)!);
      seg = qm.group(2)!.trim();
    }
    seg = seg
        .replaceFirst(
            RegExp(r'^(a|an|one|your|the|some|several|of)\s+',
                caseSensitive: false),
            '')
        .replaceFirst(
            RegExp(r'^(set|pair|piece|type)\s+of\s+', caseSensitive: false), '')
        .replaceFirst(
            RegExp(r'\s+of your (choice|choosing)\b.*$', caseSensitive: false),
            '')
        .trim();
    if (seg.length < 2) continue;
    if (RegExp(r'^\d+\s*(gp|gold|sp|cp)?$', caseSensitive: false).hasMatch(seg)) {
      continue;
    }
    if (RegExp(r'^(gp|gold|sp|cp)$', caseSensitive: false).hasMatch(seg)) {
      continue;
    }
    final name = titleCase(seg);
    if (seen.add(name.toLowerCase())) out.add((name: name, qty: qty));
  }
  return out;
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
    // Audit **B6**: same resolution as the fixed-kit path. This used to emit a
    // ref only when the item shipped in-pack — and no shipped document carries
    // a mundane-equipment fixture (A1), so a class A/B option granted nothing.
    final item = _gearRef(pack, name, qty);
    if (item != null) items.add(item);
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

/// Typed fixed ability-score bonuses from an "Ability Score Increase" trait,
/// emitted into the `ability_bonuses` stat map that the built-in species use.
/// The "+N to ability scores each" wording grants all six; explicit
/// "X score increases by N" phrases grant that one. "of your choice" wording is
/// intentionally left to the folded narrative (no fixed typing possible).
/// Fixed ASI prose → `ability_bonuses` map entries ({'STR': 2, ...}).
Map<String, int> _parseAsi(String desc) {
  if (RegExp(r'ability scores?\s+each\s+increase\s+by\s+(\d+)',
              caseSensitive: false)
          .hasMatch(desc) ||
      RegExp(r'each of your ability scores?\s+increases?\s+by\s+(\d+)',
              caseSensitive: false)
          .hasMatch(desc)) {
    final v = int.parse(RegExp(r'by\s+(\d+)').firstMatch(desc)!.group(1)!);
    return {for (final code in _abilityCode.values) code: v};
  }
  final out = <String, int>{};
  final re = RegExp(
      r'(Strength|Dexterity|Constitution|Intelligence|Wisdom|Charisma)\s+score\s+increases?\s+by\s+(\d+)',
      caseSensitive: false);
  for (final m in re.allMatches(desc)) {
    final code = _abilityCode[m.group(1)!.toLowerCase()];
    if (code == null) continue;
    out[code] = (out[code] ?? 0) + int.parse(m.group(2)!);
  }
  return out;
}

/// Map backgrounds. Descriptive (benefits folded into description) plus the
/// typed grants Open5e carries as benefit rows keyed by `type`: skill
/// proficiencies (`skill_proficiency`) → `granted_skill_refs`, SRD-2024 ability
/// options (`ability_score`) → `ability_score_options` (+ `asi_distribution_options`
/// when three abilities are offered), language slots (`language`) →
/// `granted_language_count`, and — audit **B3** — tool proficiencies
/// (`tool_proficiency`) → `granted_tool_refs` / `granted_tool_variant_group`
/// via [parseToolProficiencies].
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
      final named = _refListFromText(norm, 'ability', abilText);
      // A5E phrasing "+1 to X and one other ability score" grants the named +1
      // plus a floating +1 to any other ability. The resolver gates
      // `background_asi` by `ability_score_options` (character_resolver.dart),
      // so a single-named option silently drops the player's floating pick —
      // widen to all six abilities. SRD-2024's three-named distribution stays.
      final floating = RegExp(
        r'one\s+other\s+abilit|another\s+abilit|other\s+ability\s+score',
        caseSensitive: false,
      ).hasMatch(abilText);
      final abilities = floating
          ? [for (final n in _allAbilities) lookup('ability', n)]
          : named;
      if (abilities.isNotEmpty) {
        attrs['ability_score_options'] = abilities;
        // SRD-2024 p.83: three offered abilities → player picks +2/+1 or +1/+1/+1.
        if (!floating && abilities.length >= 3) {
          attrs['asi_distribution_options'] = ['+2/+1', '+1/+1/+1'];
        }
      }
    }
    // B3 — tool proficiencies. Tools are content cards in the built-in pack, so
    // (like `origin_feat_ref`) they travel as softRefs: a hard `_ref` would fail
    // the build, and the resolver drops a softRef whose target isn't installed.
    final toolText = descOfType('tool_proficiency');
    if (toolText != null) {
      final t = parseToolProficiencies(toolText);
      if (t.refs.isNotEmpty) attrs['granted_tool_refs'] = t.refs;
      if (t.group != null) attrs['granted_tool_variant_group'] = t.group;
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
    // A5E/Open5e backgrounds instead ship a fixed kit (no A/B) — fall back to a
    // single-option group so that gear is choosable + grantable too.
    final equipText = descOfType('equipment');
    if (equipText != null) {
      final groups = _parseEquipmentChoiceProse(pack, equipText) ??
          _fixedEquipmentGroup(pack, equipText);
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
    var prereq = (f['prerequisite'] as String?)?.trim() ?? '';
    // Junk prerequisites ("*N/A*", "N/A", "-", "None") aren't real gates — drop
    // them so they neither render a "Prerequisite: N/A" line nor block.
    if (_isJunkPrereq(prereq)) prereq = '';
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
    _parseFeatGrants(benefitText, attrs);
    final choices = _parseFeatChoiceGroups(benefitText);
    if (choices.isNotEmpty) attrs['player_choices'] = choices;
    // B5 — one `mechanical_notes` line per benefit row the parsers above left
    // untyped. A feat with no `Benefit` rows carries its rule in its own desc,
    // so that row stands in (unnamed: the name is the card's).
    final notes = <String>[];
    for (final row in kids.isEmpty ? [f] : kids) {
      final rowText = (row['desc'] as String?)?.trim() ?? '';
      if (rowText.isEmpty) continue;
      final probe = <String, dynamic>{};
      _parseFeatGrants(rowText, probe);
      if (_parseFeatAsi(rowText) != null) probe['asi'] = true;
      if (_parseFeatChoiceGroups(rowText).isNotEmpty) probe['choices'] = true;
      if (probe.isNotEmpty) continue;
      final line = _noteLine(
          identical(row, f) ? '' : (row['name'] as String?)?.trim() ?? '',
          rowText);
      if (line != null) notes.add(line);
    }
    if (notes.isNotEmpty) attrs['mechanical_notes'] = notes.join('\n');
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

/// The `classFeatures` level table for one class/subclass (audit phase **B1**).
///
/// `ClassFeature` has no level; its child `ClassFeatureItem` does, keyed by
/// `parent` → the feature's pk. Two shapes share that file and only one is a
/// granted feature:
///
///   * **granted feature** — one item per level the feature arrives or improves
///     at, `column_value == null`. Becomes a row here.
///   * **class-table column** — 20 items, one per level, each carrying a
///     `column_value` (`Proficiency Bonus`, `Augment Effects Known`, spell
///     slots). Belongs to B2's typed `*_by_level` fields, not to a feature list,
///     so it is skipped. No shipped document *mixes* the two within one feature,
///     which is what makes "every item has a `column_value`" a safe test.
///
/// A feature that improves gets one row per distinct level; `detail` (`'2 dice'`,
/// `'two attacks'`) is the only thing distinguishing those rows upstream, so it
/// carries the follow-up rows' description while the first keeps the prose.
/// No grant refs are emitted — the prose names no entity we could resolve.
// ── Class tables (audit B2) ────────────────────────────────────────────────
//
// B1 correctly refused to emit a `ClassFeatureItem` column as 20 identical
// "features" and left it to B2. Nothing then picked it up, so **171 rows of
// genuine class-table content were dropped entirely** — and worse than
// silently: the owning `ClassFeature` carries no prose (`''` in `a5e-ag`, the
// literal placeholder `'[Column data]'` in `bfrd`), so `_fold` was shipping
// empty `### Maneuvers Known` headings and three `[Column data]` paragraphs
// into the Marshal's and Mechanist's descriptions.
//
// B2 was filed as `feature_type == CORE_TRAITS_TABLE` + `column_value` →
// `cantrips_known_by_level` / `prepared_spells_by_level` / `spell_slots_by_level`
// / `extra_attack_count_by_level`. **None of that is reachable.** Measured over
// the pinned snapshot: `CORE_TRAITS_TABLE` exists in exactly one document
// (`srd-2024`, 12 rows) and `SPELL_SLOTS` in two (`srd-2014` 55, `srd-2024` 55)
// — all three are documents the publisher-wide SRD skip never builds. The
// `Cantrips Known`, `Prepared Spells` and `Spell Slots` columns those fields
// need do not exist in any shipped document.
//
// What *is* there is 7 bespoke columns across 2 classes with no schema field to
// hold them: Marshal's Commanding Presence / Followers / Maneuvers Known /
// Maneuver Degree / Lessons Known, and Mechanist's two Augment Effects Known.
// So they are rendered back into the description as a markdown table: no
// schema change, no invented mechanic, and the numbers stop vanishing.

/// True when every `ClassFeatureItem` of this feature carries a `column_value`
/// — B1's test for "this is a class-table column, not a granted feature". No
/// shipped document mixes the two inside one feature, which is what makes it a
/// test rather than a heuristic.
bool _isTableFeature(Fixture f, Map<String, List<Fixture>> itemsByFeature) {
  final items = itemsByFeature[f['_pk'].toString()] ?? const <Fixture>[];
  if (items.isEmpty) return false;
  return items.every((i) {
    final v = i['column_value'];
    return v is String && v.trim().isNotEmpty;
  });
}

/// The standard 5e proficiency bonus by level. Both `PROFICIENCY_BONUS` columns
/// on the snapshot reproduce it exactly, and the app computes it already
/// (`proficiencyTableDefault`), so rendering it would duplicate a derived value
/// as though it were content. A document that ever *deviates* is rendered.
String _standardProfBonus(int level) => '+${((level - 1) ~/ 4) + 2}';

/// Render a class's `column_value` features as one markdown table appended to
/// its description. Returns an empty string when the class has no table, or
/// when its only table is the standard proficiency bonus.
String _classTable(
  List<Fixture> features,
  Map<String, List<Fixture>> itemsByFeature,
) {
  final columns = <({String name, Map<int, String> byLevel})>[];
  for (final f in features) {
    if (!_isTableFeature(f, itemsByFeature)) continue;
    final name = (f['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) continue;
    final byLevel = <int, String>{};
    for (final i in itemsByFeature[f['_pk'].toString()]!) {
      final lvl = i['level'];
      if (lvl is! int || lvl < 1 || lvl > 20) continue;
      byLevel[lvl] = (i['column_value'] as String).trim();
    }
    if (byLevel.isEmpty) continue;
    // Drop a proficiency-bonus column that only restates the standard table.
    if ((f['feature_type'] as String?) == 'PROFICIENCY_BONUS' &&
        byLevel.entries.every((e) => e.value == _standardProfBonus(e.key))) {
      continue;
    }
    // `bfrd` ships two distinct columns both named `Augment Effects Known`;
    // numbering them keeps the header honest instead of silently merging.
    var label = name;
    final clash = columns.where((c) => c.name == name || c.name.startsWith('$name (')).length;
    if (clash > 0) label = '$name (${clash + 1})';
    columns.add((name: label, byLevel: byLevel));
  }
  if (columns.isEmpty) return '';

  final levels = <int>{for (final c in columns) ...c.byLevel.keys}.toList()..sort();
  final buf = StringBuffer('### Class Table\n\n| Level | ')
    ..writeAll(columns.map((c) => c.name), ' | ')
    ..write(' |\n|---:|')
    ..writeAll(columns.map((_) => '---'), '|')
    ..write('|\n');
  for (final lvl in levels) {
    buf.write('| $lvl | ');
    buf.writeAll(columns.map((c) => c.byLevel[lvl] ?? '—'), ' | ');
    buf.write(' |\n');
  }
  return buf.toString().trimRight();
}

/// Join a folded description and a rendered class table, either of which may be
/// empty (most classes have no table at all).
String _appendTable(String desc, String table) {
  if (table.isEmpty) return desc;
  if (desc.isEmpty) return table;
  return '$desc\n\n$table';
}

List<Map<String, dynamic>> _levelFeatures(
  List<Fixture> features,
  Map<String, List<Fixture>> itemsByFeature,
) {
  final rows = <Map<String, dynamic>>[];
  for (final f in features) {
    final name = (f['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) continue;
    final items = itemsByFeature[f['_pk'].toString()] ?? const <Fixture>[];
    if (items.isEmpty) continue;
    // Level → the item's `detail`, first non-empty wins.
    final byLevel = <int, String?>{};
    for (final i in items) {
      if (i['column_value'] != null) continue;
      final lvl = i['level'];
      if (lvl is! int || lvl < 1 || lvl > 20) continue;
      final detail = (i['detail'] as String?)?.trim();
      byLevel.putIfAbsent(lvl, () => (detail?.isEmpty ?? true) ? null : detail);
    }
    if (byLevel.isEmpty) continue;
    final desc = (f['desc'] as String?)?.trim() ?? '';
    final levels = byLevel.keys.toList()..sort();
    for (var n = 0; n < levels.length; n++) {
      final detail = byLevel[levels[n]];
      final body = n == 0
          ? [desc, if (detail != null) '**At this level:** $detail']
              .where((s) => s.isNotEmpty)
              .join('\n\n')
          : (detail != null ? '**At this level:** $detail' : desc);
      rows.add(<String, dynamic>{
        'level': levels[n],
        'name': name,
        if (body.isNotEmpty) 'description': body,
      });
    }
  }
  rows.sort((a, b) => (a['level'] as int).compareTo(b['level'] as int));
  return rows;
}

/// `'D12'` / `'d8'` → `12` / `8`.
int? _hitDie(dynamic raw) {
  if (raw is! String) return null;
  final m = RegExp(r'(\d+)').firstMatch(raw);
  return m == null ? null : int.parse(m.group(1)!);
}

String _lastSegment(String slug) =>
    slug.contains('_') ? slug.substring(slug.lastIndexOf('_') + 1) : slug;
