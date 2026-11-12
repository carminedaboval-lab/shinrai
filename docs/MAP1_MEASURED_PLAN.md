# Map 1: measured plan and district rule sheets

Draft 2, 2026-11-12 (airport moved 450 m further from the city; highways added). This turns the approved concept picture (`docs/map_concept/city_map_concept_approved_look.webp`) into real distances, and writes down for every district what makes it different, so the map cannot fill up with copies. The picture sets *where things go*; this document sets *what they are*. Where the two disagree, this document wins.

Everything here is a proposal until the owner approves it. Labelled defaults are marked **(default)**.

## 1. Frame

- **Coordinates:** metres, north is −z, the centre of Midori Park is (0, 0), the same frame the game already uses.
- **Play area:** x −1700 to +900, z −1800 to +950: **2.6 km × 2.75 km, about 7.2 km²**. The airport sits 450 m north of the city's edge, across an airport approach zone.
- **Fixed points that already exist:** Midori Park (x ±222, z ±182), the ring road around it, the north shop street and the south street.
- **Player count (default):** 36 players in squads of up to 3. At this size that is a little under one fight per hour on average across the map, concentrated at the orange and red zones, the stations and the airport. The countryside is meant to be quiet. If raids feel empty, raise the lobby to 45–48 rather than shrink the map.

```text
 z      x: -1700        -1200         -700          -200   0   300         900
-1800  +----------------------------------------------------------------------+
       |  MOUNTAINS          |            AIRPORT (runway E-W)               |
-1450  |   [DAM*] orange     |  hangars(Y)  terminal(G)  cargo(Y) fuel(Y)    |
       |    ~~~~ river       |  control tower       [S10] terminal station   |
-1150  |  foothills          +-----------------------------------------------+
       |  (west highway  ====|  AIRPORT APPROACH: expressway, north link,    |
       |   to Utsukushii)    |  service area (G), freight yard, scrub        |
 -700  +----------+  ~~~     +------+--------+---------------+---------------+
       | VALLEY   |   ~~     |ROBOT | RAIL   | GOV. PLAZA    | OLD TOWN      |
       | village  |  FOREST  |DEPOT | DEPOT  | pyramid (Y)   | shrine hill   |
 -400  | (river)  |   BELT   | (Y)  |        +---------------+ broadcast mast|
       | terraces |   ~~     +------+ HOUSING| SHOP STREETS  +---------------+
       | quarry   |    ~~    |UNIV. | blocks | +-----------+ | NIGHTLIFE     |
    0  | village  |   ~~     |campus|        | | MIDORI    | | STRIP         |
       | (hill)   |  ~~      +------+ HOSP./ | |  PARK     | +---------------+
       | river    | ~~       |        SCHOOL | |  (built)  | | MALL (dome)   |
  300  | warehouse|~~        +-------+-------+ +-----------+ +-------------+-+
       | (Y)      |~~        | STADIUM       | FAMILY HOMES  |  bay  [ISLAND]|
  600  | village  |~         | (scav market) +---------------+  ~~~  [ RED  ]|
       | (cross-  |          |               | PORT (Y)      |  ~~~  bridges |
  950  +----------------------------------------------------------------------+
        ~ = river      [S#] = station      (Y) yellow, (G) green, * orange
```

## 2. Districts at a glance

| # | District | Area (approx.) | Loot | Threat at start → end | Role |
|---|---|---|---|---|---|
| 0 | Midori Park (built) | 0.16 km² | grey, green relays | low → moderate | The known centre; relays; first thing every new player learns |
| 1 | Shop streets (Kitamachi and the rings round the park) | 0.25 km² | green | light → moderate | Food, medicine, everyday gear; close quarters |
| 2 | Government plaza (pyramid) | 0.12 km² | yellow | moderate → heavy | Landmark; armoured offices; drone-guarded |
| 3 | Old town on the shrine hill | 0.25 km² | grey, green shrine store | light → moderate | Quiet flank, high ground, broadcast mast |
| 4 | Nightlife strip | 0.12 km² | green, yellow vault | moderate → heavy | Alleys, arcades, a pachinko vault |
| 5 | Domed mall | 0.12 km² | green | light → moderate | Big interior, car parks around it |
| 6 | Housing blocks (danchi) | 0.20 km² | grey, green locked rooms | low → light | Beginner ground; bulk loot |
| 7 | Hospital and school campus | 0.15 km² | green | light → moderate | Medical; open courtyards |
| 8 | Rail depot | 0.12 km² | grey, green containers | light → moderate | Sidings, sheds; the tram's depot |
| 9 | Robot depot | 0.08 km² | yellow | moderate → heavy | Where the repair robots come out every hour (mystery) |
| 10 | University campus | 0.10 km² | green | light → moderate | Labs, library, clock tower at the forest edge |
| 11 | Stadium | 0.20 km² | green | light → moderate | Scav market on the concourse; open car parks |
| 12 | Family homes (south) | 0.20 km² | grey | low → light | Low houses, gardens, many small interiors |
| 13 | Port | 0.25 km² | yellow | moderate → heavy | Cranes, containers, warehouses; long sightlines |
| 14 | Corporate island | 0.10 km² land | **red** | maximum, always | The best loot; two bridges only |
| 15 | Airport | 0.90 km² | grey runway, green terminal, yellow hangars/cargo/fuel | moderate → heavy | Huge open ground, one terminal fight |
| 16 | Dam and research station | 0.15 km² | **orange** | heavy → very heavy | Second-best loot, far from red |
| 17 | Forest belt | 0.80 km² | grey | low → light | Quiet crossing, cover, hunting ground |
| 18 | River valley and villages | 1.20 km² | grey fields, green villages, one yellow warehouse | low → moderate | Countryside; drop-offs; long walks |
| 19 | Airport approach | 0.65 km² | grey, green service area | light → moderate | The 450 m between city and airport: the expressway, its interchange, a motorway service area, a freight yard, scrub and a low hill. Open ground with the elevated road as cover and as a sniping deck |

**Loot rule:** red only on the island; orange only at the dam; yellow never next to a drop-off. Orange and red sit at opposite corners (2.6 km apart), so a squad hunting the best loot must choose a direction.

## 2b. Streets and open ground

The overview colours each district as one block; inside, every district is streets, lanes and open space. Default proportions **(default)**: in the city about 35–45 % of the ground is streets, alleys, plazas, yards and car parks, never less than 30 %.

**Highways and main roads.** Every place connects to every other, but the network follows the land and the seams between districts instead of a grid, so it reads as grown rather than planned.
- **Airport expressway (elevated):** from the terminal south across the approach zone, then down the city's east fringe, between the old town and the map edge, past the nightlife strip and the mall, curving along the bay shore to the port. Airport freight to the port is why it exists. Inside the city it runs on pillars, so the streets underneath stay open and shaded.
- **North link:** from the expressway's interchange in the approach zone, west past the service area to a second interchange at the city's north-west corner, by the robot depot.
- **West highway:** from that interchange out through the forest, over the river on a bridge, along the foot of the mountains and off the west edge towards Utsukushii. The tram's line to the mountains runs beside it.
- **North avenue:** from the ring road straight through the shop streets to the pyramid plaza (axial, 30 m, planted median), then up to the north link.
- **Ring road** round the park (exists, 14 m), and an **east–west avenue** across the city past the park's west and east gates.
- **Coast road:** from the port west along the southern edge, through the stadium's car parks and the forest, to the crossroads village.
- **Forest road:** from the university west through the forest, over a small river bridge, to the hill village.
- **Country lanes:** link the three villages, the river warehouse and the quarry; a **mountain road** climbs in switchbacks from the north village to the dam.
- **Island bridges:** one from the port road, one from the shore by the mall.

**Real two-way traffic layout (owner's rule: it has to be real).** Japan drives on the left, so every road is laid out for left-hand traffic:
- **Expressway and west highway:** dual carriageway, two lanes each way, a central barrier, hard shoulders, slip roads at the interchanges, emergency phones and exit signs.
- **Avenues and the ring road:** two lanes each way with a planted median, turn lanes and signals at junctions, pedestrian crossings.
- **Ordinary city streets:** one lane each way with a centre line, kerbs and pavements; bus stops on a few.
- **One-way streets only where Japanese cities really have them:** narrow shopping lanes and alley streets, with the matching signs.
- **Country roads:** one lane each way; the narrowest lanes are single track with passing places, as on real rural roads.
- Abandoned cars face the right way for their lane.

What this gives play: the elevated expressway is a fast, exposed route and a long sightline; the ground under it is cover. The west highway is the obvious way in from the valley, the forest road and lanes the quiet ones.

**Inside districts (from the rule sheets):**
- Shop streets: 6–9 m shopping lanes, covered arcades, 1.5–3 m service alleys behind the shops.
- Nightlife strip: one main street and 2–4 m alleys every 15–30 m, many with stairs and dead ends.
- Old town: winding lanes 3–5 m wide, stone steps, garden walls, no straight run over 60 m.
- Family homes: 4–6 m residential lanes, footpaths between gardens, a few vacant lots.
- Housing blocks: courts, car parks, footpaths and play areas between the slabs.
- Port: wide wharves and container aisles; airport: apron and taxiways. These are the open, exposed ground.

**Open space on purpose:** the pyramid plaza, stadium car parks, mall car parks, school sports ground, university quad, the port's container yards, the airport apron, parks small and large, rice fields. Fights need both close quarters and open ground to cross.

Each district gets its own street-level plan, drawn and shown before it is built.

## 2c. Living streets, true to real Japan

The city is evacuated but still maintained by machines, so it moves and hums without people. Everything that moves or makes sound copies how it works in real Japanese cities (owner's rule: realistic to the real world). Before any element is built, collect reference photos of the real thing and match it side by side.

- **Measurements from Japanese standards:** lanes about 3.0–3.25 m, kerbs about 15 cm, pavements 2–4 m, utility poles every 30–40 m with transformers and dense overhead lines, guard rails at junctions.
- **Signs and markings to Japanese conventions:** blue direction signs, the red inverted-triangle stop sign 止まれ with its road marking, white zebra crossings, the green-and-white pedestrian signals.
- **Signals that behave like real ones:** realistic cycle times with an all-red phase, flashing pedestrian green, and crossing sounds in the real style (bird-chirp tones). Sounds are our own recordings or licensed effects, never copied melodies.
- **Shops:** noren curtains, sample displays, vending machines in clusters as real streets have them, shutters on closed shops, the shop's type deciding its dressing.
- **Wildlife that lives in Tokyo:** jungle crows, pigeons, stray cats, cicadas in summer; deer and wild boar only at the forest edge.
- **Light in 2050:** LED street lighting, neon and backlit signs, some windows lit on timers.
- **Seasons and weather follow Japan:** cherry blossom in spring, cicadas and humidity in summer, red maples in autumn; rain and puddles.
- **Check:** each finished street is compared with real reference photos from the same kind of place before it is accepted.

## 3. Rails and stations

- **Inner loop (extraction):** a rounded rectangle on the ring road around the park and its first ring of streets: x ±225.5 widened to the shop streets, z −430 to +490. Length about 2.7 km.
- **Ten stations** (default positions):

| Station | Position (x, z) | Serves |
|---|---|---|
| S1 | (0, −430) | Shop streets north, government plaza |
| S2 | (−225, −300) | Rail depot, housing |
| S3 | (−225, 0) | Housing, university |
| S4 | (−225, 300) | Hospital and school |
| S5 | (−150, 490) | Stadium, family homes |
| S6 | (120, 490) | Family homes, port |
| S7 | (225, 330) | Mall, port |
| S8 | (225, 0) | Nightlife strip |
| S9 | (225, −300) | Old town |
| S10 | (150, −1240) | Airport terminal (branch line from the loop's north-east corner, about 1 km, beside the expressway) |

Gaps between neighbouring loop stations: 190–330 m, so from anywhere in the city a station is two to four minutes on foot. The countryside has **no station** **(default)**: leaving from the valley means walking into the city, which is the price of a quiet drop. The dam and the island also have none.

- **Outer drop-off line:** runs round the edge of the map through the valley, the forest, past the airport's north fence and down the east side, and stops short of the bay.

## 4. Drop-off points (12)

Checked by calculation against every yellow, orange and red zone (yellow must be more than 250 m away, orange and red more than 350 m), against each other, and against the nearest station.

| Drop | Position (x, z) | Area | Nearest high-value zone | Nearest other drop | Nearest station (walk) |
|---|---|---|---|---|---|
| D1 | (−1600, −500) | Valley, north | Dam, 828 m | 364 m | S2, ~8 min |
| D2 | (−1620, 100) | Valley, middle | River warehouse, 577 m | 600 m | S3, ~8 min |
| D3 | (−1580, 700) | Valley, south | River warehouse, 594 m | 601 m | S4, ~8 min |
| D4 | (−1000, 930) | South-west forest edge | River warehouse, 589 m | 480 m | S5, ~5 min |
| D5 | (−520, 940) | South forest edge | Port, 740 m | 480 m | S5, ~3 min |
| D6 | (−780, −640) | North forest edge | Robot depot, 311 m | 472 m | S2, ~4 min |
| D7 | (−1250, −600) | Valley, below the dam | Dam, 650 m | 364 m | S2, ~6 min |
| D8 | (860, −600) | East edge, north | Cargo and fuel, 800 m | 450 m | S9, ~4 min |
| D9 | (870, −150) | East edge, middle | Island, 934 m | 400 m | S8, ~4 min |
| D10 | (860, 250) | East edge, south | Island, 536 m | 400 m | S7, ~4 min |
| D11 | (−620, −1680) | Airport, west fence | Hangars, 520 m | 1052 m | S10, ~5 min |
| D12 | (880, −1600) | Airport, east fence | Cargo and fuel, 361 m | 1000 m | S10, ~5 min |

All twelve pass (re-checked after the airport moved). Every drop is at least 311 m from the nearest yellow zone and at least 536 m from orange or red. Walks assume 3.85 m/s and 30 % detour.

**Solo, duo and trio (owner's rule: spawns differ by group size):**
- **Trios** use the outer drops (D1–D4, D7, D11): the longest walks, the most ground to cover, the most loot on the way.
- **Duos** use the middle drops (D5, D6, D8–D10, D12).
- **Solos** (default) get their own extra stops on the inner loop's quieter side (S2, S3, S5, S6) a minute or two after the others have spread out, so a solo never lands next to a full squad.

**Drawn together without starting together (owner's rule):** every drop is far from high-value loot, but every route from a drop to a station runs through the city's green districts, and the stations sit on the one loop. Squads spread out at the start and converge on the same ring of streets as the raid goes on. Threat rising over time pushes them inward too.

## 5. District rule sheets

Each sheet sets the four things that make a district its own (street pattern, height, age, purpose), its building kit, its one-of-a-kind landmarks, and what must not happen there. A kit is about ten building types used only in that district; neighbouring districts blend over 50–150 m at their edges instead of switching at a line.

### 0. Midori Park (built)
- **Pattern:** curving paths, lake, groves. **Height:** none; trees only. **Age:** 1990s park, 2050 refits (relays, lamps).
- **Kit:** already built; keep.
- **Landmarks:** the lake and its islands, the torii plaza.
- **Never:** new buildings inside the fence.

### 1. Shop streets
- **Pattern:** tight shotengai grid, covered arcades, 6–9 m lanes. **Height:** 2–5 floors. **Age:** 1960s–1990s shop-houses with 2050 signage.
- **Kit:** konbini, pharmacy, ramen and izakaya, barber, greengrocer, capsule hotel, police box, pachinko-free arcade, small office over shops, covered arcade roof.
- **Landmarks:** one covered arcade with a glass roof.
- **Never:** two identical shop fronts side by side; every lot differs in width (4–9 m) and storey count.

### 2. Government plaza
- **Pattern:** axial: one wide avenue into a paved plaza. **Height:** 8–20 floors round the plaza; the pyramid in the middle. **Age:** 2040s.
- **Kit:** ministry slab, records annex, security checkpoint, plaza kiosks, underground car-park ramps.
- **Landmarks:** the glass pyramid (one only), visible from the whole map.
- **Never:** greenery in rows; planting is in irregular sunken gardens.

### 3. Old town on the shrine hill
- **Pattern:** organic lanes following contours, steps, dead ends. **Height:** 1–2 floors, timber. **Age:** pre-war to 1970s.
- **Kit:** machiya townhouse (three widths), storehouse (kura), small temple, tea house, tiled-wall lane, stone steps with lanterns, garden plot.
- **Landmarks:** the shrine at the top, the broadcast mast beside it.
- **Never:** straight streets longer than 60 m.

### 4. Nightlife strip
- **Pattern:** one main street, many 2–4 m alleys off it. **Height:** 3–7 floors, narrow and tall. **Age:** 1980s–2010s, layered signs.
- **Kit:** "pencil" bar building, karaoke, game centre, pachinko hall with vault, love hotel, snack bars in one building, stair-and-sign facade.
- **Landmarks:** one vertical neon tower sign (one only).
- **Never:** signs on every building at the same height.

### 5. Domed mall
- **Pattern:** one big block with car parks on three sides. **Height:** 4 floors plus a glass dome. **Age:** 2030s.
- **Kit:** the mall (one building, many interiors), multi-storey car park, bus loop, delivery yard.
- **Landmarks:** the glass dome.
- **Never:** a second dome anywhere on the map.

### 6. Housing blocks (danchi)
- **Pattern:** slab blocks at varied angles round shared courts, not in rows. **Height:** 5–11 floors. **Age:** three building eras: 1970s slabs, 1990s point towers, one 2040s infill block.
- **Kit:** slab (two lengths), point tower, low shop row, kindergarten, water tower, bicycle shed, playground, car park, community hall.
- **Landmarks:** the water tower.
- **Never:** more than two slabs at the same angle next to each other.

### 7. Hospital and school campus
- **Pattern:** campus: buildings round courtyards and a sports ground. **Height:** 3–9 floors. **Age:** 1990s school, 2030s hospital wing.
- **Kit:** ward block, outpatients, ambulance bay, helipad roof, school block, gym, pool, sports ground.
- **Landmarks:** the helipad on the hospital roof.

### 8. Rail depot
- **Pattern:** long parallel tracks (allowed here: railways are straight). **Height:** single-storey sheds, one tall signal box. **Age:** 1980s, 2040s rolling stock.
- **Kit:** carriage shed, maintenance pit, signal box, sidings with parked trams, staff block, fuel point.
- **Landmarks:** the signal box.

### 9. Robot depot
- **Pattern:** fenced compound, one big hall, open yard. **Height:** one tall hall. **Age:** 2045, clean and unexplained.
- **Kit:** the hall with large doors, charging racks, parts store, control room, robot bays.
- **Landmarks:** the hall doors, which open on the hour **(default: as a set piece later)**.
- **Never:** explain it. Show only.

### 10. University campus
- **Pattern:** quad and paths at the forest edge. **Height:** 3–6 floors. **Age:** 1960s main hall, 2030s labs.
- **Kit:** main hall with clock tower, labs, library, dormitory, canteen.
- **Landmarks:** the clock tower.

### 11. Stadium
- **Pattern:** one oval with radiating car parks and plazas. **Height:** stadium bowl. **Age:** 2020s.
- **Kit:** the stadium, concourse stalls (scav market), ticket gates, car parks, a practice pitch.
- **Landmarks:** the stadium roof.

### 12. Family homes
- **Pattern:** irregular small lots on narrow lanes, gardens, a few vacant lots. **Height:** 1–3 floors. **Age:** mixed, 1960s to 2040s, every house different.
- **Kit:** at least eight house types plus small apartment buildings, a corner shop, a shrine, a laundry, a small park.
- **Never:** the same roof twice in a row.

### 13. Port
- **Pattern:** wharves, container stacks, warehouse rows along the quay. **Height:** low warehouses, very tall cranes. **Age:** 2010s–2040s.
- **Kit:** container stack (varied heights and colours), warehouse (three sizes), crane, reach stacker, office block, customs shed, fuel tanks.
- **Landmarks:** the crane row (cranes differ in model and height).

### 14. Corporate island
- **Pattern:** one tower with a podium and gardens. **Height:** one supertall tower. **Age:** 2048.
- **Kit:** the tower (many floors, few enterable), podium, guard posts, the two bridges.
- **Landmarks:** the tower, visible everywhere.
- **Always maximum threat.** Its own staple enemy (end-game work).

### 15. Airport
- **Pattern:** runway east-west, apron, terminal on the city side. **Height:** low terminal, control tower, hangars. **Age:** 2030s terminal, older hangars.
- **Kit:** terminal (one building), control tower, hangars (three sizes), cargo sheds, fuel tank farm, parked aircraft (few, different types), service vehicles.
- **Landmarks:** the control tower.
- **Never:** aircraft lined up identically.

### 16. Dam and research station
- **Pattern:** a concrete dam in a gorge, the station built into its face. **Age:** 1970s dam, 2040s research levels.
- **Kit:** dam crest road, spillway, research levels, turbine hall, access tunnel.
- **Landmarks:** the dam.

### 17. Forest belt
- **Pattern:** natural forest with clearings, two trails and one service road. **Never:** trees on a grid; follow the park's natural-grove rules.

### 18. River valley and villages
- **Pattern:** the river winds; three villages each with a reason to differ **(default)**:
  - **North village:** a mill and bridge on the river, timber houses along one lane.
  - **Hill village:** terraced houses and a shrine on a slope above rice terraces.
  - **Crossroads village:** a petrol station, a farm co-op and a bus shelter where two lanes meet.
- **Other features:** rice terraces (curves follow the slope, never repeated), a quarry, scattered farm sheds, one riverside warehouse (yellow).

## 5b. Reuse the buildings already made

The park's surroundings already hold many finished, approved buildings. They are the starting kits for the new districts, not one-offs to leave behind.

| Existing building (script or scene) | Reuse in |
|---|---|
| Konbini, drugstore, ramen, gyoza, barber, greengrocer (yaoya), bookshop, flower shop, bike shop, estate agent (fudosan), handmade shop, coin laundry, police box (koban), capsule hotel, business hotel, mixed-tenant building (zakkyo) — `scripts/midori_near_city_*.gd` | Shop streets (district 1) |
| Pachinko hall, karaoke, snack-bar building, pencil building, game centre, big screen, yakitori shop (`assets/shinrai/buildings/yakitori_shop`) | Nightlife strip (4) |
| Wagashi shop, coffee shop (kissa), bathhouse (sento), handmade shop | Old town (3), in older timber and tile finishes |
| South street homes and shop flats, neighbourhood houses (`midori_south_street_*`, `midori_neighbourhood_context.gd`) | Family homes (12) |
| Fukumaru apartments | Housing blocks (6) |
| Corporate district, its garage, police station, stairs and lifts (`assets/shinrai/districts/corporate_command`) | Government plaza (2), and the police station for the old town or hospital edge |
| Viaduct pieces (`midori_near_city_viaduct.gd`) | Rail depot (8), the expressway's pillars |
| Clubhouse and cafeteria, café, ceramics gallery | University campus (10) and the stadium |

**How reuse stays unrepetitive:**
- Most near-city buildings are built by code, so each placement varies its width, floor count, signage, colours, materials and dressing; a copy is never placed next to the same variant.
- Landmark buildings (police box, bathhouse, pachinko hall, police station) appear once per district at most.
- The same shop type looks different by district: a wagashi shop is tile and concrete on the shop streets, timber in the old town.
- Interiors that already exist stay enterable.

## 6. Build order

1. **Shop streets north of the park** (district 1, part). They touch the park and reuse what exists.
2. **Housing blocks west** and **old town north-east**.
3. **Nightlife strip and mall** (east), with the inner loop extended to its full size.
4. **Stadium, family homes, port** (south).
5. **Forest belt** and **river valley** (west), with the drop-off line.
6. **Airport, dam, island**.

Each step must load only when the player is near it, so memory stays under the 8 GB target. Each step is shown to the owner with same-camera pictures before the next starts.

## 7. Open decisions (owner)

- Countryside station, or walk in **(default: walk in)**.
- Solo drops on the inner loop **(default above)** or their own edge points.
- Lobby size 36 or more for this map size.
