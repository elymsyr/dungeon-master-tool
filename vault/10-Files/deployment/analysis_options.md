---
type: file-note
domain: deployment
path: flutter_app/analysis_options.yaml
layer: core
language: yaml
status: stable
updated: 2026-06-09
tags: [file]
---

# `analysis_options.yaml`

> [!abstract] Primary Purpose
> Configures the Dart static analyzer for `flutter_app`. Extends `flutter_lints`, excludes generated code, promotes three resource-safety lints from info to warning, and layers a set of const-correctness + safety lints on top of the defaults. This is the ruleset `flutter analyze` (run in CI, see [[ci-analyze-test]]) enforces.

## Inputs / Outputs
**Inputs**
- `include: package:flutter_lints/flutter.yaml` (the `flutter_lints` ^6.0.0 base from [[pubspec]]).

**Outputs**
- The effective lint/severity set surfaced in IDEs and by `flutter analyze`.

## Dependencies & Links
- Depends on: [[pubspec]]
- Used by: [[ci-analyze-test]]
- Domain map: [[Deployment-and-Ops]]
- System flow:
- Spec / reference:

## Key Logic / Variables
- `analyzer.exclude`: `**/*.g.dart`, `**/*.freezed.dart`, `lib/gen/**`, `lib/l10n/gen/**` — all freezed/drift/riverpod/json_serializable/l10n generated output is skipped.
- `analyzer.errors` (severity promotions to `warning` so CI flags them): `use_build_context_synchronously`, `cancel_subscriptions`, `close_sinks`.
- `linter.rules` (extra rules on top of flutter_lints defaults): `avoid_empty_else`, `cancel_subscriptions`, `close_sinks`, `prefer_const_constructors`, `prefer_const_constructors_in_immutables`, `prefer_const_declarations`, `prefer_const_literals_to_create_immutables`, `use_build_context_synchronously`.
- Theme of the additions: resource-leak safety (cancel subscriptions / close sinks), async-context safety, and const-correctness for widget perf.

## Notes
- `cancel_subscriptions` / `close_sinks` / `use_build_context_synchronously` appear in both `linter.rules` (enabled) and `analyzer.errors` (promoted severity) — the rule turns the lint on, the errors block raises it to warning.
