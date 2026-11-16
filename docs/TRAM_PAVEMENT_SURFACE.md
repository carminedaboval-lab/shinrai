# Tram-street pavement

The tram street and its connected fork formerly used flat vertex colour for their
pavements. They now share the existing fine-asphalt shop-footway material across
straight paths, corners, wedges and traced island/mouth tops. The residential
lanes retain their existing finish at the agreed construction boundary.

Selected edge metadata families: tram street south; tram fork south; tram fork
island lane; tram fork island stub; tram mouth tip; tram mouth point; tram mouth
point diagonal; tram diagonal south a; tram diagonal south; tram diagonal south b.

`map1_blockout.gd` assigns the shared material and opts these edges into flat
pavement shading. `map1_street.gd` routes regular tops into Footway meshes and
post-build additions into WedgeTop/PavingTop meshes. Wedge coordinates use native
metres along/out; traced tops use an unclamped projection onto their straight
carrier so overhanging geometry retains its scale. Existing shop-row shading is
unchanged because the new flat-paving flag defaults to false.

The measured addition across eleven active selected sides is eleven Footways,
two WedgeTops and four PavingTops: seventeen mesh instances and fifteen opaque
surfaces, with no added triangles or collision. Two original Paving instances
retain empty meshes after their entire top is moved. All new tops share one
existing material, shader and existing aggregate/ORM textures. Up to fifteen
additional ordinary opaque submissions are possible when all added surfaces are
visible; shadow/depth passes are separate. No full-city GPU/FPS claim is made.

## Validation, 2026-11-16

The genuine pre-change native snapshot and final baseline/native captures use
five fixed cameras: gate, street, gate-to-kerb, inner fork and island stub. The
baseline disables only the selected material assignments before native building.
Sixteen active sides are checked, including five unchanged residential controls.

The final strict report `collaboration/tram_pavement_flat2_report.json` passes with
zero errors. Both arms exited with code 0, stderr was empty, listed source/input hashes
matched between arms and stayed fixed within each run. The new-source baseline
matches the genuine old snapshot exactly. Installed positions, oriented triangle
multisets, top normals, retained vertex colours/materials, all collider faces and
transforms, and residential controls also match exactly. The native material and
texture bindings and finite metre UVs are verified; the four traced UV ranges
span their actual multi-metre surfaces, with at most 15.3 micrometres of
UV-to-position reconstruction error.

Claude's integration checks passed: trial 47/47, homes 510/510, corners 282/282, corner shop 23/23,
and the kerbs section's four assertions. Following the final shading correction,
trial 47/47 passed again; walking suites were not repeated for a shading-only fix.
The full 83/83 world run predates this pavement step and is not presented as a
fresh full-suite result for this change.

The earlier strict comparison caught 24 changed top normals from default smooth
groups. Flat shading is now set at both regular top-tool creation paths and on
the standalone new top tools. The comparator also explicitly handles a wholly
consumed carrier that remains as an empty zero-surface mesh; provenance of that
postprocessing correction is retained beside the first capture pair.

Claude and Codex accepted this surface step. Owner playtesting and commit/push
approval remain separate.
