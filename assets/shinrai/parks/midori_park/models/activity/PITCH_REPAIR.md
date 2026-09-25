# Five-a-side pitch repair

`meshy_five_a_side_football_pitch.glb` and its three original JPEGs are the supplied source. Keep them unchanged.

`meshy_five_a_side_pitch_clean.glb` is a derived version with the damaged outer net and detached skirt geometry removed. `repair_pitch_source.py` recreates it with Blender 5.2:

```
blender -b --python repair_pitch_source.py -- meshy_five_a_side_football_pitch.glb meshy_five_a_side_pitch_clean.glb
```

Godot imports the clean model, tones down its metallic material, and builds a new steel fence in `scripts/midori_pitch_fence.gd`. The fence uses 10.5 cm diamond openings, a solid kickboard over the source's low ragged trim, physical perimeter collision, and a 2.7 m north entrance. The original model has no usable gameplay collision, so the park scene provides a walkable pitch floor separately. The generated `_Image_*.jpg` files for the clean GLB are Godot import output and can be recreated from the embedded images.
