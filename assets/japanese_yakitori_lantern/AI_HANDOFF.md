# AI handoff: Japanese Yakitori Lantern

Use `japanese_yakitori_lantern.glb` as the authoritative finished asset.

Integration facts:
- Engine target: Godot 4.x
- Units: meters
- Up axis: +Y
- Front / lettering direction: -Z
- Approx overall size: 0.344 m wide x 1.017 m tall x 0.344 m deep
- High-detail hero mesh: ~446,776 triangles total
- The master asset must not be replaced by a low-poly version.
- PBR textures are embedded in the GLB and also supplied separately under `textures/`.
- The red washi includes the supplied vertical `やきとり` brush lettering.
- The bamboo rib is modeled as one continuous spiral.
- Metal collars, lips, rivets, hanger hardware, and bottom ring are geometry.
- A warm internal point light is included through glTF `KHR_lights_punctual`.

Preferred Godot workflow:
1. Copy the whole folder to `res://assets/japanese_yakitori_lantern/`.
2. Import `japanese_yakitori_lantern.glb`.
3. Instantiate the GLB directly, or use `japanese_yakitori_lantern.tscn` for the simple collision wrapper.
4. Keep imported normal maps and emissive textures enabled.
5. If the glTF light extension is not imported, add an `OmniLight3D` at local origin, warm orange (~2200 K), range about 2.5 m, shadows on.
6. Do not rescale unless gameplay requires it; the model is authored at real-world scale.
