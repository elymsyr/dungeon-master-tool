---
type: file-note
domain: world-content
path: flutter_app/lib/application/providers/template_provider.dart
layer: application
language: dart
status: active
updated: 2026-10-11
tags: [file]
---

# `template_provider.dart`

> [!abstract] Primary Purpose
> Which templates exist. `allTemplatesProvider` is what the **built-in** flows may offer (only the built-in D&D 5e schema); `userTemplatesProvider` is the user's free templates. They are kept apart on purpose so no built-in flow can pick up a free template by accident.

## Inputs / Outputs
**Inputs**
- `appDatabaseProvider` (watched — switching accounts reloads the list).
- [[user_templates_dao]], [[free_template]].

**Outputs**
- `allTemplatesProvider` (`FutureProvider<List<WorldSchema>>`) — `[generateBuiltinDnd5eV2Schema().schema]`. Consumers: character wizard, character editor, world creation, package creation, global tags. `customTemplatesProvider` is an alias.
- `userTemplatesProvider` (`AsyncNotifierProvider<UserTemplatesNotifier, List<WorldSchema>>`) — `copy(source, name)`, `createEmpty(name, playerCardName:)`, `saveInfo(id, name:, description:, tags:, coverImagePath:)` (settings dialog; tags and cover in `metadata` like worlds/packages), `delete(id)`. Consumer: the hub Templates tab.

## Dependencies & Links
- Depends on: [[user_templates_dao]], [[free_template]], [[builtin_schema]]
- Used by: `templates_tab.dart`, `template_editor.dart` (inspector), wizard / world / package dialogs (built-in list only)
- Domain map: [[World-and-Content]]
- Spec / reference: `docs/free-template/ROADMAP.md` B3, Faz 1

## Key Logic / Variables
- Free templates reach a built-in flow only when that flow opts into `userTemplatesProvider` in its own phase (worlds Faz 3, packages Faz 5, characters Faz 6). Test: `user_templates_provider_test.dart` "built-in flows never see free templates".
- An unreadable row is skipped with a `debugPrint`, never deleted.
- Notifier methods update `state` in place after the DAO write (no full reload).

## Notes
- New ids are uuid v4; timestamps UTC ISO-8601 (same format as the built-in generator).
