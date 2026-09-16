# Midori Park game-ready vegetation

## `midori_sakura_winter_sentinel_clean_v2.glb` — active

- Uses the user-supplied Winter Sentinel as its preserved source. The game-ready copy removes 1,611 tiny disconnected shard components while retaining the continuous trunk and branch structure.
- Adds 150 small VEG-01-FOL blossom bunches sampled directly from the real branch surfaces.
- The derivative flower module contains pink and pale petals only. Its green leaf faces and 4,847 mismatched twig faces are removed, so the green geometry cannot appear in Godot.
- All blossom bunches are merged into one canopy mesh, giving the tree two rendered mesh groups in total.
- Rendered triangle cost per tree: 68,531 (2,381 trunk and branches; 66,150 blossoms).
- Godot placement: 48 hand-authored transforms with varied rotation and scale.
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

## `midori_evergreen_shrub_v1.glb`

- Built from the preserved VEG-04A woody base and VEG-04B evergreen leafy sprig.
- Uses three linked, decimated leafy clusters.
- Approximate rendered triangle cost per shrub instance: 2,635.
- Godot placement: 30 hand-authored transforms with varied rotation and scale.
- Decorative only; no collision.

The untouched Meshy downloads remain under `source_glb/`. These GLBs are derived game-ready assets and can be rebuilt from those sources.
