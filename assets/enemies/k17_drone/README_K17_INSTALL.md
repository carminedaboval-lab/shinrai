# K17 drone runtime asset folder

Copy the extracted contents of `ProjectShinrai_K17_Stage35_INGAME_STATIC_TEST.zip`
into this folder without flattening its internal directories. Keep the real
`.tscn`, `.glb`/`.gltf`, materials, textures, collision resources, LODs, and
all nine socket nodes together.

The game prefers a Godot scene because it preserves the authored hierarchy and
sockets. It also discovers nested K17 scene/model files automatically, so the
original package filenames may remain unchanged.

Do not place rendered preview images here as a substitute for the 3D scene or
model. The runtime loader accepts only `.tscn`, `.glb`, or `.gltf` visuals.

On launch, the console prints the exact production visual path that loaded. If
no real K17 asset is present, Godot emits a warning and retains the existing
development proxy instead of failing the project load.
