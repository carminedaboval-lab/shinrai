# Midori Park Biome Plan (merged)

## Verdict on the three candidates

| Plan | Kept | Dropped or changed |
|---|---|---|
| **1. Midori niwa** (garden types) | Green-maple momiji glen at spawn, pine woods, moss knoll, iris shore band, hanami lawn. Filterable "look" channels in the ground texture instead of biome ids. | Bamboo grove moved to an optional last phase, because it needs a new procedural asset (the biggest art risk). |
| **2. Seven Grounds** (tactical) | Quadrant logic. Dark North Coppice as the stealth route. Meadow with taller grass. Hash-based pine reskin ramp. 2 m/px bake. Global shader uniform. "Neutral equals today" baseline. | Red spring maples. They clash with blooming sakura, so they become mostly green with a few rust trees. |
| **3. After the evacuation** (story) | Tended shrine approach, the one kept place. Relief-yard idea at the pavilion. Allotment. Trails, yards and plots painted into the worn-path map. A "care" axis. | Burnt woodland next to spawn. It is risky as a first impression and reads as dead pixels, so it is parked as an optional event patch. Flood lobe over LakesideStoneBend dropped, because it conflicts with the moss garden. |

## Intro

Midori stays one coherent lapsed Tokyo park. Eight small themed grounds sit on that baseline. Each is based on a real Tokyo park type and tied to a landmark that is already there. Mostly they are told apart by three things:

1. **Tree species**: pine, green maple, sakura groves.
2. **Understory mix and grass height**.
3. **A muted ground tint baked into the existing shared ground shader**: warmth, care, moss and wetness.

All of the themes are kept in one new static script. Every existing producer swaps a threshold or table for a lookup into it, so no new RNG calls are added. Trees stay at net zero: species are swapped and sakura regrouped, not added. Tints stay muted olive. Paths stay painted into the ground. Edges never read as lines.

## Biomes at a glance

| # | Biome | Area (world m, -z is north) | Signature look | Key assets | Gameplay feel |
|---|---|---|---|---|---|
| 1 | **Momiji-dani** 紅葉谷 (green-maple glen) | Ellipse c(110,-148) r(70,30), so x 40..180, z -178..-118. Pavilion (152,-146), fence hole (118,-179.4) | Layered green maples under the belt, about 1 tree in 6 dull rust. Warm tan litter with fallen leaves. Fern. | free3d Japanese maple .res, leaf_00..02, midnight_fern | First contact from spawn (70,-201). Clumped trees, 30-50 m lanes, pavilion loot hub |
| 1a | └ Relief yard 避難所 (sub-patch) | Ellipse c(152,-146) r(34,22) | Trampled khaki yard painted into the ground, relief kit closer together, heavier litter | park_cover pieces, can/paper litter | Contested first fight, crate and tank cover |
| 2 | **Matsubayashi** 松林 (pine woods) | Union of c(-150,-62) r(64,52), c(-104,-140) r(38,32), and East stand c(185,40) r(26,29) | High pine crowns over a clean grey-brown needle floor. Clipped evergreen mounds by the clubhouse and court. Iris carpets kept. | pine_trees_pack, evergreen_shrub_v1, iris_japonica, stones | Longest under-canopy sightlines (60 m+), trunk peeking. Clubhouse hub. |
| 3 | **Zoki-bayashi** 雑木林 (north coppice) | Soft rect x -86..40, z -178..-50 | Darkest, most layered broadleaf. Fern, deadwood, periwinkle. | existing broadleaf, fern, tree_trunk_002/hollow_bark, groundcover | Short 10-25 m sightlines. Stealth route from the north gate to the north bridge. |
| 4 | **Koke-niwa** 苔庭 (moss stroll garden) | Ellipse c(-14,20) r(44,40), so x -58..30, z -20..60. Satellite c(24,-114) r18 | Moss carpet under canopy. Tamamono mounds in 3/5/7. Lanterns. A few green maples on the crest rim. | garden_spots, kasuga_lantern, moss_00..11, mossy boulder, azaleas | King of the hill over the main bridge (+1.85 m). Crouch cover. |
| 5 | **Mizube / Hanashobu** 水辺・花菖蒲 (iris shore) | Band 0..14 m inland of terrain.shoreline plus 7 islands. 20 m hero pockets at (52,56), (149,24), (64,-97), (124,-123) | Dark damp peat bank, reed clumps, Iris japonica drifts, lily rafts, moss on stones | procedural reeds (MPSB:1458), iris, fountain grass (sage), island moss | Exposed edge, prone concealment in reeds. Bridge chokepoints. |
| 6 | **Hanami-hiroba** 花見広場 (sakura lawn) | Ellipse c(20,138) r(96,40), so x -76..116, z 98..178. South gate (0,179.4) | Fine short olive lawn. Three sakura groves at (-30,128), (30,140), (84,128). Petals. Almost no understory. | Jogoss Sakura, petal_life, Grass1 short | Most open dry land, 100 m+. Camps and trunks are the cover islands. |
| 6a | └ Shimin-nōen 市民農園 (allotment, later) | Ellipse c(-64,146) r(22,16) | Soft dark-loam plots painted into the ground. Persimmon and citrus. Mown lawn between plots. | fruit_garden prototypes, park_cover tanks/crates | Quiet low-cover story spot |
| 7 | **Sandō** 参道 (tended shrine approach) | Ellipse c(168,128) r(46,40), so x 122..214, z 88..168. Torii (164,136) | The one kept place. Rich short turf, swept floor, karikomi shrubs, two azalea colours, lanterns. | clipped_shrubs (Bush006), evergreen shrub, red + pale azalea, lanterns, path lamps | Everyone stands out on it. Lit landmark and loot chokepoint. |
| 8 | **Harappa** 原っぱ (overgrown meadow) | Ellipse c(-152,104) r(66,74), so x -218..-86, z 30..178. Playground (-144,90) | Unmown, straw-tipped tall grass. Retinted fountain grass standing in for susuki. Sparse broadleaf. Shaggy hedges. | grass blades (shader height/tint), meadow and fountain grass, periwinkle | Standing exposed, prone hidden beyond about 25 m. Playground is the eerie loot spot. |
| 0 | **Hōchi kōen-rin** 放置公園林 (lapsed baseline) | Remainder: east belt, the x≈-100 seam, mainland panels (-56,-36), (0,-68), the gap z -10..30 west | Today's accepted look, unchanged | everything as-is | Baseline mixed cover |
| opt | **Takebayashi** 竹林 (bamboo, optional) | Ellipse c(-200,40) r(18,28) | Grey-olive culm tunnel on the WEST route | procedural _bamboo_mesh (needs work) | CQB flank pocket at the West gate |

## Per-biome details

**1. Momiji-dani** (spawn view)
- **Canopy:** existing belt broadleaf plus 12-18 green maples (aomomiji). Positions are swapped, not added. Scale 0.8-1.25 with random yaw. 1 in 6 uses a single shared "rust" material at saturation 0.85 or less. Never scarlet.
- **Understory:** fern-heavy diversity pattern [4,5,6,0,4], very little lilac.
- **Ground:** warmth about 0.8, so the litter goes tan and rust. leaf_00..02 is weighted up 2x in park_floor.
- **Palette:** muted olive, warm brown, timber pavilion.
- **Relief yard (1a):** the yard and two trails, (118,-176)→(132,-160) and (176,-150)→(214,-146), are painted into the worn-path map. park_cover spacing goes to 9 m inside the ellipse. Barriers are solid forms only, no mesh or slats.
- **Edges:** blends 12-15 m into Zoki over x 30..50, where maple probability and warmth ramp down. Mizube wins within 8 m of the inlet (96,-136).

**2. Matsubayashi**
- **Canopy:** woodland_layout's reskin is extended from "100% inside GROVES" to "hash(pos) < 0.6·w" over the union. That is about 60% pine in the core, falling to today's stride mix at the edge. The three GROVES stay 100%.
- **Understory:** pattern [1,6,5] (clipped evergreen, stone, deadwood). Iris carpets stay.
- **Ground:** warmth about 0.55, desaturated duff, care 0.5. Path dirt is pale.
- **Edges:** 15 m. The pine ramp is position-hashed, so edge trees mix naturally. The SPORTS_LINK route is not a boundary.

**3. Zoki-bayashi**
- **Canopy:** as today.
- **Understory density:** understory beds x1.3, diversity [4,0,5,0,6], companions mostly fern.
- **Ground:** moss 0.25, care 0.65.
- **Edges:** NorthernIrisPocket stays a found clearing inside the Koke satellite. Fades west into pine on the x≈-90 seam and east into maple.

**4. Koke-niwa**
- **Canopy:** existing infill plus 3-5 maples on the crest rim, taken from the momiji budget.
- **Understory:** diversity [1,1,6,1,4]. Azalea groups move here from japanese_flowers.
- **Ground:** moss 1.0 under canopy, care 0.15, grass keep about 0.35.
- **Props:** moss_00..11 rings around garden stones, reusing island_nature's MultiMesh. 2 Kasuga lanterns at about (-30,4) and (-4,48), each checked with _clear. Stepping stones are flattened stone_00..05 along the existing trail (-25,30)→(0,29). No raking.
- **Edges:** 12 m, giving a moss-to-iris bank at the shore.

**5. Mizube**
- **Weight:** 1 - smoothstep(8, 14, shore_dist), wobbled ±3 m. It overrides everything near water. Bridge corridors stay clear (_is_near_future_bridge_corridor).
- **Ground:** wetness darkens to about x0.75 and lowers roughness by 0.1 in blobby noise only. Moss 0.6. Peat path dirt.
- **Planting:** reeds, iris colonies at the hero pockets (canopy rule dropped), sage-tinted fountain grass. Lily rafts as today.

**6. Hanami-hiroba**
- **Canopy:** the 36 sakura are regrouped (count unchanged). About 14 move into the three groves: the north row at x -136, -86, -30 and 30; the inner accents (-60,-90), (-60,-30), (-40,-116), (30,-124), (110,-106) and (164,-72); and 4 alternate west and east column trees. 2 more go to Sandō.
- **Understory:** almost none. Companions and gap-fill beds are skipped, and gap trees are skipped.
- **Ground:** care 0.2, so short, fine, olive turf. A 3% pink dust within 6 m of grove trunks, added to turf only.
- **Allotment (6a):** irregular 4x7 m plots painted as soft blobs into the path map. No furrows.

**7. Sandō**
- **Ground:** care 0.0, moss 0.6. Litter in park_floor drops to 0.
- **Planting:** karikomi drifts and red + pale azalea (azalea_lod0/1 is unused today).
- **Props:** 2 lanterns at about (150,116) and (180,118).
- **Edges:** the tint must be applied **after** the zones.b mix (ground_texture.gd:195-196), otherwise the protected apron hides it. Fairly crisp edge, 8-10 m, marked by shrubs and never by a hedge line.

**8. Harappa**
- **Grass:** care 0.95. Blade height x1.5 and straw tips come from the shader. Blade count is unchanged.
- **Beds and shoulders:** mostly fountain/meadow grass with an instance-colour straw tint. Periwinkle patches. Playground hedges given a taller y-scale.
- **Paths:** walk shoulders 0.2-1.65 m from the edge keep short grass, so walks stay readable.

## Architecture

**1. One map, in a new script: `scripts/midori_biomes.gd`** (extends RefCounted, static, WORLD metres). It is modelled on `midori_woodland_layout.gd:5-15`.

- **Data:**
  - `REGIONS`: ellipses and soft rects from the table above. Pine imports `Woodland.GROVES`. Koke and Sandō import `GARDENS` from `midori_garden_spots.gd:6-12`, so all of them agree.
  - Mizube is a shore band computed from `terrain.edge_distance`.
- **Cache:** `ensure(terrain)` builds a **4 m cell grid** once (110x90 = 9,900 cells). Each cell holds 9 weights as a PackedFloat32Array plus the dominant id.
  - Weights: `1 - smoothstep(0.80, 1.15, ellipse_dist + 0.12·(n-0.5))`.
  - n is a fixed-seed FastNoiseLite held in a static var. It never uses producer RNG.
  - Priority: Mizube first, then Sandō/Koke, then the rest. Weights are normalised, and the remainder goes to the baseline.
  - The first consumer calls `ensure`. Every producer already reaches terrain through the park node.
- **API:**
  - `weights_at(p)` (bilinear over the grid)
  - `biome_at(p)`
  - `pick(p, salt)`: a dithered pick from a position hash, so species edges interleave. It spends 0 RNG calls.
  - `mix(id) -> Dictionary`: diversity pattern, companion kinds, bed thresholds, shoulder table, floor counts, grass keep/height/broad, tree prototype weights, understory density.
  - `look_rgba(p) -> Color`
- **Look channels** are filterable parameters, not ids, so 9 biomes fit in one RGBA8:
  - R = litter warmth
  - G = care (0 tended, **0.5 = exactly today**, 1 overgrown)
  - B = moss
  - A = wetness
  - The baseline encodes as "no change", so the before/after renders differ only inside biomes.

**2. Ground shader, one fetch**
- In `midori_ground_texture.gd` `_install_landscape_mask` (loop at 382-412), bake a 220x180 (2 m/px, 158 KB) `look_rgba` image.
- Publish it as a **global shader uniform** `midori_biome_tex` with a project.godot `shader_globals` entry, set via `RenderingServer.global_shader_parameter_set`. The terrain tiles (shared material, terrain.gd:69/218), the bank/island EARTH_PALETTE material (MPSB:390), the grass shaders and the shore_ecotone clone (176-197) then all see it, which removes the one-time-copy trap.
- Sample it once beside `zones` (line 179) and apply it:
  - litter (192) × mix(1, (1.10,0.98,0.84), R)
  - turf/lawn_tint/scanned_turf (187, 228-229): care above 0.5 goes toward straw olive, below 0.5 toward rich dark olive
  - moss (232) = max(zones.g·0.55, B)
  - after 195-196: wetness darkening and roughness, and the care tint for protected aprons (Sandō, relief yard)
  - every RGB multiplier stays within 0.85-1.12
- `midori_worn_paths.gd` FRAGMENT (49-50) tints `dirt`: pale in pine/Sandō, peat in Mizube, khaki in the relief yard, loam in the allotment. Its re-injection keeps uniforms (140-150). The yard, plots and new trails are written into its existing 4 px/m L8 map.
- Cache the bake to `user://shinrai_cache/biome_look.bin`, keyed on the biomes, terrain and lake script hashes.

**3. Producers.** Each keeps its own safety predicates and its exact RNG call count.

| File:line | Change |
|---|---|
| grass_detail.gd 587/623, 1048/1068 | Blade tint and **height** from biome tex in vertex(), so there is no re-scatter |
| grass_detail.gd 334, 344-350 | keep/broad thresholds × mix: Koke 0.35, Take 0.1 |
| understory_placement.gd 93 | Density gate: drop gap-fill in Hanami/Sandō/relief, x1.3 in Zoki. **Add `midori_biomes.gd` to the hash list at 247** |
| woodland_diversity.gd 59-65 | `pattern = mix(pick(centre,1)).pattern`. Baseline keeps index%9 |
| woodland_companions.gd 51 | Kind table. `continue` in Hanami/Sandō/Harappa |
| planted_beds.gd 48, 64-67 | Thresholds from `mix(center*2)`. Skip beds inside the Hanami lawn |
| path_shoulders.gd 51 | `kind = table[rng.randi_range(0,2)]` (still exactly one call) |
| park_floor.gd 250, 262-268 | Count tables: Momiji leaves 2x, Koke stones 2x and tufts 0.3x, Hanami/Sandō near-empty, Mizube no can/paper. 18M triangle cap at line 6 unchanged |
| sparse_vegetation.gd 78-80, 152 | Prototype by biome: Momiji maple, Pine pine, Hanami/relief skip. Pocket pattern from table |
| woodland_layout.gd apply | Hashed pine reskin over the Matsu union. Hashed maple swap in the Momiji core (w > 0.7) |
| japanese_flowers.gd 58, 154, 65 | Iris goes to the groves plus the Mizube hero pockets (canopy rule off). Azaleas go to Koke/Sandō |
| MPSB 3667-3714 | Sakura list regrouped, same nudge-clear pass |
| shore_ecotone.gd install | Loop over the 4 hero anchors. Damp-soil tint moves into the shader; ShoreDampSoil overlay retired |
| park_cover.gd 12-21 | 9 m spacing inside the relief ellipse |

**4. New content** goes in one new producer, `scripts/midori_biome_props.gd`. It has its own seeded RNG and runs after trees, the sakura swap and park_cover, but before distance_detail. It handles:
- the reed MultiMesh (36 → about 140)
- off-island moss rings
- 4 lanterns
- karikomi drifts
- allotment props

Node names keep the prefixes that `distance_detail.category` (8-14) recognises.

## Build phases

| Phase | Content | Verify |
|---|---|---|
| **0. Map only** | midori_biomes.gd, grid, bake, debug top-down overlay render | Overlay render of the whole park. Check for no visible ellipse outlines and correct anchor coverage. Startup log shows bake ms. No visual change in game. |
| **1. Smallest useful slice: Spawn-view momiji plus ground look** | Shader tint + worn-path dirt tint + blade tint/height. Momiji maple swap (cap 12 after checking the .res triangle count) | Same-camera before/after at spawn (70,-201) looking S, plus the overview. FPS at park view ≥ about 60, with no more than +0.3 ms. User sign-off on palette and subtlety. |
| **2. Tree identity** | Pine reskin ramp, sakura regroup (3 groves + 2 Sandō), Koke crest maples, momiji up to 18 if budget allows | Renders: (-155,-30) pine, (0,150) hanami looking N, (-16,22) knoll looking E, overview. Cover lattice and camp spacing check. FPS. |
| **3. Understory and floor tables** | Diversity, companions, beds, shoulders, floor, understory gate (clear the understory cache) | Same 7 cameras. startup_profile.log counts compared (fern/bush/grass totals). FPS. |
| **4. Signature content** | Mizube reeds/iris/ecotone, Koke moss and lanterns, Sandō karikomi and azaleas, relief yard, Harappa meadow grass tint | Renders: (52,56) shore, (164,100) torii looking S, (-144,70) meadow, spawn. Draw calls no more than +40 total. |
| **5. Optional** | Allotment, bamboo proof (1 clump shown first), burnt event patch only if asked | Its own before/after plus FPS |

Fixed cameras for every phase:
- (70,-201) looking S
- (-155,-30)
- (-16,22) looking E
- (52,56)
- (0,150) looking N
- (164,100) looking S
- (-144,70)
- overview

**Performance budget (whole plan):**
- Ground: +1 bilinear fetch in each of the ground, worn-path and grass shaders, plus 158 KB.
- Trees: net 0.
- Materials: at most +2 new (rust maple, reed). Straw and sage use instance colour, which distance_detail keeps (55/80). Never duplicate a material per biome (signature at line 44).
- New instances: no more than about 1,500.
- Frame time: no more than +0.8 ms GPU.

## Asset gaps and how to cover them

| Gap | Cover |
|---|---|
| Autumn/rust maple, maple variety | Single shared tinted material on 1 in 6. Rotation and scale for variety. If triangles are over about 40k, add visibility_range 90 m or cap at 12. |
| Kuromatsu / niwaki | Accept the Scots-style pines; do not fake cloud pruning |
| Reeds, cattail | Procedural reeds (MPSB:1458) as a MultiMesh |
| Lotus, hanashobu | Iris japonica stands in. Lotus skipped. |
| Susuki | Fountain/meadow grass with a straw instance tint |
| Gravel / raked sand | Pale soil-scan tint in the shader. No rake lines. |
| Stepping stones | Flattened instanced stone_00..05 |
| Tsukubai, yukimi lantern, bamboo fence, zigzag bridge | Skip. A new asset is needed if wanted. |
| Bamboo | Procedural `_bamboo_mesh` (corporate_garden_features.gd:199) with geometric node bulges and grey-olive leaf cards. Optional phase only. |
| Vegetable crops, tents, blue tarps | Allotment uses fern/periwinkle as crops. Needs new assets for realism. |
| Ambience audio (frogs, tarps, wind in pines) | New audio assets. Not blocking. |
| Hydrangea, ginkgo, wildflowers | Omitted |

## Risks

- **RNG drift:** one extra rng call in a producer loop reshuffles every later placement, including cover and loot, and breaks the before/after comparisons. Use only `pick()` hashes and table swaps.
- **Stale caches:** add the biomes script to understory_placement.gd:247. Key the look-bake cache on the terrain and lake scripts.
- **Material clones:** if the global uniform is not used, shore_ecotone (176-197) and the bank/island material (MPSB:390) render untinted seams.
- **Protected aprons hide tint:** Sandō and the relief yard must be tinted after zones.b (195-196).
- **Too subtle versus quilted:** muted tints may go unnoticed. Readability comes from species, understory and grass height. Seven ellipses could also look like patchwork. Keep 10-15 m feathers, noise wobble, and the baseline dominant at about 40%. Judge from the overview render.
- **Maple cost:** the source OBJ is 77 MB. Measure the .res first, and fall back to 12 maples.
- **Sakura regroup:** this changes north-row cover next to spawn and the canopy G-channel. Re-check the 36 m cover hex and 26 m minimum spacing, and the bridge corridors.
- **Gameplay shifts:** Harappa's tall grass hides prone players (deliberate; needs a playtest). The Hanami lawn and the Matsu floor create long sniper lanes. The relief yard at 9 m spacing changes the loot/fight balance at the fence hole (118,-179.4).
- **User preferences:**
  - No stripes, furrows, rake lines or slats anywhere, including the allotment, barriers and bamboo.
  - No hedge rows along biome edges.
  - Olive, never lime.
  - Wetness roughness only in blobs. Check it at night so it does not look plastic.
- **Unverified layout:**
  - fruit_garden's existing site has not been checked against the allotment ellipse.
  - The line refs come from read-only maps; check them before editing.
  - Godot was not run.

```biomes
[
 {"id":"momiji","name":"Momiji-dani 紅葉谷","shape":"ellipse","center":[110,-148],"radius":[70,30],"feather_m":14},
 {"id":"relief_yard","name":"Relief yard 避難所 (sub of momiji)","shape":"ellipse","center":[152,-146],"radius":[34,22],"feather_m":10},
 {"id":"matsu","name":"Matsubayashi 松林","shape":"ellipse","center":[-150,-62],"radius":[64,52],"feather_m":15},
 {"id":"matsu","name":"Matsubayashi 松林 (court lobe)","shape":"ellipse","center":[-104,-140],"radius":[38,32],"feather_m":15},
 {"id":"matsu","name":"Matsubayashi 松林 (east stand)","shape":"ellipse","center":[185,40],"radius":[26,29],"feather_m":10},
 {"id":"zoki","name":"Zoki-bayashi 雑木林","shape":"rect","x":[-86,40],"z":[-178,-50],"feather_m":12},
 {"id":"koke","name":"Koke-niwa 苔庭","shape":"ellipse","center":[-14,20],"radius":[44,40],"feather_m":12},
 {"id":"koke","name":"Koke-niwa satellite (Northern iris pocket)","shape":"circle","center":[24,-114],"radius":18,"feather_m":6},
 {"id":"mizube","name":"Mizube / Hanashobu 水辺","shape":"shore_band","inland_m":[0,14],"full_m":8,"lake_bbox":{"x":[28,158],"z":[-136,98]},"includes":"7 islands","hero_pockets_20m":[[52,56],[149,24],[64,-97],[124,-123]]},
 {"id":"hanami","name":"Hanami-hiroba 花見広場","shape":"ellipse","center":[20,138],"radius":[96,40],"feather_m":15,"sakura_groves":[[-30,128],[30,140],[84,128]]},
 {"id":"allotment","name":"Shimin-noen 市民農園 (phase 5)","shape":"ellipse","center":[-64,146],"radius":[22,16],"feather_m":8},
 {"id":"sando","name":"Sando 参道","shape":"ellipse","center":[168,128],"radius":[46,40],"feather_m":9},
 {"id":"harappa","name":"Harappa 原っぱ","shape":"ellipse","center":[-152,104],"radius":[66,74],"feather_m":15},
 {"id":"take","name":"Takebayashi 竹林 (optional)","shape":"ellipse","center":[-200,40],"radius":[18,28],"feather_m":10},
 {"id":"baseline","name":"Hochi koen-rin 放置公園林","shape":"remainder","bounds":{"x":[-220,220],"z":[-180,180]}}
]
```