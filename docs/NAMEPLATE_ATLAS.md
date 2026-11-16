# Native house nameplate atlas

Installed and accepted by Claude and Codex on 2026-11-16. The current 14 Japanese
surnames remain on their existing plate faces. The change replaces only the
supported vector word geometry with raster coverage; plate boxes, intercoms,
colliders, surname choices, palette choices and their random-call order remain.
Owner playtesting remains separate. No commit or push has been made.

HouseDress preloads `res://scripts/interior_kit/nameplate_atlas.gd`, selects the
same surname once, and appends the returned face metadata to the existing plate
block. Unknown names/palettes retain the old vector fallback. New names require
coverage validation; the separate Suzuki diagnostic does not change the source
list or imply that every fallback glyph is complete.

The 170x85x14mm plate keeps 24 vertices and 12 triangles. Only its four front
corners carry atlas endpoints in colour R/G, palette in B and alpha 0.8. The
shared opaque wall material recognizes that reserved tag, bypasses sRGB
conversion of coordinate data, and samples linear R8 coverage. It adds no mesh,
surface, node or UV/custom stream. Wall/pillar heights remain in their existing
alpha0.20..0.74 range; do not extend them through the reserved 0.79..0.81 band.
The shader never writes opacity. See `GARDEN_WALL_SURFACE.md` for that contract.

The atlas rasterizes the existing font selection (resolved to Yu Gothic,
weight 700), without downloading or distributing a font file. The 3060x765 R8
resource has 11 generated mipmaps beyond its base level and 3,119,589 payload
bytes, compressed to 181,374 bytes on disk. Full native reload preserves every
coverage byte. Payload size is not a measured VRAM claim. Resource SHA256:
`2dadd7398099758402bbddca9872dc04bb18c3b9a26513b66a390592a5755eb9`.

The installed close view keeps both 吉田 characters readable, with the same
orientation, stone tone and placement. Edges are slightly softer than the
vector original; this is not a pixel-identical renderer. The native fitted
extent is 103.890x52mm and raster ink 105.463x51.944mm. The physical plate face is
1mm behind the former floating text plane.

## Validation

- Font/packing bake: 177 checks; separate Suzuki diagnostic 205 checks. The
  original 14-name asset is unchanged by that diagnostic.
- Append-time encoding versus the tested wrapper: 2,784 assertions over 126
  marked cases plus 12 plain/per-face/wall-height controls. Exact raw/packed
  arrays, native tangent data, formats and absent extra channels passed.
- Serialized native material: 32 checks preserving wall parameters, original
  concrete binding, exact packed palettes and full R8 payload.
- Genuine pre-install typed snapshot: 29 checks. Installed native target 1721:
  656 checks and 8 matched captures, empty stderr and unchanged source pins.
  The independent pair comparator reports `ok:true`.
- Each full/look mode preserves all non-letter oriented position/normal/RGBA
  triangles, other meshes, colliders and node/surface/UV counts. Only 156 glyph
  triangles disappear for this house; four plate corners receive payload data.
  Existing differences between full and look door/pane representations are
  reported separately, rather than claimed identical.
- Exact same 40-house window: 203,966 triangles before versus 196,769 installed,
  with 28 tags, 0 remaining supported vector plate words and unchanged names/IDs.
  This removes 7,197 triangles. The 520-house projection is 2,557,997, 42,003 under
  2.6million; it is a projection, not 520 measured houses.
- Claude's post-emission world suite: 83 passed, 0 failed. Its separate actual-ring
  check reports 188 looks and about 0.90million triangles within the existing
 520-look/2.6million budget. No player FPS claim follows from these checks.

The failed staging probes are retained. An initial tangent-absence assumption
was corrected to match genuine native data. A baseline clone was replaced by
a typed old-box shim and nonempty proof guards. The installed comparison also
records the source-confirmed optional omission of `signs` when its list becomes
empty. That correction affects comparison data only; exact verifier transitions
are pinned and no native spec, mesh or tag was rewritten.

## Evidence and remaining scope

Final pairs are under `docs/qa/nameplate_atlas_20261116/native_final/`.
Full reports and frozen source provenance are in the collaboration workspace:
`nameplate_native_verify_v3/native_pair_report.json`,
`nameplate_installed_cost/before.json` and `native.json`,
`nameplate_native_expected_install.json`, and
`nameplate_owned_install_manifest.json`. The optional-empty-key correction
changes verifier pins only; the installed cost run's original expected-runtime
manifest is archived separately with the same game hashes.

The transitional pre-emission world runs exposed a cold spike and a Koban
visibility case. The final 83/83 run passes. Later fresh-process checks find the cold vector
path in both genuine old and installed code, with identical sign implementation;
those fixtures use representative café spacing and are not an exact replay of
the production café. The canonical sign warm-up now runs once from World's
setup, before player creation, and records actual cache hits/misses. Codex's
fresh-process `sign_warm_accounting_review.log` passed all3 checks, exit0 and
empty stderr:27 misses/0 hits,76.6ms total,16.5ms worst key,0.040ms cached repeat;
26 drawn keys are covered by27 warmed keys, with one unused trade reported.
This cost belongs to Blockout's loading/build time, not free covered gameplay.
Dress is5eda389ab044cd451c4cbaf3816ce558176ac5ea372df0dd2d611ef295a1d62f;
the reviewed probe isb1c23ef514c017cc2a56f01443fbf25ee52abb3a704f829f6a844d89f4b0453f.
Every failed probe assertion reaches the process exit code. Functional coverage
and startup accounting are accepted; these timings are one local measurement.
The intermittent Koban visibility follow-up remains with Claude. A warmed same-spec 1721 CPU fixture
measures old/native medians 2.9745/3.1300ms, about 0.16ms overhead before glyph
removal. That one-house fixture does not explain the cold spike or establish
whole-world performance. Neither threshold nor visibility tolerance was relaxed.

The widened kerb assignment has its separate acceptance documented in
`KERB_SURFACE.md`; this nameplate pair held Blockout 2e0ff731 unchanged in both
arms. It does not certify that expansion or unrelated streets/traversal.
