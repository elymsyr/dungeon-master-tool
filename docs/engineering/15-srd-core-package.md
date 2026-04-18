# 15 — SRD Core Rules Package

> **For Claude.** The SRD 5.2.1 bundle ships as a *package*, not as Dart code in the app binary.
> **Source rules:** [00-dnd5e-mechanics-reference.md](./00-dnd5e-mechanics-reference.md)
> **Format spec:** [14-package-system-redesign.md](./14-package-system-redesign.md)
> **Domain refs:** [01-domain-model-spec.md](./01-domain-model-spec.md), [05-rule-engine-removal-spec.md](./05-rule-engine-removal-spec.md)

## Why This Doc Exists

The built-in dnd5e module ships only *mechanics* — the rules engine, typed domain classes, the `EffectDescriptor` DSL, and the `CustomEffect` registry. It ships **zero** content. Every concrete D&D 5e entry (the Stunned condition, the Fire damage type, Fireball, a Goblin, the Fighter class) arrives through the package system.

The default content users expect is SRD 5.2.1 (CC BY 4.0). This doc specifies the one package that provides it, its repo location, its build step, and how fresh worlds bootstrap with it installed.

## Package Identity

- `packageIdSlug`: `srd`
- `name`: `D&D 5e SRD Core Rules`
- `version`: semver, independent of the app version.
- `gameSystemId`: `dnd5e`
- `formatVersion`: `2`
- `sourceLicense`: `CC BY 4.0`
- All catalog ids are `srd:<localId>` post-import (e.g. `srd:stunned`, `srd:fire`, `srd:fireball`).

## Bundle Inventory (SRD 5.2.1)

### Catalog content
| Type | Count | Examples |
|---|---|---|
| Conditions | 17 | `srd:blinded`, `srd:charmed`, `srd:stunned`, `srd:unconscious`, … |
| Damage Types | 14 | `srd:acid`, `srd:bludgeoning`, `srd:fire`, `srd:psychic`, `srd:thunder`, … |
| Skills | 18 | `srd:athletics`, `srd:stealth`, `srd:perception`, … |
| Sizes | 6 | `srd:tiny`, `srd:small`, `srd:medium`, `srd:large`, `srd:huge`, `srd:gargantuan` |
| Creature Types | 14 | `srd:aberration`, `srd:beast`, `srd:humanoid`, `srd:undead`, … |
| Alignments | 10 (+ unaligned) | `srd:lawful_good`, …, `srd:chaotic_evil`, `srd:unaligned` |
| Languages | ~16 | `srd:common`, `srd:dwarvish`, `srd:elvish`, … |
| Spell Schools | 8 | `srd:abjuration`, `srd:evocation`, `srd:illusion`, … |
| Weapon Properties | ~14 | `srd:finesse`, `srd:heavy`, `srd:light`, `srd:versatile`, … |
| Weapon Masteries | 5 | `srd:cleave`, `srd:graze`, `srd:nick`, `srd:push`, `srd:topple` |
| Armor Categories | 3 | `srd:light_armor`, `srd:medium_armor`, `srd:heavy_armor` |
| Rarities | 6 | `srd:common`, `srd:uncommon`, `srd:rare`, `srd:very_rare`, `srd:legendary`, `srd:artifact` |

### Entity content
| Type | Count (approx) |
|---|---|
| Spells | ~361 |
| Monsters | ~320 |
| Items (weapons + armor + magic items + gear + tools + ammunition) | SRD 5.2.1 full set |
| Classes | 12 |
| Subclasses | 1 per class (SRD sample) |
| Species | SRD set |
| Backgrounds | SRD set |
| Feats | SRD set |

Every entry carries `EffectDescriptor` encoding of its mechanical behavior where representable; otherwise a `CustomEffect` pointing at an implementation id from the whitelisted registry below.

## Whitelisted `CustomEffect` Implementations

The following implementation ids are declared in the SRD package's `requiredRuntimeExtensions` and are registered by the app at startup in `flutter_app/lib/application/dnd5e/effect/custom_effect_registry.dart`:

| `implementationId` | Dart class | Feature |
|---|---|---|
| `srd:wish` | `WishImpl` | The Wish spell's open-ended replication and "anything else" branch |
| `srd:wild_shape` | `WildShapeImpl` | Druid Wild Shape form substitution |
| `srd:polymorph` | `PolymorphImpl` | Polymorph / True Polymorph form substitution |
| `srd:animate_dead` | `AnimateDeadImpl` | Controlled undead lifecycle |
| `srd:simulacrum` | `SimulacrumImpl` | Duplicate character creation |
| `srd:summon_family` | `SummonFamilyImpl` | 2024 "Summon X" spells with scaled stat blocks |
| `srd:conjure_family` | `ConjureFamilyImpl` | Pre-2024 Conjure X series |
| `srd:shapechange` | `ShapechangeImpl` | Shapechange spell |
| `srd:glyph_of_warding` | `GlyphOfWardingImpl` | Embedded-spell trigger semantics |

Extending the list requires a doc update here plus a Dart impl registered at startup.

## Repo Location and Build

Sources (human-authored, PR-reviewable):
```
flutter_app/assets/packages/srd_core/
├── manifest.json                 # metadata, version, requiredRuntimeExtensions
├── conditions.json
├── damage_types.json
├── skills.json
├── sizes.json
├── creature_types.json
├── alignments.json
├── languages.json
├── spell_schools.json
├── weapon_properties.json
├── weapon_masteries.json
├── armor_categories.json
├── rarities.json
├── spells/                       # split by school for diff-ability
│   ├── evocation.json
│   ├── abjuration.json
│   └── ...
├── monsters/                     # split by CR bucket
│   ├── cr_0_to_1.json
│   └── ...
├── items/
├── classes/
├── subclasses/
├── species.json
├── backgrounds.json
└── feats.json
```

Build step (Dart CLI tool, new):
```
flutter pub run tool:build_srd_pkg
  → reads flutter_app/assets/packages/srd_core/
  → concatenates into a single Dnd5ePackage JSON
  → computes contentHash (sha256 over content object, canonicalized)
  → emits flutter_app/assets/packages/srd_core.dnd5e-pkg.json
```

The built monolith is what ships with the app and what the importer reads. The split sources are what authors edit and PRs diff. The build tool's output is committed (reviewer sees the exact bytes that ship).

Unit tests enforce:
- Source files round-trip through `PackageValidator` with zero issues.
- Built monolith matches source concatenation byte-for-byte modulo canonicalization.
- `contentHash` is deterministic across runs (key-order stable).

## Boot Flow

### First-run bootstrap
On first app launch, `application/dnd5e/bootstrap/srd_bootstrap_service.dart` reads the built monolith from assets and imports it into a per-user content pool (the installed-packages registry). This is a one-time cost per install.

### Fresh world creation
Campaign Creation wizard (see [10-character-creation-flow.md](./10-character-creation-flow.md)) gains a "Starter Content" step between system selection and campaign-metadata entry:

```
[x] Install SRD Core Rules (recommended)
    D&D 5e 5.2.1 under CC BY 4.0. Conditions, spells, monsters,
    classes, and the standard damage types.

[ ] Start with empty catalogs
    Recommended only if you're importing your own packages or
    building a fully custom setting.
```

Default: checked. Unchecking produces a world with zero catalog content; the user must install a package before character creation can complete (the wizard detects and surfaces this).

### World Settings
Installed packages (including SRD Core) appear in `World > Settings > Installed Packages` with enable/disable/uninstall actions. Uninstalling SRD from a world with characters referencing SRD content triggers the dangling-reference warning flow defined in [01-domain-model-spec.md](./01-domain-model-spec.md) Open Question #4.

## Versioning and Upgrades

- SRD package version bumps are independent of app version.
- App ships with a specific built `srd_core.dnd5e-pkg.json`. When a user's installed SRD version is older than the bundled one, a one-tap upgrade flow uses the standard same-source `overwrite` conflict path from [14-package-system-redesign.md](./14-package-system-redesign.md).
- No auto-upgrade without user consent (in case homebrew content has referenced SRD ids that change semantics in a new SRD version).

## Licensing Attribution

Package metadata carries `sourceLicense: "CC BY 4.0"` and a `license_notice` field reproducing the attribution text per CC BY 4.0 requirements. UI surfaces the attribution in `About > Content Licenses` and on the package detail view.

## Acceptance

- Fresh install → launch app → SRD package appears in installed-packages list with ~361 spells, ~320 monsters, 17 conditions.
- New campaign wizard defaults to "Install SRD Core Rules." Unchecking produces a world that cannot complete character creation until a package is installed (wizard blocks with explanatory message).
- End-to-end test: create world with SRD → create Fighter character referencing `srd:athletics` proficiency and `srd:longsword` → put character into a combat with a Goblin (`srd:goblin`) → apply Stunned (`srd:stunned`) via a Monk-style effect descriptor → damage pipeline reports the Stunned target takes hits with advantage and auto-fails DEX saves, reading the condition's compiled `ConditionInteraction` descriptor.
- Removing the SRD package from a world with SRD-referencing characters surfaces the dangling-reference warning listing every missing id; no silent nulling.
- `CustomEffect` registry test: a hand-crafted package declaring `requiredRuntimeExtensions: ["srd:does_not_exist"]` fails import with the exact missing-id error message.

## Open Questions

1. Should the built monolith live in Git LFS? → Depends on final size. If > 5 MB uncompressed, yes; otherwise inline.
2. Should `srd_core.dnd5e-pkg.json` be pretty-printed or minified at build time? → **Minified for shipped asset, pretty-printed copy checked in under `build_artifacts/` for PR diffs.**
3. Translation of SRD text: per [43-i18n-localization-spec.md](./43-i18n-localization-spec.md), SRD content stays English. Package metadata (`name`, `description`) localized via `intl`; entity text is not.
4. Distribution of future official-style packages (e.g. Monster Manual-style homebrew by community): out of scope here; marketplace flow in [14-package-system-redesign.md](./14-package-system-redesign.md) covers it.
