# Latest Changes (Post-Release)

This document tracks updates made **after the latest tagged release**.

## Baseline

- Latest release tag: `alpha-v0.8.4`
- Release commit: *(to be filled after tagging)*
- Tracking window: `alpha-v0.8.4..HEAD`

---

## Delivered Since v0.8.4

### Battle Map (Major Feature)
- **battle_map_screen.dart, battle_map_notifier.dart, battle_map_painter.dart** — Tam battle map sistemi: navigate, ruler, circle, draw, fog (add/erase) araçları, grid sistemi, token konumlandırma, fog of war, ölçüm kalıcılığı.
- **battle_map_toolbar.dart, battle_map_mobile_toolbar.dart** — Desktop ve mobil için toolbar widget'ları.
- **token_widget.dart** — Sürüklenebilir token widget'ı.
- **hp_bar.dart** — HP bar widget'ı.
- **resizable_split.dart** — Yeniden boyutlandırılabilir split panel widget'ı.

### Encounter System Enhancements (Feature)
- **encounter_config.dart** — `EncounterConfig`: combatStatsFieldKey, conditionStatsFieldKey, columns, conditions tanımları.
- **encounter_layout.dart** — `EncounterLayout`: özelleştirilebilir sütunlar ve sıralama kuralları.
- **encounter_column_dialog.dart** — Encounter sütun düzenleme dialog'u.
- **session_screen.dart** — `_MobileCombatCard` widget'ı, condition yönetimi (ekleme/çıkarma/süre güncelleme), entity-tabanlı condition'lar.
- **world_schema.dart** — `encounterLayouts` ve `encounterConfig` field'ları eklendi.

### Rule Engine & Computed Fields (Feature)
- **rule_engine.dart** — `RuleEngine` sınıfı: cache'li hesaplama, pullField/mergeFields/conditionalList operasyonları.
- **category_rule.dart** — `CategoryRule`, `RuleSource`, `RuleType`, `RuleOperation` enum'ları.
- **entity_category_schema.dart** — `rules` field'ı eklendi.

### Undo/Redo System (Feature)
- **undo_redo_mixin.dart** — `UndoRedoMixin`: pushUndo, popUndo, popRedo (max 50 state).
- **undo_redo_provider.dart** — Provider entegrasyonu.

### Epoch/Timeline Features (Feature)
- **epoch_scroll_bar.dart** — Yatay timeline scroll bar'ı.
- **epoch_waypoint_dialog.dart** — Epoch waypoint ekleme/düzenleme dialog'u.
- **timeline_entry_dialog.dart** — Timeline entry dialog'u.

### Trash Management System (Feature)
- **campaign_local_ds.dart** — `TrashItem` sınıfı, `listTrash()`, `restoreFromTrash()`, `permanentlyDeleteFromTrash()` metotları. Soft-delete: `.trash/` dizinine taşıma + `.meta.json` metadata dosyası.
- **campaign_provider.dart** — `trashListProvider` eklendi.
- **settings_tab.dart** — Trash bölümü: silinen dünyaların listesi, geri yükleme ve kalıcı silme butonları, 30 günlük otomatik temizlik bilgisi.

### World Metadata (Feature)
- **campaign_local_ds.dart** — Dünya oluşturulurken `world_id` (UUID v4) ve `created_at` timestamp kaydediliyor.
- **schema_migration.dart** — Mevcut dünyalar için UUID otomatik backfill. `migrate()` metodu `bool changed` accumulator pattern'ine geçirildi.

### PDF Field Type (Feature)
- **field_schema.dart** — `FieldType.pdf` enum değeri eklendi (15. alan tipi).
- **field_widget_factory.dart** — `_PdfFieldWidget`: PDF dosya seçme (FilePicker), listeleme, `xdg-open` ile açma, silme.
- **template_editor.dart** — PDF için display name (`PDF`), ikon (`picture_as_pdf`), list popup desteği.

### Template System (Feature)
- **template_provider.dart** — `customTemplatesProvider`, `allTemplatesProvider`.
- **template_local_ds.dart** — Custom template'ler için CRUD operasyonları.

### Import/Export (Feature)
- **import_dialog.dart** — Entity/data import dialog'u.

### Entity Sidebar (Feature)
- **entity_sidebar.dart** — Entity sidebar widget'ı.

### Audio Track Foundation (Feature)
- **audio_models.dart** — `AudioTrack` (id, name, filePath, trackType, volume, loop), `SoundpadTheme`. Soundpad sistemi için temel.

### App Initialization & Routing (Refactor)
- **main.dart** — `AppPaths` initialization, window manager setup (800×600 min), `UiState` loading.
- **app_router.dart** — GoRouter: `/`, `/hub`, `/main` route'ları.
- **Localization** — `app_en.arb`, `app_tr.arb`, `app_de.arb`, `app_fr.arb` i18n dosyaları.

### Combat Stale State Fix (Bug Fix)
- **combat_provider.dart** — `combatProvider`'a `ref.watch(activeCampaignProvider)` eklendi. Dünya değiştirdiğinde eski encounter state'inin kalması sorunu giderildi.

### Condition Badge Styling (UI)
- **condition_badge.dart** — Duration badge'ından background color ve border kaldırıldı.

### Entity Card Editing Fix (Bug Fix)
- **field_widget_factory.dart** — 7 field widget `StatelessWidget` → `StatefulWidget` dönüştürüldü. `TextEditingController` + `didUpdateWidget` pattern uygulandı; her keystroke'ta widget yeniden oluşturulmuyor, focus/cursor kaybı yaşanmıyor.
- **entity_card.dart** — 5 `FocusNode` eklendi, controller sync `_syncIfNotFocused()` ile korunuyor.

### Mind Map Scroll Fix (Bug Fix)
- **mind_map_notifier.dart** — `isPointOverScrollableNode()` eklendi.
- **mind_map_canvas.dart** — Scroll event'i entity/note node üzerindeyse canvas zoom'a gönderilmiyor.

### Entity Card Integration (Feature)
- **session_screen.dart** — Entity Stats tab tam `EntityCard` widget'ı gösteriyor. `ref.listen` ile `nextTurn()` sırasında otomatik combatant entity seçimi.
- **mind_map_node_widget.dart** — Entity node'ları inline `EntityCard` gösteriyor.
- **mind_map_canvas.dart** — `worldSchemaProvider` watch eklendi.

---

## Validation Notes

- `dart analyze` — 0 error (14 pre-existing info/warning)
- Database tab'da entity edit: focus kaybolmuyor, text geri dönmüyor
- Mind map'te entity/note node'da scroll: canvas zoom olmuyor
- Session Entity Stats tab: EntityCard gösteriliyor, nextTurn auto-select çalışıyor
