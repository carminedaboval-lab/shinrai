# SHINRAI Yakitori Shop — Artwork Replica v6

This is the finished building-only presentation scene used by the playable town.
It preserves the real V5 authored GLB, textures, scale, collision and nine sockets,
then performs the final Godot-side architectural finish.

## Finished in V6

- Reference-matched exposure and roughness for all exterior material families
- Dark aged plaster and restrained stone/entrance floor
- Warm-neutral transparent glazing
- Finished prop-free architectural interior shell and dark timber floors
- Subtle warm ground- and upper-floor architectural light
- Fully rebuilt thin canopy flashing with closed corners
- Fully rebuilt upper roof flashing with closed perimeter edges
- Roof guard moved near the perimeter, seated on the roof and joined at corners
- Compact paired door handles
- Rear-window metal reveal and masonry-pier caps
- Two slim rear downpipes
- Existing full two-storey body, timber screen, eaves, collision and sockets retained

## Intentionally excluded

Only props remain excluded: signs, lanterns, noren, plants, furniture, kitchen
equipment, tableware, bottles, AC units and street dressing.

## Godot

The town loads:

`res://assets/shinrai/buildings/yakitori_shop/artwork_replica_v6/ProjectShinrai_YakitoriShop_ArtworkReplica_v6.tscn`

The root remains at metric scale `(1, 1, 1)`, Y-up, with the storefront facing
local `-Z`. All new finish geometry is parented under the imported Model node so
the existing placement transform and gameplay collision remain aligned.
