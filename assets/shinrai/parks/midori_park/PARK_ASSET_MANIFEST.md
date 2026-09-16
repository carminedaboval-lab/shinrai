# SHINRAI — Midori Sakura Park Asset Manifest

This manifest is the single checklist for the first production park. The user authorized assembly on 2026-09-16. The active phase is playable park assembly: footprint, zone-scale, and the first vegetation pass, while remaining source assets continue to be collected.

## Park composition target

- Match the supplied SHINRAI CITY artwork: a modern, near-future landscaped lake park surrounded by dense urban districts.
- Sakura trees replace the generic green tree canopy while preserving the artwork's lush density.
- Current footprint blockout: 220 m x 180 m (39,600 m²), with a 284 m diagonal that extends beyond the 120–130 m fog visibility range.
- Current canopy: 24 hand-placed dense sakura instances using a cleaned derivative of the user-supplied Winter Sentinel and 150 branch-attached, pink-only blossom bunches per tree.
- Current artwork pass: two lake bridges, one eastern viewing deck, nine shoreline boulder groups, two planted islands, 36 reed-like waterside clusters, nine denser shoreline grass patches, and eight new mainland grove zones with 24 existing-pack grass patches are placed in the playable park.
- Clear main entrance, secondary entrances, a loop path, lake crossing, modern pavilion, playground, sports area, viewing deck, and an open central gathering space.
- Tree trunks and structures provide deliberate cover; the central space retains long sightlines.
- All placements are local to the park scene, so every tree and prop follows the park when its city block changes.
- Avoid shrine, temple, fantasy-garden, and historical styling that is absent from the artwork.

## Meshy production assets

| ID | Asset | Unique models | Expected park instances | Triangle target per model | Status |
|---|---|---:|---:|---:|---|
| VEG-01 | Dense Winter Sentinel sakura | 1 | 48 | 68,531 assembled | Source preserved unchanged; game-ready copy removes tiny disconnected shards and all green canopy geometry; 150 branch-attached blossom bunches and 48 varied instances placed |
| VEG-01-FOL | Reusable sakura blossom branch cluster | 1 source; variants later | Canopy distribution later | 8,192 source; optimize later | Collected, approved, optimized, and used in sakura v1 |
| VEG-02 | Medium upright sakura | 1 | 5–6 | 6k–9k | Source covered by VEG-01 derivative; attempt 02 rejected as flattened |
| VEG-03 | Small leaning sakura | 1 | 4–7 | 5k–8k | Source covered by VEG-01 derivative; no separate Meshy generation |
| VEG-04 | Low shrub cluster, broad | 2 dense lilac variants | Clustered understory | Existing imported pack | Dense lilac masses and tree-gap vegetation; sparse legacy shrub removed from placement |
| VEG-05 | Low shrub cluster, narrow | Derived from VEG-04 modular sources | 6–10 | 1k–2k assembled | Source covered; no separate Meshy generation |
| VEG-06 | Reed and waterside grass cluster | 5 | 45 | 3,877 and 4,262 source plus three extracted grass groups | Thirty-six reed-like clusters mixed with nine denser landward grass patches |
| VEG-08 | Near-ground clump scatter | 1 existing source | 18,000 | MultiMesh instances | Count retained at 18,000; measured GLB bounds now keep the enlarged clumps 3.5 cm above the lawn surface |
| VEG-07 | Mossy boulder cluster, large | 1 | 9 | 5,350 source | Game-ready working copy placed as shoreline cover and island landmarks |
| VEG-08 | Mossy boulder cluster, small | Derived from VEG-07 | 5–7 | 1k–3k | Source covered; no separate Meshy generation |
| WAT-01 | Main modern arched pedestrian bridge | 1 | 1 | 11,553 source | Game-ready working copy placed on the south lake approach; railing cleanup later |
| WAT-02 | Small secondary lake footbridge | 1 | 1 | 7,200 source | Game-ready working copy placed across the north lobe; underside cleanup later |
| WAT-03 | Lakeside viewing deck and railing | 1 | 1 | 8,492 source | Game-ready working copy placed on the east overlook; entrance and centre-triangle repair later |
| ARC-01 | Open modern Japanese park pavilion | 1 | 1 | 10k–15k | Pending |
| ARC-02 | Small maintenance and restroom building | 1 | 1 | 8k–12k | Pending |
| ARC-03 | Modern park entrance marker | 1 | 1 | 4k–7k | Pending |
| FUR-01 | Weathered timber and metal bench | 1 | 5–7 | 2k–4k | Pending |
| FUR-02 | Backless stone bench | 1 | 2–3 | 1k–2k | Pending |
| FUR-03 | Recycling and rubbish station | 1 | 2 | 2k–4k | Pending |
| FUR-04 | Modern Japanese park lamp | 1 | 8–12 | 2k–4k | Pending |
| FUR-05 | Low modern path bollard light | 1 | 8–12 | 1k–3k | Pending |
| FUR-06 | Park map and information board | 1 | 1 | 2k–4k | Pending |
| FUR-07 | Directional signpost | 1 | 2–3 | 1k–2k | Pending |
| FUR-08 | Drinking fountain | 1 | 1 | 2k–3k | Pending |
| FUR-09 | Bicycle rack with two bicycles | 1 | 1 | 5k–8k | Pending |
| FUR-10 | Outdoor vending machine | 1 | 1 | 4k–6k | Pending |
| FUR-11 | Removable entrance bollard | 1 | 6–8 | 1k–2k | Pending |
| FUR-12 | Modern picnic table | 1 | 2–3 | 3k–5k | Pending |
| FUR-13 | Emergency call and information point | 1 | 1 | 2k–4k | Pending |
| ACT-01 | Compact playground set with slide and climbing frame | 1 | 1 | 10k–15k | Pending |
| ACT-02 | Basketball hoop and post | 1 | 1 | 3k–5k | Pending |
| ACT-03 | Tennis net and post set | 1 | 1 | 2k–4k | Pending |
| ACT-04 | Sports-court fence gate and equipment rack | 1 | 1 | 4k–7k | Pending |
| GAM-01 | Large concrete planter used as waist-high cover | 1 | 3–5 | 2k–4k | Pending |
| GAM-02 | Folding maintenance barricade | 1 | 2–3 | 2k–3k | Pending |
| GAM-03 | Weatherproof electrical utility cabinet | 1 | 2 | 2k–3k | Pending |
| GAM-04 | Park security camera pole | 1 | 2 | 2k–4k | Pending |

## Godot-built modular pieces

These require exact dimensions, clean repetition, simple collision, or flat materials. They will be built and controlled in Godot instead of generated as unique Meshy sculptures.

- Grass, compacted soil, gravel, stone plaza, playground rubber, and basketball court surfaces.
- Pond bed and water surface.
- Straight, inner-corner, outer-corner, and end-cap pond edging.
- Straight and curved path sections.
- Low retaining-wall modules and stair modules.
- Path handrail and pond safety-rail modules.
- Drain channels and grate modules.
- Court markings.
- Tree planting rings and root guards.
- Simple litter pieces used in larger quantities.

## Materials, decals, effects, and audio

- Sakura bark, blossom, leaf, and branch materials.
- Grass, soil, moss, gravel, stone, painted metal, timber, concrete, rubber, and water materials.
- Fallen sakura-petal decals in light, medium, and heavy coverage.
- Damp patches, mud, moss edge, leaf litter, cracks, stains, and path-wear decals.
- Falling petal particle effect with a strict distance limit.
- Pond ripple and floating-petal effects.
- Local park fog and soft light shafts where performance permits.
- Water, wind, leaves, distant city, birds, lamp hum, and pavilion creak ambience.

## Gameplay and technical setup

- Collision only for trunks, major low branches, structures, bridge, stones, benches, planters, barriers, and utility props.
- Blossom clusters, leaves, reeds, small shrubs, litter, signs, lamps, and decorative rails use no complex mesh collision.
- Three tree LOD levels plus a distant impostor or aggressive visibility range.
- Repeated trees and small vegetation use MultiMesh after hand placement is approved.
- Navigation remains open through the central plaza and main loop path.
- Cover spacing supports short sprints between trunks, planters, bridge rails, pavilion posts, and pond stones.
- The pond edge prevents accidental trapping and provides at least two crossing routes.
- Loot sockets: pavilion, maintenance building, vending machine, playground edge, bridge overlook, and utility cabinet.
- Extraction/event socket: open central plaza.
- Enemy approach sockets: main entrance, two side entrances, maintenance entrance, and bridge approach.
- Every imported GLB uses metre scale, a ground-centred pivot, PBR materials, no embedded cameras or lights, and descriptive mesh/material names.

## Source collection pipeline — active alongside footprint review

For every Meshy asset:

1. Review screenshots from front, both sides, back, top, and underside.
2. Reject disconnected parts, sealed openings, warped silhouettes, floating details, or unusable topology before texturing.
3. Download the approved model as GLB with 2K PBR textures.
4. Save the untouched file under `source_glb/<asset_id>/`.
5. Record the Meshy prompt, generation settings, licence, triangle count, texture resolution, and approval screenshots.
6. Mark the entry Collected. Do not alter the GLB or import it into the playable park during this phase.

The `source_glb` folder remains excluded from Godot scanning. The user explicitly authorized assembly on 2026-09-16. Current implementation is limited to the 220 m × 180 m playable size blockout and zone review; detailed asset optimization and placement wait for footprint approval.

## Detailed assembly pipeline — active

After collection is complete:

1. Preserve every untouched source GLB.
2. Create separate optimized Godot-ready copies.
3. Correct scale, pivot, materials, normals, mesh separation, and polygon count.
4. Add simple authored collision and required LODs.
5. Create reusable `.tscn` asset scenes.
6. Hand-place the complete artwork-matched park.
7. Test appearance, collision, culling, navigation, and frame time.

## Current reference

- `res://assets/shinrai/vegetation/sakura/references/shinrai_sakura_tree_meshy_reference_v1.png`
- `res://assets/shinrai/parks/midori_park/references/midori_park_layout_pass_v1.png`
- See `MIDORI_PARK_LAYOUT_PLAN.md` for the implemented district layout and every planned prop socket.





















