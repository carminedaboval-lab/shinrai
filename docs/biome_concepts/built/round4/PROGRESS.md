# Midori Park · round 4

Each sheet uses the archived before view, a native 1920 × 1080 game capture and the corresponding concept. The maple floor camera has no archived before or concept. Its sheet shows the paired biomes-off control and labels the missing reference.

## Crash isolation

Both archived Windows dumps show a read of address `0x168` in `nvoglv64.dll+0xeaaf01`. The latest capture failed during football-training asset loading in `_register_sites`, before the biome installer ran. An earlier coppice-and-iris-only capture lost the Vulkan device at the same driver address. Both time windows overlap a second full Godot render. This identifies a common trigger worth preventing. The dumps do not identify a defective biome asset.

Four sequential `MIDORI_BIOMES_ONLY` runs on the RTX 5050 Laptop GPU each reported exactly its selected builder, saved its screenshots and exited successfully. Shrine produced 1 capture, maple 5, meadow 3 and pine 4. None reproduced the access violation or Vulkan device loss. The existing renderer cleanup warnings still appeared at exit.

Use `tools/render_midori_biomes.ps1` for captures. It acquires a cross-process lock, checks for a Godot process already using the GPU and verifies the requested PNGs, timings and completion markers. The QA runs used a separate project identity and save profile. The original failure was not deliberately retriggered with simultaneous renders. To repeat the timing comparison, run `tools/render_midori_biomes.ps1 -Paired -Views north_coppice,north_coppice_deep,north_coppice_west -OutputDirectory <fresh-directory>`. The launcher verifies both the OFF and ON screenshots.

## North coppice

[Same-camera sheet](north_coppice_sheet.png). The exposed lawn now reads as decaying oak litter, with periwinkle, fern drifts, multi-stem oak thickets and bark-textured fallen trunks. The junction stays clear. The fern patches are more uniform and the main view has less dappled light than the concept. The sheet shows the actual game lighting.

Final same-boot change with all biomes enabled was main -1.04 ms (38.7 FPS), deep +0.23 ms (41.9 FPS), west +5.66 ms (20.9 FPS). Each camera clears the approximate +6 ms target. The ground and bark textures, cheaper distant ferns and a ground shader that skips covered layers support the denser planting.

## Iris shore

[Same-camera sheet](iris_shore_sheet.png). The east bank and inlet show violet iris stands, low sedges and damp stones on real soil. The installer dropped 171 isolated reed roots. The nine surviving wet roots belong to bank-attached stands. The bright feature in the east and inlet views is the existing sun reflection on the water. The mud still shows between the flower groups. In the main view the nearest ground is a paved walk, with the new violet bed beyond it. The north camera is over water and the nearest visible bank is about 14 m away, so the flowers appear across the pond. Those two views are partial concept matches. The north view clears the approximately +5 ms target.

Final same-boot change with all biomes enabled was main +1.74 ms (36.1 FPS), east +5.89 ms (29.5 FPS), north +1.60 ms (38.0 FPS), inlet +6.87 ms (29.6 FPS).

## Shrine approach

[Same-camera sheet](shrine_approach_sheet.png). A 7.02 m vermilion torii replaces the central plaza monument at (164, 136). The granite walk, four pairs of Kasuga lanterns and planted azalea shoulders lead to its 4.87 m opening. The reverse view retains the working civic plaza and frames the gate with two planted beds. The azaleas are more tightly clipped than in the artwork and the forward gate reads dark red against the skyline.

A normal raid boot verified 41 m of clear passage for a 0.42 m-radius capsule, in both directions, with 42 floor probes. The AI routes through the opening both ways. Moving the rest bay to (177.5, 114.7) kept both seats, their collision, all 38 plants and the existing bench loot location attached to the bench. Its furniture is placed before navigation and is present in the all-biomes-off control. This change updates the Creator layout fingerprint. Old saved arrangements use the existing review check.

The old model, pillar bodies and local neon were removed. The normal day/night switch passed the independent checks. [Night approach](night/shrine_approach.png) and [night reverse](night/shrine_approach_reverse.png).

Final same-boot change with all biomes enabled was main -1.83 ms (38.8 FPS), reverse +0.88 ms (40.8 FPS).

## Maple glen

[Same-camera sheet](maple_glen_sheet.png). Two newly built low-forking Japanese maple forms use palmate leaves and a leaf-spray atlas. The 23 trees include four russet crowns. The pavilion roof and posts are visible from the pond, and the orange shore boulder and its collider have gone. The west view still shows the existing pink tree, and the east view retains the working relief-yard containers. The fallen-leaf carpet is heavier than the concept at the fork.

Same-boot frame-time change with all biomes enabled, relative to all biomes disabled, was main +1.26 ms (49.8 FPS), east +7.54 ms (35.8 FPS), floor +1.68 ms (61.0 FPS), pavilion +2.81 ms (62.5 FPS), west +1.25 ms (44.1 FPS).

## Meadow

[Same-camera sheet](meadow_sheet.png). The new cutout susuki heads take directional light and a small amount of reflected light from the field. Across all three cameras, the sunlit plumes read as pale straw and the shaded ones as taupe. In the full-resolution main view, a sunlit head at (91, 686) measured RGB (167, 153, 131), and a shaded head at (461, 588) measured (86, 82, 71). The forked heads are stiffer and more repetitive than the artwork. More soil shows between the large grass clumps.

Same-boot frame-time change with all biomes enabled, relative to all biomes disabled, was main +1.77 ms (39.5 FPS), north +2.76 ms (44.4 FPS), west +6.11 ms (24.4 FPS).

## Pine woods

[Same-camera sheet](pine_woods_sheet.png). The bright detached V-shaped tufts near the cameras came from the pine builder planting five oversized iris fans per root. The final scene has 25 muted fans in seven compact flowering clumps, down from 220 fans. All four cameras retain the open needle floor, court, paths and clubhouse. The ground is barer than in the concept, particularly around the east stand.

Same-boot frame-time change with all biomes enabled, relative to all biomes disabled, was main -2.41 ms (55.8 FPS), court -1.42 ms (49.4 FPS), east stand -0.13 ms (31.1 FPS), reverse +1.32 ms (23.0 FPS).

## Final integration check

The final run averaged 42.8 FPS with all eight builders off and 39.8 FPS with them on across the same 21 cameras. These are arithmetic means of per-camera steady FPS. The runner used the same HQ instance, camera transforms, resolution, 70-frame settle and three 40-frame timing windows. The handoff gives numeric budgets for the three coppice views and iris north. [Per-camera samples](timings.json) include the full OFF and ON measurements and a separate area-root-hidden check.

## Fukumaru apartments — 6 November 2026

Installed two furnished middle-floor studios (201/202), a larger top-floor flat (301) with separate bedroom, and the east-alley stair from the pavement. All three doors use the normal interaction. The installed live-player route passed all 48 checkpoints and 2,342 grounded samples, including both flights, all three flats and the return to the pavement. [Before | now | concept sheets, per-flat review, photographs and evidence](fukumaru_apartments_2026-11-06/PROGRESS.md). Fittings, cloth, wood and household details are improved; lighting and material detail remain simpler than the concepts. Indicative tile-render changes were +0.63 / +0.96 / +0.68 ms for 201/202/301; shared-GPU contention prevents treating these as full-raid FPS results. Final visual acceptance remains with the user. Nothing committed.

## Fukumaru apartment surfaces — 6 November 2026

Installed the second interior pass on the same building: sealed walnut furniture, separate upholstery and linen, thinner bedding and seams, formed steel sinks with hollow cabinet carcasses, curved taps, beveled joinery, plant leaves, ceramic/enamel bathroom finishes, bounded room reflections and room-limited shadows. Fixed the unsupported gap below each kitchen worktop. Seven reviewed source/UID files replaced or added, with all 17 hashes verified and backups retained. [Before | now | concept sheets, full room views, closeups, night views and measured evidence](fukumaru_surfaces_2026-11-06/PROGRESS.md).

The installed live-player route passed 48 checkpoints and 2,342 grounded samples, including both flights, all three doors, every bathroom threshold and the upstairs bedroom. Fixed-camera GPU medians in the isolated tile were 201 5.47→6.06 ms, 202 6.80→6.77 ms and 301 living 6.65→5.87 ms; variable raw samples prevent interpreting small decreases as an FPS gain. The bathroom rose by 1.31 ms. Shop ArrayMesh geometry increased 51,236→85,288 triangles, with one or two extra visible draws. The cloth, incidental wear and bathroom shapes remain simpler than the concepts. Final visual acceptance stays with the user; nothing committed.

