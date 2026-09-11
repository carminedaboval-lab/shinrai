BLACKSITE ENEMY VISUAL SOCKET
=============================

The enemy AI no longer depends on a specific mesh.

Drop ONE production enemy scene/model here using one of these exact names:
  enemy.tscn   (preferred if you need scale/material/animation setup)
  enemy.glb
  enemy.gltf

The enemy script will automatically instance it under VisualRoot.

Visual conventions:
- Feet should be close to local Y = 0.
- Character should face local -Z in its neutral forward direction.
- Target visual height is about 1.75-1.90 m.
- Collision and navigation remain owned by scripts/enemy.gd.

The procedural tactical figure visible when no asset is present is a DEVELOPMENT
PROXY ONLY. It is intentionally separated from the AI and is not the intended
final art asset.
