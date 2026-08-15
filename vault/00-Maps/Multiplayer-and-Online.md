---
type: moc
domain: multiplayer
updated: 2026-08-15
tags: [moc]
---

# Multiplayer & Online — Map of Content

> [!summary] Scope
> Shared worlds: membership, invites, roles (owner/DM/player), auth, presence/heartbeat, character claiming, and the beta-program gates. Rides on [[Sync-and-Realtime]] for state replication.

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
- [[heartbeat_service]] — keep `profiles.last_active_at` fresh (15 min).
- [[beta_enter_gate]] — beta entry merge gates (data-loss protection).

## Data Flow
Invite (Supabase RPC) → [[world_join_service]] → `world_members` row → CDC → [[world_members_dao]] local mirror → [[world_membership_provider]] UI. Character ownership via [[character_claim_service]].

## Related Domains
- [[Sync-and-Realtime]] (replication) · [[Backend-Infra]] (RLS, RPC) · [[World-and-Content]] (what's shared).

## Source Docs
- `online_multiplayer_initiative`, `multiplayer_visibility_realtime_may14`, `char_tab_ownership_may14`, `beta_*` memories.
