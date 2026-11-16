# Garden-wall surface contract

HouseKit's outside-only and full opaque shell commits share `res://scripts/map1/map1_garden_wall.tres`. `ShellMesh.material()` remains the original opaque standard material for doors, furniture, boards and other consumers. Panes and every collider statement retain their existing paths.

Only garden-wall bodies and ground-based gate pillars have input colour alpha 0.5. Coping uses alpha 1.0. The optional sixth argument to `ShellMesh.box` encodes marked vertices while appending their existing colours:

`alpha = 0.2 + 0.3 * height_above_box_bottom`

Current 1.55 m bodies and 1.80 m pillars produce alpha at most 0.665 and 0.740. Values at or above 0.9 remain unmarked. The nameplate extension reserves alpha 0.79..0.81; future marked heights must remain below 1.96 m unless the tag allocation is revised, including interpolated face values. Current block frames rotate around Y; the height contract assumes upright blocks.

RGBA8 storage gives approximately 13.07 mm per decoded height increment. This height drives the broad dirt band, with the existing 0.10 m buried footing removed. Fine 400 x 200 mm block courses use world position, not the packed height. The shader never writes opacity `ALPHA`.

The contact-dirt falloff extends to 0.55 m above each block's own ground foot. Its position does not depend on the camera. Casting-lot tones are shared over six blocks across two courses, with at most 3.5% linear-colour modulation. This is a quiet authored approximation of casting variation, not per-pixel noise or a literal construction simulation.

The material reuses `assets/procedural_textures/concrete_detail.png`. No texture import settings or new vertex attributes are introduced. The legacy detail map has no mipmaps; its fine modulation fades when its texels become unresolved. The ordinary unmarked path preserves vertex sRGB conversion, roughness 0.88, metallic 0 and specular 0.5.

The installed append-time encoder passed 26 structural checks: positions, normals, indices, RGB bytes, array format, surface count and unmarked alpha are preserved. Actual stored pillar alpha peaked at 0.737255, with decoded error below one 13.1 mm height bin.

An equivalent featureless custom material reproduced the same close-view one-byte RGB differences versus the original StandardMaterial3D. The wall-feature shader and that control had zero differing pixels in the unmarked swatch. Image checks therefore report both exact equality and equivalence within one encoded RGB byte; the raw difference count remains in each manifest. The distance swatch was exact. This is an explicit image-comparison allowance, not a world geometry or performance threshold change.

Native comparisons use the existing `frontage_gate` and `frontage_wall` cameras. Only matching opaque shell materials are switched to the original standard material for the baseline, then restored on identical meshes. Captures require the actual installed shader, existing concrete texture, one shared material and genuine encoded native vertices. No capture-time encoding adapter is used.

The final fixed-view three-box/floor ABBA fixture measured GPU medians 0.480 ms original and 0.484 ms wall material. The 0.004 ms difference is comparable to within-run block drift (0.002-0.0035 ms); source hashes and draw/triangle counts were stable. This does not establish whole-city rendering cost. The native same-picture scenario passed both assertions: seven live street houses plus 38 map samples retained matching full/outside solid and glass geometry/colours, and outside-only retained two meshes and three nodes without new collision.

### Native daylight damp isolation (2026-11-16)

`collaboration/wall_surface_native_capture.gd --isolate-damp` captures the installed native wall and an identical-camera counterfactual with only `base_dirt_strength=0` changed in memory, restoring the installed value immediately afterward. Six shots completed, no errors, and input hashes stayed unchanged. The restored installed gate PNG is byte-identical to the previous final native gate capture.

At the exact gate camera, 7x7 patches show encoded screenshot luma changes of175.65 to155.44 on the lower wall and174.56 to143.30 at the exposed base. Upper/middle wall patches and the foreground pavement are exactly unchanged. At x1450, the affected visible strip spans y673 through761, above the pavement beginning at762. This isolates the darkening to damp, independent of mortar/casting tones. These are encoded image values, not scene-linear luminance or an estimate of real buried height. Claude accepted the wall and withdrew the remaining damp-presence finding. Owner playtest is separate.


### Nameplate extension (2026-11-16)

The same opaque material now has a reserved nameplate front-face tag at alpha
0.8. Explicit block face metadata packs atlas coordinates in R/G and one of
three original palettes in B. That payload bypasses vertex sRGB conversion and
is excluded from the wall-height path. Current wall/pillar alpha ends at0.74,
so interpolated wall values never enter the nameplate range. Do not increase
marked wall heights across the reserved band without changing the contract.
The shader still never writes opacity; no UV/custom stream is added.

The prepared native encoder matched the tested wrapper in126 name/palette/frame
cases plus12 original wall/per-face controls:2,784 assertions, exact raw and
packed arrays (including native tangents), unchanged formats and inputs. The
shared R8 coverage resource preserves its complete mip chain byte for byte.
Production renderer files and direct HouseDress emission are installed and
accepted:656 native assertions,8 matched captures and the exact40-house count
pass. See `docs/NAMEPLATE_ATLAS.md` and `collaboration/road-discussion.md`.
All earlier wall-specific evidence above retains its original scope.
