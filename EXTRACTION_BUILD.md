# Shinrai Park: The Quiet Exit

## Play this build

F5 starts the new extraction mode. The original `scenes/midori_park_size_blockout.tscn` remains the non-gameplay park review scene (open it and use F6).

Deploy from Field Operations. Recover at least one telemetry relay by holding E beside a marked park lamp, then remain inside South Gate or West Gate for 15 seconds to extract. Recovering all three relays earns a larger contract bonus. Search the existing bench compartments for salvage and ammunition. Sell extracted salvage at operations and purchase cargo upgrades or an additional medkit.

- WASD: move; Shift: sprint; Space: jump/mantle.
- LMB: fire; RMB: aim; R: reload.
- Hold E: recover telemetry/search nearby furniture.
- Hold H: heal 55 HP over 2.5 seconds; damage or firing interrupts it.
- Tab: field map and cargo; Esc: pause. Both pause the solo raid clock and actors.
- T: switch guidance between remaining relays and extraction.
- F7: High/Balanced rendering. Choose daylight or night before deployment.

The starter kit is always free: UZI, 120 rounds including its loaded magazine, one medkit, six cargo slots. A raid lasts ten minutes. Death, lockdown, abandoning the run or closing the game during a raid loses unbanked items. Stash, credits and upgrades survive. F3 fly mode and Enter-to-restart are disabled only in extraction mode.

## Honest scope of this checkpoint

This is a playable extraction-loop foundation, **not a finished AA shooter**. The K17 model is deferred at the user's request. The menu clearly identifies the current recon build and **no enemies, invisible attackers or replacement proxy models are spawned** while that asset is absent. Gunplay uses the existing UZI/arms asset. Patrol navigation, hearing, line-of-sight combat and asset-gated spawning are wired for K17, but combat balance and model integration cannot be validated until the model is provided.

No new art, models, textures or audio were generated. Interaction locations reuse the existing lamps and benches. The UI/map are ordinary Godot controls and geometry-derived cartography. The existing park layout, supplied assets and lighting pass are preserved.

## Persistence and verification

- Player progress: `user://shinrai_extraction_v1.json` (Godot's project user-data folder).
- Saves use a temporary file followed by replacement. Invalid saves are preserved and deployment is disabled instead of overwriting them.
- Extraction settlement is idempotent. Carried loot is not written before extraction.
- Automated tests use a separate `shinrai_extraction_automated_test.json`, never the player's save.
- Run: `godot --headless --path . --script res://tests/test_extraction.gd`.
- For rendered HQ/HUD/map/result captures, omit `--headless` and append `-- --render`. Captures are saved in `user://extraction_qa/`.
- Existing park placement warnings, root-certificate access warnings in the sandbox, and resource-cleanup errors at shutdown predate this build. They are not a clean-debugger sign-off.

## Park perimeter, cover and wildlife (2026-10-31)

- `scripts/midori_park_fence.gd`: green mesh fence with four gates. By day all gates stand open and the fence is whole. At night the north, west and east gates are chained, the south main gate is smashed (one panel hangs from its top hinge, the other lies on the ground) and seven holes open along the sides. Night gates re-chain at every raid start.
- Bolt cutters (`bolt_cutters`) open a chained gate: hold E for 2.6 s. They drop from the maintenance and workshop loot tables and are not consumed.
- Prone: Z, or hold B on a controller. Capsule 0.72 m, speed 1.05 m/s. Only prone fits a fence hole; the fence gap is 0.80 m high.
- The playable area now reaches the pavement strip outside the fence (X 230.5, Z 190.5). That strip is plain ground, so nothing lives out there yet.
- `scripts/midori_park_cover.gd`: emergency cover on a 36 m hex lattice, alternating low and sight-blocking tall kinds, plus camps and dropped belongings. Everything is procedural and merged per 120 m cell, ready to swap for authored GLBs.
- `scripts/midori_park_wildlife.gd`: crows and pigeons that scatter from people, hostiles and gunfire; koi and dragonflies; fireflies and lamp moths at night. Only birds near the camera use CPU.

Reproduce: `godot --headless --path . --script res://tests/test_park_perimeter.gd`. Append `-- --render` and omit `--headless` for screenshots in `user://perimeter_qa/`.

### Test suite status (2026-10-31)

Boot takes about 75 to 115 s headless, so scene tests now allow 300 s. Movement input needs a captured mouse, which a headless run never has, so the route and bridge walks call `player._advance_ground_movement` directly. Run suites one at a time.

- Passing: `test_extraction`, `test_park_perimeter`, `test_extraction_routes` (all relays and a full extraction, with no detours), `test_bridge_walk`, `test_mantle_physics`, `test_survival_physics`, `test_salvage_choice`, `test_scav_combat`, `test_open_lawn_cover` (collision check only when headless).
- Security weapon cases are placed by `extraction_weapon_loot.gd` after navigation is built, so nothing in the navigation graph avoids them. Each case takes the nearest pocket between grid routes that is on flat open ground, off the paving, at least 3.5 m from any relay, 2.6 m from any other case and 0.5 m from every real route. `test_extraction` checks these limits.
- `test_drone_police` is unreliable. Across four runs it failed one of two different checks at random, with or without the fence, cover and wildlife. One run produced a search point 244 m behind the contact, which may be a real AI bug.
- `test_k17_integration`, `test_k17_combat_extract` and `test_k17_showcase_weapons` test a drone the raid no longer spawns. They need retiring or rewriting around the police drones, and `test_k17_integration` hangs until killed.
- `test_park_quality` and `test_open_lawn_cover` measure frame rate only in a window. In the cover view at 1080p, both presets average about 33 FPS by day and night, with or without the fence, cover and wildlife.

## Raid HUD and body status (2026-11-04)

- `scripts/extraction_hud.gd` is back to the committed HUD at `a09088f`, with its medical cross, heartbeat trace and condition lines. The user preferred it to the later minimal rework. That rework, uncommitted work from another session, was saved outside the repo before restoring.
- `scripts/hud/body_status.gd` adds a see-through body (Gray Zone / Tarkov style) above the vitals cluster, as an X-ray.
  - The player model is rendered front-on in a small transparent viewport, standing in its rest pose with the arms lowered. Its skin shows only a glowing outline, tinted per part through its skin binds.
  - A skeleton built on the rig's own joints sits inside: skull and jaw, spine, rib hoops, collarbones, pelvis, and limb bones with joint balls. Each bone takes its part's colour; bleeding parts pulse red.
  - A fractured limb's long bone (humerus or femur) snaps: the two halves part, the lower half sits out of line and twitches, and the break throbs orange.
  - The medical model is unchanged. The rows below describe the parts and tints, which still apply.
  - Each part shades from pale glass through amber to red as it loses HP. A destroyed part goes dark with a red cross.
  - Bleeding parts pulse red with one or two drops. Fractured limbs show a broken bone. A part that just took damage flashes.
  - It rests faint, comes forward when injured, and shows per-part HP while checking vitals (inspect / V).
- `test_extraction` passes 119/0 with the restored HUD.

## Tokyo roads, alleys and wind (2026-11-02)

- `scripts/midori_tokyo_roads.gd` lays real road geometry 2 cm over the near city's flat ground plane, two blocks out from the park: the ring road, four-lane arterials every 256 m and two-lane roads between. It does not edit `midori_near_city.gd`. Roads further out keep the ground plane's look.
- `scripts/midori_tokyo_road.gdshader` draws the asphalt: two rotated scales of the supplied aggregate, resurfacing runs with straight joints, tyre tracks, oil drips, sealed cracks, utility trenches, concrete gutters with grates, and Japanese markings (left-hand traffic, yellow no-lane-change lines before junctions, zebras, stop lines, lane arrows, crossing diamonds, blue cycle chevrons). Street-light pools on the road after dark follow the near city's lamp spacing.
- The same module adds 止まれ on minor-road approaches (Windows Japanese system font), 117 manhole lids from the supplied lid texture, 54 signalised junctions with working Japanese vehicle and pedestrian signals (GPU-timed 60 s cycle), and a paved verge with a kerb where a strip of sea showed between the park and the ring road.
- Once the raid reaches HQ, it moves the main south street, its back lane and the corporate roads onto the same asphalt (asphalt only; their own paint and kerbs stay). The main street still has its own centre dashes and crossing.
- `scripts/midori_alley_life.gd` dresses the gaps the near city leaves between lots, within 150 m of the park: about 950 alleys. Street mouths get vending machines, bicycles, crates, bins and nobori flags in shopping blocks, and pots, towels on drying poles and cables in residential ones. Walls get meters, AC units with pipe runs and downpipes; about 1,200 wall lamps light at night (see the lamp bullet below). `midori_near_city.gd` gained one read-only list, `alleys`, filled where `_split` already cut its gaps.
- `scripts/midori_wind.gdshaderinc` is one shared breeze field that gusts travel through. Cloth, leaves, nets and cables use it, at about half strength at night. `scripts/midori_wind_debris.gd` blows a few leaves past the camera (GPU particles, fewer at night).
- Stardust Lane (`midori_near_city_lane.gd`) was reworked in place. Its floor uses the road shader, its noren, lanterns, pendants, cables and maple sway (a wind-patched copy of the shared building shader, built at runtime so `midori_near_city_bespoke.gdshader` stays untouched), and its stalls gained real bottle shelves over lit fridges, kitchen benches by trade (ramen stockpot, oden pan), corner TVs, counter food and drink, plank-fronted counters and ceiling joists. Stools, beer crates, vending machines and bicycles were rebuilt in more detail. The yakitori stall has a charcoal grill with drifting smoke, the ramen stall steam, the closed shop a dying fluorescent tube, the last house a laundry pole, and a cat sleeps on a bin. New detail uses its own random stream, so the original layout is unchanged.
- Alley lamps (2026-11-02 rework). The old glowing cube was replaced with three real fittings:
  - The ward's LED 防犯灯: an ivory shell on a bent steel arm with a frosted lens, a dusk switch, its feed cable clipped down the wall and a number plate below.
  - A green enamel shade on a swan neck with the bulb showing (commercial alleys).
  - A caged bulkhead over back doors.
  - Lens, bulb and glass glow brightest at their centre, and only after dark. The shared props shader now gives night lamps frosted roughness instead of a mirror.
  - Housings are built into separate `AlleyLamps_*` meshes on render layer 14 (`1 << 13`). The lamps' own lights skip that layer, so a housing is not washed white by its own bulb.
  - Twelve pooled OmniLights (attenuation 1.1, 6.5 to 9 m reach) follow the camera to the nearest lamps after dark, each with five GPU-particle moths.
  - The lane's pendants, battens and snack-bar lamp were rebuilt the same way, and each pendant got its own light.
- Clipped shrubs (2026-11-03). Every low shrub and hedge round the south-street homes used to be the EZTree Bush006 conifer spray: about 2,400 spiky alpha-cut cards.
  - `scripts/midori_clipped_shrubs.gd` hides them and stands about 3,400 clipped Japanese mounds (satsuki and kurume azalea, boxwood, holly) in their footprints, with species grouped by bed. It runs from `midori_south_street.gd` just before batching.
  - Each mound is a lumpy core and two leaf shells (`shaders/midori_clipped_shrub.gdshader`, world-space 3 cm leaves, a little autumn bronze). They are tiled in 24 m multimesh cells; the shells drop out at 40 and 70 m and only the core casts shadows.
  - Day frame rate around the homes rose from 61–69 to 84–98 FPS in the same views. Alpha overdraw was the cost, not triangles.
- Lake reflection (2026-11-03). The live planar reflection in `midori_lake_life.gd` redraws the whole world, about 8 of a lake view's 25 ms.
  - It now renders every other frame, keeping the image and matrices from its last render on the off frame.
  - It also renders only when one of the water's own triangles is in view. The lake's box covers most of the park, so the old box test kept it on while facing away from the water.
  - Day, Balanced, 1080p: a park view with no water in shot went from 41 to 59 FPS, the ring road north from 61 to 70, and facing the lake runs at 54.
  - Remaining big costs inside the park are the near-city skyline (about 5.6 ms) and sun shadows (about 4.6 ms). Rendering at half resolution saves only about 3 ms, so the limit is geometry, not pixels.
- Park cleanup (2026-11-03):
  - **Zigzag in the sky.** The corporate tower's stair handrails (`staircases.gd`) and guard rails (`traversal.gd`) were placed with `look_at_from_position`, which reads world points, using tower-local points. So they hung about 19 m over the park centre, and the guard rails carried collision there. They now set their local transform.
  - **Bush006 in the park.** The park's own conifer-spray bushes (about 1,300 copies in `MidoriDistanceDetail`) also get clipped shrubs, applied from `midori_distance_boot.gd` after the cells are built.
  - **Cover props rebuilt in `midori_park_cover.gd`:**
    - Cable drums: plank flanges, hub, bolts, wound cable, trailing tail.
    - Site generator, which replaces the flat orange box.
    - Ribbed site toilet cabins with a dome roof, door latch and vent stack.
    - Caged IBC water totes.
    - Folded, sagging tarps on the draped barriers.
  - Prism shading now comes from a position hash rather than the placement RNG, so adding prop detail no longer moves the cover layout. That change moved it once.
  - No repeating line detailing: the user rejected striped tarp folds, cabin ribs, flange seams, slat louvres and the cover shader's vertical rain streaks. Tarps are now smooth sheets (`_sheet`: one sag, one billow).
  - The last Bush006 shrubs (plaza and park azalea bases, built after the earlier passes) are swapped by `ClippedShrubs.apply_after_boot`, a world-wide sweep once the raid leaves BOOT. Their red flower sprigs now sit on the mounds.
- Secondary park walks (2026-11-03). PlaygroundWoodlandLoop, NorthWoodlandLoop, PlazaToSouthBridgeLanding, PavilionGardenLink and EastPromenadeToViewingDeck changed in three ways:
  - **Shape.** They follow one flowing curve (`_smooth_walk`, Chaikin, in `midori_park_size_blockout.gd`) instead of straight runs with small rounded corners.
  - **Height.** They sit at 3.5 cm, nearly flush, instead of 11 cm.
  - **Surface.** `WalkMaterials.build_secondary` is weathered masado gravel, with no slab joints or wayfinding dashes. Its rim darkens into soil and breaks unevenly into the lawn.
  - The main walks and the lake promenade are unchanged.
  - **Terrain-painted walks (DayZ-style), now the visible look.** `scripts/midori_worn_paths.gd` paints these walks and the woodland trails into the ground itself. It runs from `midori_distance_boot.gd` once the raid leaves BOOT.
    - It rasterises their centre lines into a 4 px/m path map and injects a block into the shared ground shader. There the ground swaps its own turf scan for its own soil scan, with a noise-ragged edge, surviving grass tufts, a darker loose rim, a paler packed centre and damp hollows.
    - The old walk and trail meshes keep collision and their metadata but render on no layer (`layers = 0`).
  - **Main walks (2026-11-04).** All the blue LEDs are gone:
    - The walk shader's teal dashes.
    - The cyan inlays and their emission on the supplied path modules.
    - The blue slit streak projections. The slit spotlights are now warm and dimmer.
    - The paving shader has no joints or seams. It uses two rotated stone reads to break tiling, a paler trodden middle, soil and moss toward the rim, damp stains and soft leaf flecks.
    - The paving's rim now frays: noise discards up to 26 cm of the outer edge, letting the terrain's worn shoulder show through. Grime deepens toward the broken edge. The paving is toned down to a warmer, dirtier grey that matches the land's value.
    - `midori_worn_paths.gd` also paints a ragged worn shoulder about 0.5 m out along every main walk.
    - Woodland trails in the worn map now use the smoothed route, not the grid steps. The soil scan is read twice at different angles to hide its repeat.
  - **Second pass.** The gravel is a mid warm grey-brown instead of pale sand. Detail is photo-based grit at three scales, plus damp patches, scattered stones and leaf litter thicker at the rim, with no line patterns.
  - Open ends flare to 1.7× width over their last 5 m. They also run 1.2 m on under the walk they join, so the joint is a worn mouth, not a square butt.
  - The worn-earth woodland trails (`midori_trail_surface.gd`) also changed. The grid stair-steps are simplified and smoothed. The surface is now trodden forest floor with a patchy grass edge instead of a mineral strip.
- Cost, measured in a window at 1080p: boot to HQ was about 3 to 11 s slower than without these modules, within run-to-run noise. Frame rate was unchanged in two of three views; the ring road view dropped from about 62 to 59 FPS.

## Current GitHub handoff (2026-09-24)

### Open lawn and ground vegetation pass

The park now scatters 22,000 slightly broader short clumps from the supplied ground vegetation asset, brightens the existing lawn material, and plants fuller canopies and understory on the lake islands. Nine additional clusters of the supplied mossy-boulder model provide cover in clearings. Each cluster has mesh-matched collision; placement searches for positions clear of paths, other trees and other cover. No minivan or new art was created; the user has been asked for a maintenance minivan GLB to place later. High and Balanced use 110 m directional shadow distance after a fixed-view comparison showed similar near shadows and better frame time than 150 m.

Rendered 1920 x 1080 daylight samples after this pass: High mean 53.7/min 50 FPS, Balanced mean 56.3/min 52 FPS (six samples each). Night samples: High mean 52.2/min 46 FPS, Balanced mean 58.0/min 56 FPS. A fixed open-cover collision ray found the matching body. The extraction test still reports `EXTRACTION_TEST_RESULT: 0 failures`. These are sampled views without active enemies, not a whole-map or combat performance guarantee. The aerial review still shows broad open lawns; the next visual pass should use existing low vegetation and safe cover placement without filling the sports and playground zones reserved for final art.

### Multi-view graphics check

A subsequent four-view 1080p sweep found that the original High startup preset ran around 40–44 FPS in the dense west grove and south lawn despite faster lake/plaza views. Balanced is now the startup preset; F7 still selects High. Balanced keeps nearby directional tree shadows with two shadow splits and a 90 m reach, and omits SSAO and SSR. Paired captures at the grove and rock cover showed little visible change from removing SSAO or using two shadow splits. The final default-preset sweep on the user's Performance power mode measured: daylight west grove mean 51.9/min 51, open rock cover 60/60, south lawn 51.1/min 47, lake edge 60/60 FPS; night west grove 52.6/min 52 and open cover 60/60 FPS. These sampled views meet the 45–60 FPS target, but future vegetation or enemies may lower the readings. Keep profiling as art is added.

Reproduce with `godot --path . --script res://tests/test_park_view_sweep.gd`; it uses a separate QA profile, prints `VIEW_SWEEP` results, and saves captures under `user://extraction_qa/`. The extraction regression still reports `EXTRACTION_TEST_RESULT: 0 failures` after the preset change.

The live Godot project uses `scenes/shinrai_extraction.tscn` as its main scene. The current Midori Park pass has one asymmetric lake shoreline shared by rendering, navigation and grass exclusion, seven islands, three walkable existing-asset timber bridges, denser authored tree groves, relocated trees kept clear of reserved routes, and existing-asset rock cover. Day/night lighting retains directional foliage shadows, SSAO, SSR on High and FSR scaling. Entrance pads use a stone tone, and path light streaks illuminate only at night. The existing ground material has a greener tint. The city and elevated roads outside the park are intentionally deferred; pavilion, playground, court and fountain art are also deferred until the user supplies them.

Automated extraction and render checks report `EXTRACTION_TEST_RESULT: 0 failures`. A scripted bridge-walking test physically crossed the main bridge. An earlier, narrower dense-cover sample averaged 54.5 FPS on High and 59.5 FPS on Balanced with SSAO enabled; use the newer multi-view results above for the current performance assessment. All samples omit active enemies and are not a whole-game FPS guarantee. Earlier Eco-mode readings were lower and are not the current performance baseline. The map has not yet been manually traversed end to end from insertion through all relays to extraction.

The pale arched bridges in the artwork need a user-supplied GLB; the user has been asked for one after this park pass. The supplied K17 mesh is now integrated; see the K17 checkpoint below for its current art and combat limits. Three deadwood stumps, two logs and one micro-grove tree remain skipped because their authored positions intersect reserved routes; those skipped objects do not create collision. The park still has broad open areas compared with the artwork.

## Route and cover checkpoint details

Checkpoint saved on user stop: route and cover pass applied to the live game.

- Nine instances of the supplied mossy-boulder asset provide approach cover; three candidate placements were rejected for clearance. Mesh-matched collision is shared between instances. No new art was generated.
- Guidance prefers existing paths, shows approximate walking distance, and draws the suggested route on the field map. Click a relay, salvage site or extraction gate on the map to select it; T returns to automatic relay/extraction guidance.
- The map includes the additional park routes, cover points and torii landmark. Deployment faces the first route segment.
- Automated gameplay, collision-ray and map-selection tests pass. Ground-level cover and the route-map layout were rendered and inspected. Editor F5/debugger review and full manual traversal remain pending.
- The actual-player walking test is now `tests/test_extraction_routes.gd`. It clears active patrols so it measures route connectivity and relay interaction; K17 combat is covered separately.

### Traversal follow-up

The actual-player route test exposed a blocked connection through the east relay lamp and a route endpoint outside the south relay's interaction range. Navigation now checks the connections between cells with a player-sized collision sweep, retains the existing bridges and path preference, and chooses the closest clear neighboring cell instead of the first one in scan order. No scenery, assets or graphics settings were changed in this follow-up.

A continuous headless run walked insertion → south relay → north relay → east relay → south extraction, held E at all three relays, and completed extraction. The isolated QA save recorded one extraction and 750 contract credits. This is automated controller traversal at a normal 1/60-second simulation step with accelerated wall time, not a manual editor playtest. The regression suite passed all 71 checks, including every interaction endpoint being in range. Existing shutdown resource warnings remain.

Reproduce: `godot --headless --path . --script res://tests/test_extraction_routes.gd`.

Post-fix isolated 1080p Balanced sweep (seven FPS samples per view): daylight west grove mean 51.3/min 51, open cover 60/60, south lawn 53.4/53, lake edge 60/60; night west grove 51.3/51 and open cover 60/60. No concurrent test instance was running during the sweep. These are sampled stationary recon views, not frame-time percentiles or a combat guarantee; stable 60 FPS across the map is still not achieved.

Immediate next step: profile and optimize the dense grove/lawn views toward a stable 60 FPS without sacrificing nearby foliage and shadows. Then test alternate routes and both extraction gates; the full-run check covers the main relay circuit, not every possible walkable segment or active combat.

Latest stop checkpoint: performance inspection resumed, but no new runtime or graphics changes were applied. A diagnostic script was saved outside the game at `C:/Users/hp/Documents/Codex/2026-09-18/ok-x20/work/profile_park_cost.gd`. Its first launch stopped on an indentation parse error before measurements; it is unfinished, not a verified benchmark. Next: fix that diagnostic, compare ground-clump cost, mesh LOD and shadows in fixed grove/lawn views, then apply only measured, visually checked improvements. The last verified live gameplay checkpoint remains intact.

### Balanced graphics follow-up

The diagnostic was fixed and run on the RTX 5050 Laptop GPU at a 1920×1080 output. The grove baseline cost 19.52 ms/frame and 8.82 million primitives; the lawn cost 18.80 ms/frame and 11.92 million. The main measured cost was distant imported tree geometry. Setting the viewport mesh LOD threshold to 4 in Balanced mode roughly halved rendered primitives and brought both fixed views to the 60 FPS cap in an isolated comparison. High mode retains threshold 1.

Balanced also now renders 3D at 0.75 scale (formerly 0.70) while fading the existing 22,000 ground-clump instances by chunk past 80 m over a 15 m margin. Near scatter, tree placements and shadow settings were kept. The final six-view 1080p sweep reported mean/min 60/60 FPS in daylight grove, open cover, south lawn and lake edge, and night grove and open cover. A player-controlled crossing of the installed bridge passed with mean 59.9/min 59 FPS over nine moving samples; the separate open-cover sample was 60/60. Seven lawn-transition captures showed no obvious missing patch as the distant clumps faded. All 71 extraction regression checks still pass.

These tests are sampled recon gameplay on the current laptop, without K17 combat or a manual editor/debugger sign-off. Keep the frame-time margin under review when enemies, audio and additional art are added. The diagnostics and screenshots are in the Codex review workspace, outside the game assets.

1. Complete K17 materials, animation and readable attack cues when the user supplies those assets, then playtest combat pacing.
2. Improve the park's encounter spaces and landmark visibility using existing high-quality assets. Validate at ground level, not just from the aerial artwork.
3. Add user-supplied search-container / maintenance-terminal assets and authored audio (UZI, impacts, footsteps, park ambience, extraction radio). Do not generate replacements without asking.
4. Expand the contract set and loot decisions after this first loop has been playtested. Profile real combat at 1080p/60 FPS; recon performance alone is not a combat guarantee.

Stop protocol: save the current work, apply the latest working verified state to the live project, and report completed work plus the next planned step. Keep unfinished experiments separate.

## K17 enemy checkpoint (2026-09-29)

The user supplied `K-17.bin`, which is a Blender 4.04 project containing one detailed static drone mesh. The runtime model at `assets/enemies/k17/K17_Drone_Static.glb` is a 400,000-face optimized export of that supplied mesh. It is upright at about 1.9 m tall with a grounded pivot, a neutral graphite PBR material, and Godot-generated mesh LODs. The source has no textures, UVs, color attributes, rig or animation, so this is a functional first art pass rather than a fully authored combat model.

The live extraction run loads that model and spawns six K17 patrols, two near each relay. Lightweight body, weapon-arm and upper-fin hitboxes make the visible drone hittable without render-mesh physics. The K17 patrol route skips a nearby first cell when the path refreshes, avoiding an observed back-and-forth loop. A live headless probe confirmed patrol movement, player detection and damage. `tests/test_k17_integration.gd` checks model scale, six spawns, patrol movement, hitboxes, UZI damage and a recorded kill; the core extraction test also passes. Ground-level renders were inspected for silhouette and shadows. The model is dark when backlit, so the eventual authored material and attack-cue pass remains useful. Manual editor playtesting and combat frame-time profiling remain pending.
