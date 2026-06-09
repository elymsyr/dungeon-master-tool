---
type: platform
domain: media
updated: 2026-06-09
tags: [platform]
---

# Audio — SoLoud

> [!summary] What this is
> Sound playback/mixing via `flutter_soloud` (gapless loops) for the DM soundboard. The audio "hardware integration" layer.

## Participants
- [[soundpad_engine]] — playback + mixing.
- [[soundpack_catalog_service]] — installed soundpack listing.
- [[soundpad_loader]] — soundpack asset loading.

## Notes
- Soundpacks bundled in `assets/soundpad/`; user packs in `soundpacks/`.
- Initialized in `main.dart` startup alongside multi-window.

## Related
- MoCs: [[Media-and-Assets]] · [[Platform-Targets]]
