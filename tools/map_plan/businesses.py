"""Which shop-houses are what: corner shops and restaurants among the homes (owner's wish,
2026-11-14: the residential areas lacked visible restaurants, corner shops and petrol
stations).

The map already has hundreds of shop-houses, all alike. This names some of them, by where
they stand, the way a real town sorts itself:

  corner shop   at a real corner (two streets meet at the building), so that every home has
                one within REACH metres and no two stand closer than APART metres. Where a
                homes area has none in reach, one open house on a corner with a wider street
                becomes a shop-house; lanes deep inside keep all their houses.
  restaurant    on the wider streets and in the shopping, nightlife and old-town quarters,
                near tram stops and squares where people pass, in twos and threes; the kind
                follows the quarter.

Everything else stays an ordinary shop. Petrol stations are placed elsewhere (they need
land the street builder leaves free); this file only names buildings that exist.

build(m, meet, doors) returns {"list": [...], "measure": [lines]} and may turn a few "house"
boxes into "shop" boxes. Each entry of the list:
  {"box": index into the boxes, "x", "z", "type": "corner shop" | "restaurant",
   "what": the trade, "why": the placing rule in words, "was": "shop" | "house"}
"""
import math
import random

import numpy as np

REACH = 250.0        # every home should have a corner shop within this
APART = 120.0        # and corner shops stay this far apart, so each is a landmark
WORTH = 8            # an existing shop is named a corner shop if it brings this many homes into reach
## Shops placed by hand. Each turns the house nearest its point (within 3 m) into a shop-house.
## To take one away again, delete its line and rebuild the map.
PLACED = [
    # The north block of the homes area (x 40 to 215, z 330 to 400) had no shop at all, and the
    # koban lane none along its 228 m: from the middle of lane z378 the nearest shop door was a
    # 150 m walk (survey with Codex, 2026-11-15). The house on the north-east corner of lane z378
    # and lane x 85, the block's main crossroads, becomes the neighbourhood's corner shop.
    {"x": 91.8, "z": 367.2, "what": "tobacco and sweets shop",
     "why": "the north block's crossroads (lane z378 and lane x 85); the block had no shop, the nearest door was a 150 m walk"},
]
WORTH_NEW = 6        # a house is turned into one only if it brings this many
WIDE = {"ring", "grid", "arterial", "collector", "old"}
THROUGH = {"ring", "grid", "arterial", "collector"}
ANCHOR_NEAR = 60.0   # from a tram stop or a square
ANCHOR_FAR = 110.0
CLUSTER = 35.0       # no more than three restaurants within this of each other
SAME_TRADE = 60.0    # and no two of the same trade within this
CELL = 16.0

CORNER_TRADES_THROUGH = ("convenience store", "convenience store", "convenience store", "grocer")
CORNER_TRADES_QUIET = ("grocer", "rice and liquor shop", "tobacco and sweets shop", "convenience store")
RESTAURANTS = {
    "nightlife": ("izakaya", "yakitori bar", "ramen shop", "izakaya"),
    "old": ("soba shop", "coffee shop", "set-meal diner", "sushi counter"),
    "town": ("ramen shop", "set-meal diner", "coffee shop", "curry shop", "sushi counter"),
}


def _area(m, x, z):
    for area in m.PLAN["city"]["areas"]:
        if any(r[0] <= x < r[2] and r[1] <= z < r[3] for r in area["rects"]):
            return area["type"]
    return "homes"


def build(m, meet, doors):
    rng = random.Random(m.SEED + 6161)
    streets = getattr(m, "town_streets", [])
    grid = {}
    for number, street in enumerate(streets):
        path = street["path"]
        s = 0.0
        while s <= path.length:
            x, z = path.at(s)[:2]
            grid.setdefault((int(x // CELL), int(z // CELL)), []).append((x, z, number))
            s += 3.0

    def streets_by(x, z, reach):
        """Each street that passes within reach of a point, with how near it comes."""
        found = {}
        span = int(reach // CELL) + 1
        gx, gz = int(x // CELL), int(z // CELL)
        for ix in range(gx - span, gx + span + 1):
            for iz in range(gz - span, gz + span + 1):
                for px, pz, number in grid.get((ix, iz), ()):
                    gap = math.hypot(px - x, pz - z)
                    if gap <= reach and gap < found.get(number, 1e9):
                        found[number] = gap
        return found

    boxes = m.boxes
    homes = np.array([(b[0], b[2]) for b in boxes if b[7].split("-")[0] in ("house", "timber")], dtype=float)
    # Buildings somebody already has a use for keep it.
    spoken = set()
    for key in ("scav_homes", "robot_nests", "locked_doors"):
        for entry in meet.get(key, []):
            if isinstance(entry, (list, tuple)) and len(entry) >= 2:
                spoken.add((round(float(entry[0]), 1), round(float(entry[1]), 1)))
            elif isinstance(entry, dict) and "x" in entry:
                spoken.add((round(float(entry["x"]), 1), round(float(entry["z"]), 1)))

    def setting(index):
        box = boxes[index]
        x, z = box[0], box[2]
        near = streets_by(x, z, math.hypot(box[3], box[5]) * 0.5 + 9.0)
        classes = sorted({streets[n]["cls"] for n in near})
        front = streets[min(near, key=near.get)]["cls"] if near else None
        return {"index": index, "x": x, "z": z, "corner": len(near) >= 2, "front": front, "classes": classes,
                "wide": any(c in WIDE for c in classes), "through": any(c in THROUGH for c in classes), "area": _area(m, x, z)}

    shops = [setting(i) for i, b in enumerate(boxes) if b[7] == "shop" and b[8] == 0.0]
    houses = [setting(i) for i, b in enumerate(boxes) if b[7] in ("house", "timber") and b[8] == 0.0 and i in doors
              and (round(b[0], 1), round(b[2], 1)) not in spoken]

    # ---- corner shops: cover the homes ----
    def gain(place, far):
        return int(np.count_nonzero(far & (np.hypot(homes[:, 0] - place["x"], homes[:, 1] - place["z"]) <= REACH)))

    uncovered = np.ones(len(homes), dtype=bool)
    chosen = []

    def take(pool, least, was):
        nonlocal uncovered
        pool = list(pool)
        while pool:
            pool = [p for p in pool if all(math.hypot(p["x"] - c["x"], p["z"] - c["z"]) >= APART for c in chosen)]
            if not pool:
                break
            best = max(pool, key=lambda p: (gain(p, uncovered), p["through"], -p["index"]))
            won = gain(best, uncovered)
            if won < least:
                break
            best["was"], best["won"] = was, won
            chosen.append(best)
            uncovered &= np.hypot(homes[:, 0] - best["x"], homes[:, 1] - best["z"]) > REACH
            pool.remove(best)

    take([s for s in shops if s["corner"]], WORTH, "shop")
    left_before = int(np.count_nonzero(uncovered))
    # Where homes are still out of reach: a house on a corner with a wider street opens a shop.
    take([h for h in houses if h["corner"] and h["wide"]], WORTH_NEW, "house")
    out = []
    for place in chosen:
        box = boxes[place["index"]]
        if place["was"] == "house":
            box[7] = "shop"
        trades = CORNER_TRADES_THROUGH if place["through"] else CORNER_TRADES_QUIET
        why = "the corner of %s; brings %d homes within %d m of a corner shop" % (" and ".join("a %s street" % c for c in place["classes"][:2]) or "two streets", place["won"], REACH)
        if place["was"] == "house":
            why += "; was a house, the nearest shop was out of reach"
        out.append({"box": place["index"], "x": box[0], "z": box[2], "type": "corner shop", "what": rng.choice(trades), "why": why, "was": place["was"]})

    # ---- restaurants: where people pass ----
    anchors = [(s["x"], s["z"], "tram stop %s" % s["id"]) for s in m.PLAN.get("stations", [])]
    anchors += [(p["x"], p["z"], p["name"]) for p in m.PLAN.get("supply_points", [])]
    anchors += [(s["x"], s["z"], "a %s" % s["kind"]) for s in m.spaces if s["kind"] in ("square", "station square", "pocket square", "market stalls")]
    taken = {place["index"] for place in chosen}
    eating = []
    order = []
    for shop in shops:
        if shop["index"] in taken:
            continue
        gap, name = min(((math.hypot(shop["x"] - ax, shop["z"] - az), label) for ax, az, label in anchors), default=(1e9, ""))
        order.append((gap, shop["index"], shop, name))
    order.sort(key=lambda item: (item[0], item[1]))
    for gap, _, shop, name in order:
        quarter = "nightlife" if shop["area"] == "nightlife" else ("old" if shop["area"] == "old_res" or shop["front"] == "old" else "town")
        if gap <= ANCHOR_NEAR:
            chance, why = 0.4, "%d m from %s" % (round(gap), name)
        elif gap <= ANCHOR_FAR:
            chance, why = 0.2, "%d m from %s" % (round(gap), name)
        elif quarter == "nightlife":
            chance, why = 0.35, "in the nightlife quarter"
        elif shop["through"]:
            chance, why = 0.1, "on a through street"
        elif shop["area"] in ("shops", "old_res"):
            chance, why = 0.08, "in a shopping street"
        else:
            continue
        if rng.random() >= chance:
            continue
        close = [e for e in eating if math.hypot(e["x"] - shop["x"], e["z"] - shop["z"]) <= CLUSTER]
        if len(close) >= 3:
            continue
        trades = [t for t in RESTAURANTS[quarter]
                  if not any(e["what"] == t and math.hypot(e["x"] - shop["x"], e["z"] - shop["z"]) <= SAME_TRADE for e in eating)]
        if not trades:
            continue
        entry = {"box": shop["index"], "x": shop["x"], "z": shop["z"], "type": "restaurant", "what": rng.choice(trades), "why": why, "was": "shop"}
        eating.append(entry)
    out += eating

    # ---- what came of it ----
    corners = np.array([(e["x"], e["z"]) for e in out if e["type"] == "corner shop"], dtype=float)
    lines = ["businesses among the homes:"]
    if len(corners):
        nearest = np.min(np.hypot(homes[:, None, 0] - corners[None, :, 0], homes[:, None, 1] - corners[None, :, 1]), axis=1)
        ranked = np.sort(nearest)
        lines.append("  corner shops: %d (%d were shop-houses already, %d were houses on a corner with a wider street)" % (
            len(corners), sum(1 for e in out if e["type"] == "corner shop" and e["was"] == "shop"), sum(1 for e in out if e["was"] == "house")))
        lines.append("  a home's nearest corner shop: median %d m, nine in ten within %d m, the furthest %d m; %d of %d homes are beyond %d m (%d before any house was turned)" % (
            ranked[len(ranked) // 2], ranked[int(len(ranked) * 0.9)], ranked[-1], int(np.count_nonzero(nearest > REACH)), len(homes), REACH, left_before))
        gaps = [min(math.hypot(a[0] - b[0], a[1] - b[1]) for j, b in enumerate(corners) if j != i) for i, a in enumerate(corners)] if len(corners) > 1 else [0]
        lines.append("  two corner shops are never closer than %d m (rule: %d)" % (min(gaps), APART))
    trades = {}
    for entry in out:
        trades[entry["what"]] = trades.get(entry["what"], 0) + 1
    lines.append("  restaurants: %d of the %d open shop-houses; the other %d shop-houses stay ordinary shops" % (len(eating), len(shops), len(shops) - len(eating) - sum(1 for e in out if e["type"] == "corner shop" and e["was"] == "shop")))
    lines.append("  by trade: " + ", ".join("%s %d" % (name, trades[name]) for name in sorted(trades)))
    # ---- shops placed by hand, where a walk showed a gap the rules above do not see ----
    # (Added last and without the dice, so every business above stays exactly as it was.)
    for place in PLACED:
        near = [(math.hypot(b[0] - place["x"], b[2] - place["z"]), i) for i, b in enumerate(boxes) if b[7] in ("house", "timber") and b[8] == 0.0]
        gap, index = min(near, default=(1e9, -1))
        if gap > 3.0 or any(e["box"] == index for e in out):
            lines.append("  placed %s at (%.0f, %.0f): no house there to turn; left out" % (place["what"], place["x"], place["z"]))
            continue
        box = boxes[index]
        box[7] = "shop"
        out.append({"box": index, "x": box[0], "z": box[2], "type": "corner shop", "what": place["what"], "why": place["why"], "was": "house"})
        lines.append("  placed by hand: %s in the house at (%.0f, %.0f)" % (place["what"], box[0], box[2]))
    return {"list": out, "measure": lines}


def draw(m, sheet, entries):
    """The businesses on a copy of the plan picture: corner shops green, restaurants orange."""
    from PIL import ImageDraw
    picture = sheet.copy()
    pen = ImageDraw.Draw(picture)
    for entry in entries:
        x, y = m.px(entry["x"], entry["z"])
        colour = (60, 200, 90) if entry["type"] == "corner shop" else (255, 150, 40)
        pen.ellipse((x - 5, y - 5, x + 5, y + 5), fill=colour, outline=(0, 0, 0))
    return picture


GAP_LEAST, GAP_MOST = 9.0, 16.0     # a missing shop-house's width, or two narrow ones'
LOT_DEEP = 11.0                      # a bay's 5 m and the aisle in front of it
LOT_APRON = 2.4                      # from the building line out to the footway's back
PARKING = (112, 112, 114)            # city_fabric.PARKING: the kerb builder lowers the kerb in front of this grey


def fill_row_gaps(m):
    """A gap in a row of shop-houses that nothing was planned for becomes a coin car park.

    Runs last and draws only on the ground picture and into the list of spaces: no building,
    shop, station or plot moves, and it uses no random numbers. Returns the new spaces and
    one line for the measure."""
    made = []
    rows = [(i, b) for i, b in enumerate(m.boxes) if b[7].split("-")[0] == "shop" and b[8] == 0.0]
    for i, a in rows:
        turn = math.radians(a[6])
        ux, uz = math.cos(turn), -math.sin(turn)      # along the row
        vx, vz = math.sin(turn), math.cos(turn)       # through the building
        best = None
        for j, b in rows:
            if j == i or abs(((b[6] - a[6] + 90.0) % 180.0) - 90.0) > 1.0:
                continue
            dx, dz = b[0] - a[0], b[2] - a[2]
            along, through = dx * ux + dz * uz, dx * vx + dz * vz
            if along <= 0.0 or abs(through) > 1.0:
                continue
            gap = along - (a[3] + b[3]) * 0.5
            if best is None or along < best[0]:
                best = (along, gap, b)
        if best is None or not (GAP_LEAST <= best[1] <= GAP_MOST):
            continue
        along, gap, b = best
        middle = a[3] * 0.5 + gap * 0.5
        cx, cz = a[0] + ux * middle, a[2] + uz * middle
        # Which way is the street: the side with road within ten metres of the building line.
        front = None
        for sign in (1.0, -1.0):
            for reach in (3.0, 5.0, 7.0, 9.0):
                x, z = cx + vx * sign * (a[5] * 0.5 + reach), cz + vz * sign * (a[5] * 0.5 + reach)
                if m.occupied.getpixel((int(x - m.X0), int(z - m.Z0))) == 255:
                    front = sign
                    break
            if front is not None:
                break
        if front is None:
            continue
        # The lot: from the building line back LOT_DEEP, the gap wide. Nothing may stand in it.
        # (Looked at 1.5 m in from each neighbour: a building's own mark reaches past its walls.)
        line_x, line_z = cx + vx * front * a[5] * 0.5, cz + vz * front * a[5] * 0.5
        lot_x, lot_z = line_x - vx * front * LOT_DEEP * 0.5, line_z - vz * front * LOT_DEEP * 0.5
        clear = True
        for step_u in range(-4, 5):
            for step_v in range(-4, 5):
                x = lot_x + ux * (gap * 0.5 - 1.5) * step_u / 4.0 + vx * LOT_DEEP * 0.48 * step_v / 4.0
                z = lot_z + uz * (gap * 0.5 - 1.5) * step_u / 4.0 + vz * LOT_DEEP * 0.48 * step_v / 4.0
                if m.occupied.getpixel((int(x - m.X0), int(z - m.Z0))) != 0:
                    clear = False
        if not clear or any(abs((s["x"] - lot_x) * ux + (s["z"] - lot_z) * uz) < gap * 0.5 + s["w"] * 0.5 and abs((s["x"] - lot_x) * vx + (s["z"] - lot_z) * vz) < LOT_DEEP * 0.5 + s["d"] * 0.5 for s in m.spaces):
            continue
        # Painted from the footway's back to the lot's back, so the kerb is lowered in front of it.
        deep = LOT_DEEP + LOT_APRON
        paint_x, paint_z = line_x - vx * front * (LOT_DEEP - LOT_APRON) * 0.5, line_z - vz * front * (LOT_DEEP - LOT_APRON) * 0.5
        m.gd.polygon(m.pts(m.corners(paint_x, paint_z, gap, deep, a[6])), fill=PARKING)
        space = {"kind": "coin car park", "x": round(lot_x, 2), "z": round(lot_z, 2), "w": round(gap, 2), "d": LOT_DEEP, "turn": a[6],
                 "row_gap": True, "street": [round(vx * front, 4), round(vz * front, 4)], "between": [i, m.boxes.index(b)]}
        m.spaces.append(space)
        made.append(space)
    line = "  gaps in shop rows turned into coin car parks: %d%s" % (len(made), "".join(" (%.1f m wide at %.0f, %.0f)" % (s["w"], s["x"], s["z"]) for s in made[:6]))
    return made, line

TREE_EVERY = 9.0          # street trees along a plaza's road edge
TREE_BEHIND = 3.0         # from the footway's back to the trunk: behind the 2 m apron that falls from the footway to the plaza
PLAZA_DEEP = 60.0         # how far back from the road a plaza is looked for


def plant_plaza(m, name, centre_z, half, pavement, x_from, x_to, side):
    """The open paved ground along one side of a built road becomes a tree-lined plaza
    (owner's choice, 2026-11-14, for the south side of the shop row road).

    Runs last, uses no random numbers and moves nothing: it lists the plaza as a space, with
    where its trees stand, and adds those trees to the map's trees. `side` is +1 for the side
    of greater z. The road runs along x here."""
    back = centre_z + side * (half + pavement)
    row = back + side * TREE_BEHIND
    trees = []
    x = x_from + TREE_EVERY * 0.5
    while x <= x_to - TREE_EVERY * 0.5:
        # Not where anything stands or a road crosses, and not within 5 m of either.
        clear = all(m.occupied.getpixel((int(x + dx - m.X0), int(row + dz - m.Z0))) == 0 for dx in (-5.0, -2.5, 0.0, 2.5, 5.0) for dz in (0.0, side * 2.0))
        if clear:
            # Each tree its own size, from where it stands (no two alike in a row, none random).
            mixed = (int(x * 7.0) * 2654435761) & 0xFFFFFFFF
            mixed = ((mixed ^ (mixed >> 15)) * 2246822519) & 0xFFFFFFFF
            scale = 0.92 + 0.26 * ((mixed >> 11) % 1000) / 1000.0
            trees.append([round(x, 2), round(row, 2), round(scale, 3)])
        x += TREE_EVERY
    for tree in trees:
        m.trees.append(list(tree))
    space = {"kind": "plaza", "name": name, "row_plaza": True, "x": round((x_from + x_to) * 0.5, 2), "z": round(back + side * PLAZA_DEEP * 0.5, 2),
             "w": round(x_to - x_from, 2), "d": PLAZA_DEEP, "back": round(back, 2), "side": side, "trees": trees}
    m.spaces.append(space)
    return space, "  plaza along the %s: %d street trees, %.0f m apart, %.1f m behind the footway" % (name, len(trees), TREE_EVERY, TREE_BEHIND)