# Latest Changes (Post-Release)

This document tracks updates made **after the latest tagged release**.

## Baseline

- Latest release tag: `alpha-v0.8.3`
- Release commit: `a0b7568`
- Tracking window: `alpha-v0.8.3..HEAD`

---

## Delivered Since v0.8.3

### Phase 4 — Architecture Patterns (IMPROVEMENT_ROADMAP.md)

#### Adım 2 — API Client Consolidation ✅
- `core/api/` paketi oluşturuldu: `__init__.py`, `client.py`, `base_source.py`, `dnd5e_source.py`, `open5e_source.py`, `field_mappers.py`, `entity_parser.py`
- `core/api_client.py` backward-compat facade olarak bırakıldı
- `parse_monster()` mantığı ortak `entity_parser.py`'ye taşındı

#### Adım 3 — NpcSheet + CombatTracker Decomposition ✅
- `NpcSheet` (1497 LOC) → orchestrator facade (~530 LOC) + 4 sub-widget:
  - `ui/widgets/npc_sheet_stats_tab.py` — STR/DEX/…, combat stats, defense
  - `ui/widgets/npc_sheet_actions_tab.py` — traits, actions, reactions, legendary
  - `ui/widgets/npc_sheet_inventory_tab.py` — inventory/items
  - `ui/widgets/npc_sheet_spells_tab.py` — spells
  - `ui/widgets/npc_sheet_helpers.py` — shared `make_section`, `create_feature_card`, `clear_section`
- `CombatTracker` (~632 LOC) → thin coordinator + 2 sub-widget:
  - `ui/widgets/combat_combatant_list.py` — table, row rendering, HP editing
  - `ui/widgets/combat_controls.py` — encounter selector, turn nav, quick-add form

#### Adım 4 — MVP/Presenter ✅
- `ui/presenters/__init__.py` (package)
- `ui/presenters/combat_presenter.py` — `CombatPresenter(QObject)`: tüm encounter/turn/combatant iş mantığı, signal forwarding
- `ui/presenters/npc_presenter.py` — `NpcPresenter(QObject)`: load/save/discard/delete lifecycle

#### Adım 5 — Inline CSS Cleanup ✅
- `themes/common.qss` oluşturuldu — 7 objectName-based QSS kuralı
- `config.py` `load_theme()` her temaya `common.qss` ekleyecek şekilde güncellendi
- Taşınan `setStyleSheet()` → `setObjectName()`:
  - `ui/widgets/combat_controls.py` — `roundLabel`
  - `ui/widgets/npc_sheet_helpers.py` — `featureCardTitle`
  - `ui/widgets/npc_sheet_stats_tab.py` — `statAbbrev`
  - `ui/widgets/linked_entity_widget.py` — `linkedEntityName`, `linkedEntityCard`
  - `ui/dialogs/timeline_entry.py` — `timelineQuickBtn`
  - `ui/dialogs/import_window.py` — `importTitle`

### Bug Fixes

- **NpcSheet startup crash** (`AttributeError: 'NpcSheet' object has no attribute 'grp_combat_stats'`):
  `update_ui_by_type()` `init_ui()` içinden çağrıldığı için backward-compat aliaslar `init_ui()` çağrısından önce atanacak şekilde sıra düzeltildi.

- **MarkdownEditor double-click edit mode bypass**:
  `session_tab.py` ve `mind_map_tab.py` global edit mode kapatıldığında `set_inline_switch_enabled(False)` çağırmıyordu. Düzeltildi — artık viewer'a çift tıklayınca edit moduna girmiyor.

---

## Files Updated in This Window

| Dosya | Değişiklik |
|-------|-----------|
| `core/api/__init__.py` | YENİ |
| `core/api/client.py` | YENİ |
| `core/api/base_source.py` | YENİ |
| `core/api/dnd5e_source.py` | YENİ |
| `core/api/open5e_source.py` | YENİ |
| `core/api/field_mappers.py` | YENİ |
| `core/api/entity_parser.py` | YENİ |
| `core/api_client.py` | backward-compat facade |
| `ui/widgets/npc_sheet.py` | decompose + orchestrator |
| `ui/widgets/npc_sheet_stats_tab.py` | YENİ |
| `ui/widgets/npc_sheet_actions_tab.py` | YENİ |
| `ui/widgets/npc_sheet_inventory_tab.py` | YENİ |
| `ui/widgets/npc_sheet_spells_tab.py` | YENİ |
| `ui/widgets/npc_sheet_helpers.py` | YENİ |
| `ui/widgets/combat_tracker.py` | thin coordinator |
| `ui/widgets/combat_combatant_list.py` | YENİ |
| `ui/widgets/combat_controls.py` | YENİ |
| `ui/presenters/__init__.py` | YENİ |
| `ui/presenters/combat_presenter.py` | YENİ |
| `ui/presenters/npc_presenter.py` | YENİ |
| `themes/common.qss` | YENİ |
| `config.py` | `load_theme()` güncellendi |
| `ui/widgets/linked_entity_widget.py` | CSS cleanup |
| `ui/dialogs/timeline_entry.py` | CSS cleanup |
| `ui/dialogs/import_window.py` | CSS cleanup |
| `ui/tabs/session_tab.py` | edit mode fix |
| `ui/tabs/mind_map_tab.py` | edit mode fix |

---

## Validation Notes

- `python3 -m py_compile` — tüm değiştirilen dosyalar temiz
- `python3 -m pytest tests/test_core/ -q` — 39/39 geçti
- `python3 main.py` — uygulama açılıyor, startup crash giderildi
