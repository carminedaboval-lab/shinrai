# Project Shinrai — Light 02 v3 Concept-Matched

Runtime asset:
`ProjectShinrai_Light02_ConceptMatched_v3_GodotYUp.glb`

Role: selected warm eave/downlight on commercial storefronts, matching Light Type 02 in the Project Shinrai lighting concept sheet.

Integration contract:
- Godot Y-up; fixture hangs along -Y.
- identity root.
- `SOCKET_Mount`, `SOCKET_Light`, `SOCKET_Aim` retained.
- no embedded punctual light; the town generator owns the runtime `SpotLight3D` and charges it to the existing street-light cap.
- collision proxy exists in the source GLB but is disabled for the overhead town instances.
- concept-matched construction: black enamel bell shade, warm/cream enamel inner face, porcelain holder, exposed warm bulb, rolled rim, compact upper housing.
- supplied validation reports 80,448 triangles, so town use remains capped at three close-range fixtures.

The complete user-supplied source package is preserved under `source_package/`. A `.gdignore` keeps its duplicate authoring textures, previews, concept crop, and Blender script out of Godot's import scan; the runtime GLB already carries the textures needed by the fixture.
