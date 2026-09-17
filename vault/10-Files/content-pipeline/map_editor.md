---
type: file-note
domain: content-pipeline
path: flutter_app/tool/content/map_editor.py
layer: tool
language: python
status: stable
updated: 2026-09-17
tags: [file]
---

# `map_editor.py`

> [!abstract] Primary Purpose
> Offline editor for a bundled world's **map pins**. Serves a one-file browser UI
> from stdlib `http.server`, reads/writes the `map_data` block inside
> `world-blueprint.json`, and leaves everything else in the blueprint untouched.
> Authoring pins by hand in JSON was the alternative — pin coordinates are image
> pixels, so they have to be placed by eye.

## Inputs / Outputs
**Inputs**
- `--dir <world dir>` (required, the dir holding `manifest.json` + `world-blueprint.json`), `--port` (8777), `--no-browser`, `--selftest`.
- The one root map is the **active era's** `image_path`, picked from every image under the world's `media/` tree. Location maps come from the card itself: `map_per_era[<era id>]` → `map` → first `battlemaps` entry. Media files are served straight out of the world dir (path-traversal guarded).

**Outputs**
- `world-blueprint.json` rewritten with a top-level `map_data` key (atomic replace via `.tmp`).
- Root mirror (`image_path`/`pins`/`timeline`) is always rewritten from `eras[0]` on save — `world_map_notifier.init` reads the era list first but legacy readers use the root.
- `location` rows' `map_per_era` field, when a per-era image is assigned in the pin panel (the only place the editor writes outside `map_data`; an emptied map is removed, not left as `{}`).

## Dependencies & Links
- Consumed by [[bundled_worlds_installer]] (`map_data` → `world_map_data` Drift row), rendered by `world_map_screen` / `world_map_notifier`.
- Entity ids are uuidv5 with the **same namespace and key format** as [[world_blueprint_converter]] (`{package}:{slug}:{name.lower().trim()}`) — the constant is duplicated in Python and must be kept in sync.
- [[convert_blueprint]] ignores unknown top-level blueprint keys, so `--check` still passes with `map_data` present.

## Key Logic / Variables
- **Tek ana harita, drill-in pinden.** Yan panelde harita listesi yok: kök harita aktif era'nın `image_path`'i, alt haritalara bir pinin bağlı olduğu location üzerinden inilir (pin panelinde *Haritayı aç*), üste breadcrumb ile çıkılır. Düz bir harita listesi kökü yanlışlıkla değiştirmeye açıktı ve uygulamanın gezinme modeliyle uyuşmuyordu.
- **Era'lar tam destekli**: N era + N-1 `waypoints`, ad kuralı `world_map_notifier.eraNames` ile aynı (`era_start_label` … waypoint etiketleri … `era_end_label`). Era eklemek son era'yı böler (pinleri kopyalamak opsiyonel), `location_maps` era başına ayrı tutulur, era'ya özel görsel kartın `map_per_era[<era id>]` alanına yazılır — hepsi notifier'ın okuduğu şekil.
- Timeline pinleri hâlâ yazılmıyor (boş liste olarak taşınır); uygulamada ekleniyor.
- Nested maps are **flat storage**: `eras[0].location_maps[<location entity id>].pins`. Drill-in depth lives in the app's `locationStack`, not on disk, so an arbitrarily deep nesting needs no extra structure here.
- A pin's `entityId` + `pinType` (= the entity's category slug) are what make it a card link; pointing one at a `location` that has a `map` is what makes it drillable.
- Pin paneli kartın **özetini** gösterir (parent location, faction, durum, ref'ler). Alan seçimi kategori başına tablo değil, tek bir blocklist (`DETAIL_SKIP` — uzun düzyazı + medya) + 160 karakter kırpma; soft ref `{lookup, match, value}` `value`'suna indirgenir. Yeni bir kategori eklendiğinde kod değişmez.
- Kart seçimi native `<input list>` + `<datalist>` — yazarak aranır, `slug/name` anahtarıyla eşleşir (yalnız ad yazılırsa da bulunur), eşleşme yoksa pin bağsız kalır.
- `_selftest` asserts the uuidv5 normalisation, a multi-era save→reload round-trip (root mirror + per-era `location_maps` + waypoint/active index) and `apply_per_era` write/clear.
