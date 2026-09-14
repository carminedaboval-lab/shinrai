# Install the Yakitori Artwork Replica V5

This package is laid out to merge directly into the root of the SHINRAI Godot
project (the folder containing `project.godot`).

1. Close the running Godot project.
2. Extract this ZIP into the SHINRAI project root.
3. Allow the `assets` and `scripts` folders to merge, and replace
   `scripts/town_main.gd` when prompted.
4. Reopen the project and let Godot finish importing the V5 GLB and textures.
5. Run the normal main scene.

The town script now loads:

`res://assets/shinrai/buildings/yakitori_shop/artwork_replica_v5/ProjectShinrai_YakitoriShop_ArtworkReplica_v5.tscn`

V5 specifically removes the unintended wall-line geometry, closes the upper
roof-to-wall gap, and replaces the thick storefront canopy with a thin pitched
roof/flashing/soffit assembly. Signage, lanterns/noren, final glazing, and the
finished interior remain intentionally deferred.
