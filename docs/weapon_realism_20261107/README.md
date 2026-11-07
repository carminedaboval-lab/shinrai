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
- Renders: `tools/weapon_real/capture.ps1 -Only <gun> -Tag <tag>`; same-camera pass
  `tools/weapon_real/before_after.ps1 -Backup <old weapon folders>`; sheets via
  `python tools/weapon_realism_sheet.py compare <gun>`.
- Gameplay check: `tests/weapon_realism_validate.gd`.
