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

### Phase 3 — UI Consistency (IMPROVEMENT_ROADMAP.md)

#### Theme Background Color Fix ✅
- All 11 theme `.qss` files: `QComboBox` and `QSpinBox` added to `featureCard` transparent rule
- `themes/common.qss`: `QLabel`, `QListWidget`, `:focus` transparency rules added for `#sheetContainer`
- Fixes visible background mismatch on Name/Type/Source fields, Challenge Rating, spell contents across all themes

#### Spells Tab Refactoring ✅
- Manual spells section (`LBL_MANUAL_SPELLS` QGroupBox) removed entirely
- `ui/dialogs/manual_spell_dialog.py` created — dialog with spell fields + "Save to database" checkbox
- `LinkedEntityWidget` extended with custom entry API (`add_custom_entry`, `get_custom_entries`, etc.)
- `Manual Add` button added to spells list header (emits `manual_add_requested` signal)
- Custom (inline) spells now render in the same list as DB-linked spells
- `npc_sheet_spells_tab.py` completely rewritten — simplified to ~80 LOC from ~257 LOC

#### Height/Width Auto-Sizing ✅
- `list_residents`: removed `setMaximumHeight(80)`, added auto-fit height pattern
- `list_battlemaps`, `list_pdfs`: size policy changed from `Preferred` to `Expanding`
- `LinkedEntityWidget`: QGroupBox and QListWidget → `Expanding` horizontal policy
- Horizontal scrollbar disabled, word wrap enabled on linked entity lists
- `make_section()` in helpers: `Preferred` → `Expanding`

#### Button Standardization ✅
- HP +/- buttons: inline `setStyleSheet()` removed, themed via QSS objectNames (`hpDecreaseBtn`/`hpIncreaseBtn`)
- HP button colors added to all 11 theme files (theme-appropriate red/green)
- `compactBtn` class added to `common.qss` for small icon-only buttons
- Emoji buttons replaced with Qt standard icons:
  - `screen_tab.py`: ↑/↓ → `SP_ArrowUp`/`SP_ArrowDown`
  - `pdf_viewer.py`: ◀/▶ → `SP_ArrowBack`/`SP_ArrowForward`
  - `api_browser.py`, `import_window.py`: </> → `SP_ArrowBack`/`SP_ArrowForward`
- Combat controls: `btn_quick_add` → `successBtn`, `btn_add` → `successBtn`, `btn_add_players` → `primaryBtn`, `btn_roll` → `primaryBtn`
- All small icon buttons standardized to 28×28
- Combat table: Init/AC columns `ResizeToContents`, HP/Conditions `Stretch`, Init/AC cells center-aligned

#### Battle Map Toolbar Layout ✅
- DM toolbar split from 1 row into 2 rows: tools+actions (Row 2), grid controls (Row 3)
- Tool/action buttons get full row width — text no longer clipped in some themes

#### Right-Side PDF Panel ✅
- `ui/pdf_panel.py` created — collapsible right-side PDF viewer panel (like soundpad)
- `PdfViewerWidget` lazy-loaded on first use
- Toggle button (file icon) added to main toolbar
- Soundpad and PDF panel are mutually exclusive — opening one closes the other
- `pdf_manager.py`: "Project PDF" button added with `project_requested` signal
- Signal chain: pdf_manager → DatabaseTab → MainWindow → pdf_panel
- PDF list: horizontal scrollbar disabled, long names elide with `…`

#### PDF Viewer Improvements ✅
- Middle-mouse button drag to pan/scroll PDF pages
- Removed "Folder…" button — only "Open…" remains
- Arrow emoji buttons replaced with Qt standard icons (previous session)

#### Toolbar Edit Button Fix ✅
- Edit mode button: removed `setFixedSize(28,28)`, added text label `"✏️ Edit"` for consistent sizing with other toolbar buttons

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
| `ui/widgets/npc_sheet.py` | decompose + orchestrator + transparency fix + height fix |
| `ui/widgets/npc_sheet_stats_tab.py` | YENİ |
| `ui/widgets/npc_sheet_actions_tab.py` | YENİ |
| `ui/widgets/npc_sheet_inventory_tab.py` | YENİ |
| `ui/widgets/npc_sheet_spells_tab.py` | YENİ → complete rewrite (manual spells removed) |
| `ui/widgets/npc_sheet_helpers.py` | YENİ + Expanding size policy |
| `ui/widgets/combat_tracker.py` | thin coordinator |
| `ui/widgets/combat_combatant_list.py` | YENİ + column resize + text alignment |
| `ui/widgets/combat_controls.py` | YENİ + objectNames + button sizes |
| `ui/widgets/combat_table.py` | HP buttons themed via QSS, progress bar styling |
| `ui/widgets/linked_entity_widget.py` | CSS cleanup + custom entries + manual add + width fix |
| `ui/widgets/pdf_manager.py` | Expanding size policy + Project PDF button + elide mode |
| `ui/widgets/pdf_viewer.py` | YENİ + emoji→icon + middle-mouse drag + Folder btn removed |
| `ui/pdf_panel.py` | YENİ — right-side collapsible PDF viewer panel |
| `ui/presenters/__init__.py` | YENİ |
| `ui/presenters/combat_presenter.py` | YENİ |
| `ui/presenters/npc_presenter.py` | YENİ |
| `ui/dialogs/manual_spell_dialog.py` | YENİ |
| `ui/dialogs/api_browser.py` | CSS cleanup + emoji→icon |
| `ui/dialogs/import_window.py` | CSS cleanup + emoji→icon |
| `ui/dialogs/timeline_entry.py` | CSS cleanup |
| `ui/tabs/screen_tab.py` | edit mode fix + emoji→icon |
| `ui/tabs/mind_map_tab.py` | edit mode fix |
| `ui/main_root.py` | button sizes + PDF panel + toggle btn + edit btn text |
| `ui/tabs/database_tab.py` | pdf_project_requested signal + connection |
| `ui/windows/battle_map_window.py` | toolbar split into 2 DM rows |
| `themes/common.qss` | YENİ + sheetContainer transparency + compactBtn + HP btn rules |
| `themes/dark.qss` | featureCard QComboBox/QSpinBox + HP btn colors |
| `themes/midnight.qss` | featureCard QComboBox/QSpinBox + HP btn colors |
| `themes/amethyst.qss` | featureCard QComboBox/QSpinBox + HP btn colors |
| `themes/light.qss` | featureCard QComboBox/QSpinBox + HP btn colors |
| `themes/baldur.qss` | featureCard QComboBox/QSpinBox + HP btn colors |
| `themes/discord.qss` | featureCard QComboBox/QSpinBox + HP btn colors |
| `themes/emerald.qss` | featureCard QComboBox/QSpinBox + HP btn colors |
| `themes/frost.qss` | featureCard QComboBox/QSpinBox + HP btn colors |
| `themes/grim.qss` | featureCard QComboBox/QSpinBox + HP btn colors |
| `themes/ocean.qss` | featureCard QComboBox/QSpinBox + HP btn colors |
| `themes/parchment.qss` | featureCard QComboBox/QSpinBox + HP btn colors |
| `config.py` | `load_theme()` güncellendi |
| `main.py` | toggle_pdf_panel + show_pdf_in_panel + mutual exclusion |
| `locales/en.yml` | +BTN_MANUAL_ADD, TITLE_MANUAL_SPELL, LBL_SAVE_TO_DB, BTN_PROJECT_PDF, BTN_TOGGLE_PDF_PANEL, LBL_PDF_PANEL_EMPTY |
| `locales/tr.yml` | +BTN_MANUAL_ADD, TITLE_MANUAL_SPELL, LBL_SAVE_TO_DB, BTN_PROJECT_PDF, BTN_TOGGLE_PDF_PANEL, LBL_PDF_PANEL_EMPTY |
| `locales/de.yml` | +BTN_MANUAL_ADD, TITLE_MANUAL_SPELL, LBL_SAVE_TO_DB, BTN_PROJECT_PDF, BTN_TOGGLE_PDF_PANEL, LBL_PDF_PANEL_EMPTY |
| `locales/fr.yml` | +BTN_MANUAL_ADD, TITLE_MANUAL_SPELL, LBL_SAVE_TO_DB, BTN_PROJECT_PDF, BTN_TOGGLE_PDF_PANEL, LBL_PDF_PANEL_EMPTY |

---

## Roadmap Completion Summary

### IMPROVEMENT_ROADMAP.md

| Phase | Status | Tamamlanma |
|-------|--------|-----------|
| Phase 1: Foundation | TAMAMLANDI | 100% |
| Phase 2: God Class Decomposition | TAMAMLANDI | 100% |
| Phase 3: UI Consistency | TAMAMLANDI | 100% |
| Phase 4: Architecture Patterns | TAMAMLANDI | 95% (ui/components/ minimal) |
| Phase 5: Testing & Documentation | DEVAM EDİYOR | 70% (13 test, coverage doğrulanmadı) |

### PRE_ONLINE.md

| Task | Status |
|------|--------|
| Task 1: GM Player Screen Control Panel | TAMAMLANDI |
| Task 2: Single Player Screen Window | TAMAMLANDI |
| Task 3: Auto Event Log During Combat | KISMİ |
| Task 4: Free Single Import | TAMAMLANDI |
| Task 5: Embedded PDF Viewer | TAMAMLANDI |
| Task 6: UI Standardization | TAMAMLANDI |
| Task 7: Soundpad Transition Smoothing | BAŞLANMADI |
| EventManager local dispatch | TAMAMLANDI (core/event_bus.py) |
| Socket.io client skeleton | KISMİ (bridge.py hazır, socket.io bekleniyor) |

### Kalan İşler

1. **Soundpad crossfade** (PRE_ONLINE Task 7) — henüz başlanmadı
2. **Socket.io client** — bridge skeleton hazır, gerçek socket.io entegrasyonu bekleniyor
3. **Test coverage doğrulama** — pytest-cov ile >=60% hedefi kontrol edilmeli
4. **Module docstrings** — eski dosyalarda eksik
5. **Auto Event Log genişletme** — combat log mevcut ama tam spec karşılanmamış

---

## Validation Notes

- `python3 -m py_compile` — tüm değiştirilen dosyalar temiz
- `python3 -m pytest tests/test_core/ -q` — 39/39 geçti
- `python3 main.py` — uygulama açılıyor, startup crash giderildi
