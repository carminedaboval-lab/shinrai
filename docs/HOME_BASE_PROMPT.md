# Prompt: build the player's home base (Utsukushii)

Paste everything below the line into the other AI, with this project folder open.

---

You are working in the Shinrai repository, a first-person extraction shooter in Godot 4.7 (GDScript). Read `CLAUDE.md` and `docs/CLOUD_START_HERE.md` first. The owner is not a programmer: report in plain language and short sentences.

## The job

Build the first walkable version of the player's home base, called Utsukushii. It is the place the player is in between raids. Today that role is filled only by a menu screen (the HQ menu). Build the base as its own small level. Do not remove or restyle the existing menu; the base sits alongside it until the owner approves the swap.

## What the base must contain (the owner's own design)

1. **The player's apartment.** The player starts here. It holds their stash, a weapon bench and a bed. It can be upgraded: upgrades add storage, a better bench and a medical corner. Build level 1 fully and leave clear hooks for levels 2 and 3.
2. **A few big apartment blocks** around the edge. The player's apartment is inside one of them. The others are exteriors only.
3. **A circular market in the middle** with three traders at stalls around the ring: a health trader, a gun trader and an armour trader. Standing in the centre you can see all three.
4. **A lounge** with seating facing a big screen that shows the news. The screen shows text bulletins that can be changed from a data file, for example robots closing streets in the city.
5. **A small arena** for 1v1 and 2v2 practice fights. No loot is at risk in it. There is no multiplayer yet, so put one practice bot in it for now.
6. **A tram platform** at one edge. This is how the player leaves for a raid. Walking onto the waiting tram starts the raid (call the existing deploy path; see `scripts/extraction_run.gd` `start_run`). The tram model and code already exist: `scripts/shinrai_rail_tram.gd`.

## Size and feel

- Small on purpose: about 150 metres across, everything within a one-minute walk.
- A mountain settlement outside the city: lived in, a little improvised, built by survivors and outsiders hunting the city's technology. Japanese setting, year 2050.
- It must not look repetitive. Each building has its own shape and purpose. Old low buildings mixed with newer structures.
- Realism first. The owner rejects anything that looks fake or low quality.
- Never fake detail with stripes, ribs, seams, slats or streaks. No plants in rows.
- Greens are muted olive, never lime. Paths are painted into the ground, not overlaid strips.

## Technical rules

- Make it a separate scene, `res://scenes/shinrai_home_base.tscn`, with its own script(s) under `scripts/home_base/`. Keep it light: it must load in a few seconds and stay small in memory, because the city map will be loaded in the background while the player is here.
- Reuse existing systems. Do not write new ones for: the player (`scripts/player.gd`), the profile and stash (`scripts/extraction_profile.gd`), credits and the sell/medkit/pack-upgrade actions (see how the HQ menu calls them in `scripts/extraction_run.gd` `_on_action`), and weapons (`scripts/extraction_weapon_catalog.gd`).
- Traders open the existing buy and sell actions for now. Armour does not exist in the game yet: build the armour trader's stall and a "coming soon" stock list, and write down what an armour system would need. Do not invent one.
- **Do not change the inventory system or how it looks.** Do not restyle any menu (`scripts/ui/*`, `scripts/extraction_hud.gd`, `scripts/shinrai_loading_screen.gd`).
- Never use the real save `user://shinrai_extraction_v1.json` in tests. Use a separate test profile path.
- Run Godot only through `tools/godot_locked.ps1`, one Godot at a time. Another session may be using it; wait for the lock, do not bypass it. Add `--fixed-fps 60` before `--script` for windowed tests.
- Tests must not capture the mouse (see `test_input_override` in `scripts/player.gd` and how `tests/train_ride_capture.gd` does it).
- Do not edit these files, another session is working in them: `scripts/shinrai_rail*.gd`, `scripts/shinrai_settings.gd`, `scripts/midori_park_fence.gd`, `scripts/shinrai_shader_warmup.gd`. If you need a change there, say so instead.
- Do not commit or push. The owner approves commits.

## How to work

1. First read the code and write a one-page plan: the layout with rough positions and sizes, which existing assets you will reuse, and what is missing. Show the owner a simple top-down sketch of the layout before building.
2. Build in this order, showing pictures after each step: ground and building shells, the apartment interior, the market and traders, the lounge and news screen, the tram platform that starts a raid, then the arena.
3. For every visual step show same-camera pictures, and say plainly what still looks wrong.
4. Add a test that walks the whole loop with a test profile: start in the apartment, open the stash, buy from a trader, board the tram, and confirm a raid starts.

## Done means

The owner can start the game, wake up in the apartment, walk to the market and trade, read the news screen, fight the practice bot, and board the tram to begin a raid, with the test passing and nothing in the existing menus or inventory changed.
