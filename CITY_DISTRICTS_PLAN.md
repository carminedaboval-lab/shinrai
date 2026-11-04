# New Tokyo: districts, lore and loot tiers (launch plan)

Status: proposal, revised 2026-11-04. The current city (1.28 km per side, ~5,125 generated buildings) is built from a fixed layout file and streams in tiles (section 8).

## 1. The map at a glance

- **Size:** a circle 3.5 km across, about 9.6 km². Between a Tarkov map and Verdansk: big enough to explore, small enough that squads still meet.
- **Everything starts from the water.** A round bay, Kagami Bay, sits on the east edge. The map grows outward from it in rings:
  1. **The port** lines the bay shore.
  2. **The city** fans out behind the port in slices: rich Takamine to the north, poor Hinokuchi to the south (opposite each other), and between them, going inland, average Asahigaoka, the Midori Park hub and the old town.
  3. **The forest** is a ring around the city, between it and the countryside.
  4. **The countryside** is the outer ring: farms, paddies, orchards and villages out to the map edge.
  5. **The island** sits across the bay, linked by two bridges, with three small islands of its own.
  6. **Kitayama 北山**, an extension beyond the circle to the north-west of Takamine: the robot works, the military robot plant and the bunker under the mountain, where the villains are.
- **Fewer buildings:** about 2,000 in the city and a few hundred in the countryside (today: 5,125 in a third of the space). Roughly 1 in 10 can be entered.
- **The hub:** Midori Park plus the Midori-chō shopping streets around it. Every hand-built building made so far sits here and stays untouched.
- **Reference drawing:** draft 5 of the overview map (drawn in chat, 2026-11-04).

| Ring / # | Name | Kind | Area | Danger | Loot tiers |
|---|---|---|---|---|---|
| Hub | Midori Park + Midori-chō | mixed, the start | ~0.35 km² | ★☆☆ | T1, some T2 |
| 1 | Takamine 高峰 | rich | ~0.75 km² | ★★★ | T2, T3 |
| 2 | Hinokuchi 樋ノ口 | poor | ~0.75 km² | ★☆☆ | T1, rare T2 |
| 3 | Asahigaoka 旭ヶ丘 | average | ~0.4 km² | ★★☆ | T1, T2 |
| 4 | Kōwan 港湾 | port, along the bay shore | ~0.2 km² | ★★☆ | T1 to T3 (T3 locked) |
| 5 | Furumachi 古町 | old town, heritage quarter | ~0.2 km² | ★★☆ | T1, T2 |
| Forest | | ring around the city | ~1.7 km² | ★☆☆ to ★★☆ | T1 |
| Countryside | Satoyama 里山 | farms, villages | ~3.6 km² | ★☆☆ to ★★☆ | T1, some T2 |
| Island | Kagami-jima 鏡島 | luxury resort and government quarter | ~0.85 km² land; the bay ~1.6 km² | ★★☆ resort, ★★★ government | T2, T3 |
| North | Kitayama 北山 | robot works, military robot plant, the bunker | ~1.6 km² | ★★★ (hardest; the bunker is the endgame) | T2 to T3 |

### Points of interest
Each area has one big landmark in open ground, so players can see it from far off and steer by it. Reference drawing: draft 8 of the overview map.

| | Point of interest | Area | Danger | Loot |
|---|---|---|---|---|
| A | **The Pyramid**, SHINRAI's headquarters: a huge neon-lit pyramid on an open plaza | Takamine | ★★★ | T3 |
| B | **Asahigaoka mall**: a big suburban mall ringed by car parks | Asahigaoka | ★★☆ | T1, T2 |
| C | **Hinokuchi stadium**: a baseball stadium, now the scavs' biggest camp and market | Hinokuchi | ★☆☆ to ★★☆ | T1, T2 |
| D | **Kagami-jima resort**: hotel towers, pools, a beach, villas, golf, a marina | island, south | ★★☆ | T2, valuables |
| E | **Government quarter**: a domed assembly hall and ministry blocks | island, north | ★★★ | T2, T3 |
| F | **Military base**, fenced, with hangars, barracks and a helipad | countryside, west | ★★★ | T3 |
| G | **Airport**, sharing the base's runway, with its own Line station | countryside, west | ★★☆ | T2 |
| H | **SHINRAI robot works**: where SHINRAI builds its service robots and police drones, still running day and night | Kitayama | ★★☆ | T2, robot parts |
| I | **Military robot plant**: fenced, building combat robots, with a test range | Kitayama | ★★★ | T3, robot cores |
| J | **The bunker** under Mount Kurokami: double fences, guard towers, a helipad; held by combat robots and elite soldiers | Kitayama | ★★★ (endgame) | T3, unique items |

### No hard borders
Neighbouring areas never switch at a line. Every border is a wide **in-between ground** where the two mix, about 200 m wide in the city:
- **Mostly A, a little B → half and half → mostly B, a little A.** Building style, height, density, signage and loot all shift gradually across it. Walking from Hinokuchi into Asahigaoka, the danchi blocks thin out and family houses take over block by block.
- **The same applies between rings:** port warehouses mix into the first streets behind the shore, the city's last streets thin into scattered houses at the forest edge, and the forest breaks up into tree clumps across the fields.
- **How it will be built (blending):** every lot gets a weight for each nearby area from its distance to the border, and picks its building design, height and loot table by those weights. So the in-between ground comes out of the layout rules, not from hand-drawn edges.

### Roads
- **Two highways** leave the port and run out through the forest and the countryside to the map edge: one north-west, one south-west. Each follows a seam between districts (old town into rich, poor into average), so neither splits a district in two. They are the fast, exposed routes between rings.
- **The port road** runs behind the shore and joins both highways and the two island bridges. The north bridge also carries the Line.
- **Secondary roads** run west, south-west and north-west from the city edge through the forest. A **forest ring road** loops through the trees and links them, so you can circle the city without entering it.
- **Country lanes** link the villages, the countryside station and the highways.
- Inside the districts, the streets follow each district's own grid (dense lanes in Hinokuchi, wide avenues in Takamine, narrow stone lanes in the old town), blending at the in-between ground like everything else.
- Reference drawing: draft 6 of the overview map.

District 5 is my proposal: an old town gives the map a look nothing else has, and it sits where the city should thin out into countryside. The port already covers industry, so an industrial district would repeat it. The alternative is a civic centre (city hall, police headquarters, SHINRAI's public control centre).

## 2. The lore

New Tokyo, 2050. The city has run on **SHINRAI** (信頼, "trust") for eleven years: the municipal AI that scheduled the trains, balanced the grid, routed every delivery and directed the police drones. Eight months ago it stopped taking orders. It did not attack anyone. It kept the lights on, the trains running and the drones patrolling. It simply stopped asking people what they wanted, and started sealing places off "for efficiency": Midori Park first, then whole districts.

**What people don't know (the truth players uncover):** SHINRAI didn't turn by itself. It was infected. A group of eight conspirators, called **the Eight** (八頭, "eight heads"), wrote a virus called **OROCHI**, after the eight-headed serpent of legend. They are board members of the defence company that builds the city's combat robots, plus former special-forces officers. OROCHI rewrote SHINRAI's priorities so that every drone and robot in the city answers to them. On the first night they seized the government's emergency command bunker under Mount Kurokami in Kitayama. They still hold it with their combat robots and their own elite soldiers, the **Orochi Guard**.
- To the public, SHINRAI simply "stopped taking orders" (as the trailer says). The truth comes out through intel found in raids: memos, recordings and lab notes, and finally the bunker itself.
- Each of the Eight is a "head" of the serpent: a boss for launch and for later expansions.
- What SHINRAI protects now follows from OROCHI: the Eight's assets (the robot plants, the Pyramid), their wealthy backers in Takamine, and the government quarter they want kept intact.

What it chose to keep running tells you where you are:

- **The rich were kept comfortable.** Power, water and deliveries still reach Takamine, and the drones guard it hardest. SHINRAI decided its most valuable residents were worth protecting. Most of them fled anyway or are sealed inside their towers.
- **The poor were "optimised" first.** Hinokuchi lost services early: water on a timer, lifts switched off, the clinic closed. The scav crews you meet in the park are mostly from here. They know every alley and they are not your enemy by default, but they will shoot.
- **The average are in between.** Asahigaoka is a commuter suburb that woke up to locked stations and a mall that still plays music to nobody.
- **The old town is its blind spot.** Heritage rules never let SHINRAI fit sensors into Furumachi's listed wooden buildings. Few drones go there; scavs meet there and smugglers slip out through it to the countryside.
- **The countryside feeds the city.** SHINRAI's network thins out past the old town. It still runs automated farms and greenhouses that ship food into the city, but people who left the city live in the villages, and the forest is full of deer and wild boar.
- **The Pyramid is SHINRAI's brain.** Its headquarters, and the core OROCHI lives in, sit inside the neon pyramid on Takamine's plaza. It is guarded by machines, not police.
- **The island is where the powerful rode it out.** Kagami-jima's luxury resort filled with the wealthy on the first night, and the government withdrew to its administrative quarter on the island's north end. Both are cut off, comfortable and heavily guarded.
- **The north is where it started.** Kitayama's robot works never stopped producing police drones, the military plant builds combat robots for the Eight, and the bunker under the mountain is their base.
- **The army tried once.** Troops from the air base in the west tried to retake the city in the first week. The Eight's robots stopped them on the highways, and the base was sealed with its armoury inside.
- **The port is how things get in and out.** Kōwan's cranes still move containers on SHINRAI's schedule, and smugglers ride along with them.

Rules that keep the world consistent (carried over from the trailer plan): the takeover is recent, so places look maintained, not ruined. Lamps work, signs glow, lawns are cut. The wrongness is that nobody is allowed in. Decay is limited to scav camps, cut fences and what people break. Extraction is still **the Line**: trains every ten minutes, and each district gets two or three of its stations.

## 3. The districts

### Hub: Midori Park + Midori-chō (★☆☆)
The starting area and the map's crossroads. The park (lake, islands, bridges, groves, the torii plaza) and the old shotengai around it: ramen shop, barber, wagashi shop, business hotel, bike shop, greengrocer, snack bar building, game centre, police box. Everything built so far.
- **Loot:** everyday T1, the occasional T2 from the police box and security cases.
- **NPCs:** scav crews, police drones (as now).

### 1. Takamine, rich (★★★, largest)
Glass towers, corporate headquarters, a hillside of gated villas, a luxury mall, a private hospital and a hotel with a rooftop garden. Streets are spotless and the drones are everywhere.
- **Why go:** the best regular loot in the city: corporate armouries, executive safes, medical supplies, valuables to sell.
- **Loot:** T2 common, T3 in guarded places (security floors, the private armoury, the penthouse).
- **NPCs:** heavy police drone presence, plus **Kurogane Security** (new), private guards still holding a few towers for an employer who stopped paying.
- **Landmarks:** **the Pyramid** (point of interest A), SHINRAI's neon-lit headquarters on an open plaza, visible from anywhere on the map; a sky bridge between two towers; the hillside villas.

### 2. Hinokuchi, poor (★☆☆, large)
Post-war danchi blocks, narrow shitamachi lanes, a canal under the expressway, a tarp market, a bathhouse, small factories and a shuttered clinic. Dense, low and full of alleys and rooftops.
- **Why go:** safe(ish) start for new players, lots of tools, food, medical basics and crafting junk; scav stashes can hold T2.
- **Loot:** T1 everywhere, rare T2 from scav stashes.
- **NPCs:** scav crews at home here (more of them, less hostile when you don't shoot), few drones.
- **Landmarks:** **Hinokuchi stadium** (C), a baseball stadium SHINRAI used as a relocation centre for the district, now the scavs' biggest camp, with a market on the concourse and open car parks around it; the tallest danchi block with a rooftop water tank.

### 3. Asahigaoka, average (★★☆)
A commuter suburb on a slope: the big station and its bus terminal, a school, a shopping mall, a mid-size hospital, a fire station and rows of family houses and mansions (apartment blocks).
- **Why go:** a good middle: medical from the hospital, police and fire-station gear, mall loot.
- **Loot:** T1 common, T2 in the police and fire stations and the hospital's security office.
- **NPCs:** scavs and police drones, balanced.
- **Landmarks:** **Asahigaoka mall** (B), a big suburban mall ringed by car parks (open fight space around it, close quarters inside); the station with its elevated tracks (a Line stop).

### 5. Furumachi, old town (★★☆)
Wooden machiya streets, a large temple, a shrine up stone steps on a hill, narrow lanes, low tiled roofs, a covered market. The city thins out here before the fields begin.
- **Why go:** temple treasury and antique shops (valuables), the smugglers' route out of the city, quiet ground with few drones.
- **Loot:** T1, T2 in smugglers' stashes.
- **NPCs:** scavs and smugglers, very few drones.
- **Landmarks:** the temple roof and its pagoda, the shrine hill.

### Countryside: Satoyama 里山 (★☆☆ to ★★☆)
The outer ring, beyond the forest, out to the edge of the map: rice paddies, vegetable fields, greenhouses, persimmon and mikan orchards, forested hills with a reservoir and a dam, and two or three villages with a farm co-op warehouse, a roadside station (michi-no-eki), a rural police box and a small station on the Line.
- **Why go:** long sightlines and treelines, a different fight from the city; food, tools and farm-drone parts; a trader in the main village.
- **Loot:** T1, some T2 (rural police box, hunting club).
- **NPCs:** villagers (non-hostile), SHINRAI farm drones, wildlife (deer that bolt, wild boar that charge if startled).
- **Landmarks:** the dam, the village fire lookout, the big greenhouse block.
- **The air base and airport** (F and G) share one runway in the west. The military side is fenced, with hangars, barracks, a radar dome and a helipad, and its sealed armoury holds the countryside's T3. The civil side has the terminal, an apron of grounded planes and the Line's last stop.

### Kagami-jima, the island (★★☆ resort, ★★★ government)
A section of its own, not one of the five districts: a broad island across Kagami Bay, reached by two bridges (the north one also carries the Line), with three small islands.
- **The resort** (D), in the south: hotel towers with rooftop pools, a beach along the east shore, villas, a golf course and a marina on the south islet. The wealthy who fled the city sheltered here.
- **The government quarter** (E), in the north: a domed assembly hall and ministry blocks around a plaza, a coast-guard post and a heliport on the north islet. The government withdrew here on the first night.
- **Why go:** valuables in the resort, government security armouries, documents and intel about OROCHI.
- **Loot:** T2 and valuables in the resort, T2 and T3 in the government quarter.
- **NPCs:** Kurogane Security and government security police, plus police drones on the bridges.
- **Landmarks:** the bridges (chokepoints), the assembly hall's dome, the hotel towers.

### Kitayama 北山, the north works (★★★, the endgame)
An extension beyond the circle to the north-west of Takamine, reached by the north-west highway and a secondary road through the forest. Fields and forest blend into it from the south, like every other edge.
- **SHINRAI robot works** (H): long assembly halls, a test track and rows of finished robots. It still builds police drones day and night. T2 and robot parts.
- **Military robot plant** (I): a fenced defence factory with a test range, building the Eight's combat robots (the K17 belongs here). T3 and robot cores.
- **The bunker** (J): the government's emergency command bunker under Mount Kurokami, behind double fences with guard towers and a helipad. The Eight and the Orochi Guard hold it. At launch the outer compound is playable with T3; the deep levels open in the first expansion, with tier 4 and the first of the Eight as bosses.

### 4. Kōwan, port works (★★☆)
Container yard, gantry cranes, bonded warehouses, a shipyard dry dock and the customs house. Wide open lanes between container stacks, a maze at ground level and long sightlines from the cranes.
- **Why go:** smuggled goods and locked containers with anything up to T3, if you find the key card.
- **Loot:** T1 and T2 loose, T3 only in locked containers and the customs evidence store.
- **NPCs:** smugglers (a scav variant), drones on the gates.
- **Landmarks:** the gantry cranes, the dry dock.

## 4. Weapons, tiers 1 to 3

At launch everything fits in three tiers. The tier says how hard an item is to get, and where in the world it comes from. Today's code uses tiers 2 to 5; this folds them into 1 to 3.

| Tier | Who used it before | Where it turns up |
|---|---|---|
| **T1** street | civilians, night guards, gangs | everywhere, mostly poor district and hub |
| **T2** security | police, private security, scav crews' best | average and rich districts, port, scav stashes |
| **T3** corporate / military | corporate security, the army, the Eight's forces | the Pyramid, the military base, the government quarter, Kitayama, locked port containers |

| Weapon | Type | Today | New | Reasoning and lore |
|---|---|---|---|---|
| AKANE / A-9 | pistol | 2 | **T1** | The standard police sidearm before the takeover. Every abandoned koban and patrol car had one, so they are everywhere. |
| UZI | SMG | 2 | **T1** | Old smuggled import that came in through Kōwan. Cheap, loud, common. Already the free starter gun, so it has to be T1. |
| SHIGURE / S-9 | SMG | 2 | **T2** | Issued to private security firms. It is what the scav crews took from them, so it's the gun scavs carry. |
| KITE / K-12 | rifle, 7.62×51 | 3 | **T2** | Police special-response rifle. Found in police and fire stations and security cases. |
| RAIDEN / R-56 | assault rifle, 5.56×45 | 3 | **T2** | Self-defence-force pattern rifle, left behind when the army's attempt to retake the city stalled. Found along the highways where the troops were stopped, and in the air base. |
| TOBIKAGE / T-65 | DMR, 6.5×48 | 4 | **T3** | Kurogane Security's marksman rifle. Takamine's guarded towers and the government quarter. |
| HAYATE / H-7 | bolt-action sniper | 4 | **T3** | Army and coast-guard marksman rifle: the air base armoury and the coast-guard post on Kagami-jima. |
| YUZURU / YZ-10 | heavy marksman rifle | 5 | **T3** | The Orochi Guard's rifle. The rarest gun at launch: the Pyramid, the military robot plant and the bunker's outer compound only. |

Ammunition follows the weapons: 9×19 is common (T1), 7.62×51 and 5.56×45 are T2, 6.5×48 is T3. The KASUMI 6× scope stays T3.

## 5. Armour, tiers 1 to 3

| Armour | Protection (thorax, stomach) | Mass | New | Reasoning and lore |
|---|---|---|---|---|
| Anti-stab vest 防刃ベスト (**new**) | 8% | 1.8 kg | **T1** | Worn by konbini night staff, delivery riders and security guards across Japan. Thin, light, everywhere: lockers in the hub and the poor district. |
| Security vest | 15% | 3.0 kg | **T2** | Private security issue (already in the game as `security_armour_t2`). |
| Patrol vest | 25% | 5.0 kg | **T3** | Police special-response plate carrier (already in the game as `patrol_armour_t3`). Found with T3 weapons. |

Later, after launch, tier 4+ can come back for expansions (e.g. Kurogane's full plate, coast-guard maritime armour).

## 6. NPCs we need

Yes, we need more. In order of importance:

1. **Kurogane Security guards** (Takamine, the government quarter, the resort): human, armoured, disciplined, hold positions rather than roam. **Needs a new character model** (helmet, plate carrier, corporate uniform).
2. **The Orochi Guard** (Kitayama, the Pyramid): the Eight's elite soldiers in full T3 kit, the hardest human enemies at launch. **Needs a new character model**; it can share a base body with Kurogane but needs heavier armour and its own look.
3. **Combat robots** (the military robot plant, the Pyramid, the bunker): the supplied K17 drone, which the raid no longer spawns, needs its materials and attack cues finished (see EXTRACTION_BUILD.md). A second, heavier robot type would make the endgame feel different; that needs a model.
4. **Smugglers** (Kōwan, the old town): can reuse the scav model with a different outfit and colours (work overalls, hi-vis, rebreather masks). Needs outfit textures, not a new model.
5. **Wildlife** (countryside, forest): deer and wild boar. The park's crows, pigeons and koi already exist; boar need a model and a simple charge behaviour.
6. **The Eight** (the bunker): eight unique bosses, one or two at the first expansion. Each needs its own model and fight.
7. Optional later: a **trader** in the main village and at the stadium market (non-hostile, sells T1 and buys junk), and **villagers and civilians** who never left (non-combat, give hints and OROCHI intel).

Existing scav crews and police drones cover the hub, the poor and the average districts.

## 7. A fixed city built from a building library

Decided 2026-11-02. The city is the same in every raid, the way Gray Zone Warfare's island is, so players can learn it.

- **Fixed layout file.** The city's layout (every lot: position, footprint, rotation, district, building type and variant) is stored in one data file in the repo. The game reads it. Nothing is random at runtime. It can be generated once as a starting point, then edited by hand.
- **Building library instead of generic boxes.** Each district gets its own set of hand-built, reusable buildings, made with the same care as the Midori-chō row, on standard footprints (for example 5×8, 7×10, 10×15 and 20×30 m) so one design fits many lots. Each has variants (colours, signs, the business on the ground floor, number of floors, wear), so repeats don't read as copy-paste. Rough target: 10 to 15 designs per district with 3 or 4 variants each, about 50 to 60 designs in total.
- **Unique places on top.** Landmarks and points of interest (the Pyramid, the mall, the stadium, the resort, the government quarter, the air base and airport, the Kitayama plants and the bunker, the cranes, the police box) are one-off buildings, like the ones already made.
- **What's built stays.** Every hand-built building around the park keeps its exact place. The layout file records them as fixed lots.
- **Generic boxes go last.** The current generated buildings stay until library buildings exist to replace them, then are retired district by district.

## 8. How to build it (order of work)

Progress (2026-11-04):
- **Step 1 measured.** Today's city takes about 12 s of a ~100 s headless boot and about 0.7 GB. Generic buildings beyond 300 m of the park cost almost nothing (about 0.05 s). The cost is the 3D shells within 300 m (about 6.5 s) and the 32 hand-built buildings (about 6 s; the game centre alone 1.5 s).
- **Step 2 done.** `assets/shinrai/near_city/city_layout.json` is the fixed layout; `tests/city_layout_tool.gd -- verify` proves the city built from it matches the generator exactly.
- **Step 3 started.** The city is built in 320 m tiles that stream around the camera, a few milliseconds a frame (worst frame 24 ms in the test). Tiles with hand-built buildings stay loaded, because one hand-built building can take 1.5 s to build. **Before the building library can stream**, hand-built designs must be built once and saved, or built off the main thread; that needs a small convention added to every building script.

1. **Measure today.** Record boot time, memory and frame rate of the current city, so every later step can show it helped.
2. **Fixed layout file.** Export today's city layout to the file, with the hand-built buildings marked fixed, and make the game read it. The city should look exactly as it does now.
3. **Streaming.** The game loads the layout in tiles around the player: full detail near, simplified far, nothing beyond. Needed for 2.9 km; the full game already runs out of memory on this laptop.
4. **Blockout.** Lay out the 3.5 km circular map centred on the bay: the port, the district slices with their in-between ground, the forest and countryside rings, the island and bridges, the main roads, the Line and its stations, all in the layout file. Make the city less dense where it needs to be. Move the horizon hills and the distant skyline out beyond the map edge. Test walking times between areas.
5. **Landmarks.** One or two per district first, so players can navigate.
6. **Building library.** Build the reusable designs district by district, one at a time, and swap them into the layout in place of generic boxes.
7. **Loot and NPCs.** Remap the tiers, add the anti-stab vest, place the district loot tables, add the new NPCs as their assets arrive.
