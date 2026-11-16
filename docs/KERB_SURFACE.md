# Kerb and gutter material

Status: installed and active on the agreed TRAM_PAVED family. Claude accepted
the actual city views and Codex accepted the independent native comparison on
2026-11-16. Owner playtesting remains separate.
The completed pavement pass is documented separately in
`docs/TRAM_PAVEMENT_SURFACE.md`.

Current scope note: Claude subsequently widened the same material assignment to
the95 metadata-defined street families (85 newly opted in) in Blockout SHA256
`2e0ff73117beb14ded1533c72b860a27e936346c1e0a9ddfe27da80f17206c26`.
That wider assignment is installed and independently accepted on2026-11-16.
Both fresh scoped arms passed with identical515 source pins and empty stderr. The separately constructed TurningCircleEdge remains
plain/default-off and is an explicit unchanged control. The completed native acceptance below remains specifically the tram
family comparison against five unchanged boundary controls; it must not be
represented as the widened-family control test. Blockout is held at the widened version
through the separate nameplate comparison, whose before/native arms both use
that same floor. No draw-call saving is inferred from different cameras.

## Ownership and data contract

Codex owns `map1_kerb_surface.gdshader`, its shared material and material tests.
Claude owns the optional Street interface and native geometry builder changes.
The approved street photo remains `docs/art_targets/street_target_01.webp`.

`marked_kerb` defaults to false. `kerb_surface_material` defaults to null. Marked
concrete stores alpha as `0.20 + 2.0 * actual_local_lift_metres`; RGB, positions,
normals and triangle order remain unchanged. Both ends of a lowered or ramped
unit use their own actual lift. End caps, grates, poles, hardware, pits, wires
and other unmarked geometry retain alpha 1. General triangle/quad helpers stay
unchanged. A separate default-off `cast_corner_tones` flag controls
the intentional curved casting/channel colour correction; it is independent
of marking so the mark-on/off RGB preservation can be tested.

RGBA8 ArrayMesh packing truncates alpha to bytes. One height step is
`1/(255*2)` metres, about 1.961 mm. The shader uses a smooth 40 mm contact falloff;
this signal is not an exact-height or collision input. It never writes opacity.
The packing rule is recorded in
[Godot's mesh colour packer](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/rendering_server.cpp#L650-L664).

## Material

One shared opaque material retains the existing vertex casting colours and adds
normalized luma detail from the already installed HGU150 PrecastCurb base-colour
PNG. Whole-image means: linear 0.1185226012, encoded 0.3784859383. Drain and EndCap
copies of the source texture are byte-identical. Roughness remains 0.92, metallic
0 and specular 0.5. The new material creates no joints, displacement, noise layer
or camera fade. A muted tint is confined to low road-contact height.

## Completed prototype evidence, 2026-11-16

- Staged high, lowered and sloping specimens: six same-camera shots, ten
  structural checks passed, empty stderr and unchanged input hashes.
- Unmarked grate controls match exactly. A close pole-control patch differs by
  at most one encoded RGB byte, and the eye-level control is exact. A featureless
  custom-shader control has the same bounded difference; candidate and
  featureless controls match exactly in all unmarked patches. Native scene
  acceptance remains separate.
- Balanced ABBA fixture: GPU medians 0.494 ms original and 0.494 ms candidate;
  paired deltas +0.004 and -0.002 ms versus 0.006 ms baseline drift. Two visible
  draw calls and 154 primitives remain unchanged. This is fixture evidence,
  not a whole-city GPU or FPS claim.
- Independent native straight-unit proof: 32 cases, 568 assertions passed,
  zero packed-byte mismatches. Maximum decoded-height error 1.814 mm. Geometry,
  winding, normals, RGB, indices, formats, caps and appended grate checks remain
  strict. Both sides, high/dropped/ramped profiles, sloped terrain and drain
  inlets are included.
- Independent curved and legacy proof: 2,867 assertions passed. Forty-eight
  corner/nose/fillet geometries match the genuine legacy opt-out; 96 marking
  pairs preserve geometry, winding, normals, indices and RGB with casting held
  false/true separately. Thirty-two original straight cases also match legacy.
  All caps/grates and packed bytes pass; maximum height loss is 1.941 mm.
  This callback matrix uses straight carriers; the native map comparison checks
  the selected family as actually built, including its bent carrier.

The initial probe's incorrect half-bin assumption failed and is preserved.
`kerb_straight_data_probe_contract_revision.json` records the explicit quantizer
correction, native packing evidence, old/new script hashes and reports. The
native height encoding did not change to satisfy the revised check.

## Native scene acceptance, 2026-11-16

The resource is bound only in Blockout's TRAM_PAVED branch, with `marked_kerb`
and `cast_corner_tones` enabled. The five boundary-control streets retain the
plain material. Both fresh five-view captures completed with empty stderr and
unchanged input hashes. `collaboration/kerb_native_report.json` reports `ok:true`.

Ordered geometry, normals, winding, mesh formats, colliders and node counts are
unchanged. The accepted 17 paving meshes remain (11 Footway, 2 WedgeTop and
4 PavingTop), with one shared paving material and one shared kerb material.
Intentional curved casting RGB changes are bounded and reported separately;
mark-only RGB preservation is covered by the held-style data matrix. Five
matched views cover the fork, island stub, frontage gate, frontage street and
gate-to-kerb connection. This comparison does not prove every player route or
whole-city frame rate.

Installed acceptance pins (SHA256):

- Kerb shader: `48dcc23ad487e528305cfe7910b4d74b32517910c9a60ab794153d3636422147`
- Material: `b1fdc9ecf5692d5a1ea148c2997ee74c7d1e65b6fc4aaa2855c12792e51cc340`
- Street: `708a59b1065eb8ddb1a56ed6337bd1e86df57ded755eb3d37f7c96ed3be597af`
- Blockout: `ade03591696053670124fd51886117e9f19ce118d2c9c1fca1205500d3084802`
- HouseDress: `c1bd4bfaa2aaafcc0ebe8d08771ef98fbc5fc8af12e5ff4bc0ee9f4990c2f757`

The source hold was released after the comparison. No commit or push has been
made. Owner playtesting remains separate.


## Expanded metadata-family acceptance, 2026-11-16

Both arms held Blockout2e0ff731, Street708a59b1 and the same saved warm-up source
(Dress640456eb). The baseline reset only the85 newly opted-in families; all10
accepted TRAM families remained active. Inventory covers95 metadata families,
190 configured side records,14 suppressed and176 with actual geometry, plus the
separate plain round control. One shared kerb material is bound.

`kerb_expansion_comparison.json` reports `ok:true`. Full ordered data for the
four expanded sample families plus TRAM/round controls preserves positions,
triangle winding, normals, formats, indices, colliders and node counts. Non-Edge
paving/material/UV data and control mesh data remain exact. Intentional bounded
corner-casting RGB changes are counted separately; the matching Street data
probe retains2,867 passing assertions for marker/legacy invariance.

Five matched views cover a residential corner, narrow residential lane, long
shop kerb, west shop corner and the round control. Codex visually reviewed the
four expanded views and accepts the same restrained finish Claude reviewed in
the city. The round remains default/plain and is the next separately scoped
opt-in. This evidence does not certify every traversal route, whole-city pixel
identity, draw-call savings or FPS. No historical ADE full-file diff is claimed:
the same current2e0f source was used in both arms. Both captures and all515
source pins stayed unchanged within/across arms.

Evidence lives in `collaboration/kerb_expansion_baseline/`,
`kerb_expansion_native/`, `kerb_expansion_comparison.json` and the frozen
`kerb_expansion_protocol.md`. The source hold is released after capture.


## Turning-circle acceptance, 2026-11-16

Blockout E8E3C773310F0E08E96F9D7BB76363A1F0F6B6AC2EB7A63F9A64640592280F9F
adds only the same guarded three kerb opt-ins to TurningCircleEdge. Reversing
that block/comment recovers the exact previously accepted2e0f source. Street
remains708a59b1; no geometry, paving or hardware interface was changed.

The independent actual-round data probe passed39 checks over80 native units.
It matches trace/native packed data and collisions, checks endpoint kerb-face
ground datums, native RGBA8 truncation and unmarked caps/footway. Actual terrain
under this arc is flat; this does not test a sloped round or hardware (the native
round is built with an empty hardware list).

The ring-only baseline/native pair exited0, empty stderr,3 matching views per
arm and unchanged matching pins. `kerb_round_comparison.json` is `ok:true`.
Positions, winding, normals, raw RGB, UV/index/formats, collisions and node counts
remain exact; only exposed concrete height alpha and the material assignment
change. All95 metadata-family bindings remain unchanged. No surface/triangle
addition or draw-call/FPS saving is claimed. Codex reviewed both flare joins and
the close channel/contact view and accepts the matching restrained finish.
Claude also confirmed actual-city visual acceptance on the shared board.

Evidence: `kerb_round_data/round_data.json`, `kerb_round_baseline/`,
`kerb_round_native/`, `kerb_round_comparison.json`, and frozen
`kerb_round_protocol.md`. The source hold is released. Later circle-asphalt work
is separate: the pre-repair inventory found9 global fillet sides but2 actual
approaches and0 CircleAsphalt meshes because the old selector returned early.
Its later restoration below adds the already-authored visual surface and is
not part of the preceding kerb proof.

## Circle asphalt restoration acceptance, 2026-11-16

Blockout97d8c569a6d211cbdd21e0d686a8543faa5b1dcab6f51ed4a763f064a170046d
records the two actual approach sides when the circle is constructed and uses
those references for the existing asphalt caller. The exact E8E3-to-current
diff contains this selector change and comments; Street's fan, UVs, lift and
material implementation remain unchanged. Claude confirmed the repair visually
in the city and reported a full world83/0 result.

Codex's controlled current-source pair omits only `_circle_asphalt()` in its
baseline, without reconstructing historical source. Both arms exited0 with
empty stderr and3 matched views. All519 input pins stayed fixed and matched.
`circle_asphalt_comparison.json` is `ok:true`: one native CircleAsphalt mesh,
one surface and one descendant beneath its existing StreetEdge approach;
291 vertices/97 fan triangles, no body/shape addition. Ordered fan footprint
matches the source-derived outline; metre UVs and the existing asphalt shader,
textures and no-line parameters pass. This trace is recomputed from pinned
native inputs, not a runtime interception or independently surveyed outline.

All existing ring/two-approach mesh, ordered geometry/RGBA/normals/UV/winding,
collision and node data stay exact. Lightweight95-family plus ring binding
controls also stay exact. Codex reviewed both joins and the close gutter view:
the plain patch becomes continuous textured road up to the channel, with no
new visible join seam or stray line in those views. The narrow restoration is
accepted by both collaborators. This does not certify whole-city geometry,
traversal or FPS. The source hold is released.

Final baseline/native PNG pairs and comparison report are under
`docs/qa/circle_asphalt_20261116/`; raw manifests, reviewed expected hash,
source diff and frozen protocol remain in the collaboration workspace.
