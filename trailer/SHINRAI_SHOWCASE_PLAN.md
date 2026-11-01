# SHINRAI — Multiplayer Showcase Trailer Plan

Format: narrated gameplay showcase in the style of the Call of Duty: Ghosts multiplayer reveal. One calm, confident narrator walks through the game feature by feature over "gameplay" footage. Target length 2:30 to 2:45, 1920x1080, 30 fps. No cinematic, no story cutscene: every picture should read as play.

The game is not ready, so the footage is built from three sources that must look like one capture:

| Source | What it is | Share of the cut |
|---|---|---|
| ENGINE | Real Godot captures from `tests/trailer_capture.gd` (free camera, HUD off) | ~45% |
| STAGED | Real first-person captures from `tests/trailer_staged_capture.gd`: the live player, view model and HUD driven by scripted input (sprint, mantle-aim, lean, jump-ADS, doors, relay approach), plus the HQ menu and transparent HUD plates | ~15% |
| AI | Stills and image-to-video clips generated from engine stills as seed frames | ~40% |

Anything with a squad, a firefight, a building climb or another player is AI. Anything that is just the park, the light, the drones patrolling, the gates and the lake is ENGINE. The HUD is always the real HUD.

The narration is written with working defaults; section 7 lists each default and what the code settled. Only `[STUDIO]` is still blank.

---

## 1. Rules for faking gameplay convincingly

1. Seed every AI shot from an engine still. The rendered stills are in `trailer\engine\stills\` and the matching 1080p clips in `trailer\engine\clips\` (the capture script writes them to `%APPDATA%\Godot\app_userdata\Shinrai\trailer\` first). Image-to-video from those frames keeps the trees, lamps, paving and grade identical to the real captures. Text-to-video from scratch will drift into generic Unreal-looking footage and the cut will fall apart.
2. Keep AI shots short: 2 to 4 seconds. Long AI clips reveal themselves. Cut on action.
3. Never let the AI shot carry a mechanic. The narration states the mechanic, an ENGINE or STAGED shot shows it, the AI shot shows the result (an operator on the roof, a squad at the gate). The viewer connects them.
4. Real HUD on everything first person. The AI clip is the background plate; the HUD is a separate layer. That one detail does most of the selling.
5. One grade. Export every ENGINE clip, build a single LUT in Resolve from the day and night looks, apply it to the AI clips too. Add a touch of the engine's TAA softness (light gaussian, 0.3 px) to AI clips so they stop looking sharper than the game.
6. No faces larger than a quarter of the frame. Operators wear helmets, hoods, respirators. Hands and weapons in first person only in STAGED shots, from the real view model.
7. Do not show anything the design will not ship. A trailer promise is a promise.

---

## 2. Script

Narrator: male or female, mid-40s, unhurried, dry. Think a field briefing, not a hype reel. Music under at -18 dB until the PvP beat, then it opens up.

Timecodes are targets. VO lines are written to be read at about 2.5 words per second.

### Beat 0 — Cold open (0:00–0:14)

| Time | Picture | Source |
|---|---|---|
| 0:00 | Black. Rain and distant traffic. A radio click. | audio |
| 0:03 | d01_aerial_establish: high dawn drone shot over Midori Park, New Tokyo skyline behind. | ENGINE |
| 0:09 | n07_aerial_city_glow: same move at night, neon city. | ENGINE |
| 0:12 | Title card: SHINRAI. | graphic |

VO: "New Tokyo. Twenty fifty. Eight months ago the city's AI stopped taking orders. It kept the lights on, the trains running, and the police drones patrolling. It just stopped asking anyone what they wanted. Midori Park was the first place it sealed. It has been open for business ever since."

(Backstory rule: the takeover is recent, so the park looks maintained, not ruined. Lamps work, signs glow, lawns are cut. The wrongness is that nobody is allowed in. Scav camps and cut fences are the only decay. Keep every AI shot consistent with that: no rust, no vines, no post-apocalypse.)

### Beat 1 — This is Shinrai (0:14–0:40)

| Time | Picture | Source |
|---|---|---|
| 0:14 | d02_south_gate_push with HUD plate: walking in through the open south gate at day. | STAGED |
| 0:19 | AI: four operators moving in a loose line through the south gate, seen from behind, lamp bollards either side. Seed: d02 still. | AI-VIDEO |
| 0:22 | d03_torii_plaza: neon torii plaza at day. | ENGINE |
| 0:26 | HUD plate close-up: relay counter 0/3, raid timer. | STAGED |
| 0:29 | AI: one operator holding a hand on a Japanese path lamp, kneeling, squad covering. Seed: a lamp still from d03/d04. | AI-VIDEO |
| 0:33 | d04_lake_edge: the lake, bridges, deck. | ENGINE |
| 0:37 | n06_west_gate_exfil with HUD extraction bar. | STAGED |

VO: "Shinrai is a twelve-player extraction shooter. You drop into the park as a squad of four. Three telemetry relays are hidden on the lamp network. Recover one and you've earned your ticket out. Recover all three and the contract pays. Everything you carry out is yours. Everything you carry in, you can lose."

### Beat 2 — The park (0:40–0:58)

| Time | Picture | Source |
|---|---|---|
| 0:40 | d05_sakura_grove: west grove, sakura. | ENGINE |
| 0:45 | d08_playground_pan, d09_pavilion_east: quick cuts. | ENGINE |
| 0:50 | AI: operator prone under the fence gap, grass in foreground, bolt cutters on the chest rig. Seed: night hole still (`perimeter_qa/hole_night.png`). | AI-VIDEO |
| 0:53 | n01_gate_smashed: the smashed south gate at night. | ENGINE |

VO: "Four hundred and forty metres of park. A lake, seven islands, the groves, the pitches, the plaza under the torii. By day the gates stand open. By night they're chained, the main gate is down, and the only ways in are the holes someone else cut before you."

### Beat 3 — Movement (0:58–1:26)

This is the Ghosts "contextual lean / slide" slot. Five mechanics, each stated once, shown once, all performed by the same squad in the same block of the park (the shopfront street beyond the torii plaza), so the beat reads as one run rather than a montage.

| Time | Picture | Source |
|---|---|---|
| 0:58 | STAGED: first person sprint along a park path, camera weight, hard stop at a low wall, the view settles. | STAGED |
| 1:01 | AI: first person mantle over a planter wall, weapon still raised and tracking a drone mid-mantle. Seed: d07_cover_lattice still, with the real arms plate over it. | AI-VIDEO + HUD |
| 1:05 | AI: first person coming to a shopfront corner, the camera leans out around it, sights up, a scav 20 m down the street. Seed: `visual_fx_qa/compare_after_main_street.png`. | AI-VIDEO + HUD |
| 1:09 | AI: third person, operator throws the anchor at the roof edge of the yakitori shop, line goes taut, they go up the wall hand over hand. Seed: yakitori facade still. | AI-VIDEO |
| 1:14 | AI: first person, halfway up the wall, one hand on the line, pistol up, firing down at the same scav. Real HUD, real pistol view model plate. | AI-VIDEO + HUD |
| 1:18 | STAGED: jump from the roof edge to a lower awning, aim down sights in the air, land heavy, camera dips and recovers. | STAGED or AI |
| 1:22 | AI: operator landing from the awning into the plaza, knees bent, squad passing. | AI-VIDEO |

VO: "Movement has weight. You sprint, and you feel it when you stop. You mantle with your weapon up, and you can shoot before your feet are down. Lean around a corner before you commit to it. The anchor puts you on any roof in the park, and you can fight on the way up. Jump, and your sights still work. Fast, but never floaty."

### Beat 3b — The buildings (1:26–1:40)

| Time | Picture | Source |
|---|---|---|
| 1:26 | ENGINE/STAGED: first person pushing a shop door open (the real building-access door, if a capture of it frames well), interior beyond. | ENGINE |
| 1:30 | AI: operator clearing a dim shop interior, counter, shelves, light through shoji panels, teammate at the door. Seed: an interior capture or the yakitori interior still. | AI-VIDEO |
| 1:34 | AI: looking down from an upper-floor window of the clubhouse onto the plaza, two operators crossing below. Seed: d03 still. | AI-VIDEO |
| 1:37 | STAGED: loot prompt on a shelf unit, bag count ticking up. | STAGED |

VO: "Nearly every building in and around the park opens. Shops, the clubhouse, the pavilion, the apartments over the street. Every floor is a route, a loot run, or a place to hold."

### Beat 4 — The set piece: contact at the torii plaza (1:40–2:14)

One continuous staged engagement, built like a scene: our squad (the same four operators from Beat 1, identified by silhouette and a colour tag per operator) goes for the relay on the lamp at the neon torii plaza. It is written so every shot answers the one before it. Music opens up at 1:56. (The pavilion in the game is still a placeholder pad, so the plaza, which renders beautifully in both day and night captures, is the stage instead.)

Geography: the torii on its lit ring at the plaza centre, benches and planters south of it, the lake deck to the west, shopfronts beyond the fence to the east. Keep screen direction consistent: our squad moves left to right, the threat comes from the right.

| Time | Picture | Source |
|---|---|---|
| 1:40 | d03_torii_plaza at dusk grade: wide, the plaza, quiet. Two of our operators at frame left behind the planters. | ENGINE + AI |
| 1:44 | AI: a scav crew of three around the torii base, one on a knee behind a planter watching the approach, one on a radio, one at the vending machine. They are alert and spread, not idle. Seed: d03 still. | AI-VIDEO |
| 1:48 | STAGED: first person, our lead signals hold, the HUD shows a relay 40 m out. | STAGED |
| 1:51 | AI: our flanker moving right along the bench line, low, while the scav watcher's head turns toward the sound. | AI-VIDEO |
| 1:55 | AI: the scav watcher fires first; the crew splits, one runs to the far torii pillar, one goes prone behind the planter. They flank, they do not stand still. Seed: d03 still. | AI-VIDEO |
| 1:59 | AI: first person suppressing across the plaza ring, tracers, a scav sliding behind the torii pillar, real HUD. | AI-VIDEO + HUD |
| 2:03 | d06_drone_patrol then AI: a police drone arrives from the lake path at speed, searchlight on, and engages the scavs first, because they fired first. | ENGINE + AI |
| 2:07 | AI: wide, drone and scavs trading fire under the torii, our squad using the moment to run the relay: one operator's hand on the path lamp, two covering. | AI-VIDEO |
| 2:11 | STAGED: relay counter ticks to 1/3, extraction opens on the HUD, drone searchlight swinging toward camera. | STAGED |

VO: "The scav crews who live in the park now are not targets. They watch the approaches, they flank, they pull back when it goes wrong, and they fight the drones too. The drones answer whoever shoots first. Use that. Recover the relay while the park argues with itself."

### Beat 5 — PvP: the other squads (2:14–2:30)

| Time | Picture | Source |
|---|---|---|
| 2:14 | AI: our squad pulling back west along the lake deck, another squad (different colour tags) already on the arched bridge ahead. Both freeze. Seed: d04 still. | AI-VIDEO |
| 2:18 | AI: first person suppressing across the water, tracers, real HUD. Seed: d04 still. | AI-VIDEO + HUD |
| 2:22 | AI: night now, muzzle flashes under the torii, neon reflections on wet paving. Seed: n02 still. | AI-VIDEO |
| 2:26 | STAGED: HUD, the raid clock reads 0:38:12, and a second line: NEXT TRAIN 01:47. | STAGED |

VO: "And every other squad in the park wants the same three relays. Three squads per raid. Kill a carrier and their cargo is yours. A raid can run two hours. You can leave after ten minutes. The question is whether you can afford to."

### Beat 5b — The Line (2:30–3:00)

The signature mechanic, and the trailer's climax. Extraction is a one-way train. It leaves every ten minutes from the first ten minutes of the raid, and the line has twelve stops around and outside the city. Every stop is a place squads converge, so every departure is a fight. Shoot this as one continuous sequence: the squad runs for the train, the platform, the doors, the ride out. Music peaks on the doors closing, cuts dead as the train clears the platform, one hit on the logo.

| Time | Picture | Source |
|---|---|---|
| 2:30 | STAGED/AI: night street outside the fence, the big 新東京 billboard (the one in `perimeter_qa/south_gate_night.png`) flickers from its advert to a transit map: a pulsing dot for the player, a route to the nearest station, a countdown at 02:00. Our squad looks up at it. Build the screen graphic yourself and composite it onto the engine capture; do not let the AI invent the map. | STAGED + graphic |
| 2:33 | AI: wide, night, an elevated rail line beyond the park fence, a train's headlights coming around the curve, the station lit against the city. Seed: n07 aerial still or `visual_fx_qa/compare_after_main_street.png` at night. | AI-VIDEO |
| 2:35 | AI: a rival squad under a different screen two streets over, looking up at the same map. Seed: the billboard still. | AI-VIDEO |
| 2:37 | AI: our four sprinting up station stairs, the wounded one helped, muzzle flashes from the street behind. | AI-VIDEO |
| 2:41 | AI: the platform. Another squad already there behind a vending machine and a pillar. A police drone on the far platform turning toward the noise. The train sliding in, doors not yet open. | AI-VIDEO |
| 2:45 | AI: first person, leaning out from a platform pillar, firing down the platform, real HUD, door-chime audio. | AI-VIDEO + HUD |
| 2:49 | AI: doors open, both squads break for different carriages, one operator dragged in by the strap as the chime sounds. | AI-VIDEO |
| 2:53 | AI: interior, the carriage, our squad on the floor and seats, breathing, through the window the platform slides away, the drone's searchlight sweeps the glass. | AI-VIDEO |
| 2:57 | AI: exterior, the train crossing above the city, neon below, the park dark behind it. Cut to black on the crossing bell. | AI-VIDEO |

VO: "Extraction is the Line. One way out, every ten minutes, twelve stops around and outside the city. Two minutes before each departure, some of the city's screens will show you where you are and where the nearest platform is. Some. And everyone else can read them too. Every platform is a meeting place, and nobody on it wants to share the carriage. Miss the train, and you have ten more minutes in the park."

(The screen rule is a gameplay promise and a visual signature: the AI runs the city and chooses when to help. Make the map graphic look like a transit board, not a game minimap: white route line, station kanji, a sans-serif countdown, the dot pulsing at the player. Keep the HUD's own timer modest or absent here so the screen is the only source of the time; default: the HUD does not show it, the screens are the only source.)

(For the AI-VIDEO shots here, generate the station once as a still and reuse it as the seed for every platform shot so the geography holds. Suggested look: a small elevated suburban station, two platforms, a glass shelter, the same green mesh fence motif, kanji station sign, a vending machine, a drinks-can recycling bin. Station name in-world: 緑公園前 Midori-kōen-mae, "Midori Park Front".)

### Beat 6 — Progression (3:00–3:14)

| Time | Picture | Source |
|---|---|---|
| 3:00 | STAGED: Field Operations screen, stash, credits, cargo slots. Captured from the real HQ menu. | ENGINE UI |
| 3:04 | AI stills: three weapon renders on a dark bench, SHIGURE S-9 (SMG), RAIDEN R-56 (assault rifle), HAYATE H-7 (bolt sniper), 1 s each with a slow push. Nameplate in the HUD font under each. | AI-STILL |
| 3:08 | STAGED: buying a cargo upgrade, then the extra medkit. | ENGINE UI |
| 3:11 | STAGED: Loadout & Inventory screen, a Patrol vest and a found KITE K-12 being equipped. (HQ is a menu in the game, so there is no locker-room shot.) | ENGINE UI |

VO: "Sell what you extract. Buy cargo, buy medical. Everything else you find out there, and the better it is, the harder it is to bring home. Your stash survives. Your kit does not."

(Weapons are found in security cases, not bought; the only purchases are pack upgrades and medkits. The VO states that as a feature rather than hiding it. Weapon names in the game: UZI, SHIGURE S-9, KITE K-12, RAIDEN R-56, TOBIKAGE T-65, HAYATE H-7, YUZURU YZ-10, AKANE A-9 pistol starter.)

### Beat 7 — Close (3:14–3:26)

| Time | Picture | Source |
|---|---|---|
| 3:14 | n07_aerial_city_glow, slow, the rail line's lights threading through it. | ENGINE |
| 3:19 | SHINRAI logo (信頼 small beneath it). Line under: "Catch the last train." | graphic |
| 3:23 | PC · Wishlist on Steam · [STUDIO] | graphic |

VO: "Shinrai. Wishlist now."

Running length with these beats is about 3:25, which is in line with the Ghosts reveal. If it must come in under 2:45: cut Beat 3b to one shot, drop the night torii shot in Beat 5, shorten Beat 2 to two shots, and move Progression to a 6-second HUD-only pass. Never cut the train.

---

## 2b. Variety and the Japanese feel

Variety is the difference between a showcase and a loop of the same lawn. Every beat changes at least two of: location, time of day, camera distance, weather. Rough map of the cut:

| Beat | Location | Time | Distance |
|---|---|---|---|
| 0 | aerial, city | dawn, night | far |
| 1 | south gate, torii plaza, lake | day | medium, first person |
| 2 | west grove, playground, pavilion, fence | day to night | wide |
| 3 | shopfront street | overcast day, light rain | first person, close |
| 3b | shop interior, clubhouse upper floor | day | interior |
| 4 | pavilion, east lawn | dusk | medium, first person |
| 5 | lake deck, bridge, torii, west gate | night | wide to close |
| 6 | HQ | interior | close |

Japanese texture, in every AI prompt and in what you ask the engine captures to frame: sakura and maple, stone path lamps, the neon torii, shoji light through shop windows, vending machines, kanji signage (新東京, 焼鳥, ひなた商店 already exist in the game: reuse them, never invent kanji that might read wrong), red paper lanterns on the yakitori shop, bicycle racks, koi in the lake, crows on the fence, a convenience store glow, umbrellas on a scav camp. Rain for one beat only (Beat 3), so the wet neon reflections land once and feel earned.

Also use the game's own sound world for it: crows, cicadas at dusk, a train crossing bell in the distance, a convenience-store door chime when a building opens.

---

## 3. Engine shot list

Rendered by `trailer\RENDER_TRAILER_SHOTS.cmd` (stills only, about 3 minutes per pass) or `RENDER_TRAILER_SHOTS.cmd clips` (every frame of every shot dumped as a 1080p JPEG, then `cut_trailer_shots.py` encodes one H.264 MP4 per shot into `clips\`). Output folder: `%APPDATA%\Godot\app_userdata\Shinrai\trailer\`; the finished stills and clips are also copied into `trailer\engine\` in the project (git-ignored). Godot's own movie writer is not used because it records the 1280x720 window the project forces, whatever flags it is given.

| Shot | Time of day | Move | Used in |
|---|---|---|---|
| d01_aerial_establish | day | high aerial push toward the park, skyline behind | Beat 0 |
| d02_south_gate_push | day | walk in through the south gate | Beat 1 (STAGED) |
| d03_torii_plaza | day | dolly toward the neon torii | Beat 1 |
| d04_lake_edge | day | lake edge, bridges, deck | Beat 1, seeds |
| d05_sakura_grove | day | through the west grove | Beat 2 |
| d06_drone_patrol | day | 80° orbit around the nearest police drone | Beat 4 |
| d07_cover_lattice | day | camera at prone height inside tall grass on the south lawn (reads as a prone POV) | Beat 2 fence-gap seed, Beat 3 |
| d08_playground_pan | day | red maple, playground, skyline | Beat 2 |
| d09_pavilion_east | day | boulder cover in front of the reserved pavilion pad with a scav tent (the pavilion art is not in yet) | Beat 4 scav-crew seed only |
| n01_gate_smashed | night | walk up to the smashed south gate, a scav silhouette on the paving | Beat 2 |
| n02_torii_neon | night | torii in pink neon on its lit ring, vending machine | Beat 5 seed |
| n03_fireflies_grove | night | grove with fireflies, path lamp at frame edge | Beat 2 |
| n04_drone_patrol | night | four drones under a red maple and a path lamp, shop signs behind | Beat 4 |
| n05_lake_lamps | night | lake with the bridge and lit skyline | Beat 5 seed |
| n06_west_gate_exfil | night | path lamps toward the west fence and shopfronts | Beat 1, 5 (STAGED) |
| n07_aerial_city_glow | night | low aerial over the south lawn to the neon skyline | Beat 0, 7 |
| n08_billboard_street | night | the 新東京 billboard street seen from inside the gate | Beat 5b transit-map composite |

Camera positions live in `tests/trailer_capture.gd`. Adjust `pos`, `look`, `fov` and `seconds` per shot and re-run; the stills are the fast way to check framing before a movie render. The free camera parks the player far outside the south-east fence so no body or view model wanders into frame.

### Staged shots, HUD plates and HQ menu

Rendered by `trailer\RENDER_TRAILER_SHOTS.cmd staged` (stills) or `RENDER_TRAILER_SHOTS.cmd staged clips`, which runs `tests/trailer_staged_capture.gd` in its `--hq`, `--plates`, `--shots` and `--shots --night` modes. The player, view model and HUD are the real ones; the harness only teleports the player and feeds `sr_` input actions, so every mechanic shown is the shipped code. Positions come from the harness's `--probe` mode, which writes doors, relays, exits and drone groups to `probe.json`.

| Shot | Light | What happens | Used at |
|---|---|---|---|
| s01_gate_walk_in | day | walk in through the south gate, HUD live, 0/3 | 0:14 |
| s02_sprint_stop | day | sprint up the entry path, release, the view settles | 0:58 |
| s03_mantle_aim | day | run at the 1.15 m planter row by the south path, mantle with aim held, sights up before the feet land | 1:02 |
| s04_corner_lean | day | lean right then left from cover at the torii plaza, aiming | 1:05 |
| s05_jump_ads | day | sprint, jump, aim in the air, heavy landing | 1:18 |
| s06_door_push | day | open a south-street shop door and step inside | 1:26 |
| s06b_clubhouse_door | day | the clubhouse front door as the alternative interior | 1:26 alt |
| s07_relay_approach | day | walk toward the south garden relay, crouch, hold | 1:48 |
| s08_west_exfil_hud | night | west exfil path with one relay banked | 0:37, 2:11 |
| s09_drone_searchlight | night | the south-garden drone group sweeping toward camera | 2:11 |

HUD plates land in `plates\` as 1920x1080 PNGs with alpha, one per narrated state: `p01_start_0of3`, `p02_relay_1of3`, `p03_extraction_bar`, `p04_next_train` (the NEXT TRAIN line is a trailer mock added by the harness, not game UI), `p05_urgent` (timer under 90 s goes red), `p06_loot_prompt`, `p07_locked`. Drop them as a top track over AI first-person shots; no keying needed. HQ captures: `hq01_field_operations.png`, `hq02_buy_sequence` (a 3.6 s clip: cargo upgrade then medkit), `hq02_after_purchase.png`, `hq03_loadout_inventory.png`, from a staged mid-career profile (1,840 credits, 7 of 11 runs extracted, one pack upgrade).

---

## 4. AI prompt sheet

### Style bible (prepend to every prompt)

> Realistic third-person game capture, modern real-time engine render, 1080p, slight temporal anti-aliasing softness, neutral grade with cool shadows and warm light, overcast New Tokyo 2050, Midori Park: Japanese public park with sakura trees, green mesh fence, Japanese stone path lamps, neon torii gate, mossy boulders, wooden arched bridges over a lake, emergency cover barriers and sandbags, low-rise Japanese shopfronts with neon kanji signs beyond the fence. Operators wear civilian-paramilitary rain gear, hoods, respirators and small backpacks, carrying compact submachine guns and pistols. The park is sealed but maintained: working lamps, cut lawns, clean signage, no rust, no ruins, no vines. No faces. No lens flare, no film grain, no letterbox. Matte, not glossy.

Night variant: add "moonlit blue night, deep blue sky, warm sodium path lamps, neon pink and cyan signage glow, fireflies".

### Image prompts (generate stills, pick one, then animate)

- **AI-01 Squad at the gate**: "[style] four operators walking through an open park gate in loose file, seen from behind at hip height, lamp bollards either side, paved entry, daylight" — seed: d02 still.
- **AI-02 Relay hold**: "[style] one operator kneeling with a gloved hand pressed to a stone Japanese path lamp, holographic ring around the lamp base, two teammates covering outward, sakura behind" — seed: d03/d04 still.
- **AI-03 Fence gap**: "[style, night] operator lying prone, crawling under a cut gap in a green mesh fence, grass in the foreground, bolt cutters on chest rig, lamp light" — seed: `perimeter_qa/hole_night.png`.
- **AI-04 Mantle aim** (first person): "[style] first person view mantling over a concrete planter wall, left hand on the wall edge, right hand holding a pistol raised toward a quadruped police drone 15 m away" — seed: d07 still. Composite real arms plate on top if the hands look wrong.
- **AI-04b Corner lean** (first person): "[style, light rain] first person view leaning out from the corner of a wooden Japanese shopfront with red paper lanterns, submachine gun sights up, a hooded scavenger 20 m down a wet street with neon kanji signs" — seed: `visual_fx_qa/compare_after_main_street.png`.
- **AI-04c Shop interior**: "[style] operator moving through a dim Japanese shop interior, counter, shelves of goods, daylight through shoji panels, teammate silhouetted at the door" — seed: an interior capture if the door opens on camera, else the yakitori facade still.
- **AI-04d Upper window**: "[style] view from an upper-floor window of a park clubhouse down onto a plaza with a neon torii, two operators crossing below" — seed: d03 still.
- **AI-05 Throw anchor**: "[style] third person, operator throwing a compact grapple anchor with a thin line at the roof edge of a two-storey Japanese shopfront, line trailing, arm extended" — seed: `visual_fx_qa/compare_after_main_street.png` or the yakitori shop still.
- **AI-06 Climb and fire** (first person): "[style] first person, hanging from a taut climbing line against a wooden shopfront wall, left hand on the line, right hand firing a pistol downward, muzzle flash, street below" — seed: AI-05 output.
- **AI-07 Roof drop**: "[style] operator landing from a roof edge onto plaza paving, knees bent, dust, two teammates running past, neon torii in background" — seed: d03 still.
- **AI-08 Scav crew in the pavilion**: "[style, dusk] three scavengers in hooded rain gear inside an open-sided wooden park pavilion, one kneeling at the rail watching the lawn, one talking into a radio, one behind a pillar, alert and spread out" — seed: d09 still.
- **AI-08b Scavs break**: "[style, dusk] the same pavilion, one scavenger firing from the rail, one sprinting to the far pillar, one dropping prone, tracers" — seed: AI-08 output, keep the same three silhouettes.
- **AI-09 Drone engages**: "[style, dusk] quadruped police drone arriving fast across a lawn with its searchlight on, firing at a wooden pavilion, scavengers ducking behind pillars" — seed: d06 still.
- **AI-09b Relay under fire**: "[style, dusk] wide: a police drone and scavengers trading fire at a pavilion in the background, while in the foreground one operator kneels with a hand on a stone path lamp and two teammates cover" — seed: d09 still.
- **AI-10 Lawn contact**: "[style] two squads of operators dropping prone into tall grass on an open lawn, 40 m apart, trees behind, one muzzle flash" — seed: south lawn still.
- **AI-11 Deck suppress** (first person): "[style] first person firing a submachine gun across a lake from a wooden viewing deck, tracers over water, arched bridge, sakura" — seed: d04 still.
- **AI-12 Bridge sprint**: "[style] operator sprinting over a wooden arched bridge, bullet impacts splintering the rail, sakura petals in the air" — seed: d04/n05 stills.
- **AI-13 Torii firefight**: "[style, night] muzzle flashes under a neon torii gate, wet paving reflecting pink and cyan, two operators behind planters" — seed: n02 still.
- **AI-13b Rival squad under a screen**: "[style, night] three operators on a wet street looking up at a large billboard screen showing a white transit map with a pulsing dot, neon shopfronts, rain" — seed: the composited billboard still from the engine capture.
- **AI-14 Station master still**: "[style, night] small elevated suburban train station beside a sealed park, two platforms, glass shelter, kanji station sign, vending machine, green mesh fence, neon city behind, train headlights approaching around a curve" — seed: n07 still. Generate this first; it is the seed for AI-14a to AI-14e.
- **AI-14a Stairs**: "[style, night] four operators sprinting up station stairs, one supporting a wounded teammate, muzzle flashes from the street below" — seed: AI-14.
- **AI-14b Platform standoff**: "[style, night] station platform, a rival squad behind a vending machine and a pillar, a police drone on the opposite platform turning, a train sliding in with its doors closed" — seed: AI-14.
- **AI-14c Platform lean** (first person): "[style, night] first person leaning out from a platform pillar, firing a submachine gun down the platform, train doors in frame" — seed: AI-14b.
- **AI-14d Boarding**: "[style, night] train doors open, operators breaking for two different carriages, one dragged in by a backpack strap" — seed: AI-14b.
- **AI-14e Carriage**: "[style, night] inside a train carriage, four operators on the floor and seats catching their breath, the platform sliding past the windows, a searchlight sweeping the glass" — no seed needed; match the grade.
- **AI-14f Ride out**: "[style, night] elevated train crossing above a neon city, the dark sealed park behind it, rain on the rails" — seed: n07 still.
- **AI-15 Weapon renders**: "[style] product render of a compact submachine gun on a dark workbench, soft top light, no text" for SHIGURE S-9; same prompt with "modern bullpup assault rifle" for RAIDEN R-56 and "long bolt-action sniper rifle with a 6x scope" for HAYATE H-7. Add the nameplates in the edit, not in the image.

### Motion prompts (image-to-video, 3–4 s, camera locked unless stated)

Keep motion prompts short. Good: "operators walk forward, slight handheld sway". Bad: paragraphs. Suggested per shot:

- AI-01: "the group walks away from camera, slow follow"
- AI-02: "kneeling operator holds still, teammates scan left and right, lamp ring pulses"
- AI-03: "operator crawls forward under the fence, grass sways"
- AI-04: "camera rises over the wall, pistol stays on the drone"
- AI-05: "anchor flies, line snaps taut, operator starts climbing"
- AI-06: "camera sways on the line, two shots fired downward"
- AI-07: "operator lands, dust puff, teammates run past"
- AI-08: "searchlight snaps to the operator, drone fires twice"
- AI-09: "scavs move right to left between barriers"
- AI-10: "both squads drop into the grass, one tracer"
- AI-11: "three-round bursts, tracers over water, slight recoil"
- AI-12: "operator sprints toward camera, rail splinters"
- AI-13: "two muzzle flashes, reflections flicker"
- AI-14: "squad backs out, searchlight sweeps across"

Generators that take an image and a motion prompt and hold the frame well: Runway Gen-4, Kling 2.x, Luma Ray, Veo 3. Generate 4 to 6 variants per shot and keep the one with the least warping in the hands and weapons. Expect to discard most first-person hand shots and composite the real arms plate instead.

---

## 5. Audio

- VO: record dry, close, in one session. Slight low-pass and a short room reverb. The script above is 240 words, which lands at 2:30 with pauses.
- Music: one track, dark electronic with a taiko or low percussion motif, 95–105 BPM. Quiet and sparse until 1:45, then a drop with the PvP beat, out at 2:28, sting on the logo.
- SFX: real game audio does not exist yet, so build a small library: UZI/SMG bursts, pistol, drone servo and alarm chirp, searchlight clunk, rain, crows, fireflies' silence, radio clicks, climbing-line snap, heavy landing thump. Every mantle, landing and sprint stop gets a weight sound. That is half of "heaviness".

---

## 6. Assembly pipeline

1. `trailer\RENDER_TRAILER_SHOTS.cmd` → check stills, adjust camera positions in `tests/trailer_capture.gd`, repeat until every ENGINE shot frames well.
2. `trailer\RENDER_TRAILER_SHOTS.cmd clips` → `frames\<shot>\*.jpg`, then `clips\*.mp4` (one per shot, 1920x1080, 30 fps, no audio: the trailer's sound is built separately).
2b. `trailer\RENDER_TRAILER_SHOTS.cmd staged` → check the first-person stills, HQ stills and plates; adjust positions in `tests/trailer_staged_capture.gd`; then `staged clips` for the frame dumps and MP4s.
3. Generate AI stills from the seeds in `stills\`, animate, export 1080p.
4. Resolve (free) timeline at 1920x1080 30 fps: lay VO first, then cut pictures to the VO, then music.
5. HUD plates as a top track on STAGED and first-person AI shots. Match the HUD state to the narration (relay count, timer, extraction bar).
6. Build one LUT from the engine clips and apply to the AI clips. Add 0.3 px gaussian to AI clips.
7. Titles: SHINRAI in a condensed sans, the same cyan the HUD uses for "EXTRACTION", on black.

---

## 7. Details needed from you

Settled from the code (no answer needed):

- Weapons are found, never bought. Names: UZI, SHIGURE S-9, KITE K-12, RAIDEN R-56, TOBIKAGE T-65, HAYATE H-7, YUZURU YZ-10, AKANE A-9. Beat 6 uses SHIGURE, RAIDEN, HAYATE.
- HQ is a menu ("SHINRAI / FIELD OPERATIONS", "THE QUIET EXIT"). Purchases are pack upgrades and medkits only. The locker-room AI shot is cut.
- Drones are the park's police only (spider drones in groups of 3 to 5). There are no player drones, so "our drones" in the brief means the police drones the squad has to avoid; the plan already treats them that way.
- Raid rules as built: 2-hour timer, 3 relays, extraction needs at least one relay and 15 s uninterrupted at the South or West gate, 15 s insertion grace, carried kit lost on death. Current build is solo PvE.

Still open. Defaults in parentheses are what the script uses until you say otherwise:

- Player count and squad size (default: 4-player squads, 12 players per raid, so "three squads").
- What happens to a killed player's cargo (default: it drops and anyone can take it).
- How long ago the takeover was, and the AI's in-world name (default: "eight months", unnamed, just "the city's AI").
- Park name. The code and UI say Shinrai Park; the assets and this plan say Midori Park (default: Midori Park, since "Shinrai" is the game's own title).
- The throwable climbing device's name and look (default: "the anchor", a fist-sized hook on a thin line).
- The nearest station's name (default: 緑公園前 Midori-kōen-mae) and whether the HUD shows the next departure (default: no, screens only).
- Tagline (default: "Catch the last train."), studio name, platforms, release line (default: "Wishlist on Steam").
- Narrator: in-world handler or neutral announcer (default: neutral, low, unhurried).
