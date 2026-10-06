---
type: file-note
domain: combat-vtt
path: flutter_app/lib/presentation/widgets/dice/dice_log.dart
layer: presentation
language: dart
status: active
updated: 2026-10-06
tags: [file]
---

# `dice_log.dart`

> [!abstract] Primary Purpose
> Zar atışlarının oturum günlüğüne (session tab'daki chat log) düşmesi: serbest zar, skill check, saving throw. Satırda kullanıcı adı, karakter adı ve ne atıldığı yazar, örneğin `eren (Thorin) — Stealth check: 17 (d20: 12 + 5)`. DM'in atışları (ve çevrimdışı kullanıcınınkiler) doğrudan günlüğe yazılır. Online oyuncunun atışı `log_dice_roll` RPC'siyle (migration 106) DM'e gider.

## Inputs / Outputs
**Inputs**
- `DiceRollView.onRolled` → `DiceLogger.log(kind, label, character, total, detail)` ([[dice_physics]]: `rollDice` ve `DiceFab` menüsü).
- `activeCampaignIdProvider`, `currentWorldRoleProvider`, `authProvider`, `combatCharactersProvider` (oyuncunun serbest zarı için kendi karakteri), `currentProfileProvider` (DM'in kullanıcı adı), `localeProvider`.
- DM: `WorldSyncService.events` → `world_dice_rolls` INSERT; `worldMembersProvider(worldId)` (user_id → username).

**Outputs**
- `DiceRollKind` (`roll` | `skill` | `save`), `diceLogLine(l10n, ...)` (saf, test edildi).
- `diceLoggerProvider` / `DiceLogger`.
- `dmDiceLogProvider` (`Provider<void>`, `main_screen.dart` kuruyor).
- `combatProvider.addLog(line)`; Supabase `log_dice_roll` (oyuncu).

## Dependencies & Links
- Depends on: [[combat_provider]], [[world_sync_service]], [[migrations-online-worlds]] (106)
- Used by: [[dice_physics]] (`dice_fab.dart`), `field_widget_factory.dart` (proficiency table: `save_bonuses`/`saving_throws` → save, diğerleri skill; `entityName` karakter adı), `main_screen.dart`
- Domain map: [[Combat-and-VTT]]
- System flow: [[Share-Broadcast-Flow]]

## Key Logic / Variables
- Atış, sonuç **belli olur olmaz** günlüğe yazılır/gönderilir (`DiceRollView.onRolled`, simülasyon ~90 ms). Sonuç atıştan önce `Random` ile seçildiği için zarların inmesini (animasyon 1–3 sn) beklemiyor. Kalan gecikme ağ tarafında: RPC → INSERT → postgres_changes (genelde birkaç yüz ms).
- Açık dünya yoksa (`activeCampaignId` null) hiçbir şey yazılmaz.
- Rol `player` → RPC; karakter verilmemişse (serbest zar) oyuncunun bu dünyadaki ilk kendi karakteri. Hata yalnız `debugPrint`: kuyruk/yeniden deneme yok, günlük kaydı kaybı kabul.
- DM satırı kendi dilinde biçimler (`lookupL10n(localeProvider)`); RPC yapılandırılmış alan taşır (tür, etiket, toplam, döküm), metin değil.
- Sunucu: satırın sahibi `auth.uid()` (başkası adına yazılamaz), karakter adı istemcinin beyanı. Satırı yalnız DM okur. Her yazma o dünyanın 1 saatten eski satırlarını siler.

## Notes
- DM'in kendi atışlarında karakter yalnız tablo satırından gelir (karakter/canavar kartı adı); serbest zarda yalnız kullanıcı adı.
