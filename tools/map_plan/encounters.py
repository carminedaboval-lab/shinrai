"""What a player meets on Map 1 between fights with other players.

The owner's worry was boredom: a big, dense town with nothing happening in it. His answer
was looting, robots (some hidden in buildings), scavs who loot and live in buildings, and
scav coves with patrols. This module turns that into places on the map, by rule:

*  COVES and PATROL ROUTES come from the plan file: they are placed by hand, each for a reason.
*  SCAV HOMES are ordinary houses a scav would pick: off the main roads the robots patrol,
   close to water or to something that grows, away from the drop-offs.
*  DORMANT ROBOTS wait in the buildings robots would use: car parks, big sheds, power and
   water plant.
*  ROBOT WORK SITES close one side street each, so the way through a block changes.
*  BIRDS: crows on the roofs round every cove and square, pigeons on the squares, water
   birds on the lake, the stream and the river.
*  Which doors open: nearly all of them (owner, 2026-11-13). A fixed share of town buildings
   stays shut, spread along every street.

Only some of each pool are used in one raid. measure() plays many raids and reports how far
a player on a street ever is from something to do.
"""
import math
import random

import numpy as np
from PIL import Image, ImageDraw

from city_fabric import Path, dense
import junctions

HOMES = {"house", "timber", "shop"}
TOWN_KINDS = {"house", "timber", "shop", "building", "tall", "slab", "office", "apartment", "luxury"}
ROBOT_KINDS = {"carpark", "hall", "hangar"}
MAIN = {"arterial", "ring", "highway", "grid"}


def _spread(candidates, spacing, limit):
    """Takes candidates in order, keeping each at least `spacing` from those already taken."""
    out = []
    for c in candidates:
        if all(math.hypot(c[0] - o[0], c[1] - o[1]) >= spacing for o in out):
            out.append(c)
            if len(out) >= limit:
                break
    return out


def _route(plan, spec):
    if "points" in spec:
        points = [tuple(p) for p in spec["points"]]
    else:
        roads = {r["name"]: r for r in plan["roads"]}
        pieces = [list(map(tuple, roads[name]["points"])) for name in spec["roads"]]
        points = pieces[0]
        if len(pieces) > 1:
            nxt = pieces[1]
            if min(math.dist(points[0], nxt[0]), math.dist(points[0], nxt[-1])) < min(math.dist(points[-1], nxt[0]), math.dist(points[-1], nxt[-1])):
                points = points[::-1]
        for piece in pieces[1:]:
            if math.dist(points[-1], piece[-1]) < math.dist(points[-1], piece[0]):
                piece = piece[::-1]
            points = points + piece
    if spec.get("loop") and math.dist(points[0], points[-1]) > 1.0:
        points = points + [points[0]]
    return points


def build(m):
    plan = m.PLAN
    spec = plan["encounters"]
    rules = spec["rules"]
    T = m.TERRAIN
    drops = [(d["x"], d["z"]) for d in plan["drops"]]
    stations = [(s["x"], s["z"]) for s in plan["stations"]]
    core = plan["city"]["core"]

    def clear_of(x, z, points, gap):
        return all(math.hypot(x - px, z - pz) >= gap for px, pz in points)

    def mask(painter):
        image = Image.new("L", (m.W, m.H), 0)
        painter(ImageDraw.Draw(image))
        return np.asarray(image) > 0

    def at(mask_, x, z):
        return bool(mask_[min(max(int(z - m.Z0), 0), m.H - 1), min(max(int(x - m.X0), 0), m.W - 1)])

    # Land near a main road (robots patrol those), and land near water or something that grows.
    reach = rules["scav_home_off_main_roads_m"]
    near_main = mask(lambda d: [d.line(m.pts(r["points"]), fill=255, width=int(r["width"] + 2 * reach), joint="curve") for r in plan["roads"] if r.get("class") in MAIN])
    water = plan["water"]

    def living(d):
        d.line(m.pts(water["stream"]["points"]), fill=255, width=170, joint="curve")
        d.line(m.pts(water["river"]["points"]), fill=255, width=190, joint="curve")
        for s in m.spaces:
            if s["kind"] in ("park", "shrine", "temple"):
                d.ellipse([s["x"] - 85 - m.X0, s["z"] - 85 - m.Z0, s["x"] + 85 - m.X0, s["z"] + 85 - m.Z0], fill=255)
    near_living = mask(living)

    boxes = m.boxes
    ground = [(i, b) for i, b in enumerate(boxes) if b[8] == 0.0]

    # ---- coves ----
    coves = []
    for cove in spec["coves"]:
        c = dict(cove)
        if "camp_on" in c:
            # The estate's cove sits in one of its towers: the one farthest from the tram.
            estate = next(d for d in plan["districts"] if d["pattern"] == "danchi")["rects"][0]
            towers = [b for _, b in ground if b[7] in ("tall", "apartment") and b[4] > 30 and estate[0] <= b[0] <= estate[2] and estate[1] <= b[2] <= estate[3]]
            if towers:
                best = max(towers, key=lambda b: min(math.hypot(b[0] - sx, b[2] - sz) for sx, sz in stations))
                c["x"], c["z"] = best[0], best[2]
                c["lookouts"] = [[best[0], best[2]]]
        c["patrol"] = _route(plan, {"points": c["patrol"], "loop": c.get("loop", False)})
        c["patrol_m"] = round(Path(c["patrol"]).length)
        coves.append(c)

    # ---- scav homes ----
    scored = []
    for i, b in ground:
        x, z = b[0], b[2]
        if b[7] not in HOMES or not 35 <= b[3] * b[5] <= 170:
            continue
        if at(near_main, x, z) or not at(near_living, x, z):
            continue
        if not clear_of(x, z, drops, rules["scav_home_clear_of_drops_m"]) or not clear_of(x, z, stations, 120):
            continue
        if any(math.hypot(x - c["x"], z - c["z"]) < c["radius"] + 60 for c in coves):
            continue
        scored.append((x, z, i))
    order = random.Random(m.SEED + 31)
    order.shuffle(scored)       # no corner of the map gets first pick
    homes = _spread(scored, 82.0, rules["scav_homes_pool"])

    # ---- dormant robots ----
    nests = []
    for i, b in ground:
        x, z = b[0], b[2]
        area = b[3] * b[5]
        use = None
        if b[7] in ROBOT_KINDS:
            use = "car park" if b[7] == "carpark" else "hall"
        elif b[7] == "shed" and area >= 500:
            use = "shed"
        elif b[7] == "building" and 150 <= area <= 330 and not (core[0] < x < core[2] and core[1] < z < core[3]):
            use = "plant"
        if use and clear_of(x, z, drops, rules["robot_nest_clear_of_drops_m"]):
            nests.append((x, z, i, use))
    for x, z, why in ((-206, -570, "tram power house"), (-552, -814, "substation"), (628, -776, "water works")):
        near = min(ground, key=lambda ib: math.hypot(ib[1][0] - x, ib[1][2] - z))
        nests.insert(0, (near[1][0], near[1][2], near[0], why))
    nests = _spread(nests, 135.0, rules["robot_nests_pool"])
    if len(nests) < rules["robot_nests_pool"]:
        # Big ordinary buildings with shutters down: offices, stores.
        extra = [(b[0], b[2], i, "shuttered store") for i, b in ground if b[7] in ("building", "slab", "office") and b[3] * b[5] >= 320
                 and clear_of(b[0], b[2], drops, rules["robot_nest_clear_of_drops_m"])]
        order.shuffle(extra)
        nests = _spread(nests + extra, 135.0, rules["robot_nests_pool"])

    # ---- robot work sites ----
    sites = []
    streets = getattr(m, "town_streets", [])
    for street in streets:
        if street["cls"] not in ("local", "alley", "collector") or street["path"].length < 55:
            continue
        x, z, tx, tz = street["path"].at(street["path"].length * 0.5)
        if clear_of(x, z, drops, 200) and clear_of(x, z, stations, 60):
            sites.append((x, z, round(street["path"].length), street["cls"]))
    order.shuffle(sites)
    sites = _spread(sites, 135.0, rules["work_sites_pool"])

    patrols = []
    for route in spec["robot_patrols"]:
        points = _route(plan, route)
        patrols.append({"name": route["name"], "points": [[round(x, 1), round(z, 1)] for x, z in points], "length_m": round(Path(points).length), "loop": route.get("loop", False)})

    # ---- which doors open ----
    # Owner's rules (2026-11-13): nearly every building opens; a fixed share stays shut. The
    # shut ones are mostly the buildings with many floors: half of those are shut (they cost
    # the most to fill, and with one in two open nobody can tell which it will be). What is
    # left of the share is spread thinly over the low buildings. Steps are uneven so shut
    # buildings never come in a rhythm; a scav home or a robot building is never shut.
    shut_share = rules["closed_building_share"]
    tall_from = rules["tall_building_floors"]
    tall_share = rules["closed_share_of_tall"]
    keep_open = set(h[2] for h in homes) | set(n[2] for n in nests)
    enter = set(keep_open)

    def floors_of(b):
        return max(1, round((b[4] - 0.9) / 3.1))

    town = [(i, b) for i, b in ground if b[7] in TOWN_KINDS]
    tall = [(i, b) for i, b in town if floors_of(b) >= tall_from]
    low = [(i, b) for i, b in town if floors_of(b) < tall_from]
    shut = set()
    for group, share, slots, cycle in ((tall, tall_share, (0, 2, 3, 7, 8, 10), 12), (low, None, (2, 9, 15), 20)):
        if share is None:      # whatever the tall buildings left of the overall share
            share = max(0.0, (shut_share * len(town) - len(shut)) / max(len(group), 1))
        owed = 0.0
        for n, (i, b) in enumerate(group):
            if n % cycle in slots:
                owed += share * cycle / len(slots)
            if owed >= 1.0 and i not in keep_open:
                owed -= 1.0
                shut.add(i)
    for i, b in ground:
        if b[7] in TOWN_KINDS:
            if i not in shut:
                enter.add(i)
        elif b[7] in ("shed", "hangar", "terminal", "mall", "hall", "carpark", "stadium", "tower") and b[3] * b[5] >= 100:
            enter.add(i)

    # ---- locked doors, and upstairs (owner, 2026-11-13) ----
    # A locked door means medium or high loot behind it, and something to break it with.
    # How often depends on the district's loot: the richer the district, the more locks.
    zones = [(z["rect"], z["tier"]) for z in plan["zones"]]

    def loot_at(x, z):
        for r, tier in zones:
            if r[0] <= x <= r[2] and r[1] <= z <= r[3]:
                return "yellow"
        for d in plan["districts"]:
            if d["loot"] in ("green", "yellow") and any(r[0] <= x <= r[2] and r[1] <= z <= r[3] for r in d["rects"]):
                return d["loot"]
        return "grey"

    every = rules["locked_door_one_in"]
    seen = {tier: 0 for tier in every}
    locked = []
    upstairs = 0
    for i, b in ground:
        if i in enter and b[7] in TOWN_KINDS:
            if b[4] >= 5.6:
                upstairs += 1
            if i in keep_open:
                continue
            tier = "yellow" if b[7] == "luxury" else loot_at(b[0], b[2])   # luxury flats are locked as often as a high-loot district
            seen[tier] += 1
            if seen[tier] % every[tier] == every[tier] // 2:
                locked.append([b[0], b[2], tier])

    # ---- birds ----
    birds = []
    tall = [b for _, b in ground if b[7] in TOWN_KINDS | {"shed", "stadium", "mast"} and b[4] >= 8]
    for c in coves:           # crows gather where people leave scraps
        near = sorted(tall, key=lambda b: math.hypot(b[0] - c["x"], b[2] - c["z"]))[:3]
        for b in near:
            if math.hypot(b[0] - c["x"], b[2] - c["z"]) < 130:
                birds.append({"kind": "crow", "on": "roof", "x": b[0], "z": b[2], "y": round(b[1] + b[4], 1), "count": 3, "why": c["name"]})
    for s in m.spaces:
        if s["kind"] in ("square", "station square"):
            birds.append({"kind": "pigeon", "on": "ground", "x": s["x"], "z": s["z"], "count": 8, "why": s.get("name", s["kind"])})
            near = [b for b in tall if math.hypot(b[0] - s["x"], b[2] - s["z"]) < 45]
            if near and "name" in s:
                b = max(near, key=lambda b: b[4])
                birds.append({"kind": "crow", "on": "roof", "x": b[0], "z": b[2], "y": round(b[1] + b[4], 1), "count": 2, "why": s["name"]})
    lake = water["lake"]
    for a in (0.6, 3.4):
        birds.append({"kind": "heron", "on": "ground", "x": round(lake["center"][0] + math.cos(a) * (lake["radii"][0] + 3), 1), "z": round(lake["center"][1] + math.sin(a) * (lake["radii"][1] + 3), 1), "count": 1, "why": "the park lake"})
    for line, share in ((water["stream"]["points"], (0.3, 0.7)), (water["river"]["points"], (0.2, 0.45, 0.7))):
        walk = Path(line)
        for f in share:
            x, z, tx, tz = walk.at(walk.length * f)
            birds.append({"kind": "heron", "on": "ground", "x": round(x - tz * 4, 1), "z": round(z + tx * 4, 1), "count": 1, "why": "the water's edge"})

    out = {
        "coves": [{"name": c["name"], "x": c["x"], "z": c["z"], "radius": c["radius"], "crew": c["crew"], "why": c["why"],
                   "lookouts": c["lookouts"], "patrol": [[round(x, 1), round(z, 1)] for x, z in c["patrol"]], "patrol_m": c["patrol_m"]} for c in coves],
        "scav_homes": [[x, z] for x, z, _ in homes],
        "robot_nests": [[x, z, why] for x, z, _, why in nests],
        "work_sites": [[round(x, 1), round(z, 1), length, cls] for x, z, length, cls in sites],
        "robot_patrols": patrols,
        "birds": birds,
        "locked_doors": locked,
        "charging_stations": [[s["x"], s["z"], s["bays"], s["robots"], s.get("why", "")] for s in m.spaces if s["kind"] == "charging station"],
        "upstairs": upstairs,
        "rules": rules,
    }
    return out, enter


def measure(m, enc, enter):
    """Plays many raids on paper: how far is a player on a street from something to do?"""
    plan = m.PLAN
    rules = enc["rules"]
    walk = lambda metres: metres * plan["rules"]["detour"] / plan["rules"]["walk_speed_mps"]
    streets = getattr(m, "town_streets", [])
    points = []
    for street in streets:
        s = 6.0
        while s < street["path"].length:
            x, z = street["path"].at(s)[:2]
            if plan["city"]["core"][0] < x < plan["city"]["core"][2] and plan["city"]["core"][1] < z < plan["city"]["core"][3]:
                points.append((x, z))
            s += 12.0
    P = np.array(points, dtype=np.float32)

    def nearest(targets):
        Tg = np.array(targets, dtype=np.float32).reshape(-1, 2)
        best = np.full(len(P), 1e9, dtype=np.float32)
        for k in range(0, len(Tg), 400):
            chunk = Tg[k:k + 400]
            d = np.sqrt(((P[:, None, :] - chunk[None, :, :]) ** 2).sum(axis=2))
            best = np.minimum(best, d.min(axis=1))
        return best

    lines = []
    core = plan["city"]["core"]
    town = [b for b in m.boxes if b[8] == 0.0 and core[0] <= b[0] <= core[2] and core[1] <= b[2] <= core[3]]
    paint = np.asarray(m.ground.crop((core[0] - m.X0, core[1] - m.Z0, core[2] - m.X0, core[3] - m.Z0))).astype(np.int64)
    packed = paint[:, :, 0] * 65536 + paint[:, :, 1] * 256 + paint[:, :, 2]
    import city_fabric
    surfaces = [m.ASPHALT, m.STREET, m.SIDEWALK, city_fabric.STREET_LOCAL, city_fabric.ALLEY, city_fabric.LANE]
    road = float(np.isin(packed, [c[0] * 65536 + c[1] * 256 + c[2] for c in surfaces]).sum())
    occ = packed
    roofs = sum(b[3] * b[5] for b in town if b[7] not in ("signal", "mast"))
    total = float(occ.size)
    lines.append("THE CITY (the built-up half of the map)")
    lines.append("  city area %.2f km2 of the map's 5.0; the rest is park, valley, forest, hills, airport land" % (total / 1e6))
    lines.append("  of that whole area: roofs %.0f%%, streets and roads %.0f%%, everything else (yards, parks, squares, plots, sites' open ground, water) %.0f%%" % (100 * roofs / total, 100 * road / total, 100 * (total - roofs - road) / total))
    fabric = getattr(m, "town_mask", None)
    if fabric is not None:
        stamp = Image.new("L", (m.W, m.H), 0)
        pen = ImageDraw.Draw(stamp)
        for b in m.boxes:
            if b[8] == 0.0 and b[7] not in ("signal", "mast"):
                pen.polygon(m.pts(m.corners(b[0], b[2], b[3], b[5], b[6])), fill=255)
        covered = (np.asarray(stamp) > 0) & fabric
        lines.append("  in the lived-in streets alone (no park, no big sites): roofs %.0f%% of the ground. From memory, real low-rise Tokyo is somewhat denser than that (not checked against a source)." % (100.0 * covered.sum() / max(fabric.sum(), 1)))

    door_list = [(m.boxes[i][0], m.boxes[i][2]) for i in sorted(enter)]
    town_doors = [(m.boxes[i][0], m.boxes[i][2]) for i in sorted(enter) if m.boxes[i][7].split("-")[0] in TOWN_KINDS]
    town_count = sum(1 for b in m.boxes if b[8] == 0.0 and b[7].split("-")[0] in TOWN_KINDS)
    d_door = nearest(door_list)
    lines.append("")
    lines.append("DOORS THAT OPEN")
    lines.append("  %d of %d town buildings can be entered (%.0f%%), plus %d site buildings" % (len(town_doors), town_count, 100.0 * len(town_doors) / max(town_count, 1), len(door_list) - len(town_doors)))
    lines.append("  %d town buildings stay shut (%.0f%%; the rule is %.0f%%)" % (town_count - len(town_doors), 100.0 * (town_count - len(town_doors)) / max(town_count, 1), 100 * rules["closed_building_share"]))
    lines.append("  from any point on a street, the nearest one is %.0f m away on average, %.0f m at worst" % (float(d_door.mean()), float(d_door.max())))

    lines.append("  by floors (open / shut):")
    table = {}
    upper = [0, 0]
    for i, b in enumerate(m.boxes):
        if b[8] != 0.0 or b[7].split("-")[0] not in TOWN_KINDS:
            continue
        floors = max(1, round((b[4] - 0.9) / 3.1))
        row = table.setdefault(min(floors, 10), [0, 0])
        row[0 if i in enter else 1] += 1
        if i in enter:
            upper[0] += floors - 1
            upper[1] += floors - 1 if floors >= 5 else 0
    for floors in sorted(table):
        lines.append("    %s floors: %d / %d" % ("10+" if floors == 10 else floors, table[floors][0], table[floors][1]))
    lines.append("  upper floors to fill: %d, of which %d in buildings of five floors or more" % tuple(upper))
    opened = [s for s in m.spaces if s["kind"] in ("pocket square", "pocket park", "garden", "coin car park", "bicycle park", "empty lot", "cafe terrace", "market stalls", "street shrine", "charging station", "police box", "billboard", "vending corner", "public toilet", "playground")]
    kinds = {}
    for s in opened:
        kinds[s["kind"]] = kinds.get(s["kind"], 0) + 1
    lines.append("  plots left open where a 5 to 7 floor building was not built: %d (%.1f hectares): %s" % (len(opened), sum(s["w"] * s["d"] for s in opened) / 1e4, ", ".join("%d %s" % (kinds[k], k) for k in sorted(kinds))))
    open_places = [(s["x"], s["z"]) for s in m.spaces if s["kind"] not in ("coin car park", "bicycle park", "empty lot", "charging station", "billboard", "vending corner", "public toilet", "police box", "turning circle")]
    by_tier = {}
    for _, _, tier in enc["locked_doors"]:
        by_tier[tier] = by_tier.get(tier, 0) + 1
    lines.append("  %d of the open ones have an upstairs (two floors or more)" % enc["upstairs"])
    lines.append("  %d have a locked door with medium or high loot behind it (%s); from a street point the nearest is %.0f m away on average" % (
        len(enc["locked_doors"]), ", ".join("%d in %s districts" % (by_tier[k], k) for k in sorted(by_tier)), float(nearest([l[:2] for l in enc["locked_doors"]]).mean())))
    d_open = nearest(open_places)
    worst = int(d_open.argmax())
    lines.append("")
    lines.append("ROOM TO BREATHE")
    lines.append("  %d squares, parks, pocket parks, gardens, shrine and temple grounds in the town" % len(open_places))
    lines.append("  from any point on a street, the nearest is %.0f m away on average (%.0f s walk); 9 in 10 points are within %.0f m; the worst is %.0f m, at x %.0f z %.0f"
                 % (float(d_open.mean()), walk(float(d_open.mean())), float(np.percentile(d_open, 90)), float(d_open.max()), P[worst][0], P[worst][1]))

    # Many raids: different homes, robots and work sites each time.
    rng = random.Random(m.SEED + 99)
    cove_pts = [(c["x"], c["z"]) for c in enc["coves"]]
    cove_r = np.array([c["radius"] for c in enc["coves"]], dtype=np.float32)
    routes = [Path(c["patrol"]) for c in enc["coves"]]
    robot_routes = [Path(p["points"]) for p in enc["robot_patrols"]]
    med, far, close = [], [], []
    for _ in range(200):
        live = []
        live += rng.sample(enc["scav_homes"], min(rules["scav_homes_per_raid"], len(enc["scav_homes"])))
        live += [n[:2] for n in rng.sample(enc["robot_nests"], min(rules["robot_nests_per_raid"], len(enc["robot_nests"])))]
        live += [w[:2] for w in rng.sample(enc["work_sites"], min(rules["work_sites_per_raid"], len(enc["work_sites"])))]
        live += rng.sample(town_doors, rules["roaming_scav_crews"])
        manned = [s[:2] for s in enc["charging_stations"] if s[3] > 0]
        live += rng.sample(manned, min(len(manned), round(len(manned) * rules["charging_stations_live_share"])))
        live += [r.at(rng.uniform(0, r.length))[:2] for r in routes]
        for r in robot_routes:
            live += [r.at(rng.uniform(0, r.length))[:2] for _ in range(rules["robot_groups_per_patrol"])]
        d = nearest(live)
        Cp = np.array(cove_pts, dtype=np.float32)
        dc = np.sqrt(((P[:, None, :] - Cp[None, :, :]) ** 2).sum(axis=2)) - cove_r[None, :]
        d = np.minimum(d, np.maximum(dc.min(axis=1), 0.0))
        med.append(float(np.median(d)))
        far.append(float(np.percentile(d, 90)))
        close.append(float((d < 100).mean()))
    count = (rules["scav_homes_per_raid"] + rules["robot_nests_per_raid"] + rules["work_sites_per_raid"] + rules["roaming_scav_crews"]
             + len(routes) + len(robot_routes) * rules["robot_groups_per_patrol"] + len(cove_pts))
    stations = enc["charging_stations"]
    live_stations = round(sum(1 for s in stations if s[3] > 0) * rules["charging_stations_live_share"])
    count += live_stations
    lines.append("")
    lines.append("SOMETHING ALIVE (200 raids played on paper, a different draw each time)")
    lines.append("  in one raid: %d coves, %d cove patrols, %d lived-in houses of %d, %d dormant robots of %d, %d robot work sites of %d, %d robot patrol groups, %d roaming scav crews = %d things"
                 % (len(cove_pts), len(routes), rules["scav_homes_per_raid"], len(enc["scav_homes"]), rules["robot_nests_per_raid"], len(enc["robot_nests"]),
                    rules["work_sites_per_raid"], len(enc["work_sites"]), len(robot_routes) * rules["robot_groups_per_patrol"], rules["roaming_scav_crews"], count))
    lines.append("  robot recharge stations: %d on the map with %d bays and %d robots standing in them; about %d stations live in one raid" % (len(stations), sum(s[2] for s in stations), sum(s[3] for s in stations), live_stations))
    lines.append("  from a point on a town street, the nearest is typically %.0f m away (%.0f s walk); 9 in 10 points are within %.0f m (%.0f s)"
                 % (float(np.mean(med)), walk(float(np.mean(med))), float(np.mean(far)), walk(float(np.mean(far)))))
    lines.append("  %.0f%% of street points have one within 100 m (close enough to hear or see)" % (100 * float(np.mean(close))))
    lines.append("  birds: %d spots (%d crow roofs, %d pigeon squares, %d water-bird spots)" % (
        len(enc["birds"]), sum(1 for b in enc["birds"] if b["kind"] == "crow"), sum(1 for b in enc["birds"] if b["kind"] == "pigeon"), sum(1 for b in enc["birds"] if b["kind"] == "heron")))
    return lines


def draw(m, sheet, enc, label):
    """The encounter picture: the map dimmed, with only this layer drawn bright."""
    from PIL import ImageEnhance
    picture = ImageEnhance.Brightness(sheet).enhance(0.5)
    draw_ = ImageDraw.Draw(picture, "RGBA")
    rust, steel, bird = (232, 120, 72, 255), (110, 190, 236, 255), (236, 236, 236, 255)

    def dots(points, colour, step, r):
        walk = Path(points)
        s = 0.0
        while s <= walk.length:
            x, z = walk.at(s)[:2]
            draw_.ellipse([x - m.X0 - r, z - m.Z0 - r, x - m.X0 + r, z - m.Z0 + r], fill=colour)
            s += step
    for p in enc["robot_patrols"]:
        dots(p["points"], steel, 14, 2.6)
    for c in enc["coves"]:
        dots(c["patrol"], rust, 10, 2.4)
    for x, z in enc["scav_homes"]:
        draw_.ellipse([x - m.X0 - 6, z - m.Z0 - 6, x - m.X0 + 6, z - m.Z0 + 6], fill=rust, outline=(20, 20, 20, 255))
    for x, z, _ in enc["robot_nests"]:
        draw_.rectangle([x - m.X0 - 6, z - m.Z0 - 6, x - m.X0 + 6, z - m.Z0 + 6], fill=steel, outline=(20, 20, 20, 255))
    for x, z, _, _ in enc["work_sites"]:
        draw_.line([x - m.X0 - 7, z - m.Z0 - 7, x - m.X0 + 7, z - m.Z0 + 7], fill=steel, width=4)
        draw_.line([x - m.X0 - 7, z - m.Z0 + 7, x - m.X0 + 7, z - m.Z0 - 7], fill=steel, width=4)
    for sx, sz, *_ in enc["charging_stations"]:
        draw_.ellipse([sx - m.X0 - 9, sz - m.Z0 - 9, sx - m.X0 + 9, sz - m.Z0 + 9], fill=(240, 244, 248, 255), outline=steel, width=4)
    for lx, lz, _ in enc["locked_doors"]:
        draw_.polygon([(lx - m.X0, lz - m.Z0 - 4), (lx - m.X0 + 4, lz - m.Z0), (lx - m.X0, lz - m.Z0 + 4), (lx - m.X0 - 4, lz - m.Z0)], fill=(240, 206, 90, 255))
    for b in enc["birds"]:
        x, z = b["x"] - m.X0, b["z"] - m.Z0
        if b["kind"] == "crow":
            draw_.polygon([(x, z - 6), (x - 5, z + 4), (x + 5, z + 4)], fill=(24, 24, 26, 255), outline=bird)
        else:
            draw_.ellipse([x - 3, z - 3, x + 3, z + 3], fill=bird)
    for c in enc["coves"]:
        x, z, r = c["x"] - m.X0, c["z"] - m.Z0, c["radius"]
        draw_.ellipse([x - r, z - r, x + r, z + r], fill=(232, 120, 72, 70), outline=rust, width=5)
        for lx, lz in c["lookouts"]:
            draw_.rectangle([lx - m.X0 - 5, lz - m.Z0 - 5, lx - m.X0 + 5, lz - m.Z0 + 5], outline=(255, 255, 255, 255), width=2)
        label(draw_, (x, z - r - 18), c["name"].upper(), 24, fill=(255, 196, 160))
    for d in m.PLAN["drops"]:
        x, z = d["x"] - m.X0, d["z"] - m.Z0
        draw_.polygon([(x, z - 13), (x - 11, z + 9), (x + 11, z + 9)], fill=(250, 250, 250, 255))
    # Its own legend, over the old one.
    left = m.W + 34
    draw_.rectangle([m.W, 0, picture.width, picture.height], fill=(22, 24, 26, 255))
    label(draw_, (left, 56), "SHINRAI · MAP 1", 34, anchor="lm")
    label(draw_, (left, 100), "What you meet between fights", 22, anchor="lm", fill=(210, 210, 204))
    label(draw_, (left, 130), "Defaults, to change. Draft %d." % m.PLAN["draft"], 18, anchor="lm", fill=(210, 210, 204))
    rules = enc["rules"]
    rows = [
        ("ring", rust, "Scav cove: camp, lookouts, heavy crew"), ("dots", rust, "Cove patrol route"),
        ("disc", rust, "House a scav may live in (%d of %d a raid)" % (rules["scav_homes_per_raid"], len(enc["scav_homes"]))),
        ("dots", steel, "Robot patrol route"),
        ("square", steel, "Robot may lie dormant here (%d of %d)" % (rules["robot_nests_per_raid"], len(enc["robot_nests"]))),
        ("cross", steel, "Robot work site: street closed (%d of %d)" % (rules["work_sites_per_raid"], len(enc["work_sites"]))),
        ("station", steel, "Robot recharge station (%d)" % len(enc["charging_stations"])),
        ("diamond", (240, 206, 90, 255), "Locked door: better loot, needs breaking (%d)" % len(enc["locked_doors"])),
        ("crow", bird, "Crows on a roof, watching"), ("disc", bird, "Pigeons, water birds"),
        ("drop", (250, 250, 250, 255), "Drop-off point"),
    ]
    y = 190
    for shape, colour, text in rows:
        cx = left + 16
        if shape == "ring":
            draw_.ellipse([cx - 13, y - 13, cx + 13, y + 13], fill=(232, 120, 72, 70), outline=colour, width=4)
        elif shape == "dots":
            for k in (-12, 0, 12):
                draw_.ellipse([cx + k - 3, y - 3, cx + k + 3, y + 3], fill=colour)
        elif shape == "disc":
            draw_.ellipse([cx - 6, y - 6, cx + 6, y + 6], fill=colour)
        elif shape == "square":
            draw_.rectangle([cx - 6, y - 6, cx + 6, y + 6], fill=colour)
        elif shape == "cross":
            draw_.line([cx - 7, y - 7, cx + 7, y + 7], fill=colour, width=4)
            draw_.line([cx - 7, y + 7, cx + 7, y - 7], fill=colour, width=4)
        elif shape == "station":
            draw_.ellipse([cx - 9, y - 9, cx + 9, y + 9], fill=(240, 244, 248, 255), outline=colour, width=4)
        elif shape == "diamond":
            draw_.polygon([(cx, y - 6), (cx + 6, y), (cx, y + 6), (cx - 6, y)], fill=colour)
        elif shape == "crow":
            draw_.polygon([(cx, y - 7), (cx - 6, y + 5), (cx + 6, y + 5)], fill=(24, 24, 26, 255), outline=colour)
        else:
            draw_.polygon([(cx, y - 10), (cx - 9, y + 7), (cx + 9, y + 7)], fill=colour)
        label(draw_, (left + 46, y), text, 17, anchor="lm")
        y += 40
    return picture
