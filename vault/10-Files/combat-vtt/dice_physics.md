---
type: file-note
domain: combat-vtt
path: flutter_app/lib/presentation/widgets/dice/dice_physics.dart
layer: presentation
language: dart
status: active
updated: 2026-10-05
tags: [file]
---

# `dice_physics.dart` (+ `dice_roll_view.dart`, `dice_fab.dart`)

> [!abstract] Primary Purpose
> The 3D dice roller. A bottom-right dice button on world screens (DM + player) and the standalone character sheet opens a menu over a lightly dimmed screen; the chosen dice are thrown in 3D on that dim and a result card shows the total. Results are decided by `Random` **before** the throw; the physics only shows them. Screen-only: nothing is logged, saved or sent to players.

## Inputs / Outputs
**Inputs**
- `throwDice(counts, rng, trayX:, trayZ:)` — `counts` is kind → how many (`diceKinds`: d4 d6 d8 d10 d12 d20 d100), tray half-size in world units (from `DiceView`, sized to the screen).
- No providers, DAOs, Supabase or events.

**Outputs**
- `DiceRoll` — `dice` (`ThrownDie`: shape, decided face, pose track at `diceSimHz` = 240/s, body-frame `remap`), `results` (kind → values, `diceKinds` order; a d100 is one value 1–100), `total`, `steps`.
- `DiceFab` widget ([dice_fab.dart](../../../flutter_app/lib/presentation/widgets/dice/dice_fab.dart)) — the button + menu route. `DiceRollView` / `DiceKit` / `DiceView` ([dice_roll_view.dart](../../../flutter_app/lib/presentation/widgets/dice/dice_roll_view.dart)) — rendering.

## Dependencies & Links
- Depends on: `flutter_scene` (Flutter GPU), `vector_math` — see [[pubspec]].
- Used by: `field_widget_factory.dart` (proficiency table rows → `rollDice`), `main_screen.dart`, `player_main_screen.dart`, `character_editor_screen.dart` (standalone route only; embedded editors rely on the host's button).
- Domain map: [[Combat-and-VTT]]

## Key Logic / Variables
- **Physics, then relabel.** A small rigid-body sim (gravity 30, friction 0.45, corner contacts against a floor + 4 tray walls, dice-vs-dice as horizontal sphere pushes) runs the whole throw up front (cap 4 s; a die still moving tips onto its nearest face over ¼ s). Then each die is rotated by one of its own symmetries (`_remap`) so the face that physically landed carries the decided number — every frame stays physically valid. A d4 is read at its top corner, so its result is the face it lies on (`readsBottom`).
- **Off the UI isolate:** the sim runs through `compute` (desktop AOT: 30d6 ~11 ms, 15d100 ~17 ms). The hot loop is allocation-free: corners are transformed once per step into `_Body.corners`, walls out of the bounding sphere's reach are skipped, the contact solver works on scratch vectors (`_v`, `_c`). A track (`DiceTrack`) is one `Float32List` of 7 floats per step (pos xyz + quat xyzw), so it comes back from the isolate as a typed array. `maxDicePerRoll` = 30 (a d100 counts as 2).
- **Screen sizing (`DiceView`):** a die across is ~20% of the short side, clamped 72–120 px; the camera height follows from that (24° lens, tilted ~10°). The tray is the visible ground minus 0.8 units, and 110 px at the top are kept free for the result card.
- **Rendering (`DiceKit`):** built per dice look on first menu open (only the last look is cached; switching rebuilds) — a runtime number atlas + rounded mesh (14% bevel) + clearcoat resin material per shape, one shadow-casting light, and a `ShadowCatcherMaterial` floor so shadows fall on the dimmed app (the scene clears to transparent). One shared `Scene`; nodes are added per roll and removed on close. Atlas textures use `TextureContent.data` so their mip chain is a plain byte average — the default `color` path does sRGB pow() per texel on the UI isolate (~1 s desktop, seconds on a phone). On build, one frame is warmed up with every shape (`scene.warmUp`) so the first throw doesn't stall on shader compile. **Phone tier (`_phone`, Android/iOS):** no shadow map, no `ShadowCatcherMaterial` floor, no clearcoat; each die gets a blob shadow instead (`DiceKit.blob`: a 64 px radial-gradient texture on a `PlaneGeometry` with a blended `UnlitMaterial`, laid on the floor along the light and widened with height in `_place`). Measured on an iGPU with a GPU-saturating harness: shadows were ~50% of GPU time, clearcoat ~35% more with 30 dice, MSAA ~16% (cheap on tile GPUs, kept); the tier cuts GPU time 53% (1 die) to 65% (30 dice). Desktop keeps the full look. Render cost (desktop): a single shadow cascade (`shadowMaxDistance` fitted per screen by `DiceView`, clip range kept close to the tray), `pixelRatio` capped at 2 on desktop and 1.25 on Android/iOS (`_maxPixelRatio`; phones are fill-bound on the full-screen shadow floor), scene inside a `RepaintBoundary`, and `autoTick: false` once the dice settle — while the result card is up the 3D view does not render per frame.
- **Dice themes:** `diceLooks` maps every app theme name to a plain-resin `DiceLook` (body/ink colours), followed by named styles (`gold`, `silver`, `marble`, `wood`, `bone`, `galaxy`, `infernal`, `crystal`, `dragon-eye`, `arcane`). `UiState.diceTheme` is a look name or `'auto'`; `resolveDiceLook(setting, appTheme)` picks the look (`auto` → the active app theme, unknown → `dark`). `DiceFab` resolves it and passes it down to `DiceRollView`. Picked in Settings → Dice theme: `DicePreview` (the resolved look as a 3D d20 seen straight down onto its 20) above two chip groups, names only, each chip in its own look (body colour, ink label; `auto` in the app theme's) — Themes (`auto` + the app-theme looks) and Others (the named styles) (its own small `Scene` per look, same `_dieNode` as a throw; loading it also readies the roller's `DiceKit`; tapping through chips builds one kit at a time and skips the looks tapped past). Rounded meshes depend on the shape only and are cached across looks (`_geometries`).
- **Dice styles (`DiceLook`):** all on the same `PhysicallyBasedMaterial` as resin, so per-pixel cost does not rise. Patterns (`DicePaint`: marble veins, wood grain, galaxy clouds/stars, lava cracks) are painted into the number atlas; `glow` adds a second emissive atlas (numbers, stars, cracks on black); metal is `metallic: 1` with black ink as enamel, and the kit's scene tilts `environmentTransform` so a top-down view catches the IBL horizon. `coat: false` drops clearcoat (it is ~35% of desktop GPU time). See-through looks (`opacity < 1`) blend the shell, give the numbers a dark rim, and on desktop add an inside-out copy of the die (`_dieGeometry(inside: true)`, `AlphaMode.mask`, tinted) so the far faces' numbers show — the engine always culls a blended surface's back faces. Numbers are drawn in `diceFont(look)`: `DiceLook.font` (a Google Fonts family — the app theme's own font for terminal/mono/terra/jade/carmine, a fitting display face per named style, e.g. Cinzel for gold, Audiowide for galaxy, UnifrakturMaguntia for infernal) or `serif` when null; `DiceKit._build` awaits `GoogleFonts.pendingFonts()` before painting the atlas, and offline-never-fetched falls back to serif. The picker chips are labelled in the same font and weight (w800 only — each weight is a separate download). A `DiceCore` (`eye`: planar-projected slit-pupil ball turned in `_dieNode` to look up at the camera once the die rests; `gem`: small d8) is an unlit child node with no shadow. Measured with a GPU-saturating harness (30 d20s, stacked views), relative to `dark`: desktop every style 96–145%; phone tier opaque styles ≈100%, `crystal` 99%, `dragon-eye`/`arcane` 95–96% (the extra draw per die; the back-face mesh is skipped on phones because it cost ~10%).
- **Fallback:** if `DiceKit.load()` fails (no Flutter GPU), the roll shows only the result card; the failure is `debugPrint`ed (bug-report log).
- **Interaction:** tap a die = throw just that one; +/− build a set, Roll throws it. Tap during the tumble skips to the landed dice; tap after closes. Back / Esc / the dim close the menu.
- **Direct roll (`rollDice(context, ref, counts, modifier:, label:)`):** throws without the menu; the result card adds `modifier` to the dice total and shows `label` above it. The proficiency table (skills / saving throws, `field_widget_factory.dart`) calls it on a row tap: d20 + that row's Total, titled with the row name. Rows without a computable total (no `stat_block`) don't roll.
- **Platform switch:** Flutter GPU is enabled in the Linux and Windows runners (`DartProject`), Android manifest meta-data and iOS/macOS `Info.plist` (`FLTEnableFlutterGPU`); web needs nothing.

## Notes
- Gotchas inherited from the prototype: `vm.Quaternion.rotated()` applies the inverse of the engine's compose — orientation math goes through matrices; flutter_scene renders left-handed (atlas "right" is normal × up); one `Mesh` per `Node`.
- `test/presentation/widgets/dice/dice_physics_test.dart` checks every die rests flat on the decided face, and results are in range.
- The desktop session left panel still has its own inline d4–d100 buttons that log to the combat log; separate from this roller.
