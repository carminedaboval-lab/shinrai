# Long Paved Walkway — Godot Integration

This is a **hero alley / pedestrian-edge asset**, not a replacement for the procedural SHINRAI road network.

The project's existing production road is intentionally lightweight and repeated throughout the generated town. This Sketchfab-derived walkway remains much denser even after optimization, so use it in a small number of authored locations where the wall, paving and vegetation detail are visible at close range.

## Expected game-ready file

Place the optimized GLB here:

`res://assets/environment/roads/long_paved_walkway/LongPavedWalkway_GameReady_GodotYUp_1K.glb`

The wrapper scene in this folder expects that exact path.

## Game-ready asset properties

- Godot orientation: **X = width, Y = up, Z = length**
- Centered on X/Z
- Lowest point aligned to Y = 0
- Approximate overall size: **2.60 m wide × 10.03 m long × 0.65 m high**
- Render geometry: **36,115 triangles** (source: 361,165)
- Two retained PBR material sets
- Embedded textures reduced from 4K to **1K**
- Intended use: one/few authored alley, canal-edge or side-path segments

## Wrapper scene

Use:

`LongPavedWalkway_GameReady.tscn`

It instances the GLB and adds simple low-cost static collision:

- one box for the walkable paved surface
- one box for the raised wall/parapet edge

The collision is deliberately simple rather than trimesh collision because the visual mesh is still comparatively dense.

## Performance guidance

Do **not** tile this asset across every generated road cell. The current SHINRAI production road is only about 3K triangles per authored module and is already integrated into the procedural road system. Keep that road for the network and use this walkway as an environmental accent.

For the first test, place a single instance on the locked visual-comparison side street or another authored alley and review:

- scale against doors, curbs and the player
- whether the wall side faces the intended building/canal edge
- night readability under the current GL Compatibility renderer
- texture sharpness at normal gameplay distance
- collision height at the paved surface

## License

See `ATTRIBUTION.md`. The asset is by **SPLEEN VISION** and licensed **CC BY 4.0**. Keep the attribution with the project and include an equivalent credit in release credits / third-party notices.
