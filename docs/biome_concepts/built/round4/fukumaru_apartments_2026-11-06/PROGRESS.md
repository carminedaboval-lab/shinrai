# Fukumaru apartments — 6 November 2026

Installed three furnished, enterable apartments above the ramen shop: two compact studios (201 and 202) on the middle floor and the larger 301 flat with a separate front bedroom on the top floor. The east-alley stair connects both landings to the public pavement. Doors use the existing E interaction.

[Current building and rooms](rooms_now.jpg) · [Whole building and both stair flights](now/08_full_stair.png)

## 201 — front studio

[Before | now | concept](comparison/201_front_studio.jpg). Blue futon with a real pillow, low table and floor cushion, steel kitchenette, miniature refrigerator, ceramic mugs, towel, soap and shelf plant. Rounded fabric, cream curtains and warmer timber replace the initial rigid surfaces. The layout matches the source screenshot. Cloth detail and bounced daylight remain simpler than the concept.

## 202 — rear studio

[Before | now | concept](comparison/202_rear_studio.jpg). Storage bed with cream bedding and a blue foot cover, desk/lamp/books/pencils, kitchenette, framed park print and household objects. The bedroom no longer contains geometry from the neighboring gallery. The broad furniture positions follow the concept; the bed covers and cupboard faces are still more uniform than the reference.

## 301 — upstairs flat

[Before | now | concept](comparison/301_living_kitchen.jpg). Upholstered sofa, cushions and throw, kitchen with kettle and drying rack, dining table and wall art, separate double bedroom and fitted bathroom. Both the neighboring gallery and a curtain protruding into the bathroom were corrected. Furniture and walking routes match the intended plan. Runtime wall/metal lighting is flatter than the generated artwork.

## Verification

The installed live source passed the actual player/access-service route: all 48 checkpoints and 2,342 grounded samples, three doors opened, all bathroom thresholds crossed, both stair flights climbed and descended, and return to the public pavement. [Installed route](evidence/installed_walk.json), [tested code hashes](evidence/installed_walk_hashes.json), and [installation receipt](evidence/installed_sources.json). No production saves were used. Visual/floor-feel acceptance remains with the user.

The seven final Vulkan captures use the actual streamed city tile and unchanged camera transforms. [Capture manifest](evidence/capture.json) and [source hashes](evidence/source_hashes.json). The additional whole-stair picture isolates the building for a clear elevation. Night pictures show the near-final version; the only later change removes the hidden curtain panel in 301's wet room. Native runs completed without script/shader errors; the city fixture's pre-existing seven-Texture shutdown warning remains.

Observed room frame intervals were 4.39 / 5.07 / 5.28 ms, compared with 3.76 / 4.11 / 4.60 ms before the concept pass. That is approximately +0.63 / +0.96 / +0.68 ms, with +5 / +6 / +6 visible draws. Total shop ArrayMesh triangles are 51,236. [Raw timings and limitations](evidence/cost_comparison.json). These are indicative isolated-tile measurements; another task used the shared GPU during this work, so they do not establish full-raid FPS or a contention-free performance comparison.

The installer preserved original scripts in the workspace's fukumaru_apartments_qa/prior folder and verified all 15 source/UID files. Approved sakura files and unrelated weapon work were not edited. Nothing was committed.
