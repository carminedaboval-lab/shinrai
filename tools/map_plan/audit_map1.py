"""Gameplay audit of Map 1: is the spacing and the size of things right to start building on?

Run after build_map1_blockout.py:   python tools/map_plan/audit_map1.py

Reads data/map1/map1_plan.json and data/map1/generated/map1_blockout.json and prints one line
per check, PASS or FIX, with the numbers. It changes nothing. The limits are defaults, in
LIMITS below, and each says what it protects.
"""
import json
import math
import os
import random

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
PLAN = json.load(open(os.path.join(ROOT, "data", "map1", "map1_plan.json"), encoding="utf-8"))
DATA = json.load(open(os.path.join(ROOT, "data", "map1", "generated", "map1_blockout.json"), encoding="utf-8"))

LIMITS = {
    "drop_to_first_door_m": 260,      # a player who lands must reach something to search within about 90 s
    "drop_clear_of_threat_m": 150,    # and must not land inside a fight
    "straight_road_m": 450,           # the longest dead-straight view down a road: a sniper should not own a kilometre
    "tram_stop_clear_of_station_m": 18,  # a recharge station never wakes on someone just waiting for a tram
    "dead_zone_m": 260,               # no building is further than this from anything that can ever be alive
    "quiet_share": (0.15, 0.45),      # in one raid, the share of the town with nothing alive within 150 m: some calm, not empty
    "building_min_m2": 14, "building_max_m2": 3200,
    "attention_gap_min": 9.0,         # a player should notice something going off at least this often (minutes)
}
WALK = PLAN["rules"]["walk_speed_mps"] / PLAN["rules"]["detour"]
TOWN = {"house", "timber", "shop", "building", "tall", "slab", "office", "apartment", "luxury"}
results = []


def check(ok, text):
    results.append(ok)
    print(("PASS  " if ok else "FIX   ") + text)


def dist_to_line(p, line):
    best = 1e9
    for a, b in zip(line, line[1:]):
        dx, dz = b[0] - a[0], b[1] - a[1]
        l2 = dx * dx + dz * dz or 1e-9
        t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / l2))
        best = min(best, math.hypot(p[0] - a[0] - dx * t, p[1] - a[1] - dz * t))
    return best


def main():
    kinds = DATA["kinds"]
    enc = DATA["encounters"]
    boxes = [(b[0], b[2], b[3], b[5], b[4], kinds[b[7]]) for b in DATA["boxes"]]
    town = [b for b in boxes if b[5].split("-")[0] in TOWN and b[2] * b[3] >= 14]
    doors = [b for b in town if "-" not in b[5]]
    drops = [(d["id"], d["x"], d["z"]) for d in PLAN["drops"]]
    core = PLAN["city"]["core"]
    rules = enc["rules"]

    print("== LANDING ==")
    for name, x, z in drops:
        door = min(math.hypot(x - b[0], z - b[1]) for b in doors)
        threats = [("cove " + c["name"], math.hypot(x - c["x"], z - c["z"]) - c["radius"]) for c in enc["coves"]]
        threats += [("recharge station", math.hypot(x - s[0], z - s[1])) for s in enc["charging_stations"]]
        threats += [("dormant robot", math.hypot(x - n[0], z - n[1])) for n in enc["robot_nests"]]
        threats += [("scav home", math.hypot(x - h[0], z - h[1])) for h in enc["scav_homes"]]
        # A patrol is a group on the move, and no group starts a raid within 250 m of a drop-off (plan rule),`n        # so its road only counts as a threat when it runs right past the landing.`n        threats += [("robot patrol road " + p["name"], dist_to_line((x, z), p["points"]) + 90.0) for p in enc["robot_patrols"]]
        what, gap = min(threats, key=lambda t: t[1])
        check(door <= LIMITS["drop_to_first_door_m"] and gap >= LIMITS["drop_clear_of_threat_m"],
              "%s: first door %.0f m (%.0f s); nearest threat %s at %.0f m" % (name, door, door / WALK, what, gap))

    print("\n== TRAM STOPS AND RECHARGE STATIONS ==")
    for st in PLAN["stations"][:9]:
        gap = min(math.hypot(st["x"] - s[0], st["z"] - s[1]) for s in enc["charging_stations"])
        check(gap >= LIMITS["tram_stop_clear_of_station_m"], "%s: nearest recharge station %.0f m from the platform (wakes at %d m)" % (st["id"], gap, rules["charging_station_wake_m"]))
    spacing = min(math.hypot(a[0] - b[0], a[1] - b[1]) for i, a in enumerate(enc["charging_stations"]) for b in enc["charging_stations"][i + 1:])
    check(spacing >= 140, "closest two recharge stations are %.0f m apart" % spacing)

    print("\n== LONG STRAIGHT VIEWS (clear of stalled vehicles) ==")
    breakers = DATA.get("view_breakers", [])
    for road in PLAN["roads"]:
        if road.get("class") in ("expressway", "bridge", "ramp") or road["name"].startswith("Airport service"):
            continue
        pts = road["points"]
        run, longest = 0.0, 0.0
        heading, origin, ends = None, pts[0], (pts[0], pts[-1])
        for a, b in zip(pts, pts[1:]):
            h = math.atan2(b[1] - a[1], b[0] - a[0])
            length = math.hypot(b[0] - a[0], b[1] - a[1])
            straight = heading is not None and abs((h - heading + math.pi) % math.tau - math.pi) < math.radians(2.5)
            if not straight:
                origin, run = a, 0.0
            run += length
            heading = h
            if run > longest:
                longest, ends = run, (origin, b)
        if longest > 300:
            a, b = ends
            tx, tz = (b[0] - a[0]) / longest, (b[1] - a[1]) / longest
            marks = sorted((v[0] - a[0]) * tx + (v[1] - a[1]) * tz for v in breakers if v[2] == road["name"] and dist_to_line(v, [a, b]) < 14)
            marks = [0.0] + [s for s in marks if 0 < s < longest] + [longest]
            clear = max(q - p for p, q in zip(marks, marks[1:]))
            check(clear <= LIMITS["straight_road_m"], "%s: %.0f m straight, longest clear view %.0f m (%d groups of stalled vehicles)" % (road["name"], longest, clear, len(marks) - 2))

    print("\n== SIZES ==")
    zones = [z["rect"] for z in PLAN["zones"]]
    areas = sorted(b[2] * b[3] for b in town if not any(r[0] <= b[0] <= r[2] and r[1] <= b[1] <= r[3] for r in zones))
    check(areas[0] >= LIMITS["building_min_m2"] and areas[-1] <= LIMITS["building_max_m2"],
          "town buildings outside the loot sites: smallest %.0f m2, median %.0f m2, largest %.0f m2 (%d buildings)" % (areas[0], areas[len(areas) // 2], areas[-1], len(areas)))
    narrow = [b for b in town if min(b[2], b[3]) < 3.4]
    check(len(narrow) <= len(town) * 0.02, "%d town buildings are under 3.4 m wide (too narrow for a room and a stair)" % len(narrow))
    widths = {}
    for road in PLAN["roads"]:
        widths.setdefault(road.get("class", "?"), []).append(road["width"])
    print("      road widths by class: " + ", ".join("%s %s-%s m" % (k, min(v), max(v)) for k, v in sorted(widths.items())))
    gaps = [math.hypot(a["x"] - b["x"], a["z"] - b["z"]) for i, a in enumerate(enc["coves"]) for b in enc["coves"][i + 1:]]
    check(min(gaps) >= 250, "scav coves: closest two are %.0f m apart (a crew goes on guard at gunfire within 220 m, so one fight must not pull in the next cove)" % min(gaps))

    print("\n== DEAD ZONES AND QUIET ==")
    alive = [(c["x"], c["z"]) for c in enc["coves"]] + [tuple(h) for h in enc["scav_homes"]] + [(n[0], n[1]) for n in enc["robot_nests"]]
    alive += [(w[0], w[1]) for w in enc["work_sites"]] + [(s[0], s[1]) for s in enc["charging_stations"]]
    routes = [p["points"] for p in enc["robot_patrols"]] + [c["patrol"] for c in enc["coves"]]
    in_city = [b for b in town if core[0] < b[0] < core[2] and core[1] < b[1] < core[3]]
    sample = in_city[::3]
    worst = (0.0, None)
    for b in sample:
        d = min(min(math.hypot(b[0] - a[0], b[1] - a[1]) for a in alive), min(dist_to_line(b, r) for r in routes))
        if d > worst[0]:
            worst = (d, b)
    check(worst[0] <= LIMITS["dead_zone_m"], "the building furthest from anything that can ever be alive is %.0f m from it, at x %.0f z %.0f" % (worst[0], worst[1][0], worst[1][1]))

    rng = random.Random(11)
    quiet = []
    for _ in range(60):
        live = rng.sample(enc["scav_homes"], min(rules["scav_homes_per_raid"], len(enc["scav_homes"])))
        live += [n[:2] for n in rng.sample(enc["robot_nests"], min(rules["robot_nests_per_raid"], len(enc["robot_nests"])))]
        live += [w[:2] for w in rng.sample(enc["work_sites"], min(rules["work_sites_per_raid"], len(enc["work_sites"])))]
        manned = [s[:2] for s in enc["charging_stations"] if s[3] > 0]
        live += rng.sample(manned, round(len(manned) * rules["charging_stations_live_share"]))
        live += [(c["x"], c["z"]) for c in enc["coves"]]
        for r in routes:
            for _ in range(2):
                live.append(r[rng.randrange(len(r))])
        quiet.append(sum(1 for b in sample[::4] if min(math.hypot(b[0] - a[0], b[1] - a[1]) for a in live) > 150) / len(sample[::4]))
    share = sum(quiet) / len(quiet)
    low, high = LIMITS["quiet_share"]
    check(low <= share <= high, "in one raid %.0f%% of the town has nothing alive within 150 m (wanted %d to %d%%: calm stretches, not emptiness)" % (100 * share, low * 100, high * 100))

    events = PLAN.get("events")
    if events:
        print("\n== THINGS GOING OFF ==")
        minutes = PLAN["rules"]["raid_minutes"]
        gaps_all, seen_all = [], []
        places = {"coves": [(c["x"], c["z"]) for c in enc["coves"]], "work_sites": [(w[0], w[1]) for w in enc["work_sites"]],
                  "stations": [(s["x"], s["z"]) for s in PLAN["stations"][:9]], "chargers": [(s[0], s[1]) for s in enc["charging_stations"]],
                  "homes": [tuple(h) for h in enc["scav_homes"]], "depot": [(-590, -540)], "mast": [(618, -566)], "patrols": [r[len(r) // 2] for r in routes[:5]],
                  "drops_supply": [(d["x"], d["z"]) for d in PLAN.get("supply_points", [])],
                  "fuel": [(f["x"], f["z"]) for f in DATA.get("fuel_stations", [])]}
        for _ in range(40):
            happening = []
            for e in events["schedule"]:
                spots = places.get(e["where"], [])
                for t in e["minutes"]:
                    if e.get("everywhere"):
                        happening.append((t, None, 0))
                    elif e.get("along"):
                        lines = [PLAN["rail"]["loop"]] if e["where"] == "loop" else rng.sample(routes[:5], min(e.get("count", 1), 5))
                        for route in lines:
                            happening.append((t + rng.uniform(-1.0, 1.0), ("line", route), e["noticed_m"]))
                    elif spots:
                        for spot in rng.sample(spots, min(e.get("count", 1), len(spots))):
                            happening.append((t + rng.uniform(-1.0, 1.0), spot, e["noticed_m"]))
            for b in rng.sample(sample, 30):
                times = sorted(t for t, spot, r in happening if spot is None or (dist_to_line(b, spot[1]) <= r if spot[0] == "line" else math.hypot(b[0] - spot[0], b[1] - spot[1]) <= r))
                marks = [0.0] + times + [float(minutes)]
                gaps_all.append(max(q - p for p, q in zip(marks, marks[1:])))
                seen_all.append(len(times))
        gaps_all.sort()
        check(gaps_all[len(gaps_all) // 2] <= LIMITS["attention_gap_min"],
              "a player standing anywhere in town notices %.1f things going off in a raid on average; the longest wait between two is %.1f min typically, %.1f min in the worst tenth of places"
              % (sum(seen_all) / len(seen_all), gaps_all[len(gaps_all) // 2], gaps_all[int(len(gaps_all) * 0.9)]))

    print("\n%d checks, %d to fix" % (len(results), results.count(False)))


if __name__ == "__main__":
    main()
