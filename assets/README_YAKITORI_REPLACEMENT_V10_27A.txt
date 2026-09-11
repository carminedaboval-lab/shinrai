PROJECT SHINRAI — v10.27a Yakitori Building Replacement

INSTALL
1. Close Godot.
2. Back up the current project folder.
3. Extract this ZIP directly into the folder that contains project.godot.
4. Allow Windows to replace scripts/town_main.gd when prompted.
5. Open the project and run scenes/main.tscn normally.

Do not drag the Yakitori scene into main.tscn manually. The updated town script
installs it during deterministic generation.

EXPECTED RESULT
- The locked starting-street storefront is selected with the existing test logic.
- Its complete procedural building root is removed before street fixtures are built.
- The authored 4.20 m x 1.20 m x 3.60 m Yakitori shell is installed at scale 1.
- The authored entrance is aligned to the removed building's road threshold.
- The old roof, walls, interior, AC, pipes, utility boxes, façade props and collision
  are not retained behind the new building.
- The authored GLB collision remains active and the central entrance stays traversable.
- Two invisible anchor nodes preserve compatibility with the existing capped lighting.

SUCCESS MESSAGE IN GODOT OUTPUT
v10.27a authored Yakitori replacement: removed ... completely | installed ... | scale 1

SCOPE
This pass replaces one complete building only. It does not add the lantern, noren,
signage, AC, pipes, plants, furniture or new lights.

RUNTIME NOTE
Godot is unavailable in the build environment. The source, resources and archive
were statically validated; final visual placement must be confirmed in your runtime.
