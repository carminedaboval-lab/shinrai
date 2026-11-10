# Engine techniques for a bodycam camera and image in Godot 4 (4.3 to 4.7, Forward+)

Scope note: this file covers implementation techniques. Formulas and shader code under **Inferences** are my own derivations or standard formulas I did not fetch a source for this session. They are labelled. Treat every "starting value" as a tuning default, not a measured fact. Godot API names under Inferences that are not cited were written from memory of the 4.x API. Check them against the 4.7 class reference before relying on them.

---

## 1. Wide-angle / fisheye lens: models, overscan, source-FOV maths, Godot pipeline options, Panini

### Takeaway
Render a normal rectilinear Camera3D at a wider FOV than you need (overscan). Then run one full-screen pass that, for each output pixel, inverts a fisheye mapping (equidistant or equisolid works well) to get a view direction and projects that direction back into the rectilinear source. The required source FOV comes in closed form from the corner direction. It must stay well under 180 degrees, so a "true" 150+ degree diagonal look needs a lower-strength mapping or a mild Brown–Conrady barrel on top of a wide rectilinear source. In Godot the cleanest place for the pass is a `CompositorEffect` compute shader (HDR, before tonemap) or a `CanvasLayer` + `ColorRect` with `hint_screen_texture` (after tonemap, simpler).

### Cited Findings
- Fisheye mapping functions (r is image radius, f is focal length, θ is the angle from the optical axis): rectilinear r = f·tan θ (straight lines stay straight, θ < 90°); stereographic r = 2f·tan(θ/2) (preserves angles, edges compressed least); equidistant r = f·θ (preserves angular distance); equisolid r = 2f·sin(θ/2) (equal solid angle per area); orthographic r = f·sin θ (strong edge compression). — [Wikipedia: Fisheye lens](https://en.wikipedia.org/wiki/Fisheye_lens)
- Brown–Conrady model: xu = xd + (xd − xc)(K1 r² + K2 r⁴ + …) + tangential P1/P2 terms. Barrel distortion "typically will have a negative term for K1", pincushion a positive one. The division model xu = xc + (xd − xc)/(1 + K1 r² + K2 r⁴ …) handles strong distortion with fewer terms. "A single term is usually sufficient to model most cameras", and the single-term form has an analytic inverse. Inverting the general model has no analytic solution, so iterative solvers or approximations are used. — [Wikipedia: Distortion (optics)](https://en.wikipedia.org/wiki/Distortion_(optics))
- Lateral chromatic aberration can be reduced by warping R, G and B separately. Run in reverse, that tells you how to simulate it. — [Wikipedia: Distortion (optics)](https://en.wikipedia.org/wiki/Distortion_(optics))
- CompositorEffect basics (Godot 4.7 docs): `@tool extends CompositorEffect`; in `_init()` set `effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT` and `rd = RenderingServer.get_rendering_device()`; `_render_callback(p_effect_callback_type, p_render_data)` runs on the render thread every frame; `p_render_data.get_render_scene_buffers()` cast to `RenderSceneBuffersRD`; `get_internal_size()` is the 3D resolution before upscaling, since upscaling runs after post-processing; `get_color_layer(view)` is the colour image RID; loop over `get_view_count()`; dispatch `(size-1)/8+1` groups for an 8×8 local size; uniforms come through `UniformSetCacheRD.get_cache(shader, 0, [uniform])`; push constants are a `PackedFloat32Array` padded to a multiple of 4 floats. The compositor works only in Forward+ and Mobile and only at 3D pipeline stages. Runtime GLSL compilation is for prototyping; a `.glsl` file can be precompiled and cached. — [Godot docs: The Compositor](https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html)
- Screen reading in canvas_item shaders: `uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;` read with `SCREEN_UV`. The first node that uses it triggers one full-screen back-buffer copy that later nodes reuse; `BackBufferCopy` controls this. Use a mipmap filter if you need blurred LOD reads. In 3D spatial shaders the screen is copied once, after opaque and before transparent, so transparent objects are missing. That makes a spatial-quad approach worse than a 2D overlay for a final lens pass. — [Godot docs: Screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)
- Panini: Sharpless, Postle and German (2010) describe a "simple double projection of the sphere to the plane" that can render images 150° or more wide. The parameter d runs from 0 up: d = 0 is standard perspective, d = 1 is cylindrical stereographic, and d → ∞ tends towards cylindrical orthographic. — [Eurographics CAe 2010 paper](https://diglib.eg.org/handle/10.2312/COMPAESTH.COMPAESTH10.009-016); [Paul Bourke: Fisheye to Pannini](https://paulbourke.net/dome/fish2pannini)
- Bourke's forward Pannini mapping is h = S·sin(longitude), v = S·tan(latitude). He keeps horizontal FOV fixed while varying d (examples at 130° and 150°). — [Paul Bourke](https://paulbourke.net/dome/fish2pannini)
- The libpano13 general Pannini takes d ∈ [0, ∞) for horizontal compression and t, b ∈ [−1, 1] for top and bottom vertical squeeze. — [libpano13 PaniniGeneral.h](https://svnlliurexnet.gva.es/leia/mods-backports/trunk/libpano13/PaniniGeneral.h)
- Hugin's general Panini: max HFOV is 160° at compression 0, 320° at 100 and 180° at 150. Vertical squeeze keeps verticals straight and reduces horizontal-line curvature. Hard squeeze works up to about 160°. The resulting radial-line curvature "is typically unnoticeable at 130 degrees or less." — [Hugin manual: The General Panini Projection](https://hugin.sourceforge.io/docs/manual/The_General_Panini_Projection.html)

### Inferences
**Recommended model for a bodycam.** Real bodycams have strong barrel distortion with fairly straight lines near the centre. Two good options:
1. A blend between rectilinear and a fisheye mapping. Equidistant is the easiest to invert: θ = r_norm·θ_edge. Or use equisolid, θ = 2·asin(r/(2f)), which gives softer edge compression.
2. A rectilinear source plus a single-term division or Brown model. It is cheap and a small k is easy to art-direct, but it cannot reach real-fisheye angles without huge overscan.

Option 1 is better for the 140 to 160 degree diagonal look. A "strength" uniform `s ∈ [0,1]` can mix θ between the rectilinear and fisheye inverse, for example `θ = mix(atan(r·tanθe), r·θe, s)`. That gives one art-direction knob.

**Inverse-mapping algorithm, per output pixel (derived):**
```
// p = output pixel in normalised coords: x in [-1,1], y in [-1/aspect, 1/aspect]
r_out   = length(p);                 // 1.0 at the horizontal edge
phi     = atan(p.y, p.x);            // azimuth is preserved by radial lenses
theta   = g_inv(r_out * g(theta_h)); // theta_h = target horizontal half-FOV
// equidistant: g(t)=t, g_inv(r)=r ; equisolid: g(t)=2 sin(t/2), g_inv(r)=2 asin(r/2)
// stereographic: g(t)=2 tan(t/2), g_inv(r)=2 atan(r/2)
dir     = vec3(sin(theta)*cos(phi), sin(theta)*sin(phi), cos(theta)); // camera space, +z forward
src     = dir.xy / dir.z / tan(theta_src_h);  // rectilinear source, x in [-1,1]
uv      = vec2(src.x, src.y * aspect) * 0.5 + 0.5;  // flip y to match engine convention
if (any(lessThan(uv, 0)) || any(greaterThan(uv, 1)) || dir.z <= 0) -> black / vignette
```

**Required source FOV (derived).** Let a = width/height. The output corner sits at r_c = sqrt(1 + 1/a²), so θ_c = g_inv(r_c·g(θ_h)). The corner direction keeps its azimuth φ_c = atan(1/a), so its rectilinear x is tan θ_c·cos φ_c. No black corners needs **tan(θ_src_h) ≥ tan(θ_c) · a / sqrt(a² + 1)**. The source vertical half-FOV follows from tan(θ_src_v) = tan(θ_src_h)/a, the same aspect ratio. If you accept black or vignetted corners, which is very bodycam-like, size the source for the edge only: tan θ_src_h ≥ tan θ_h.
- *Worked example:* equidistant, 16:9, target HFOV 120° (θ_h = 60°). Then r_c = 1.147, θ_c = 68.8°, tan θ_c = 2.58, factor 0.872, tan θ_src_h = 2.25, so θ_src_h = 66.0°. **Source HFOV is about 132° and source VFOV about 103°.** Godot `Camera3D.fov` is the vertical FOV by default (`keep_aspect = KEEP_HEIGHT`, from memory; verify), so set `fov ≈ 103.4`.
- *Practical limit:* θ_c must stay below 90°. Above roughly 75° the source magnification (next point) gets bad. So for a fully filled 16:9 frame with rectilinear overscan, keep the target HFOV at or below about 130° (equidistant). Wider looks should let the corners go dark or shrink the strength.

**Centre resolution loss (derived).** Near the centre, output radius r maps to source radius r·θ_h/tan θ_src_h. In the example that is 1.047/2.25 ≈ 0.47, so the centre is magnified about 2.1× and looks soft. That suits a bodycam. To keep the centre crisp, raise `Viewport.scaling_3d_scale` above 1.0 (for example 1.3 to 1.5; cost grows roughly with scale²) or render the source into a larger SubViewport. Overscan costs nothing in pixel count. Only the resolution scale costs.

**Godot implementation options, ranked:**
1. **CompositorEffect compute (Forward+, Godot 4.3+).** Assign a `Compositor` resource with the effect to `WorldEnvironment.compositor` or `Camera3D.compositor` (property names from memory). The effect runs at `EFFECT_CALLBACK_TYPE_POST_TRANSPARENT`, which I believe comes before tonemap, glow and auto exposure, so the image is still linear HDR. A warp gathers from other pixels, so do not read and write the same image in one dispatch. First `rd.texture_copy` the colour layer into a persistent temp texture with matching format (recreate it on resize), bind that as a sampled texture with a linear sampler, and write the warped result back to `get_color_layer(view)` as a storage image. Note: Godot's glow, DOF and motion blur then run on the warped image. That is fine and arguably correct, because a real lens distorts before the sensor.
2. **CanvasLayer (high layer) + full-rect ColorRect with a canvas_item shader using `hint_screen_texture, filter_linear, repeat_disable`.** Simplest, and works in every renderer. It runs after tonemap, on LDR display values, and costs one full-screen copy. Put grain, compression and sharpening in the same or a later layer, since those belong in display space anyway. 2D UI then needs a higher CanvasLayer so it is not distorted, unless you want the HUD burned in.
3. **SubViewport source + TextureRect or ColorRect shader.** Needed for the frame-hold trick (section 6). It also makes overscan resolution explicit (`SubViewport.size = output × 1.3`).

**Panini as an alternative.** Panini keeps verticals straight and is "wide but undistorted-looking". It suits gameplay readability more than bodycam authenticity. A shader version can use h = S·sinλ, v = S·tanφ with S = (d+1)/(d+cosλ) (S is standard Sharpless form from memory; Bourke gives it only as an image). It inverts per pixel in closed form for the cylinder-to-sphere direction. Starting point: d = 0.5 to 1.0 at 120 to 130° HFOV. For the bodycam look, use a radial fisheye instead: real body cameras are radial lenses, so verticals bow.

**Starting values:** target HFOV 115 to 125° at 16:9; equidistant/rectilinear mix s = 0.6 to 0.8; or Brown k1 = −0.15 to −0.30, k2 = +0.02 to +0.05 in normalised coordinates on a source HFOV of about 110°.

### Gaps
- Real bodycam lens FOVs and mappings (for example Axon Body 3 or 4) were not researched here. Other researchers may cover them. I found no primary source on which fisheye mapping body cameras use.
- I did not fetch a source that states the exact compositor stage order relative to tonemap, glow and auto exposure. The "POST_TRANSPARENT is pre-tonemap HDR" claim comes from memory of 4.3+ behaviour.
- The Sharpless S formula was not verified against the paper text (Bourke shows it only as an image).

---

## 2. Chromatic aberration, vignette, sharpening, grain/sensor noise, black lift / highlight clipping

### Takeaway
Do chromatic aberration (CA) and vignetting inside the lens pass, using the per-pixel θ you already compute. Do sharpening, noise and the black/white transfer in display space, after tonemap, in that order. A cheap integer hash noise keyed to the held-frame index keeps grain in step with the low frame rate.

### Cited Findings
- Lateral CA comes from the R, G and B channels warping by different amounts, so warping them separately simulates it. — [Wikipedia: Distortion (optics)](https://en.wikipedia.org/wiki/Distortion_(optics))
- canvas_item screen reads support several samplers of the same screen texture with different filters (for example nearest and linear). Mipmap-filtered `textureLod` reads give a cheap blur, which helps for unsharp-mask blur or bloom-ish halation. — [Godot docs: Screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)

### Inferences
**Chromatic aberration (in the lens pass).** Compute θ per channel with a slightly different lens strength: `theta_c = theta * (1.0 + ca * vec3(+1, 0, -1))`. Alternatively scale the source radius per channel. Sample three times with linear filtering. Starting value `ca = 0.004 to 0.010`. Bodycam sensors with cheap plastic optics show visible purple/green fringing at the edges, so 0.008 is a good default. Weight it by r² so the centre stays clean.

**Vignette.** Natural optical falloff is roughly cos⁴θ (standard optics, not fetched). Use the lens θ you already have: `v = pow(cos(theta * vig_scale), 4.0)`, then `color *= mix(1.0, v, vig_amount)`. Start with `vig_amount = 0.6` and `vig_scale ≈ 1.0`. Add a hard mechanical corner cut (`smoothstep(r_c*0.98, r_c*1.02, r_out)` to black) if you want the "lens housing" look.

**Unsharp mask (display space, after any downscale):**
```glsl
vec3 c  = texture(scr, uv).rgb;
vec3 b  = (texture(scr, uv + vec2(px.x,0)).rgb + texture(scr, uv - vec2(px.x,0)).rgb
         + texture(scr, uv + vec2(0,px.y)).rgb + texture(scr, uv - vec2(0,px.y)).rgb) * 0.25;
vec3 sharp = c + amount * (c - b);              // amount 0.4 to 0.9; bodycams over-sharpen
sharp = clamp(sharp, min(c,b)-0.1, max(c,b)+0.1); // optional halo limiter
```
Do the sharpening on luma only so chroma does not ring: convert to YCbCr, sharpen Y, convert back. For the cheap "1-pixel halo" look of bodycam DSPs, use radius 1 px with amount 0.6 to 0.8. Run sharpening **before** compression blocking and grain, matching the camera DSP → encoder order.

**Sensor noise / grain.** Avoid `fract(sin(dot()))`, which shows patterns on some GPUs. Use an integer hash such as PCG on `uvec3(FRAGCOORD.xy, frame_index)`. Model:
```glsl
float n = (hash01(px, frame) + hash01(px, frame+7u) - 1.0);       // approx triangular, mean 0
float luma = dot(col, vec3(0.2126,0.7152,0.0722));
float sigma = grain_base * (1.0 + iso_gain) * mix(1.0, 0.3, sqrt(luma)); // more in shadows
col += n * sigma;                    // luma noise
col += (vec3(hash(px,frame+1u), hash(px,frame+2u), hash(px,frame+3u)) - 0.5) * sigma * chroma_noise;
```
Starting values: `grain_base = 0.02 to 0.035` in display units; `chroma_noise = 0.3 to 0.5`. Drive `iso_gain` from your exposure state (section 5) so dark scenes get grainier, as with real auto gain. Bodycam noise is blocky after compression, so generate the noise at half resolution (`floor(FRAGCOORD.xy/2)`) and let the compression pass smear it.

**Black lift / highlight clipping (display space):**
```glsl
col = max(col - black_crush, 0.0) / (1.0 - black_crush); // crush 0.01 to 0.03
col = col * (1.0 - lift) + lift;                          // lift 0.02 to 0.05 (milky shadows)
vec3 g = col * gain;                                      // gain 1.0 to 1.2
col = min(g, 1.0);                                        // hard sensor clip
float clip = smoothstep(0.85, 1.0, max(g.r, max(g.g, g.b)));
col = mix(col, vec3(1.0), clip * 0.6);                    // clipped areas go flat white
```
Set the Godot Environment tonemapper to Linear or a low-white Reinhard/Filmic so highlights actually clip, instead of ACES rolling them off. Disable `Viewport.use_debanding` (property from memory) if you want banding (section 4).

**Performance.** All of this is ALU-light. In one pass it costs 3 lens taps (CA), 4 to 5 sharpen taps and about 10 ALU ops for noise. That is far below 0.5 ms at 1080p on mid-range GPUs (estimate, not measured). Merge into as few passes as possible. Each extra canvas `hint_screen_texture` pass that needs the previous result needs a `BackBufferCopy`, which means another full-screen copy.

### Gaps
- No fetched source for cos⁴ vignetting or for PCG hashing in Godot. Both are standard.
- No measured timings for these effects in Godot.

---

## 3. Rolling shutter simulation

### Takeaway
A rolling-shutter sensor captures each row at its own time t(y) = t₀ + t_readout·y/h. For a game camera you can treat the effect as rotation-only. Per output row, rotate the view direction by −ω·Δt(row) before projecting into the source image. This fits straight into the fisheye inverse-mapping pass as one extra small rotation, so it costs close to nothing.

### Cited Findings
- Rolling-shutter row timing: t(i,y) = t_i + t_s·y/h, where y is the row and h the number of rows. The sign flips for bottom-to-top readout. — [USPTO patent, rolling shutter correction](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10771699)
- Each row sees the camera pose at its own time: rotation R(t) and translation p(t) are evaluated per row. Global-warp methods assume rotation is roughly constant during readout, which breaks under fast rotation. — [Toronto CS project report](https://www.cs.toronto.edu/~lindell/teaching/2529/past_projects/2025/report/prashanth-shyamala.pdf)
- The warp can be computed per row or at vertical subdivisions to save cost, and is easy to do on GPU with a vertex shader warp plus fragment resampling. — [USPTO patent 9554045](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9554045)
- NVIDIA Omniverse models rolling shutter as a per-pixel shutter-time offset where rows expose at the same instant and later rows are offset by a constant step. — [NVIDIA Omniverse cameras docs](https://docs.omniverse.nvidia.com/materials-and-rendering/latest/cameras.html)

### Inferences
**Angular velocity on the CPU.** In `_process` (render rate, not physics), get `q_prev` and `q_cur` from the camera's global basis. Compute `dq = q_prev.inverse() * q_cur`, then `ω = dq.get_axis() * dq.get_angle() / delta` in camera-local space. Smooth it slightly (exp decay, λ ≈ 30 /s) to avoid frame-to-frame spikes. Pass it as a push constant or uniform. Translation rolling shutter (parallax) is negligible except for very close objects. Ignore it.

**Shader (inside the lens pass, after computing `dir` in camera space):**
```glsl
float row = uv_out.y;                       // 0 top .. 1 bottom (output = sensor rows)
float dt  = (row - 0.5) * readout_time;     // centre row = "now", so the image does not shift overall
vec3  a   = -omega_cam * dt * rs_strength;  // small-angle rotation vector
dir = dir + cross(a, dir);                  // first-order Rodrigues; fine for |a| < ~0.1 rad
dir = normalize(dir);
// ...then project dir into the rectilinear source as in section 1
```
Fast yaw gives skewed verticals ("jello lean"). Fast roll gives a curved horizon. Pitch gives vertical squash or stretch. The timing uses the **output** (distorted) row, because the sensor sits behind the lens. That is the main reason to fuse this into the fisheye pass.

**Starting values.** `readout_time = 0.015 to 0.030 s` (cheap CMOS at 30 fps, my estimate; see Gaps). `rs_strength = 1.0`; exaggerate to 1.5 to 2 for readability. The skew pushes samples outside the source, so add about 5° of extra source FOV margin.

**Cheaper alternative** for a non-fisheye pipeline: a horizontal shear `uv.x += (row-0.5) * omega_yaw * readout_time * f_px / width`, where `f_px = (H/2)/tan(fov_v/2)`.

**Interaction with frame hold.** With a 30 fps frame hold (section 6), compute ω over the held interval (`dq` between held frames, divided by 1/30 s). Only update the effect when a new frame is captured.

### Gaps
- No primary source found for typical bodycam sensor readout times. The 15 to 30 ms figure is an estimate.
- I found no Godot-specific rolling-shutter shader or tutorial. The code above is a derivation from the cited models.

---

## 4. Video compression look (block DCT, macroblocks, chroma subsampling, banding, keyframe pumping)

### Takeaway
A true 8×8 DCT → quantise → IDCT runs naturally as a compute shader, one 8×8 workgroup per block with shared memory, so it fits in a `CompositorEffect`. It is the most expensive effect in a typical stack, but still cheap in absolute terms if done separably. Cheaper fragment approximations (detail-adaptive block averaging, 4:2:0 chroma sampled per 2×2 block, luma posterisation) give 80% of the look. "Keyframe pumping" and motion-starved bitrate are best faked by modulating quantiser quality over time and with camera angular speed.

### Cited Findings
- Pipeline: forward DCT per 8×8 block (64 px → 64 coefficients, 1 DC and 63 AC), quantise (high frequencies → 0 at low quality), inverse DCT, optional 4:2:0 chroma subsample (colour smear), optional deblock filter. "A thread group maps naturally onto an 8×8 block" with shared memory. Skipping deblocking "looks like a mosaic". It is described as "the most expensive effect in a typical stack". Fast motion gives "a smear of melting blocks". — [StraySpark: Compression artifacts explained (DCT compute shader)](https://www.strayspark.studio/blog/compression-artifacts-explained-dct-compute-shader)
- Godot Retro shader pack includes a "Jpeg Compression" shader ported from paniq's ShaderToy. It is a ready Godot starting point. — [awesome.ecosyste.ms: godotretro](https://awesome.ecosyste.ms/projects/github.com%2Fahopness%2Fgodotretro)
- A Godot forum user trying to port a GLSL DCT ran into texture-binding problems in Godot's shader language. The thread had no accepted solution. — [Godot Forum: Implementing DCT shader in Godot](https://forum.godotengine.org/t/implementing-dct-shader-in-godot/142612)
- CompositorEffect compute dispatch with 8×8 local size and `UniformSetCacheRD` (see section 1). — [Godot docs: The Compositor](https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html)

### Inferences
**True DCT, compute version (Godot 4.3+ CompositorEffect, `local_size_x = 8, local_size_y = 8`).** The math is the standard JPEG DCT-II (not fetched): F(u,v) = ¼·C(u)C(v)·Σₓ Σᵧ f(x,y)·cos((2x+1)uπ/16)·cos((2y+1)vπ/16), with C(0) = 1/√2 and C(k>0) = 1. Steps:
1. Each thread loads one pixel, converts to YCbCr (BT.601: Y = 0.299R + 0.587G + 0.114B; Cb = 0.564(B−Y); Cr = 0.713(R−Y)), subtracts 0.5 and writes to `shared float blk[3][8][8]`. Then `barrier()`.
2. Row 1-D DCT (8 MACs per thread), `barrier()`, then column 1-D DCT (8 MACs). The separable form costs 16 MACs per pixel per channel instead of 64.
3. Quantise: `F = round(F / (Q[u][v] * qscale)) * (Q[u][v] * qscale)`. Use a larger qscale (2 to 3×) for chroma.
4. Inverse: column IDCT, then row IDCT (16 MACs). Convert back to RGB and write.

The total is about 32 MACs per pixel per channel plus 4 barriers, a fraction of a millisecond at 1080p on a modern GPU (estimate). Precompute the 8×8 cosine table as a `const float` array.

Standard JPEG luminance table (Annex K, from memory; verify), row-major:
`16 11 10 16 24 40 51 61 / 12 12 14 19 26 58 60 55 / 14 13 16 24 40 57 69 56 / 14 17 22 29 51 87 80 62 / 18 22 37 56 68 109 103 77 / 24 35 55 64 81 104 113 92 / 49 64 78 87 103 121 120 101 / 72 92 95 98 112 100 103 99`. These values are on a 0 to 255 scale, so divide by 255 when working in 0 to 1. IJG quality scaling: S = 5000/Q for Q < 50, else 200 − 2Q; table = floor((S·T + 50)/100), clamped to ≥ 1. Bodycam-like starting quality is Q ≈ 35 to 55 luma and ≈ 20 to 35 chroma. MPEG/H.264 use 16×16 macroblocks and 4×4/8×8 integer transforms. For "H.264 look", 8×8 with occasional 16×16 flat blocks in low-detail regions reads correctly.

**Where to run it.** It must run on display-referred values, after tonemap. A CompositorEffect at POST_TRANSPARENT runs before tonemap (see Gap 1), so either:
- (a) render the world in a SubViewport and run the compute pass with `RenderingDevice` on that viewport's texture from a script, or
- (b) apply a manual tonemap and its inverse around it (messy), or
- (c) use the fragment approximation in the final CanvasLayer.

For a first implementation, (c) is recommended.

**Cheap fragment approximation (one canvas pass, about 6 to 10 taps):**
```glsl
vec2 blk  = floor(FRAGCOORD.xy / 8.0);
vec2 bc   = (blk * 8.0 + 4.0) / screen_px;            // block centre UV
vec3 mean = textureLod(scr_mip, bc, 3.0).rgb;          // 8x8 average via mip level 3 (filter_linear_mipmap)
vec3 c    = texture(scr, uv).rgb;
float detail = length(c - mean);
// detail-adaptive quantisation: flat blocks collapse to the mean, detailed blocks keep edges but get posterised
float q = qscale * mix(1.0, 0.35, smoothstep(0.02, 0.15, detail));
vec3 ycc = rgb2ycc(mix(mean, c, 1.0 - q));
// 4:2:0 chroma: take chroma from the 2x2 (or 4x4 for harsher) block centre
vec2 cuv = (floor(FRAGCOORD.xy / 2.0) * 2.0 + 1.0) / screen_px;
ycc.yz = rgb2ycc(texture(scr, cuv).rgb).yz;
ycc.x  = floor(ycc.x * levels + 0.5) / levels;          // banding: levels 48 to 96 (8-bit is 255)
col = ycc2rgb(ycc);
```
Mip-based block means only line up with an 8-pixel grid if the screen texture's mip chain does. That holds for power-of-two-aligned blocks at LOD 3. Expect some misalignment at odd resolutions; an explicit 4-tap mean is safer.

**Banding.** Quantise luma in gamma space to 48 to 96 levels without dither. Concentrate it in smooth gradients (skies, walls) by multiplying `levels` by `mix(0.6, 1.0, detail_mask)`. Turn off Godot's debanding.

**Keyframe pumping / bitrate starvation (time modulation):**
```
gop_phase = fract(time / gop_length)            // gop_length 1.0 to 2.0 s
q_time    = mix(q_iframe, q_pframe, smoothstep(0.0, 0.25, gop_phase))  // sharp right after the I-frame, then degrades
q_motion  = 1.0 + motion_k * clamp(|omega| / 3.0, 0, 1)                // fast pans starve bitrate
qscale    = base_q * q_time * q_motion
```
Starting values: `q_iframe = 0.7`, `q_pframe = 1.3`, `motion_k = 1.5`. For P-frame smear, keep a history texture (SubViewport or compute image). During fast motion blend 10 to 30% of the previous output, block-aligned. Real codecs carry residual blocks forward, so smear per 8×8 block, not per pixel.

**Performance.** The fragment approximation is about 10 texture taps in one pass, negligible. A true per-pixel DCT in a fragment shader needs intermediate storage (4 separable passes chained through BackBufferCopy or SubViewports). A single-pass naive version costs 64 taps per coefficient and should be avoided. Compute plus shared memory is the right tool for the real thing.

### Gaps
- No timings were found for any DCT shader in Godot.
- The JPEG table and IJG scaling come from memory and were not fetched. Verify against ITU-T T.81 Annex K or libjpeg source.
- No source covers simulating GOP/keyframe pumping in real-time games. The approach above is my design.

---

## 5. Auto exposure with lag (CameraAttributesPractical / Physical)

### Takeaway
Godot's built-in auto exposure (Forward+ only) gives exponential adaptation with `auto_exposure_speed` and target brightness via `auto_exposure_scale`, clamped by min/max ISO in `CameraAttributesPractical`. It does not overshoot. For bodycam "pumping" (an overshoot, then settle) and blown windows, combine a slow-ish built-in AE with a hard-clipping tonemapper and an optional scripted underdamped spring on `exposure_multiplier`.

### Cited Findings
- `CameraAttributes.auto_exposure_enabled` (default false) turns on tonemapping auto exposure, Forward+ only. `auto_exposure_scale` (default 0.4) "Affects the intensity of auto exposure". `auto_exposure_speed` (default 0.5) "Affects the time needed for the camera to perform auto exposure". `exposure_multiplier` (default 1.0) scales exposure. `exposure_sensitivity` (default 100 ISO): with AE on, doubling it raises EV100 by one stop, acting as exposure compensation; available only with `rendering/lights_and_shadows/use_physical_light_units`. — [Godot docs: CameraAttributes](https://docs.godotengine.org/en/latest/classes/class_cameraattributes.html)
- `CameraAttributesPractical.auto_exposure_max_sensitivity` (default 800 ISO) limits how bright AE can push dark scenes. `auto_exposure_min_sensitivity` (default 0) limits how far it darkens bright scenes. AE works from the scene's average luminance and is Forward+ only (not Mobile or Compatibility). — [Godot docs: CameraAttributesPractical](https://docs.godotengine.org/en/latest/classes/class_cameraattributespractical.html)

### Inferences
**Starting setup (`CameraAttributesPractical` on Camera3D or WorldEnvironment):**
- `auto_exposure_enabled = true`
- `auto_exposure_speed = 0.8 to 1.2`. Faster than the default 0.5, so walking from interior to daylight visibly blows out for about 1 s and then recovers. Bodycams adapt in roughly 0.5 to 1.5 s (estimate).
- `auto_exposure_scale = 0.35 to 0.45`
- `auto_exposure_min_sensitivity = 50`, `auto_exposure_max_sensitivity = 1600 to 3200`. A high max lets night scenes brighten; pair it with heavy grain driven by the implied gain.

**To get blown highlights:** use a Linear tonemapper (or Filmic/Reinhard with `tonemap_white` about 1.0 to 2.0), since ACES rolls off too gracefully. Put strong emissive or sun values on windows and skies so their luminance is several stops above the interior average, and the AE (an average metering) leaves them clipped. Add Environment glow with `glow_hdr_threshold ≈ 1.0` for sensor bloom around clipped areas.

**Pumping with overshoot (optional, scripted).** The built-in AE gives no luminance readback to script (I found no API). Estimate it yourself: render a 16×16 or 32×32 SubViewport from the same camera at `UPDATE_ALWAYS` every N frames and read back with `get_texture().get_image()`. The GPU→CPU stall is small at that size but not free; read every 4 to 8 frames. Or run a reduction in the CompositorEffect into a small buffer and read it with `rd.buffer_get_data` (it syncs). Feed log2(lum) into an underdamped spring (ζ ≈ 0.5, ω ≈ 4 to 6 rad/s) and set `exposure_multiplier = 2^(target_ev − spring_ev)` with built-in AE off. This also gives an `iso_gain` value to drive grain (section 2).

**Performance.** Built-in AE is one luminance reduction per frame, negligible.

### Gaps
- The docs don't state exactly how `auto_exposure_scale` maps to target luminance (middle grey), or what the time constant of `auto_exposure_speed` is. Tuning has to be empirical.
- I found no API for reading the current auto-exposure value from GDScript.

---

## 6. Low frame-rate look (frame hold) without touching simulation

### Takeaway
Render the 3D world into a `SubViewport` and drive it manually. Keep it on `UPDATE_DISABLED` and set `UPDATE_ONCE` at 30 Hz from a timer accumulator in `_process`. Show its texture full-screen with the lens/compression shader. Physics, input and audio keep running at full rate, and the GPU does less work. Do not use `Engine.max_fps`, which slows input sampling and the main loop.

### Cited Findings
- `SubViewport.render_target_update_mode` values: `UPDATE_DISABLED` (0) "Do not update the render target"; `UPDATE_ONCE` (1) "Update the render target once, then switch to UPDATE_DISABLED"; `UPDATE_WHEN_VISIBLE` (2, default); `UPDATE_WHEN_PARENT_VISIBLE` (3); `UPDATE_ALWAYS` (4). `size` must be at least 2 px; it cannot be set manually under a stretching SubViewportContainer. — [Godot docs: SubViewport](https://docs.godotengine.org/en/stable/classes/class_subviewport.html)

### Inferences
**Script sketch (GDScript, Godot 4.x):**
```gdscript
@export var capture_hz := 30.0
var _acc := 0.0
var held_frame_index := 0
func _process(delta: float) -> void:
    _acc += delta
    var period := 1.0 / capture_hz
    if _acc >= period:
        _acc = fmod(_acc, period)        # keep phase; avoid drift
        $WorldView.render_target_update_mode = SubViewport.UPDATE_ONCE
        held_frame_index += 1            # push to shaders: grain seed, rolling-shutter omega, GOP phase
```
Put a `Camera3D` inside the SubViewport that copies the gameplay camera's `global_transform` each frame, or set `world_3d` to share the main world. Display through a `TextureRect` or `ColorRect` with `ViewportTexture`. Your lens shader then samples a normal texture, so no `hint_screen_texture` is needed.

**Jitter.** Set capture times on an exact 1/30 s grid. If the display runs at 60, 120 or 144 Hz, 30 fps divides 60 and 120 cleanly; at 144 Hz expect uneven 4/5-frame cadence, which actually reads as authentic. Add ±2 ms random jitter to `period` if you want encoder-ish judder.

**Interactions.** Disable TAA motion-vector reliance or accept some smear, since TAA history runs per rendered frame. Godot's motion blur is not built in for 4.x Forward+ to my knowledge. Grain, rolling shutter and GOP phase should advance only on held frames. The viewmodel and arms must be inside the same SubViewport so they are held too. The HUD, if any, stays at full rate outside.

**Performance.** The world renders at 30 Hz, about half the GPU cost of 60. The display pass runs at full refresh but is cheap.

### Gaps
- I did not verify whether a SubViewport sharing `world_3d` with the root viewport duplicates shadow-map and GI updates. Profile it, or render only in the SubViewport and turn the root 3D off (`Viewport.disable_3d` on the root, or don't put a Camera3D there).

---

## 7. Procedural camera motion: bob, springs, chest-mount lag, strafe roll, noise drift, frame-rate-independent smoothing, trauma shake

### Takeaway
Build the bodycam transform as a stack: body yaw (lags the aim) × chest-mount offset × footstep bob (phase-locked to distance travelled) × spring-filtered impacts × trauma noise. Use exponential decay or critically damped springs for every smoothing step so behaviour does not depend on frame rate. Shake is trauma² × noise, with trauma decaying linearly (Eiserloh, GDC 2016).

### Cited Findings
- Squirrel Eiserloh's GDC 2016 talk "Math for Game Programmers: Juicing Your Cameras With Math" (SMU Guildhall) covers screen shake and camera-behaviour math. — [GDC Vault listing](https://gdcvault.com/play/1023146/contactUs)
- Trauma model as implemented from the talk: gameplay adds trauma in [0,1], trauma decays linearly, shake magnitude = trauma raised to an exponent so small hits register less; the "trauma" 0 to 1 float and the use of Perlin noise come from this talk. — [StraySpark Godot camera docs: Noise and shake](https://www.strayspark.studio/docs/godot-camera-system/noise-and-shake); [baratgabor Unity3D-PerlinCameraShake](https://github.com/baratgabor/Unity3D-PerlinCameraShake)
- Separate noise offsets per axis (for example noise(t+100) for x, noise(t+200) for y), as in Bevy's official example that follows the talk. — [Bevy 2D screen shake example](https://bevy.org/examples/camera/2d-screen-shake/)
- Perlin noise feels noticeably better than plain random numbers for shake. — [baratgabor Unity3D-PerlinCameraShake](https://github.com/baratgabor/Unity3D-PerlinCameraShake)

### Inferences
**Frame-rate-independent smoothing (standard formulas):**
- Exp decay: `x = lerp(x, target, 1.0 - exp(-lambda * delta))`, with `lambda = ln(2) / half_life`. In Godot: `x = lerpf(x, target, 1.0 - exp(-lambda * delta))`; for rotations use `Basis.slerp` or `Quaternion.slerp` with the same weight.
- Critically damped spring, semi-implicit Euler (stable for ω·dt < ~0.5; otherwise substep or use the closed form from Daniel Holden's "Spring-It-On", not fetched):
  `v += (-2.0*zeta*omega*v - omega*omega*(x - target)) * dt;  x += v * dt;` with `zeta = 1` for critical damping, `omega = 2π·f_natural`.
  Recommended: impacts and recoil ζ = 0.5 to 0.7 (some overshoot), body lag ζ = 1.0, ω = 8 to 14 rad/s.

**Footstep-synced bob (chest mount):**
```
phase += horizontal_speed / stride_length * PI * delta   // one step per half cycle; stride_length about 0.75 m walk, 1.0 m run
bob_y    = -A_v * abs(sin(phase))          // dip at each footfall (abs sin gives two dips per cycle)
bob_x    =  A_h * sin(phase)               // side-to-side, one sway per stride pair
bob_roll =  A_r * sin(phase)
bob_pitch=  A_p * abs(cos(phase))
amp      = smoothstep(0.2, 1.5, speed)     // fade in with speed
```
Starting values (chest mount moves more than eyes, which the brain stabilises): walk A_v = 0.015 to 0.025 m, A_h = 0.010 to 0.015 m, A_r = 0.6 to 1.0°, A_p = 0.4°; sprint ×1.8 to 2.2. Fire footstep sounds when `abs(sin(phase))` crosses zero, keeping audio and visuals in step. If a full-body animation drives the chest bone (section 9), most bob comes free from the animation. Add only a filtered residual.

**Chest-mount lag behind look direction.** The bodycam is mounted on the torso, so camera yaw is the **body** yaw, not the aim yaw. Keep `aim_yaw` and `aim_pitch` (mouse) separate from `body_yaw`. Spring `body_yaw` towards `aim_yaw` (ζ = 1, ω ≈ 6 to 10), with a hard limit `|aim_yaw − body_yaw| ≤ 25 to 35°` (push the body when exceeded). Camera pitch follows aim pitch at about 0.4 to 0.6 of its amount, since torsos bend less than heads, and also lags. That is the core "bodycam, not head-cam" feel. It overlaps with the weapon deadzone (section 8).

**Strafe roll:** `target_roll = -roll_per_mps * local_velocity.x` with `roll_per_mps ≈ 0.4 to 0.8°/(m/s)`, clamp ±3°, exp-decay half-life 0.12 s. Add a yaw-rate roll (lean into turns): `-0.02 × yaw_rate_deg_s`, clamp ±2°.

**Idle drift (breathing and sway).** Godot 4 replaced OpenSimplexNoise with `FastNoiseLite` (noise types include Simplex/OpenSimplex2 and Perlin; from memory of the 4.x API). Use one FastNoiseLite with `frequency = 1.0` and sample `get_noise_1d(t * f + axis_offset)` per axis. Idle pitch/yaw amplitude 0.3 to 0.6° at f ≈ 0.15 to 0.3 Hz, plus breathing `0.004 m × sin(2π·0.25·t)` vertical. Scale ×2 to 3 after sprinting (fatigue value decaying over 5 to 10 s).

**Trauma shake (Eiserloh-style):**
```gdscript
trauma = max(trauma - trauma_decay * delta, 0.0)       # trauma_decay ≈ 0.8 to 1.5 /s
var s := trauma * trauma                               # or pow(trauma, 3) for more contrast
var t := Time.get_ticks_msec() * 0.001 * shake_freq    # shake_freq ≈ 15 to 25 Hz for impacts
rot_offset = Vector3(max_pitch * s * noise.get_noise_1d(t),
                     max_yaw   * s * noise.get_noise_1d(t + 100.0),
                     max_roll  * s * noise.get_noise_1d(t + 200.0))
```
Starting values for a bodycam: max_pitch = max_yaw = 3 to 4°, max_roll = 5 to 6°. Use small translational shake (≤ 1 cm) since rotation dominates on a strapped camera. Add trauma for gunshots (own: 0.15 to 0.25; nearby explosion: 0.6 to 1.0) and hard landings (0.3 to 0.5).

**Order of application.** body_yaw/pitch → mount offset (chest at about 1.35 m height, 0.12 m forward of the spine) → bob → impact springs → shake → final camera. Keep everything in `_process` (render rate) and interpolate physics-body positions (Godot 4.3+ has physics interpolation for 3D, `physics/common/physics_interpolation`, from memory). Otherwise the camera judders against a 60 Hz physics character.

### Gaps
- I did not access Eiserloh's slides or video directly. The trauma details come from third-party implementations citing the talk.
- The spring closed-form and Holden reference were not fetched.
- No measured data on real chest-mounted camera motion amplitudes. The values above are estimates.

---

## 8. Free aim / weapon deadzone, weapon sway/inertia, procedural recoil

### Takeaway
Treat the aim direction as a state separate from the camera. Mouse input moves the aim inside an elliptical deadzone around the screen centre. Once it reaches the edge, the camera (body) yaws and pitches. The weapon's transform comes from the aim, plus spring-driven sway (lagging mouse velocity and body motion), plus recoil impulses into springs. With no crosshair, the true muzzle direction must come from the weapon, not the screen centre.

### Cited Findings
- No primary source fetched this session is specific to free-aim deadzones. The spring and trauma sources in section 7 apply to sway and recoil. — [StraySpark Godot camera docs](https://www.strayspark.studio/docs/godot-camera-system/noise-and-shake)

### Inferences
**Deadzone (angles relative to the camera/body):**
```
aim_off += mouse_delta * sens                     // aim offset from camera forward, in degrees
// elliptical deadzone of half-extents (dz_x, dz_y)
e = length(aim_off / vec2(dz_x, dz_y))
if e > 1:
    excess  = aim_off - aim_off / e               // part beyond the ellipse
    cam_yaw += excess.x;  cam_pitch += excess.y   // push the camera
    aim_off -= excess
// soft recentre while moving: aim_off = lerp(aim_off, 0, 1 - exp(-k*delta)), k ≈ 1 to 3 when walking, 0 when still
```
Starting values: dz_x = 6 to 10°, dz_y = 4 to 6°. Use smaller values (2 to 4°) or 0 when aiming down sights. For a pure bodycam camera, also run the chest-lag spring from section 7 on cam_yaw so even the "pushed" camera follows smoothly.

**Weapon sway / inertia (spring per axis, in weapon-local space):**
- Input: `target_sway = -mouse_velocity * sway_gain` (gain about 0.02 to 0.04°/(deg/s)), clamp ±4°. Add `-body_accel * 0.002` m for positional inertia.
- Spring with ζ = 0.6, ω = 10 to 12 rad/s on rotation; ζ = 0.7, ω = 9 rad/s on position.
- Add idle breathing sway using the noise from section 7 at 1.5 to 2× the camera amplitude, reduced by 70% when aiming down sights or holding breath.

**Procedural recoil (per shot):**
```
recoil_vel_pitch += kick_up * rand_range(0.9, 1.1)          // weapon spring impulse (deg/s)
recoil_vel_yaw   += kick_side * rand_range(-1, 1)
weapon_pos_vel.z += kick_back                                 // m/s, back toward shoulder
cam_trauma       += 0.12 to 0.2                               // bodycam shake
aim_off.y        += muzzle_climb * 0.4                        // part of climb persists in aim (player must pull down)
```
Use an underdamped spring for snappy recovery (ζ = 0.45 to 0.6, ω = 18 to 25 rad/s). Starting values for an M4-class rifle: kick_up 120 to 180°/s, kick_side 40 to 70°/s, kick_back 1.2 to 1.8 m/s, muzzle_climb 0.6 to 0.9° per shot. Pistols: about 1.3× kick_up, about 0.6× kick_back. Since the camera is chest-mounted, the image should **not** follow the muzzle climb directly. Only shake it, plus a small (≤ 0.3°) pitch shove. This is a key bodycam difference from FPS head-cams.

**Hit direction.** Raycast from the weapon muzzle along the weapon's forward vector, not from the screen centre. With lens distortion, any aim point drawn on screen must be projected through the same lens function (section 1) to sit on the right pixel.

### Gaps
- I found no published reference implementation of free-aim deadzones (for example from Insurgency, ARMA or Unrecord) during this session. The design above is standard practice from memory.

---

## 9. Full-body / IK arms in Godot 4 (SkeletonIK3D vs SkeletonModifier3D / TwoBoneIK3D, LookAtModifier3D, true first-person body)

### Takeaway
Target 4.6+ and use the new `SkeletonModifier3D`-based stack. Use `TwoBoneIK3D` (deterministic, needs a pole target) for each arm, driven by hand targets on the weapon. Use `LookAtModifier3D` for the spine and head aim (4.4+). Optionally add `LimitAngularVelocityModifier3D` (4.6) to smooth IK snaps. For the bodycam, attach the Camera3D to the chest bone with `BoneAttachment3D`. That makes the full body visible "for free" and gives authentic body-driven motion.

### Cited Findings
- IK history: Godot 4.4 added `SkeletonModifier3D` and `LookAtModifier3D`; 4.5 added `SpringBoneSimulator3D` and `BoneConstraint3D`; 4.6 introduced `IKModifier3D` and `ChainIK3D`. — [Godot blog: Inverse Kinematics returns to Godot 4.6](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/)
- 4.6 hierarchy: `IKModifier3D` → `TwoBoneIK3D`, `ChainIK3D` → (`SplineIK3D`, `IterateIK3D` → `FABRIK3D`, `CCDIK3D`, `JacobianIK3D`). `TwoBoneIK3D` and `SplineIK3D` are always deterministic. `IterateIK3D` determinism is optional; in deterministic mode with few iterations the end bone may not reach the goal. A 2-pass deterministic FABRIK emulates the old "magnet" option. The old IK was "removed during the upgrade to 4.0". — [Godot blog](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/)
- 4.6 adds post-processing modifiers: `BoneConstraint3D` can reference `Node3D`s, `BoneTwistDisperser3D` spreads twist to ancestors, and `LimitAngularVelocityModifier3D` smooths deterministic IK. `LookAtModifier3D` can be treated as one-bone IK; "users must specify the bone axis based on the bone rest." — [Godot blog](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/)
- `TwoBoneIK3D` inherits `IKModifier3D` ← `SkeletonModifier3D`. It is a "rotation-based intersection of two circles" solver that **requires a pole target** and builds a plane from joint and pole. Settings are indexed (`settings/<index>/root_bone_name` and so on), so one node can drive several chains (both arms). It has root, middle and end bones, target node, pole node, pole direction, and an optional extended end bone or virtual end. Twist can be handled through the pole direction. — [Godot 4.6 docs: TwoBoneIK3D](https://docs.godotengine.org/en/4.6/classes/class_twoboneik3d.html)
- 4.6 IK is deterministic regardless of previous-frame state, which suits networked use where only target positions are shared. — [GameFromScratch: IK returns to Godot](https://gamefromscratch.com/inverse-kinematics-ik-return-to-godot/)
- Jolt Physics is the default for new 3D projects in 4.6. — [80.lv: Godot 4.6 is out](https://80.lv/articles/godot-4-6-is-out)

### Inferences
**SkeletonIK3D status.** The legacy `SkeletonIK3D` node (FABRIK-style, 4.0 to 4.5) is, to my knowledge, marked deprecated in the 4.x class reference. The blog's wording ("removed during the upgrade to 4.0") is about the 3.x-era system and conflicts with that. **Verify in the 4.7 class reference** whether `SkeletonIK3D` still exists. Either way, do not build new work on it. Use `TwoBoneIK3D`.

**Recommended rig (4.6/4.7):**
```
CharacterBody3D
└─ Model (glTF)
   └─ Skeleton3D                 (modifier_callback_mode_process = idle, render-rate; property from memory)
      ├─ (AnimationTree/AnimationPlayer drive base pose: locomotion, weapon-hold layer)
      ├─ LookAtModifier3D  spine_02/spine_03 → aim target (influence 0.5 each, split across 2 bones)
      ├─ TwoBoneIK3D       setting 0: upperarm_r → lowerarm_r → hand_r, target = Weapon/GripR, pole = ElbowPoleR
      │                    setting 1: upperarm_l → lowerarm_l → hand_l, target = Weapon/GripL (foregrip), pole = ElbowPoleL
      ├─ LimitAngularVelocityModifier3D (arms, to avoid snaps when targets jump)
      └─ BoneAttachment3D (bone = spine_03 / chest) → BodycamMount → Camera3D
```
Modifiers run in child order after animation, so order matters: spine look-at → weapon placement → arm IK. Place the weapon from the **aim** state (section 8) in a script that runs before the skeleton modifiers. Or make the weapon a child of a "WeaponPivot" driven by the aim and sway springs, and let IK pull the hands to it. Each `SkeletonModifier3D` has an `influence` for blending, for example fading IK out during reload animations (from memory).

**Pole targets.** Put elbow poles about 0.4 m behind and 0.3 m below or outward of the shoulders, parented to the chest, so elbows hang naturally.

**True first-person body visibility.** Camera on the chest means the head is above or behind the lens. Hide the head and neck mesh for the camera only, with a shadow-only duplicate (`GeometryInstance3D.cast_shadow = SHADOW_CASTING_SETTING_SHADOWS_ONLY`) or a separate surface/mesh on a render layer excluded from the camera's `cull_mask`. Arms, hands, legs and torso stay visible. With a 120°+ lens the lower frame will show the chest rig and hands, a strong authenticity cue.

**Filter the camera motion.** Raw chest-bone motion from mocap can be jittery or too strong. Don't parent the camera rigidly. Each frame, read the bone global transform and spring/exp-decay the camera towards it (half-life 0.03 to 0.06 s for position, 0.04 to 0.08 s for rotation), then add the procedural layers from section 7 at reduced amplitude.

### Gaps
- `SkeletonIK3D` deprecated vs removed is unresolved (see conflict above).
- The exact `LookAtModifier3D` API changes in 4.6/4.7 were not checked.
- Whether `Skeleton3D.modifier_callback_mode_process` exists under that name in 4.7 was not verified.

---

## 10. Viewmodel with separate FOV vs world camera, and interaction with lens distortion

### Takeaway
For a bodycam, the full-body + IK approach (section 9) is preferable to a classic viewmodel, because everything shares one camera and one lens. If you need a viewmodel (to stop weapon clipping), use one camera with a viewmodel spatial shader that rebuilds the projection with its own FOV and compresses depth in the vertex stage (adjusted for 4.3+ reverse-Z). Apply the lens distortion as a single full-screen pass afterwards, so weapon and world distort together.

### Cited Findings
- Common viewmodel shader (MIT, Riordan/Kastor): in `vertex()`, `float scale = 1.0 / tan(fov * 0.5 * PI/180); PROJECTION_MATRIX[0][0] = scale / (VIEWPORT_SIZE.x / VIEWPORT_SIZE.y); PROJECTION_MATRIX[1][1] = scale;`; in `fragment()`, `DEPTH = FRAGCOORD.z * 0.7` to reduce clipping. Commenters report a Y-flip in Godot 4.x (negate the matrix scale terms) and advise against writing DEPTH in the fragment stage for performance, setting `POSITION.z` in the vertex stage instead. — [godotshaders: First Person View Model Shader](https://godotshaders.com/shader/first-person-view-model-shader/)
- Godot 4.3 switched to **reverse-Z**. The near plane is now clip-space Z = 1.0 (was 0.0). `POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX,1.0)` needs no change. `DEPTH = 0.0` must become `DEPTH = 1.0`. Clip-space depth comparisons must be flipped (`clip_pos.z < depth`). Do comparisons in view space where possible. — [Godot blog: Introducing Reverse Z](https://godotengine.org/article/introducing-reverse-z/)
- A weapon-FOV shader using `POSITION.z = mix(POSITION.z, 0, 0.997)` broke in 4.3. Changing the target to 1.0 made it visible again (anecdotal fix). — [Godot Forums: weapon FOV shader broken in 4.3](https://godotforums.org/d/40946-weapon-shader-doesnt-work-in-43)
- Modifying the projection matrix this way puts the weapon's **shadows in the wrong place**, since the shadow pass uses the modified projection. No resolution was posted. — [Godot Forum: Fixing weapon clipping using shader causes shadow bug](https://forum.godotengine.org/t/fixing-weapon-clipping-using-shader-causes-shadow-bug/91595)
- Unreal practice: FOV correction plus Z-scale to pull the viewmodel towards the camera; keep a small but non-zero near plane. — [Unreal forum: First Person Viewmodel Correction](https://forums.unrealengine.com/t/first-person-viewmodel-correction-z-clipping-and-separate-fov/147783)
- 3D screen-texture reads miss transparent objects. A separate `Viewport` with a matching camera is the docs' suggested alternative for 3D captures. — [Godot docs: Screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)

### Inferences
**Viewmodel shader for 4.3+ (derived from the sources above):**
```glsl
shader_type spatial;
render_mode cull_back;
uniform float vm_fov_deg = 60.0;     // smaller than world FOV so the gun isn't stretched by the wide source FOV
uniform float vm_depth   = 0.05;     // squash into the nearest 5% of depth range (reverse-Z: toward 1.0)
void vertex() {
    float s = 1.0 / tan(radians(vm_fov_deg) * 0.5);
    mat4 P = PROJECTION_MATRIX;
    P[0][0] = s / (VIEWPORT_SIZE.x / VIEWPORT_SIZE.y);
    P[1][1] = s;                      // check sign on your version; Godot 4 comment reports a Y flip with the old shader
    POSITION = P * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    POSITION.z = mix(POSITION.w, POSITION.z, vm_depth); // reverse-Z: z/w → 1.0 is near; keeps gun in front of world
}
```
Here `mix(POSITION.w, z, k)` yields z/w = 1 − k·(1 − z/w), squashing depth towards the near plane while staying perspective-correct. It is my derivation; test it. The shadow bug: give the weapon `cast_shadow = OFF` and add a shadow-only duplicate mesh using the normal material, positioned in world space. Or accept no weapon shadow.

**Important for the bodycam pipeline:** the world source FOV is very wide (about 100° vertical, section 1). A viewmodel left at world FOV gets heavily stretched at the source stage, then compressed again by the lens pass, so the gun looks tiny and far. Two coherent options:
- (A) **Physically consistent:** skip the separate FOV. Put the real weapon and full-body arms in the world (section 9) and handle clipping with a short collision ray that pulls the weapon back or raises it ("weapon collision/obstruction"). The lens then distorts weapon and world identically. That is what a real bodycam shows and is the recommended choice.
- (B) **Viewmodel:** use the shader above with `vm_fov_deg` set so the weapon's screen size *after* the lens pass looks right. The lens pass still distorts it because distortion runs on the final image. Avoid compositing a separate viewmodel SubViewport *after* the lens pass, which would leave the gun undistorted and break the look. If you composite one, do it before distortion (render both into textures, composite, then distort in one canvas pass).

**Lens pass placement with a viewmodel.** CompositorEffect at POST_TRANSPARENT and the canvas overlay both see the viewmodel, since it is in the same 3D viewport, so both distort it. Transparent weapon parts (sights, glass) are included at POST_TRANSPARENT and in the canvas overlay, but not in a spatial `hint_screen_texture` pass (docs limitation above).

**Performance.** The viewmodel shader is free; vertex-stage depth avoids the fragment DEPTH write, which disables early-Z. A second SubViewport for a viewmodel would cost a second scene render pass (shadows, GI lookups), so avoid it.

### Gaps
- Exact Y-sign handling of `PROJECTION_MATRIX[1][1]` in 4.4 to 4.7 was not verified on current builds.
- The `mix(POSITION.w, POSITION.z, k)` reverse-Z depth squash is my derivation, not from a source.
- No source checked whether `VIEWPORT_SIZE` aspect matches the rendered aspect when `scaling_3d_scale ≠ 1`. It should, as internal size, but this is unverified.
