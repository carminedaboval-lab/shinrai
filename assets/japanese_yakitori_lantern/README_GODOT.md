# Japanese Yakitori Paper Lantern — Godot 4 asset

## Primary file
`japanese_yakitori_lantern.glb` is the finished high-detail model. It is authored in meters, Y-up, with the front/lettering facing -Z. PBR textures are embedded in the GLB.

## Godot
Copy this whole folder to `res://assets/japanese_yakitori_lantern/`. You can drag the GLB directly into a scene, or instantiate `japanese_yakitori_lantern.tscn` for the included simple collision wrapper.

The GLB includes a warm point light using `KHR_lights_punctual`. If the importer does not create it in your Godot version, add an `OmniLight3D` at the model origin with a warm orange color (~2200 K), range ~2.5 m, shadows enabled.

## Materials/textures
- Red/orange washi base color, normal/fiber breakup, roughness, emissive glow
- Reference-traced vertical やきとり lettering baked into the washi textures
- Dark bamboo spiral rib material
- Aged blackened-steel base color, normal scratches/pitting, metallic/roughness

## Geometry
This is intentionally a high-detail hero asset rather than a low-poly prop. Paper rib deformation is modeled physically and the bamboo is a continuous spiral. The metal caps, rolled lips, rivets, hanger, and bottom ring are geometry.

## Suggested engine settings
Use Forward+ for the best real-time result. Keep the imported normal maps enabled. For Bloom-like glow in Godot 4, use WorldEnvironment/Environment glow if your renderer/settings support it.
