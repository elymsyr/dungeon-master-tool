---
type: file-note
domain: chargen
path: flutter_app/lib/application/character_creation/caster_progression.dart
layer: application
language: dart
status: stable
updated: 2026-08-19
tags: [file]
---

# `caster_progression.dart`

> [!abstract] Primary Purpose
> Pure, Flutter-free D&D 5e caster-progression helpers. Derives spell-related caps (cantrips known, prepared/known count, max preparable spell level) and spell-slot maps from a class entity's `caster_kind`, falling back to embedded SRD §1.5 slot tables when the class entity's per-level tables aren't populated. Wired into the wizard's Spells step and the level-up planner.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none — top-level functions + the `CasterKind` enum.
- Reads: caller-supplied `Entity? cls` (reads `caster_kind`, `spell_slots_by_level`, `cantrips_known_by_level`, `prepared_spells_by_level`) and an `int level`.
- Supabase / CDC / events / triggers: none.

**Outputs**
- Public API: `CasterKind` enum (`none/full/half/third/pact`), `parseCasterKind`, `levelTableValue`, `defaultCantripsKnown`, `defaultPreparedSpells`, `maxPreparableSpellLevel`, `slotsByLevelOverride`, `spellSlotsForClass` (optional `subclass:`), `defaultSpellSlotsByLevel`, `effectiveCasterKind` (**R5**).

## Dependencies & Links
- Depends on: `entity.dart` only.
- Used by: [[level_up_planner]], [[multiclass_helper]] (`combinedCasterLevel` calls `defaultSpellSlotsByLevel(CasterKind.full,...)`), the wizard Spells step.
- Domain map: [[Character-System]]
- System flow: [[Grant-Resolution]]
- Spec / reference: [[SRD-5.2.1]] §1.5

## Key Logic / Variables
- `effectiveCasterKind(cls, subclass)` (**R5 / F-pass0-08's sibling F-pass0-10**): the subclass wins **only when it names a caster kind other than None** — a 2014-shaped archetype (Arcane Warrior, Eldritch Trickster, Soulspy, Underfoot) casts although its class declares `None`, while an absent or `None` subclass value must never downgrade a Cleric. Every caster-kind reader outside the entity editor goes through it: [[level_up_planner]], the wizard's Spells step, its spell validation, the commit-time `spell_slots` seed and the review step. Before R5 `CasterKind.third` was unreachable: the only reader was the class card.
- `parseCasterKind`: maps the schema enum strings `'Full'/'Half'/'Third'/'Pact'` to `CasterKind`; anything else (incl. 'None'/'Ritual') → `none`.
- `levelTableValue(raw, level)`: reads an `int` out of a `Map<int,int>`-shaped (JSON-stringified keys tolerated) per-level table; null on miss so callers fall back to defaults.
- `defaultCantripsKnown`: full → 3/4/5 (by <4/<10/else); pact → 2/3/4; half/third/none → 0.
- `defaultPreparedSpells`: full = `level+3`; half = `floor(level/2)+1` from L2; third = `(level-2)~/2+1` from L3; pact = `(level+1)~/2+1`; none = 0.
- `maxPreparableSpellLevel`: full `floor((level+1)/2)` clamp 1-9; half clamp 1-5 from L2; third clamp 1-4 from L3; pact clamp 1-5; none 0.
- Embedded SRD slot tables (`const`, indexed by `level-1`): `_fullCasterSlots` (20×9), `_halfCasterSlots` (20×5), `_thirdCasterSlots` (20×4), `_pactSlots` (20×`[count, slotLevel]` — all pact slots share one level and recharge on a **short** rest).
- `slotsByLevelOverride`: reads an author override `spell_slots_by_level` (`Map<level, Map<spellLevel, count>>`, stringified keys); returns null when absent/malformed/no row; empty map distinguishes "override says zero" from "no override".
- `spellSlotsForClass(cls, level)`: override first, else `defaultSpellSlotsByLevel(parseCasterKind(...))`. `defaultSpellSlotsByLevel` returns `{spellLevel: count}` (zeros sparse-omitted); pact returns a single `{slotLevel: count}` entry.

## Notes
- Default cantrip/prepared curves are deliberately approximate "middle" values when the class entity has nothing populated; the UI surfaces a "populate the class table for exact counts" hint.
- **Audit T2-2 (2026-08-14) — division of labour, now data-backed.** The 12 built-in classes ship their own `cantrips_known_by_level` / `prepared_spells_by_level` (and Paladin/Ranger `spell_slots_by_level`), harvested from the pinned snapshot's `srd-2024/ClassFeatureItem.json` into `srd_core/classes.dart`, so the approximate curves above no longer decide anything for SRD content — they remain the fallback for packaged classes only. The slot tables here were checked cell for cell against that same source: `_fullCasterSlots` and `_pactSlots` agree on all 20 levels (so nothing duplicates them in data), `_halfCasterSlots` agrees at levels 2–20 and differs at **level 1** — SRD 5.2.1 gives Paladin/Ranger 2 first-level slots, the 2014-shaped preset gives none. The preset is deliberately left 2014-shaped because every bundled Open5e pack is `game_system: 5e-2014`; the edition difference is stated in the built-in pack's data instead. Pinned by `test/domain/srd_core_spellcasting_tables_test.dart`.

- **Audit M4 (2026-08-15) — bu dosya "sayfaya iniyor mu" sorusunun cevaplandığı yer.** `spell_slots_by_level` / `cantrips_known_by_level` / `prepared_spells_by_level` `CharacterResolver`'a hiç uğramaz; `spellSlotsForClass` yalnız **iki** noktadan çağrılır — `character_creation_wizard_screen`'in commit'i ve seviye atlama diyaloğunun apply'ı — ve sonuç karakterin kendi `spell_slots` alanına yazılır. Bu **tasarım**: alan DM tarafından düzenlenebilir bir pip ızgarası, resolver'da yeniden hesaplamak elle girilen max/remaining değerlerini her okumada ezerdi. Bilinen boşluk: `class_levels`'ı diyalog dışında elle yükseltmek ızgarayı uyarısızca bayat bırakır. `test/application/character_creation/spell_slot_grid_reach_test.dart` şunları pinler: 8 gömülü büyücü sınıfının hepsi ızgara üretir; yazılmış tablo preset'i yener (Paladin/Ranger L1 `{1: 2}`, preset boş); paketlerde **0 büyücü sınıf** vardır (19 pakette 2 sınıf kartı, ikisi de kaynakta `caster_type: NONE`) — bir paket büyücü gönderdiği gün test düşer.
