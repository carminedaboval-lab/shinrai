# Apartment surface pass 2 — staged visual QA

The final reviewed package is `captures/surface_final2` (seven day cameras), `captures/surface_final2_close` (three detail cameras), and `captures/surface_final2_night` (the three principal room cameras). Every image is a native 1600×900 Vulkan capture on the RTX 5050. All use the actual streamed near-city tile with both neighbouring shops and the archived fixed review sky, sun and exposure. This is a near-city preview, not a full raid performance benchmark.

The before | now | concept sheets are `captures/surface_final2/comparison/201_front_studio.jpg`, `202_rear_studio.jpg`, and `301_living_kitchen.jpg`. Before is the previously installed concept implementation (`captures/final`). The new timing control's seven PNGs are byte-identical to `surface_before`, which itself matches that installed before version. Cameras, FOV, resolution and environment were preserved. Generated concepts have small perspective differences and remain targets rather than rendered evidence.

The deeper pass visibly improves rounded furniture edges, actual hollow sinks and curved taps, contrasting steel/hob surfaces, sealed dark timber, textile colour, cloth hems and curved foliage. Cabinet sides and a support rail now meet the counter instead of leaving an unsupported black slot. The final room lighting removes the earlier horizontal shadow-acne bands and cool upper-wall strip. Day and night retain blue/teal cloth, neutral cabinetry and readable rooms. The bath is readable but rather uniformly lit. Fine shadow/SSAO dithering remains visible on pale walls at full resolution. Walls, cupboard faces and some fabric folds still look more regular and less naturally varied than the photographic concepts; the result should not be described as matching their realism.

All final day, close and night runs completed without script or shader errors. All used new private Windows desktops that were never switched to and isolated APPDATA/LOCALAPPDATA/TEMP/TMP. Native process snapshots every 200 ms found no other Godot process during these runs. A first launch attempt had yielded before fixture writes when another short Godot process was detected. The fixture's existing seven Texture RID shutdown leaks remain; completed captures and manifests were saved before shutdown.

Final sources are frozen in each run's `source_hashes.json`; `verified_candidate_sources.json` also covers all 17 candidate source/UID files. Root installed the reviewed sources. The exact live checkout then passed the standing-player route: 48 checkpoints, 2,342 samples, all grounded, including public pavement crossing, both stair flights, actual three-door interaction, each wet-room threshold, bedroom and return to pavement. All 17 installed source/UID hashes matched the installation receipt before and after this test. Evidence is `walks/surface_installed/walk.json`, `code_hashes.json` and `verified_installed_sources.json`. The adapter uses shipped movement/capsule and the raid floor/boundary functions while omitting profile/HQ/HUD setup. It runs headlessly with private user directories and does not replace the user's playtest.

Timing uses 70 settling frames, then three 40-frame trials at each fixed camera. The manifest retains all 120 CPU and GPU timestamp samples per view, all trial means, and the median trial mean, alongside the original wall-clock intervals. Viewport CPU time excludes unrelated gameplay logic. GPU timings may lag several frames, all within the unchanged view. The control restored and verified all 15 archived installed source/UID files, then rendered consecutively with `surface_final`; `surface_final2` reran the tiny cabinet support correction under the same instrumentation and process guard. Thus the final2 table uses the earlier fresh control, not an immediately adjacent second control.

| Fixed view | Before GPU ms | Final GPU ms | Before → final draws |
|---|---:|---:|---:|
| North street | 7.38 | 7.45 | 447 → 449 |
| Stair approach | 7.09 | 6.58 | 352 → 354 |
| 201 front studio | 5.47 | 6.06 | 141 → 142 |
| 202 rear studio | 6.80 | 6.77 | 66 → 68 |
| 301 living/kitchen | 6.65 | 5.87 | 190 → 192 |
| 301 bedroom | 6.63 | 7.29 | 331 → 333 |
| 301 bathroom | 5.46 | 6.77 | 308 → 310 |

Timing variation within the three trials is substantial and many ranges overlap, so small lower medians do not establish an optimisation. The report supports roughly similar isolated-tile rendering cost with selected final medians up to about 1.3 ms higher. It does not establish full-raid FPS or eliminate GPU-clock and background-application variation. Full data is in `captures/surface_final2/cost_comparison.json` and the two capture manifests.

Total shop ArrayMesh base triangles increased from 51,236 to 85,288; mesh count from 105 to 107 and ArrayMesh surface count from 33 to 35. This metric excludes non-ArrayMesh primitives. Street and stair cameras have no active room shadow lamp; each interior camera has one, with shadow caster mask 64. This prevents the room lights from casting unrelated city geometry into their shadow maps.
