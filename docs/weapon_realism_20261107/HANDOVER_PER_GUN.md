# Guns: hand-over per gun (weapon realism session, standing down 2026-11-07)

## State on disk (uncommitted)
- All 7 glbs are rebuilt from the current builders.
- Traced sockets are re-applied to kite, shigure, raiden_r56 (weapon tscn + viewmodel magazine_grip).
- A full `godot --headless --import` is still running from this session; the cache was wiped. Let
  it finish, since the locked runner waits on it.
- Not yet rendered or validated after the restore: run captures (after + before using
  `--assets-root res://docs/weapon_realism_20261107/before_assets`), sheets, and
  `tests/weapon_realism_validate.gd`. The last pre-restore run was 128/128.

## Unfinished per gun
**akane (Glock 17 Gen 5)**
- Just patched: grip flares out of the frame (no ledge); rounded takedown lever, slide stop and
  mag catch. Not rendered yet.
- Open: no slide/barrel tilt on cycle; markings are flat inlays; the grip texture is shader-only;
  the trace was hand-picked points, not the automatic tracer.

**raiden_r56 (M4A1 Block II)**
- Traced (refs/m4a1_blockii_right.json); sheet sent.
- Open: forward assist and brass deflector are crude; the PMAG texture panels are simple; the RIS
  II front cap is round, not square; left-side controls come from drawings, not a left photo.

**tobikage (SVD)**
- Just re-traced: stock and magazine with the real double-H stamping (refs/svd_right.json).
- Not rendered or sent since.
- Open: the receiver top is hidden by the scope mount in the photo, so it's still modelled; the
  barrel and flash-hider diameters are from spec (the photo's are blurred and inflated).

**hayate (M40A5)**
- Stock re-traced from the M-40A3 photo (1.1 mm/px); sheet sent.
- Open: plain olive (no camo paint); the folding BUIS is a gameplay addition; bottom metal and
  bolt detail are simplified; worth a higher-res trace if one can be found.

**yuzuru (AI AW)**
- Stock re-traced from the PSG 90 image (2 mm/px, low res); sheet sent.
- Open: needs a better reference; the fore-end slot pattern and chassis are approximate.

**shigure (EVO 3 A1)**
- Traced (refs/evo3a1_left.json); sheet sent.
- Open: the handguard front face is blocky; the stock skeleton recesses are approximate; the
  magazine is opaque (the real one is smoke-translucent).

**kite (SCAR 17S)**
- Traced from the FN studio photo (refs/scar17s_left.json); sheet sent.
- Open: the right side is mirrored from the left (except the port and charging slot); the black
  controls are extruded silhouettes (could be shaped); the upper's side has no machining steps.

**uzi**
- Unchanged real Sketchfab Uzi; never part of the rebuild.

## Tools
- trace.py: Ref, clean, span_at, lathe with `reach` window.
- refs/*.json; refs/level.py (for tilted photos).
- The browser tracer JS is in this session's transcript: marching squares, Douglas-Peucker,
  rail-pitch scale.
