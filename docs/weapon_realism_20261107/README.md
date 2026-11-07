> **Per-gun open items from the previous session: see [HANDOVER_PER_GUN.md](HANDOVER_PER_GUN.md).**

# Guns → real counterparts (2026-11-07)

Every gun was rendered close up from fixed cameras (left, right, top, a 3/4
first-person view and the muzzle), compared with its real counterpart, then
rebuilt at real dimensions and re-rendered through **the same cameras**. Each
camera frames the union of the old and new model, so the longer real guns are
not cropped. Sheets: `sheets/<gun>_before_after.jpg`. Close-up review renders
(`*_live_*`, `*_sights_live_*`) are in `renders/`.

The previous guns were original stylised designs: blocky procedural kit or
lumpy AI meshes. None was a near-copy of a real gun, so each one was rebuilt
rather than tweaked. Only the Akane had a design note ("Glock-style"); the
other mappings are labelled defaults chosen from each gun's role, calibre,
capacity, mass and silhouette.

| Game gun | Real counterpart | Reference used |
|---|---|---|
| AKANE / A-9 | Glock 17 Gen 5 MOS, 9×19 | Commons "Glock 17 Gen 5 Gun white bg crop.png" (traced, 8.8 px/mm) |
| RAIDEN / R-56 | Colt M4A1, SOPMOD Block II layout | Commons "M4A1 SOPMOD Block II.jpg" (traced, RIS II = 311 mm) |
| TOBIKAGE / T-65 | Dragunov SVD, laminated furniture | Commons "Dragunovs rt noBG.jpg" (traced, 1225 mm OAL) |
| HAYATE / H-7 | USMC M40A5 (Rem 700, McMillan A4) | published dimensions (no clean side photo on Commons) |
| YUZURU / YZ-10 | Accuracy International AW | published dimensions |
| SHIGURE / S-9 | CZ Scorpion EVO 3 A1 | Commons "Scorpion EVO 3 A1 left.jpg" (traced, 241 mm height) |
| KITE / K-12 | FN SCAR 17S (SCAR-H) | Commons "FN SCAR-L and SCAR-H.png" (traced, low resolution) |
| UZI | IMI Uzi | already a real Uzi (CC-BY Sketchfab rig by 1Matzh); checked, unchanged |

Trademarked logos (GLOCK, COLT, FN, CZ…) are replaced with the in-game names in
the same places and styles (slide logo box, receiver roll marks, selector
markings, serials).

## Photo-trace pass (after the user's "trace them really carefully")
For the guns that were furthest off, outlines are now extracted automatically from calibrated side
photos (marching squares on a colour/alpha mask, simplified to about 0.3 mm). The scale is
measured from the 10.0 mm MIL-STD-1913 slot pitch where the gun has a rail. Each part is the traced
outline clipped to that part's region, extruded at the real part width, then rounded. Traced
controls, screws and slots become relief or recesses, and traced holes are cut through. Reference
data lives in `tools/weapon_real/refs/`; `tools/weapon_real/trace.py` turns it into geometry
(including true-round lathe parts for barrels and brakes).

| Gun | Trace source | Scale |
|---|---|---|
| Kite / SCAR 17S | FN America studio left-side photo, 2400 px | 2.42 px/mm (rail slots) |
| Shigure / EVO 3 A1 | Commons "Scorpion EVO 3 A1 left.jpg", 3807 px | 6.10 px/mm (rail slots) |
| Raiden / M4A1 | Commons "M4A1 SOPMOD Block II.jpg", 7607 px | 7.18 px/mm (rail slots) |
| Tobikage / SVD | Commons "Dragunovs rt noBG.jpg" | 0.978 px/mm (1225 mm OAL) |
| Hayate / M40A5 stock | Commons "M-40A3.jpg", levelled on the barrel (13.1°) | 1124 mm OAL |
| Yuzuru / AW stock | Commons "PSG 90 G24" side image | 1180 mm OAL |

The FN photo is used only to measure outlines; it isn't copied into the game or the sheets.

## Gap lists

**AKANE → Glock 17 Gen 5.**
Before: 233 mm long (real 202 mm); slide floating above the frame with a visible gap; faceted
angular frame and octagonal guard; inset grip panels instead of Gen 5 texture; four rail nubs; no
beavertail, takedown lever, slide stop or mag-catch shape; ball on the muzzle face; no ejection-port
barrel hood.
Fixed: traced side profile, 186 mm slide with Gen 5 nose and top chamfers, 7 front and 7 rear
serrations at 5.1 mm pitch (real grooves), right-side ejection port showing the barrel hood
("9x19"), extractor with loaded-chamber bump, MOS cover plate with two screws, polymer U-notch
rear sight with white outline and front dot sight, keyhole muzzle with crowned barrel and guide
rod, moulded frame with beavertail, squared hooked trigger guard, single-slot rail, Gen 5 flared
magwell and front cutout, ambidextrous slide stops, serrated takedown levers, two frame pins,
ribbed mag catch, serial plate, Gen 5 safety-blade trigger, Gen 5 raised grip texture (shader),
magazine with witness holes, orange follower and top round. nDLC slide and barrel and polymer
finishes. Real-size sockets (muzzle, sights, MOS socket, slide stop, port, magazine grip).
Remaining: the grip texture is a shader pattern, not geometry; markings are flat inlays, not cut;
the barrel stays still while the slide cycles (no tilt).

**RAIDEN → M4A1.**
Before: an invented bullpup-like carbine with olive two-tone, skeleton stock, no forward assist,
port, dust cover or AR controls.
Fixed: flat-top upper with MIL-STD-1913 rail and T-markings, round barrel-extension housing,
ejection port with open dust cover and visible bolt carrier (forward-assist serrations, cam pin,
extractor), forward assist, brass deflector, A2 charging handle and latch. Lower with flared
magwell, bolt-catch boss, mag-release fence and button, pivot, takedown, trigger and hammer pins,
SAFE/SEMI/AUTO selector, A2 guard and curved trigger, A2 grip with checkering. Buffer tower,
castle nut, QD end plate, receiver extension, B5 SOPMOD stock with battery tubes and QD cups,
12.25 in RIS II quad rail, A2 birdcage (five slots, closed bottom), PMAG with top rounds, KAC
flip-up sights.
Remaining: lower-receiver side contours and PMAG texture panels are simplified; the RIS II vent
pattern is approximate.

**TOBIKAGE → Dragunov SVD.**
Before: an invented boxy DMR with a ribbed handguard and strut stock.
Fixed: AK-pattern receiver and top cover, trunnion with tangent rear sight, right-side safety
lever, charging handle, mag-release paddle, left PSO dovetail rail, gas block and regulator, gas
tube, laminated vented handguard with retaining rings, hooded front sight with bayonet lug,
5-slot flash hider, laminated skeleton thumbhole stock with cheek rest and butt pad, ribbed
10-round magazine. Iron eye relief set to 0.34 m in the catalogue (the SVD rear sight sits on the
trunnion).
Remaining: the catalogue still lists the ammo as "6.5×48 fictional" (gameplay data left
unchanged); the stock shape is approximate.
Pass 3 changes (see the table below for the full list):
- Receiver re-placed from the trace: 577-950, bottom -31.5, cover 37.5.
- The stock no longer includes the receiver hump.
- Ribbed early cover, cover catch, forward regulator and left-side swivels.
- 58k vertices.

**HAYATE → M40A5.**
Before: the barrelled action floated above an invented olive stock.
Fixed: Remington 700 receiver, recoil lug, 25 in heavy barrel with brake, Badger 30 MOA rail,
detachable 5-round bottom metal, polished bolt with tactical knob (the bolt-lift pivot is on the
bore axis), McMillan A4 stock with adjustable cheek, LOP spacers, recoil pad, flush cups, front
stud rail.
Remaining: plain olive instead of hand-painted camo; low folding backup irons were added so iron
ADS keeps working (a real M40A5 has none).

**YUZURU → Accuracy International AW.**
Before: an invented skeleton-stock bolt gun.
Fixed: AW receiver with rail, 26 in barrel with brake, aluminium chassis with stock bolts,
thumbhole stock with fore-end slots, moulded guard, 10-round magazine, 3-lug bolt, AW-style
front post and hood plus rear aperture.
Remaining: built from published specs, so stock contours are approximate.

**SHIGURE → CZ Scorpion EVO 3 A1.**
Before: a lumpy AI mesh with smeared baked textures.
Fixed: traced upper/lower split, top rail, left non-reciprocating charging handle, port and bolt,
raked textured grip, large trigger guard, ambidextrous selector, bolt catch, mag paddle and
button, tapered handguard with M-LOK slots and handstop, thread protector, side-folding stock
and hinge, curved smoked magazine, front post and rotating rear drum.
Remaining: the magazine is not rendered translucent; handguard and upper detailing are
simplified.

**KITE → FN SCAR 17S.**
Before: a lumpy AI mesh.
Fixed: monolithic FDE upper with full-length top rail and side/bottom rails, left charging
handle, right port, polymer lower, grip, guard, ambidextrous safety and mag buttons, bolt catch,
side-folding stock with cheek riser, 3-prong flash hider, 20-round steel magazine, folding sights.
Remaining: traced from a low-resolution photo, so upper side contours and the stock are
simplified; no gas regulator detail.

**UZI.** Already an accurate IMI Uzi (ribbed top cover, grip safety, folding stock, front-sight
ears, knurled barrel nut). No change needed.

## Pass 3: one agent per gun, plus shared finish (2026-11-07, integrated)
Each gun was reworked part by part against its real counterpart by its own agent. The shared
finish shader was rewritten, and an integrator then applied the shared requests, re-rendered
every gun (after and before, same cameras) and ran the gameplay check. Nothing is committed.

| Gun | Fixed in this pass | Still differs | Vertices (README budget) |
|---|---|---|---|
| AKANE / Glock 17 Gen 5 | Rail moulded into a flat-bottomed dust cover; full barrel-hood top showing in the port; no half-moon cutout (FS frame); bevelled dust-cover nose; floor-plate lip; polymer trigger and safety; grooved slide-lock lever; slide-stop arm; barrel serial; smooth relief at the mag catch; flush serial plate | Grip texture is shader-only; markings are flat inlays; slide-stop arm and serration counts come from memory, not a photo; no barrel tilt | 75,443 (61k, +24%) |
| RAIDEN / M4A1 Block II | Invented RIS II vent holes removed; clamshell split and 6 bolts; front disc artefacts removed and open rail front with barrel; real A2 birdcage; gas block and tube; KAC front and rear sights rebuilt; selector arc SAFE/SEMI/AUTO; 10 mm guard bar; castle-nut notches; rubber butt pad; smooth PMAG with floorplate; 39 mm charging handle; magwell flare; rail slot numbers | Lower-receiver side contours simplified; the new left close-up shows the selector markings barely readable; SOPMOD stock has no adjustment lever; KAC knobs not knurled; handguard 320 mm vs 311 mm spec | 90,280 (102k, -12%) |
| TOBIKAGE / Dragunov SVD | Receiver re-placed from the trace (d 577-950, bottom -31.5, cover top 37.5); receiver hump removed from the stock; magazine closes into the magwell; no AK rivets; ribbed early cover with spring-guide button; cover catch lever; forward regulator sleeve (1/2); left-side swivels; trigger housing and guard from the trace; chamfered flash-hider nose; 23 mm barrel; smoothed stock and real cheek-rest groove; PSO rail with recoil slot; OpticSocket and EjectionPort moved | Part widths estimated (one 0.98 px/mm photo); no handguard parting line; no rear-sight numerals; trigger housing simplified; laminate ply bands only where the surface cuts across the plies | 58,116 (54k, +8%) |
| HAYATE / M40A5 | Remington 700 short action (168 mm) with port, tang, gas vent and lug; true 25 in barrel; SureFire-style brake; McMillan A4 rebuilt as a smooth loft at spec widths with thumb notch, saddle cheek piece, 6 flush cups and bipod stud; embedded front rail; Badger 30 MOA base and M5 bottom metal; AICS 5-round mag; real folding BUIS; markings tangent to the round surfaces; markers moved | Length of pull 12.8 in (real 13-14.5 in): butt not lengthened so the first-person fit is kept; plain OD with no field camo; brake ports and flush-cup positions are labelled defaults; muzzle camera locked to the old muzzle point (muzzle_live is correct) | 38,656 (62k, -38%) |
| YUZURU / AI AW | Stock re-traced from a measured PSG 90 photo with lofted rounded sections; action group moved 40-60 mm forward; 70 mm butt spacer and pad assembly; cheek piece; monopod; fore-end flute and swivel cup instead of invented slots; flat-sided receiver at +23.5 mm rail; 6-lug bolt, shroud, safety and swept handle; clamp-collar brake with windows; moulded guard; markings on the right; markers moved | Black (AWP) colour rather than olive; no bolt flutes or extractor; the shroud rotates with the bolt; no stock parting seam | 74,218 (58k, +28%) |
| SHIGURE / CZ Scorpion EVO 3 A1 | True 1913 top rail from front to rear sight; flat-topped upper running forward to the front sight; hollow M-LOK handguard; charging slot on both sides; magwell flare; translucent smoked magazine with 27 visible rounds and follower; cylindrical flash hider and bored barrel; real rotating rear drum; ambidextrous selector, pictograms and bolt catch; rubber butt pad | Stock and hand stop are extrusions; magazine holds 27, not 30; no sling points; grip texture is shader-only | 57,073 (57k, 0%) |
| KITE / FN SCAR 17S | Upper section 42 mm with anodised band to -13 mm; lightening slots and charging channels; 1913 side and bottom rails; NRCH; sling plates; phosphated gas block, regulator and folding front sight; open compensator prongs; rebuilt rear sight on an 83 mm sight line; real lower controls; long low port with deflector; markings, oval logo and data matrix; grip texture limited to the panel; stock beam step, comb button and LOP marks; real stamped mag | Compensator prong slots approximate; engraving faint; no Torx recesses or checkered pads; section widths estimated | 46,170 (47k, -2%) |
| UZI / IMI Uzi | Textures re-authored: no fake 0.5 AO; satin baked-enamel finish with bare-steel wear; phosphate barrel and magazine; matte ABS grips; roll marks restamped with in-game names (UZI S.M.G. / FULL AUTO / SHINRAI ARMS) | Selector still reads S/F (Model B); handguard sheen gradient; the BEFORE column is blank (there is no uzi in `before_assets/`) | 17,045 (unchanged) |

**Shared finish (`scripts/weapon_real_finish.gd` / `.gdshader`).** Wear is driven by object-space
signed curvature: convex bevels lighten, and in contact patches they wear through to bare metal;
concave fillets collect dust; rounded surfaces take on a handling polish. New patterns: hard-anodised
aluminium (6), rubber (7) and plain (8). Laminate plies and glue lines are shown when `ply_mm > 0`,
and phosphate has blotchy oil-sheen patches. Unknown material names fall back to a keyword finish.
Integrator changes:
- Edge wear and dust now fade out once a pixel covers more than about 0.3-0.7 mm. This removes
  the bright dashed outlines on rail slots in full-gun views; close-ups keep the wear.
- "SVD magazine steel" edge wear lowered from 0.6 to 0.35.
- McMillan OD darkened to (0.24, 0.27, 0.19) and (0.23, 0.26, 0.18).
- Added "AW bullet jacket" (copper) and "SCAR phosphate steel" (grey phosphate on the gas block
  and front sight base). "SCAR magazine" lightened to the real golden FDE (0.6, 0.5, 0.32).

The smoked EVO magazine names stay out of the table on purpose so the glTF alpha blend survives.

**Capture (`tests/weapon_realism_capture.gd`).** Changes:
- 8192 directional shadow atlas with soft-high filtering and blended splits, which removes the
  stair-stepped barrel shadow on stocks.
- New `left_live` close-up framed on GripRight: the left side of the lower or frame, for the
  selector, roll marks and mag catch.

Before and after were both re-rendered with these settings.

**Validation:** `tests/weapon_realism_validate.gd` gives 128/128 with 0 failures. Every gun's
sight line is centred (0.0000), including those whose markers moved: tobikage, hayate, yuzuru and
kite. Run it windowed, as its usage line shows. A `--headless` run has no frame cap, so the
fixed frame waits end before the equip animation does: that gives 13 false failures ("ready for
input after equip" and "sight line centred").

Open shared items:
- Handling polish comes from noise. Placing it where hands actually rest needs a vertex-colour
  contact mask from the builders.
- "M4 hard anodized" covers both upper and lower, so the real colour mismatch between them can't
  be shown.
- `hayate_muzzle.json` stays on the old muzzle point (-0.805) so before and after share a camera.

## Not covered
- Optics (AME reflex, TOBI prism, KASUMI scope) were not rebuilt.
- Reference photos are linked by name, not embedded in the sheets. Downloading them needs the
  user's OK.

## Verification
`tests/weapon_realism_validate.gd` loads all seven rebuilt viewmodels on the real arms rig:
128 checks, 0 failures. For every gun: fitted to the hands, all sockets present, muzzle ahead of
the camera, magazine part resolved, real finishes applied, iron sight line exactly centred at full
ADS (0.0000 offset), fires, empty reload completes, and the Hayate/Yuzuru bolt cycle completes.
Not verified: a full park boot / in-raid playtest, and scav (enemy) hand fit with the new Shigure.

Polygon budget (vertices, before → after, including the rounded-edge pass): Akane 35k → 61k,
Raiden 63k → 102k, Tobikage 38k → 54k, Hayate 101k → 62k, Yuzuru 147k → 58k, Shigure 52k →
57k, Kite 59k → 47k. That totals about 441k against 495k before, and Godot import still
generates LODs.

The second pass (after the parent session's review) made machined edges 2.2× rounder (3-segment
bevels that catch light and wear), strengthened edge wear and roughness variation, deepened the
laminate grain, and added:
- the SVD's sloped, ribbed dust cover;
- the M40A5's larger tactical knob and action screws;
- a round-shouldered Scorpion handguard;
- a muzzle camera that looks into each gun's crown.

All of it re-validated: 128/128.

`before_assets/` holds an untracked copy of the previous weapon folders (about 85 MB). The
"before" renders come from it, and it doubles as a rollback copy. Delete it when it's no longer
needed.

## Rebuild / re-render
- Builders: `tools/weapon_real/<gun>.py` (Blender 5.2, `blender --background --python ...`),
  helpers in `tools/weapon_real/wr.py`.
- Finishes: `scripts/weapon_real_finish.gd` / `.gdshader`, keyed by material name.
- Renders + sheet (preferred, safe with several agents): `powershell -File
  tools/weapon_real/one_gun_locked.ps1 -Key <gun> -Builder <builder> [-SkipBuild] [-WithBefore]`.
  It takes the exclusive `.godot_render.lock` for every Godot step. Older path:
  `tools/weapon_real/capture.ps1 -Only <gun> -Tag <tag>`; same-camera pass
  `tools/weapon_real/before_after.ps1 -Backup <old weapon folders>`; sheets via
  `python tools/weapon_realism_sheet.py compare <gun>`.
- Gameplay check: `tests/weapon_realism_validate.gd`. Run it windowed, without `--headless`, and
  under the same lock.
