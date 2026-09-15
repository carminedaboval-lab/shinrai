# SHINRAI — Midori Park Vegetation

This folder is the production home for the Midori Park vegetation kit.

The project is using a modular Meshy-to-Godot workflow because full plants with dense leaves and flowers are unreliable when generated as one object. The working rule is:

> **Meshy makes the pieces; Godot assembles the plant.**

No existing gameplay scene is changed by this folder. Vegetation assets should stay isolated here until an individual asset has been visually approved and imported cleanly.

## Current production state

- **Sakura family** — full tree plus a smaller flowering branch have been generated externally; final repository import is pending.
- **Bush family** — full bush plus a smaller branch/sprig have been generated externally; final repository import is pending.
- **VEG-06** — Japanese waterside reeds / ornamental sedge. Reference-image generation is the next step; do not spend Image-to-3D credits until the 2D silhouette has been approved. See `VEG-06_WATERSIDE_REEDS.md`.

The repository did not previously have a dedicated vegetation hierarchy, so this folder establishes one without touching `scripts/town_main.gd` or the current main scene.

## Standard production workflow

1. **Structure first** — generate the trunk, woody body, main branches, stems, or root mass as a clean connected object.
2. **Foliage separately** — generate a small reusable leafy sprig with clearly separated leaves and good depth.
3. **Flowers separately when needed** — use small blossom clusters rather than asking Meshy to solve a full flowering canopy.
4. **Import components as GLB** — preserve the original Meshy source export until the Godot version is validated.
5. **Assemble in Godot** — duplicate, rotate, scale, and place the approved modules to build the final plant.
6. **Create variants from the same family** — vary silhouette and density before generating entirely new species.
7. **Optimize only after approval** — merge static pieces or use instancing after the look is locked, not during the first visual pass.

## Godot import contract

The current project targets Godot 4.7 using the GL Compatibility renderer, so vegetation should be conservative about material count and transparency.

For every imported vegetation component:

- GLB format.
- Metres as the working unit.
- Y-up orientation.
- Root / planting point at or very near local origin.
- Whole mesh above the ground plane unless the asset intentionally includes a buried root plug.
- Connected geometry where practical; no floating fragments.
- Keep the authored Meshy textures with the source GLB for traceability.
- Prefer one material per logical component; avoid unnecessary duplicate surfaces.
- No collision on leaves, flowers, reeds, or small bushes unless gameplay specifically requires it.
- For tree trunks that need collision, use simple authored collision rather than trimesh collision on the full canopy.

If a later foliage asset uses alpha-cutout cards, prefer alpha scissor/cutout behavior over full transparent blending where the look allows it. This reduces sorting and overdraw problems in dense park scenes.

## Naming convention

Use stable production IDs even when the visible species name changes.

Example for VEG-06:

- Source GLB: `SHINRAI_VEG06_WatersideReeds_A_GodotYUp.glb`
- Packed scene: `VEG06_WatersideReeds_A.tscn`
- Material: `M_VEG06_WatersideReeds`
- Optional lower-detail variant: `SHINRAI_VEG06_WatersideReeds_A_LOD1_GodotYUp.glb`

For modular families, add a component suffix rather than inventing a new family ID, for example:

- `_Trunk_A`
- `_Branch_A`
- `_LeafSprig_A`
- `_BlossomCluster_A`

## Suggested asset folder shape

When an asset is ready to commit, keep the source and Godot-facing files together:

```text
midori_park/
  veg_06_waterside_reeds/
    SHINRAI_VEG06_WatersideReeds_A_GodotYUp.glb
    VEG06_WatersideReeds_A.tscn
    textures/
    README_GODOT.md
    asset_manifest.json
```

Do not add `.import` files manually. Let Godot regenerate them from the committed source assets.

## Performance rules for the park

- Spend geometry on silhouette, not hidden intersections.
- Keep small ground plants cheap enough to repeat many times.
- Reuse approved sprigs and blossom clusters instead of creating unique geometry for every copy.
- Use `MultiMeshInstance3D` or an equivalent batching strategy for large repeated beds of the same finished prop.
- Use a few authored variants with randomized rotation/scale before creating more species.
- Reduce shadow distance / shadow casting on dense small vegetation if it becomes a frame-time problem.
- Build LODs for hero trees before mass placement across the park.

## Approval gate

A vegetation asset is not considered game-ready until it passes all of these checks:

- Clean silhouette from several camera angles.
- No floating geometry or obvious generation fragments.
- Correct root/base placement.
- Textures survive Godot import without unexpected color or alpha issues.
- Reasonable triangle count for its screen size and repetition count.
- No accidental collision on foliage.
- At least one in-engine scale check next to the player/environment.

The first priority is quality and repeatability of the workflow; broad park placement comes after the core vegetation families are stable.
