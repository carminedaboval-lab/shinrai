# Independent Midori shop identities

Original custom forest/cafe, book, produce/sun, skewer/ember and ceramic-maker seal geometry was authored for Shinrai. No stock icon library, raster generation, or Meshy assets were used.

All lettering is converted to SVG paths. Noto Sans JP / Noto Serif JP provide restrained shop lettering; genuine Yuji Boku calligraphy provides Yakitori fascia; genuine marker-derived Yusei Magic provides the produce offers. Unmodified SIL OFL notices are included. FONT_PROVENANCE.json and DISPLAY_FONT_PROVENANCE.json record official source URLs and SHA256 hashes. Fonts are staging build dependencies only and are not required at runtime.

Produce offer copy is authored fictional shop content: 本日の青果 / みかん / 3個 280円 / 季節の野菜 / 地元産 入荷. These are fictional prices, not claims about a current retailer.

Mori letters are three closed extruded meshes, not a quad. Font contours were united using Skia path operations to remove overlaps, flattened with preserved holes, extruded to 20 mm solid depth and lightly bevelled. Native local artwork reads from -Z; local X is mirrored for that front view. Geometry report and imported-mesh validation accompany the GLB. All three meshes have zero nonmanifold and zero boundary edges after welding glTF seam duplicates at 1 micrometre.

Haku plaque is a 360 x 440 x 28 mm ceramic solid with rounded perimeter and actual boolean recessed Japanese ハク / 陶器 plus a small maker-dot pocket. Recess depth is 2.2 mm, with a subtle ceramic patina material in recess floors. Geometry check reports zero boundary and zero nonmanifold edges. It is not printed or a flat overlay. Its native front is -Z. Both GLBs contain no lights, cameras or colliders.

All SVGs parse as XML and have no text, image, script or external reference dependencies. Dimensions and hashes are in manifest.json. CPU previews show artwork on separately represented substrates and are staging art reviews; installed player-height and game lighting acceptance belongs to the integration owner.
