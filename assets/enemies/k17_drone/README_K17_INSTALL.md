# K17 drone runtime asset folder

The Stage 35 Godot scene uses absolute project resource paths rooted at
`res://assets/enemies/k17`.

From the extracted package, locate:

`godot_test/assets/enemies/k17`

Copy that entire `k17` folder into this game's `assets/enemies` directory so
the final path is:

`assets/enemies/k17`

Keep its real `.tscn`, `.glb`/`.gltf`, materials, 4K textures, collision
resources, LODs, and all nine socket nodes together. Do not flatten or rename
the files. The runtime prefers the Godot `.tscn` scene and never accepts a
rendered image as a model substitute.

On launch, the console prints the exact production visual path that loaded. If
no real K17 asset is present, Godot emits a warning and retains the existing
development proxy instead of failing the project load.
