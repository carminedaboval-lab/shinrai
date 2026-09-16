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

- The active mainland understory uses the two denser variants from `vendor/lilac_bush_pack/`.
- The sparse small lilac variant is excluded. Dense variants are placed in irregular masses and between mixed broadleaf/skinny-pine pairs.
- Twenty-four patches from the existing dense-grass pack sit around the eight mainland infill groves; the lake islands are unchanged. The heavy `Grass1` variant is corrected for dark transparent-blade self-shadowing and restricted to four reduced-scale deep-woodland accents; shoreline patches use only the two lighter variants.
- The Meshy ground-clump scatter remains at 18,000 instances. Its imported bounds were measured at 0.796875 m high with a -0.378906 m base, so placement now uses the true base plus a fixed 3.5 cm reveal instead of an assumed centred one-metre pivot.

## Waterside and shoreline assets

- `midori_green_fountain_grass_v1.glb` and `midori_swaying_meadow_grass_v1.glb` are exact working copies of the preserved VEG-06 originals. Thirty-six varied instances provide the reed-like lake-edge layer.
- `vendor/cosmic_dust_grass/grass_1k.glb` supplies three denser grass forms. Nine landward patches are mixed between the reed-like clusters to thicken the shoreline without reaching full Grey Zone Warfare density. The 1K GLB is used to control memory cost; the full source scene is not repeated as one 81K-triangle unit.
- `midori_mossy_boulder_cluster_v1.glb` is an exact working copy of VEG-07. Nine scaled and rotated groups provide shoreline landmarks and combat cover.
- The running scene supplies simple boulder collision. The grass clusters remain decorative and stop rendering beyond the park fog range.

## Staged deadwood sources

- `vendor/mistrzjang1_tree_trunk/` contains the downloaded retopologized beech trunk and PBR maps. It is staged for the fallen-log pass and is not spawned yet.
- `vendor/michaeldebbarma_hollow_bark/` contains the 220,222-polygon hollow-bark source. It is intentionally staged only; when placed, it must be limited to one or two focal props or reduced first.

The untouched Meshy downloads remain under `source_glb/`. These GLBs are derived game-ready assets and can be rebuilt from those sources.
