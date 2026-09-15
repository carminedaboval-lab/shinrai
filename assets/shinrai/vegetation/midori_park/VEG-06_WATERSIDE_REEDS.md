# VEG-06 — Waterside Reeds / Ornamental Sedge

## Purpose

Compact waterside vegetation for Midori Park: lake edges, ornamental water features, damp planting beds, and transitional planting between lawn/path areas and water.

This asset is intentionally generated as a single clean clump rather than a field of grass. It should read well at gameplay distance and remain cheap enough to instance repeatedly.

## Current gate

**Status: 2D reference image pending approval.**

Use Meshy's **Generate Image** option first. Do **not** run Image-to-3D until the generated image has been checked for a clean, connected silhouette.

## Generate Image prompt

```text
A single isolated compact clump of Japanese waterside reeds and ornamental sedge, containing 18 to 24 broad sturdy ribbon-shaped green blades growing radially from one connected root base, plus five taller reed stems with narrow seed heads. Varied heights, gentle natural curves, asymmetrical three-dimensional fountain silhouette. Photorealistic botanical studio product render on a perfectly plain light-gray background. Entire plant and root base visible with generous margins. Broad separated blades with clear gaps. No water, soil, pot, rocks, flowers, text, floating pieces, hair-thin grass, or cropped tips.
```

## What to approve in the 2D image

Choose the image with:

- one obvious connected root/base mass;
- broad, separated blades rather than hair-thin grass;
- visible gaps/negative space between blades;
- convincing front-to-back depth;
- an asymmetrical natural fountain silhouette;
- all blade and seed-head tips fully inside frame;
- no water, soil, pot, rocks, flowers, labels, or floating fragments.

Reject images where the center becomes an unreadable tangled knot. Meshy should be able to infer individual blades from the reference.

## Image-to-3D settings after approval

- **Detail:** High Detail
- **Textures:** Ultra 2K
- **Image Enhancement:** Off
- **Split:** Off
- **Triangle target:** approximately 4,000 if Meshy requests a target

Do not increase triangle count simply to preserve hair-thin detail. The broad-blade silhouette is the intended optimization strategy.

## Godot target

Proposed final names:

```text
SHINRAI_VEG06_WatersideReeds_A_GodotYUp.glb
VEG06_WatersideReeds_A.tscn
M_VEG06_WatersideReeds
```

Import expectations:

- Y-up, metres, base at local origin.
- No gameplay collision by default.
- Prefer a single material/surface if the Meshy output supports it cleanly.
- Verify the backside and interior of the clump; 2D-to-3D plant generation can produce hidden cavities or paper-thin artifacts.
- Preserve the original GLB before any optimization pass.

## Variant strategy

Do not generate several unrelated reed species immediately. First make one strong approved VEG-06 model, then derive visual variety through:

- Y rotation;
- small uniform scale variation;
- mild non-uniform width/height variation when it does not distort the blades;
- density variation from placement, not from duplicating geometry inside the source asset.

If a second authored variant is eventually required, create `VEG06_WatersideReeds_B` from the same visual language rather than changing species or material family.
