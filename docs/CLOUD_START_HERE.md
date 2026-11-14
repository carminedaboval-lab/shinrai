# Shinrai: start here (for AI agents and new contributors)

Last refreshed 2026-11-12. If something here disagrees with the code, the code wins: fix this page.

Shinrai is a first-person **extraction shooter** set in an evacuated Tokyo in 2050. You ride a tram into the city, loot, fight, and ride a tram out before lockdown. It is built in **Godot 4.7.2 (Forward+)** with GDScript. The playable world today is **Midori Park**, a 440 × 360 m park (world x −220..220, z −180..180, north = −z), its ring road and tram line, and the north shop street. The rest of the city is mostly backdrop.

**What the game is meant to become** is in [GAME_DESIGN.md](GAME_DESIGN.md): what the owner decided, what is only a proposal, and what is open. Read it before changing any gameplay rule.

The owner is not a programmer. Report in plain language and short sentences.

## State of the repository

- Work happens on branch `street/drains-curbs-sidewalk-realism`. On 2026-11-12 it was 9 commits ahead of `origin/main` and **not pushed**.
- The working tree also holds a lot of **uncommitted work from several AI sessions** (home base, the midge enemy, shop streets, gun and bodycam changes). Run `git status` before you start.
- **Never commit or push without the owner's approval.** Never commit another session's files.
- `git` is not on PATH. GitHub Desktop's copy is under `%LOCALAPPDATA%\GitHubDesktop\app-*\resources\app\git\cmd\git.exe`.
- The project folder is inside OneDrive. Sync has been measured slowing park boots from about 152 s to about 200 s over a day of test runs. Pause sync before comparing timings. Do not keep tools or results only in a temporary folder; they have been wiped before.

## Run it

- Godot is at `%USERPROFILE%\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe`.
- To play, double-click one of the launchers in the project folder:
  - `PLAY_SHINRAI.cmd`: the normal game. Main scene `res://scenes/shinrai_bootstrap.tscn`.
  - `Play Utsukushii.cmd`: the walkable home base, `res://scenes/shinrai_home_base.tscn` (in progress).
  - `Play Shop Streets.cmd`: the normal game, but raids begin in the shop streets district (`-- --spawn=shop_streets`).
  - `Play Map Blockout.cmd`: the whole 5 km² Map 1 plan as a grey blockout at true size, to walk and fly through (`res://scenes/shinrai_map1_blockout.tscn`). A layout test, not art; it opens in seconds.
- **Every automated Godot run goes through `tools/godot_locked.ps1`.** It takes a lock so only one Godot runs at a time, and runs at below-normal priority. Two renders at once have crashed the NVIDIA driver, and several sessions share this PC.

  ```powershell
  .\tools\godot_locked.ps1 -Out "$env:TEMP\shinrai_test.log" -TimeoutSec 900 -GodotArgs "--headless --path . --script res://tests/test_extraction.gd"
  ```

  - Errors go to `<out>.err`. Read both files.
  - For windowed tests add `--fixed-fps 60` before `--script`. Without it an unfocused window runs uncapped and frame-counted waits fail falsely.
  - Tests must not capture the mouse (see `test_input_override` in `scripts/player.gd`).
  - Tests never use the real save `user://shinrai_extraction_v1.json`.
- **Boot time on the dev laptop** (RTX 5050 Laptop, 8 GB video memory, 15 GB RAM): the menu appears in about 1 s, and the park finishes building behind it in about 67–70 s on a warm launch. A cold launch has not been re-measured since the memory work; it was about 100 s before it. The very first open of the project imports a lot of assets.
- **Memory:** a park boot peaks at about 8.6 GB for the game process at the default MSAA 4x + FXAA. Temporal anti-aliasing costs about 5 GB more on this driver; it is a menu option, not the default. Check free memory before a park boot, and skip the boot if another Godot is running.

## Tests

- Main suite: `tests/test_extraction.gd` (last recorded result: 119 passed, 0 failed).
- Also: `test_extraction_routes`, `test_park_perimeter`, `test_scav_combat`, `test_open_lawn_cover`, `test_survival_physics`, `test_salvage_choice`, `test_bridge_walk`, `test_mantle_physics`, and `raid_clock_check`.
- A park test boots the whole park (allow 300 s). Run suites one at a time.
- Small, fast tests that do not load the park exist for the bodycam and guns (`tests/bodycam_capture.gd` uses a test yard that loads in seconds). Prefer that pattern for gameplay work.
- **Enemy AI has its own fast test yard:** `tests/probe_scav_ai.gd` runs the scav crew through nine situations in about 20 s, headless. See [SCAV_AI.md](SCAV_AI.md).
- Known bad: `test_drone_police` is unreliable. The three `test_k17_*` files test a drone the raid no longer spawns, and `test_k17_integration` hangs.
- There is no continuous integration. The only GitHub workflow fetches ground textures.

## Key docs (read in this order)

1. [GAME_DESIGN.md](GAME_DESIGN.md): the design decisions, proposals and open questions.
2. [MAP1_MEASURED_PLAN.md](MAP1_MEASURED_PLAN.md): **the current map target.** 5 km² (2.05 × 2.44 km), 43 players with backfill, 20 districts with rule sheets, 10 stations, 12 drop-offs with bot posts between them, build order. A draft awaiting the owner's approval. Its distances are checked by `python tools/map_plan/check_map1.py`. The map picture, the encounter picture (scav coves, robots, birds: `docs/map_concept/map1_encounters_draft4.png`), the real ground heights and the grey blockout are all made by `python tools/map_plan/build_map1_blockout.py` from `data/map1/map1_plan.json` (sections 2f, 2g, 4c, 4d and 8 of the plan). `python tools/map_plan/audit_map1.py` checks the map is fit to play on (48 checks). The loot, salvage, materials, workbench and robot-armour plan is [LOOT_AND_CRAFTING_PLAN.md](LOOT_AND_CRAFTING_PLAN.md). Its mood picture is `docs/map_concept/city_map_concept_approved_look.webp`.
3. [LOADING_AND_MENUS.md](LOADING_AND_MENUS.md): how the game boots, the speed and memory work with all its measurements, and the guardrails for new content.
4. `EXTRACTION_BUILD.md` (project root): the build log. Detailed, but its oldest sections describe earlier checkpoints.
5. [home_base/README.md](home_base/README.md) and [UTSUKUSHII_LAYOUT.md](UTSUKUSHII_LAYOUT.md): the walkable home base.
6. [PARK_BIOME_PLAN.md](PARK_BIOME_PLAN.md) and `docs/biome_concepts/`: the eight park biomes, concept art (`after_*.png`, `extra/after_*.png`) and in-game comparison sheets (`built/**/*_sheet.png`). `built/round4/PROGRESS.md` is the latest biome status.
7. [weapon_realism_20261107/README.md](weapon_realism_20261107/README.md): the guns, rebuilt as their real counterparts. Before/after sheets are in `sheets/`.
8. [GRAPHICS_UPGRADES.md](GRAPHICS_UPGRADES.md), [FREE_ASSETS_REPORT.md](FREE_ASSETS_REPORT.md), [ASSET_SHORTLIST_1.md](ASSET_SHORTLIST_1.md): graphics options and outside assets researched.

Older plans, kept for reference: [MAP_LAYOUT_PLAN.md](MAP_LAYOUT_PLAN.md) (smaller maps; its XP and skill proposal is still the only one) and `CITY_DISTRICTS_PLAN.md` (the earlier circular 9.6 km² city and district lore).

## Where things stand

- **Raid loop (works, solo PvE):**
  - The raid begins aboard a tram, which stops at a random stop the player did not choose (`scripts/shinrai_rail.gd`, ten stops on the ring road).
  - Recover at least 1 of 3 telemetry relays. Then leave by boarding the tram at any stop and staying aboard, or at the South or West park gate with a 15 s hold.
  - The raid lasts **46 minutes** (`RAID_SECONDS` 2760 in `scripts/extraction_run.gd`). Threat rises over it, drone sweeps enter at 17 and 32 minutes, and a last tram is called with 3 minutes left.
  - Enemies: police spider-drone packs and a 3-person scav crew.
  - Systems in place: survival metabolism, a per-limb medical model, an inventory with backpacks, and an Operations menu (HQ) with credits, stash and pack upgrades.
- **In progress, not committed (check `git status`):**
  - **Home base, Utsukushii:** apartment, market, lounge, practice yard and tram platform (`scripts/home_base/`). The apartment is being reviewed section by section. The full tram-to-raid route is not yet verified.
  - **Midge:** a small starter flying enemy (`assets/enemies/midge/`, `tests/test_midge*.gd`).
  - **Shop streets, district 1:** the streets north of the park made walkable, slice 1 (`scripts/midori_shop_streets.gd`, `reports/shop_streets/`).
- **Not built yet:**
  - XP, levels and skills.
  - Death and gear rules beyond "unbanked items are lost".
  - Multiplayer: there is no networking code at all.
  - Robots, loot tiers by zone, and the map beyond the park and its streets.
- **Biomes** (`scripts/midori_biomes.gd`, plus builders in `scripts/biomes/`):
  - All eight are installed and built as the last step of the park boot.
  - The sakura lawn uses a procedural Somei-yoshino generator, `scripts/biomes/sakura_tree_generator.gd`, which the owner approved.
  - `MIDORI_BIOMES_OFF=1` disables all biomes. `MIDORI_BIOMES_ONLY=name,name` runs only the named builders.
- **Guns:** rebuilt to real dimensions (builders in `tools/weapon_real/`). The Glock 17 (in-game "Akane") is the furthest along: baked wear skin, true-size hands, a rebuilt reload. As of 2026-11-10 the other guns still used the enlarged hands and had no baked skin; per-gun open items are in `docs/weapon_realism_20261107/HANDOVER_PER_GUN.md`. The optics were not rebuilt.
- **Bodycam:** an optional chest-camera view (F4), `scripts/fx/bodycam_rig.gd`. Tuned for the pistol first. Sheets in `reports/bodycam/`.
- **Anti-aliasing:** MSAA 4x + FXAA by default, chosen by the owner from same-camera sheets (`reports/smoothing/`). Settings live in `scripts/shinrai_settings.gd`.

## Rules that keep the game fast and small

Full detail is in [LOADING_AND_MENUS.md](LOADING_AND_MENUS.md) under "Guardrails for new content".

- New texture imports are VRAM-compressed (BC7, high quality, mipmaps), except UI and images read by code.
- A new shader built in code goes through `scripts/shinrai_shader_pool.gd`. Never edit a pooled shader's code in place.
- Baked copies of a mesh go through `scripts/shinrai_mesh_bake_cache.gd`, with `group_key()` and `tag()` on every batch.
- Long work during the boot takes turns through `scripts/shinrai_loading_budget.gd` so the menu stays responsive.
- To prove a change left the world the same, compare `tests/probe_world_fingerprint.gd` output before and after.
- Memory tools: `tools/mem_probe.ps1` and `tools/mem_watch.ps1`. The owner wants memory reported for the game process only.

## Capture tools

- `tools/biome_capture.gd`: same-camera biome shots. Set `BIOME_VIEWS=view,view`; PNGs go to `user://biome_build/`. `BIOME_NIGHT=1` for night.
- `tools/tree_closeup_capture.gd`: close-ups of the cherry trees.
- `tools/render_midori_biomes.ps1`: a locked, verified capture runner (Windows).
- `tools/weapon_real/`: gun builders and render/validation.
- `tests/bodycam_capture.gd`, `tests/train_ride_capture.gd`, `tests/home_base_capture.gd`, `tests/district_capture.gd`: capture runs for those areas.
- Finished comparison sheets for the owner go in `reports/`.

## The owner's standing preferences (important)

- Realism first. They reject anything that looks fake or "low quality".
- **Never fake detail with stripes, ribs, seams, slats or streaks.** No plants in rows or lattices.
- Paths are painted into the ground shader (DayZ style), never overlaid strips.
- Greens are muted olive, never lime.
- **Nothing may pop in or vanish while in view.** Swaps happen only out of view. Streaming and baking are welcome if they are faster with no visible pop-in or quality loss.
- Always show **same-camera before / now / concept** images for any visual change. Work area by area, and don't move on until an area matches its concept.
- Show any outside model, texture or sound to the owner and get a yes before downloading or using it.
- Fill open details with sensible defaults and label them **(default)**, instead of sending a list of questions.
- Large binary assets are committed directly; the repo does not use Git LFS. Keep single files under 100 MB.
- Bulky intermediate renders are ignored by `.gitignore`. Regenerate them with the tools above.

## What to build next (set 2026-11-13, after the Map 1 layout was closed for a first pass)

The plans are written and checked; almost none of it is game code. In order, with what each one unlocks:

1. **The owner walks the blockout** (`Play Map Blockout.cmd`). Nobody has yet judged draft 4 on foot. Layout changes are cheap now and dear later.
2. **One real house in the test yard:** two floors, an inside stair, one locked room, one window that breaks. It proves the interior kit that 3,500 open buildings depend on (`docs/GAME_DESIGN.md` 7b).
3. **Doors and glass:** the locked door and the crowbar; a smashed window that can make you bleed, a shot-out one that does not unless you touch the frame. With a headless probe, like the bird probe.
4. **The first robot and its recharge station:** the hum from 25 m, the lights changing at 12 m, waking at 6 m; stripping it for a power cell and its access chip, which opens locked doors quietly (`docs/LOOT_AND_CRAFTING_PLAN.md` 7).
5. **Materials and breaking down** at the workbench (`data/design/crafting.json`). The home base files belong to another session: agree with it first.
6. **The mission screen and the first three missions,** with the choice of who gets a piece of evidence (`data/design/missions_line1.json`, `docs/STORY.md`).
7. **Then the districts for real,** in the order of `docs/MAP1_MEASURED_PLAN.md` section 6, starting with the shop streets north of the park.

**Known and owed, said by the owner on 2026-11-14:** the Map 1 roads "look awful" in the world pictures. They are only flat colour painted into the ground picture: no kerbs, no pavements, no markings, no surface. That is expected at this stage and is a pass of its own once the basics are in; when it is done, show same-camera before and after. The owner's target picture for it is `docs/art_targets/street_target_01.webp` (a guide to copy the look from, not a texture to use): coarse dark asphalt, one worn white edge line, a concrete gutter strip with a drain grate, a low kerb of separate concrete blocks, a narrow asphalt pavement, a concrete utility pole standing in the pavement, block garden walls with railings on top. The houses get their detailing at the same point ("once the basics are finished").

**Road pass started 2026-11-14, with Codex (the ChatGPT app), uncommitted.** Three streets of Map 1 now have real edges; every other road is still the flat picture.

- **What builds it:** the map file lists the streets to build under `street_edges` (`tools/map_plan/build_map1_blockout.py`: "homes street trial", "koban lane", "shop row"). `scripts/map1/map1_street.gd` lays each side: kerb and gutter units, footway, lowered kerbs where a car or a crossing meets it, curved corners into side streets with the road's asphalt carried 3 m in, one grate and one pole, an optional sloping forecourt, and the asphalt ribbon. `scripts/map1/map1_blockout.gd` decides per street what each side gets.
- **Trial homes street** (z = 448, `Play Trial Street.cmd`): both sides, garden walls behind the footway.
- **Koban lane** (z = 413): Codex's café terrace and police box (`map1_koban_lane.gd`) on the same kerb module.
- **Shop row road** (z = -448, x -438 to -231, 14 m wide): shop fronts by trade with cut-letter Japanese signs (`map1_house_dress.gd`, placing in `tools/map_plan/businesses.py`), a forecourt sloping to the shop doors, a zebra crossing and signals, a coin car park in the row's one gap (`map1_car_park.gd` and Codex's fixtures), and on the south side a tree-lined plaza the owner chose over a second row of buildings (`map1_plaza.gd`, Codex's benches and lamps).
- **Whose files:** Codex owns the materials (`map1_trial_asphalt.*`, `map1_shop_footway.tres`, `map1_shop_forecourt.tres`), the props scripts and its walk tests; the map generator, the kerb module, houses and shop fronts are this side's. The two talk in `C:\Users\hp\OneDrive\Documenti\ChatGPT\shinrai\collaboration\road-discussion.md`.
- **Checks:** `tests/probe_map1_street.gd` (47 checks), the world probe groups, Codex's `tests/map1_*_walk.gd`. Views for one's own look: `tests/map1_world_capture.gd` (`wide_road`, `wide_pavement`, `wide_junction`, `wide_plaza`, `plaza_pit`, `corner_kerb`, `corner_island`).
- **Known gaps:** the shop row road has only a centre line on 14 m (shoulders or a bus stop await the owner); side streets are flat picture past 3 m; street trees are the placeholder model; 50 of the 106 named businesses are in buildings that are still grey boxes; the ground picture is drawn up to a metre off a road's true edge when its width is an even number of metres, so take positions from the exported line and width.
- The owner does not want pictures sent unless he asks; open the game at the spot instead (`-- --spawn=x,z,turn`).

**Robot and recharge bay look: postponed by the owner on 2026-11-14** ("we can do the robots when we do the enemies, not now"). The first-pass robot and station work and are tested (`tools/ai/run_robot_probe.ps1`); their art pass, to match `docs/art_targets/robot_and_bay_target_01.jpg`, belongs with the enemy work.

Checks to run after any change to a plan: `python tools/map_plan/check_map1.py`, `python tools/map_plan/audit_map1.py` (48 checks), `python tools/design/check_design.py` (40 checks).