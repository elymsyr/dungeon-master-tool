# Roadmap

Tracked work for upcoming releases — bugs to fix and features to add. Items are grouped by type, not strictly ordered.

---

## Bugs

### Marketplace download not visible until restart
After downloading a world / template / package from the marketplace, the new item does not appear in the corresponding tab until the app is closed and reopened. The relevant provider needs to refresh its list right after a successful import.

### Post composer button stays disabled while typing
On the Feed, the **Post** button only enables on focus loss / debounce. It should react immediately as the user types so a non-empty draft is always submittable.

### Like button has noticeable delay
Liking a post waits for the round-trip before updating the icon. Switch to optimistic update — flip the icon instantly and reconcile in the background, with rollback on failure.

### Mobile settings: theme cards too short
Theme preview tiles in the mobile Settings tab are clipped vertically. Increase their height so the swatch + label both fit comfortably.

### Social tab cramped on mobile
The Social shell (Feed / Marketplace / Messages / Players) was laid out for desktop. Needs a dedicated mobile pass — proper spacing, single-column flows, sticky tab bar.

---

## Features

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

---

## UI / Theming

### Theme-driven visual identity
The app currently looks like a generic Material shell regardless of theme. Each theme should ship its own visual character — for some themes this means **harder, sharper edges**, different elevation, accent shapes — applied **across the entire app and every tab**, not just color swaps. Themes can vary among themselves; the goal is that switching theme noticeably changes the feel of the whole interface.
