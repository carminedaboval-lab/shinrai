# Shinrai: start here (for AI agents and new contributors)

Shinrai is a first-person **extraction shooter** set in an evacuated Tokyo in 2050. You survive, loot, level up and unlock skills. It is built in **Godot 4.7 (Forward+)** with GDScript. The playable world today is **Midori Park**, a 440 × 360 m park (world x −220..220, z −180..180, north = −z), plus its surrounding streets. The rest of the city is mostly backdrop.

As of 2026-11-07, all work is on `main`. Branch `street/drains-curbs-sidewalk-realism` holds the same commits.

## Run it
- Main scene: `res://scenes/shinrai_bootstrap.tscn`. Raid scene: `res://scenes/shinrai_extraction.tscn`.
- Tests are headless scripts in `tests/`:
  - `godot --headless --path . --script res://tests/test_extraction.gd` (last result: 119/0).
  - Also: `test_extraction_routes`, `test_park_perimeter`, `test_scav_combat`, `test_open_lawn_cover`, `test_survival_physics`, `test_salvage_choice`, `test_bridge_walk`, `test_mantle_physics`.
- A full raid boot takes about **6–8 minutes** on the dev laptop (RTX 5050 Laptop). The first open of the project imports a lot of assets.
- Don't run two Godot renders at once on the same GPU; it has crashed the NVIDIA driver. For captures, use `tools/render_midori_biomes.ps1`, which takes a lock.

## Key docs (read in this order)
1. `EXTRACTION_BUILD.md`: the build log. Current systems, rules and test results.
2. `docs/MAP_LAYOUT_PLAN.md`: **map size, raid length, player count and layout plan.** The user's latest direction:
   - 2–3 player fights per hour.
   - "Big but not too big": about 2.3 km² for Map 1, with 18 players in squads of up to 3 and 50-minute raids.
   - Includes a forest belt and a satoyama village edge.
   - Solo/co-op PvE ships first, because there is no netcode yet.
3. `CITY_DISTRICTS_PLAN.md`: the full 9.6 km² city plan (only the plan exists; it is not built).
4. `docs/PARK_BIOME_PLAN.md`: the eight themed park biomes.
5. `docs/biome_concepts/`: concept art (`after_*.png`, `extra/after_*.png`) and in-game comparison sheets (`built/**/*_sheet.png`). `built/round4/PROGRESS.md` is the latest biome status.
6. `docs/weapon_realism_20261107/README.md`: the guns, rebuilt as their real counterparts. Glock 17 Gen 5, M4A1, SVD, M40A5, AI AW, Scorpion EVO 3, SCAR 17 and Uzi. Before/after sheets are in `sheets/`.

## Where things stand
- **Raid loop (works, solo PvE):**
  - Spawn on the north shop street.
  - Download at least 1 of 3 telemetry relays, then extract at the South or West gate with a 15 s hold.
  - Enemies are police spider-drone packs and a 3-person scav crew.
  - Systems in place: survival metabolism, a per-limb medical model, and an HQ with credits, stash and pack upgrades.
  - `RAID_SECONDS` is currently 7200. The plan says 50 min.
- **Not built yet:**
  - XP, levels and skills (the plan proposes a design).
  - Multiplayer: there is no networking code at all.
  - The larger map beyond the park.
- **Biomes** (`scripts/midori_biomes.gd`, plus builders in `scripts/biomes/`):
  - All eight are installed and run after the raid boots.
  - The sakura lawn uses a procedural Somei-yoshino generator, `scripts/biomes/sakura_tree_generator.gd`, which the user approved.
  - `MIDORI_BIOMES_OFF=1` disables all biomes. `MIDORI_BIOMES_ONLY=name,name` runs only the named builders.
- **Guns:** all seven were rebuilt to real dimensions (builders in `tools/weapon_real/`). The suggested next step is a real PBR materials pass (anodized aluminium, polymer, parkerized steel, wood, edge wear). The optics were not rebuilt.

## Capture tools
- `tools/biome_capture.gd`: same-camera biome shots. Set `BIOME_VIEWS=view,view`; PNGs go to `user://biome_build/`.
- `tools/tree_closeup_capture.gd`: close-ups of the cherry trees.
- `tools/render_midori_biomes.ps1`: a locked, verified capture runner (Windows).
- `tools/weapon_real/`: gun builders and render/validation.

## The user's standing preferences (important)
- Realism first. They reject anything that looks fake or "low quality".
- **Never fake detail with stripes, ribs, seams, slats or streaks.** No plants in rows or lattices.
- Paths are painted into the ground shader (DayZ style), never overlaid strips.
- Greens are muted olive, never lime.
- Always show **same-camera before / now / concept** images for any visual change. Work area by area, and don't move on until an area matches its concept.
- Large binary assets are committed directly; the repo does not use Git LFS. Keep single files under 100 MB.
- Bulky intermediate renders are ignored by `.gitignore`. Regenerate them with the tools above.
