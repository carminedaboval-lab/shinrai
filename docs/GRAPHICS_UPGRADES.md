# Graphics upgrades: Unreal 5 features vs Godot 4.7

Shinrai runs on stock Godot 4.7.2 (Forward+). This page lists what Unreal 5 has that we didn't, what Godot can do about each one, and what has been switched on in `scripts/shinrai_graphics.gd` (autoload `ShinraiGraphics`).

## What the park used before this pass
Checked on 4.7.2 with a ClassDB/ProjectSettings dump. The presets live in `midori_park_size_blockout.gd` (`_apply_render_quality`).

- **AA and scaling:** TAA at native 1080p, bilinear scaling at 1.0, no MSAA. Mip bias +0.5.
- **GI:** none. Ambient light comes from the sky, plus SSAO on both presets and SSIL on High only. SDFGI, VoxelGI and LightmapGI are unused.
- **Reflections:** a cached lake ReflectionProbe (`UPDATE_ONCE`), sky reflections, and SSR on High only.
- **Shadows:** PSSM sun with 2 splits and 60 m on Balanced, 4 splits and 110 m on High. Engine defaults are a 4096 atlas and the "Low" soft filter. PCSS comes from `light_angular_distance` 0.6.
- **Fog:** depth fog with aerial perspective. Volumetric fog at night, and in daylight on High.
- **Tonemap and grade:** AgX at white 6.0, with a split-tone colour-correction ramp.
- **Camera:** player DOF only while aiming iron sights (`CameraAttributesPractical`). No auto exposure.
- **Sky:** a ProceduralSkyMaterial gradient plus a cloud dome (`midori_calm_clouds`).
- **LOD:** imported mesh LODs (threshold 1 on High, 4 on Balanced), visibility ranges on scatter, and per-chunk fade for the ground clumps. No occlusion culling. No compositor effects.
- **Filtering:** anisotropic samplers are used in about 50 shaders (ground, roads, paths), but the level was the engine default of 4x.

## Gap table

| Unreal 5 feature | Godot 4.7 option | Kind | Effort | Status here |
|---|---|---|---|---|
| **TSR** temporal upscaler / AA | **FSR 2.2** (`SCALING_3D_MODE_FSR2`) | native | setting | **done** |
| DLSS / XeSS / FSR 3.1+ | Not in 4.7. FSR 3.1 is an open engine PR (#111631). NVIDIA's RTX Godot fork (2026) is a fork. No maintained GDExtension found. | engine build | high | no |
| **Virtual shadow maps** | Bigger PSSM atlas (up to 16K), high soft filter, PCSS | native | setting | **done** (8K + High filter) |
| **Lumen GI** | SDFGI (dynamic, open world), VoxelGI (bounded), LightmapGI (baked), plus SSIL | native | setting / bake | SSIL widened, SDFGI measured (below) |
| **Lumen reflections** | SSR plus ReflectionProbes | native | setting | SSR widened to Balanced |
| **Nanite** | Auto mesh LOD (meshoptimizer), visibility ranges (HLOD), baked occluders. True virtual geometry needs an engine fork. | native / engine build | medium / very high | already used; occluders are a follow-up |
| **Contact shadows** | None built in. Possible as a CompositorEffect (depth ray-march toward the sun), but it can't split direct from ambient light. | compositor | medium-high | no (follow-up) |
| **Motion blur** (per object) | None built in. CompositorEffect addons exist, e.g. sphynx-owner's JFA motion blur (MIT). | addon / compositor | low-medium | no: an FPS default would be off anyway |
| **DOF** (cinematic, bokeh) | Native DOF with bokeh shape and quality settings | native | setting | already used for ADS |
| **Auto exposure** (eye adaptation) | `CameraAttributes.auto_exposure_*` | native | setting | measured (below); the bodycam mode will own its own |
| **Subsurface scattering** | `subsurf_scatter_*` and transmittance on BaseMaterial3D, screen-space SSS | native | per-material | already available; leaves use backlight |
| **Hair / groom** | No strand hair; use cards with alpha hash / anisotropy | asset | n/a | not needed (first person) |
| **Decals** | Native Decal node (albedo, normal, ORM, emission) | native | none | already used |
| **Water** | Custom shaders plus probes; no Water plugin equivalent | project shader | medium | lake shader exists |
| **Sky atmosphere** | ProceduralSky/PhysicalSky, or Sky3D addon (MIT, TokisanGames) | native / addon | low-medium | ProceduralSky kept: `_apply_time_of_day` assumes it |
| **Volumetric clouds** | Sky shader or compositor ray-march (clayjohn's demo, Sunshine Clouds 2) | addon / compositor | medium | cloud dome exists; follow-up |
| **Film grain, chromatic aberration, lens** | CompositorEffect | compositor | low | **owned by the bodycam plan**, not duplicated |
| Output dithering | `use_debanding` | native | setting | **done** |
| Anisotropic filtering | `anisotropic_filtering_level` | native | setting | **done** (16x) |

"Kind" key: *native* means a stock Godot setting or node. *addon* means a maintained third-party plugin with an MIT-compatible licence. *compositor* means a CompositorEffect we would write. *engine build* means a custom or forked Godot.
