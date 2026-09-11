# Project Shinrai — Light 03 v1 Under-Eave LED

Runtime asset:
`ProjectShinrai_Light03_UnderEaveLED_v1_GodotYUp.glb`

Role: recessed under-eave / soffit LED for renovated and contemporary storefronts.

Integration contract:
- Godot Y-up.
- root / `SOCKET_RoofPlane` sits on the underside surface of the canopy or eave.
- recessed body extends along local `+Y` into the roof/eave.
- runtime beam points along local `-Y`.
- `SOCKET_Light` and `SOCKET_Aim` are retained.
- no embedded punctual light; `town_main.gd` owns the runtime `SpotLight3D` and charges it to `MAX_STREET_LIGHTS`.
- supplied scale: 87 mm visible outer diameter, 75 mm cutout, 72 mm recess depth.
- supplied lighting target: 3000 K, about 300 lm reference, 3 m range, 50 degree beam.
- supplied validation reports 23,640 triangles. Locked-road use is capped at two fixtures.

The complete user-supplied source package is preserved under `source_package/`. A `.gdignore` keeps authoring textures, previews, references and the Blender script out of Godot's import scan; the runtime GLB already embeds the textures it needs.
