# Shinrai map layout: recommendation

## Your three questions

**How big?** Plan the world at the full 9.6 km² from `CITY_DISTRICTS_PLAN.md`, but keep each raid map to about 1.0–1.5 km². The first map, **Midori Ward**, is about 1.1 km². What makes a raid feel alive is how many separate groups share each square kilometre. Your trailer default of 12 players in squads of 4 on 9.6 km² comes to about 0.3 groups per km², or one fight every 3+ hours. Gray Zone Warfare got "giant empty map" complaints at a similar density. So the world is big, and each raid is dense. You can see the rest of the city from inside the raid, and you unlock it by levelling up.

**How long?** **40 minutes** per raid, the same for day and night. Most of the genre sits at 25–45 minutes (Tarkov Customs 35, Hunt 45). The longest route on Midori Ward takes about 8 minutes to walk, so travel stays under a third of the raid. A raid plus stash time fits twice into the usual 1–2 hour session. Keep today's 2-hour timer as an optional night-only "Long Haul" mode.

**How many players?**
- **Build first:** solo or co-op PvE (1–3 players) with about 40 AI. Three AI "rival contractor" crews stand in for other players. You have no netcode yet, so this is the version you can ship.
- **PvPvE once netcode exists:** **12 players, squads of at most 3**, which makes about 4–6 groups. Add a separate solo queue of 6 solos.
- On 1.1 km² that gives about 3–5 player contacts per hour, a fight every 12–20 minutes. That is Hunt: Showdown's pace.
- Cap squads at 3, not 4. Every extra squad member removes one independent group from the map.

---

## The pick: a merge

- **The world model comes from Hub & Spokes.** One continuous fixed city. Each raid opens one map of 1.0–1.5 km². Your player level unlocks more maps, and Line train transits connect them.
- **The launch map comes from Midori Cordon.** It grows outward from the park that already plays, and it stays inside the existing ±640 m near-city tiles. That means no new streaming work.
- **The progression comes from all three proposals.** Skills change how you get through the map, not just your stats.

### World plan (the "big" part, delivered over time)

| Map | Area | Players | Raid | Unlock | Contents |
|---|---|---|---|---|---|
| 1. Midori Ward | ~1.1 km² | 12 | 40 min | Lv 1 | Park hub, shop streets, rail yard, danchi, entertainment strip, corporate tower |
| 2. Hinokuchi (S) | ~1.2 km² | 12 | 40 min | Lv 5 | Poor district, stadium scav market, storm drains |
| 3. Kōwan–Asahigaoka (E) | ~1.1 km² | 12 | 40 min | Lv 10 | Mall, port container yard, cranes, smuggler boat |
| 4. Takamine (N) | ~1.2 km² | 12 | 40 min | Lv 15 | Pyramid plaza, guarded towers, Kurogane guards |
| Later | 0.85–3.6 km² each | 12–16 | 40–45 min | Lv 12–25 | Satoyama + air base, Kagami-jima, Kitayama endgame |
| Event: Full City | ~2.7 km² | 24 | 50 min | Lv 15 | Hub plus all districts at once |

Maps join edge to edge. Extracting by Line train can carry you and your gear straight into the next map, the way Tarkov's transits work. Map positions follow the ring order in `CITY_DISTRICTS_PLAN.md`. Check them against `city_layout.json` before any blockout.

---

## Map 1: Midori Ward layout

The play area runs x −540..+540, z −460..+540 (north is −z, park centre is 0,0). That is 1,080 × 1,000 m, about 1.08 km². About 100 m of real generated city sits beyond the cordon, and the existing skyline covers the rest. That keeps the "city ends here" edge out of sight from the viaduct and the tower roof. Counting the tower, the housing slabs and the viaduct deck, walkable floor area comes to about 1.4 km².

| Zone | Bounds (x, z) | Area | Loot | Role and landmarks |
|---|---|---|---|---|
| **Midori Park (built)** | ±220, ±180 | 0.16 km² | T1 benches and fruit trees; T2–T4 weapon cases at the relays | Contested centre. 3 relays, 2 gate extracts, 8 biomes (coppice stealth route, Harappa meadow where prone hides you, Hanami lawn as an open killing ground). |
| **Kitamachi shop streets (N)** | −300..300, −460..−182 | 0.17 km² | T1–T2; koban key room **T3** | Food, water and medicine. Reuses the 32 hand-built `near_city_*` shops. Covered arcade sections keep sightlines to 50–120 m. |
| **Rail yard + Line station (NW)** | −540..−300, −460..−60 | 0.10 km² | T2 containers; sealed freight car **T3** (−420, −120), needs a bolt-cutter hold | Line train extract E1. The viaduct runs east 7 m up: fast, exposed, 300 m+ sightlines. |
| **Hachiman hill (NE)** | 300..540, −460..−60 | 0.10 km² | T1 houses; T2 shrine storehouse | Quiet flank and marksman perch with 250–400 m downhill views. |
| **East strip (E)** | 222..540, −60..190 | 0.08 km² | T2 valuables; pachinko vault **T3** (420, 60) | Close quarters, 10–40 m alleys. Pachinko parlour, game centre, bars. |
| **Nishi-danchi (W)** | −540..−222, −60..540 | 0.19 km² | T1 bulk; a few locked T2 rooms | Beginner area. 5 five-storey slabs built from one modular apartment kit, plus the existing Fukumaru apartments and a water tower. Culvert extract E5. |
| **Minami homes + clinic (S)** | −222..60, 182..540 | 0.10 km² | T1–T2; clinic T2 medical, rare T3 surgery kit | The existing south street, 7 homes, 4 shop flats and the scav crew. Adds a clinic for the per-limb medical system. |
| **Midori Corp + police (SE)** | 60..540, 190..540 | 0.17 km² | Police armory and tower floors 5–8 **T3**; warehouses T2 | Endgame area, with no spawn within 350 m. Boss and 3 guards on tower floors 6–8. Roof helipad extract E4. |

**Loot gradient.** The T3 spots (koban, freight car, vault, police and tower) take up about 11% of the area and hold about 45% of the loot value. The edges are T1. A new player works inward from the west and north, and a levelled player heads for the south-east.

**AI, about 40 at start:**
- 20 drones: the existing relay packs of 3, 4 and 5, plus new packs of 4 at the police station and the tower lobby.
- 15 scavs: 5 crews of 3 built on `scav_squad.gd`, one each in rail, Kitamachi, danchi, east strip and Minami.
- 1 tower boss with 3 guards.
- 2 backfill scav crews arrive at 12:00 and 22:00.
- At most 24 AI run full simulation at once. AI more than 200 m from every player ticks at 2 Hz.

### Map (approximate scale, north up)

```
        x=-540                            x=0                            x=+540
z=-460  +--------------------------------------------------------------+
        |S1 RAIL YARD      |KITAMACHI SHOP STREETS   |S2 HACHIMAN HILL |
        |E1 Line station   |konbini  pharmacy  ramen |shrine store (T2)|
        |sidings  T2 boxes |koban key room !  capsule|old houses     S3|
        |==================|== Line viaduct, 7 m up =|marksman perch   |
        |freight car ! (T3)|S0 north shop street     |                 |
z=-180  |                  +---------g---------------+                 |
        |                  |      MIDORI PARK        |                 |
        |                  | R coppice   momiji glen |                 |
        |NISHI-DANCHI      | pine woods   moss hill  gEAST STRIP       |
        |5-floor slabs x5  |     ~~~~ lake ~~~~   R  |pachinko vault ! |
        |water tower     E3| iris shore    harappa   |bars, game centre|
        |                  | R hanami lawn  sando    |              E6 |
z=+180  |                  +-----------E2------------+-----------------|
        |S6        E5      |MINAMI homes   |! POLICE STATION (T3)      |
        |  culvert: no bag |court  clinic  |MIDORI CORP TOWER E4 !     |
        |                  |scav crew      |8 floors, boss on 6-8 (T3) |
        |                  |               |bayside warehouses (T2)    |
        |     S5           |   S4          |                           |
z=+540  +--------------------------------------------------------------+
S = squad spawn (S0 = today's solo spawn)   E = extract   R = relay
g = park gate   ! = T3 loot   ~ = lake   = = Line viaduct
```

---

## Spawns and extracts

**Spawns.** Six squad spawns sit on the edge band. All coordinates are (x, z):

| Spawn | Location | Coordinates |
|---|---|---|
| S1 | NW | (−520, −440) |
| S2 | N | (250, −450) |
| S3 | NE | (530, −330) |
| S4 | S | (−100, 530) |
| S5 | SW | (−400, 530) |
| S6 | W | (−530, 250) |
| S0 | north shop street | (70, −201.5) |

- S0 is today's spawn. Keep it for solo PvE and the tutorial only.
- Rules, all checked against these coordinates:
  - Spawns are at least 300 m apart with no line of sight between them.
  - Every spawn is at least 330 m from the nearest T3 spot.
  - Every spawn has a T1–T2 point of interest 1–2 minutes away.
  - The nearest assigned extract is at least 380 m away.
- The south-east and east-south quarter has no spawns, because the T3 areas are there.
- The 15 s insertion grace stays.

**Extracts.** Every safe exit costs something: a relay, cash, your backpack, a keycard or a wait. Every extract can be reached from at least 2 directions.

| ID | Where | Type | Rule |
|---|---|---|---|
| E1 | Line station (−420, −300) | Timed, loud | Trains at 10:00, 20:00, 30:00 and a final one at 38:00. Doors stay open 45 s. The chime carries about 600 m. No cap on riders. Can transit you to the next map. |
| E2 | Park South gate (0, 167) | Relay-gated | Needs at least 1 relay downloaded by **your group**. 15 s hold. |
| E3 | Park West gate (−205, 40) | Relay-gated | Same as E2. Chained at night: use bolt cutters or the nearby prone hole. |
| E4 | Tower roof (220, 330) | Keycard | Security keycard, or Electronics rank 3. 60 s drone-lift call; rotors heard about 500 m away. 3 seats, one use per raid. |
| E5 | Canal culvert (−320, 250) | Quiet | No backpack. 6 m prone crawl, 10 s hold. |
| E6 | East checkpoint (530, 100) | Paid, timed | Hand over a cash item worth about 300 credits. Open 8:00–32:00. 7 s countdown. |

**Assignments.** Each spawn gets 3–4 extracts, Tarkov-style:

| Spawn | Extracts |
|---|---|
| S1 | E2, E3, E5 |
| S2 | E1, E2, E3, E6 |
| S3 | E2, E3, E6 |
| S4 | E1, E2, E3, E5 |
| S5 | E1, E2, E3 |
| S6 | E1, E2, E3 |

E4 is open to anyone who carries the keycard.

**Relay fix.** Today a relay is a one-time pickup. With 6 groups and 3 relays, half the lobby could never use E2 or E3. Make each relay a terminal that **every group can download once**. The download takes a 20 s hold and alerts the nearby drone pack. The cost becomes noise and exposure, not scarcity.

**Raid clock (40 min):**

| Time | Event |
|---|---|
| 0:15 | Grace ends |
| 8:00 | E6 opens |
| 10 / 20 / 30 | Trains |
| 12 / 22 | AI backfill crews arrive |
| 30:00 | Curfew sweep: drone backup cooldown drops from 45 s to 20 s, searchlights on, shutters close 3 alleys |
| 32:00 | E6 closes |
| 38:00 | Last train |
| 40:00 | Lockdown, using the existing "park locked down" message; unbanked items are lost |

**Night** uses the same 40 minutes, with the existing chained gates, 7 prone holes, shorter AI vision and +25% loot value.

---

## How raids feed levelling and skills

This is all new code. `extraction_profile.gd` has no XP today.

**XP:**
- First search of a container: 5–40 XP by tier.
- Relay download: 150.
- Kills: scav 40, drone 60, player 150, boss 400.
- Survival actions (drinking or eating while low, treating a bleed or fracture): small amounts.
- Extracting gives a ×1.2 bonus. **Death keeps 50% of the raid's XP**, so a lost raid still levels you.
- Target: 600–1,200 XP per extracted raid. One skill point per level.

**Levels gate maps and contracts:**
- Lv 1: park relays.
- Lv 5: freight-car manifest, and Map 2.
- Lv 10: police evidence room, and Map 3.
- Lv 15: tower boss and data core, and Map 4.

**Skills that change the route, not only the numbers.** Each works on Map 1 from day one:

| Skill | Effect |
|---|---|
| **Athletics** | Stamina pool 100 → 130 (full sprint 37 → 48 m), drain 18 → 15/s. The speed gain is small; the real payoff is in how long you can sprint. |
| **Fieldcraft** | Bolt cutters 2.6 → 1.4 s, prone speed 1.05 → 1.3 m/s, quieter in the coppice and meadow, faster culvert crawl. |
| **Electronics** | Faster relay download. Opens the vault and koban locker without a key. Rank 2 runs the tower service lift (skips 6 floors). Rank 3 calls the helipad without a keycard. |
| **Scavenger** | Search speed, plus 1 extra container per house. |
| **Survival** | Metabolism −20%, food-poisoning resistance. |
| **Field Medic** | Faster tourniquets and splints on the existing per-limb model. |
| **Marksman** | Better arm endurance and less sway. Pays off on the hill and viaduct sightlines. |

**Survival carry-over.** At full activity, a 40-minute raid only drains about 31 hydration, so as things stand metabolism barely matters. Carry hydration, food, energy and injuries between raids, and charge credits to refill at HQ. That makes the survival systems part of the loop.

**Economy.** Keep the existing sell, pack-upgrade and medkit menu. Add pack level 3 at 1,800 credits, a skill respec for credits, and cash items to carry for E6.

---

## Build plan (solo-dev estimates)

1. **P0 Rules, 3–5 weeks, on the map you have now.**
   - Raid length per map: `RAID_SECONDS` 7200 → 2400.
   - XP, levels, skill points and the first 6–7 skills, with a save migration `shinrai_extraction_v1` → `v2`.
   - Survival carry-over.
   - Per-group relays.
   - An extract-type framework: timed, keycard, paid, no-backpack.
   - Fix "ten minutes" in `EXTRACTION_BUILD.md` and the 2-hour / 4-player rules in the trailer plan.
   - Delete the dead `_spawn_entry_guard()` code and the stale K17 tests.
   - Write a one-page note on which systems the server will own later (raid clock, loot, AI, metabolism), so you don't build them in a way that is hard to network.
2. **P1 Go/no-go and the inner ward, 2–3 months.**
   - First, profile combat with 24 AI on the RTX 5050 laptop. Fix the 33 FPS cover view.
   - Replace the rect list in `_inside_playable_area` (`extraction_run.gd:1510`) with one map polygon.
   - Make the park, Kitamachi, Minami and corporate areas playable (about 0.55 km²).
   - Interiors: koban, pharmacy, clinic.
   - Extracts E2, E3, E4. AI rival crews.
   - **The inner 0.55 km² can ship on its own as a fallback.**
3. **P2 West and rail, 2–3 months.** Modular danchi kit, rail yard, viaduct deck, E1, E5.
4. **P3 East and NE, 2–3 months.** East strip, Hachiman hill, E6, boss, backfill crews, curfew sweep. **Map 1 is complete after about 9–12 months.** About 40 hand-built interiors at 2–4 days each is the real schedule driver.
5. **P4 Co-op, 3–4 months.** 3 players on a Godot ENet listen server.
6. **P5 and later.**
   - Dedicated servers for 12-player PvPvE. Headless boot must drop from 75–115 s to under 20 s.
   - Map 2 (Hinokuchi) with Line transit.
   - Then Maps 3 and 4, and the Full City event.

---

## Top risks

1. **Memory and frame rate.** The full game already runs out of memory on the laptop, and combat with many AI has never been profiled. The P1 profile decides everything else. If it fails, cut AI to about 30 or ship the 0.55 km² inner ward.
2. **Netcode retrofit.** The clock pauses, metabolism is local, and AI is local. Adding server authority to that is the biggest hidden cost. Every PvP number above stays a guess until P5.
3. **Interior cost, not km².** About 90 interiors on Map 1. Reuse the danchi and shop-flat kits hard, and keep the edges mostly exterior.
4. **The park as a camping funnel.** Both central extracts are in the park. Per-group relays, 4 gates plus 7 night holes, side extracts that skip the park, and death heatmaps once PvP exists.
5. **Borders that look fake.** The cordon needs physical reasons to stop you: barricades, flooded underpasses, embankments. The current push-back is only a backstop. This is art time, and borders sit in the same category as the roads you keep rejecting.
6. **"It doesn't feel big."** One raid is about the size of Tarkov Woods. Height, the visible skyline and maps you can see but haven't unlocked have to carry the sense of scale.

---

## Decisions only you can make

1. **What ships first?**
   - **A)** Solo/co-op PvE with AI rival crews. Recommended: it can be built with no netcode.
   - **B)** PvPvE from the start. Adds 6+ months before anyone plays.
2. **Raid length?**
   - **A)** 40 min, with a 2-hour Long Haul night mode. Recommended.
   - **B)** 30 min, faster and more Arc Raiders-like.
   - **C)** Keep 2 hours as the main mode. More DayZ-like; the lobby empties out mid-raid.
3. **Movement realism?** Walking at 3.85 m/s is closer to a jog; real walking is about 1.4 m/s.
   - **A)** Keep the current speeds. All the times above hold.
   - **B)** Slow walking to about 2.5 m/s. Every travel time grows about 1.5×, and the raid goes to 45–50 min.

---

## Update: target of 2–3 fights per hour, "big but not too big"

The user set a target of 2–3 player fights per hour on average, with a map that feels big but not too big.

### The math

- **The model:** contacts per hour = 2 × detection radius × average speed × other groups per km².
  - Detection radius is 0.15 km in town. Cautious average speed is 3.6 km/h.
  - That works out to about 1.08 × (other groups per km²).
- **Corrections:**
  - About 70% of contacts turn into a fight.
  - On average about 75% of groups are still in the raid. Groups thin out as players die or extract.
- **Result:** fights per hour ≈ 0.57 × (G − 1) / A, where G = groups in the lobby and A = map area in km².

### Map size per lobby (squads of up to 3, about 2.4 players per group)

| Players | Groups | Area for 2 fights/h | Area for 2.5/h | Area for 3/h |
|---|---|---|---|---|
| 12 | 5 | 1.13 km² | 0.91 km² | 0.76 km² |
| 16 | 6.7 | 1.62 km² | 1.29 km² | 1.08 km² |
| **18** | **7.5** | **1.84 km²** | **1.47 km²** | **1.23 km²** |
| 24 | 10 | 2.55 km² | 2.04 km² | 1.70 km² |

### Recommendation

- **Build Map 1 at about 1.5 km².** That is about 1.25 × 1.2 km, roughly Tarkov Woods size.
- **Tune the fight rate with lobby size, not map size.**
  - About 18 players (squads of up to 3) gives about 2.5 fights per hour.
  - 16 players gives about 2.2. 20 players gives about 2.8.
  - Changing lobby size is a config number. Changing map size is months of work.
- **Travel stays fine.**
  - The longest route is about 1.7 km. At a 3.85 m/s walk that is about 9–10 min, or about 15–19 min at a cautious pace.
  - Raids stay at 40 min, so travel takes no more than about a third of the raid.
- **Fights include AI too.** Placed AI crews add 2–4 AI fights per hour on top of the PvP fights. In PvE-first, AI rival crews stand in for the player groups, so the same density table applies to them.
- **Caveat:** these are model estimates. Playtests decide the final lobby size. Map 1's layout from above scales up from 1.1 to about 1.5 km² by pushing the edge band out about 60–100 m per side. The rail yard, the danchi and the hill get more room.

### Option checked: 2.3 km², 18 players, 50-minute raid

- **Groups:** 7.5 groups, so a group has 6.5 others; 75% of them are still in the raid on average.
- **Contacts:** 1.08 × 0.75 × 6.5 / 2.3 ≈ **2.3 per hour**, or about 1.9 per raid.
- **Fights:** at the 70% conversion rate, ≈ **1.6 per hour**, or about 1.3 per raid.
- **Chance per raid (Poisson):**
  - At least one player encounter: 1 − e^−1.9 ≈ **85%**.
  - At least one fight: 1 − e^−1.3 ≈ **74%**.
- **First contact:** about 26 minutes on average; the median is about 18 minutes.
- **Hotspots** (T3 loot, extracts, relays) concentrate players by about 1.5–2× in the core. A player who heads for the core sees about 2.5–3 fights per hour; one who stays on the edge sees about 1.
- **Travel:** at about 1.5 × 1.5 km, the longest route is about 2.1 km straight, or about 2.8 km walked. That is about 12 min at full walk and about 25 min at a cautious pace, which fits a 50-minute raid.
- **To reach 2 fights per hour on 2.3 km²:** about 22 players, or stronger hotspots.
