# Island nature assets
New sources: Poly Haven Rock Moss Set 01 (Kless Gyzen), https://polyhaven.com/a/rock_moss_set_01 ; Moss 01 (Rob Tuytel), https://polyhaven.com/a/moss_01 . CC0: https://polyhaven.com/license . Downloaded 2026-10-06, API file MD5 checks passed for dependencies.
Original glTF, buffers and 2K maps retained in staging island_asset_qa/source. Runtime derivatives centre each existing mesh at its base and export individual GLBs. No invented geometry or recolouring. Moss source opacity is packed into diffuse alpha, then uses alpha scissor in Godot; fronds retain source centimetre scale.
Six stone variants, 12 moss frond variants. Stones use original diffuse/normal/roughness maps; placement sinks their bases 18 percent of scaled height. Stone groups have unequal widths of 2.2, 1.3, .85 and .65 metres where land clearance permits. Existing supplied fern/shrub assets form low planting pockets.
Composition reference: https://www.tokyo-park.or.jp/teien/en/kiyosumi/view.html . This borrows a pond-island stone composition, not a claim that the rock scan came from Japan or a named Japanese moss species.

Installed final composition: 25 stones (four per island on six islands, one main stone on the smallest islet), 111 supplied low fern/shrub plants, 33,415 moss fronds. Stone groups share one source material; moss variants share one source material. Stone convex hull collisions follow the imported mesh and placement transforms. Moss and foliage have no new collision.

Mainland reuse: rock_03.glb now also supplies six solid cover sites, with exposed height 1.558-1.722 m and a 140 m visibility range. The scan and its textures are unchanged. See MAINLAND_COVER_REVIEW.md in the park asset folder for installed placement/physics evidence.
