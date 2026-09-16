# Midori Park game-ready vegetation

## `midori_sakura_winter_sentinel_clean_v2.glb` — active

- Uses the user-supplied Winter Sentinel as its preserved source. The game-ready copy removes 1,611 tiny disconnected shard components while retaining the continuous trunk and branch structure.
- Adds 150 small VEG-01-FOL blossom bunches sampled directly from the real branch surfaces.
- The derivative flower module contains pink and pale petals only. Its green leaf faces and 4,847 mismatched twig faces are removed, so the green geometry cannot appear in Godot.
- All blossom bunches are merged into one canopy mesh, giving the tree two rendered mesh groups in total.
- Rendered triangle cost per tree: 68,531 (2,381 trunk and branches; 66,150 blossoms).
- Godot placement: 24 hand-authored transforms with varied rotation and scale.
- Collision: simple generated trunk cylinders; branches and flowers have no mesh collision.
- Visibility range: 150 metres, hidden by the park fog.

## `midori_sakura_winter_sentinel_dense_v1.glb` — superseded

- Earlier twenty-cluster prototype retained as a build reference.
- Superseded because its flower modules included visible green leaves and the untouched source mesh contained many floating shard components.

## `midori_sakura_tree_v1.glb` — inactive prototype

- Built from the preserved VEG-01 hero-sakura woody source and VEG-01-FOL blossom branch.
- The rejected angular pink canopy faces were removed.
- Uses four linked, decimated blossom-and-leaf clusters and clean structural branches.
- Approximate rendered triangle cost per tree instance: 14,891.
- This temporary rebuild is not referenced by the park. It was superseded by the active Winter Sentinel version and is retained only as a build reference.
- Collision: simple generated trunk cylinders; decorative branches and foliage have no mesh collision.

## `midori_evergreen_shrub_v1.glb` — inactive

- Built from the preserved VEG-04A woody base and VEG-04B evergreen leafy sprig.
- Uses three linked, decimated leafy clusters.
- Approximate rendered triangle cost per shrub instance: 2,635.
- Removed from park placement because its low spreading form read as an isolated artificial bush.
- Retained only as a source reference; no collision.

## Mainland understory

- The pine pack's three dedicated sapling LOD1 meshes supply fourteen varied young-pine placements on the mainland. They use the skinny-tree clearance rules and no collision.
- The previously unused `Tree EZTree1.Bush006` mesh supplies fifty-six low woodland plants in uneven five-plant floor pockets. They remain decorative and are kept out of important routes.
- The active mainland understory uses the two denser variants from `vendor/lilac_bush_pack/`.
- The sparse small lilac variant is excluded. Dense variants are placed in irregular 3–7 plant masses and asymmetric three-shrub pockets between mixed broadleaf/skinny-pine pairs. Former isolated shrub rows are removed, and active lilacs preserve approximately 1.3 m beside important paths.
- Twenty-four patches from the existing dense-grass pack sit around the eight mainland infill groves; the lake islands are unchanged. The heavy `Grass1` variant is corrected for dark transparent-blade self-shadowing and restricted to four reduced-scale deep-woodland accents; shoreline patches use only the two lighter variants.
- The Meshy ground-clump scatter remains at 18,000 instances. Its imported bounds were measured at 0.796875 m high with a -0.378906 m base, so placement now uses the true base plus a fixed 3.5 cm reveal instead of an assumed centred one-metre pivot.
- `vendor/midnight_fern/midnight_fern.glb` supplies up to 48 reduced-scale fern accents in twelve irregular mainland pockets. These decorative plants add recognizable floor foliage without changing the 18,000-clump scatter or touching the islands.
- `vendor/emerald_fountain_grass/emerald_fountain_grass.glb` supplies the 5,628-triangle mid-height sedge layer. It is varied between approximately 0.62 and 0.88 m and placed in irregular three-to-six-plant mainland groups between groves, shrubs, and ferns; it has no collision and does not touch the islands.

## Japanese maple accents

- `vendor/free3d_japanese_maple_n030123/` supplies the first distinct Japanese maple. Its 545,103-triangle source is restricted to one 6.4 m hero placement with simple trunk collision.
- A second, lighter 3D Warehouse maple remains pending its actual download. The heavy first maple is not duplicated as a substitute.

## Waterside and shoreline assets

- `midori_green_fountain_grass_v1.glb` and `midori_swaying_meadow_grass_v1.glb` are exact working copies of the preserved VEG-06 originals. Thirty-six varied instances provide the reed-like lake-edge layer.
- `vendor/cosmic_dust_grass/grass_1k.glb` supplies three denser grass forms. Nine landward patches are mixed between the reed-like clusters to thicken the shoreline without reaching full Grey Zone Warfare density. The 1K GLB is used to control memory cost; the full source scene is not repeated as one 81K-triangle unit.
- Twenty-five reduced-scale fountain/meadow grass accents create irregular mainland transition pockets around grove floors. They add a mid-height layer without changing the 18,000 near-ground clumps or repeating the heavy grass mesh.
- `midori_mossy_boulder_cluster_v1.glb` is an exact working copy of VEG-07. Nine scaled and rotated groups provide shoreline landmarks and combat cover.
- The running scene supplies simple boulder collision. The grass clusters remain decorative and stop rendering beyond the park fog range.

## Staged deadwood sources

- `vendor/mistrzjang1_tree_trunk/` supplies the downloaded retopologized beech trunk and PBR maps. Seven rotated and proportion-varied copies form fallen pieces, while five upright copies form stump bases.
- `vendor/michaeldebbarma_hollow_bark/` supplies one 220,222-polygon focal prop. It remains limited to a single reduced-scale mainland placement.
- Deadwood is settled slightly into the terrain and preserves approximately 1.3 m beside important paths. Collision is limited to four large logs, three tall stumps, and the heavy focal piece.

The untouched Meshy downloads remain under `source_glb/`. These GLBs are derived game-ready assets and can be rebuilt from those sources.
