---
type: file-note
domain: world-content
path: flutter_app/lib/presentation/dialogs/template_update_dialog.dart
layer: presentation
language: dart
status: active
updated: 2026-10-12
tags: [file]
---

# `template_update_dialog.dart`

> [!abstract] Primary Purpose
> Free template worlds follow their template (`docs/free-template/ROADMAP.md` Faz 3, DESIGN §6.4). When a free world finishes opening and its template changed since the world last took it, asks **Update / Ignore / do not show again for this world**. Built-in worlds never get here.

## Inputs / Outputs
**Inputs**
- `worldSchemaProvider` (the open world's own copy), `activeCampaignProvider.notifier.data` (`template_dismissed_hash`, `template_updates_muted`), `userTemplatesProvider`.

**Outputs**
- Update → `ActiveCampaignNotifier.applyTemplateUpdate(template)` (world schema replaced, card data untouched, D17).
- Ignore → `dismissTemplateUpdate(freeTemplateContentHash(template))`: quiet until the template changes again.
- Do not show again → `muteTemplateUpdates()`.

## Dependencies & Links
- Depends on: [[free_template]] (`pendingTemplateUpdate`, `freeTemplateContentHash`), [[campaign_provider]], [[template_provider]]
- Used by: `main_screen.dart` — `ref.listen(activeCampaignLoadingProvider)` at the top of `build` (before the splash return), true → false runs `offerTemplateUpdate` after the frame. `package_screen.dart` (Faz 5) — `_PackageScreenContent.initState`, after the first frame; inside the package's `ProviderScope`, so `worldSchemaProvider` / `activeCampaignProvider` are the package's and Update saves through `_PackageAsCampaignRepo` → `ActivePackageNotifier.save`.
- Domain map: [[World-and-Content]]

## Key Logic / Variables
- Revives the dialog that sat dead in `worlds_tab.dart` (`_showPreOpenTemplateDialogDead`) after `TemplateSyncService` was deleted in `781b8bd7` (ROADMAP B1). The hub now navigates to `/main` before the load finishes, so the check lives on the main screen, not the hub.
- No change list: the old `computeWorldSchemaDiff` lines are hard-coded English and match by label.
