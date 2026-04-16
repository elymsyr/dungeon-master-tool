# Roadmap

Tracked work for upcoming releases — bugs to fix and features to add. Items are grouped by type, not strictly ordered.

## Features

### Package types
Today there is one generic package type. Split it into two distinct kinds:

- **Entity Card Pack** — current behavior (schema + entities).
- **Sound Pack** — opens directly into the Soundpad sidebar as the landing view. Users can add tracks from the pack straight into their personal library.

### Profile pictures
Avatar upload + display across the app: profile screen, post author, message thread header, players list. Storage in the existing avatar bucket.

### Global tag system
Tags entered in one place (e.g., a Game Listing) should be discoverable when other users create their own listings. Provide an autocomplete / suggestion list of existing tags so the same tag is reused instead of slight variants.

### Online data cache layer
Cache online-side data (marketplace listings, shared content, etc.) locally instead of refetching from scratch every time. Invalidate on meaningful changes rather than on every view.

### Slot field type
A new field type: **slot**. Renders as a row of centered, theme-styled checkboxes with no inline text. The player can add as many slot checkboxes as they want to a given slot field. Include a refill button in the top-right of the field to reset all checkboxes at once. Intended for spell slots, ammo, charges, hit dice, etc.

### Rules system overhaul
The rules engine is the single most important upcoming work. Today's implementation is partial, inconsistent across field kinds, and not dynamic enough to express the situations players actually want to model. This section collects everything that needs to change.

**Current bugs**
- Rules do not fire uniformly across field types. Example: a rule that pushes spells from an item into the spell-slot field of an NPC who owns that item works. The analogous rule targeting the **actions** field does not fire, or only fires after a significant delay when the template is updated.
- Template updates are not reliably picked up by existing worlds/entities — rule re-evaluation after a template edit is lagging or missing entirely.

**New rule modes: `to be equipped` and `when equipped`**
Introduce two explicit rule phases so equipment logic can be modeled properly:
- **`to be equipped`** — predicates that gate *whether* an item can be equipped at all. Must be dynamic and composable. Examples:
  - Spell can only be equipped if caster level ≥ spell level.
  - Sword/staff can only be wielded if a given attribute (STR, INT, …) meets a threshold.
  - A spell requires Intelligence ≥ X to be prepared.
- **`when equipped`** — effects that apply *while* an item is equipped. Examples:
  - Cursed items that apply a condition while worn.
  - Items that grant +/- to an attribute, or add/remove conditions, only while equipped.
  - Items whose spells are injected into the owner's spell list only while held.

**Dynamic cross-field predicates**
Rules must be able to compare the contents of one field against another and drive presentation based on the result. Concrete target example:
- An NPC has an `Equipment` list field and a `Spell` list field.
- A spell entity has a `Necessary Items` field.
- Rule: *"In the NPC's spell list, render each spell in faded grey if any item in its `Necessary Items` is missing from the NPC's `Equipment` list."*

This generalizes to: "show items in list field A with style S if field B on each item is [subset of / equal to / disjoint from] field C on the containing entity." The rule builder needs to express set relationships between fields on different entities, not just flat value checks.

**Design goal**
The rule system should be fully dynamic — users compose predicates and effects from primitives (field references, set operations, comparisons, entity relationships) rather than picking from a fixed list of hard-coded rule templates. Treat this as a ground-up redesign of the rule builder, not an incremental patch.