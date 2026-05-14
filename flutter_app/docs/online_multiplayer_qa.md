# Online Multiplayer — Manual QA Checklist

PR-O1..O11 (2026-05-13) ile gelen online multiplayer foundation için
end-to-end test rehberi. İki Flutter instance (veya iki farklı kullanıcı
hesabıyla iki cihaz) ile koşulur.

## Ön gereksinimler

- Supabase `migrations/026_online_worlds.sql` apply edilmiş olmalı.
- `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` ile
  build alınmalı (offline modda online özellikler kilitli).
- İki ayrı Supabase user (DM hesabı + Player hesabı).

## Senaryo 1 — World publish + invite

DM:
1. Hub → Worlds → "Create New World" ile yeni dünya oluştur.
2. Dünyaya tıkla → ⚙ → Online bölümü → "Make Online".
3. "Invite codes" → "New invite" → 8 karakter base32 kod gözükmeli.
4. Kodu kopyala.

Player:
1. Hub → Worlds → "Join" → kodu yapıştır → "Join".
2. World hub listesinde belirmeli.
3. World'e double-click → main screen player varyantı açılır.
4. Üst-sağda **PLAYER** badge görünmeli.

## Senaryo 2 — Entity realtime sync

DM:
1. Worldü aç. Database tab'inde yeni entity oluştur (örn. yeni NPC).
2. Adını/açıklamasını düzenle. Otomatik save bekle (~1-2 sn).
3. Entity card üstündeki share ikonu → "Share with all players" toggle aç.

Player:
1. Database tab'a geç. Az önce paylaşılan entity sidebar listesinde belirmeli.
   - **Realtime test**: DM share toggle'ı açar açmaz player sayfasında <2sn'de
     görünmeli (manual refresh gerekmemeli).
2. Player paylaşılmamış başka entity'leri **görmemeli**.

## Senaryo 3 — Karakter akışı

DM:
1. Right sidebar → Characters → yeni karakter oluştur.
2. Karakter satırına sağ tık → "Assign to player..." → player'ı seç.

Player:
1. Character tab'i aç. Karakter listede gözükmeli (sadece kendi karakterleri).
2. Karaktere tıkla → editor açılmalı, düzenlemeler save olur.
3. DM tarafında karakter sidebar'da player'ın değişiklikleri yansımalı.

DM (claim pool):
1. Başka bir karakter sağ tık → "Make available for claim".

Player:
1. Character tab'in üstünde **Available characters** kutusu belirmeli.
2. "Claim" → karakter ownerId player'a atanır, listeye eklenir, pool'dan
   kaybolur.

## Senaryo 4 — Mind map izolasyonu

DM:
1. Mind map tab'da nodes ekle. Default map'e yazılır.

Player:
1. Mind map tab'i aç. DM'in node'larını **görmemeli** — boş canvas.
2. Kendi node'larını ekleyebilmeli; bunlar `player_<uid>` map'inde saklanır.
3. DM tarafına player node'ları yansımamalı (privacy).

## Senaryo 5 — Soundmap salt-okunur

DM:
1. Soundmap sidebar → bir tema seç + müzik başlat.

Player:
1. Soundmap ikonu → sade sidebar açılır.
2. "Playing" badge yeşil, aktif tema adı görünür.
3. Track listesi / play-pause / upload yok.
4. Master volume slider'ı oynatılınca yalnızca player'ın cihazında ses
   seviyesi değişir (DM'in seviyesini etkilemez).

## Senaryo 6 — Offline davranış

Player:
1. Worldü açıkken Wi-Fi'yi kes.
2. Local düzenlemeler (kendi mind map, kendi karakter) sorunsuz devam etmeli.
3. Wi-Fi açılınca sync devam — uyuyan değişiklikler push edilir, DM
   tarafında <5sn içinde belirir.

DM:
1. Worldü açıkken bağlantıyı kes, entity oluştur/sil.
2. Bağlantı geri gelince state Supabase'e push olur. Player tarafı catch-up
   yapar.

## Senaryo 7 — Davet limitleri

DM:
1. Tek-kullanımlık invite oluştur. Player kodu kullanır → consumed.
2. Aynı kodu ikinci kez kullanmaya çalış → "Invite has no uses left".
3. DM dialog'da "Revoke" tıkla → kodu sil → kullanılamaz.

## Senaryo 8 — Leave / unpublish

Player:
1. World settings → "Leave World" → ondan ayrılır.
2. World hub listesinden kaybolur. Tekrar girmek için yeni invite gerekir.

DM:
1. World settings → "Make Offline" → onay → Supabase'den silinir.
2. Local data korunur. Tüm üyeler erişimi kaybeder. Tekrar online yaparsa
   member listesi sıfır.

---

## Bilinen sınırlamalar (PR-O11 sonrası)

- **Outbox queue yok**: offline yazımlar fire-and-forget, online geçince
  next save'de push olur. Tek tek silinen entityler offline'da kaydedilirse
  delete event kaybolabilir. (Outbox eklenecek follow-up PR.)
- **Per-entity character refs tracking**: player'lar sadece DM'in explicit
  paylaştığı entity'leri görür; "karakterin envanterindeki item otomatik
  görünür" özelliği henüz yok (PR-O6.5).
- **Mind map sync to Supabase**: per-player mapId routing var, RLS hazır,
  ama mirror push henüz mind_map_nodes/edges tablolarına yazmıyor (state_json
  blob içinde gidiyor — DM tarafından okunabilir).
- **Soundmap realtime sync**: player UI state lokal; DM'in tema değişimi
  player'a otomatik propagate olmuyor (sync provider eklenecek).
- **Game session / second screen**: Tab placeholder var, projection sync
  yok. Bu senaryo bir sonraki initiative.
- **PDF sidebar**: player'da widget-local state — uygulama kapanıp açılınca
  liste resetlenir. Persistence per (world, user) key follow-up.

## Otomatik test ideası

`flutter_app/test/online/`:
- `world_invite_redemption_test.dart` — RPC mock + Drift upsert.
- `entity_share_visibility_test.dart` — visibleEntityProvider filter.
- `world_mirror_echo_test.dart` — recently-pushed id'lerin echo suppression'ı.

Server tarafı için `pgtap` veya manuel `supabase test db` ile RLS coverage:
- DM yetkisi olmayan kullanıcı `world_entities` upsert deneyince reddedilir.
- Player sadece paylaşılmış entityler için SELECT alır.
- Player başka bir player'ın karakterini UPDATE edemez.
