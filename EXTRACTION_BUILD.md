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

## Current GitHub handoff (2026-09-24)

### Open lawn and ground vegetation pass

The park now scatters 22,000 slightly broader short clumps from the supplied ground vegetation asset, brightens the existing lawn material, and plants fuller canopies and understory on the lake islands. Nine additional clusters of the supplied mossy-boulder model provide cover in clearings. Each cluster has mesh-matched collision; placement searches for positions clear of paths, other trees and other cover. No minivan or new art was created; the user has been asked for a maintenance minivan GLB to place later. High and Balanced use 110 m directional shadow distance after a fixed-view comparison showed similar near shadows and better frame time than 150 m.

Rendered 1920 x 1080 daylight samples after this pass: High mean 53.7/min 50 FPS, Balanced mean 56.3/min 52 FPS (six samples each). Night samples: High mean 52.2/min 46 FPS, Balanced mean 58.0/min 56 FPS. A fixed open-cover collision ray found the matching body. The extraction test still reports `EXTRACTION_TEST_RESULT: 0 failures`. These are sampled views without active enemies, not a whole-map or combat performance guarantee. The aerial review still shows broad open lawns; the next visual pass should use existing low vegetation and safe cover placement without filling the sports and playground zones reserved for final art.

### Multi-view graphics check

A subsequent four-view 1080p sweep found that the original High startup preset ran around 40–44 FPS in the dense west grove and south lawn despite faster lake/plaza views. Balanced is now the startup preset; F7 still selects High. Balanced keeps nearby directional tree shadows, uses a 90 m shadow reach, and omits SSAO and SSR. Side-by-side captures at the grove and rock cover showed little visible change from removing SSAO. The final default-preset sweep on the user's Performance power mode measured: daylight west grove mean 48.4/min 44, open rock cover 60/60, south lawn 50.6/50, lake edge 60/60 FPS; night west grove 50/50 and open cover 60/60 FPS. One grove sample remained 1 FPS below the 45 FPS target, and future vegetation or enemies may lower these readings. Keep profiling as art is added.

Reproduce with `godot --path . --script res://tests/test_park_view_sweep.gd`; it uses a separate QA profile, prints `VIEW_SWEEP` results, and saves captures under `user://extraction_qa/`. The extraction regression still reports `EXTRACTION_TEST_RESULT: 0 failures` after the preset change.

The live Godot project uses `scenes/shinrai_extraction.tscn` as its main scene. The current Midori Park pass has one asymmetric lake shoreline shared by rendering, navigation and grass exclusion, seven islands, three walkable existing-asset timber bridges, denser authored tree groves, relocated trees kept clear of reserved routes, and existing-asset rock cover. Day/night lighting retains directional foliage shadows, SSAO, SSR on High and FSR scaling. Entrance pads use a stone tone, and path light streaks illuminate only at night. The existing ground material has a greener tint. The city and elevated roads outside the park are intentionally deferred; pavilion, playground, court and fountain art are also deferred until the user supplies them.

Automated extraction and render checks report `EXTRACTION_TEST_RESULT: 0 failures`. A scripted bridge-walking test physically crossed the main bridge. An earlier, narrower dense-cover sample averaged 54.5 FPS on High and 59.5 FPS on Balanced with SSAO enabled; use the newer multi-view results above for the current performance assessment. All samples omit active enemies and are not a whole-game FPS guarantee. Earlier Eco-mode readings were lower and are not the current performance baseline. The map has not yet been manually traversed end to end from insertion through all relays to extraction.

The pale arched bridges in the artwork need a user-supplied GLB; the user has been asked for one after this park pass. The K17 enemy visual is also still pending, so no enemies spawn. Three deadwood stumps, two logs and one micro-grove tree remain skipped because their authored positions intersect reserved routes; those skipped objects do not create collision. The park still has broad open areas compared with the artwork.

## Route and cover checkpoint details

Checkpoint saved on user stop: route and cover pass applied to the live game.

- Nine instances of the supplied mossy-boulder asset provide approach cover; three candidate placements were rejected for clearance. Mesh-matched collision is shared between instances. No new art was generated.
- Guidance prefers existing paths, shows approximate walking distance, and draws the suggested route on the field map. Click a relay, salvage site or extraction gate on the map to select it; T returns to automatic relay/extraction guidance.
- The map includes the additional park routes, cover points and torii landmark. Deployment faces the first route segment.
- Automated gameplay, collision-ray and map-selection tests pass. Ground-level cover and the route-map layout were rendered and inspected. Editor F5/debugger review and full manual traversal remain pending.
- An unfinished automated walking test was moved out of the live project to the review workspace on stop; it is not part of this checkpoint.

Immediate next step: finish a real-player walk from insertion through the relays and extraction, correct any collision snags, and profile several gameplay views. Do not treat navigation-cell connectivity or one sampled view as proof of full traversal or stable 60 FPS.

1. Add the user-supplied K17 package, verify its scale, materials, collision and readable attack cues, then playtest patrols and combat pacing.
2. Improve the park's encounter spaces and landmark visibility using existing high-quality assets. Validate at ground level, not just from the aerial artwork.
3. Add user-supplied search-container / maintenance-terminal assets and authored audio (UZI, impacts, footsteps, park ambience, extraction radio). Do not generate replacements without asking.
4. Expand the contract set and loot decisions after this first loop has been playtested. Profile real combat at 1080p/60 FPS; recon performance alone is not a combat guarantee.

Stop protocol: save the current work, apply the latest working verified state to the live project, and report completed work plus the next planned step. Keep unfinished experiments separate.
