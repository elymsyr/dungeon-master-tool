---
type: file-note
domain: content-pipeline
path: flutter_app/tool/check_findings.py
layer: tool
language: python
status: stable
updated: 2026-08-17
tags: [file]
---

# `check_findings.py`

> [!abstract] Primary Purpose
> Makes Stage **F2**'s exit criterion runnable instead of remembered. That criterion — *"every entry carries a checklist item, an affected-entity count, reproducible evidence, a proposed cause code and options"* — has to hold across a sweep of **20 packs, one session each**, in a ledger no compiler ever reads. This tool reads `flutter_app/docs/pack_conformance_findings.md` and fails if an entry is missing any of those, or if the three summary counters have drifted from the real entries. Where [[scan_pack]] is the sweep's reading tool, this is its bookkeeping gate.

## Inputs / Outputs
**Inputs**
- `python3 tool/check_findings.py` — validates the ledger; exit 1 with one `HATA:` line per problem.
- `python3 tool/check_findings.py --selftest` — asserts the live ledger is clean *and* that a deliberately malformed entry still trips six separate checks, so the validator cannot silently become a no-op.
- Reads one markdown file. Writes nothing, touches no pack.

**Outputs** — stdout plus an exit code, for a human at the end of a scan session (plan §"Sonraki adım").

## Dependencies & Links
- Ledger: `flutter_app/docs/pack_conformance_findings.md` · yardstick: `pack_conformance_checklist.md` · procedure: `pack_conformance_plan.md`
- Sibling: [[scan_pack]] (the F1 tool this one is modelled on)
- Domain map: [[Content-Pipeline]]

## Key Logic / Variables
- **`ITEMS`, `SCOPES`, `CODES` are the closed vocabularies** — 31 checklist ids (cross-checked against the checklist's own 31 `###` headings), `pass0` + `builtin` + the 19 pack slugs (cross-checked against `assets/open5e_packs/`), and the roadmap §1 cause codes `S L M D P N` **plus `A`**. `A` exists because F2 measured that all six roadmap codes describe *content loss* landing in the importer, while checklist groups **E/F/G** are app-side findings whose fix lands in `presentation`/`application`/`catalog_publish`.
- **Exactly one checklist item per entry.** Not style — the per-item counter cannot be summed otherwise, and the counter check enforces it.
- **Counters are read only from the `## Özet sayaçlar` section.** An entry may carry its own distribution table (the "yayılan bulgu" rule: one cause across several packs is filed once under `pass0`, with a `paket | etkilenen` table), and those rows are *not* tallies. The first version of the parser swallowed them and reported 85 findings against an empty ledger.
- **`F-kuru-*` entries are validated but never counted.** The template's worked example is a real measurement of a *known-open* gap (roadmap known-open #4 — 93 spells with no `class_refs`, 85 with no class tag either, `{deepm: 75, kp: 7, a5e-ag: 3}`), deliberately chosen because K7 says a documented gap is not a finding — so the format stays exercised on every run without the ledger acquiring a fake entry.
