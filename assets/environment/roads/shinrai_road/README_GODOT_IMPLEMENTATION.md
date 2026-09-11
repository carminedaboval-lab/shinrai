# SHINRAI ROAD — GODOT 4 IMPLEMENTATION HANDOFF

This package contains the complete current road asset: final high-poly source,
approved dry PBR textures, optimized game mesh, references, and Godot helper files.

## IMPORTANT: DO NOT REGENERATE THE ROAD
Use the supplied game-ready mesh and textures. The source high-poly folder is
included only for rebakes/LOD changes.

## Exact asset
- Asphalt road only.
- Width: 3.10 m.
- Length: 5.00 m.
- Dry/matte material.
- No curb.
- No drain.
- No manhole.
- No road markings.
- No puddles or wet reflections.
- Dominant irregular longitudinal center crack.
- Broad, restrained repair history.
- Fine compact asphalt aggregate.

## Drop-in path
Copy the included `assets` folder into the Godot project root so this exists:

`res://assets/environment/roads/shinrai_road/`

The paths in the provided `.tres` and EditorScripts assume that exact location.

## Preferred Godot mesh
Use:

`mesh/SHINRAI_Road_LP_Godot_YUp.glb`

It is already converted for Godot:
- Y is up.
- X is road width.
- Z is road length.
- Lowest road surface point is aligned to Y = 0.

Do NOT rotate it another 90 degrees.

## Material
Preferred Godot material:

`godot/M_SHINRAI_Road_Dry.tres`

It uses:
- Base Color: `SHINRAI_Road_FineAggregate_BaseColor_2K.png`
- ORM: `SHINRAI_Road_RealisticDry_ORM_2K.png`
  - R = Ambient Occlusion
  - G = Roughness
  - B = Metallic (black / non-metal)
- Normal: `SHINRAI_Road_RealisticDry_NormalGL_2K.png`

The OpenGL normal is the correct supplied normal for Godot.

## Dry crack-seal detail
The integrated project also includes a separate sparse repair layer:

`repairs/M_SHINRAI_CrackSeal.tres`

It uses a transparent 1K albedo, a very shallow OpenGL normal, and an ORM map
with 247/255 roughness and zero metallic. The six placements are fixed in
`scripts/town_main.gd`; they add no collision and consume no procedural RNG.

One isolated locked-street utility repair uses:

`repairs/M_SHINRAI_UtilityCut.tres`

It is a transparent visual-only decal with the same road aggregate, slightly
darker repair fill, a thin low-contrast seam, no raised rim and no wet response.

The locked-street manhole test uses:

`repairs/M_SHINRAI_ManholeCover.tres`
`repairs/M_SHINRAI_ManholeCut.tres`

The cover is 0.65 m across and the feathered asphalt cut is 0.94 m across. Both
are dry visual-only planes with no collision or procedural scatter.

The locked-street curb-edge repair test uses:

`repairs/M_SHINRAI_CurbEdgeRepair.tres`

Its visible strip is approximately 0.26 m x 2.07 m. The straight edge meets the
existing raised block edge while the opposite edge feathers into the road. It
adds no curb mesh, collision or procedural scatter.

## Physical curb and drain test
The first 5 m north-side test module uses:

`curb_drain/M_SHINRAI_CurbConcrete.tres`
`curb_drain/M_SHINRAI_DrainMetal.tres`
`curb_drain/M_SHINRAI_DrainBed.tres`

Its 0.15 m grated channel plus 0.20 m concrete transition exactly fills the
existing 0.35 m road-to-sidewalk gap. Five separate slab meshes and 55 grate
bars provide physical joints and open slots. It is visual-only pending approval.
For the dry night renderer, the concrete texture is multiplied by a cool-neutral
0.48/0.50/0.52 tint and uses 0.18 normal strength. The grate uses lifted warm
oxidized-metal values with 0.62 metallic and 0.68 roughness so its bars remain
readable against the recessed dark bed. No geometry values changed in v10.26x.

## Automatic scene setup
After Godot finishes importing the files:

1. Open `godot/build_shinrai_road_scene.gd`.
2. Use **File > Run** / run the EditorScript.
3. It creates:
   `godot/SHINRAI_Road_GameReady.tscn`
4. Instance that scene into the existing environment.

If the project has a different asset path, edit the `ROOT` constant in the
EditorScript and the texture paths in `M_SHINRAI_Road_Dry.tres`.

## Collision
For a static road, either use the project's existing collision workflow or:
1. Open the generated `SHINRAI_Road_GameReady.tscn`.
2. Run `godot/OPTIONAL_add_static_trimesh_collision.gd`.
3. Save the scene.

The visual mesh is only 3,072 triangles, so static trimesh collision is reasonable.
If the project has its own road collision system, use that instead.

## Texture import
Use the 4K textures as supplied. For 3D use, keep mipmaps enabled.

The normal map is OpenGL/X+ Y+ Z+. Do not invert its Y channel.
A DirectX copy is included only for other engines:
`SHINRAI_Road_Baked_NormalDX_4K.png`.

The 16-bit micro height map is included for optional parallax/displacement or rebaking.
Do not enable expensive height/parallax by default unless the existing build already uses it.

## Performance
Game-ready render mesh:
- 1,617 vertices
- 3,072 triangles
- 4K material maps

If 4K is too heavy for the target platform, downscale the texture set together to 2K.
Do not reduce only the normal map while keeping the masks/material at mismatched UV layouts.

## Source high-poly
`SOURCE_HIGH_POLY/` contains the final dense bake source:
- 886,657 vertices
- 1,769,472 triangles
- source heightfield NPZ
- GLB / PLY
- Blender reconstruction script
- final previews and metadata

Do not put the high-poly mesh into the runtime game scene.

## Reference
`REFERENCE/` contains the original concept sheet and close-up supplied for this road.
The concept shows wet lighting, but this delivered road intentionally remains DRY.

## Files to use in runtime
Minimum runtime set:
- `mesh/SHINRAI_Road_LP_Godot_YUp.glb`
- `textures/SHINRAI_Road_FineAggregate_BaseColor_2K.png`
- `textures/SHINRAI_Road_RealisticDry_ORM_2K.png`
- `textures/SHINRAI_Road_RealisticDry_NormalGL_2K.png`
- `godot/M_SHINRAI_Road_Dry.tres`

The procedural town also uses the optional repaired-pothole set:
- `repairs/SHINRAI_PotholeRepair_Albedo_1K.png`
- `repairs/SHINRAI_PotholeRepair_ORM_1K.png`
- `repairs/SHINRAI_PotholeRepair_NormalGL_1K.png`
- `repairs/M_SHINRAI_PotholeRepair.tres`

These are visual-only irregular decals. They do not add collision, change the
navigation surface, or consume procedural RNG draws.

Everything else is source, optional control data, or fallback.
