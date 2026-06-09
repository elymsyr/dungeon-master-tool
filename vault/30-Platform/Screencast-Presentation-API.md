---
type: platform
domain: projection
updated: 2026-06-09
tags: [platform]
---

# Screencast / Presentation API

> [!summary] What this is
> Second-screen via the OS Presentation API (Miracast / AirPlay / external display). Renders the player view onto a cast target without a separate Flutter window. The OS-display "hardware integration" path.

## Participants
- [[projection_output_screencast]] — Presentation-API-backed transport.
- [[screencast_main]] — screencast render entrypoint.

## Notes
- One of the [[projection_output]] implementations; same filtered snapshot input as the others ([[Fog-of-War-and-Visibility]]).
- Platform availability varies — see [[Platform-Targets]].

## Related
- MoCs: [[Projection-Second-Screen]] · [[Multi-Window-IPC]] · [[Platform-Targets]]
