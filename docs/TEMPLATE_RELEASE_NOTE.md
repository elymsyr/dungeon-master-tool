# How to Write a Release Note

This file is the **template and style guide** for every Dungeon Master Tool release note going forward. Copy the template block below into `RELEASE_NOTES.md` (at the top, above the previous release) and fill it in. Keep the tone plain, player-facing, and specific — no marketing fluff, no internal jargon the user can't act on.

---

## Rules of thumb

1. **Write for the player, not the committer.** If a change isn't user-visible or doesn't affect upgrade behavior, it belongs in the commit log, not here. Strip refactors, renamed private widgets, internal-only flags, and test-only changes.
2. **Group by user intent, not by file.** A single feature that touched six files is one section. Six unrelated fixes are six bullets.
3. **Lead with the outcome.** "Share your characters on the Marketplace" beats "Added `character` to `item_type` enum."
4. **Be specific about breakage.** If the user must do something (uninstall, apply migration, re-publish), say it at the top in a `> Heads-up` callout and again in **Upgrade notes**.
5. **Absolute dates only.** "April 2026", not "last month".
6. **No emojis** unless the product UI itself uses one (e.g. the `📥` download glyph in listing cards — fine to mirror here).
7. **Keep Known Issues honest.** If something is deferred or intentional-for-now, say so. Silence reads as a bug waiting to bite.

---

## Section order (in the template below)

1. Title + Beta tag + version
2. Release date
3. Links (GitHub release, website)
4. One-paragraph intro — what this release is *about*
5. Heads-up callouts (only when action is required)
6. **Highlights** — ~6–10 bullets, one line each, user-outcome framing
7. **What's new** — grouped feature sections with real explanations
8. **Smaller improvements** — single-line bullets for polish items
9. **Bug fixes** — user-visible fixes only
10. **Deprecations & removals** — what disappeared and what replaces it
11. **Upgrade notes** — version bump, required actions, data-migration caveats
12. **Known issues** — honest list of what's deferred, broken-on-purpose, or watch-outs
13. Sign-off

> Backend/schema migrations (Supabase SQL, server-side DDL) are **not** part of the user-facing release note. They belong in a separate deployment doc for self-hosters, not here. Do not list migration file names or schema changes in this document.

---

## Template

Copy everything between the `<!-- BEGIN -->` and `<!-- END -->` markers into `RELEASE_NOTES.md` and fill in the placeholders in `{{curly braces}}`. Delete any section that genuinely doesn't apply to this release (don't leave empty headings).

<!-- BEGIN RELEASE TEMPLATE -->

## Dungeon Master Tool v{{MAJOR.MINOR.PATCH}} — {{Theme / one-line subtitle}} (Beta)

**Release date:** {{Month YYYY}}
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v{{MAJOR.MINOR.PATCH}}) · [elymsyr.github.io](https://elymsyr.github.io/)

{{One short paragraph: what this release is about, who benefits, and what (if anything) the user needs to do to install it cleanly. 3–5 sentences max.}}

> **Heads-up for {{audience — e.g. self-hosted deployments / Android users / desktop users}}:** {{one-sentence action the user must take, and what breaks if they skip it}}.

---

### Highlights

- **{{Feature name}}** — {{one-line user-facing outcome}}.
- **{{Feature name}}** — {{one-line user-facing outcome}}.
- **{{Feature name}}** — {{one-line user-facing outcome}}.
- **{{Feature name}}** — {{one-line user-facing outcome}}.
- **{{Feature name}}** — {{one-line user-facing outcome}}.
- **{{Feature name}}** — {{one-line user-facing outcome}}.

---

### {{Group name — e.g. Marketplace}}

#### {{Feature title}}
{{2–6 sentences explaining what changed from the user's point of view, where to find it in the UI, and any quirks worth knowing. Mention concrete numbers (size limits, counts, timings) when they matter. Avoid file paths unless the user will interact with them directly.}}

#### {{Feature title}}
{{Same treatment. If there are implementation quirks the user *should* know about, list them as sub-bullets:}}

- {{Quirk or caveat 1}}.
- {{Quirk or caveat 2}}.

### {{Group name — e.g. Editors, Profile, Admin}}

{{Prose or bullets, whichever reads more clearly. Use before/after comparisons when the change replaces something the user already knew:}}

**Before (v{{previous}}):** {{what it was}}
**After (v{{this}}):** {{what it is now}}

---

### Smaller improvements

- **{{Area}}** — {{what changed, one line}}.
- **{{Area}}** — {{what changed, one line}}.
- **{{Area}}** — {{what changed, one line}}.
- **l10n** — {{new/changed translation keys and which languages are covered}}.

---

### Bug fixes

- **{{Area}}** — {{symptom the user saw}} is fixed. {{One-line note on what changed, if non-obvious.}}
- **{{Area}}** — {{symptom}} is fixed.
- **{{Area}}** — {{symptom}} is fixed.

---

### Deprecations & removals

- **{{Thing that's gone}}** — {{what replaced it, or why it was removed}}.
- **{{Thing that's gone}}** — {{replacement / rationale}}.

---

### Upgrade notes

- **App version bump:** `{{prev}}` → `{{this}}`.
- **In-app migrations:** {{list each one-shot migration that runs on first launch, and the condition that triggers it. Say "idempotent" if it's safe to re-run.}}
- **{{Platform-specific action, if any}}:** {{e.g. "Android users on pre-5.0 must uninstall once before installing; future updates install over the top."}}
- **{{External dependency}}:** {{e.g. "Supabase required for social features — purely-local usage unaffected."}}
- **{{Backwards-compat caveat}}:** {{e.g. "Listings published before this release won't have cover images until re-published."}}

---

### Known issues

- **{{Issue title}}** — {{what the user will observe, and whether it's deferred-by-design or a real bug tracked for a later release}}.
- **{{Issue title}}** — {{same treatment}}.
- **{{Issue title}}** — {{same treatment}}.

---

*Thanks for playing. Roll well.*

<!-- END RELEASE TEMPLATE -->

---

## Filling-in checklist

Before publishing, walk this list top to bottom:

- [ ] Version number matches `pubspec.yaml` and the git tag.
- [ ] Release date is the day the GitHub release is published, not the day the notes were drafted.
- [ ] GitHub release link and website link both resolve (no 404s).
- [ ] Every **Highlight** bullet has a corresponding detailed section below, and vice versa — no orphans in either direction.
- [ ] Every **Heads-up** callout is repeated in **Upgrade notes** with the exact action.
- [ ] No Supabase / backend migration file names appear anywhere in the note — they belong in the deployment doc, not here.
- [ ] **Bug fixes** only lists things a user could have observed — no "fixed flaky test", no "renamed internal widget".
- [ ] **Deprecations & removals** covers every removed UI surface, setting, exception type, or public flag.
- [ ] **Known issues** is not empty if there are known deferred items — honesty over polish.
- [ ] No placeholder `{{…}}` strings remain.
- [ ] Preview renders cleanly on GitHub (tables align, callouts render, no stray HTML).

---

## Suggested tweaks vs. the v5.0 note

A few additions baked into the template above that the v5.0 release note didn't have:

1. **Explicit `Downloads & source` line** right under the date, with both the GitHub release and the elymsyr.github.io links — previously the reader had to go hunt for the download.
2. **A dedicated `Bug fixes` section** separate from "Smaller improvements". v5.0 mixed polish and fixes into one bucket; splitting them makes it obvious at a glance what's new capability vs. what's a repair.
3. **A pre-publish checklist** at the bottom of this guide — catches the "migration file referenced in notes but not committed" class of mistake.
4. **`(Beta)` baked into the title line** so every release carries the beta tag consistently while the project is pre-1.0-stable, instead of appearing only in some places.

If any of these feel like overkill for a small patch release, it's fine to drop the corresponding section — just don't leave the heading behind empty.
