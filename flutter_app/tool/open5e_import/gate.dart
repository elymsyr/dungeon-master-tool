// Relational sanity gate (offline audit tool, phase **T3**).
//
// The engine; `bin/gate_packs.dart` is the CLI over it and `bin/build_packs.dart`
// runs it over what it just wrote, so a pack that fails here never ships.
//
// Fifth sibling of `audit_packs.dart` (are the fields filled?),
// `dupe_census.dart` (should this entity exist?), `diff_packs.dart` (what did my
// rebuild change?) and `verify.dart` (is the value the source's?). This one asks
// the question none of them can: **do the entities hang together?**
//
// Every check here is per-*entity* and relational, which is exactly the shape a
// per-field census cannot express. `docs/open5e_content_audit.md` §3.5 exists
// because of that hole: `open5e-tob3` shipped 396 statblocks with no actions and
// every tool stayed green — `audit_packs` counted `action_refs` as "filled"
// (many monsters had one), the build gate saw no dangling ref (the refs that
// existed all resolved, there were simply too few), and `verify_packs` compares
// values, not cardinalities.
//
// ## The rules
//
//   monster-actionless      a `monster` whose five action buckets are all empty
//   orphan-child            a `creature-action` / `trait` no statblock points at
//   dangling-hard-ref       a uuid `_ref` with no entity of that id in the pack
//   dangling-soft-ref       a `{slug|_lookup, name}` ref that resolves nowhere
//   qualifier-strip         a soft ref that resolves *only* after the runtime's
//                           trailing-parenthetical retry
//   empty-equipment-option  an `equipment_choice_groups` option with no item
//   bucket-skew             a pack whose base `action_refs` are outnumbered by
//                           its bonus/reaction/legendary/lair refs
//
// `bucket-skew` is the shape of the tob3 defect stated as a rule rather than as
// a count: every statblock has actions and only some have the other three, so a
// pack where the base bucket loses is a mis-bucketed conversion, not content.
// tob3 shipped 2 `action_refs` against 307 of the others.
//
// `qualifier-strip` is a *latent* hazard, not a live bug, and is asserted so it
// stays that way (audit L0, §3.4). `_ensureChild` disambiguates a colliding
// child name with the creature's ("Scimitar (Firetamer)") and the runtime's
// `findEntityIdByName` strips exactly that qualifier on a miss, so 3,501 bundled
// rows have a stripped form that names a built-in card. Nothing points at those
// names today. The day something does, it lands on the generic card silently —
// this rule is what makes that noisy instead.
//
// ## Resolution scope
//
// A soft ref resolves lazily at read time across every *installed* package, so
// the index here is the built-in pack (in scope for every world implicitly) plus
// every bundled pack — the same corpus `dupe_census` section C uses, matched the
// same way: `findEntityIdByName` is case-**sensitive**.
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';

/// A monster's five child-action buckets. `action_refs` is the base one and is
/// schema-required; the other four are situational.
const kActionBuckets = <String>[
  'action_refs',
  'bonus_action_refs',
  'reaction_refs',
  'legendary_action_refs',
  'lair_action_refs',
];

/// Every monster field whose targets are that one statblock's own rows.
const _childRefKeys = <String>[...kActionBuckets, 'trait_refs'];

/// Below this many monsters a pack's bucket mix is anecdote, not distribution
/// (`tdcs` ships 4 creatures with 7 actions between them).
const _minMonstersForSkew = 20;

/// `pack/name` of statblocks that are actionless **upstream** — checked in the
/// pinned snapshot: `a5e-mm/CreatureAction.json` has no row parented to either,
/// and neither name exists in any v1 `Monster.json`, so B8's backfill has
/// nothing to recover. T3's exit is "green, or each exception carries a
/// reason"; this is the list of reasons, and it is deliberately by name so a
/// pack that loses a different creature's actions still fails.
const _actionlessUpstream = <String>{
  'open5e-a5e-mm/Frog',
  'open5e-a5e-mm/Seahorse',
};

/// `pack/name / option` of equipment options whose kit names **nothing the
/// SRD 5.2.1 catalog ships** (audit **B6**). Each was read: they ask for a
/// generic category rather than an item ("a set of artisan's tools", "one
/// musical instrument of your choice"), or for gear 5.2.1 dropped ("common
/// clothes", "cold-weather clothes", "vestments", "snowshoes", "donkey"). A
/// holy symbol is three cards (Amulet / Emblem / Reliquary), so picking one
/// would be a coercion. All four still grant their gold, and the option label
/// still shows the prose. Same contract as [_actionlessUpstream]: by name, so a
/// *different* option going empty still fails the gate.
const _kitlessUpstream = <String>{
  'open5e-tdcs/Recovered Cultist / A',
  'open5e-toh/Mysterious Origins / A',
  'open5e-toh/Northern Minstrel / A',
  'open5e-toh/Trophy Hunter / A',
};

/// See the `escape-residue` rule: `Væ00e6ttir` is `Vættir` with the escape
/// marker collapsed and the code point left behind as text.
final _escapeResidue = RegExp(r'æ00[0-9a-fA-F]{2}');

class GateViolation {
  GateViolation(this.pack, this.rule, this.subject, this.detail);

  final String pack;
  final String rule;

  /// The entity (or pack) the rule failed on.
  final String subject;
  final String detail;

  @override
  String toString() => '$pack · $subject — $detail';
}

class GateReport {
  final List<GateViolation> violations = [];

  Map<String, int> get countsByRule {
    final out = <String, int>{};
    for (final v in violations) {
      out[v.rule] = (out[v.rule] ?? 0) + 1;
    }
    return out;
  }

  void printPlain({int examples = 5}) {
    if (violations.isEmpty) {
      print('Relational gate: green — no violations.');
      return;
    }
    final byRule = <String, List<GateViolation>>{};
    for (final v in violations) {
      byRule.putIfAbsent(v.rule, () => []).add(v);
    }
    print('Relational gate: ${violations.length} violation(s)\n');
    byRule.forEach((rule, list) {
      print('## $rule — ${list.length}');
      for (final v in list.take(examples)) {
        print('   $v');
      }
      if (list.length > examples) {
        print('   … ${list.length - examples} more');
      }
      print('');
    });
  }
}

/// `(slug, name)` join key — byte-for-byte what `findEntityIdByName` indexes
/// on, NUL-separated so a name containing a space cannot collide.
String nameKey(String slug, String name) => '$slug\u0000$name';

/// The runtime's qualifier-tolerant retry, copied from `findEntityIdByName`:
/// on an exact miss, one attempt with a trailing parenthetical removed.
String? _strippedName(String name) {
  final stripped = name.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
  if (stripped.isEmpty || stripped == name) return null;
  return stripped;
}

/// `(slug, name)` of everything the built-in pack ships — Tier-0 seed rows plus
/// the SRD 5.2.1 core content. Every soft ref in a bundled pack is aimed here.
Set<String> builtinNameIndex() {
  final out = <String>{};
  generateBuiltinDnd5eV2Schema().seedRows.forEach((slug, rows) {
    for (final row in rows) {
      final name = row['name'];
      if (name is String) out.add(nameKey(slug, name));
    }
  });
  for (final raw in buildSrdCorePack().entities.values) {
    if (raw is! Map) continue;
    final slug = raw['type']?.toString();
    final name = raw['name']?.toString();
    if (slug != null && name != null) out.add(nameKey(slug, name));
  }
  return out;
}

/// Read every `*.pkg.json` in [packDir] and gate them together.
GateReport gatePackDir(String packDir) {
  final files = Directory(packDir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.pkg.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final packs = <String, Map<String, dynamic>>{};
  for (final f in files) {
    final root = jsonDecode(f.readAsStringSync());
    if (root is! Map) continue;
    final entities = root['entities'];
    if (entities is! Map) continue;
    packs[f.uri.pathSegments.last.replaceAll('.pkg.json', '')] =
        entities.cast<String, dynamic>();
  }
  return gatePacks(packs, builtinNameIndex());
}

/// The gate itself: [packs] is `packName → (entityId → wire row)`, [builtin] the
/// `(slug, name)` index every soft ref may also land in.
GateReport gatePacks(
  Map<String, Map<String, dynamic>> packs,
  Set<String> builtin,
) {
  final report = GateReport();

  // Soft refs resolve across every installed package, so the name index is the
  // built-in pack plus the whole bundled corpus, not one pack at a time.
  final nameIndex = {...builtin};
  for (final entities in packs.values) {
    for (final raw in entities.values) {
      if (raw is! Map) continue;
      final slug = raw['type']?.toString();
      final name = raw['name']?.toString();
      if (slug != null && name != null) nameIndex.add(nameKey(slug, name));
    }
  }

  packs.forEach((pack, entities) {
    final referencedChildren = <String>{};
    var monsters = 0;
    var baseActions = 0;
    var otherActions = 0;

    entities.forEach((id, raw) {
      if (raw is! Map) return;
      final type = raw['type']?.toString() ?? '?';
      final name = raw['name']?.toString() ?? id;
      final attrs = raw['attributes'];
      if (attrs is! Map) return;

      if (type == 'monster') {
        monsters++;
        var actions = 0;
        for (final bucket in _childRefKeys) {
          final refs = attrs[bucket];
          if (refs is! List) continue;
          for (final r in refs) {
            if (r is String) referencedChildren.add(r);
          }
          if (bucket == 'trait_refs') continue;
          actions += refs.length;
          if (bucket == 'action_refs') {
            baseActions += refs.length;
          } else {
            otherActions += refs.length;
          }
        }
        if (actions == 0 && !_actionlessUpstream.contains('$pack/$name')) {
          report.violations.add(GateViolation(
              pack, 'monster-actionless', name, 'no action of any kind'));
        }
      }

      for (final option in _equipmentOptions(attrs)) {
        final items = option['items'];
        // Audit **B6**: an option's items are a mix of in-pack uuids and
        // cross-pack soft refs at the built-in catalog, and `resolveEntityRef`
        // grants both. Counting only the uuid would call every linked option
        // empty — the exact blindness that let the gear stubs look correct.
        final resolved = items is List
            ? items.where((i) =>
                i is Map &&
                (i['ref'] is String
                    ? entities.containsKey(i['ref'])
                    : i['ref'] is Map &&
                        nameIndex.contains(nameKey(
                            (i['ref']['slug'] ?? i['ref']['_lookup'] ?? '')
                                .toString(),
                            (i['ref']['name'] ?? '').toString()))))
            : const [];
        final subject = '$name / ${option['option_id'] ?? '?'}';
        if (resolved.isEmpty && !_kitlessUpstream.contains('$pack/$subject')) {
          report.violations.add(GateViolation(pack, 'empty-equipment-option',
              subject, 'option resolves no item'));
        }
      }

      _walkRefs(attrs, (key, value) {
        if (value is String) {
          if (!entities.containsKey(value)) {
            report.violations.add(GateViolation(
                pack, 'dangling-hard-ref', name, '$key → $value'));
          }
          return;
        }
        if (value is! Map) return;
        final slug = (value['slug'] ?? value['_lookup'])?.toString();
        final target = value['name']?.toString();
        if (slug == null || target == null) return;
        if (nameIndex.contains(nameKey(slug, target))) return;
        final stripped = _strippedName(target);
        if (stripped != null && nameIndex.contains(nameKey(slug, stripped))) {
          report.violations.add(GateViolation(pack, 'qualifier-strip', name,
              '$key → $slug/"$target" resolves only as "$stripped"'));
          return;
        }
        report.violations.add(GateViolation(
            pack, 'dangling-soft-ref', name, '$key → $slug/"$target"'));
      });
    });

    // **R2 / F-pass0-27.** Upstream's half-resolved unicode escapes (`æ` plus
    // the four hex digits of the character it stood for) shipped straight to
    // eight cards, one of them a card *name*, and no gate could see it: the
    // text matched the source byte for byte. The mapper repairs it; this rule
    // is what stops it returning silently.
    entities.forEach((id, raw) {
      if (raw is! Map) return;
      for (final key in const ['name', 'description']) {
        final v = raw[key];
        if (v is String && _escapeResidue.hasMatch(v)) {
          report.violations.add(GateViolation(
              pack,
              'escape-residue',
              raw['name']?.toString() ?? id,
              '$key carries a half-resolved unicode escape'));
        }
      }
    });

    entities.forEach((id, raw) {
      if (raw is! Map) return;
      final type = raw['type']?.toString();
      if (type != 'creature-action' && type != 'trait') return;
      if (referencedChildren.contains(id)) return;
      report.violations.add(GateViolation(pack, 'orphan-child',
          raw['name']?.toString() ?? id, '$type reachable from no statblock'));
    });

    // Strictly outnumbered: a pack where the two sides tie is thin, not broken,
    // and thin is `audit_packs`' question.
    if (monsters >= _minMonstersForSkew && baseActions < otherActions) {
      report.violations.add(GateViolation(
          pack,
          'bucket-skew',
          pack,
          '$baseActions action_refs across $monsters monsters, against '
              '$otherActions bonus/reaction/legendary/lair — the base bucket '
              'cannot be the smallest'));
    }
  });

  return report;
}

/// The `equipment_choice_groups` options of one entity, flattened.
Iterable<Map> _equipmentOptions(Map attrs) sync* {
  final groups = attrs['equipment_choice_groups'];
  if (groups is! List) return;
  for (final g in groups) {
    if (g is! Map) continue;
    final options = g['options'];
    if (options is! List) continue;
    for (final o in options) {
      if (o is Map) yield o;
    }
  }
}

/// Visit every ref-shaped value under [node]: hard uuids and soft `{slug, name}`
/// maps alike. A ref lives under a key ending in `_ref`/`_refs`, or under `ref`
/// inside an equipment item; nothing else in the wire format holds one.
void _walkRefs(dynamic node, void Function(String key, dynamic value) visit) {
  if (node is Map) {
    node.forEach((k, v) {
      final key = k.toString();
      if (key == 'ref' || key.endsWith('_ref') || key.endsWith('_refs')) {
        if (v is List) {
          for (final item in v) {
            visit(key, item);
          }
        } else if (v != null) {
          visit(key, v);
        }
        return;
      }
      _walkRefs(v, visit);
    });
  } else if (node is List) {
    for (final item in node) {
      _walkRefs(item, visit);
    }
  }
}
