# System Mechanics Roadmap — Official Package Support

> Automated System Architecture Inspector — development roadmap derived from a
> full audit of the official first-party catalog (19 Open5e packs · 20,712
> cards) and the built-in SRD 5.2.1 core (~2,260 cards). Per-entity evidence:
> [`entity_audit_log.md`](entity_audit_log.md). Branch: `list`. Generated
> 2026-06-10.

## How to read this

Each item is a **global deficiency** — a missing system-wide mechanic, rule, or
dedicated data field — that blocks the official packages from being fully
supported. Findings are split into:

- **System-level gaps** — the runtime/schema genuinely cannot express or enforce
  the rule. These need engineering in the resolver, schema, or UI.
- **Content-pipeline gaps** — the schema *already supports* the structure (the
  SRD core uses it), but the Open5e importer leaves the data in a generic text
  field. These need work in `flutter_app/tool/open5e_import/` (mappers).

Anchor files: schema `flutter_app/lib/domain/entities/schema/builtin/content.dart`;
resolver `flutter_app/lib/domain/services/character_resolver.dart`; picker/UI
`flutter_app/lib/presentation/screens/characters/pending_choice_resolver_dialog.dart`;
importer `flutter_app/tool/open5e_import/`.

---

## Priority 1 — System-level gaps (runtime cannot enforce/resolve)

### 1.1 Feat prerequisites are never validated at apply-time
**Symptom.** Every feat prerequisite field — `prereq_ability_ref` +
`prereq_min_score`, `prereq_min_character_level`, `prereq_requires_spellcasting`,
`prereq_class_refs`, `prereq_species_refs`, and the advanced `prereq_clauses`
DSL — is read **only** by the feat-picker dialog to *filter the list*
(`pending_choice_resolver_dialog.dart` ~L505–526). The character resolver
applies a feat with **zero validation** (`character_resolver.dart`, feat pass
~L677–732). Any character assembled outside the happy-path picker (imported
JSON, programmatic build, sync from another client, a retro-active stat change
that invalidates a prereq) keeps a feat it no longer qualifies for, silently.

**What the architecture needs.**
- A shared **prerequisite evaluator** (pure function over the resolving
  `EffectiveCharacter`) used by *both* the picker filter and the resolver, so
  the two can never diverge.
- The resolver should **emit a validation diagnostic** (warning row on
  `EffectiveCharacter`) rather than silently apply, when a granted feat's
  prereq is unmet — leaving GM override possible but visible.
- Add the missing **prereq field types** the official content needs but the
  schema cannot express (see 1.2).

**Affected official content.** 73 feats; 27 carry an explicit prerequisite.

### 1.2 Missing prerequisite field types (proficiency / feat / trait / size / "other")
**Symptom.** 5 official feats state a prerequisite that has **no structured
field at all**, so it is stranded in free text and can never be enforced:
- *Ace Driver* — "Proficiency with a type of vehicle"
- *Stunning Sniper* — "Proficiency with a ranged weapon"
- *Giant Foe* — "A Small or smaller race"
- *Harrier* — "Shadow Traveler trait OR ability to cast *misty step*"
- *Well-Heeled* — "Prestige rating of 2 or higher" (system-specific resource)

The schema has `prereq_ability_ref`, `prereq_class_refs`, `prereq_species_refs`,
`prereq_min_character_level`, `prereq_requires_spellcasting`, but **no**
`prereq_proficiency_ref`, `prereq_feat_ref`, `prereq_trait_ref`,
`prereq_size_ref`, or a generic `prereq_spell_castable_ref`.

**What the architecture needs.** Extend the feat-prereq schema (and the
`prereq_clauses` DSL grammar) with proficiency / feat / trait / size / spell-
castable predicates, and teach the evaluator from 1.1 to resolve them against
the character's granted proficiencies, feats, traits, size and known spells.

### 1.3 No spell-effect resolution engine
**Symptom.** Spells are richly typed for *casting metadata* (level, school,
range, components, save ability, concentration, ritual) but the
**`effects` / `spellEffectList` field is empty for all 1,297 official spells**,
and the resolver never reads spell effects at all. Damage dice, scaling
("At Higher Levels"), saving-throw outcomes (half / negate), and applied
conditions live entirely in `description` markdown. The runtime knows *which*
spells a character has, not *what they do*.

**What the architecture needs.**
- A **structured spell-effect model** that is actually populated:
  `{kind: damage|heal|condition|buff|debuff, dice, damage_type_ref,
  save_ability_ref, save_effect, condition_refs, scaling}` per spell, plus
  upcast scaling rules.
- A **spell-effect resolver / casting engine** (combat-tracker side) that reads
  those rows to roll damage, apply saves, and surface conditions — the spell
  analogue of the existing `applyEffect()` switch used for feats/species.
- Importer support to emit the structured rows (see 2.3).

**Affected official content.** 1,297 spells across 8 packs.

### 1.4 Background language grants are authored but never consumed
**Symptom.** 24 official backgrounds set `granted_language_count` (e.g. Acolyte,
Noble, Soldier each `= 1`), but the resolver's background pass
(`character_resolver.dart` ~L865–905) **never reads the field** — no language
choice is surfaced and no language is added. The number is dead data.

**What the architecture needs.** A **"choose N languages" pending-choice** path
(parallel to the existing skill/tool/ASI pending choices) wired into the
background pass, plus resolver application of the chosen languages. It should
share one chooser with the species language grant.

### 1.5 No structured "feature" mechanic for backgrounds (and no enforced attunement-prereq)
**Symptom (background).** Unlike classes/subclasses, backgrounds have **no
`features` field**; the background's special feature (e.g. "Shelter of the
Faithful") exists only inside `description`. The 2024-style `origin_feat_ref` is
applied via the UI picker, not the resolver.

**Symptom (magic items).** Attunement *prerequisites* ("requires attunement by a
spellcaster / by a wizard") are stored only in text; `requires_attunement` is a
bare boolean with no enforced gate.

**What the architecture needs.** Either model background features as
auto-granted trait/feat entities (the SRD-core pattern) consistently across
imported content, or add a typed `features`/`rule_effects` field to the
background category. For magic items, add an optional structured
`attunement_prereq` (class/species/alignment/spellcasting predicate) reusing the
1.1 evaluator.

---

## Priority 2 — Content-pipeline gaps (schema supports it; importer does not populate it)

The SRD 5.2.1 core proves the schema already supports these structures. The
official Open5e packs fail the audit because the importer
(`flutter_app/tool/open5e_import/`, esp. the chargen mapper) drops the content
into a single text field instead of the typed fields.

### 2.1 Subclasses: 101/101 dump every feature into one `description` field
**Symptom.** Every one of the 101 imported subclasses carries **only**
`description` (commonly 2,000–9,300 characters) + `parent_class_ref`. The
schema's structured `features` rows, `rule_effects`, `granted_at_level`, and
grant lists (`granted_action_refs` / `granted_trait_refs` / `granted_feat_refs`
/ `granted_reaction_refs`) — all used by `srd_core/subclasses.dart` and applied
by the resolver — are **entirely unused**. Result: no per-level subclass feature
is mechanically applied; the wizard / level-up walker has nothing to absorb.

**What the architecture needs.** A subclass mapper that **parses the feature
table out of the source text into per-level `features` rows**, emitting grant
refs for the mechanical pieces (auto-granted traits/feats/actions) so the
resolver's feature-absorption passes (`absorbFeatureRows*`) can apply them. This
is the single highest-volume data-structure defect in the catalog.

### 2.2 Feats: 64/73 carry their benefits as `description` text only
**Symptom.** Only 9 official feats populate the structured `effects` list; the
other 64 describe their benefits (expertise dice, AC bonuses, extra reactions,
movement, etc.) purely in `description`. The feat-effect engine
(`applyEffect()` switch with 50+ effect kinds) is fully capable of applying many
of them, but the data is not mapped.

**What the architecture needs.** Importer mapping of common feat benefit phrases
to typed `effects` rows, and (for benefits the engine cannot yet represent — new
action grants, conditional triggers) either new effect kinds or an
`auto_granted_by` trait/action entity. Flag the residue that genuinely needs new
effect kinds.

### 2.3 Spells: importer emits no structured effect rows
**Symptom.** Complementary to 1.3 — even once the resolver exists, the importer
currently emits `damage_type_refs` / `save_ability_ref` / `attack_type` but no
`effects` rows with dice and scaling.

**What the architecture needs.** Extend the spell mapper to extract damage dice,
"At Higher Levels" scaling, and rider conditions into the structured
spell-effect model from 1.3.

### 2.4 Classes & residual species/subspecies text
**Symptom.** The 2 imported classes (Marshal, Mechanist) have typed
proficiencies/hit-die/caster fields but **no structured per-level `features`
list** — features in `description`. A handful of species/subspecies (Shade,
Dwarf Chassis, Human Chassis, Human/Half-Elf Heritage) leave their traits in
`description` rather than `granted_*` fields.

**What the architecture needs.** Same feature-table parsing as 2.1 applied to
the class mapper; complete the `granted_*` mapping for the few species/subspecies
that fell back to text.

---

## Priority 3 — Cross-cutting / validation infrastructure

- **Importer audit gate.** Add a CI check in the import pipeline that **fails or
  warns** when a chargen entity (feat/background/subclass/class) is emitted with
  a non-empty prerequisite-or-feature `description` but empty structured fields —
  turning the defects in Part A of the ledger into build-time signal so they
  cannot silently reappear.
- **Single prerequisite/predicate evaluator** (from 1.1/1.2) reused by the feat
  picker, the resolver, magic-item attunement, and `prereq_clauses` — one DSL,
  one evaluator, no UI/runtime drift.
- **Resolver diagnostics surface.** A first-class "unmet requirement / unapplied
  mechanic" warning channel on `EffectiveCharacter` so unenforced prereqs and
  text-only mechanics are visible to the GM instead of silently ignored.

---

## Summary table

| # | Deficiency | Type | Affected official cards |
|---|---|---|---|
| 1.1 | Feat prereqs not validated at apply-time | System | 73 feats (27 w/ prereq) |
| 1.2 | Missing prereq field types (proficiency/feat/trait/size/spell) | System (schema) | 5 feats (free-text prereq) |
| 1.3 | No spell-effect resolution engine | System | 1,297 spells |
| 1.4 | Background `granted_language_count` never consumed | System | 24 backgrounds |
| 1.5 | No background-feature field; attunement-prereq unenforced | System | 53 bg + 1,063 items |
| 2.1 | Subclass features dumped in one text field | Pipeline | 101 subclasses |
| 2.2 | Feat benefits as text, not `effects` | Pipeline | 64 feats |
| 2.3 | Spell `effects` rows not emitted | Pipeline | 1,297 spells |
| 2.4 | Class/residual species features in text | Pipeline | 2 classes + 5 species/subspecies |
| 3 | Importer audit gate · unified evaluator · resolver diagnostics | Infra | system-wide |

See [`entity_audit_log.md`](entity_audit_log.md) for the card-by-card ledger
backing every row above.
