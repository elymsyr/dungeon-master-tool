# Latest Changes (Post-Release)

This document tracks updates made **after the latest tagged release**.

## Baseline

- Latest release tag: `alpha-v0.8.4`
- Release commit: *(to be filled after tagging)*
- Tracking window: `alpha-v0.8.4..HEAD`

---

## Delivered Since v0.8.4

### Entity Card Editing Fix (Bug Fix)
- **field_widget_factory.dart** — 7 field widget (Text, TextArea, Integer, StatBlock, CombatStats, GenericList, Dice) `StatelessWidget` → `StatefulWidget` dönüştürüldü. `TextEditingController` + `didUpdateWidget` pattern uygulandı; `ValueKey`'lerden value kaldırıldı. Artık her keystroke'ta widget yeniden oluşturulmuyor, focus/cursor kaybı yaşanmıyor.
- **entity_card.dart** — 5 `FocusNode` eklendi, controller sync `_syncIfNotFocused()` ile korunuyor: field focus'tayken provider rebuild controller'ı ezmiyor.

### Mind Map Scroll Fix (Bug Fix)
- **mind_map_notifier.dart** — `isPointOverScrollableNode()` eklendi (entity/note node bounds check).
- **mind_map_canvas.dart** — `Listener.onPointerSignal` artık scroll event'i entity/note node üzerindeyse canvas zoom'a göndermiyor; node içindeki `SingleChildScrollView` scroll'u alabiliyor.

### Entity Card Integration (Feature)
- **session_screen.dart** — Entity Stats tab (tab 3) artık tam `EntityCard` widget'ı gösteriyor. `ref.listen` ile `nextTurn()` sırasında otomatik olarak sıradaki combatant'ın entity'si seçiliyor ve tab 3'e geçiliyor.
- **mind_map_node_widget.dart** — Entity node'ları artık inline `EntityCard` gösteriyor (eski custom text/chip rendering kaldırıldı).
- **mind_map_canvas.dart** — `worldSchemaProvider` watch eklendi, `categorySchemas` node widget'lara geçiriliyor.

---

## Validation Notes

- `flutter analyze` — 0 error (12 pre-existing info/warning)
- Database tab'da entity edit: focus kaybolmuyor, text geri dönmüyor
- Mind map'te entity/note node'da scroll: canvas zoom olmuyor
- Session Entity Stats tab: EntityCard gösteriliyor, nextTurn auto-select çalışıyor
