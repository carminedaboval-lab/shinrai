"""Checks the Map 1 plan (docs/MAP1_MEASURED_PLAN.md, draft 3) by calculation.

Run:  python tools/map_plan/check_map1.py

The numbers live in data/map1/map1_plan.json: change one there, run this script, and copy
the tables it prints into the document. Metres; north is -z; the centre of Midori Park is (0, 0).
Rectangles are (x_min, z_min, x_max, z_max).
"""
import json
import math
import os

PLAN_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "data", "map1", "map1_plan.json")
with open(PLAN_PATH, encoding="utf-8") as handle:
    PLAN = json.load(handle)

# ---- frame and rules (owner's rules, with default numbers), all from the plan file ------
FRAME = tuple(PLAN["frame"])
RULES = PLAN["rules"]
TARGET_KM2 = RULES["target_km2"]
YELLOW_CLEAR = RULES["yellow_clear_m"]      # a drop must be more than this from any yellow zone
TOP_CLEAR = RULES["top_clear_m"]            # ... and more than this from orange or red
DROP_SPACING = RULES["drop_spacing_m"]      # neighbouring drops at least this far apart
HEARING = RULES["gunfire_heard_m"]          # default: how far gunfire carries (needs a sound test)
WALK_SPEED = RULES["walk_speed_mps"]
DETOUR = RULES["detour"]                    # streets are not straight lines
PLAYERS = RULES["players"]
GROUP_SIZE = RULES["group_size"]            # average players per group with squads of up to 3
RAID_MIN = RULES["raid_minutes"]
JOIN_UNTIL_MIN = RULES["join_until_minutes"]

ZONES = [(z["name"], z["tier"], tuple(z["rect"])) for z in PLAN["zones"]]
STATIONS = [(s["id"], s["x"], s["z"]) for s in PLAN["stations"]]
# Drop-offs, clockwise from the north-west.
DROPS = [(d["id"], d["x"], d["z"], d["area"]) for d in PLAN["drops"]]

def rect_distance(x, z, rect):
    x0, z0, x1, z1 = rect
    dx = max(x0 - x, 0, x - x1)
    dz = max(z0 - z, 0, z - z1)
    return math.hypot(dx, dz)


def walk_minutes(metres):
    return metres * DETOUR / WALK_SPEED / 60.0


def main():
    failures = []
    width = FRAME[2] - FRAME[0]
    depth = FRAME[3] - FRAME[1]
    area = width * depth / 1e6
    print(f"Frame: {width} m x {depth} m = {area:.2f} km2 (target {TARGET_KM2})")
    if abs(area - TARGET_KM2) > 0.05:
        failures.append("area is off target")

    print("\n| Drop | Position (x, z) | Area | Nearest high-value zone | Nearest other drop | Nearest station (walk) |")
    print("|---|---|---|---|---|---|")
    walks = {}
    for name, x, z, label in DROPS:
        if not (FRAME[0] <= x <= FRAME[2] and FRAME[1] <= z <= FRAME[3]):
            failures.append(f"{name} is outside the frame")
        nearest = None
        for zone, tier, rect in ZONES:
            distance = rect_distance(x, z, rect)
            limit = YELLOW_CLEAR if tier == "yellow" else TOP_CLEAR
            if distance <= limit:
                failures.append(f"{name} is {distance:.0f} m from {zone} ({tier}, needs more than {limit})")
            margin = distance - limit
            if nearest is None or margin < nearest[0]:
                nearest = (margin, zone, tier, distance)
        other = min(math.hypot(x - ox, z - oz) for oname, ox, oz, _ in DROPS if oname != name)
        if other < DROP_SPACING:
            failures.append(f"{name} is only {other:.0f} m from another drop (needs {DROP_SPACING})")
        station = min(STATIONS, key=lambda s: math.hypot(x - s[1], z - s[2]))
        station_distance = math.hypot(x - station[1], z - station[2])
        walks[name] = walk_minutes(station_distance)
        print(f"| {name} | ({x}, {z}) | {label} | {nearest[1]} ({nearest[2]}), {nearest[3]:.0f} m | {other:.0f} m | {station[0]}, ~{walks[name]:.0f} min |")

    print("\nBot posts between neighbouring drops (midpoint, distance to each drop):")
    print("| Between | Gap | Post (x, z) | Heard by both? |")
    print("|---|---|---|---|")
    for index, (name, x, z, _) in enumerate(DROPS):
        nname, nx, nz, _ = DROPS[(index + 1) % len(DROPS)]
        gap = math.hypot(x - nx, z - nz)
        mx, mz = (x + nx) / 2, (z + nz) / 2
        heard = "yes" if gap / 2 <= HEARING else f"no, {gap / 2:.0f} m each way: needs two posts"
        print(f"| {name}-{nname} | {gap:.0f} m | ({mx:.0f}, {mz:.0f}) | {heard} |")

    ordered = sorted(walks, key=walks.get, reverse=True)
    print("\nLongest walks first:", ", ".join(f"{n} {walks[n]:.0f} min" for n in ordered))

    orange = next(r for n, t, r in ZONES if t == "orange")
    red = next(r for n, t, r in ZONES if t == "red")
    gap_x = max(red[0] - orange[2], 0)
    gap_z = max(red[1] - orange[3], 0)
    print(f"\nOrange to red, edge to edge: {math.hypot(gap_x, gap_z):.0f} m")

    groups = PLAYERS / GROUP_SIZE
    for alive, label in ((0.75, "no backfill"), (0.90, "with backfill")):
        per_hour = 1.08 * 0.70 * alive * (groups - 1) / area
        per_raid = per_hour * RAID_MIN / 60.0
        print(f"Fights per hour ({label}, {alive:.0%} of groups alive on average): {per_hour:.1f}; "
              f"per {RAID_MIN}-minute raid: {per_raid:.1f}; chance of at least one: {1 - math.exp(-per_raid):.0%}")
    print(f"A player who joins at {JOIN_UNTIL_MIN} min has {RAID_MIN - JOIN_UNTIL_MIN} min left; "
          f"the last tram is called with 3 min left.")

    # Scav coves: heavy crews must not sit on top of a drop-off or a tram station.
    meet = PLAN.get("encounters", {})
    if meet:
        clear_drop = meet["rules"]["cove_clear_of_drops_m"]
        clear_station = meet["rules"]["cove_clear_of_stations_m"]
        print("\n| Scav cove | Position (x, z) | Crew | Nearest drop | Nearest station |")
        print("|---|---|---|---|---|")
        for cove in meet["coves"]:
            x, z, radius = cove["x"], cove["z"], cove["radius"]
            drop = min(DROPS, key=lambda d: math.hypot(x - d[1], z - d[2]))
            drop_gap = math.hypot(x - drop[1], z - drop[2]) - radius
            station = min(STATIONS, key=lambda s: math.hypot(x - s[1], z - s[2]))
            station_gap = math.hypot(x - station[1], z - station[2]) - radius
            if drop_gap < clear_drop:
                failures.append(f"{cove['name']} is {drop_gap:.0f} m from {drop[0]} (needs {clear_drop})")
            if station_gap < clear_station and "camp_on" not in cove:
                failures.append(f"{cove['name']} is {station_gap:.0f} m from {station[0]} (needs {clear_station})")
            print(f"| {cove['name']} | ({x}, {z}) | {cove['crew']} | {drop[0]}, {drop_gap:.0f} m | {station[0]}, {station_gap:.0f} m |")

    print("\nRESULT:", "pass" if not failures else "FAIL")
    for failure in failures:
        print("  -", failure)


if __name__ == "__main__":
    main()
