# Fukumaru surfaces and furnishings — 6 November 2026

This is the second interior pass on the same building: studios 201 and 202, and the larger 301 flat. The previous installed rooms are retained as Before. The three generated room concepts remain the visual target; the user has final visual approval.

The kitchens now have hollow visual cabinet carcasses around genuinely recessed sinks, formed stainless rims, drains, curved taps and handles. The collision blocks retain their original dimensions. Beveled furniture edges, table aprons, chair stretchers, shelf brackets, rounded vessels and thin curved plant leaves replace the coarse first-pass shapes. Existing project walnut veneer replaces the rough furniture wood. Upholstery and linen have different filtered weaves; thinner duvet profiles, sewn edges and the sofa throw give cloth clearer construction. The color correction restores the intended grey upholstery, blue bedding and green leaves.

Floors use narrower boards and subtle staggered end joints. Interior metal reflects bounded room captures. Ceiling lights illuminate the whole room, while live shadows are limited to the current room and apartment geometry. The enclosed bathrooms now use their own existing fixture positions for illumination and interior enamel/ceramic materials. Four reflection probes refresh once on creation or an actual day/night change. The shadow selection checks the camera five times per second and admits both adjoining rooms at the upper bedroom doorway.

## Visual review

- **201:** The futon reads as a thin cover rather than an inflated cushion; sink depth, taps, cabinet edges and curtain color are clearer. The concept still has more irregular cloth folds and softer natural window light.
- **202:** Cabinet joinery, the desk finish and bed edge are more convincing. The concept's stronger daylight and more varied fabric wear remain ahead of the built room.
- **301:** Grey upholstery, finished timber, formed kitchen fittings and real contact shadows move the room closer to the concept. Some small props and bathroom shapes remain simple. This is an improvement pass, not a claim of photoreal equivalence or user acceptance.

[201 comparison](comparison/201_front_studio.jpg) · [202 comparison](comparison/202_rear_studio.jpg) · [301 comparison](comparison/301_living_kitchen.jpg). Full views are in `now`, closeups in `details`, and matching night checks in `night`.

## Verification

Seven reviewed source/UID files were installed into the live checkout; all 17 tracked apartment/dependency hashes matched before and after the live validation. The exact installed build passed the standing-player route: 48 checkpoints, 2,342/2,342 grounded samples, all three normal E-interaction doors, both stair flights, every bathroom threshold, the upstairs bedroom, and the return to the pavement. It travelled 74.54 m, with a maximum single-frame rise of 0.0371 m. This is an automated movement check, not the user's playtest.

The capture harness uses an isolated near-city tile with the actual neighbouring buildings, fixed 1600×900 cameras and the archived environment. It runs on a private Windows desktop that is never displayed, with separate user-data paths. Native process checks every 200 ms yield to another Godot process. Measurements describe this fixture, not whole-raid FPS or user playtest approval.

The repeated baseline images were byte-identical to the earlier installed-room captures. Both the control and final captures recorded zero other Godot processes. Each view settles for 70 frames, then records three 40-frame intervals. These are medians of the three viewport GPU-time means:

| Same camera | Before GPU ms | Now GPU ms |
| --- | ---: | ---: |
| North street | 7.38 | 7.45 |
| Stairs | 7.09 | 6.58 |
| 201 | 5.47 | 6.06 |
| 202 | 6.80 | 6.77 |
| 301 living/kitchen | 6.65 | 5.87 |
| 301 bedroom | 6.63 | 7.29 |
| 301 bathroom | 5.46 | 6.77 |

The raw samples vary considerably, so the lower readings are not evidence of an FPS improvement. The selected medians show roughly similar fixture cost, with up to 1.31 ms extra in the bathroom. The shop's ArrayMesh geometry increased from 51,236 to 85,288 triangles, and visible draw counts increased by one or two. Final metadata confirms zero apartment shadow lights from the street/stair cameras, and one active room shadow light with caster mask 64 in every interior camera. CPU render medians were 0.53–1.25 ms. Full per-frame data, masks, source hashes and capture settings are in `evidence`.

The first lighting attempt was rejected during review: spotlight cone boundaries and shadow acne degraded the rooms. Those intermediate images are retained in the staging QA history and are not the published Now images. The final review uses the same room cameras as Before. Generated concepts have slight perspective differences.

All seven day views, three closeups and three night views completed without script or shader errors. The native renderer still reports the same seven Texture RID shutdown leaks seen in the baseline; screenshots and reports complete before shutdown. The live route ran without script/runtime failures. No production save data was used.

Godot's [light caster masks](https://docs.godotengine.org/en/stable/classes/class_light3d.html#class-light3d-property-shadow-caster-mask) keep unrelated city geometry out of the apartment shadow pass. [Viewport render measurements](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-measured-render-time-gpu) separate rendering work from the broader frame interval; GPU clock and other application workloads can still affect timings.

No commits. Final visual acceptance remains with the user.
