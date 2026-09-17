# Midori Park modular path kit

User-supplied Meshy models staged on 2026-09-17 for the mainland path pass.

| Project file | Supplied file | Runtime normalization |
| --- | --- | --- |
| `midori_path_straight.glb` | `Meshy_AI_Sci_Fi_Pathway_0917104801_texture.glb` | 3 m width, 6 m length, 0.12 m thickness; source rotated onto XZ |
| `midori_path_curve.glb` | `Meshy_AI_Curved_Futuristic_Wal_0917104904_texture (1).glb` | 3 m connector width, approximately 7.4 m span, 0.12 m thickness |
| `midori_path_junction.glb` | `Meshy_AI_Triway_Junction_0917110519_texture.glb` | 3 m branch connectors, approximately 9 m footprint, 0.12 m thickness; source rotated onto XZ |
| `midori_path_resting_pocket.glb` | `Meshy_AI_Moonlit_Courtyard_0917112714_texture.glb` | approximately 7.2 x 8 m rest node, 0.12 m thickness; source rotated onto XZ |

The source meshes remain unchanged. `midori_park_size_blockout.gd` performs the reversible orientation, scale, grounding, collision, and cyan texture-mask emission pass at runtime. The existing blockout paths stay beneath phase one until the final circulation layout is approved.
