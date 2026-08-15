---
type: file-note
domain: world-content
path: flutter_app/lib/presentation/widgets/field_widgets/entity_link.dart
layer: presentation
language: dart
status: stable
updated: 2026-08-15
tags: [file]
---

# `entity_link.dart`

> [!abstract] Primary Purpose
> **The one "open this entity" entry point**, plus the one test for whether a stored ref is openable at all (audit phase **U3**, 2026-08-15). Created because the phase's stated design decision — where a widget nested inside a field asks for a card to be opened — had a third answer nobody had noticed: the provider already existed and was already used, it just was not reachable from `structured_list_field_widgets`, and one of the two screens was not listening to it.

## Inputs / Outputs
**Inputs**
- A `WidgetRef` (nullable at every call site — a field widget rendered without Riverpod stays inert rather than throwing).
- The stored ref value, in any of its envelopes, plus the merged `Map<String, Entity>` the card was rendered against.

**Outputs**
- `void navigateToEntity(WidgetRef, String id, {String? sourcePanel})` — writes [[ui_state_provider|entityNavigationProvider]] (+ the panel hint, inverted from `sourcePanel`).
- `String? entityLinkTarget(Object? raw, Map<String, Entity>? byId)` — the id to open, or **null**.
- `class EntityLink` — wraps a child in the tap when `targetId != null`, renders it untouched otherwise.

## Key Logic

**Why a provider and not a threaded callback.** U3 filed the choice as open ("a callback threaded through the field widgets, or a provider both screens already listen to — pick one; do not add a third copy of the selection state"). Measurement closed it: `entityNavigationProvider` had existed all along, `main_screen` listened to it, and the relation chips in [[field_widget_factory]] and the entity links in `markdown_text_area` already wrote to it. Threading a callback would have added a second mechanism next to a working one and touched every field-widget constructor; a new provider would have been the third copy the phase forbade. So this file only *lifts the write out* of `field_widget_factory` so the structured-list mini fields can reach it too.

**`package_screen` was the dead half.** It kept its own `_selectedEntityId` and never listened, so every link inside a package's cards was a tap that did nothing. U3 added the listener — same provider, same clear-after-handling, no second selection field. `main_screen`'s listener additionally switches to the Database tab and honours the panel hint; the package screen has neither, so it clears the hint and ignores it.

**`entityLinkTarget` returning null is the load-bearing half.** It delegates to [[entity_ref|resolveEntityRef]] — the reader U1 standardised the wizard on — so all four envelopes (bare uuid, `{_ref, name}`, `{_lookup, name}`, soft `{slug, name}`) become links and **nothing else does**. A ref into an uninstalled pack resolves to nothing and must therefore stay plain text: *a link that opens an empty dialog is worse than no link*. The underline is the affordance and appears on exactly the same condition, so it cannot promise a tap that will not land.

**The bug this closed was not "untappable", it was "invisible".** The reported symptom was that tapping a spell in a spell list did nothing. The cause was one layer lower: the presentation layer carried its own envelope readers (`resolveRelationId`'s O(n) scan, `_parseIds`, `_parseItems`) that knew `_lookup` and `_ref` but **not** the soft `{slug, name}` shape a package writes for a cross-pack target. Those fell through to `e['id']` → null → dropped, so a packaged spell never rendered in the first place. U3 pointed all three at `entityLinkTarget`, and folded `_lookup` into `resolveEntityRef` so there is one reader rather than two that disagree.

## Dependencies & Links
- Depends on: [[entity_ref]] (`resolveEntityRef`), `ui_state_provider` (`entityNavigationProvider`, `entityNavigationTargetPanelProvider`), `entity.dart`.
- Used by: [[field_widget_factory]] (`_navigateToEntity` is now a one-line delegate; `resolveRelationId` / `_parseIds` / `_parseItems` resolve through it) and `structured_list_field_widgets.dart` (`_MiniRelationField`, `_MiniRelationListField` — the widgets U3 named as having no gesture at all).
- Listened to by: `main_screen.dart` (selection + Database tab + panel hint) and `package_screen.dart` (selection only, since U3).
- Pinned by `test/presentation/entity_link_navigation_test.dart` — 5 cases: a soft-ref spell in a spell list opens its card, a mini relation field in a structured row opens its card, an unresolvable ref neither underlines nor navigates, and two that assert `entityLinkTarget` **is** `resolveEntityRef` for all four shapes (U3 adds no second envelope reader). Both link halves are mutation-checked: disabling either makes two of them fail.
- Domain map: [[World-and-Content]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]]
- Audit: `flutter_app/docs/open5e_content_audit.md` §6 U3.
