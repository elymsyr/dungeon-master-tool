# Beta v3.0.0 - Social Hub

First release with online social features. Profiles, following, posts, direct/group messages, public marketplace and a one-shot admin gate. **Beta** release -- feedback welcome via [GitHub Issues](https://github.com/elymsyr/dungeon-master-tool/issues).

---

## Downloads

| Platform | File | Notes |
| :--- | :--- | :--- |
| Android | `DungeonMasterTool-Android.apk` | Enable "Install from unknown sources" if prompted |
| iOS | `DungeonMasterTool-iOS.ipa` | Unsigned -- sideload via Xcode or AltStore |
| Windows | `DungeonMasterTool-Windows.zip` | Extract and run `dungeon_master_tool.exe` |
| Linux | `DungeonMasterTool-Linux.zip` | Extract and run `./bundle/dungeon_master_tool` |
| macOS | `DungeonMasterTool-MacOS.zip` | See [macOS installation guide](https://github.com/elymsyr/dungeon-master-tool#macos-installation) |

---

## Highlights

- **Profile menu** -- the top-right sign-in/out icon is now an avatar + username popup with View Profile, Edit Profile, Admin Panel (admins only) and Sign Out actions. New users get a mandatory username dialog on first sign-in.
- **Social hub redesign** -- the Social tab is now a 4-section shell with a pill-style segmented control: **Feed**, **Players**, **Messages**, **Marketplace**. Cleaner desktop layout with a 720px centered max-width.
- **Feed** -- post composer with character counter, follow-based timeline, image upload (counts toward your storage quota).
- **Players** -- public game listings ("looking for a group"), seat counts, schedule, plus username search to discover and follow other DMs.
- **Messages** -- direct messages and group chats over Supabase Realtime, asymmetric chat bubbles, conversation list with last-message preview.
- **Marketplace** -- browse public worlds, templates and packages from every user. Filter by type, jump to the owner's profile.
- **Per-item public/private toggle** -- world/template/package settings dialogs now have a visibility switch. Public items are uploaded as gzip payloads to Supabase Storage and shown in the Marketplace + the owner's profile.
- **Cloud backup relocation** -- backup list moved out of the Social tab into the top-right cloud icon, sitting directly above the storage bar.
- **Admin gate** -- privileged actions like updating the built-in D&D 5e template are gated through a Supabase `is_admin()` RPC. The admin email is **not** in the source code -- the grant is a one-time SQL run on the Supabase dashboard.

---

## Backend changes

New Supabase migration `003_social.sql` introduces:

- `profiles`, `follows`, `profile_counts` view, `search_profiles` RPC
- `posts`, `game_listings`, `shared_items`
- `conversations`, `conversation_members`, `messages` (with realtime)
- `app_admins` table + `is_admin()` SECURITY DEFINER RPC
- Extended `get_user_total_storage_used` to cover posts + shared payloads
- Row-Level Security on every table (public read where appropriate, owner-only writes, conversation membership for messages)

Storage buckets: `avatars` (public), `post-images` (public), `shared-payloads` (private).

---

## Technical Details

- **Framework:** Flutter 3.41 / Dart 3.11
- **Architecture:** Clean Architecture (Domain / Data / Application / Presentation)
- **State Management:** Riverpod
- **Database:** Drift SQLite (local) + Supabase Postgres (online)
- **Realtime:** Supabase channels for chat
- **Models:** Freezed + json_serializable
- **Routing:** go_router with `/profile/:userId` and `/admin` routes

---

## Upgrading from 2.0.3

1. Apply `supabase/migrations/003_social.sql` on your Supabase project.
2. Create the storage buckets listed above.
3. (Admin only) Run the one-shot grant from `supabase/README.md` to seed `app_admins`.
4. Rebuild the app -- no local DB migration is required (the local Drift schema is unchanged; public/private state lives in Supabase).

---

## What's Next

See [TODO.md](https://github.com/elymsyr/dungeon-master-tool/blob/main/TODO.md) for the roadmap.

---

## License

[CC BY-NC 4.0](https://github.com/elymsyr/dungeon-master-tool/blob/main/LICENSE)
