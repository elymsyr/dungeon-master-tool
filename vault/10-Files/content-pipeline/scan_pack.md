---
type: file-note
domain: content-pipeline
path: flutter_app/tool/scan_pack.py
layer: tool
language: python
status: stable
updated: 2026-08-17
tags: [file]
---

# `scan_pack.py`

> [!abstract] Primary Purpose
> The **reading** half of Stage F's per-pack sweep, where [[audit_packs]] / [[dupe_census]] / [[gate_packs]] / [[verify_packs]] are the counting half. Those four answer *"is the field filled / does it collide / does it hang together / does it match the source"* corpus-wide; this one opens **one** `*.pkg.json` far enough for a human to judge whether the filled value is the **right** value — inside a reading budget, so a 3.3 MB pack never has to be read whole. Procedure: `flutter_app/docs/pack_conformance_plan.md` §4 (audit phase **F1**).

## Inputs / Outputs
**Inputs**
- `python3 tool/scan_pack.py <slug|path>` — category map, entity total, a ready-to-paste `--only` list for the `--packs` isolation step, and the `metadata` block (checklist **A1, B5, G1–G3**).
- `python3 tool/scan_pack.py <slug> --cat <category> [--picks N]` — per-field fill table for that category (**A2, C1–C5**; a schema field absent from the table is `0/n` → **C8** candidate) then the sample: first, last and three interior entities, chosen **by index** so a re-run reads the same rows.
- `python3 tool/scan_pack.py --selfcheck` — asserts the pack file shape and two pinned facts before a sweep trusts the tool.
- Reads `assets/open5e_packs/open5e-<slug>.pkg.json` only. No snapshot, no Dart, no DB.

**Outputs** — stdout for a human. Nothing is written; the sweep changes no content (audit rule K1/F4).

## Dependencies & Links
- Related: [[audit_packs]] (the counting sibling; this tool prints its `--only` argument), [[emit]] (the asset shape it decodes).
- Domain map: [[Content-Pipeline]]

## Key Logic / Variables
- **It exists because the plan's four inline snippets did not run** (F1, 2026-08-17). They called `python` (only `python3` is installed), iterated `d['entities']` as a **list** when the emitted shape is an **id → entity map**, and read `e['fields']` / `e['category']` when [[emit]] writes **`attributes`** / **`type`**. A transcriber who fixed only the crash would have measured every field as empty and filed *"this pack is blank"* against all 20 scan units.
- **Scalar arrays are folded onto one line, and that is what makes the budget real.** Raw `json.dumps(indent=1)` spends one line per uuid in `trait_refs` / `action_refs` / `skill_bonuses.rows`, so five monsters cost **691 lines** — one category over the whole ~600-line per-pack budget, and `open5e-tob3`'s four categories **872**. Folded: the same sample is **285**, the whole pack **433**. Per-entity cost by category is tabulated in the plan's §4.
- `--selfcheck` pins two things a silent change would otherwise hide: the `tdcs` shape (35 entities, `trait` 11 / `monster` 4, every entity carrying `attributes`), and `vom`'s `cost_gp` being **`null` on all 1,063 rows** — the fact F1 corrected in checklist **C5**, which had read §5.8's `MagicItem.cost = 0.00` as a *shipped* value rather than a *source* column.
- Long values are elided at 400 chars and list bodies after 3 items (`… +n`) — a monster's 18-row `skill_bonuses` is structure, not content, and reading all of it 20 times buys nothing.
