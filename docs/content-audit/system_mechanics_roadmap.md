# System Mechanics Roadmap — Official Package Support

> Automated System Architecture Inspector — development roadmap derived from a
> full audit of every official first-party package (**19 Open5e packs ·
> 20,712 entity cards**) plus the built-in hand-authored **SRD 5.2.1 core**.
> Per-entity evidence: [`entity_audit_log.md`](entity_audit_log.md).
> Branch: `list`. Generated 2026-06-10.

## How to read this

Each item below is a **global deficiency** — a missing system-wide mechanic,
validation rule, or dedicated data field — that prevents the official packages
from being fully supported. Two kinds of gap are distinguished:

- **System-level gaps** — the runtime/resolver/schema cannot *express* or
  *enforce* the rule no matter how clean the data is. These need engineering.
- **Content-pipeline gaps** — the schema **already supports** the structure
  (the hand-authored SRD core populates it), but the Open5e importer leaves the
  data folded into a generic text field. These need importer/source work.

The distinction matters: the SRD core is the structural gold standard. It was
verified during this audit that the SRD subclass builder emits
`granted_at_level` + typed `features`, and the SRD feat builders emit typed
`effects`/`prereq_min_score`/`granted_modifiers`. The schema can hold all of it.
The official Open5e packs simply do not fill those fields.

**Anchor files**
- Schema: `flutter_app/lib/domain/entities/schema/builtin/content.dart`
- Resolver: `flutter_app/lib/domain/services/character_resolver.dart`
- Picker/validation UI: `flutter_app/lib/presentation/screens/characters/pending_choice_resolver_dialog.dart`
- Importer: `flutter_app/tool/open5e_import/mappers/` (`chargen.dart`, `item.dart`, `spell.dart`, `monster.dart`)
- SRD reference: `flutter_app/lib/domain/entities/schema/builtin/srd_core/`

---

## Priority 1 — System-level gaps (runtime cannot enforce/resolve)

### 1.1 Feat & magic-item prerequisites are never validated at apply-time
**Symptom.** Every typed prerequisite the schema declares for a feat —
`prereq_ability_ref` + `prereq_min_score`, `prereq_min_character_level`,
`prereq_requires_spellcasting`, `prereq_class_refs`, `prereq_species_refs` — is
read **only** by the feat-picker dialog to *filter the candidate list*
(`pending_choice_resolver_dialog.dart` ~L501–544). The character resolver
(`character_resolver.dart`) contains **no prerequisite check whatsoever** (the
feat pass, ~L662–763, applies feats with zero validation). Any character
assembled outside the happy-path picker (imported JSON, programmatic build, sync
from another client, or a retroactive ability-score edit that invalidates an
already-taken feat) keeps a feat it no longer qualifies for, silently. The same
is true of magic-item attunement restrictions ("requires attunement by a
spellcaster / by a creature of evil alignment" — 35 such items in *Vault of
Magic* alone): `requires_attunement` is a bare boolean; the *who-may-attune*
clause lives only in prose and is never checked.

**Evidence.** 27/73 official feats carry prerequisite text; 22 carry structured
prereq data — but 0 of those are enforced when the feat is applied.

**Architecture change.** Add a `validatePrerequisites(character, entity)` pass
to `CharacterResolver` that runs on every assemble (not just the picker), emits
a typed list of unmet-prerequisite warnings onto the resolved character, and is
surfaced on the sheet. Magic-item attunement needs a typed
`attunement_requirement` field (ability/class/species/alignment clause) the same
pass can read.

### 1.2 `prereq_clauses` is an undeclared attribute key (schema-integrity hole)
**Symptom.** The importer emits a rich ALL-of `prereq_clauses` list
(`chargen.dart` ~L425–526) and the picker dialog consumes it
(`pending_choice_resolver_dialog.dart` L505), but the feat category schema in
`content.dart` (`_featCategory`, L599–668) **does not declare a `prereq_clauses`
field** — only the flat `prereq_*` fields. 22 official feats ship a
`prereq_clauses` attribute that no schema field describes.

**Architecture change.** Declare `prereq_clauses` (a typed clause-list field) in
`_featCategory` so attribute-key integrity holds and the editor can render/edit
it. Then have the resolver (not just the dialog) evaluate it as part of 1.1.

### 1.3 No mechanical layer for class / subclass level-features
**Symptom.** The schema supports `class.features` and `subclass.features`
(level-keyed typed feature lists) plus `subclass.granted_at_level`, and the SRD
core populates them. The official packs do not: **all 101 official subclasses
carry only `description` + `parent_class_ref`** (0 features, 0
`granted_at_level`, 0 `rule_effects`), and **both official base classes**
(*Marshal*, *Mechanist*) carry no `features` map. So a character taking any
official subclass receives **zero** mechanical grants — every feature is inert
prose. The resolver's subclass pass (`character_resolver.dart` ~L981–990) reads
`saving_throw_refs`/`weapon_proficiency_categories`/`armor_training_refs`/
`rule_effects` from the subclass — none of which official subclasses populate.

**Architecture change (system side).** Primarily a pipeline gap (2.2), but the
runtime also needs: a level-feature scheduler in the resolver that applies
`features[].rule_effects` at the correct character level, and a "feature not yet
mechanized" placeholder state so the sheet can render the prose feature while
flagging it unenforced. `subclass.granted_at_level` is schema-`required` yet
absent on all 101 cards — the resolver currently tolerates the null; it should
record it as a data-integrity warning rather than silently defaulting.

### 1.4 No "constrained choice" resolution for imported content
**Symptom.** Official backgrounds list `ability_score_options` as **all six
abilities** (see *Acolyte*) even when the prose says "+1 Wisdom and one other,"
because the importer cannot parse the constrained choice. There is no typed
representation of the "+2/+1 vs +1/+1/+1" distribution for any official
background (`asi_distribution_options` populated on **0/53**). Combined with the
resolver's background ASI pass (~L878–885) reading a free `background_asi` pick
map, the distribution rule is enforced only by wizard UI convention, never by
data.

**Architecture change.** A first-class "constrained choice" descriptor
(pick-N-of-set, with per-option amount) usable by background ASI, species ASI,
skill-of-your-choice grants, and feat ASI alike — so "one other ability of your
choice" round-trips as data instead of degrading to "all six."

---

## Priority 2 — Content-pipeline gaps (schema supports it; importer leaves text)

These do **not** need schema or resolver changes — the SRD core already
exercises the same fields. They need work in `tool/open5e_import/mappers/`
and/or richer upstream Open5e source data. The importer header (`chargen.dart`
L19–22) is candid about this: *"Honest source limits (left empty, not faked):
leveled class `features`/subclass `granted_at_level` …, feat effect/ASI DSL, and
any 'of your choice' grant — all stay folded in the description."*

### 2.1 Feat benefits left in prose (no typed `effects`)
**64 of 73 official feats** have their entire mechanical benefit in
`description`, with no typed `effects` and no `granted_modifiers`. Only 9 feats
(Crafting Expert, Lightly/Moderately/Heavily Outfitted, Natural Warrior, Shield
Focus, Skillful, Skirmisher, Swift Combatant) are mechanized. The resolver's
feat pass reads `effects`/`granted_modifiers`/`asi_*`; for the other 64 it
applies nothing.

### 2.2 Subclass & class features left in prose
See 1.3 — all 101 subclasses and both base classes ship feature text only. This
is the single largest chargen content-pipeline deficit by card count.

### 2.3 Backgrounds missing typed grants
Across 53 official backgrounds: `origin_feat_ref` **0/53** (schema-`required`),
`asi_distribution_options` **0/53** (schema-`required`), `starting_gold_gp`
**0/53**, `default_inventory_refs` **0/53**, `rule_effects` **0/53**. Two
backgrounds (*Fate-Touched*, *Guildmember*) additionally lack
`granted_skill_refs`; 26/53 lack `ability_score_options`. Equipment choice
groups (52/53) and granted skills (51/53) are otherwise well-populated.

### 2.4 Monster traits encode mechanics as pure text
All **6,423 official `trait` cards** carry only `description` + `source` +
`trait_kind`. Traits that are mechanically load-bearing (damage-resistance
bundles, regeneration, *Magic Resistance*, *Pack Tactics*, *Sunlight
Sensitivity*) are indistinguishable from flavor traits — there is no typed
effect, so a VTT/automation layer cannot act on them.

### 2.5 Species / subspecies partially mechanized
Of 11 official species, 4 lack `size_ref` and 3 lack `speed_ft` (*Darakhul*,
*Gearforged*, *Shade*); 2 carry no `granted_modifiers`. Of 30 subspecies the
grants are partial (e.g. `granted_cantrip_refs` on only 4/30). These should be
completable from source.

---

## Priority 3 — Data-structure hygiene

### 3.1 `description` duplicated into `attributes.description`
For feats (73/73 byte-identical), backgrounds, subclasses, species, spells,
traits and creature-actions, the top-level entity `description` is copied
**verbatim** into `attributes.description`. This doubles storage for 20k+ cards
and risks the two copies drifting after an edit. Pick one canonical home
(top-level `Entity.description`) and drop the mirror, or document the mirror's
purpose.

### 3.2 Monster `stat_block` raw text alongside typed fields
Every one of 2,885 monster cards carries a `stat_block` field *in addition to*
the full set of typed fields (ac, hp, speeds, saves, senses, action_refs, …).
If `stat_block` is a raw rendered dump it is redundant with the typed data and
carries the same drift risk as 3.1; if it is the authoritative source, the typed
fields risk going stale. Clarify which is canonical.

### 3.3 Constrained choices flattened to full sets
As in 1.4 / 2.3: "ability/skill/language of your choice" is imported as the full
option set rather than a "choose N" descriptor, erasing the constraint the prose
states. This is a structural loss, not just a missing field.

---

## Suggested sequencing

1. **1.2** (declare `prereq_clauses`) — small, unblocks integrity + editor.
2. **1.1** (apply-time prerequisite validation) — highest correctness payoff;
   covers feats and magic-item attunement.
3. **2.3 / 1.4** (background required fields + constrained-choice descriptor) —
   fixes two schema-`required` fields currently empty on all 53 cards.
4. **1.3 / 2.2** (subclass & class level-feature mechanization) — largest
   chargen win; needs both a resolver scheduler and importer/source work.
5. **2.1 / 2.4 / 2.5** (feat effects, trait effects, species completion) —
   incremental content mechanization.
6. **3.1–3.3** (hygiene) — opportunistic, low risk.
