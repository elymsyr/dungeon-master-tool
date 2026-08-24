---
type: moc
domain: multiplayer
updated: 2026-08-24
tags: [moc]
---

# Multiplayer & Online — Map of Content

> [!summary] Scope
> Shared worlds: membership, invites, roles (owner/DM/player), auth, presence/heartbeat, character claiming. Rides on [[Sync-and-Realtime]] — specifically [[Share-Broadcast-Flow]] — for what actually reaches a player.

> [!warning] Beta programı kaldırıldı, online oyun herkese açıldı (2026-08-24)
> 90 slotlu, admin onaylı kapı yok. Uygulamayı indiren herkes tam erişimli. Hesap yalnızca üç şey için gerekli: **online oynamak**, **marketplace'e paylaşmak**, **başka kullanıcıların içeriğini indirmek**. Resmi katalog ve gezinme hesapsız açık.
>
> Aynı geçişte oyuncunun aldığı veri de daraldı: dünyanın tamamı değil, yalnızca DM'in paylaştıkları. Migration **076** (beta) + **077** (mirror).

## Key Files
- [[world_member]] · [[world_invite]] · [[world_role]] — online membership models.
- [[world_membership_service]] · [[supabase_world_membership_service]] — member CRUD via RPC.
- [[world_membership_provider]] — fetch members/invites/roles.
- [[world_members_dao]] · [[world_invites_dao]] — local mirror.
- [[world_join_service]] — accept invite → membership.
- [[character_claim_service]] — claim/release a PC from the pool.
- [[auth_provider]] — Supabase auth state.
- [[route_access]] — rota başına "bu hesap ister mi" kararı (O1); misafir yerel her ekrana girer, yalnız `/profile` ve `/admin` kapalıdır.
- [[guest_mode_provider]] — "hesapsız devam et" seçiminin kalıcılığı (O1).
- [[account_gate]] — "bu yüzey hesap ister mi" tek yüklemi + yüzey tablosu (O2); misafir/offline-build/oturumlu üç durumu adlandırır.
- [[account_gated_surface]] — kapılı yüzeyin çizimi: misafire giriş çağrısı, auth'suz build'de hiç (O2).
- [[guest_promotion_service]] — misafir ağacının hesaba devri (O3): DB kapalıyken kopya, yollar yeniden yazılır, sentinel en sonda.
  O4 devamı: ağaç **bir kez** talep edilir (`.guest_claimed`), talep onu `guest_archive/<ts>/`'e taşır, çıkış temiz bir misafir alanına iner, ikinci hesap hiçbir şey soğuramaz.
- [[heartbeat_service]] — keep `profiles.last_active_at` fresh (15 min).

## Data Flow
Invite (Supabase RPC) → [[world_join_service]] → `world_members` row → CDC → [[world_members_dao]] local mirror → [[world_membership_provider]] UI. Character ownership via [[character_claim_service]].

Katılan oyuncu **boş** bir dünya kabuğu alır (`worlds.state_json` 077'de düştü); içerik DM paylaştıkça gelir. Neyin aktığı: [[Share-Broadcast-Flow]].

## Related Domains
- [[Sync-and-Realtime]] (replication) · [[Backend-Infra]] (RLS, RPC) · [[World-and-Content]] (what's shared).

## Source Docs
- `online_multiplayer_initiative`, `multiplayer_visibility_realtime_may14`, `char_tab_ownership_may14`. (`beta_*` notları tarihsel — program kapandı.)
