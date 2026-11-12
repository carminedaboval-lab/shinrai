# AKANE first-person arms

This Glock-only overlay derives from the player wardrobe arms. It has its own
mesh, bind transforms and grip data; the shared wardrobe arms are not replaced.
The hand geometry restores the MakeHuman donor palm and finger proportions,
with only a narrow transition at the existing forearm seam. Finger segment
lengths remain fixed. The pose uses separate MCP flexion and lateral motion,
parallel interphalangeal hinges, and contact fitting against the Glock and the
opposite hand. The thumb-web weights have a bounded smoothing pass; adjacent
finger webs, distal regions and the forearm seam retain their source weights.

`akane_grip_pose.gd` contains the final palm transforms, individual finger
transforms and arm-origin offsets as a preloaded constant dictionary, so the data
is included in exported builds. `akane_wardrobe_pose.gd` applies these during
aiming and blends the support hand into the existing reload animation. The
normal-map strength is reduced only on the hands/arms material.

## Asset credits

- Human mesh, male shape, UVs, source hand weights and skin: [MakeHuman / MPFB](https://github.com/makehumancommunity/mpfb2/tree/master/src/mpfb/data)
  and [MakeHuman system assets](https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html), CC0.
- Forearm geometry and relief: BodyParts3D, © The Database Center for Life
  Science, [CC BY-SA 2.1 Japan](https://creativecommons.org/licenses/by-sa/2.1/jp/).
  [Database](https://dbarchive.biosciencedbc.jp/en/bodyparts3d/desc.html) ·
  [Original paper](https://doi.org/10.1093/nar/gkn613).
- Fitted shirt: basic tucked T-shirt by Toigo, credited as MRT in the source,
  [MakeHuman Shirts 01](https://static.makehumancommunity.org/assets/assetpacks/shirts01.html), CC0.
- Inherited first-person skeleton binding and animation driver: [Ultimate FPS
  Animations by 1Matzh](https://sketchfab.com/3d-models/uzi-ultimate-fps-animations-73266e9f1eb949b69a3ab11d8f636048),
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The overlay carries
  newly fitted geometry and materials. Retain this attribution when distributing it.

## Fitting references

- [Griffin et al., Calibration and Mapping of a Human Hand for Dexterous Telemanipulation](https://bdml.stanford.edu/oldweb/touch/publications/griffin_asme00.pdf), section 3.1, for separate MCP flexion/abduction and parallel finger hinge axes.
- [Hahn et al.](https://pubmed.ncbi.nlm.nih.gov/8543884/) for measured finger-joint coupling. Fitting bounds and coupling values are modeling choices, not universal anatomical limits.
- [Chris Baker, How to Use a Semi-Automatic Pistol: Part 2](https://www.luckygunner.com/lounge/use-semi-automatic-pistol-part-2/) for the two-hand visual reference: support palm on exposed grip, fingers over the firing-hand fingers, firing thumb above the support hand.
