---
type: file-note
domain: data-layer
path: flutter_app/lib/data/datasources/remote/
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# Remote datasources — index

> [!abstract] Primary Purpose
> The Supabase-facing datasource layer for **online-only / social / admin** features (distinct from the Drift+CDC world-sync path). Each class wraps `Supabase.instance.client` directly, hitting named Postgres tables, Storage buckets, and SQL RPCs. Most expose a private `_userId` getter that throws `StateError('Not authenticated')` if no session. These are NOT part of the offline-first world mirror — that goes through DAOs ([[daos-index]]) + outbox ([[tables-sync]]).

## Inputs / Outputs
**Inputs**
- Constructor deps: none (each lazily reads `Supabase.instance.client`).
- Reads: Supabase tables / Storage buckets / RPCs (per-DS below).

**Outputs**
- Public API: instantiated directly or via providers (e.g. `postsRemoteDsProvider` in `social_providers.dart`); consumed by [[repositories-index]] (cloud backup) and social/admin providers.
- Supabase pushed / RPC called: extensive — see per-DS list.

## Dependencies & Links
- Depends on: `supabase_flutter`; domain entities (`UserProfile`, `GameListing`, `MarketplaceListing`, `Conversation`, `AppNotification`, `BugReport`, …).
- Used by: [[repositories-index]] (`CloudBackupRepositoryImpl`), social/admin providers, [[marketplace_cover_sync_service]].
- Domain map: [[Data-Layer]]
- System flow: [[CDC-Sync-Flow]]
- Spec / reference: [[Multiplayer-and-Online]], [[Backend-Infra]], [[rpc-reference]]

## Key Logic / Variables
- **`cloud_backup_remote_ds.dart`** → `CloudBackupRemoteDataSource` — gzip-JSON cloud backup CRUD. Bucket `campaign-backups` (private, RLS `{user_id}/` prefix), table `cloud_backups`. Path `{user_id}/{type}s/{item_id}.json.gz`. Used by `CloudBackupRepositoryImpl`.
- **`profiles_remote_ds.dart`** → `ProfilesRemoteDataSource` — user profiles CRUD/query over table `profiles` + view `profile_counts` + RPC `search_profiles`; avatar bucket `avatars`. `fetchCurrent`/`fetchById`.
- **`follows_remote_ds.dart`** → `FollowsRemoteDataSource` — follow toggle + listing over `follows` (joins `profiles`). `isFollowing(targetUserId)`.
- **`posts_remote_ds.dart`** → `PostsRemoteDataSource` — social feed; table `posts` (+ `post_likes`), bucket `post-images` (counts to `posts.size_bytes` quota). `FeedScope {all, following, discover}`; cursor pagination (`before` = `created_at <` page); first page gets HN-style "hot" rerank, later pages pure chronological.
- **`messages_remote_ds.dart`** → `MessagesRemoteDataSource` — DMs/group chat over `conversations` + `messages`, RPC-heavy: `get_my_conversations`, `leave_conversation`, `delete_conversation`, `add_conversation_member`, `kick_conversation_member`, `rename_conversation`, `mark_conversation_read`, `get_total_unread_count`.
- **`game_listings_remote_ds.dart`** → `GameListingsRemoteDataSource` — "looking for group" board; tables `game_listings` + `game_listing_applications`. `fetchOpen({gameLanguage, system, tag})` newest-first.
- **`marketplace_listings_remote_ds.dart`** → `MarketplaceListingsRemoteDataSource` — published content packages; table `marketplace_listings`, bucket `shared-payloads` (path `{owner_id}/listings/{listing_id}.json.gz`). Each publish is an immutable independent row (no lineage). `publishSnapshot`, `downloadPayload`, `deleteListing`, `updateListingCover`, `listAllCurrent`, `fetchListingsByIds`, `listCurrentByOwner`, `fetchListing`.
- **`bug_reports_remote_ds.dart`** → `BugReportsRemoteDataSource` — user bug reports (status open/read/resolved, captures appVersion/platform/logs); `BugReportRateLimitException` on throttle.
- **`notifications_remote_ds.dart`** → `NotificationsRemoteDataSource` — end-user notifications inbox (online-only, mig 069 RPCs): `list_notifications`, `submit_notification_response`, `mark_notification_read`, dismiss-all-read.
- **`admin_notifications_remote_ds.dart`** → `AdminNotificationsRemoteDataSource` — admin broadcast authoring + response viewing (`AdminNotificationSummary`, `NotificationResponseRow`; blocks = markdown/poll/input).
- **`admin_beta_requests_remote_ds.dart`** → `AdminBetaRequestsRemoteDataSource` — admin beta request queue: RPCs `admin_list_beta_requests`, `admin_approve_beta_request`, `admin_reject_beta_request`, `admin_list_beta_participants` (`BetaRequestEntry`, `BetaParticipantEntry`, `BetaApproveResult`).
- **`admin_users_remote_ds.dart`** → `AdminUsersRemoteDataSource` — admin console (~14 KB): RPCs `get_all_users_summary`, `search_users`, `ban_user`/`unban_user`/`get_banned_users`, `get_system_storage_stats`, `set_online_restriction`/`get_restricted_users`/`am_i_online_restricted`, `admin_delete_post/marketplace_listing/game_listing/message`, `admin_list_posts/game_listings/marketplace_listings/audit_log`. Row types: `AdminUserSummary`, `BannedUserEntry`, `RestrictedUserEntry`, `StorageBucketStat`, `OnlineRestriction`, `AdminPostRow`, `AdminGameListingRow`, `AdminMarketplaceListingRow`.

## Notes
- World/character/package *content* sync does NOT live here — it uses the Drift mirror + `sync_outbox` + CDC ([[tables-sync]], [[world_mirror_applier]]).
- Most write paths funnel through SQL RPCs (security-definer functions) rather than direct table writes; see [[rpc-reference]].
