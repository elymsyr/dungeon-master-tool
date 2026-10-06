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
- **DM hareket uygulama (`_applyMove`)**: yalnız `moved_at` dolu UPDATE ve şu anki iznin combatant/encounter'ı. Satırın `path` (107, `parseTurnPath`) ve `kind`'ı (`TurnMoveKind` move/leg/undo) okunur. DM'in battlemap notifier'ı yaşıyorsa (`ref.exists(battleMapProvider(enc))`) hareket ona gider: `applyRemoteMove(id, pos, via, newLeg)` izi oyuncunun yürüdüğü noktalarla uzatır (leg = yeni geri al durağı), gridSnap'i uygular, `persistTokenPositions`; `undoRemoteMove` DM'in geri al butonuyla aynı adımı atar (izi yoksa oyuncunun hedefine). Notifier yoksa eski yol: gridSnap (`(p/gs).round()*gs`) + `saveMapData` → `PendingWriteBuffer` (combatTick 500 ms debounce).
- **`TurnMoveSender`**: aynı anda tek RPC, iki çağrı arası ≥100 ms. `send(grant, pos, via:, newLeg:)` bekleyen hareketle birleşir — konum en sonuncu, `via` noktaları uç uca eklenir (hiçbir yürünen nokta kaybolmaz; 400'ü aşarsa her ikinci nokta atılarak inceltilir). Yeni sürükleme (`newLeg`) ve `undo(grant, target)` asla başka çağrıyla birleşmez, sırayla gider. RPC `false` dönerse (sıra geçti) o iznin bekleyenleri atılır ve `onRejected` izni düşürür (yalnız hâlâ aynı izinse, `identical`). Sunucuda 107 yoksa (`PGRST202`) bir kez yalnız konumla yeniden dener ve bundan sonra `p_path`/`p_kind` göndermez.
- **Güvenlik**: oyuncunun tabloya yazma politikası yok. Tek kapı `move_turn_token` (SECURITY DEFINER): `owner_id = auth.uid()` + combatant eşleşmesi + üyelik, pozisyon `BETWEEN -1e6 AND 1e6` (NaN/∞ reddedilir). anon EXECUTE yok. SELECT yalnız DM + sahip.

## Notes
- Oyuncu UI (`battle_map_projection_view.dart`, yalnız `interactive`): "Sıra sende" bandı + geri al, kendi token'ında yeşil halka. Sürükleme `Listener` ile (gesture arena dışında), basılıyken `InteractiveViewer` pan/zoom kapalı. Bırakınca yerel pozisyon yayın ≤0.75 hücre yaklaşana ya da 2 sn dolana kadar tutulur. Yerel iz DM'in `TokenMove` modelinin aynısı (`_ownPath` + `_ownStops`): sürükleme başında yayındaki iz (`snapshot.trail`, aynı token ise) tohum olur, ilk hareket yeni durak açar (`newLeg`), çeyrek hücrede bir örneklenen noktalar `via` olarak gönderilir — DM aynı noktalardan aynı izi kurar. Tutma bitince yerel iz bırakılır, yayındaki iz gösterilir. Geri al son durağa döner (DM'in `_dropLastStop`'unun aynısı) ve `undo` gönderir. Oynamıyorken oyuncu yayındaki izi görür (DM'in oynattığı token'lar ve diğer oyuncuların turları dahil).
- Bilinen eski sorun (dokunulmadı): oyuncu painter'ının aktif tur vurgusu `turnIndex`'i token listesi indeksi sanıyor. Gizli token varsa kayıyor.
