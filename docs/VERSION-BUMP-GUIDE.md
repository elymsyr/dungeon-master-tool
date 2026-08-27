# Version Bump Guide

Follow this procedure end-to-end whenever the user asks to bump the version.

---

## 1. Find the current version

```bash
git tag --sort=-v:refname | head -1
```

Read `flutter_app/pubspec.yaml` (`version:` field) and `flutter_app/lib/core/constants.dart` (`appVersion` + `appProcess`) as the source of truth.

## 2. Review commits since the last tag

```bash
git log <last_tag>..HEAD --oneline
```

Read every commit message. Classify changes into: new features, bug fixes, breaking changes, internal-only refactors.

## 3. Decide the version

**If the user specified a version**, use it as-is.

**If not**, bump according to semver rules:

| Change type | Bump |
|---|---|
| Only bug fixes, polish, no new UI | **patch** (x.y.Z+1) |
| New user-facing features, no breaking changes | **minor** (x.Y+1.0) |
| Breaking changes, removed features, schema migration that requires action | **major** (X+1.0.0) |

**Default to beta.** Append the pre-release tag unless the user explicitly says otherwise:

- Beta tag: `beta-vX.Y.Z` (git tag) — `appProcess` stays `'beta'` in `constants.dart`.
- Stable tag: `vX.Y.Z` — only when the user explicitly requests a stable release; then also change `appProcess` to `'stable'` in `constants.dart` and the status badge in `README.md`.

## 4. Update version in source files

All four locations must match:

| File | What to change |
|---|---|
| `flutter_app/pubspec.yaml` | `version: X.Y.Z` (line 4) |
| `flutter_app/lib/core/constants.dart` | `appVersion = 'X.Y.Z'` (line 8) |
| `README.md` | Badge: `version-vX.Y.Z` (line 16), status badge if stable |
| `RELEASE_NOTES.md` | New release note section at the top (see step 5) |

## 5. Write the release note

1. Read `docs/TEMPLATE_RELEASE_NOTE.md` for format and rules.
2. Read the previous release note in `RELEASE_NOTES.md` to carry over known issues.
3. Copy the template between `<!-- BEGIN -->` and `<!-- END -->`.
4. Fill in every section. Delete sections that don't apply — don't leave empty headings.
5. Insert the new note at the **top** of `RELEASE_NOTES.md` (below the `# Release Notes` heading).
6. Every **Highlight** bullet must have a matching detailed section, and vice versa.
7. Carry forward unresolved known issues from the previous release.

## 6. Apply extra changes (if any)

If the user asked for additional changes alongside the version bump, apply them now. Do not bundle unrequested changes.

## 7. Verify

Run from `flutter_app/`:

```bash
flutter analyze
flutter test
```

Fix any issues before finishing.

## 8. Do NOT commit or tag

Stop after verification. Only commit and create the git tag when the user explicitly asks.
