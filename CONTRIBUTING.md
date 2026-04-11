# Contributing to Dungeon Master Tool

Thank you for your interest in contributing. This guide covers environment setup, coding standards, and the pull request workflow.

---

## Code of Conduct

Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before participating.

---

## Getting Started

### Prerequisites

- Flutter 3.41+ (stable channel)
- Dart 3.11+
- Git
- For Linux builds: `clang`, `cmake`, `ninja-build`, `libgtk-3-dev`, `pkg-config`, `libglib2.0-dev`, `lld`, `libstdc++-12-dev`, `libasound2-dev`
- For Android builds: Android Studio or Android SDK with Java 17

### Setup

1. Fork and clone the repository.
2. Navigate to the Flutter project:
   ```bash
   cd flutter_app
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run code generation:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
5. Launch the app:
   ```bash
   flutter run
   ```
6. Verify everything works:
   ```bash
   flutter analyze && flutter test
   ```

---

## Project Structure

```
flutter_app/lib/
  core/           -- Constants, configuration, utilities, extensions
  domain/         -- Pure Dart entities, abstract repositories, use cases
  data/           -- Drift database, DAOs, repository implementations
  application/    -- Riverpod providers, business logic services
  presentation/   -- Screens, widgets, themes, localization, routing
```

See [flutter_app/README.md](flutter_app/README.md) for full architecture documentation.

---

## Coding Standards

- Follow the lint rules defined in `analysis_options.yaml` (flutter_lints).
- Use **Riverpod** for state management. Annotate providers with `@riverpod` where possible.
- Use **Freezed** for immutable model classes.
- Use **Drift** for all database access. Never use raw SQL outside DAOs.
- Keep the domain layer free of Flutter and third-party package imports.
- Name files in `snake_case` and classes in `PascalCase`.
- Write tests for new logic, targeting the domain and application layers.

---

## Localization

All user-facing strings must go through the localization system:

1. Add new keys to `lib/presentation/l10n/app_en.arb` first.
2. Add translations to `app_tr.arb`, `app_de.arb`, and `app_fr.arb`.
3. Run `flutter gen-l10n` or let `flutter run` regenerate automatically.

---

## Code Generation

This project uses `build_runner` for Freezed, Riverpod, Drift, and JSON serialization. After changing any annotated file, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Generated files (`*.g.dart`, `*.freezed.dart`) should not be committed.

---

## Pull Request Process

1. Create a branch from `main` with a descriptive name (e.g., `feature/combat-conditions` or `fix/map-zoom-crash`).
2. Make focused, single-purpose commits.
3. Run `flutter analyze` and `flutter test` before pushing.
4. Open a pull request against `main` with:
   - A clear title describing the change.
   - A description explaining what changed and why.
   - Screenshots or recordings for UI changes.
   - References to related issue numbers.
5. Address review feedback with new commits (do not force-push).

---

## Reporting Issues

Use the GitHub issue templates:

- **Bug Report** -- for crashes, incorrect behavior, or UI issues.
- **Feature Request** -- for new functionality or improvements.
- **Question / Discussion** -- for general questions or help.

---

## License

Contributions are accepted under the project's [CC BY-NC 4.0](LICENSE) license. By submitting a pull request, you agree that your contribution will be licensed under the same terms.
