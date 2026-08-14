// The definition of "the same card", shared by the census and the build
// (audit phase **L4**).
//
// This module exists because the two sides used to disagree by construction.
// `bin/dupe_census.dart` held the text comparison in a private function, and
// `bin/build_packs.dart` can only reach the shared modules — so a build that
// dropped duplicates would have applied its own notion of "identical" while the
// census that grades it applied another. A phase whose exit criterion *is* a
// census number cannot afford two definitions of the number, so there is one
// here and both sides import it.
//
// ## What counts as the same card
//
// **Same `(category, name)` case-folded, *and* the same prose.** Not name
// alone: L1 measured 1,643 built-in name collisions of which **1,636 say
// something different** — A5E and Black Flag restat the SRD, so a name-only
// rule would delete the A5E *Fireball* a user installed *Adventurer's Guide*
// to get. Name-only was considered and rejected on that measurement; wanting it
// anyway is a policy change to the audit doc §2.5, not a bug fix.
//
// Two further rules, both of which exist because their absence manufactures
// evidence:
//
//  * **empty text is never a match.** A `monster` carries its content in
//    `attributes`, not in a description, so "both blank" is absence of
//    evidence. [builtinSameCard] requires non-empty prose on both sides.
//  * **no qualifier stripping.** The trailing parenthetical is usually the
//    mechanic ("Legendary Resistance (3/Day)") or `_ensureChild`'s
//    disambiguator ("Scimitar (Firetamer)"); stripping it would declare 3,501
//    qualified statblock rows duplicates of built-in cards they do not
//    duplicate.
//
// ## Which direction a duplicate may be dropped — decided by L4, 2026-08-15
//
// **Toward the built-in pack only.** The built-in SRD 5.2.1 Core pack is in
// scope for every world, package and character *implicitly* (audit §2.1), so a
// card it already ships verbatim can be dropped and every pointer re-aimed at
// it for free: nothing extra is installed, downloaded or declared.
//
// A card two *bundled* packs share is a different question with the opposite
// answer, and it is answered by measurement rather than preference — see
// [kBundledSharedPolicy].
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';

import 'gate.dart' show nameKey;
import 'refgraph.dart' show PackBuilder;

/// Why a card shared by two bundled packs is **kept in both** (audit L4).
///
/// The candidate set was 189 names / 193 copies whose copies are textually
/// identical. Measured on the promoted assets, **188 of the 189 are
/// monster-owned children** and they fall into exactly two pack pairs:
/// `open5e-tob` ⟷ `open5e-tob-2023` (174 — one book and its 2023 reprint) and
/// `open5e-a5e-mm` ⟷ `open5e-bfrd` (13 — two systems restating the same SRD
/// creature). The 189th is `language` "Void Speech" in 6 packs, which L2
/// already priced and kept.
///
/// Each of those copies is a *different statblock's* internals: "Bite
/// (Amphiptere)" in `tob` belongs to `tob`'s Amphiptere and the one in
/// `tob-2023` to `tob-2023`'s. Electing one owner and pointing the loser's
/// monster at it would make that monster's bite disappear whenever the owning
/// pack is not installed — a broken statblock, which is strictly worse than a
/// duplicate child row that no picker even lists. It is L2's transitive-install
/// price again (2.9 MB of Tome of Beasts for a one-row card) with a sharper
/// edge: here the cost is content, not bytes.
///
/// So L4's open "which pack owns it" question resolves to **nobody has to** —
/// the set that would need an owner is empty. The alphabetical-slug tiebreak
/// L4 floated is deliberately *not* implemented, because implementing it would
/// mean shipping the defect above.
const kBundledSharedPolicy =
    'bundled↔bundled duplicates are kept in both packs (audit L4); only '
    'built-in duplicates are dropped';

/// Comparison form for description prose: whitespace collapsed, ends trimmed,
/// case preserved (a case edit in a rules sentence is a real edit).
String normText(String? s) =>
    (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Description as the app would show it: the top-level wire key, falling back
/// to `attributes.description` (the importer writes both; hand-authored SRD
/// cards sometimes only carry one).
String cardText(Map row) {
  final top = normText(row['description'] as String?);
  if (top.isNotEmpty) return top;
  final attrs = row['attributes'];
  if (attrs is Map) return normText(attrs['description'] as String?);
  return '';
}

/// Identity key for duplicate detection: `(slug, lowercased name)`.
///
/// Case is folded because the importer title-cases and a case variant is still
/// the same card. This is **not** the runtime's key — [nameKey] is — and the
/// difference is deliberate; see the header.
String identityKey(String slug, String name) =>
    nameKey(slug, name.toLowerCase());

/// One card the built-in pack ships, under its own canonical name.
class BuiltinCard {
  const BuiltinCard(this.slug, this.name, this.text);

  final String slug;

  /// The built-in's spelling, which is what a retargeted soft ref must use —
  /// `findEntityIdByName` is case-sensitive.
  final String name;

  final String text;
}

/// Every card the built-in pack puts in scope, keyed by [identityKey].
///
/// Tier-0 seed rows from the schema builder plus the Tier-1 hand-authored SRD
/// catalog; both are pure Dart, so this needs no database and no Flutter
/// binding. First writer wins, matching `_nameIndexFor`.
Map<String, BuiltinCard> builtinCardIndex() {
  final out = <String, BuiltinCard>{};
  generateBuiltinDnd5eV2Schema().seedRows.forEach((slug, rows) {
    for (final row in rows) {
      final name = (row['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      out.putIfAbsent(
        identityKey(slug, name),
        () => BuiltinCard(slug, name, normText(row['description'] as String?)),
      );
    }
  });
  for (final raw in buildSrdCorePack().entities.values) {
    if (raw is! Map) continue;
    final slug = (raw['type'] as String?)?.trim() ?? '';
    final name = (raw['name'] as String?)?.trim() ?? '';
    if (slug.isEmpty || name.isEmpty) continue;
    out.putIfAbsent(
      identityKey(slug, name),
      () => BuiltinCard(slug, name, cardText(raw)),
    );
  }
  return out;
}

/// The built-in card this row is a verbatim copy of, or null.
///
/// Both texts must be non-empty and equal after [normText]. A blank-vs-blank
/// pair is absence of evidence, never a match.
BuiltinCard? builtinSameCard(
  Map<String, BuiltinCard> index,
  String slug,
  String name,
  String text,
) {
  if (text.isEmpty) return null;
  final hit = index[identityKey(slug, name)];
  if (hit == null || hit.text.isEmpty) return null;
  return hit.text == text ? hit : null;
}

// ── The drop, applied at build time ───────────────────────────────────────

/// What [dropBuiltinDuplicates] did to one pack.
class DropReport {
  DropReport(this.dropped, this.retargeted);

  /// `"<slug> <name> → <builtin slug> <builtin name>"`, one per removed card.
  final List<String> dropped;

  /// How many `_ref` placeholders were re-aimed at the built-in card.
  ///
  /// Deleting is only half of the phase: a dropped card that anything points
  /// at must leave a **soft ref by name** behind, never a hard ref to an id
  /// that no longer exists. The rule of thumb L4 states is that the reference
  /// *count* before and after must match and only the target changes — so this
  /// number is the evidence for the half a `dupe_census` entity count cannot
  /// show.
  final int retargeted;

  bool get isEmpty => dropped.isEmpty;
}

/// Remove every card in [pack] that the built-in pack already ships verbatim,
/// re-aiming each pointer at the built-in card as a soft ref (audit **L4**).
///
/// Call it after mapping and **before** `PackBuilder.resolveRefs`: the drop
/// invalidates the `_ref` index entry, so retargeting has to happen while the
/// placeholders are still placeholders. Afterwards there is nothing left to
/// re-aim — the refs are uuids and the information about what they meant is
/// gone.
///
/// Only the built-in direction is dropped; see [kBundledSharedPolicy].
DropReport dropBuiltinDuplicates(
  PackBuilder pack,
  Map<String, BuiltinCard> builtin,
) {
  final drops = <String, BuiltinCard>{};
  final dropIds = <String>[];
  final dropped = <String>[];

  pack.entities.forEach((id, raw) {
    if (raw is! Map) return;
    final slug = raw['type'];
    final name = raw['name'];
    if (slug is! String || name is! String) return;
    final hit = builtinSameCard(builtin, slug, name, cardText(raw));
    if (hit == null) return;
    drops[identityKey(slug, name)] = hit;
    dropIds.add(id);
    dropped.add('$slug "$name" → ${hit.slug} "${hit.name}"');
  });
  if (dropIds.isEmpty) return DropReport(const [], 0);

  for (final id in dropIds) {
    pack.remove(id);
  }

  var retargeted = 0;
  Object? retarget(Object? node) {
    if (node is List) return [for (final v in node) retarget(v)];
    if (node is! Map) return node;
    final ref = node['_ref'];
    final name = node['name'];
    if (ref is String && name is String) {
      final hit = drops[identityKey(ref, name)];
      if (hit != null) {
        retargeted++;
        // A soft ref, under the built-in's own spelling: `findEntityIdByName`
        // is case-sensitive, so echoing the pack's casing could dangle.
        return <String, String>{'slug': hit.slug, 'name': hit.name};
      }
      return node;
    }
    return {
      for (final e in node.entries) e.key.toString(): retarget(e.value),
    };
  }

  for (final raw in pack.entities.values) {
    if (raw is! Map) continue;
    final attrs = raw['attributes'];
    if (attrs is Map) {
      raw['attributes'] = retarget(Map<String, dynamic>.from(attrs));
    }
  }

  dropped.sort();
  return DropReport(dropped, retargeted);
}
