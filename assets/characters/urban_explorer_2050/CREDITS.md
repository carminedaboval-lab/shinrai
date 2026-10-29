Urban Explorer 2050 character and separate first-person sleeves
Audit date: 2026-10-09

Original character concept and Meshy output
The character concept was generated for this user request: a realistic light
tactical urban explorer in Japan, 2050. Meshy generated the character geometry,
textures and source humanoid rig; motion clips were added in Meshy's library.
Preserved original exports and reference prompts are in the parent task folder.
The derived world body and high-detail sleeves retain material from those files.
This provenance note does not independently establish account-specific Meshy
licensing rights or replace the service's applicable terms.

Existing first-person weapon, gloves, skeleton and animations
This work is based on "[UZI] Ultimate FPS Animations"
(https://sketchfab.com/3d-models/uzi-ultimate-fps-animations-73266e9f1eb949b69a3ab11d8f636048)
by 1Matzh (https://sketchfab.com/1Matzh) licensed under CC-BY-4.0
(http://creativecommons.org/licenses/by/4.0/).

The supplied project's assets/uzi/license.txt is preserved verbatim as
original_uzi_license.txt beside this note. Keep that attribution with a shared
or distributed build that uses the supplied rig, gloves or animations.

Modification description
The new Meshy-derived sleeve geometry was extracted and fitted to the existing
weapon rig using its weighted bind matrices. A small overlay contains the new
sleeves and named skin binds, without a copied weapon or copied motion clips.
At runtime it uses the existing skeleton and animations. The existing finger
and glove geometry remains intact because the Meshy hand retarget was not
accepted for weapon-contact quality. The original clothing, watch and exposed
forearm meshes are hidden only after successful binding of the new sleeves.
Do not describe this fallback as a completed new high-detail finger mesh.

The source assets/uzi/scene.gltf, scene.bin, textures and license are preserved.
Separate cheap-tier torso, arm and leg armour candidates have their own source,
derivative and validation files under ../armour_tier01. This note does not claim
that armour can currently be equipped or provides damage protection.
