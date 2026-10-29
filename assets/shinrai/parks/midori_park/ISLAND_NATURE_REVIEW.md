# Midori island nature review - 2026-10-06

Authoritative project: C:/Users/hp/OneDrive/Documenti/GitHub/shinrai. Main scene: res://scenes/shinrai_extraction.tscn; park review scene also has the new service.

Two CC0 Poly Haven asset packs were acquired, checked against API MD5 metadata, and adapted into six rock GLBs and twelve moss-frond GLBs. Original assets/maps remain in staging island_asset_qa/source. Individual meshes have centred floor pivots and source materials/colours; moss diffuse alpha is restored from its source opacity map. Existing supplied fern and floor-shrub assets are reused.

The scoped service midori_island_nature.gd installs after terrain. It fits unequal stone groups to each island, gathers low planting into adjacent pockets, leaves exposed ground, and excludes trunks, island banks and declared routes. Stones sink 18 percent of their scaled height and use matching convex hull collision. Moss retains centimetre source dimensions, has 14 m detail culling, and uses shared alpha-scissor material. Rock and plant detail culls at 55 m. No island terrain, water, existing tree positions or source assets were replaced.

## Verification

Godot import and final source parse check passed. Targeted git diff --check passed. Fresh full authoritative Forward+ scene load reviewed the initial pass and preserved all 730 trunk registry positions. The final grouping/collision refinement was reloaded from the installed source into that full scene and reviewed at player height in seven daylight and seven night views, plus stone/moss close views. Final terrain bounds and physics ray tests passed: all 25 solid rocks were hit on their own colliders, no new visual bounds extend into water, and minimum conservative planted footprint bank gap is 0.51856 m. The small islet intentionally uses one stone where the remaining grouped positions cannot clear banks/trunks.

Evidence: island_asset_qa/review.log, final_day_*.png, final_night_*.png, final_stone_close.png and final_moss_close.png.

Final counts:
{
  "islands": [
    {
      "floor_plants": 16,
      "island": 0,
      "moss_fronds": 5341,
      "stones": 4
    },
    {
      "floor_plants": 16,
      "island": 1,
      "moss_fronds": 5355,
      "stones": 4
    },
    {
      "floor_plants": 16,
      "island": 2,
      "moss_fronds": 5347,
      "stones": 4
    },
    {
      "floor_plants": 16,
      "island": 3,
      "moss_fronds": 5348,
      "stones": 4
    },
    {
      "floor_plants": 16,
      "island": 4,
      "moss_fronds": 5344,
      "stones": 4
    },
    {
      "floor_plants": 16,
      "island": 5,
      "moss_fronds": 5339,
      "stones": 4
    },
    {
      "floor_plants": 15,
      "island": 6,
      "moss_fronds": 1341,
      "stones": 1
    }
  ],
  "moss": 33415,
  "plants": 111,
  "rocks": 25,
  "stone_collisions": 25
}

## Limits

This is inspired by Japanese pond-island stone composition, not a reproduction of a specific Japanese garden or proof of Japanese rock geology/moss species. No overall performance or AAA quality claim is made. The runtime log also contains existing log/cache write permission and root-certificate diagnostics; a provisional review assertion required adjusting its minimum rock count for the smallest islet, followed by successful final collision/bounds checks. These diagnostics are separate from successful local import, parse and final runtime checks.
