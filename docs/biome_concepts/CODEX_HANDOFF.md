# Handoff to Codex: Midori Park biomes (2026-11-05)

Claude built this and is handing it over because of usage limits. Nothing is committed. Don't commit unless the user asks.

## How it works
- `scripts/midori_biomes.gd` runs after the raid boots. It is called from `scripts/midori_distance_boot.gd`.
- It bakes look maps into the ground shader, then runs each builder listed in `BUILDERS`. The builders live in `scripts/biomes/*.gd`.
- Shared helpers: `biome_kit.gd` and `thin_all.gd`. `thin_all.hide_low_planting` hides plants, including the distance-detail copies of them.
- Env switches:
  - `MIDORI_BIOMES_OFF=1` turns all biomes off.
  - `MIDORI_BIOMES_ONLY=name,name` runs only the named builders.
- Plan: `docs/PARK_BIOME_PLAN.md`.
- Concepts: `docs/biome_concepts/after_*.png` and `extra/after_*.png`.
- Botany reference for the cherries: `docs/biome_concepts/closeup/SOMEI_YOSHINO_REFERENCE.md`.
- In-game shots per round: `docs/biome_concepts/built/round3/`, which also has `<area>_sheet.png` laid out as before | game | concept.
- Code snapshots: `docs/biome_concepts/built/code_snapshots/`.

## Render / verify
- Godot: `%USERPROFILE%\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe`
- Capture script (camera list in `VIEWS`): `C:\Users\hp\AppData\Local\Temp\claude\b41c4749794c309f\ec465bd6-52e3-405f-8043-7f471da5be47\scratchpad\build_capture.gd`. Copy it into the repo (for example `tools/biome_capture.gd`) if you need it to persist.
- Run: `<godot> --path . --disable-vsync --script <capture>`, with env `BIOME_VIEWS=view,view` (empty means all views) and optionally `MIDORI_BIOMES_ONLY`.
- Output: PNGs go to `%APPDATA%\Godot\app_userdata\Shinrai\biome_build\<view>.png`. Stdout prints `SHOT <view> steady_fps=..`.
- A full boot takes about 6–8 minutes.
- Parse check: `<godot> --headless --path . --check-only --script res://scripts/biomes/<file>.gd`. All files pass as of handoff.

## Status per area (see round3 sheets)
- **Done and approved:** sakura lawn. It uses the procedural cherry `sakura_tree_generator.gd` (v8h) plus wind-blown petals. Leave it as is.
- **Good:**
  - Moss garden.
  - Pine woods: only the last spiky grass tufts near the cameras still need removing.
- **In progress when stopped** (files edited after round 3, none of it verified):
  - `north_coppice.gd`: needs a dark olive litter floor under a dense, continuous understory of ferns, shrubs and periwinkle, plus visible fallen logs. It also has to cost much less: today it adds +18–30 ms per view; the target is about +6 ms. Render 2 was still too sparse and lawn-like.
  - `iris_shore.gd`:
    - The main view's foreground may be a paved walk; plant the bank beyond it instead.
    - `iris_shore_north` costs +16 ms; cut that to about +5 ms.
    - No single reeds standing in open water.
  - `shrine_approach.gd`:
    - Build a continuous, swept granite approach from (164,95) to the plaza.
    - Add lanterns in pairs and azalea plus clipped-shrub drifts.
    - Plant the plaza rim in the reverse view.
  - `maple_glen.gd`:
    - The maples read as dark, acacia-like shapes. Give them lacy, lighter green crowns with translucency.
    - Remove the orange boulder in the pond.
  - `meadow.gd`: the susuki plumes render white or blue and glow. They should be pale straw.
- **WARNING:** the last render after the shrine/maple/meadow/pine edits CRASHED with an access violation. Find which of those four files causes it first. Isolate by setting `MIDORI_BIOMES_ONLY` to one builder at a time. If you can't find it quickly, restore that file from `code_snapshots/<file>_r3.gd`, if a snapshot exists.

## FPS (round 3, average over 29 views)
- 61.9 with biomes off, 50.7 with biomes on.
- Hotspots: coppice, iris north, moss satellite.

## User preferences
- No stripes, rows, lattices, slats or streaks.
- Paths are painted into the ground, never overlaid as strips.
- Muted olive greens, never lime.
- DayZ-like natural integration.
- Always show same-camera before / now / concept images for each area.
- Don't move on from an area until it matches its concept.
