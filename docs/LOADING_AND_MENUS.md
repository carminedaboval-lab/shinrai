# Loading and menus

How Shinrai starts, builds the park behind the menu and deploys. Written 2026-11-07, after the
menu-first rebuild.

## What the player sees

1. **Loading screen, about 1 s.** Shader feature latch (`ShinraiShaderWarmup.latch_features`), then
   the park scene starts loading on a worker thread.
2. **Operations menu at about 1 s.** The park keeps loading and building behind it. 3D is off
   while it builds, so the menu shows the blurred plaza art. DEPLOY reads
   `DEPLOY · PREPARING PARK n%` with a thin progress bar and is enabled.
3. **DEPLOY pressed early** shows the deploy cover (the loading screen, owner `deploy`) with the
   remaining progress and **CANCEL DEPLOY**. The deploy then starts by itself when the world is
   ready. CANCEL returns to the menu with focus on DEPLOY.
4. **World ready** (about 150-160 s on the dev laptop, cached navigation). The last step warms
   the chosen time of day and quality offscreen under the menu, then turns the live 3D park on
   behind the menu. DEPLOY now reads `DEPLOY · GOLDEN HOUR` / `NIGHT`.
5. **DEPLOY when ready** takes about 1 s under the cover. A second deploy, after returning to HQ,
   is about 0.4 s.

The menu changes hands once, about 20 s in. The boot host's early menu
(`ShinraiMenuSource`) is replaced by ExtractionRun's own Operations menu in the same frame, with
no gap and no double menu. The time-of-day choice, the quality choice, a requested deploy, a
focus loss during that deploy and an open quit dialog all carry over.

## Files and owners

| File | Role |
|---|---|
| `scripts/shinrai_bootstrap.gd` | Boot flow: loading screen, latch, threaded load, early menu, instantiate, hand-over, view warm-up, 3D on, watchdog and Retry. Starts the loading budget's frame clock. |
| `scripts/shinrai_load_state.gd` | `ShinraiLoadState`: static progress (`fraction`, `stage`, `world_ready`, `first_launch_shaders`, `menu_shown`), progress bands, loading-screen helpers. |
| `scripts/shinrai_menu_source.gd` | Early Operations-menu source before ExtractionRun exists. It reads the profile and never writes it. |
| `scripts/extraction_run.gd` | `_prepare_park` (producers, navigation, distance boot, world-complete step, render budget, `phase = HQ`), deploy queue and cover, menu-source methods. |
| `scripts/shinrai_world_complete.gd` | Work that used to wait for `phase != BOOT`: road resurfacing, the late shrub sweep, worn paths, biomes, then a navigation refresh around new colliders. |
| `scripts/shinrai_loading_budget.gd` | Shared per-frame main-thread budget (`checkpoint`, `stage`, `wait_structure`). |
| `scripts/shinrai_shader_warmup.gd` | Feature latch, offscreen view warm-up, first-launch stamp. |
| `scripts/shinrai_loading_screen.gd` | Loading screen and deploy cover (owner tokens). |
| `scripts/ui/shinrai_menu_kit.gd`, `scripts/ui/shinrai_operations_menu.gd`, `scripts/extraction_hud.gd` | Menus in the inventory's visual language. |

## Interfaces

**Loading screen** (group `shinrai_loading_ui`): `begin(text, owner)`, `finish(owner)` (hides when no
owner is left), `set_stage(text, progress)`, `fail(message)`, `show_cancel(enabled)`, `active`, signals
`retry_requested` and `cancel_requested`. `progress` is the **overall** build fraction (0..1, like
`ShinraiLoadState.fraction`) or -1. The bar, the header percentage, the step rows and the
"Resources n%" line all come from that one value. Once `fail()` is shown, `set_stage` changes
nothing until the next `begin()`.

**Progress milestones** (`ShinraiLoadState.band(text, start, end, expected_seconds)`; `tick()` creeps
toward the end of a band, never reaching it):

| Band | Range | Expected | Set by |
|---|---|---|---|
| Park resources | 0.00-0.20 | 9 s | bootstrap (real threaded-load progress) |
| Park structure | 0.20-0.45 | 20 s | bootstrap |
| Producers | 0.45-0.65 | 90 s | ExtractionRun, raised at each finished producer wait (paths 0.48, lamps 0.50, furniture 0.52, south street 0.55, aftermath 0.58, corporate 0.59, fence and cover 0.61, fruit garden 0.63) |
| Navigation and details | 0.65-0.75 | 18 + 6 s | ExtractionRun |
| Completing the park | 0.75-0.95 | 40 s | world-complete step (its own stage texts) |
| Warm-up | 0.95-1.00 | 3 s | bootstrap |

**Operations menu source** (`ShinraiOperationsMenu.configure(source)`): `menu_profile()`,
`menu_world_ready()`, `menu_can(action)`, `menu_night()`, `menu_high_quality()`, `menu_last_error()`,
and actions through `action_requested(action)`. ExtractionRun and `ShinraiMenuSource` implement it.
`refresh()` updates in place and keeps focus.

**ExtractionRun**: `world_ready()` (phase left BOOT, navigation ready, view warmed), `in_hq_menu()`,
`deploy_queued`, `view_settings_locked()` (true while a warm-up renders the current variant: TIME,
GRAPHICS and F7 are held then), `start_run(retry_save)` (queues while the world builds),
`cancel_queued_deploy()`, `warm_park_view(include_menu_pose, limit_msec)`, `finish_view_warmup()`,
`apply_menu_preferences()`.

**Loading budget**: `checkpoint(park)` yields once this frame's share is spent: 50 ms, or 14 ms while
the player is using a menu over the build (input within the last 4 s). The share is counted from the
start of the frame (the boot host calls `frame_started()` from the first `process_frame` listener), so
work that resumes before the first checkpoint counts too.

## Order of the build (`ExtractionRun._prepare_park`)

1. Producer waits: terrain, desire paths, lanterns and lamps, identity, south street, aftermath,
   corporate district, park fence, park cover, **island nature** (its stone colliders must be in the
   navigation graph; it no longer lands before the graph by timing alone).
2. Fruit garden, Creator layout, navigation graph, clubhouse doors, sites.
3. Distance boot (`midori_distance_boot.install_before_hq`).
4. **If the distance boot succeeded:** the world-complete step, then the render budget (reflection
   layers, near plant shadows, draw distances). Geometry the world-complete step adds is listed first
   (`shinrai_render_budget_before` meta). The draw-distance and reflection passes leave it as built
   and judge visibility as it was before that step. This gives the look the park had when the render
   budget ran first (biome planting keeps its full draw distance and stays in the lake reflection).
   Plant shadows are captured once over the thinned planting, not re-captured on every thin pass.
   **If the distance boot gave up:** no biomes, worn paths or late sweep, as before; only the roads
   are resurfaced.
5. `phase = HQ`, then the boot host warms the view under the menu and turns 3D on. Only then is
   `world_ready()` true.

## Deploy

`start_run()` while the world builds calls `_queue_deploy()`: the cover appears (owner `deploy`) with
CANCEL. When the world is ready, `_deploy()` runs under the same cover. It applies the menu
preferences, warms the chosen variant (cached per variant per session), commits `profile.begin_run()`,
sets up the raid, draws one frame and drops the cover. Physics runs one step per frame under the
cover and for the first two raid frames, so the long deploy frames never turn into an 8-step catch-up
in the first live frame. A focus loss while a deploy is queued or pending (early menu included)
starts the raid paused.

## How to measure

Always through the lock, always with a QA profile (the probes set their own):

```
powershell -NoProfile -File tools/godot_locked.ps1 -Out <log> -TimeoutSec 900 -GodotArgs "--path . --script res://tests/probe_menu_time.gd -- --second-deploy --midori-fruit-seed=7"
```

`probe_menu_time.gd` flags:
- `--deploy-immediately`: press DEPLOY on the first menu frame (queued deploy).
- `--simulate-input`: move the mouse over the menu every frame of the build (the 14 ms share).
- `--second-deploy`: return to HQ and deploy again.
- `--no-deploy`: stop after world ready.
- `--profile-startup`: print `LONG_SLICE` lines (stretches over 250 ms between budget checkpoints, with
  the code that ran).
- `--strict`: exit code 2 when any frame over 0.5 s happens while the menu is up.

What it prints:
- `MENU_PROBE <stamp>` lines: first_frame, menu_visible, park_in_tree, run_created, world_ready,
  menu_idle_5s, deploy_pressed, raid_view, raid_5s (and hq_return, deploy2_pressed, raid2_view).
- `MENU_PROBE_SEGMENT`: frames, average frame, physics ms and steps per frame, and frames over
  250 / 500 / 1000 ms, for the stretch since the previous stamp.
- `MENU_PROBE_MENU_UP`: the same over every frame the menu was usable over an unfinished world.
- `MENU_PROBE_TARGET`: menu frames over 0.5 s against the target of 0.
- `MENU_PROBE_LONG`: every frame over 1 s, with the stage before and after it.

Other checks:
- `tests/probe_world_fingerprint.gd -- --fp-out=<json>`: per-group hashes of the built park.
  `render_hash` (draw distance, render layers, shadow casting) is new and is not in older fingerprints.
  Compare two fingerprints with `compare_fp.py` (WORLD's scratch tool) or by group `hash`.
- `tests/probe_ui_capture.gd -- --out <dir> --tag <tag>`: 1920x1080 captures of every screen.
- `tests/probe_boot_time.gd`, `tests/probe_menus.gd`, `tests/test_extraction.gd` (headless),
  `tests/test_salvage_choice.gd`.

## Timings

Dev laptop (RTX 5050 Laptop), warm shader caches, cached navigation, `--midori-fruit-seed=7`, QA
profile. The baseline is the old flow (HQ, then a frozen loading screen, then the menu). Logs are in
the session scratchpad (`fix/probe_default.txt`, `probe_immediate.txt`, `probe_input.txt`).

| | Baseline | Now |
|---|---|---|
| Menu visible | 141.6 s | **1.0 s** |
| Worst frame while the menu is up | 30 s (frozen loading screen) | **2.9 s** (park scene instantiate) |
| Frames over 1 s / over 0.5 s with the menu up | n/a | 24 / 67 (target 0) |
| World ready | HQ 111.6 s, park complete about 200 s | **152.6 s** (153-154 s with DEPLOY pressed at once, or with the player moving the mouse the whole time) |
| Average frame while building | n/a | 89 ms idle, 58 ms while the player uses the menu |
| DEPLOY after world ready, to raid view | 5.5 s (one 3.8 s frame) | **1.1-1.5 s** (worst frame 0.6-0.9 s, under the cover) |
| DEPLOY pressed at once, raid view after world ready | n/a | 1.8 s (one 1.3 s frame, under the cover) |
| Worst frame in the first 5 raid seconds | 4.55 s | **274-289 ms** |
| Physics steps in the raid's first frames | n/a | 1 per frame (was 3.3 per frame, up to 8 in one frame) |
| Second deploy (after returning to HQ) | n/a | 0.4-0.7 s |

Fingerprint against the park as it was built before the menu-first boot (`fp_before.json`): every
group that differed only through the render-budget order now matches. Draw distances: 40,927 scanned,
12,907 ranged, the same as with the old order. `render_hash` matches a run with the old order in 76 of
77 groups. The clubhouse group (dynamic doors) differs in every run.

## Open items

- **Frames over 0.5 s while the menu is up (target 0): 67, 24 of them over 1 s, worst 2.9 s.** Input is
  buffered during them, not lost. The biggest are:
  - Park scene `instantiate()` plus the first `_ready` slice: 2.9 s at about 12 s.
  - Run creation (HUD, grass install): 2.4 s.
  - South street `_ready` (`batch_tree` tail, day-bounce layers): 1.6-2.9 s.
  - Corporate district `_ready`: 2.2 s.
  - Distance detail install: 2.4 s.
  - The slice before the render budget: 2.1 s.
  - Near-city tiles, lake life, garden spots and identity pockets: 1-2 s each.

  Each needs `LoadingBudget.checkpoint` calls inside that module's synchronous body.
  `probe_menu_time --strict` fails while any remain.
- **Second pass, 2026-11-07** (fingerprint identical in 73 of 77 groups; the other four, ExtractionRun,
  clubhouse, park props and wildlife, hold moving runtime state and differ run to run; every count
  matches). Split: the south-street shops (`Architecture.build`) and houses
  (`NeighbourhoodBuildings.build`) are coroutines with a turn per building; the street's shrub swap
  uses `ClippedShrubs.apply_budgeted`; the garden-spot grass trim takes a turn per batch and tests
  each batch only against the regions that reach it; the 2050 identity takes a turn when it wakes
  after the garden spots (that frame went from 2.1 s to two of about 1 s). Totals barely moved:
  over 1 s 27 -> 25, over 0.5 s 67 -> 68, world ready 158 -> 153 s (run-to-run noise is a few
  frames and seconds). Splitting a 2 s frame into two 1 s frames does not lower the counts; the
  remaining frames are mostly single synchronous bodies of 1-1.5 s.
- Measured and ruled out: the near-city wall textures (19 images, 0.6 s in all, already one per
  turn) and loading the corporate `building.tscn` (its 2.4 s is instancing the garage, 1,462
  meshes in `_ready`, so a threaded load does not help).
- Note when reading `LONG_SLICE`: "after" is the last checkpoint that returned, not always the
  culprit. A coroutine resuming from a plain `await process_frame` (a `while not x.installed` wait)
  runs until its own first checkpoint and is charged to whoever checkpointed before it.
- Grass install (`MidoriGrassDetail._install_ground_clumps`, 1.1 s in one frame) stays synchronous:
  producers read its batches as soon as `_installed_scene_id` is set and assume they are complete.
- **Where the ~150 s goes (measured 2026-11-08; all tried changes reverted, none moved world ready):**
  - Stage durations in `STARTUP_PROFILE` are wall time in a shared budget, not cost. Example:
    `terrain.height_grid` reads 27 s, but the grid itself is 0.33 s of CPU in 6 frames; the terrain
    sat at a checkpoint while other producers (alley life above all) spent each frame's budget,
    because waiters resume in the order they yielded and the terrain always yielded last.
  - That wait is not on the real critical path. A fair queue (budget waiters served first, oldest
    first) cut the stage to 11 s, but the terrain then started later (it also waits for
    `woodland_diversity`) and still finished at ~60 s; world ready stayed at 153 s.
  - The budget size barely matters: `--loading-budget-ms=120` gave world ready at 147 s and `=250`
    at 148 s (default 50 ms: 151-153 s), with frames averaging only 93 ms at 250. Most frames do
    not fill even the default share, so the build is bounded by its chain of producer waits plus
    real work, not by the per-frame share.
  - The biome stage (~33 s at the end) is mostly real CPU in the eight builders (pine woods 8.3 s,
    iris shore 5.5, sakura lawn 4.9, moss 3.5, coppice 3.0, meadow 2.8, shrine 2.4, maple 1.9;
    the colour-map bake is 0.6 s). `BiomeKit.open_ground` is only 26 ms of it (1,390 calls), and
    the shoreline distance is cheap (203 points): an exact shoreline index (0 mismatches in
    200,000 checks) saved nothing measurable.
  - Biome builders do not use the shared budget: their loops yield with plain
    `await process_frame` on fixed counts (`if z % 4 == 0`). Switching all 22 of those loop yields
    to `Budget.checkpoint(park, true)` left the stage at 33.6 s (reverted; its fingerprint run did
    not complete), so the builders are CPU-bound, not frame-bound. With those checkpoints in place
    the per-site tally (`Budget.reset_site_profile` / `print_site_profile`, called by
    `midori_biomes.install_now` under `--profile-startup`) gave 14.7 s of CPU between checkpoints:
    `biome_kit.gd leaf_floor` 4.5 s (per-square-metre density callable, water and path tests, then
    each leaf), moss garden `_mound_groups` 1.4, coppice twigs 1.4, meadow `_cells` 1.1, maple
    `_leaf_floor` 1.0, meadow `_grass` 0.9, iris `_stamp` 0.7 and `_scan` 0.5. Pine woods (8.3 s)
    barely shows by site: its work sits in synchronous blocks between its phase yields.
  - Exact speed-ups there are per-builder work worth a few seconds each. The large remaining lever
    is caching the finished biome planting per park version and seed (~30 s), not done.
  - Measuring caveat: the project lives in OneDrive. Each Godot run writes `.godot` caches and
    `startup_profile_events.log` into the synced folder; OneDrive's sync service reached ~8,900 s of
    CPU and world ready drifted from 152 s to 196-209 s over a day of runs with no code change on
    the critical path. Pause sync (or move the project out of OneDrive) before comparing timings.
- QA tools kept: `--loading-budget-ms=<n>` (idle/opaque share override, default unchanged) and,
  with `--profile-startup`, `BUDGET_CPU_MS` lines every 20 s: CPU between two checkpoints in one
  frame, charged per module (same attribution caveat as `LONG_SLICE`).
- **Instantiating the park on a worker thread** would remove most of the 2.9 s frame. Not done: the
  scene's `CollisionObject3D` nodes create physics-server bodies when they are constructed, and the
  physics server is not running thread-safe in this project. That would race with the main thread's
  physics steps.
- **First launch (empty shader caches):** the menu stays interactive. WARMUP measured stalls of up to
  about 12 s during the build on a cold cache. They happen whether a menu or a loading screen is
  showing, and Windows' "Not Responding" depends on message pumping, not on what is drawn. The current
  flow has not been measured cold.
- The navigation cache key changes with the fruit-garden seed. An uncached seed adds 11-17 s.
- Not run live: the watchdog fail and Retry path, a quit dialog open at the hand-over, and an open
  settings drawer at the hand-over (the drawer closes; it is not carried over).
- A deploy warm-up that passes its 20 s limit keeps rendering in the background (only the boot waits
  for it). Its end-of-warm restore no longer touches `disable_3d`.

## Park build speed (2026-11-08)

Goal: reach `world_ready` (the park fully built) sooner without changing the park. Target was under
75 s on a warm launch. Result: **about 98-99 s warm, 117 s cold**, down from 199 s on the same
(busy) machine the same day, and 153 s on a quiet one the day before. The target is not met. The
timings in the sections above are older; this section replaces them.

### What was slow

From `--profile-startup` traces (`startup_profile_events.log`, stage `duration_ms`):

| Stage | Before | After (warm) | What it was |
|---|---|---|---|
| `raid.world_complete` | 42.4 s | 19.5 s | the last step, mostly the eight biome builders |
| `world.biomes` | 38.0 s | 15.8 s | biome look maps and builders |
| `terrain.height_grid` | 32.4 s | 0.7 s | the terrain height grid, waiting in line for frame budget |
| `south_street._assign_day_bounce_layers` | 16.6 s | 0.05 s | a repeated walk over every street mesh |
| `flowers.templates` | 14.0 s | 0.01 s | iris scenes loaded on the main thread |
| `south_street.ClippedShrubs` | 9.5 s | 0.24 s | shrub bounds worked out again and again |
| `south_street.batch_tree` | 6.6 s | 1.0 s | merged meshes read back from the GPU |
| `feature.lake_life` | 2.2 s | 0.4 s | one shader compiled per creature |

### What changed

No content was removed or thinned, no seed changed and nothing moved to after `world_ready` or into
the raid. The techniques were: exact shortcuts for repeated scans, pure-data work on worker threads
(results applied on the main thread in the original order), threaded resource loads, and waiting
for the real producer instead of a fixed number of frames.

- **Terrain** (`midori_terrain.gd`): the height grid is computed on a worker while the planting
  services finish, then checked against the final inputs (recomputed if they changed).
- **South street** (`midori_south_street*.gd` and its helpers): merged meshes reuse the vertex
  arrays kept in memory (`midori_south_street_mesh_arrays.gd`) instead of reading them back from the
  GPU; day-bounce layers and shrub bounds are worked out once.
- **Near city** (`midori_near_city*.gd`): layout parsing, texture mip levels and building shells on
  worker threads, textures prefetched.
- **Nature** (flowers, desire paths, island nature, lake life, park floor, shoulders, sparse
  vegetation, clipped shrubs): iris scenes load on loader threads; the grass trims and the shoulder
  sweep run on threads; island nature and desire paths take budget turns; sparse vegetation waits for
  the flowers and the island instead of 20 physics frames.
- **Biomes** (`midori_biomes.gd`, `scripts/biomes/*`): look-map rows on threads, a shoreline
  distance table, builder grids in parallel, maple and cherry tree geometry started early, builder
  assets prefetched, loop yields by time instead of fixed row counts.
- **Pipeline:** the idle-menu frame share is 100 ms (`FRAME_BUDGET_USEC`; 14 ms while the player
  uses the menu, unchanged); distance-detail cells grouped and filled on threads; draw-distance and
  reflection passes walk the tree once; breeze materials and shaders shared; the corporate tower
  loads on a loader thread; garden-spot trims test only the regions that reach a batch.
- **Final safety pass:** the shoulder sweep worker no longer calls into the park node (it reads the
  park's path-edge table directly, and the sweep is waited for if its owner goes away); the
  biome look-map rows read a copy of the shore data, not the terrain node, so quitting or pressing
  Retry mid-bake cannot free data a worker is using; the iris colony trim no longer waits on the
  shared thread pool from the main thread (it was likely behind one 10 s menu frame), and it now
  reports `flowers.trim_read`, `flowers.trim_wait` and `flowers.trim_apply` separately.

### Caches

No new caches were added. The two that already existed are both in `user://shinrai_cache/`
(on Windows `%APPDATA%\Godot\app_userdata\Shinrai\shinrai_cache\`):

| File | Saves | Key (sha256 of) |
|---|---|---|
| `navigation_<key>.bin` | the walk graph, about 10 s | `NAV_CACHE_VERSION` and grid constants, shoreline, terrain heights, bridge walks, path-edge table, the park script's route constants, every layer-1 collider, the Creator layout. The 8 newest are kept. |
| `understory_<key>.bin` | understory placement, about 6 s | `CACHE_VERSION`, bed limit, tree positions, centres, sockets, and the sha256 of the 7 scripts that decide the placement |

`navigation_key_rows.txt` is a debug listing of the key's parts, written with `--profile-startup`.
To clear the caches, quit the game and delete the `shinrai_cache` folder; the next launch rebuilds
them (that is a cold launch). Each fruit-garden draw (1, 2 or 3 trees; the seed is random per world)
has its own navigation file, so a player reaches fully warm launches after a few starts.

### Numbers

Dev laptop, Steam running, `--midori-fruit-seed=13` (the single-tree draw the baseline fingerprint
has; seed 7 above grows 3 trees and does not match it).

| | Before (busy machine) | Warm | Cold |
|---|---|---|---|
| World ready | 199.3 s (153 s quiet) | **98.3-99.0 s** | **117.0 s** |
| Worst frame with the menu up | 4.73 s | 2.98-3.22 s | 3.03 s |
| Menu frames over 1 s / over 0.5 s | 37 / 90 | 14-15 / 48-49 | 15 / 54 |
| DEPLOY to raid view | 1.1-1.5 s | 0.9 s | |
| Worst frame, first 5 raid seconds | 274-289 ms | 256 ms | |
| Second deploy | 0.4-0.7 s | 0.34 s | |

Cold costs about 18 s more than warm: navigation 10.2 s instead of 0.26 s, understory 6.6 s instead
of 0.4 s. Both caches rebuilt byte-for-byte identical in every cold run.

Checks: the world fingerprint (`tests/probe_world_fingerprint.gd`, compared with
`fp_compare.ps1` from the session scratchpad) matches the pre-speed baseline in every group except
the four that change from run to run (ExtractionRun, clubhouse, park props, wildlife). The
navigation cache key, which hashes every collider, the heights and the path edges, equals the
baseline's. `tests/test_extraction.gd` (headless) and `tests/probe_boot_time.gd` pass.

### Open items

- **Under 75 s is not reached.** What is left on the path: the terrain is installed at about 39 s
  (7 s waiting for woodland diversity, a 5 s drape); the producer chain to park cover ends at about
  75 s (`garden_spots.wait_nature` 30-40 s, `breeze.install` 9-16 s); then `world_complete` takes
  19.5 s, of which the biome builders run one after another for 15.8 s. Caching the finished biome
  planting per park version is the largest remaining lever.
- **Menu frames over 0.5 s: 48-54 (target 0).** The worst is still the park scene instantiate frame
  (about 3 s). One earlier run had a 10 s frame when the desire paths finish: several producers wake
  in that frame and run without a checkpoint. The iris trim part of it is fixed; if it comes back,
  the new `flowers.trim_*` stages show whether reading the grass buffers is the cost.
- **Creator Mode refuses to boot** ("The park furniture has changed"): `midori_2050_identity.gd`
  gained budget checkpoints in the menu-first work, so its sha256 no longer equals
  `COMPATIBILITY_SOURCE_SHA256` in `scripts/creator/creator_identity_adapter.gd`. Needs its owner to
  confirm the adapters and update the constant (`a06ccd38…`). Predates the speed work.
- The merged south-street meshes' normals differ by up to 0.0001 (they no longer go through the GPU's
  16-bit round trip). Not visible; the fingerprint does not hash normals.
- The navigation cache key does not include `extraction_navigation.gd` itself: after editing how the
  graph is built, bump `NAV_CACHE_VERSION`. The understory key hashes script files, which an export
  with binary scripts may not contain.
- Quit or Retry during the boot can still leave a few pure-data worker tasks or threaded loads
  unclaimed (lake life, park floor, near-city mip tasks, some resource requests). No crash, a warning
  at exit.
- Not covered by the fingerprint: vertex normals, materials beyond their class, light positions and
  the ground texture. The ground-texture report's `tree_count` now reads 754 instead of 728: the
  count is taken when the mask finishes, and 26 later trees (25 sparse-gap trees, 1 plaza shade tree)
  now arrive during it. The mask
  itself reads the tree list when it starts, so it uses the same 728 trees as before.
- Timings move by 20 % with Steam or OneDrive busy; compare runs made under the same load.

## Park build speed, pass 2 (2026-11-08, afternoon)

Same rules as pass 1: nothing removed, thinned, reseeded or moved after `world_ready`. Result on a
clean machine: **warm 83-86 s** (best role runs 78 s), **cold 99.9 s**. The 75 s target is still
missed. The pass-1 numbers above are superseded by this section.

### What changed

- **Scene load** (`shinrai_bootstrap.gd`, new `shinrai_scene_prefetch.gd`): helper threads load the
  park scene's plain assets while the scene request runs; the scene finds them already loaded.
- **Park blockout** (`midori_park_size_blockout.gd`, `midori_horizon.gd`, `midori_bridge_walks.gd`,
  `midori_pitch_remaster.gd`, `midori_walk_materials.gd`): the park-instantiate frame is split
  (3.2 s -> 1.4-1.5 s); path strips share one shader and build vertices on workers; the bank fit and
  bridge loops run on workers; the lake-ground shader is compiled once instead of six times.
- **Terrain** (`midori_terrain.gd`): tile vertex arrays are built on the height-grid worker; the
  drape lift of 338k plant instances is computed on workers from a copy of each batch and written
  back in walk order (a batch resized in between is lifted live instead).
- **Ground mask** (`midori_ground_texture.gd`): computed in bands on workers from data copied when
  the mask starts. Its report's `tree_count` is now taken from that copy (728, not 754): the mask
  itself always used those 728 trees, the texture is identical.
- **Alley life, corporate edges, south street, garden spots, near-plant shadows**
  (`midori_alley_life.gd`, `midori_corporate_street_edges.gd`, new `midori_primitive_sources.gd`,
  `midori_south_street.gd`, `midori_garden_spots.gd`, `midori_near_plant_shadows.gd`): alley
  dressing built on one worker in the same order; repeated box meshes, primitives and the
  plant-shadow shader shared instead of rebuilt.
- **Biomes and worn paths** (`midori_biomes.gd`, `scripts/biomes/*`, `midori_worn_paths.gd`,
  `extraction_run.gd`, `shinrai_world_complete.gd`): look maps are baked on a worker as soon as the
  terrain is installed, the worn-path map as soon as the desire paths finish (both used only if
  their inputs are still equal); one fast copy of the biome weight maths is shared by the builders;
  the thinning pass reuses its park walk.
- **Review player** (`midori_park_size_blockout.gd`): it now ignores mouse look in the single frame
  it is live before the run disables it, so its pose no longer depends on where the mouse moved.

### Caches

No new disk caches. The look-map prebake and worn-path prepaint are in memory only and are
discarded if their inputs changed. The two existing caches (navigation, understory) are unchanged;
see the pass-1 table above for where they are and how to clear them.

### Numbers (`--midori-fruit-seed=13`, menu probe, clean machine)

| | Original | Pass 1 | Pass 2 |
|---|---|---|---|
| World ready, warm | 153 s quiet / 199 s busy | 98-99 s | **83-86 s** |
| World ready, cold | - | 117 s | **99.9 s** |
| Worst menu frame | 4.73 s | 2.98-3.24 s | 2.56-3.22 s |
| Menu frames over 0.5 s / over 1 s | 90 / 37 | 48-54 / 14-15 | 40-43 / 10-11 |
| DEPLOY to raid view | 1.1-1.5 s | 0.8-1.2 s | 0.8-1.5 s |
| Worst frame, first 5 raid seconds | 274-289 ms | 249-301 ms | 253-305 ms |

**Memory warning (measured 16:20-16:30):** a boot commits about 20 GB of private memory (working set
only 1-3 GB). The pass-1 files, swapped in for one run, commit the same 20 GB at the same pace, so
pass 2 did not cause it. On this 15 GB laptop, with about 16 GB already committed by other programs
(Steam, NVIDIA App, Discord, Edge), the boot then pages to disk and every run after about 15:30 took
104-205 s. Those runs are invalid as timings; check free RAM before measuring.

### Open items (pass 2)

- 75 s warm not reached. Left on the path: the terrain gate (about 15 s, mostly waiting for woodland
  diversity), south street (about 8.5 s on the main thread), and the biome builders (13.5 s, run after
  every producer; a placement cache was judged unsound because builders query physics and other
  producers' output).
- 40-43 menu frames over 0.5 s (target 0); the largest are the desire-paths-finish frame
  (2.5-3.8 s), the breeze install slice and the frame where the raid is created.
- DEPLOY to raid view: pass-2 samples range 0.8-1.5 s against 0.8-1.2 s in pass 1. Not proven worse;
  needs an A/B on a quiet machine.
- Find what commits the 20 GB during a boot (true for pass 1 too).
- Quitting or pressing Retry mid-boot can leave the ground-mask, biome-prebake and worn-path-prepaint
  worker tasks unclaimed (a warning at exit), and Retry blocks on them for a few seconds. The ground
  texture is not reinstalled after Retry (older bug).
- Carried over: Creator Mode sha256 check of `midori_2050_identity.gd`; headless `shrine_approach.gd`
  errors; the books shop's unseeded `pick_random()`. Pass-2 edits mark saved Creator layouts stale
  (their key hashes every `midori*.gd`), although the world is the same.

## Boot memory (2026-11-09, memory-fix round)

Measured with `tests/probe_mem_report.gd` (engine-side samples each second) and the OS sampler
`memwatch2.ps1` (private bytes, WDDM GPU memory), windowed Vulkan Forward+, warm, `--midori-fruit-seed=13`.

### Where the 19-20 GB went (MEASURE)

- ~7.5-9 GB: Vulkan driver memory outside Godot's allocator and outside GPU memory, growing with the pipeline
  counters (1753 surface + 690 specialization + 384 mesh pipelines by world_ready; ~40 MB per distinct shader,
  ~5 MB per pipeline in a micro-benchmark).
- ~7.5 GB: GPU resources charged to the process; 5.1-5.3 GB textures (3.17 GB of them uncompressed RGB8/RGBA8
  from 543 lossless imports), 1.1-1.2 GB mesh buffers (non-indexed horizon / alley / layout meshes).
- ~2.7 GB: Godot's own allocator (never-cleared SurfaceTools, duplicated GLB meshes, build-time layout data).
- Commit limit 27 GB with ~11 GB used by other apps: 3 of 4 measurement boots died at 76-104 s.

### What changed (no visible change; world fingerprint identical except the declared deltas)

- Shaders: `scripts/shinrai_shader_pool.gd` shares one compiled `Shader` per distinct code text; per-instance
  `Shader.new()` sites (lantern flames, ferns, shore plants, screens, grime, turf, paving, fence) route through it.
  The chain-link fence size moved from the GLSL text to a `panel_metres` uniform. 193 -> 135 shaders, 1753 -> 1409
  surface pipelines. Rule: never edit a pooled shader's `code` in place; ask the pool for a variant.
- Textures: 435 lossless `.import` files are now VRAM-compressed BC7 (`compress/mode=2`, `high_quality=true`;
  normal maps also BC7 because some shaders read all three channels). UI/HUD, weapons, images read back by code,
  under-256 px and `BarkDecd.png` stay lossless. Near-city wall arrays and sign atlas are BC7 at runtime
  (`midori_near_city.gd _mip`).
- Geometry: SurfaceTools cleared after `commit()` and quads indexed (alley life, park cover, tokyo roads, near-city
  hero/kit); `scripts/shinrai_mesh_bake_cache.gd` shares one baked copy per (mesh, materials) instead of
  `ArrayMesh.duplicate()` per batch (1,366 fewer mesh copies). Copies that are recoloured afterwards stay private.
- Buffers: desire-path trim and terrain lift read/write MultiMesh buffers once instead of per instance (no
  renderer CPU copy). `shinrai_world_complete.gd` runs `release_build_data()` on every park module, the near city
  (`MidoriHorizon/NearCity`), static helpers, navigation and breeze at the end of the boot (14-38 ms).

### Numbers (integrator, two boots 06:06 / 06:08)

| | before | after |
|---|---|---|
| peak private | 19.4-20.5 GB | 14.86 / 15.04 GB |
| private at world_ready | ~19.4 GB | 14.5 GB |
| MEMORY_STATIC at world_ready | 2.65-2.83 GB | 1.83 GB |
| RD textures / buffers | 5.1-5.3 / 1.1-1.2 GB | 2.89 / 1.14 GB |
| GPU committed (peak) | 7.4-7.6 GB (VRAM full) | 5.45-5.55 GB |
| pipelines mesh / surface / specialization | 384 / 1753 / 690 | 384 / 1409 / 675-677 |
| world_ready warm | 83-86 s | 69.5-69.8 s |

Fingerprint deltas: `vtx_hash` of MidoriAlleyLife / MidoriParkCover / MidoriTokyoRoads / MidoriHorizon (indexing;
triangle counts identical), MidoriHorizon `mat_hash` (BC7 sign atlas), MidoriBasketballCourt `mat_hash` (constant ->
uniform). The integrated run also showed MidoriDistanceDetail -6 MultiMesh nodes (found after the run, not predicted):
batches sharing one baked mesh merged into one far chunk, which renames every later chunk and re-rolls which 25 % skip
shadows (`midori_near_plant_shadows.gd` ranks `sha256(path)`). Fixed afterwards: each former `duplicate()` call takes a
`BakeCache.group_key()` and tags its batch nodes, and distance detail groups by that key (`bake_group` meta) instead of
the shared mesh's id, so the old chunks come back exactly. Verified 2026-11-09 21:36: the 13 touched files parse, and a
fingerprint boot shows MidoriDistanceDetail identical to the reference again (totals back to 67253 nodes / 26228
MultiMesh nodes), leaving only the five deltas above; no script errors, world_complete at 70.4 s.

`tests/test_extraction.gd` 119/0. `tests/probe_boot_time.gd` HQ at 71.4 s against 87.0 s for the same probe on the
reference tree (the 156.8 s figure first quoted came from a loaded machine and is not a fair reference). Menu hitches
(proxies; `probe_menu_time` itself was not run): frames over 1 s about 11 -> 5-6, longest about 2.6 s, unchanged.
The reference boots had 5.6-7.8 GB commit free at start against ~11.4 GB in the after boots, so "no more crashes" is not
yet proven. Full record: scratchpad `mem\integ\INTEGRATION.md`, `mem\<role>\NOTES.md`, `mem\review_measurement\`.

### How to re-measure

1. Close other heavy apps, note commit free (`Get-Counter '\Memory\Committed Bytes','\Memory\Commit Limit'`).
2. Warm boot once (fingerprint or any boot), then run `tests/probe_mem_report.gd` windowed with
   `--midori-fruit-seed=13` while `memwatch2.ps1` samples private bytes and WDDM GPU memory every 2 s.
3. Read peak private, private / MEMORY_STATIC / RD textures / pipelines at `world_ready`, and the world_ready time.
4. Run `tests/probe_world_fingerprint.gd` and compare against the saved reference; run `probe_menu_time` for hitches.

### Guardrails for new content

- A memory budget check in the tests: fail when peak private or RD textures at world_ready grow past a set margin.
- New texture imports default to VRAM-compressed (BC7, high quality, mipmaps), except UI and images read by code.
- Warn on duplicate shaders (same code text, different `Shader` objects) and duplicate meshes in the boot probe;
  new per-instance shaders go through `shinrai_shader_pool.gd`, baked part copies through `shinrai_mesh_bake_cache.gd`
  (with `group_key()` / `tag()` on every batch built from them).
- Streaming or a saved park once the world grows past what one boot can hold.

### Round 2 (2026-11-09 evening)

Measured on one warm Vulkan boot each (seed 13), after commit 3819733:

| | round 1 | round 2 fixes | + pipeline cache off |
|---|---|---|---|
| peak private | 15.0 GB | 14.1 GB | 13.3 GB |
| GPU committed (peak) | 5.45 GB | 4.85 GB | 4.76 GB |
| RD textures | 2.89 GB | 2.45 GB | 2.45 GB |
| MEMORY_STATIC at world_ready | 1.83 GB | 1.82 GB | 1.55 GB |
| surface pipelines | 1409 | 1331 | 1331 |
| world_ready | ~70 s | 67.8 s | 66.8 s |

- Fixes: 23 more duplicate shaders pooled (body status, barrel fires, city glow, wildlife, hill rings) and one lantern
  flame text; near-city shells no longer upload an all-zero UV2; one fine-timber grain texture instead of two; four
  civic SVG signs BC7; nine layered scav body textures limited to 2048 px (the only change that is not strictly
  invisible: softer only closer than ~0.8 m); reflection atlas 64 -> 32 slots (22 probes exist); desire-path
  `paving_cells` and small boot-only tables freed in `release_build_data()`; the lake planar reflection renders once per
  30 frames while the root viewport has 3D disabled (boot).
- `rendering/rendering_device/pipeline_cache/enable=false`: Godot's in-memory copy of every compiled pipeline cost about
  0.8 GB; the GPU driver keeps its own on-disk shader cache, and the warm boot was not slower without it. Re-check the
  load time after a driver update or on another GPU.
- Fingerprint: the five round-1 deltas plus `BiomeMossGarden.mat_hash` (shared flame text), as predicted.
- Not a boot lever: soft shadows on lamps (`light_size > 0`) add ~145 specialization pipelines only when night falls
  (+157 vs +12 with hard shadows). Textures held by scripts but not drawn: 310 MB (238 MB park assets, 48 MB scavs).
- Direct3D 12 (`--rendering-driver d3d12`, trial only): peak private 12.0 GB but GPU committed 8.5 GB. Cause measured
  with `tests/probe_mem_small_buffers.gd`: D3D12 rounds every GPU buffer up to 64 KB (20,000 tiny MultiMeshes = 1.29 GB,
  20,000 one-quad meshes = 3.75 GB; 0.07 GB on Vulkan). The park has 26,222 MultiMesh nodes and 11,534 unique meshes, so
  about 5 GB of D3D12's memory is rounding. Next step: merge static meshes per module and map cell, free the hidden
  distance-detail sources, build tiny plant clusters as fewer MultiMeshes; then D3D12 should land near 7-8 GB.
- Pending: `tools/bridge_artwork_bc7.gd` (bridge textures to BC7, ~0.1 GB) did not pass its own dry run yet;
  `tests/probe_mem_near_city_index.gd` needs the UV2 expectation updated (round2 REQUESTS.md).

### Round 3: end-of-boot consolidation (2026-11-10)

`scripts/shinrai_consolidate.gd` runs once per park from `extraction_run.gd`, after the render budget (so draw
distances are already assigned) and before HQ; raid path only. Switches after `--`: `--no-consolidate`,
`--no-consolidate-plants`, `--no-consolidate-merge`, `--no-consolidate-street`. Report: `SHINRAI_CONSOLIDATE {json}`
and park meta `shinrai_consolidation`. Takes about 1.3 s of the boot.

- Plants: frees the 7,057 source batches distance detail copied and hid, and the 1,220 cells the Bush006 swap hid
  (MultiMesh nodes 26,228 -> 17,951).
- Static merge (`shinrai_static_merge.gd`, corporate district only): 5,539 single-use boxes -> 425 merged meshes
  (unique meshes 6,309 -> 1,191), same Material objects, triangles equal (75,168), collision carriers kept with
  `mesh = null`. A raw reference count cannot tell single-use meshes apart (meshes in the tree carry engine-side
  references); the per-module use count is the test.
- South Street (`shinrai_street_consolidate.gd`): identical primitives shared and hidden-for-good visuals freed
  (unique meshes 2,023 -> 712, 519 nodes freed).
- Result: nodes 67,355 -> 53,588; MEMORY_STATIC 1.55 -> 1.35 GB. Same-camera day captures (three corporate views,
  five park views) match with it off and on.
- Memory, one boot each: Vulkan peak private unchanged (13.3-13.5 GB). Direct3D 12 11.36 -> 10.96 GB; its reported
  video memory in use falls 8.8 -> 6.9 GB, but the freed 64 KB slots are not returned to the system because the
  pieces are created during the boot and freed at its end. To bank that ~1.9 GB the builders must not create them in
  the first place (build the district merged, give hidden sources no GPU buffer).
- Designs for the next steps (shader set, streaming, plant batches) concluded: on Vulkan about 7 GB is driver memory
  that follows pipeline count; same-picture shader merging is worth an estimated 1-3 GB for a large effort; streaming
  a 440 x 360 m park saves ~25 MB on Vulkan. Under 8 GB is only plausible on Direct3D 12.

### Open items (boot memory)

- Specialization pipelines (677, ~3-4 GB): nearly all appear when the lake reflection SubViewport first renders;
  giving it the main view's scene-state flags is the biggest remaining lever (needs a night capture pair).
- 23 duplicate shaders remain (body-status bone shader, park-cover barrel fire x7, horizon, wildlife): ~0.5-1 GB.
- Freeing hidden distance-detail sources (two biome steps still read them), the warm-up latch superset, and a
  D3D12 trial are later rounds. 1.2 GB of orphaned lossless `.ctex` files remain in `.godot/imported`.
- The probe's data walk hits 4 freed-object references per boot (`probe_mem_report.gd:509`); harmless, but find
  the owner and clear the stale reference.
- Commit headroom is still thin with Steam/Discord/Edge open (system commit peaked at 30.6 GB during a boot).
- BC7 quality, measured 2026-11-09 with `tests/probe_mem_texture_quality.gd` (imported copy vs source file, no park
  boot): 434 textures compared, median PSNR 45 dB, 5th percentile 31 dB, alpha cut-out flips at most 0.19 % of pixels.
  Lowest: `cat_cafe_neon_text.png` 25 dB, `realistic_trees_collection` leaf base colours 26-28 dB, lilac billboard
  normals 28 dB; worth a side-by-side in game if any look off. Nine night views (`BIOME_NIGHT=1` with
  `tools/biome_capture.gd`) render with lanterns, lamps, neon and the lake intact; there is no night "before" set.
- Raid, measured 2026-11-09 with `probe_menu_time --second-deploy`: menu worst frame 2.59 s, over 1 s 5 (was 10),
  over 0.5 s 27 (was 40-43); raid start hitch 0.37 s, first 5 s in the raid average 19 ms a frame, worst 0.26 s;
  second deploy 0.23 s. Private memory stays at 15.0 GB in the raid (no growth), GPU 5.45 GB. Free RAM fell to
  0.3 GB and system commit reached 28.8 of 30.0 GB during the boot.
- `midori_terrain.gd` lift copies each batch's buffer at the start of the walk and writes it back at the end; a
  module that edits the same batch's transforms in between (none found) would be undone.
- Longer raid play (walking the park, combat) is still unmeasured; the probe covers only the first 5 s.
