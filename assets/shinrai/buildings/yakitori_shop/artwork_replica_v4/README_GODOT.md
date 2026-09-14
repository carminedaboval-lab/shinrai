# SHINRAI Yakitori Shop — Artwork Replica v4

This is the building-only pass matched to the supplied Yakitori Shop material
sheet. It replaces the shallow one-storey shell and runtime stack of extension
boxes with one full-depth, two-storey authored GLB.

## Current project

The included `scripts/town_main.gd` instantiates:

`res://assets/shinrai/buildings/yakitori_shop/artwork_replica_v4/ProjectShinrai_YakitoriShop_ArtworkReplica_v4.tscn`

Run `res://scenes/main.tscn` normally. The deterministic commercial test corridor
replaces its former procedural storefront with this scene at scale `(1, 1, 1)`.

For manual use, drag the `.tscn` above into a Godot scene. The asset is authored
in metres, Y-up, with its front facing local `-Z`.

## Locked body dimensions

- Width: **4.20 m**
- Full depth: **4.58 m**
- Highest architectural silhouette: **6.40 m**
- Entrance socket: **(0.0, 0.0, -0.72)**

## Included now

- Full-depth two-storey plaster/concrete shell
- Existing bevelled ground-floor storefront with the obsolete upper cap removed
- Artwork-matched upper window proportions and vertical timber screen
- Layered canopy/eaves, true low-slope roof, flashing, rear piers, and roof rail
- Continuous stone plinth, compact paired pulls, and offset rear window
- Game collision with a future 1.16 m interactive-door opening
- Three canopy-light sockets and clean sockets for later passes
- Nine artwork material families with embedded PBR textures and tangent data

## V4 close-up corrections

- Side/rear formwork joints are thin charcoal reveals rather than black bars
- Plaster, stone, and roof textures are recolored to the artwork swatches
- Roof surface is matte charcoal and separate from metallic edge flashing
- Roof guard is lower, thinner, inset, and follows the roof pitch
- Upper eave, soffit ribs, brackets, and flashing have a lighter silhouette
- Long horizontal timber members use corrected grain direction
- Canopy lenses use a restrained warm emission for closer inspection

## Intentionally deferred

Signage, lanterns/noren, plants, props, AC units, finished glazing calibration,
and interior design are not included. The current glass and interior materials
are explicitly named `PLACEHOLDER` so they can be replaced independently.

## Later-pass sockets

- `SOCKET_CanopyLight_00` through `02`
- `SOCKET_Lantern_Right_LATER`
- `SOCKET_VerticalSign_Right_LATER`
- `SOCKET_Noren_LATER`
- `SOCKET_InteriorOrigin_LATER`
- `SOCKET_Roof`

The deterministic source builder is included in `source/`.
