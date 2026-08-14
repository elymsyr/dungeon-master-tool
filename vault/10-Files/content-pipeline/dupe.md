---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/dupe.dart
layer: tool
language: dart
status: stable
updated: 2026-08-15
tags: [file]
---

# `dupe.dart`

> [!abstract] Primary Purpose
> **The single definition of "the same card"**, plus the build-time drop that acts on it (audit phase **L4**). Created 2026-08-15 because the two sides that need this definition could not share it: [[dupe_census]] held the text comparison in a private function inside an 835-line `bin/` script, while [[build_packs]] can only reach the shared modules. A phase whose exit criterion *is* a census number cannot afford two notions of the number — the build would have gone green while shipping something else. Both sides now import this.

## Inputs / Outputs
**Inputs**
- The built-in pack, read purely: `generateBuiltinDnd5eV2Schema().seedRows` + `buildSrdCorePack()` (no DB, no Flutter binding, no source snapshot).
- A [[refgraph|PackBuilder]] mid-build, for `dropBuiltinDuplicates`.

**Outputs**
- `String normText(String?)` — whitespace collapsed, ends trimmed, **case preserved** (a case edit in a rules sentence is a real edit).
- `String cardText(Map row)` — description as the app shows it: top-level wire key, falling back to `attributes.description`.
- `String identityKey(slug, name)` — `(slug, lowercased name)`. **Not** the runtime key (`nameKey` in [[gate_packs]]) — the difference is deliberate.
- `class BuiltinCard { slug, name, text }` + `Map<String, BuiltinCard> builtinCardIndex()`.
- `BuiltinCard? builtinSameCard(index, slug, name, text)` — the match test.
- `DropReport dropBuiltinDuplicates(PackBuilder, index)` — the drop + retarget.
- `const kBundledSharedPolicy` — the recorded reason bundled↔bundled duplicates are *kept*.

## Key Logic

**What counts as the same card: same `(category, name)` case-folded AND the same prose.** Never name alone — L1 measured that of 1,643 built-in name collisions **1,636 say something different** (A5E and Black Flag restat the SRD), so a name-only rule would delete the A5E *Fireball* a user installed *Adventurer's Guide* to get. Two guards exist because their absence manufactures evidence:

- **empty text is never a match.** A `monster` carries its content in `attributes`, so "both blank" is absence of evidence.
- **no qualifier stripping.** The trailing parenthetical is usually the mechanic ("Legendary Resistance (3/Day)") or `_ensureChild`'s disambiguator ("Scimitar (Firetamer)"); stripping would declare 3,501 qualified statblock rows duplicates.

**Which direction a duplicate may be dropped — the asymmetry is the whole rule.**

- **Toward the built-in pack → drop.** It is in scope for every world, package and character implicitly ([[Package-Links]], audit §2.1), so removing a verbatim copy and re-aiming its pointers costs nothing: no install, no download, no declaration.
- **Toward another bundled pack → keep, in both.** A link makes the target a transitive install dependency. Measured on the promoted assets, **188 of the 189 textually-identical shared names are monster-owned children** (174 `open5e-tob` ⟷ `open5e-tob-2023`, 13 `open5e-a5e-mm` ⟷ `open5e-bfrd`), each belonging to a *different* statblock, and the 189th is L2's `Void Speech`. Electing an owner would delete a monster's own bite whenever the owning pack is absent — L2's price with the cost paid in content rather than megabytes. So there is **no per-name winner list, because no name is contested**, and the alphabetical-slug tiebreak the phase floated is deliberately unimplemented. `kBundledSharedPolicy` says so at the point a future rebuild would reach for it.

**`dropBuiltinDuplicates` runs on the emit side, after mapping and strictly before [[refgraph]]'s pass 2.** Order is not a preference: the drop deletes the row's `_ref` index entry, so any placeholder still aimed at it makes pass 2 report an unresolved ref and [[build_packs]] exit 1. That is a feature — **the retarget is structurally forced, not merely tested** (verified by mutation: disabling the rewrite fails the build with the same 15 refs it would have rewritten). Each placeholder becomes a soft ref `{slug, name}` under the **built-in's own spelling**, because `findEntityIdByName` is case-sensitive and echoing the pack's casing is how L3 shipped `"Spare The Dying"` against a corpus spelling it `"Spare the Dying"`.

**Measured result (2026-08-15, pinned snapshot `d4276c58`):** 7 cards dropped (3 `creature-action`, 4 `trait`, all monster-owned children in `open5e-a5e-mm` / `open5e-bfrd`), 15 refs retargeted. `dupe_census` section A "same text" **7 → 0**; section C **4,059 → 4,074 refs, 0 dangling** — the rise *is* the retarget, and the exit's "the total may not drop" is what proves nothing silently became empty.

## Dependencies & Links
- Imports [[gate_packs]] (`nameKey`) and [[refgraph]] (`PackBuilder`).
- Imported by [[build_packs]] (the drop) and [[dupe_census]] (the comparison + `--list-builtin-same`, which prints the drop set so it can be read rather than inferred from a count).
- Reads [[builtin_schema]] + [[srd-pack-content]].
- Pinned by `test/tool/builtin_dupe_drop_test.dart` — 7 cases: the four unit rules above, plus the two the audit's L4 exit named (two packs that both shipped *Nimble Escape* list it exactly once, and **Blink Dog**'s `bonus_action_refs` resolve the same count with the teleport now landing on the built-in card).
- Audit: `flutter_app/docs/open5e_content_audit.md` §2.5 · §3.2 · §6 L4.
- MoC: [[Content-Pipeline]].
