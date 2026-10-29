# Mainland boulder cover - installed review

The island's pointed Poly Haven rock_03.glb is reused for six additional mainland cover placements. Existing boulder cover and the island planting are retained. No asset geometry, materials or source textures changed.

Installed source: scripts/midori_island_nature.gd; authoritative scene: res://scenes/shinrai_extraction.tscn. The service picks one position within each of six bounded mainland regions, excluding water, routes, reserved activity areas, tree trunks, planned asset sockets, existing boulder cover and flower beds. Eight terrain samples limit the supporting height variation to 0.20 m. Footprints are conservative diagonal bounds; declared route gap exceeds footprint radius plus 2 m, planned socket gap exceeds radius plus 11 m, and existing/new cover is spaced at least 16/24 m respectively. The boulders retain a sunk base and exact transformed convex hull collision; their render range is 140 m.

## Installed placements
[
  {
    "exposed_height_m": 1.558,
    "node": "MainlandStoneCover_0",
    "p": "(-84.77791, 102.4694)",
    "radius": 1.55584553108717
  },
  {
    "exposed_height_m": 1.64,
    "node": "MainlandStoneCover_1",
    "p": "(-55.23594, -111.8977)",
    "radius": 1.63773213798649
  },
  {
    "exposed_height_m": 1.722,
    "node": "MainlandStoneCover_2",
    "p": "(-45.0, -30.0)",
    "radius": 1.71961874488582
  },
  {
    "exposed_height_m": 1.558,
    "node": "MainlandStoneCover_3",
    "p": "(98.30267, 119.0007)",
    "radius": 1.55584553108717
  },
  {
    "exposed_height_m": 1.64,
    "node": "MainlandStoneCover_4",
    "p": "(191.0255, -101.4748)",
    "radius": 1.63773213798649
  },
  {
    "exposed_height_m": 1.722,
    "node": "MainlandStoneCover_5",
    "p": "(-167.9229, -115.0833)",
    "radius": 1.71961874488582
  }
]

## Verification

Final source parse check and targeted git diff --check passed; installed/candidate SHA-256 matches. A fresh full authoritative Forward+ scene run accepted all six cover sites, retained all 730 baseline tree positions and the island counts of 25 stones/111 floor plants, and captured twelve player-height day/night views. Physics ray checks at 1 m above terrain, from two perpendicular directions per boulder, hit each boulder's own solid collider. This proves crouch-height physical occlusion in those sampled directions, not enemy combat behaviour or full standing cover on every contour.

All six daylight placements and representative night views were visually inspected. Five silhouettes read clearly in the chosen views; the eastern woodland placement is partly obscured by the existing tree canopy from the review camera. Source shapes and terrain burial produce exposed heights 1.558-1.722 m, rather than inflated giant rocks.

Evidence: mainland_cover_qa/review.log and cover_day_*.png / cover_night_*.png. The review instance exited normally. Existing user-log and shader-cache write diagnostics and root-certificate diagnostics are separate from successful assertions. No full-game FPS or AAA-quality claim is made.
