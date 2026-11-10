# Bodycam view and gun work: hand-over from the gun session (2026-11-09)

The Park session takes over from here. Everything below is uncommitted unless it says otherwise. The last gun commit is `4937ebe`.

## 1. Bodycam view: written, never run

### Files
| File | State |
|---|---|
| `scripts/fx/bodycam_rig.gd` (new) | Complete first version. Never loaded in Godot. Constants use literal radians, avoiding `deg_to_rad` in `const`. |
| `scripts/fx/bodycam_lens.gdshader` (new) | Complete equidistant fisheye with radial chromatic aberration, cos^4 vignette and corner darkening. Never compiled. |
| `scripts/player.gd` | Three hooks only: (1) `const BodycamRig := preload("res://scripts/fx/bodycam_rig.gd")` and `var bodycam: BodycamRig` after the `CameraTrauma` preload; (2) in `_ready()`, after `camera_trauma.bind(camera)`, create `BodycamRig`, `add_child`, `bind(self)`; (3) in `_unhandled_input`, `KEY_F4` calls `bodycam.toggle()` (works in extraction mode too). |
| `tests/weapon_ads_capture.gd` | New `--bodycam` flag. After the raid starts it calls `player.bodycam.set_enabled(true)`, then takes the usual hip and ADS shots for each gun. |

All files should parse, but none has been through Godot. The first run should check the error log for both new files.

### Design (from `reports/Bodycam camera mode research.md`)
- **Eye/Lens split without moving anything.**
  - The existing `player.camera` (Head 1.58 m → Camera3D) stays the **eye**: aim, shooting rays, ADS, viewmodel, lean, recoil and DOF are unchanged.
  - The rig adds a second `Camera3D` called `BodycamLens`, a child of the rig Node, so it has no parent transform. It becomes `current` only while bodycam mode is on.
  - The rig never moves the eye. Default mode is untouched, because the lens is never current.
- **Viewmodel.**
  - All weapons stay parented `camera → WeaponPosture → viewmodel` on `VIEWMODEL_LAYER` (1 << 19).
  - The lens copies `player.camera.cull_mask`, so the gun renders in the same 3D image and the fisheye bends it with the world.
  - Seen from the chest, the gun sits high in frame and there is no sight picture. That is intended.
- **Mount.**
  - The chest is `eye.origin − 0.24 m up + 0.11 m forward`, along the lagged yaw.
  - Mount tilt is −5°.
  - The lens follows 45% of head pitch (85% while aiming); the tilt fades to 0 while aiming.
- **Torso lag.**
  - Yaw follows body yaw with exponential rate 9/s, clamped to 14° behind. Sourced: the head leads the thorax by 13 ± 11°.
  - Pitch uses rate 10/s.
- **Gait.**
  - Cadence comes from the movement state, not raw speed: walk 1.9 Hz, sprint 2.8 Hz, crouch 1.5 Hz. Phase advances one unit per step.
  - Vertical bob is cos(step): 1.25 cm half-amplitude walking, 4 cm sprinting.
  - Lateral bob is sin(stride): 0.9 / 2.2 cm.
  - Roll is 1.1° / 2.6°; nod is 0.8° / 2.0°.
  - Strafe roll is up to 2°, turn roll up to 2.5°.
  - Landing uses a damped spring: k 120, damping ratio 0.55.
  - All of this is multiplied by `motion_scale` (default 0.7) and reduced 60% while aiming.
- **Lean and trauma.**
  - The eye's position already carries the lean shift. The lens adds 80% of the lean roll.
  - `h_offset` / `v_offset` are copied from the eye, so firing and hit trauma show.
- **Lens pass.**
  - A `CanvasLayer` with `layer = -1` draws after 3D and before every HUD layer. It holds a full-rect `ColorRect` using a `hint_screen_texture` shader.
  - The target is 120° horizontal equidistant, Motorola VB400 class.
  - The source camera's vertical FOV comes from the corner-fill rule `tan(src_h) = tan(θ_corner)·a/√(a²+1)` (about 103° vertical at 16:9, set with `KEEP_HEIGHT`).
  - `lens_strength` runs from 0 (rectilinear 120°) to 1.
- **Other behaviour.**
  - The crosshair is hidden while bodycam mode is on.
  - The rig only takes the view back from the eye camera, never from a death cam or cutscene camera.
  - `process_priority = 1000`, so it runs after the player has moved, looked and leaned.

### Untested and risky
- Not loaded in Godot at all. Expect small fixes.
- The `tactical_crosshair.visible` toggle is untested; the HUD may set visibility elsewhere.
- The fisheye centre will look soft, because it is magnified about 2.15×. The research suggests `scaling_3d_scale` of 1.3–1.5 if that matters.
- The first-person body (`scripts/urban_explorer_body.gd`) is set up for the eye: the model is pushed back 0.32 m and the head, arms and upper torso are hidden. So the chest lens will not see the player's own vest or legs. That is a separate remodel task the user wants researched on its own.
- The pistol aim light (`pistol_candidate_viewmodel.gd`) sits at the eye, not the lens; that is fine.
- Systems that call `get_viewport().get_camera_3d()` (LOD, wind, wildlife and others) will get the lens while bodycam mode is on. That should be harmless, since it is only about 25 cm lower.
- The prism scope and lake reflection follow their own logic, so check scopes in bodycam mode.

### Remaining (agreed with the user)
1. Run it:
   - `powershell -File tools/godot_locked.ps1 -Out <log> -GodotArgs "--path . --script res://tests/weapon_ads_capture.gd -- --out <dir> --only akane,raiden_r56 --bodycam"`, then the same without `--bodycam` for comparison.
   - Show the user same-camera default vs bodycam shots, hip and aimed.
   - Confirm the default view is pixel-identical to before.
   - Run `tests/weapon_realism_validate.gd`. It needs a window; headless gives false failures.
2. Comfort sliders in the options menu: motion scale and lens strength.
3. Later phases, each with its own research per the user: sensor look (30 Hz frame hold, rolling shutter, exposure lag with its own Linear or Filmic Environment, compression, grain, timestamp overlay with an invented brand such as "MIHARI BC-7"), free-aim deadzone and muzzle-origin rays, and a full body visible from the chest (remodel and animation).
4. Answer the open user question: aiming setup, chest plus optional helmet or glasses cam (recommended) or chest only.

## 2. Gun work after commit 4937ebe (uncommitted, validated)

The last full validation (`tests/weapon_realism_validate.gd` with a window) found 0 failures, after the Glock square-notch change.

### Ergonomics pass
- **Files:** `tools/weapon_real/{trace.py, kite_scar17.py, shigure_evo3.py, raiden_m4a1.py, tobikage_svd.py, yuzuru_aiaw.py}`, plus the rebuilt glbs `assets/weapons/{kite,shigure,raiden_r56,tobikage,yuzuru}/*_geometry.glb` and the sheets in `docs/weapon_realism_20261107/sheets/` (including the new `ergonomics_before_after.jpg`).
- **New helpers in `trace.py`:**
  - `clip_convex`, a Sutherland–Hodgman clip.
  - `grip_loft`, egg-shaped sections along the grip's rake. It accepts several convex pieces of the outline.
  - `smoothstep` and `squeeze`, which slim part of a dense mesh by a factor(d, y).
- **What changed:**
  - Oval grips on the M4, SCAR and EVO.
  - SVD wrist squeezed 16%.
  - AW grip widths reduced.
  - SCAR and EVO trigger guards slimmed to about 17–18 mm.
  - SCAR hinge flush with the receiver at 42 mm.
  - EVO handguard nose rounded; the front face is at d 31.6.

### Glock
- **Files:** `tools/weapon_real/akane_glock17.py`, `assets/weapons/akane/akane_geometry.glb`, `assets/weapons/akane/akane_viewmodel.tscn`, `scripts/extraction_weapon_catalog.gd`, `scripts/pistol_candidate_viewmodel.gd`.
- **What changed:**
  - Factory square rear notch: 3.5 mm wide, bottom at 3.4 mm below the sight top, with a square white "U" outline 0.9 mm thick. The user corrected the earlier round notch.
  - Sight white is slightly emissive: the `luminous()` helper, strength 0.35.
  - `iron_eye_relief_m` 0.32 → 0.25.
  - `ads_speed` 9.0 → 6.7, giving about a 0.15 s aim time.
  - `pistol_candidate_viewmodel.gd` has an aim-only `SpotLight3D` at the eye: viewmodel layer only, 6.5° cone, energy 0.7, fading in over ads_blend 0.45–1.0, off with an optic. It lifts the black slide back from pure black.

### Pending "Glock skin"
- The user feels the Glock "looks like the least detailed gun in an FPS ever" and wants a skin or detail pass on it.
- Not started.
- The likely direction: real surface detail (slide nDLC finish variation, frame stippling read, markings depth, wear on the slide edges and controls), within the [[no-line-patterns]] rule. That means no fake stripes, seams or grooves as "detail".
- Use same-camera before/after captures.

### Gotchas not in the README
- Always run Godot through `tools/godot_locked.ps1` or `tools/weapon_real/one_gun_locked.ps1`. An inline lock attempt once failed and ran anyway.
- In the builders, intersecting with `trace.shape()` / `crown_loft()` is safe. Avoid region booleans on one-piece stocks, because they leave steps; use `squeeze` after a voxel-only `moulded` pass instead. Never squeeze an already-decimated mesh, because it streaks.
- Keep loft stations at least 0.8 mm apart, or `wr.bevel` throws spikes. `wr.bevel` now deletes spikes and prints `BEVEL_SPIKES`.
- Blender: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe --background --factory-startup --python tools/weapon_real/<builder>.py`.
- Git is not on the PowerShell PATH: use `C:\Users\hp\AppData\Local\GitHubDesktop\app-3.6.5\resources\app\git\cmd\git.exe`.
- Never commit `assets/uzi/textures/*`, `tools/weapon_real/__pycache__/*`, or other sessions' `.uid` and probe files.
- `reports/` and `research_notes/` (the bodycam research) are new and untracked.
