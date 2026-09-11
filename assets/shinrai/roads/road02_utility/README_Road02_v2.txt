PROJECT SHINRAI — ROAD 02 v2 REAL-JAPAN REVISION

WHAT CHANGED AFTER CHECKING REAL JAPANESE STREETS

1. ROAD SURFACE
The v1 interpretation as sixteen separate stone slabs was too literal.
For this concept, a much better real-world match is Kyoto's stone-pattern water-retentive asphalt:
porous asphalt is filled with cement slurry and then cutter-scored to create a paving-stone appearance.

The v2 asset is therefore a continuous road body with an ashlar-style cutter pattern in the PBR height/normal maps.
This also performs better for procedural generation because there are no physical gaps between 1 m modules.

2. SURFACE DETAIL
The aggregate and pores are finer and more asphalt-like.
The v1 oversized volcanic pores were reduced.
Cracking is sparse rather than covering every block.
A separate wet mask still emphasizes low cuts, pores and repaired cracks for the rainy-night look.

3. REAL SEWER MANHOLE
A true human-entry Japanese sewer manhole is 600 mm-class.
JIS A 5506 covers sewer manholes with a 600 mm frame internal diameter.
The new Sewer600 module uses a full-scale cover with:
- ductile-iron style material
- flush frame/recess
- multidirectional raised grip
- three small lifting/key openings
- no invented 水 symbol

4. WATER UTILITY COVER
Small water covers are separate from sewer manholes.
The kit now includes a 220 mm WaterValve module marked:
止水栓
This is closer to the compact water shutoff/handhole covers visible in real Japanese alleys.

5. PROCEDURAL KIT
Godot-ready 1 m modules:
- Base_A
- Base_B
- Base_C
- Sewer600
- WaterValve220

All are:
- Y-up
- road surface Y=0
- normal +Y
- exact 1 m snap
- -colonly collision
- no curb

SOURCE TEXTURES
Road: 4K Base Color / Roughness / Normal / Height / AO / MetallicRoughness / WetMask
Sewer: 2K PBR
Water valve: 1K base / normal

The ready-made GLBs embed smaller copies for practical game import size.
Use the full-resolution source maps through the Blender generator for final-quality exports.
