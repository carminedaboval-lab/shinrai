PROJECT SHINRAI — LIGHT 03 v1
UNDER-EAVE / SOFFIT RECESSED LED

TARGET
The small circular LED downlights that disappear into the wooden eaves in the new Project Shinrai artwork.

RESEARCH BASIS
This is modeled after the Japanese "軒下用ダウンライト" class rather than a generic puck.
A compact black DAIKO φ75 eave fixture provides a useful real product scale:
- 87 mm visible diameter
- 75 mm ceiling cutout
- 72 mm recess depth
- 3000 K
- 300 lm
- 50 degree beam
- 30 degree cutoff
- IP44 / rain-resistant eave use

Panasonic also specifically designs its eave-downlight families for condensation, wind/rain,
corrosion resistance, compact appearance, and thin/glareless trim.

ARTWORK MATCH
The LED optic colors are sampled directly from the supplied new artwork.
Trim sample RGB: [52, 23, 3]
LED median RGB: [250, 213, 134]
LED highlight RGB: [255, 232, 181]

GAME PLACEMENT
- Root / SOCKET_RoofPlane = underside surface of the eave.
- Hidden body recesses upward into the roof.
- Godot final orientation is Y-up.
- Runtime light points downward along -Y.
- SOCKET_Light is 6 mm below the roof plane to avoid self-clipping.
- SOCKET_Aim is directly below.
- HELPER_Cutout_75mm marks the real-world style cutout diameter.

STARTING GODOT LIGHT
SpotLight3D
Temperature: 3000 K
Lumens reference: ~300
Range: ~3 m
Spot angle: 50 degrees
Tune energy/exposure to the level.

MATERIALS
2K PBR:
- warm-black trim
- dark anti-glare baffle
- aluminium recessed body
- frosted warm LED optic + emission

The fixture deliberately has a very thin visible flange so repeated copies blend into timber soffits.
