# Midori park flowers - provenance and game adaptation

Installed palette: white / violet-marked Japanese fringed iris and coral-red azalea. Original scan textures retained; no invented recolours or generated image assets.

## Iris japonica
Source: CC0 Crested Iris (Iris japonica), ffish.asia / floraZia.com.
https://sketchfab.com/3d-models/cc0-crested-iris-iris-japonica-f7895008d16a48cb93ed136352cffa63
License: CC0 Public Domain; commercial use allowed. Verified on model page and download dialog, 2026-10-05.

Unmodified download: staging flower_lush_qa/source/iris_japonica_original.glb.
Game adaptation uses the scanned open blossom and leaves. Calibration cube and spent flowering specimen excluded. Blossom scaled to approximately 5.5 cm across; only the lower stalk extended to give a 44 cm plant. Six scanned leaf fans per rhizome clump, leaning outward with small size variation; flowering clumps carry two adjacent rhizome shoots. Approximately 58 percent of leaf clumps flower. Runtime flowering height approximately 46-57 cm. This is an adapted single-flower shoot, not an exact reconstruction of a complete branched flowering stem.
LOD0: 6,353 stem/blossom triangles per flowering shoot + 6 x 616 leaf triangles per clump. Non-flowering clumps have leaves only.
LOD1: 1,651 stem/blossom triangles per flowering shoot + 6 x 616 leaf triangles per secondary clump; the main west carpet uses 3 x 616 leaf triangles per distant clump.

## Coral-red azalea (Rhododendron sp., Yamatsutsuji group)
Source: CC0 Azalea, Rhododendron sp., ffish.asia / floraZia.com.
https://sketchfab.com/3d-models/cc0-azalea-rhododendron-sp-2f5a16ad05db49bb83a9777031f9a530
License: CC0 Public Domain; commercial use allowed. Verified on model page and download dialog, 2026-10-05. Source does not establish an exact species/cultivar.

Unmodified download: staging flower_lush_qa/source/red_azalea_original.glb.
One existing scanned flowering sprig retained with its original coral-red petals and leaves, calibration cube and alternate specimen excluded. Sprig scaled to 12 cm across. Flowering tips assembled around the supplied broadleaf shrub structure; this is an adapted garden shrub, not a scanned whole azalea bush.
LOD0: 3,929 triangles per sprig. LOD1: 1,128 triangles per sprig. Fifteen sprigs per shrub.

Both models: reduced geometry, source textures resized to 2048 px, lit rough materials, two distance detail levels (7 m flower-shoot switch / 14 m leaf and azalea switch, 50 m cull, 1.5 m fades). Original supplied park assets remain unchanged.

## Botanical context
Tokyo Metropolitan Park Association lists fringed iris (Iris japonica) and azaleas in the Kiyosumi Gardens flower calendar:
https://www.tokyo-park.or.jp/teien/en/kiyosumi/calendar.html
Kew describes Iris japonica flowering stems 30-80 cm tall and flowers about 5 cm across:
https://powo.science.kew.org/taxon/urn%3Alsid%3Aipni.org%3Anames%3A438741-1/general-information

The pale Hirado azalea scan was evaluated but is not used in the installed red palette. Its source and prepared files remain archived in staging:
https://sketchfab.com/3d-models/cc0-hirado-azalea-r-x-pulchrum-4b71e4fd4250439f85c1aebe01eb945f

## Woodland placement reference (2026-10-06)
The user selected the shaga woodland photograph in this Japan Weather Association article:
https://tenki.jp/suppl/kous4/2020/04/17/29786.html
Reference image viewed in browser:
https://i-storage.tenki.jp/large-lite/storage/static-images/suppl/article/image/2/29/297/29786/2/large.jpg

Composition: repeated upright trunks, overlapping masses of iris foliage, pale flowers above the leaves, and visible woodland depth. Three bounded areas reuse the supplied Pine_big_1_LOD1 tree, keeping established trunk positions and never enlarging the measured crown radius. Eight authored branch-contact trees are protected. The existing model is a pine, not a cedar asset or an exact botanical match for the reference forest.

Iris colonies: one main organic west carpet, approximately 28 x 21 m before clearance masks, plus six smaller irregular colonies in the north and east groves. The larger west colony is rendered in 7 m spatial batches so detail changes remain local; its distant leaf clumps use three fans rather than six. Densely spaced leaf clumps follow the terrain; not every leaf clump flowers. Grass and taller companion vegetation overlapping the accepted flower footprints are thinned. Whole shrub and fern roots within the flower beds are hidden. Surrounding lush vegetation and fern pockets remain outside these beds, keeping the flowers readable. Companion mesh parts use shared whole-plant bounds so the pruning does not leave floating leaf or branch fragments. Secondary colony centres must be beneath a crown or its immediate shoulder. The main west carpet spans the established west woodland floor, with trunk openings and an irregular perimeter. Paths, water, functional clearings, trunks and planned asset sockets constrain every placement.

Azaleas: groups of adjacent shrubs at lighter grove edges, outside the main west carpet perimeter, with natural size/yaw variation and the original coral-red scanned flowering tips. Sites with more than one overlapping crown are excluded. The game uses a geometric canopy mask, not a soil-pH or horticultural simulation.

Botanical placement sources:
https://aiph.org/floraculture/news/plant-profile-iris-japonica/
Iris japonica spreads through creeping rhizomes into evergreen cover and grows well in partial shade with ferns.
https://www.rhs.org.uk/plants/rhododendron/growing-guide
Azaleas prefer sheltered, light dappled shade and moist, well-drained acidic soil.
Real azalea group photograph viewed:
https://akagishizenen.jp/blog/20250514
https://akagishizenen.jp/hubfs/cms/images/DSCN5270.jpg

The final separation pass follows the user request to avoid mixing plants until the flowers disappear. It reserves each accepted iris colony and azalea group as a readable patch, with taller vegetation at the perimeter. No source asset files are modified by this exclusion.
