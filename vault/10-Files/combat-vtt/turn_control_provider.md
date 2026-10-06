---
type: file-note
domain: combat-vtt
path: flutter_app/lib/application/providers/turn_control_provider.dart
layer: application
language: dart
status: stable
updated: 2026-10-06
tags: [file]
---

# `turn_control_provider.dart`

> [!abstract] Primary Purpose
> Online oyuncunun **kendi turunda kendi token'ını** oynatması. DM battlemap'i online yayınlarken encounter'ın sırası bir oyuncunun karakterine gelince, DM dünya başına tek satırlık bir izin yazar (`world_turn_control`, migration 105). Oyuncu token'ını yalnız `move_turn_token` RPC'siyle oynatır, sunucu da kimliği ve sırayı doğrular. DM hareketi encounter'a uygular, yayın her zamanki gibi `world_projection` üzerinden herkese gider. Onay adımı yok, akış canlı.

## Inputs / Outputs
**Inputs**
- DM: `projectionControllerProvider` (online çıkış açık mı, aktif öğe battlemap mi + snapshot), `combatProvider` (encounter, `turnIndex`/`round`), `combatCharactersProvider` (`Character.ownerId`), `activeCampaignIdProvider`, `currentWorldRoleProvider`, `authProvider`.
- DM: `WorldSyncService.events` → `world_turn_control` UPDATE (oyuncunun hareketi).
- Oyuncu: `myTurnGrantProvider` ← [[world_mirror_applier]] (seed + CDC).

**Outputs**
- `TurnGrant`: izin modeli (`key` = encounter|combatant|owner|`round/turnIndex`).
- `wantedTurnGrant(...)`: saf fonksiyon, DM durumunun gerektirdiği izin.
- `dmTurnControlProvider` (`Provider<void>`, `main_screen.dart` kuruyor): DM tarafı.
- `myTurnGrantProvider` (`StateProvider<TurnGrant?>`): oyuncu tarafı.
- `turnMoveSenderProvider` / `TurnMoveSender`: oyuncunun RPC göndericisi.
- Supabase: `world_turn_control` DELETE + INSERT (DM), `move_turn_token` RPC (oyuncu).
- DM'de `combatProvider.saveMapData` → yayın.

## Dependencies & Links
- Depends on: [[combat_provider]], [[projection_output_online]], [[world_sync_service]], [[migrations-online-worlds]] (105)
- Used by: `main_screen.dart` (kurulum), [[world_mirror_applier]] (oyuncu seed/CDC), `battle_map_projection_view.dart` (oyuncu UI)
- Domain map: [[Combat-and-VTT]] · [[Multiplayer-and-Online]]
- System flow: [[Share-Broadcast-Flow]]

## Key Logic / Variables
- **İzin kuralı (`wantedTurnGrant`)**: online çıkış açık, aktif projeksiyon öğesi `BattleMapProjection`, encounter'ın `turnIndex`'indeki combatant snapshot'ta görünüyor (gizli token snapshot'ta yok, izin de yok), karakterinin `ownerId`'si var ve DM değil. Origin = snapshot'taki token pozisyonu (oyuncunun geri alma hedefi).
- **DM yazımı (`_DmTurnControl.update`)**: `key` değişince **önce DELETE, sonra INSERT**. Eski sahip yeni satırı RLS yüzünden göremez, sırasının bittiğini yalnız DELETE event'inden öğrenir. Pozisyon key'de yok, oyuncu oynarken izin yeniden yazılmaz. İlk çağrı her durumda DELETE atar (çöken oturumdan kalan satır temizlensin). Yazmalar tek zincirde sıralı. Hata sonrası aynı izin en erken 5 sn sonra yeniden denenir: `update` her projeksiyon değişiminde (viewport 30 Hz) çağrılıyor, çevrimdışı DM bunu istek fırtınasına çevirmesin.
- **DM hareket uygulama (`_applyMove`)**: yalnız `moved_at` dolu UPDATE ve şu anki iznin combatant/encounter'ı. `encounter.gridSnap` açıksa DM'in kendi bırakmasıyla aynı kural (`(p/gs).round()*gs`). Kalıcılık `saveMapData` → `PendingWriteBuffer` (combatTick 500 ms debounce). DM ekranı açıksa notifier yalnız oynayan token'ı delta olarak alır ([[grid_canvas]]).
- **`TurnMoveSender`**: aynı anda tek RPC. Bekleyen konumlar en sonuncuya katlanır (kuyruk yok), iki çağrı arası ≥100 ms. RPC `false` dönerse (sıra geçti) bekleyen konum atılır ve `onRejected` izni düşürür (yalnız hâlâ aynı izinse, `identical`).
- **Güvenlik**: oyuncunun tabloya yazma politikası yok. Tek kapı `move_turn_token` (SECURITY DEFINER): `owner_id = auth.uid()` + combatant eşleşmesi + üyelik, pozisyon `BETWEEN -1e6 AND 1e6` (NaN/∞ reddedilir). anon EXECUTE yok. SELECT yalnız DM + sahip.

## Notes
- Oyuncu UI (`battle_map_projection_view.dart`, yalnız `interactive`): "Sıra sende" bandı + geri al (origin'e RPC), kendi token'ında yeşil halka. Sürükleme `Listener` ile (gesture arena dışında), basılıyken `InteractiveViewer` pan/zoom kapalı. Bırakınca yerel pozisyon yayın ≤0.75 hücre yaklaşana ya da 2 sn dolana kadar tutulur. Turun yolu (`_ownTrail`, origin'den yarım hücrede bir örneklenir) DM'deki gibi yeşil kesik iz + `ft · m` etiketiyle çizilir; geri al ve izin değişimi izi siler. İzin değişince yerel durum sıfırlanır.
- Bilinen eski sorun (dokunulmadı): oyuncu painter'ının aktif tur vurgusu `turnIndex`'i token listesi indeksi sanıyor. Gizli token varsa kayıyor.
