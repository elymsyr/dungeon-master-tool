# Roadmap

Tracked work for upcoming releases — bugs to fix and features to add. Items are grouped by type, not strictly ordered.

## Features

### Version Control Indicator

Add an indicator to the main menu header. It will get the latest release from https://github.com/elymsyr/dungeon-master-tool and show if a new release is up. The releases are published with <process>-<version> name. Current is beta-v4.0.1

### Cloud sync overhaul
Replace the current snapshot/lineage flow with a simpler model:

- **Drop "Start fresh lineage" toggle** and version chaining entirely — every publish creates a fresh, independent snapshot. Users can manually delete old ones.
- **Multi-device change badge:** when an item that exists locally has been edited from another device, show a notification dot on the Settings icon. The intent is "you have cloud changes to pull," not version conflict resolution.
- Replace `marketplace_listings.lineage_id` / `is_current` / `superseded_by` columns and the related "update prompt / mute / dismiss" UI with this lighter flow.

### Replace "Switch World" with "Quit"
The current sidebar action labeled *Switch World* (also for Package / Template) should become a plain **Quit** button that returns to the selector screen, instead of forcing the user through a switch dialog.

### Package types
Today there is one generic package type. Split it into two distinct kinds:

- **Entity Card Pack** — current behavior (schema + entities).
- **Sound Pack** — opens directly into the Soundpad sidebar as the landing view. Users can add tracks from the pack straight into their personal library.

### In-app messaging integration
Wire the existing `messages_remote_ds` + Realtime channels into the actual Messages tab end-to-end: conversation list, unread state, real-time updates, send/receive, mobile layout.

### Profile pictures
Avatar upload + display across the app: profile screen, post author, message thread header, players list. Storage in the existing avatar bucket.

### In-app notification system
A unified in-app notification surface (badge + drawer/list). **First integration: messages** — unread DM count + per-message notifications. Designed so future sources (marketplace updates, follows, replies) can plug in.

### Global tag system
Tags entered in one place (e.g., a Game Listing) should be discoverable when other users create their own listings. Provide an autocomplete / suggestion list of existing tags so the same tag is reused instead of slight variants.

---

## Performance

### Latency audit
Several areas feel sluggish: button taps, tab switches, hitches during casts/animations. Run a profiling pass with Flutter DevTools, identify the worst offenders (rebuild storms, large widget trees, sync work on the main isolate), and apply targeted fixes — `select`-based watches, `const` constructors, lazy lists, deferred work.