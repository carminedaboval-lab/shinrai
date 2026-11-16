# Map 1 road-paint coverage

The road shader uses two shared, linear coverage-data textures. Missing paint exposes the existing asphalt. Stripe, centre, stop-line and crossing placement retain the original equations.

- `road_paint_coverage_light_bc7.res`: aggregate threshold at damage 0.
- `road_paint_coverage_heavy_bc7.res`: aggregate threshold at damage 1.
- Each texture is 2048 x 2048 BC7 with twelve mip levels, including the base. Each payload is 5,592,432 bytes; both total 11,184,864 bytes, approximately **10.67 MiB** before driver overhead. This is shared texture data, not a per-road allocation.
- These samplers must **omit `source_color`**. Their values are linear surface coverage, not display colour or transparency.
- Coverage holes are generated before float mipmaps, then quantized and compressed. Runtime code loads the resulting portable textures; it does not bake them.
- The existing aggregate PNG supplies luminance in linear space. Endpoint masks use `smoothstep(.014 + .006*d, .022 + .006*d, luminance)`. Mixing endpoints is an authored coverage mixture, rather than an exact intermediate nonlinear threshold.
- Fine coverage repeats over 12 metres. Coarser wheel abrasion repeats over 64 metres and is restricted to the known crossing's vehicle tracks. There is no camera-distance opacity switch.
- `traffic_wear_layout` stores corridor-centre magnitude in x and median half-width in y. A zero centre represents one shared narrow corridor; a negative centre disables traffic wear. Both ribbon surfaces carry it, including the surface without an edge line. Generic mouth/end patches retain the disabled default.

The data represents an artistic approximation of surface wear. BC7 is lossy. Sampled base mean absolute error was 0.34%/0.27%; worst per-mip mean coverage bias stayed below 0.37 percentage points. Heavy/light ordering reversals affected at most 0.83% of sampled fine pixels; none occurred from mip 4 onward. The bake audit must accompany replacements.

Validation used identical before/after cameras at 4 m and 10.5 m on the same crossing bars, overhead views, and edge-line reading at 15 m and 30 m. Plain-asphalt comparison PNGs were byte-identical. The two masks bound on 117 native street materials. A balanced ABBA test of a fixed 1920 x 1080 MSAA 4x crossing viewport measured median GPU cost 0.552 ms before and 0.622 ms after, with one draw and two triangles throughout. This is not a full-game performance measurement.

Provenance and detailed audits are retained in the collaboration workspace's `road_paint_scalar_coverage_bake/bake.json`. The source image is `res://assets/environment/roads/shinrai_road/textures/SHINRAI_Road_FineAggregate_BaseColor_2K.png`. Use the scalar coverage baker with an explicit output directory when regenerating; review the audit and fixed-camera comparisons before replacing either resource.

The self-contained regeneration tool is "res://tools/map_plan/bake_road_paint_coverage.gd". It defaults to a scratch user directory. Supply an explicit reviewed output folder through "--out=<folder>"; do not regenerate directly over accepted resources before checking its audit.
