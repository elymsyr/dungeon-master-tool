---
type: platform
domain: cross-cutting
updated: 2026-06-09
tags: [platform]
---

# Platform Targets

> [!summary] What this is
> The app ships to desktop (Windows/macOS/Linux), mobile (iOS/Android), and web from one Flutter codebase. Capability differs per target; this note tracks the per-platform constraints.

## Targets
| Target | Notes |
|---|---|
| **Desktop** | Full UI; multi-window second-screen ([[Multi-Window-IPC]]); SoLoud audio ([[Audio-SoLoud]]). |
| **Mobile** | Responsive layout; keyboard/mention handling; realtime lifecycle suspend; Image cacheWidth. |
| **Web** | Browser-based; some native plugins degrade. |
| **Second-screen** | 4th projection output; window or [[Screencast-Presentation-API|screencast]] or online. |

## Notes
- Build matrix in [[ci-build]]. Platform dirs: `flutter_app/{android,ios,macos,windows,linux,web}/`.
- Mobile perf items tracked in `flutter_app/docs/mobile_performance_audit_*` + `mobile_responsiveness_audit_*`.

## Related
- MoCs: [[Deployment-and-Ops]] · [[Projection-Second-Screen]]
