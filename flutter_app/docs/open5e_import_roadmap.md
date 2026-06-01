# Open5e → Content Packages — Roadmap & Reference

**Status:** P0–P5 shipped — all v2 content built (22 packages: ~3,540 monsters,
~1,955 spells, ~2,319 magic items, 26 classes + 125 subclasses, 63 species, 58
backgrounds, 91 feats). Only P2 (marketplace publish) remains; user reviews the
content before any publish.
**Author tooling:** `flutter_app/tool/open5e_import/`
**Source data:** `open5e-api-staging/data/` (58 MB, read-only)

---

## 1. Overview & goals

The app already ships **SRD 5.2.1 as built-in content** (`srd_core` pack,
regenerated each launch). This initiative imports the much larger **Open5e**
dataset — thousands of monsters, spells, items, classes, species, backgrounds,
feats from many publishers — as **user-owned content packages** that can be made
online and published to the marketplace. Packages are *not* baked into the
built-in pack.

**Decisions (locked with the user):**

- **Sources:** maximal breadth — every source under `data/v1/**`, `data/v2/**`,
  `data/raw_sources/srd_5_2/**`. SRD docs become their own packages too but are
  excluded by default from marketplace publish (avoid duplicate listings).
- **Content types:** everything (monsters, spells, items, classes, subclasses,
  species, backgrounds, feats, equipment, conditions/rules).
- **Depth:** **stats + descriptive text** only — fill every stat field we can
  derive plus full description markdown. No typed effect/grant DSL.
  **Consequence:** imported classes/species/feats/backgrounds are *descriptive
  reference content*; they render in cards/editor but are **not** wired into
  level-up automation (`planLevelUp`, resolver grants). Monsters/spells/items
  are fully usable because they render purely from stat fields + text.
- **Media:** deferred. Per-package cover image only; no per-entity art upload.

**Built-in vs package:** a package is a `Packages` row + `PackageSchemas` +
`PackageEntities`. Built-in SRD uses `srdStableEntityId` + a guarded read-only
repo path; Open5e packs are ordinary personal packages (mutable, shareable,
publishable). They reuse the same wire format and the built-in v2 schema.

---

## 2. Source inventory

Two API snapshots coexist:

- **v1** — Django fixtures, denormalized. Monster actions/traits embedded as
  JSON-string fields (`actions_json`, `legendary_actions_json`). Split by source
  folder (`v1/wotc-srd`, `v1/tob`, `v1/cc`, `v1/menagerie`, …).
- **v2** — normalized. `Creature.json` + separate `CreatureAction.json`,
  `CreatureActionAttack.json`, `CreatureTrait.json` joined by `parent` slug;
  clean enums under `v2/open5e/core/`. Split by publisher/document.

**Publishers / documents (v2):**

| Publisher | Documents | License |
|---|---|---|
| Wizards of the Coast | `srd-2014`, `srd-2024` | OGL 1.0a / CC-BY-4.0 |
| Kobold Press | `tob`, `tob2`, `tob3`, `tob-2023`, `toh`, `vom`, `ccdx`, `bfrd`, `kp`, `deepm`, `deepmx`, `wz` | OGL 1.0a |
| EN Publishing | `a5e-ag`, `a5e-ddg`, `a5e-gpg`, `a5e-mm` | OGL 1.0a (A5e variant) |
| Green Ronin | `tdcs` (Tal'Dorei) | OGL 1.0a |
| Somanyrobots | `spells-that-dont-suck` | OGL 1.0a |
| Open5e | `open5e`, `open5e-2024`, `core` | CC-BY-4.0 |

**Approx record counts** (v2 unless noted): ~3,540 creatures, ~12,228 creature
actions, ~5,244 action attacks, ~8,613 creature traits, ~1,955 spells, ~2,319
magic items, ~440 generic items, ~75 weapons, ~63 species + 330 species traits,
~151 character classes + 1,249 class features, ~58 backgrounds, ~91 feats.
License/attribution is carried per `Document.json` (`licenses` array).

**Smallest v2 monster source:** `green-ronin/tdcs` (4 creatures) — used for P0.

**Built packages (P0–P4, one per v2 document with mappable content):** the
registry is auto-discovered (`sources.dart` scans `data/v2/**/Document.json`), so
every document below produced a `<pkg>.pkg.json`. Entity counts as built:

| Package | Monsters | Spells | Magic items | License | SRD overlap |
|---|--:|--:|--:|---|:--:|
| `open5e-a5e-mm` (Monstrous Menagerie) | 586 | — | — | OGL | |
| `open5e-tob-2023` (ToB 1, 2023) | 408 | — | — | OGL | |
| `open5e-tob3` (Tome of Beasts 3) | 397 | — | — | OGL | |
| `open5e-tob` (Tome of Beasts) | 391 | — | — | OGL | |
| `open5e-tob2` (Tome of Beasts 2) | 383 | — | — | OGL | |
| `open5e-bfrd` (Black Flag SRD) | 360 | — | — | CC-BY | |
| `open5e-ccdx` (Creature Codex) | 356 | — | — | OGL | |
| `open5e-tdcs` (Tal'Dorei) | 4 | — | — | OGL | |
| `open5e-srd-2014` (SRD 5.1) | 325 | 319 | 499 | OGL | ✓ |
| `open5e-srd-2024` (SRD 5.2) | 330 | 339 | 757 | CC-BY | ✓ |
| `open5e-deepm` (Deep Magic) | — | 515 | — | OGL | |
| `open5e-a5e-ag` (Adventurer's Guide) | — | 371 | — | CC-BY | |
| `open5e-spells-that-dont-suck` | — | 180 | — | CC-BY | |
| `open5e-toh` (Tome of Heroes) | — | 91 | — | OGL | |
| `open5e-deepmx` (Deep Magic Extended) | — | 64 | — | OGL | |
| `open5e-wz` (Warlock Zine) | — | 43 | — | OGL | |
| `open5e-kp` (KP Compilation) | — | 31 | — | OGL | |
| `open5e-open5e` (Open5e Originals) | — | 2 | — | OGL | |
| `open5e-vom` (Vault of Magic) | — | — | 1063 | OGL | |

Each monster pack also carries its creature-action + trait child entities (e.g.
`open5e-tob` = 391 monsters + 1303 actions + 1039 traits). **0 unresolved refs**
across all packs. Total bundled asset weight ≈ **32 MB** (see R6).

**P5 char-build content** (descriptive) folds into the same per-document packages
and adds three more documents (`a5e-ddg`, `a5e-gpg`, `open5e-2024` — backgrounds/
subclasses only), for **22 packages** total: 26 base classes + 125 subclasses
(largest: `toh` 76 subclasses), 63 species (`toh` 40, `srd-2014` 13), 58
backgrounds (`a5e-ag` 21), 91 feats (`a5e-ag` 59). Child feature/trait/benefit
rows are folded into each entity's `description` markdown (see §6).

---

## 3. App package system (the seam we reuse)

- **Wire format** (`srd_core/_helpers.dart`): `packEntity({slug, name,
  description, source, attributes})` → `{name, type, source, description,
  image_path, images, tags, dm_notes, pdfs, location_id, attributes}`. Tier-0
  refs = `lookup(slug, name)` → `{_lookup, name}`; inter-entity refs =
  `ref(slug, name)` → `{_ref, name}`.
- **Id + ref resolution** (`srd_core/srd_core_pack.dart` `buildSrdCorePack`):
  Pass 1 mints `uuidv5(namespace, "slug:name")`; Pass 2 rewrites `_ref` → id;
  `_lookup` left for import-time resolution.
- **Install seam** (`data/repositories/package_repository_impl.dart`
  `_saveToDb`, ~line 399): `PackageRepository.save(name, {entities,
  world_schema, template_id, template_original_hash, …})`, full-replace via
  `PackagesDao.upsertEntities`. Non-typed top keys (e.g. `metadata`) land in
  `state_json`.
- **Online + marketplace:** `package_provider.dart` `makeOnline()` →
  `personal_packages` mirror; `marketplace_listing_provider.dart`
  `publishSnapshot(itemType:'package', localId, …)` (gzip + RPC, beta-gated,
  migration 057).
- **Schema:** `builtin_dnd5e_v2_schema.dart` `generateBuiltinDnd5eV2Schema()`
  (`schemaId = builtin-dnd5e-default-v2`), 73 categories. `WorldSchema.toJson()`
  serializes/round-trips cleanly (verified) — embedded at install time.

---

## 4. Field-mapping reference

Open5e v2 → app `attributes`. Lookups normalized to canonical Tier-0 names via
`tool/open5e_import/normalize.dart` (single source of truth: `buildTier0Lookups`
seed rows). Unknown values → logged to `unmapped_report.json`, never a dangling
`_lookup`.

### Monster (`monster`)

| Open5e Creature field | app key | notes |
|---|---|---|
| `name` | `name` | |
| `size` | `size_ref` | lookup `size` |
| `type` (`"humanoid (elf)"`) | `creature_type_ref` + `tags_line` | split subtype `(…)` |
| `alignment` | `alignment_ref` | lookup `alignment` |
| `armor_class` / `armor_detail` | `ac` / `ac_note` | |
| `hit_points` / `hit_dice` | `hp_average` / `hp_dice` | |
| `ability_score_*` | `stat_block.{STR..CHA}` | |
| `initiative_bonus` | `initiative_modifier` / `initiative_score` | falls back to DEX mod; score = 10 + mod |
| `walk`/`fly`/`swim`/`burrow`/`climb` | `speed_*_ft` | floats → int ft |
| `hover` | `can_hover` | |
| `darkvision_range`/`blindsight_range`/`tremorsense_range`/`truesight_range` | `senses` | `[{sense, range_ft}]` |
| `telepathy_range` | `telepathy_ft` | |
| `passive_perception` | `passive_perception` | fallback 10 + WIS mod |
| `challenge_rating` (`"7.000"`) | `cr` | `1/8`,`1/4`,`1/2` for fractions |
| `experience_points_integer` | `xp` | fallback from CR table |
| `proficiency_bonus` | `proficiency_bonus` | fallback from CR |
| `damage_resistances`/`_immunities`/`_vulnerabilities` | `resistance_refs`/`damage_immunity_refs`/`vulnerability_refs` | lookup `damage-type` list |
| `condition_immunities` | `condition_immunity_refs` | lookup `condition` list |
| `languages` | `language_refs` | lookup `language` list |
| `saving_throw_*` | `save_bonuses` | proficiencyTable: `proficient=true`, `misc = bonus − abilityMod − PB` |
| `skill_bonus_*` | `skill_bonuses` | same |
| CreatureAction (split by `action_type`) | `action_refs`/`bonus_action_refs`/`reaction_refs`/`legendary_action_refs`/`lair_action_refs` | `_ref` → `creature-action` |
| CreatureTrait | `trait_refs` | `_ref` → `trait` |

### Creature-action (`creature-action`)

`action_type` (ACTION/BONUS_ACTION/REACTION/LEGENDARY_ACTION/LAIR_ACTION) →
`action_type` (Title Case); `desc` → `description`; `uses_type`
(RECHARGE_ON_ROLL/RECHARGE_AFTER_REST) → `recharge_kind` (Roll/Short Rest);
`uses_param` (PER_DAY) → `uses_per_day`. From the matched **CreatureActionAttack**:
`to_hit_mod` → `attack_bonus`; `attack_type` + reach/range → `attack_kind`
(Melee/Ranged Weapon/Spell); `reach`/`range`/`long_range` → `reach_ft`/
`range_normal_ft`/`range_long_ft`; `damage_die_count`+`damage_die_type`+
`damage_bonus` → `damage_dice` ("XdY+Z"); `damage_type` → `damage_type_ref`.

### Trait (`trait`)

`name`/`desc` → `name`/`description`; `trait_kind` defaults to `Other` (Open5e
has no kind field).

### Spell (`spell`) — `mappers/spell.dart`, DONE

| Open5e Spell field | app key | notes |
|---|---|---|
| `name` / `desc` (+ `higher_level`) | `name` / `description` | higher-level appended as `**At Higher Levels.**` |
| `level` | `level` | int |
| `school` | `school_ref` | lookup `spell-school`; a5e `transformation`→Transmutation |
| `casting_time` (`"10minutes"`) | `casting_time_amount` + `casting_time_unit_ref` | regex parse → (amount, unit); week/turn/round→`Special` |
| `range`/`range_unit`/`range_text` | `range_type` + `range_ft` | feet/ft, miles×5280, `any`→Unlimited; else Self/Touch/Sight keyword |
| `verbal`/`somatic`/`material` | `components` | V/S/M booleans → lookup `casting-component` |
| `material_specified`/`material_cost`/`material_consumed` | `material_description`/`material_cost_gp`/`material_consumed` | |
| `duration`/`concentration` | `duration_amount`+`duration_unit_ref` / `requires_concentration` | `instantaneous`/`permanent`/`*dispelled*`/N rounds-minutes-hours-days; tail→`Special` |
| `ritual` | `is_ritual` | |
| `damage_types[]` | `damage_type_refs` | lookup `damage-type` |
| `saving_throw_ability` | `save_ability_ref` | lookup `ability`; empty omitted |
| `attack_roll` | `attack_type` | Ranged if range>5 ft else Melee |
| `classes[]` (`"srd_wizard"`) | **`tags`** | descriptive — NOT `class_refs` (spell packs ship no class entities; an inter-entity `_ref` would dangle) |

### Magic item (`magic-item`) — `mappers/item.dart`, DONE

| Open5e MagicItem field | app key | notes |
|---|---|---|
| `name` / `desc` | `name` / `description` / `effects` | |
| `category` (`"wondrous-item"`) | `magic_category_ref` | lookup `magic-item-category`; shield→Armor, ammunition→Weapons |
| `rarity` (`"very-rare"`) | `rarity_ref` | lookup `rarity` |
| `requires_attunement` (+ `attunement_detail`) | `requires_attunement` + `attunement_prereq` | |
| `cost` / `weight` | `cost_gp` / `weight_lb` | parsed from string, only if > 0 |
| (none) | `activation` | defaults to `None`; `is_cursed`/`is_sentient` default false |

`base_item_ref` is intentionally not emitted (magic-item packs ship no base
weapon/armor entities to point at).

**Scope cut:** mundane SRD `Weapon.json` / `Armor.json` / generic `Item.json`
(adventuring gear) are **not** imported — they duplicate built-in SRD equipment
1:1 with no unique value, and exist only in the publish-excluded SRD packs.
Magic weapons/armor/shields (e.g. from Vault of Magic) ARE captured via the
magic-item mapper.

### Class / subclass / species / background / feat — `mappers/chargen.dart`, DONE

Descriptive only (locked policy). For every type, the parent `desc` plus its
child rows (joined by `parent` slug) are folded into one `description` markdown
(`### <child name>` blocks). **No grant/effect DSL and no inter-entity `_ref`**
is emitted, so these render as reference cards but never dangle and don't
auto-wire into level-up.

| Type | Source rows | app slug | typed fields filled | folded child |
|---|---|---|---|---|
| Class (base, `subclass_of==null`) | `CharacterClass` | `class` | `hit_die` (`D12`→12), `saving_throw_refs` (abbrev→ability), `primary_ability_ref` (when present), `caster_kind` (FULL/HALF/PACT/NONE→Full/Half/Pact/None) | `ClassFeature` |
| Class (`subclass_of` set) | `CharacterClass` | `subclass` | — (parent class name → tag + `*Subclass of …*` header) | `ClassFeature` |
| Species (+ subspecies) | `Species` | `species` | — (subspecies → parent tag) | `SpeciesTrait` |
| Background | `Background` | `background` | — | `BackgroundBenefit` |
| Feat | `Feat` | `feat` | `repeatable=false`; `prerequisite` → `**Prerequisite:**` header | `FeatBenefit` |

Name collisions (3rd-party docs reuse generic subclass/feat names) are
disambiguated with a ` (Parent)` / ` (n)` suffix so `pack.add` never silently
merges two distinct entities.

### Canonical Tier-0 targets (normalization)

`size`(6), `creature-type`(14), `alignment`(10), `damage-type`(13),
`condition`(15), `language`(19), `spell-school`(8), `rarity`(6),
`magic-item-category`(9), `sense`(4), `area-shape`(6), `casting-time-unit`(7),
`duration-unit`(7), etc. Resolved live from `buildTier0Lookups` so the importer
never drifts from the schema.

---

## 5. Transform architecture

Offline Dart CLI (`tool/open5e_import/`), run with `dart run`:

```
tool/open5e_import/
  bin/build_packs.dart   # entry: --data <path> --out <dir> --rev <tag>
  sources.dart           # SourceDoc registry (slug, title, publisher, license, v2Dir) + attribution
  loaders.dart           # fixture reader {model,pk,fields} → {_pk, ...fields}; groupBy/byPk
  normalize.dart         # Normalizer (canonical sets from buildTier0Lookups) + UnmappedSink + titleCase
  refgraph.dart          # PackBuilder: per-package uuidv5 namespace, two-pass _ref resolution, integrity
  mappers/monster.dart   # Creature(+Action+Attack+Trait) → monster + creature-action + trait
  mappers/spell.dart     # Spell → spell (classes → tags; range/casting/duration normalized)
  mappers/item.dart      # MagicItem → magic-item (category/rarity normalized)
  mappers/chargen.dart   # Class/Species/Background/Feat → descriptive cards (child rows → markdown)
  emit.dart              # assemble payload, write <pkg>.pkg.json + manifest.json + unmapped_report.json
  test/monster_mapper_check.dart  # self-checking verification (dart run, exit code)
```

- **Pure-Dart reuse:** imports the app's `_helpers.dart`, `lookups.dart`,
  `dnd5e_constants.dart` via `package:dungeon_master_tool/...` (no Flutter deps).
- **Per-package namespace:** `uuidv5(url-namespace, "open5e-pack:<name>")` so ids
  are stable across rebuilds and never collide across packages.
- **Child dedup:** actions/traits deduped within a package by content signature;
  name collisions with different content get an SRD-style ` (CreatureName)`
  suffix so `_ref` resolves unambiguously.
- **Schema attach (R1):** packs ship only `entities` + `metadata`; the app-side
  `Open5ePackInstaller` embeds `generateBuiltinDnd5eV2Schema().schema.toJson()`
  + `template_id` at install, keeping the asset compact and always current.
- **Output:** one `<package>.pkg.json` per document + a `manifest.json` the app
  reads via `rootBundle` to list installable packs. Build **fails (exit 1)** on
  any unresolved `_ref`.

**App-side install** (`lib/application/services/open5e_pack_installer.dart`):
`available()` reads the manifest; `install(info)` loads the asset, attaches the
schema, and calls `PackageRepository.save`. The installer is **type-agnostic** —
it streams `entities`/`counts` generically, so monster/spell/magic-item packs all
install unchanged. UI entry: the **Open5e** button in the Packages hub tab opens
an install dialog listing all 19 packs with their per-type counts.

---

## 6. Depth policy & known limitations

- Monsters/spells/items: **fully usable** (render from stat fields + text).
- Classes/species/feats/backgrounds: **descriptive only**. They appear as cards
  with their text but do **not** auto-grant features on level-up. This is an
  accepted trade-off (no effect/grant DSL parsing). Surface a "reference content"
  label in the UI for these categories (P5).
- Per-monster: `legendary_action_uses` defaults to 3 (Open5e omits the count);
  secondary/extra attack damage stays in the action description.

---

## 7. Licensing & attribution

Every package embeds an attribution string in `metadata.attribution`
(`sources.dart` `attributionFor(license)`), mirroring `srdAttribution`:

- **OGL 1.0a** sources (Kobold Press, A5e, Green Ronin, Somanyrobots): OGL notice.
- **CC-BY-4.0** sources (Open5e, SRD): CC notice.

Publish-time validator (P2) must refuse a package lacking a license/attribution.
Attribution is surfaced in the package About panel. **R2 (legal):** redistributing
OGL 3rd-party content via the marketplace needs the user's sign-off; SRD packages
are excluded from publish by default to avoid duplicate listings.

---

## 8. Validation strategy

- **Build-time:** zero unresolved `_ref` (else exit 1); `unmapped_report.json`
  for every non-canonical lookup value; per-package counts.
- **Self-check** (`test/monster_mapper_check.dart`): counts, ref integrity, all
  lookups canonical, plus golden spot-checks — Firetamer + Adult Cave Dragon
  (monster), Fireball + Acid Arrow (spell: level/school/range/components/duration/
  higher-level/class-tags), Akaasit Blade (magic item: category/rarity), Barbarian
  + Grappler (class hit-die/saves/folded features, feat prerequisite). Runs via
  `dart run`, exits non-zero on regression.
- **Schema round-trip:** `WorldSchema.toJson()` ↔ `jsonEncode` verified (73
  categories, ~588 KB).
- **App render check (manual):** install a pack → open a monster statblock and
  confirm stats + actions render.
- Project convention: rely on `flutter analyze` (0 new issues); `flutter test`
  is skipped per team preference — tool verification is `dart run`-based.

---

## 9. Phased roadmap

- **P0 — Thin slice (DONE).** Tool skeleton + v2 loader + monster mapper for
  Tal'Dorei (`tdcs`). One pack emitted (4 monsters, 10 actions, 11 traits, 0
  unmapped, 0 unresolved). App installer + schema-attach + Open5e hub button.
  `dart analyze` clean, `flutter analyze` 0 new issues. R1 resolved (embed schema).
- **P1 — Full monster source (DONE).** Tome of Beasts: 391 monsters, 1303
  creature-actions (deduped from 1427), 1039 traits (from 1123), **0 unresolved
  refs**. Edge cases handled: `recharge_min_roll` (Recharge 5–6), `uses_per_day`
  (PER_DAY), fuzzy 3rd-party alignments/languages logged to
  `unmapped_report.json` (28 non-SRD languages, 10 fuzzy alignments — dropped
  from refs, not errors). Golden assertions locked in
  `test/monster_mapper_check.dart` (Adult Cave Dragon CR16/PB5/saves + recharge +
  attack parsing). Pack payload minified (4.3 MB → 2.8 MB).
- **P2 — Marketplace path.** `makeOnline` → `publishSnapshot` for a pack;
  attribution embed + publish-time validator; download round-trip on a 2nd
  account.
- **P3 — Scale all monster sources (DONE).** `sources.dart` now auto-discovers
  every `data/v2/**/Document.json`; the build loop dispatches per content type.
  Shipped monster packs: ToB 1/2/3 + ToB-2023, Creature Codex, Black Flag SRD,
  A5e Monstrous Menagerie, Tal'Dorei, SRD 5.1/5.2 — ~3,540 monsters total, 0
  unresolved refs. Only expected 3rd-party vocab unmapped (titanic size, 72
  non-SRD languages, 95 fuzzy alignments). (v1-only sources: none remaining — all
  packageable content present in v2.)
- **P4 — Spells + items (DONE).** `mappers/spell.dart` (10 sources, ~1,955
  spells) + `mappers/item.dart` (Vault of Magic + SRD, ~2,319 magic items). All
  schools/casting-units/durations/components/categories/rarities resolved to
  canonical Tier-0 names — **zero** spell/item lookup misses. Goldens locked.
  Mundane SRD weapons/armor/gear deliberately not imported (built-in duplicates).
- **P5 — Classes / species / feats / backgrounds (descriptive) (DONE).**
  `mappers/chargen.dart`: 26 base classes + 125 subclasses, 63 species, 58
  backgrounds, 91 feats across 11 source docs. Child feature/trait/benefit rows
  folded into `description` markdown; only safe class scalars (hit die, saves,
  primary ability, caster kind) typed. No grant DSL, no dangling refs. Golden:
  Barbarian (hit_die 12 / Con+Str saves / folded features), Grappler (prereq).
- **P6 — Media (optional, deferred).** Per-entity art via the existing R2 pipeline
  under media limits, only if revisited.

---

## 10. Open risks & decisions log

- **R1 (resolved):** schema attach — embed the live built-in v2 schema at install
  (verified `toJson` round-trip). Not referenced by id.
- **R2 (open):** legal sign-off to redistribute OGL 3rd-party content via the
  marketplace. Attribution embed is necessary but not sufficient — needs user
  confirmation. SRD packs excluded from publish by default.
- **R3 (resolved):** dedup actions/traits **within** a package (not across
  packages) — implemented by content signature.
- **R4 (resolved):** A5e is a ruleset variant. In practice only three vocab
  classes don't map to SRD 5e Tier-0 — non-SRD languages, fuzzy alignments, and
  the invented "titanic" size — all logged to `unmapped_report.json` and dropped
  from refs (never dangling). All stat fields map cleanly; no schema mismatch
  blocked a build.
- **R5 (watch):** embedded schema is ~588 KB per package; gzip at publish (the
  RPC already gzips). Consider a shared-schema reference if payload size becomes
  a problem at scale.
- **R6 (ACTION NEEDED before release):** the 22 bundled `.pkg.json` assets now
  total **≈32 MB** in the app binary (largest: srd-2024 ~3.7 MB, tob-2023 3.3 MB,
  a5e-mm 3.3 MB). These are **author-seeding** assets — once published, end-users
  download from the marketplace, not the bundle. The full 30 MB should NOT ship in
  production. Options before release: (a) move pack generation out of `assets/`
  and publish from a local build dir (author runs `build_packs.dart`, installs,
  publishes — nothing bundled); (b) bundle only a curated starter subset; (c)
  drop the two SRD-overlap packs (−6.7 MB of pure built-in duplicates). For the
  current **review phase** the packs stay bundled so the user can install and
  inspect them locally; revisit before P2 publish.
