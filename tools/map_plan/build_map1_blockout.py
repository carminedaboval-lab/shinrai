"""Builds the Map 1 map picture and grey blockout from the plan file.

Run:  python tools/map_plan/build_map1_blockout.py

Reads   data/map1/map1_plan.json
Writes  data/map1/generated/map1_ground.png      ground picture, 1 pixel = 1 metre (roads, water,
                                                 fields painted into it; the blockout's floor)
        data/map1/generated/map1_blockout.json   every box, shape, tree and marker of the blockout
        docs/map_concept/map1_plan_draft4.png    the same ground with footprints, zones, rails,
                                                 stations, drop-offs and names drawn on top

The blockout is a layout test at true size, not art: plain boxes with the right footprint,
height and spacing, so distances, sightlines and routes can be judged before anything real
is built. Same seed, same map, every run.

This file lays down the frame: ground, water, the roads of the plan, and the big sites (the
plaza, the depots, the campus, the stadium, the port, the airport, the dam, the countryside).
The lived-in city between them is built by city_fabric.py.
"""
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import city_fabric  # noqa: E402
import terrain  # noqa: E402
import country  # noqa: E402
import junctions  # noqa: E402
import encounters  # noqa: E402
import businesses  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
with open(os.path.join(ROOT, "data", "map1", "map1_plan.json"), encoding="utf-8") as handle:
    PLAN = json.load(handle)
X0, Z0, X1, Z1 = PLAN["frame"]
W, H = X1 - X0, Z1 - Z0
OUT = os.path.join(ROOT, "data", "map1", "generated")
OVERVIEW = os.path.join(ROOT, "docs", "map_concept", "map1_plan_draft%d.png" % PLAN["draft"])
SEED = 20261113

# Hand-drawn lines marked "smooth" have their corners rounded once, here, for everyone.
for _road in PLAN["roads"]:
    if _road.get("smooth"):
        _road["points"] = city_fabric.chaikin(_road["points"], 3)
PLAN["water"]["stream"]["points"] = city_fabric.chaikin(PLAN["water"]["stream"]["points"], 3)
PLAN["water"]["river"]["points"] = city_fabric.chaikin(PLAN["water"]["river"]["points"], 2)

CITY_GROUND = (124, 123, 116)
GROUND = {
    "park": (96, 104, 74), "plaza": (152, 150, 142), "rail_depot": (110, 105, 98), "robot_depot": (134, 136, 136),
    "port": (116, 116, 116), "island": (138, 128, 124), "airport": (104, 111, 84), "dam": (108, 104, 96),
    "forest": (64, 76, 52), "valley": (110, 114, 78), "approach": (104, 107, 82), "foothills": (90, 91, 72),
    "fringe": (106, 110, 88),
}
ASPHALT = (60, 60, 62)
STREET = (74, 74, 76)
STREET_TRIAL = (112.0, 447.0)   # the homes street that gets the first real kerb (ROAD-002)
HOMES_BLOCK = (40.0, 400.0, 180.0, 525.0)   # x from, z from, x to, z to: every lane in here gets a real edge
EAST_LANES = (240.0, 395.0, 400.0, 530.0)   # east of the turning circle: a square grid of lanes, from clear of the tram street to clear of the collector at x 410
# Junctions where several streets share one space, left as the painted road for now (agreed with
# Codex, 2026-11-14): the detailed kerbs stop on clear approaches round them.
DEFERRED_JUNCTIONS = [
    {"name": "tram fork", "x": 191.0, "z": 490.0, "why": "Tram street south turns north-east and lane z 496.5 goes straight on east from inside it"},
    {"name": "diagonal at lane z 466 and lane x 224", "x": 220.0, "z": 463.0, "why": "both lanes meet the diagonal tram street within its footway zone, 7 m apart, and cross each other there"},
]
DIAGONAL_PILOT = (200.0, 452.0, 232.0, 481.5)   # where Tram street south runs diagonally: the first lanes that meet a street at an angle
NORTH_OF_KOBAN = (40.0, 330.0, 215.0, 400.0)  # north of the koban lane, to clear of the tram street's north-south stretch (west footway back x 221)
KOBAN_EAST = (180.0, 400.0, 215.0, 425.0)     # and lane x 188.7's last stretch, so it meets the koban lane on the map's lines
# (The diagonal pilot is left out until the compound junction there is designed: see road-discussion.md, 2026-11-14 evening.)
# The tram fork, stage A (agreed with Codex, owner's yes 2026-11-15): the lane that carries straight on
# east where Tram street south bends away (lane z 497), from clear of the fork's point at x 195 to
# where the east grid takes it up at x 240, with the two lanes that cross it at x 218 and x 224.
# The fork itself (the bend, the south footway's shift, the point between lane and street) is
# stage B and stays painted.
FORK_APPROACH = (200.0, 484.0, 240.0, 509.0)
TRAM_SOUTH_TO = 187.27         # and Tram street south's own edge runs on to here: where the fork's inner kerb curve begins, 3.7 m short of the bend at x 191 and clear of house 1661's door (x 186.3)
FORK_KERB_HALF = 1.6           # the fork's south kerb is laid as one side of a narrow strip this far from its line
FORK_CURVE_FROM = 188.0        # where that kerb's S begins: past house 1661's door and east wall
FORK_LEAD_EAST = 0.6           # and a unit's length of straight kerb before the lane's built start
BLOCKS = (HOMES_BLOCK, EAST_LANES, NORTH_OF_KOBAN, KOBAN_EAST, FORK_APPROACH)
TRAM_SOUTH = (120.0, 490.0)    # Tram street, south: the wide street across the south of the homes block
KOBAN_LANE = (96.0, 412.0)     # the lane north of the trial street, with the police box and the cafe terrace
SHOP_ROW = (-340.0, -447.0)    # the wide road in front of the shop row: the first wide road with a real kerb
RING_KERB_X = -468.0          # the Outer ring's east kerb as painted where the shop row meets it
SHOP_WEST_CORNER_R = 5.5      # the shop row's corners into the Outer ring
SHOP_ROW_SPAN = (-440.0, -230.0)   # only this stretch of it, by x: past the T-junction with Tram street, west (x -263 to -249), so the kerb can turn that corner
SIDEWALK = (148, 146, 140)
LANE = (98, 92, 80)
PATH = (132, 124, 104)
RAIL_BED = (86, 82, 76)
WATER = (60, 86, 100)
CONCRETE = (150, 150, 146)
PAVING = (164, 160, 150)
GREEN = (98, 108, 76)
GRAVEL = (152, 146, 130)
FIELDS = [(126, 128, 84), (118, 122, 76), (134, 131, 94), (112, 118, 70), (140, 136, 100)]
TIER = {"yellow": (222, 184, 60), "orange": (226, 128, 48), "red": (206, 70, 70), "green": (110, 170, 96), "grey": (150, 150, 150)}
ROAD_COLOUR = {"avenue": ASPHALT, "street": STREET, "highway": ASPHALT, "country": LANE, "bridge": CONCRETE, "ramp": ASPHALT}
WITH_SIDEWALK = {"ring": 6, "grid": 6, "arterial": 6, "collector": 4}

ground = Image.new("RGB", (W, H), (90, 92, 74))
occupied = Image.new("L", (W, H), 0)  # 255 = road, rail or water; lower values = something stands here
gd = ImageDraw.Draw(ground)
od = ImageDraw.Draw(occupied)
boxes = []    # [x, y_base, z, w, h, d, rot_deg, kind]
shapes = []   # {"shape": "pyramid" | "dome" | "cylinder", ...}
trees = []    # [x, z, scale]
spaces = []   # small public places: {"kind", "x", "z", "w", "d", optional "name"}
TERRAIN = None   # terrain.Terrain: the heights of the ground, set first thing in main()
STEEP_STEP = 7.0  # nobody builds where the ground falls this much across one footprint


# ---- drawing and placing ----------------------------------------------------------------

def px(x, z):
    return (x - X0, z - Z0)


def pts(points):
    return [px(x, z) for x, z in points]


def rect_px(rect):
    return [rect[0] - X0, rect[1] - Z0, rect[2] - X0, rect[3] - Z0]


def paint_line(points, width, colour, block=True):
    gd.line(pts(points), fill=colour, width=max(1, round(width)), joint="curve")
    if block:
        od.line(pts(points), fill=255, width=max(1, round(width) + 2), joint="curve")


def paint_poly(points, colour, block=False):
    gd.polygon(pts(points), fill=colour)
    if block:
        od.polygon(pts(points), fill=255)


def corners(x, z, w, d, rot):
    a = math.radians(rot)
    ca, sa = math.cos(a), math.sin(a)
    out = []
    for lx, lz in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)):
        out.append((x + lx * ca + lz * sa, z - lx * sa + lz * ca))
    return out


def is_free(x, z, w, d, rot=0.0, margin=0.0):
    """True when the footprint (grown by margin) touches no road, water, rail or building."""
    w2, d2 = w + margin * 2, d + margin * 2
    a = math.radians(rot)
    ca, sa = math.cos(a), math.sin(a)
    nx = max(2, math.ceil(w2 / 2.5))
    nz = max(2, math.ceil(d2 / 2.5))
    for i in range(nx + 1):
        for j in range(nz + 1):
            lx = -w2 / 2 + w2 * i / nx
            lz = -d2 / 2 + d2 * j / nz
            sx = x + lx * ca + lz * sa
            sz = z - lx * sa + lz * ca
            if not (X0 + 2 <= sx < X1 - 2 and Z0 + 2 <= sz < Z1 - 2):
                return False
            if occupied.getpixel((int(sx - X0), int(sz - Z0))) > 0:
                return False
    return True


def add_box(x, z, w, d, h, rot=0.0, y=0.0, kind="building", force=False, margin=0.0, stamp=True, absolute=False):
    if not force and not is_free(x, z, w, d, rot, margin):
        return False
    if absolute:
        base = y
    else:
        levels = [TERRAIN.at(cx, cz) for cx, cz in corners(x, z, w, d, rot)] + [TERRAIN.at(x, z)]
        low, high = min(levels), max(levels)
        if not force and high - low > STEEP_STEP:
            return False
        if y > 0.0:      # a part that sits on top of something else
            base = high + y
        else:            # stands on the ground: its foundation reaches the lowest corner
            base = low - 0.3
            h = h + (high - low) + 0.3
    boxes.append([round(x, 2), round(base, 2), round(z, 2), round(w, 2), round(h, 2), round(d, 2), round(rot, 1), kind, (99.0 if kind in ("deck", "pillar") else 0.0) if absolute else y])
    if stamp:
        od.polygon(pts(corners(x, z, w, d, rot)), fill=200)
    return True


def add_tree(x, z, scale):
    if not (X0 + 3 <= x < X1 - 3 and Z0 + 3 <= z < Z1 - 3):
        return
    if occupied.getpixel((int(x - X0), int(z - Z0))) > 0:
        return
    trees.append([round(x, 1), round(z, 1), round(scale, 2)])


def scatter_trees(rect, rng, cell, fill, scale=(0.8, 1.35), holes=()):
    """Natural scatter: a jittered coarse lattice with random gaps, never rows."""
    z = rect[1] + rng.uniform(0, cell)
    while z < rect[3]:
        x = rect[0] + rng.uniform(0, cell)
        while x < rect[2]:
            tx, tz = x + rng.uniform(-cell * 0.48, cell * 0.48), z + rng.uniform(-cell * 0.48, cell * 0.48)
            if rng.random() < fill and not any(math.hypot(tx - hx, tz - hz) < hr for hx, hz, hr in holes):
                add_tree(tx, tz, rng.uniform(*scale))
            x += cell * rng.uniform(0.75, 1.3)
        z += cell * rng.uniform(0.75, 1.3)


def wobbly(a, b, rng, step, sway):
    """A line from a to b that never runs straight for long."""
    length = math.hypot(b[0] - a[0], b[1] - a[1])
    count = max(1, int(length / step))
    nx, nz = -(b[1] - a[1]) / max(length, 0.01), (b[0] - a[0]) / max(length, 0.01)
    out = [a]
    for i in range(1, count):
        t = i / count
        off = rng.uniform(-sway, sway)
        out.append((a[0] + (b[0] - a[0]) * t + nx * off, a[1] + (b[1] - a[1]) * t + nz * off))
    out.append(b)
    return out


def in_poly(x, z, poly):
    inside = False
    for (ax, az), (bx, bz) in zip(poly, poly[1:] + poly[:1]):
        if (az > z) != (bz > z) and x < ax + (bx - ax) * (z - az) / (bz - az):
            inside = not inside
    return inside


def make_place(rect, kind, rng, name=None):
    """A named square or park from the plan file, placed before anything is built round it."""
    x0, z0, x1, z1 = rect
    cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
    box = rect_px(rect)
    if kind == "square":
        gd.rectangle(box, fill=PAVING)
        for _ in range(rng.randint(3, 6)):
            add_tree(rng.uniform(x0 + 3, x1 - 3), rng.uniform(z0 + 3, z1 - 3), rng.uniform(0.6, 0.9))
        add_box(cx + rng.uniform(-w * 0.15, w * 0.15), cz + rng.uniform(-d * 0.15, d * 0.15), 2.2, 2.2, rng.uniform(2.5, 4.5), kind="landmark", force=True, stamp=False)
        for _ in range(rng.randint(1, 3)):   # a kiosk or a stall on the edge
            add_box(rng.uniform(x0 + 3, x1 - 3), rng.choice([z0 + 2.5, z1 - 2.5]), rng.uniform(2.5, 4), 2.4, 2.6, kind="small", force=True, stamp=False)
    else:
        gd.rectangle(box, fill=GREEN)
        gd.line(pts(wobbly((x0, cz + rng.uniform(-d * 0.3, d * 0.3)), (x1, cz + rng.uniform(-d * 0.3, d * 0.3)), rng, 9, 2.5)), fill=PATH, width=2)
        for _ in range(int(w * d / 70) + 2):
            add_tree(rng.uniform(x0 + 2, x1 - 2), rng.uniform(z0 + 2, z1 - 2), rng.uniform(0.6, 1.1))
        for _ in range(3):
            add_box(rng.uniform(x0 + 6, x1 - 6), rng.uniform(z0 + 6, z1 - 6), rng.uniform(1.5, 3), rng.uniform(1.5, 3), rng.uniform(1.2, 2.4), rot=rng.uniform(0, 90), kind="small", force=True, stamp=False)
    od.rectangle(box, fill=180)
    space = {"kind": kind, "x": round(cx, 1), "z": round(cz, 1), "w": round(w, 1), "d": round(d, 1)}
    if name:
        space["name"] = name
    spaces.append(space)


# ---- ground, water, roads, rails ----------------------------------------------------------

def paint_base():
    core = PLAN["city"]["core"]
    for district in PLAN["districts"]:
        colour = GROUND.get(district["pattern"])
        if colour is None:
            continue
        if district["pattern"] in ("plaza", "rail_depot", "robot_depot", "port", "park", "island"):
            continue   # drawn after the city's ground, below
        for rect in district["rects"]:
            gd.rectangle(rect_px(rect), fill=colour)
    gd.rectangle(rect_px(core), fill=CITY_GROUND)
    for district in PLAN["districts"]:
        if district["pattern"] in ("plaza", "rail_depot", "robot_depot", "port", "park"):
            for rect in district["rects"]:
                gd.rectangle(rect_px(rect), fill=GROUND[district["pattern"]])
    water = PLAN["water"]
    for key in ("bay", "south_water", "reservoir"):
        paint_poly(water[key], WATER, block=True)
    paint_line(water["river"]["points"], water["river"]["width"], WATER)
    paint_stream(block=True)
    cx, cz = water["lake"]["center"]
    rx, rz = water["lake"]["radii"]
    box = [cx - rx - X0, cz - rz - Z0, cx + rx - X0, cz + rz - Z0]
    gd.ellipse(box, fill=WATER)
    od.ellipse(box, fill=255)
    for district in PLAN["districts"]:   # the island's ground sits on top of the bay
        if district["pattern"] == "island":
            for rect in district["rects"]:
                gd.rounded_rectangle(rect_px(rect), radius=60, fill=GROUND["island"])
                od.rectangle(rect_px(rect), fill=0)


def paint_stream(block):
    """The park lake's outflow to the bay: water between green banks with a footpath."""
    stream = PLAN["water"]["stream"]
    line = pts(stream["points"])
    gd.line(line, fill=GREEN, width=stream["banks"], joint="curve")
    gd.line([(x + 4, y - 4) for x, y in line], fill=PATH, width=2, joint="curve")
    gd.line(line, fill=WATER, width=stream["width"], joint="curve")
    if block:
        od.line(line, fill=255, width=stream["banks"] + 2, joint="curve")


def stream_trees(rng):
    for x, z in city_fabric.dense(PLAN["water"]["stream"]["points"], 7.0):
        if rng.random() < 0.5:
            side = rng.choice([-1, 1])
            trees.append([round(x + rng.uniform(-2, 2), 1), round(z + side * rng.uniform(5.0, 7.0), 1), round(rng.uniform(0.6, 1.0), 2)])


def station_square(station):
    sx, sz = station["x"], station["z"]
    outward = (1 if sx > 0 else -1, 0) if abs(sx) > 200 else (0, 1 if sz > 0 else -1)
    return sx + outward[0] * 29, sz + outward[1] * 24


def paint_roads(first):
    """The roads and rails of the plan. first=True also marks them so nothing is built on
    them; later calls only draw them again, on top of what the town painted."""
    if first:
        for road in PLAN["roads"]:   # pavements under every town road, before any asphalt
            extra = WITH_SIDEWALK.get(road.get("class", ""))
            if extra:
                gd.line(pts(road["points"]), fill=SIDEWALK, width=road["width"] + extra, joint="curve")
    for road in sorted(PLAN["roads"], key=lambda r: r["width"]):
        line = pts(road["points"])
        if road["kind"] == "expressway":
            # Elevated: nothing is built under it, but the ground below stays open.
            if first:
                od.line(line, fill=255, width=road["width"] + 4, joint="curve")
            gd.line(line, fill=(84, 84, 84), width=road["width"], joint="curve")
            continue
        gd.line(line, fill=ROAD_COLOUR[road["kind"]], width=max(1, round(road["width"])), joint="curve")
        if first:
            od.line(line, fill=255, width=round(road["width"]) + 2, joint="curve")
    for station in PLAN["stations"][:9]:   # every tram station has a paved square of its own
        cx, cz = station_square(station)
        box = [cx - 17 - X0, cz - 14 - Z0, cx + 17 - X0, cz + 14 - Z0]
        gd.rounded_rectangle(box, radius=6, fill=PAVING)
        if first:
            od.rectangle(box, fill=180)
            spaces.append({"kind": "station square", "x": cx, "z": cz, "w": 34, "d": 28})
    for key in ("loop", "airport_branch", "mountain_line"):
        gd.line(pts(PLAN["rail"][key]), fill=RAIL_BED, width=6, joint="curve")
        if first:
            od.line(pts(PLAN["rail"][key]), fill=255, width=8, joint="curve")


def elevated_road(road):
    """Deck boxes on pillars along the expressway."""
    deck_y, thick = 9.0, 1.4
    points = road["points"]
    for a, b in zip(points, points[1:]):
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        rot = math.degrees(math.atan2(-(b[1] - a[1]), b[0] - a[0]))
        add_box((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, length + 6, road["width"], thick, rot=rot, y=deck_y, kind="deck", force=True, stamp=False)
        count = max(1, int(length / 34))
        for i in range(count):
            t = (i + 0.5) / count
            add_box(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, 2.4, 6.0, deck_y, rot=rot, kind="pillar", force=True, stamp=False)


def bridge_deck(road):
    """A real deck over the water, level with the land at both ends."""
    points = road["points"]
    for a, b in zip(points, points[1:]):
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        rot = math.degrees(math.atan2(-(b[1] - a[1]), b[0] - a[0]))
        add_box((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, length + 4, road["width"], 0.9, rot=rot, y=terrain.PLAIN - 0.9, kind="deck", force=True, stamp=False, absolute=True)
        for t in (0.25, 0.75):
            add_box(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, 2.0, road["width"] - 3, terrain.PLAIN - 0.9, rot=rot, y=0.0, kind="pillar", force=True, stamp=False, absolute=True)


# ---- the big sites ------------------------------------------------------------------------

def gen_park(d, rng):
    rect = d["rects"][0]
    for a, b in (((-215, -40), (200, 120)), ((-120, -175), (-40, 175)), ((120, -170), (150, 170)), ((-210, 110), (210, -120))):
        paint_line(wobbly(a, b, rng, 30, 12), 3, PATH)
    scatter_trees(rect, rng, 9.0, 0.62, holes=[(40, 20, 105), (-150, 100, 34), (150, -110, 30)])


def gen_plaza(d, rng):
    rect = d["rects"][0]
    gd.rectangle(rect_px([-100, -640, 100, -490]), fill=(166, 164, 156))
    od.rectangle(rect_px([-56, -621, 56, -509]), fill=255)  # the pyramid
    shapes.append({"shape": "pyramid", "x": 0, "z": -565, "y": 0, "size": 100, "height": 62, "kind": "glass"})
    for _ in range(7):  # irregular sunken gardens, never rows
        gx, gz = rng.uniform(rect[0] + 20, rect[2] - 20), rng.uniform(rect[1] + 12, rect[3] - 12)
        if abs(gx) < 122 and -662 < gz < -468:
            continue
        gd.ellipse([gx - rng.uniform(8, 18) - X0, gz - rng.uniform(6, 13) - Z0, gx + rng.uniform(8, 18) - X0, gz + rng.uniform(6, 13) - Z0], fill=(100, 108, 78))
    for _ in range(240):
        along_x = rng.random() < 0.6
        w, dep = (rng.uniform(46, 72), rng.uniform(20, 28)) if along_x else (rng.uniform(20, 28), rng.uniform(46, 72))
        add_box(rng.uniform(rect[0] + 40, rect[2] - 40), rng.uniform(rect[1] + 26, rect[3] - 22), w, dep, rng.randint(8, 20) * 3.6, kind="slab", margin=6)
    for x, z in ((-140, -474), (140, -474), (0, -688)):
        add_box(x, z, 8, 5, 3.2, kind="small", margin=1)


def gen_mall(d, rng):
    add_box(500, 208, 230, 112, 16, kind="mall", margin=2)
    shapes.append({"shape": "dome", "x": 500, "z": 208, "y": 16, "size": 106, "height": 30, "kind": "glass"})
    add_box(642, 174, 54, 46, 15, kind="carpark", margin=2)
    add_box(352, 254, 38, 22, 7, kind="small", margin=2)
    gd.rectangle(rect_px([336, 132, 380, 232]), fill=(104, 104, 106))      # open car park, plain
    gd.rectangle(rect_px([618, 208, 668, 290]), fill=(104, 104, 106))


def gen_danchi(d, rng):
    rect, poly = d["rects"][0], d["site_poly"]
    # The estate's own green, playground and little square, with the slabs standing round them.
    make_place([-392, -264, -324, -212], "park", rng)
    make_place([-446, -214, -402, -174], "park", rng)
    make_place([-312, -420, -276, -386], "square", rng)
    shapes.append({"shape": "cylinder", "x": -355, "z": -300, "y": 20, "size": 9, "height": 10, "kind": "landmark"})
    add_box(-355, -300, 3, 3, 20, kind="mast", force=True)
    angles = [0, 90, 24, -32, 62, -58]
    last = []
    for _ in range(1400):
        w = 58 if rng.random() < 0.55 else 40
        angle = rng.choice(angles)
        if last[-2:] == [angle, angle]:
            continue
        x, z = rng.uniform(rect[0] + 30, rect[2] - 30), rng.uniform(rect[1] + 30, rect[3] - 20)
        if in_poly(x, z, poly) and add_box(x, z, w, 11.5, rng.randint(5, 11) * 2.9, rot=angle, kind="slab", margin=8.5):
            last.append(angle)
    towers = 0
    for _ in range(80):
        x, z = rng.uniform(rect[0] + 26, rect[2] - 26), rng.uniform(rect[1] + 26, rect[3] - 26)
        if towers < 3 and in_poly(x, z, poly) and add_box(x, z, 18, 18, rng.randint(12, 14) * 2.9, rot=rng.choice([0, 30, 45]), kind="tall", margin=12):
            towers += 1
    for w, dep, h in ((50, 10, 4), (24, 16, 4), (26, 18, 6), (12, 5, 2.6)):
        for _ in range(80):
            x, z = rng.uniform(rect[0] + 20, rect[2] - 20), rng.uniform(rect[1] + 20, rect[3] - 20)
            if in_poly(x, z, poly) and add_box(x, z, w, dep, h, rot=rng.choice([0, 90, 24]), kind="small", margin=4):
                break
    for _ in range(420):
        x, z = rng.uniform(rect[0] + 4, rect[2] - 4), rng.uniform(rect[1] + 4, rect[3] - 4)
        if in_poly(x, z, poly) and rng.random() < 0.5:
            add_tree(x, z, rng.uniform(0.6, 1.0))


def gen_campus_medical(d, rng):
    add_box(-610, 105, 92, 24, 27, kind="slab", margin=3)        # ward block
    add_box(-610, 105, 20, 20, 0.6, y=27, kind="landmark", force=True, stamp=False)  # helipad
    add_box(-615, 172, 64, 40, 12, kind="building", margin=3)    # outpatients
    add_box(-548, 150, 22, 12, 4.5, kind="small", margin=2)      # ambulance bay
    add_box(-672, 180, 16, 30, 9, kind="building", margin=2)     # staff block
    gd.rectangle(rect_px([-560, 62, -526, 128]), fill=(104, 104, 106))   # car park, plain
    scatter_trees(d["rects"][0], rng, 18.0, 0.34, scale=(0.6, 1.0))


def gen_school(d, rng):
    add_box(-350, 96, 74, 12, 12, kind="building", margin=3)     # classroom blocks
    add_box(-340, 142, 60, 12, 12, rot=8, kind="building", margin=3)
    add_box(-290, 250, 40, 26, 10, kind="building", margin=3)    # gym
    add_box(-372, 266, 30, 16, 4, kind="small", margin=2)        # pool
    gd.rectangle(rect_px([-410, 170, -330, 232]), fill=(126, 118, 92))  # sports ground
    od.rectangle(rect_px([-410, 170, -330, 232]), fill=180)
    scatter_trees(d["rects"][0], rng, 18.0, 0.34, scale=(0.6, 1.0))


def gen_rail_depot(d, rng):
    for i in range(9):  # sidings: railways are straight, the one place long parallels belong
        z = -674 + i * 23 + (3 if i % 2 else 0)
        paint_line([(-462, z), (-196, z)], 2, (72, 68, 62), block=False)
    for z, w in ((-660, 132), (-612, 118), (-564, 140), (-516, 104)):
        add_box(-330 + rng.uniform(-30, 30), z, w, 18, 9, kind="shed", margin=2)
    add_box(-230, -476, 30, 12, 9, kind="building", margin=2)
    add_box(-330, -478, 7, 7, 14, kind="landmark", margin=1)      # signal box
    add_box(-440, -476, 10, 8, 5, kind="small", margin=1)


def gen_robot_depot(d, rng):
    rect = d["rects"][0]
    gd.rectangle(rect_px([rect[0] + 8, rect[1] + 8, rect[2] - 8, rect[3] - 8]), outline=(96, 98, 98), width=2)
    add_box(-590, -540, 130, 90, 28, kind="hall", margin=4)
    add_box(-640, -400, 40, 24, 8, kind="building", margin=3)
    add_box(-540, -390, 20, 14, 10, kind="building", margin=3)
    for _ in range(7):
        add_box(rng.uniform(-672, -510), rng.uniform(-470, -366), 8, 2.2, 3, rot=rng.uniform(0, 180), kind="small", margin=2)


def gen_campus_university(d, rng):
    gd.rectangle(rect_px([-650, -160, -572, -84]), fill=(98, 106, 76))  # quad
    od.rectangle(rect_px([-650, -160, -572, -84]), fill=180)
    add_box(-610, -185, 72, 22, 15, kind="building", margin=3)
    add_box(-610, -205, 9, 9, 38, kind="landmark", force=True)   # clock tower
    add_box(-655, -285, 52, 20, 15, kind="building", margin=3)
    add_box(-585, -292, 48, 20, 15, rot=12, kind="building", margin=3)
    add_box(-560, -122, 14, 50, 18, kind="building", margin=2)
    add_box(-612, -50, 42, 30, 12, kind="building", margin=3)    # library
    add_box(-680, -110, 12, 60, 18, kind="slab", margin=2)       # dormitory
    add_box(-566, -34, 26, 18, 6, kind="small", margin=2)        # canteen
    scatter_trees(d["rects"][0], rng, 15.0, 0.44, scale=(0.7, 1.15))


def gen_stadium(d, rng):
    rect = d["rects"][0]
    cx, cz, rx, rz = -450, 650, 130, 110
    gd.rectangle(rect_px(rect), fill=(122, 122, 118))
    gd.ellipse([cx - rx - 40 - X0, cz - rz - 40 - Z0, cx + rx + 40 - X0, cz + rz + 40 - Z0], fill=(138, 136, 130))
    gd.ellipse([cx - 62 - X0, cz - 40 - Z0, cx + 62 - X0, cz + 40 - Z0], fill=(96, 110, 72))
    segments = 30
    for i in range(segments):
        a0, a1 = math.tau * i / segments, math.tau * (i + 1) / segments
        mid = (a0 + a1) / 2
        bx, bz = cx + math.cos(mid) * (rx - 14), cz + math.sin(mid) * (rz - 14)
        chord = math.hypot((math.cos(a1) - math.cos(a0)) * rx, (math.sin(a1) - math.sin(a0)) * rz)
        tangent = math.degrees(math.atan2(-math.cos(mid) * rz, -math.sin(mid) * rx))
        add_box(bx, bz, chord + 1.5, 28, 34, rot=tangent, kind="stadium", force=True)
    gd.rectangle(rect_px([-655, 800, -585, 870]), fill=(100, 112, 76))   # practice pitch
    for _ in range(26):  # concourse stalls, scattered
        a = rng.uniform(0, math.tau)
        add_box(cx + math.cos(a) * (rx + rng.uniform(12, 34)), cz + math.sin(a) * (rz + rng.uniform(12, 34)), rng.uniform(3, 5), rng.uniform(2.5, 4), 2.8, rot=rng.uniform(0, 180), kind="small", margin=1)
    add_box(-290, 640, 8, 34, 4, kind="small", margin=2)                  # ticket gates
    for box in ([-570, 800, -250, 875], [-655, 480, -600, 560]):          # car parks, plain
        gd.rectangle(rect_px(box), fill=(104, 104, 106))
    scatter_trees(rect, rng, 24.0, 0.28, scale=(0.6, 1.0), holes=[(cx, cz, 190)])


def gen_port(d, rng):
    gd.rectangle(rect_px([60, 880, 600, 935]), fill=(128, 128, 126))      # quay apron
    sizes = [(60, 30, 10), (44, 24, 9), (82, 36, 12)]
    for _ in range(160):
        w, dep, h = rng.choice(sizes)
        add_box(rng.uniform(100, 560), rng.uniform(596, 744), w, dep, h, rot=rng.choice([0, 0, 90]), kind="shed", margin=7)
    add_box(120, 600, 30, 16, 21, kind="building", margin=3)
    add_box(520, 800, 40, 18, 7, kind="shed", margin=3)
    for _ in range(4):
        x, z = rng.uniform(80, 200), rng.uniform(760, 850)
        if is_free(x, z, 15, 15, 0, 4):
            shapes.append({"shape": "cylinder", "x": round(x, 1), "z": round(z, 1), "y": 0, "size": 14, "height": 12, "kind": "tank"})
            od.ellipse([x - 8 - X0, z - 8 - Z0, x + 8 - X0, z + 8 - Z0], fill=200)
    for _ in range(420):
        wide, high = rng.randint(1, 4), rng.randint(1, 4)
        add_box(rng.uniform(220, 590), rng.uniform(760, 872), 12.2, 2.44 * wide, 2.59 * high, rot=rng.choice([0, 0, 0, 90]), kind="container%d" % rng.randint(0, 3), margin=1.2)
    for i, x in enumerate((120, 215, 300, 400, 505)):  # cranes that differ in model and height
        height = (58, 72, 64, 78, 60)[i]
        for dx in (-9, 9):
            add_box(x + dx, 902, 2.5, 2.5, height * 0.7, kind="crane", force=True, stamp=False)
            add_box(x + dx, 922, 2.5, 2.5, height * 0.7, kind="crane", force=True, stamp=False)
        add_box(x, 912, 24, 24, 4, y=height * 0.7, kind="crane", force=True, stamp=False)
        add_box(x, 925, 4, 60 + i * 4, 4, y=height * 0.7 + 4, kind="crane", force=True, stamp=False)
        add_box(x, 905, 3, 3, height * 0.3, y=height * 0.7 + 4, kind="crane", force=True, stamp=False)


def gen_island(d, rng):
    add_box(770, 750, 112, 92, 14, kind="slab", force=True)
    add_box(770, 750, 46, 46, 260, kind="tower", force=True)
    for x, z in ((690, 640), (850, 640), (700, 880), (850, 870), (668, 720), (745, 566)):
        add_box(x, z, 6, 6, 4, kind="small", force=True)
    scatter_trees(d["rects"][0], rng, 17.0, 0.35, scale=(0.6, 0.95))


def gen_airport(d, rng):
    gd.rectangle(rect_px([-640, -1455, 860, -1405]), fill=(70, 70, 72))            # runway
    gd.rectangle(rect_px([-600, -1392, 820, -1376]), fill=(92, 92, 92))            # taxiway
    gd.rectangle(rect_px([-680, -1376, 780, -1172]), fill=(134, 134, 130))         # apron
    od.rectangle(rect_px([-640, -1455, 860, -1376]), fill=255)
    add_box(70, -1225, 380, 100, 18, kind="terminal", force=True)
    shapes.append({"shape": "cylinder", "x": 60, "z": -1300, "y": 0, "size": 9, "height": 46, "kind": "landmark"})
    shapes.append({"shape": "cylinder", "x": 60, "z": -1300, "y": 46, "size": 16, "height": 9, "kind": "glass"})
    od.ellipse([60 - 10 - X0, -1300 - 10 - Z0, 60 + 10 - X0, -1300 + 10 - Z0], fill=200)
    for x, z, w, dep, h in ((-590, -1272, 82, 62, 18), (-492, -1266, 62, 52, 15), (-432, -1262, 44, 44, 12)):
        add_box(x, z, w, dep, h, kind="hangar", margin=2)
    for _ in range(80):
        add_box(rng.uniform(340, 500), rng.uniform(-1320, -1215), rng.uniform(40, 58), rng.uniform(24, 32), rng.uniform(8, 11), rot=rng.choice([0, 90]), kind="shed", margin=5)
    for _ in range(40):
        x, z = rng.uniform(575, 685), rng.uniform(-1315, -1215)
        size = rng.choice([14, 18, 22])
        if is_free(x, z, size + 4, size + 4, 0, 3):
            shapes.append({"shape": "cylinder", "x": round(x, 1), "z": round(z, 1), "y": 0, "size": size, "height": round(rng.uniform(9, 14), 1), "kind": "tank"})
            od.ellipse([x - size / 2 - X0, z - size / 2 - Z0, x + size / 2 - X0, z + size / 2 - Z0], fill=200)
    for x, z, turn, length in ((-260, -1330, 20, 38), (-140, -1345, -35, 30), (300, -1350, 70, 44), (720, -1310, 5, 26)):
        add_box(x, z, length, 4, 4, rot=turn, y=2, kind="aircraft", force=True)   # few, different, never lined up
        add_box(x, z, 5, length * 0.9, 0.8, rot=turn, y=3.4, kind="aircraft", force=True, stamp=False)


def gen_approach(d, rng):
    rect = d["rects"][0]
    gd.rectangle(rect_px([-430, -1040, -260, -985]), fill=(100, 100, 102))
    add_box(-380, -1000, 60, 18, 7, kind="building", margin=3)                      # service area
    add_box(-300, -1005, 30, 16, 6, kind="shed", margin=2)                          # fuel canopy
    for _ in range(40):
        add_box(rng.uniform(380, 560), rng.uniform(-1060, -980), rng.uniform(30, 52), rng.uniform(16, 24), rng.uniform(6, 9), rot=rng.choice([0, 20, 90]), kind="shed", margin=6)
    for _ in range(60):
        add_box(rng.uniform(360, 600), rng.uniform(-1090, -960), 12.2, 2.44 * rng.randint(1, 2), 2.59 * rng.randint(1, 3), rot=rng.choice([0, 90, 35]), kind="container%d" % rng.randint(0, 3), margin=1.5)
    scatter_trees(rect, rng, 15.0, 0.34, scale=(0.5, 0.95), holes=[(-345, -1010, 80), (470, -1020, 130)])


def gen_dam(d, rng):
    add_box(-985, -1262, 192, 16, 70, kind="dam", force=True)
    for w, h, z in ((90, 22, -1246), (70, 36, -1249), (46, 50, -1251)):
        add_box(-985, z, w, 10, h, kind="building", force=True, stamp=False)
    add_box(-985, -1212, 52, 24, 12, kind="building", force=True)                   # turbine hall
    add_box(-1090, -1262, 20, 60, 90, rot=14, kind="rock", force=True)              # gorge walls
    add_box(-880, -1262, 20, 60, 90, rot=-12, kind="rock", force=True)
    scatter_trees(d["rects"][0], rng, 13.0, 0.4, scale=(0.8, 1.3))


def gen_forest(d, rng):
    rect = d["rects"][0]
    for a, b in (((-870, -560), (-710, -380)), ((-875, 300), (-705, 560))):
        paint_line(wobbly(a, b, rng, 26, 9), 2, PATH, block=False)
    holes = [(rng.uniform(rect[0] + 40, rect[2] - 40), rng.uniform(rect[1] + 60, rect[3] - 60), rng.uniform(16, 28)) for _ in range(5)]
    scatter_trees(rect, rng, 7.4, 0.8, scale=(0.9, 1.5), holes=holes)


def gen_valley(d, rng):
    rect = d["rects"][0]
    for _ in range(42):  # fields: irregular shapes that follow the valley, none repeated
        cx, cz = rng.uniform(rect[0] + 20, rect[2] - 20), rng.uniform(rect[1] + 30, rect[3] - 30)
        a = rng.uniform(0, math.pi)
        rw, rd = rng.uniform(18, 46), rng.uniform(12, 26)
        poly = []
        for k in range(7):
            t = math.tau * k / 7 + rng.uniform(-0.25, 0.25)
            lx, lz = math.cos(t) * rw * rng.uniform(0.8, 1.1), math.sin(t) * rd * rng.uniform(0.8, 1.1)
            poly.append((cx + lx * math.cos(a) - lz * math.sin(a), cz + lx * math.sin(a) + lz * math.cos(a)))
        gd.polygon(pts(poly), fill=rng.choice(FIELDS))
    # Water, roads and rail again, on top of the fields.
    paint_line(PLAN["water"]["river"]["points"], PLAN["water"]["river"]["width"], WATER)
    for road in PLAN["roads"]:
        if road["kind"] in ("country", "highway") or road["name"] in ("Coast road", "West avenue"):
            paint_line(road["points"], road["width"], ROAD_COLOUR[road["kind"]])
    paint_line(PLAN["rail"]["mountain_line"], 6, RAIL_BED)
    gd.ellipse([-1140 - X0, 415 - Z0, -1070 - X0, 525 - Z0], fill=(124, 120, 112))  # quarry
    add_box(-1060, 290, 58, 42, 10, kind="shed", margin=1)                           # river warehouse
    for village in PLAN["villages"]:
        placed = 0
        for _ in range(400):
            if placed >= village["houses"]:
                break
            a, r = rng.uniform(0, math.tau), rng.uniform(6, 58)
            if add_box(village["x"] + math.cos(a) * r * 0.75, village["z"] + math.sin(a) * r, rng.uniform(7, 10), rng.uniform(5.5, 7.5), rng.choice([4.6, 5.2, 6.4]), rot=rng.uniform(0, 180), kind="timber", margin=2.5):
                placed += 1
    add_box(-1012, -452, 14, 9, 7, rot=20, kind="landmark", margin=1)                # mill by the river
    add_box(-1112, -60, 8, 6, 5, kind="landmark", margin=1)                          # hill shrine
    add_box(-1030, 700, 16, 10, 5, rot=-12, kind="shed", margin=1)                   # petrol station
    add_box(-1075, 712, 30, 16, 6, rot=8, kind="shed", margin=1)                     # farm co-op
    sheds = 0
    for _ in range(60):
        if sheds < 9 and add_box(rng.uniform(rect[0] + 12, rect[2] - 12), rng.uniform(rect[1] + 20, rect[3] - 20), 12, 8, 4, rot=rng.uniform(0, 180), kind="timber", margin=8):
            sheds += 1
    scatter_trees(rect, rng, 17.0, 0.22, scale=(0.7, 1.2))


def gen_foothills(d, rng):
    for rect in d["rects"]:
        for _ in range(int((rect[2] - rect[0]) * (rect[3] - rect[1]) / 9000)):
            size = rng.uniform(5, 14)
            add_box(rng.uniform(rect[0] + 10, rect[2] - 10), rng.uniform(rect[1] + 10, rect[3] - 10), size, size * rng.uniform(0.6, 1.2), size * rng.uniform(0.4, 0.9), rot=rng.uniform(0, 180), kind="rock", margin=2)
        scatter_trees(rect, rng, 10.5, 0.55, scale=(0.8, 1.4))


def gen_fringe(d, rng):
    rect = d["rects"][0]
    for _ in range(60):
        add_box(rng.uniform(rect[0] + 10, rect[2] - 46), rng.uniform(rect[1] + 20, rect[3] - 20), rng.uniform(10, 18), rng.uniform(8, 13), rng.uniform(4, 9), rot=rng.choice([0, 90, 15]), kind="building", margin=9)
    scatter_trees(rect, rng, 14.0, 0.32, scale=(0.6, 1.1))


SITES = ["plaza", "mall", "island", "airport", "dam", "robot_depot", "rail_depot", "campus_medical", "school", "campus_university", "stadium", "port", "danchi"]
COUNTRY = ["approach", "valley", "fringe", "foothills", "forest", "park"]
GENERATORS = {
    "park": gen_park, "plaza": gen_plaza, "mall": gen_mall, "danchi": gen_danchi, "campus_medical": gen_campus_medical,
    "school": gen_school, "rail_depot": gen_rail_depot, "robot_depot": gen_robot_depot, "campus_university": gen_campus_university,
    "stadium": gen_stadium, "port": gen_port, "island": gen_island, "airport": gen_airport, "approach": gen_approach,
    "dam": gen_dam, "forest": gen_forest, "valley": gen_valley, "foothills": gen_foothills, "fringe": gen_fringe,
}


# The countryside and the sites that are laid out by hand live in country.py.
for _pattern, _function in country.GENERATORS.items():
    GENERATORS[_pattern] = (lambda d, rng, f=_function: f(sys.modules[__name__], d, rng))


# ---- the map picture ----------------------------------------------------------------------

def font(size):
    for name in ("arialbd.ttf", "arial.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


TAKEN = []   # label boxes already on the picture, so no two names sit on each other


def label(draw, xy, text, size, fill=(255, 255, 255), anchor="mm", must=True):
    f = font(size)
    box = draw.textbbox(xy, text, font=f, anchor=anchor)
    box = (box[0] - 3, box[1] - 3, box[2] + 3, box[3] + 3)
    if any(box[0] < t[2] and box[2] > t[0] and box[1] < t[3] and box[3] > t[1] for t in TAKEN):
        if not must:
            return False
    TAKEN.append(box)
    x, y = xy
    for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, 1), (-1, 1), (1, -1)):
        draw.text((x + dx, y + dy), text, font=f, fill=(20, 22, 24), anchor=anchor)
    draw.text((x, y), text, font=f, fill=fill, anchor=anchor)
    return True


def dashed(draw, points, colour, width, dash=16, gap=12):
    for a, b in zip(points, points[1:]):
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        t = 0.0
        while t < length:
            e = min(t + dash, length)
            draw.line([(a[0] + (b[0] - a[0]) * t / length, a[1] + (b[1] - a[1]) * t / length), (a[0] + (b[0] - a[0]) * e / length, a[1] + (b[1] - a[1]) * e / length)], fill=colour, width=width)
            t += dash + gap


def name_tall_buildings():
    """Owner's rule (2026-11-13): a building of five floors or more is one of three things,
    and you can tell which from the street: an office, ordinary apartments, or luxury
    apartments. Which one follows from where it stands, as it would in a real town:
    luxury where the view is (facing the park, along the stream), offices in the shopping
    streets and the government quarter, ordinary apartments everywhere else."""
    areas = PLAN["city"]["areas"]
    plaza = next(d for d in PLAN["districts"] if d["pattern"] == "plaza")["rects"][0]
    park = next(d for d in PLAN["districts"] if d["pattern"] == "park")["rects"][0]
    stream = city_fabric.dense(PLAN["water"]["stream"]["points"], 6.0)
    counts = {"office": 0, "apartment": 0, "luxury": 0}
    for box in boxes:
        if box[7] not in ("tall", "building", "slab") or box[8] != 0.0 or round((box[4] - 0.9) / 3.1) < 5:
            continue
        x, z = box[0], box[2]
        in_shops = any(a["type"] == "shops" and any(r[0] <= x < r[2] and r[1] <= z < r[3] for r in a["rects"]) for a in areas)
        in_plaza = plaza[0] <= x <= plaza[2] and plaza[1] <= z <= plaza[3]
        park_gap = math.hypot(max(park[0] - x, 0, x - park[2]), max(park[1] - z, 0, z - park[3]))
        by_stream = min(math.hypot(x - sx, z - sz) for sx, sz in stream) <= 38
        if (park_gap <= 44 and z > park[1]) or by_stream:     # the park's north side is the shopping street
            box[7] = "luxury"
        elif in_shops or in_plaza:
            box[7] = "office"
        else:
            box[7] = "apartment"
        counts[box[7]] += 1
    return counts


def roof_parts():
    """What tells the three apart from far off, in the blockout: an office roof is flat, an
    apartment block has its water tank, a luxury block steps back to a penthouse."""
    for box in list(boxes):
        base = box[7].split("-")[0]
        if box[8] != 0.0 or base not in ("apartment", "luxury"):
            continue
        x, y, z, w, h, d, rot = box[:7]
        if base == "luxury":
            add_box(x, z, w * 0.68, d * 0.68, 3.4, rot=rot, y=y + h, kind=box[7], force=True, stamp=False, absolute=True)
        else:
            a = math.radians(rot)
            ox, oz = w * 0.22, d * 0.2
            add_box(x + ox * math.cos(a) + oz * math.sin(a), z - ox * math.sin(a) + oz * math.cos(a), 2.6, 2.6, 2.4, rot=rot, y=y + h, kind="small", force=True, stamp=False, absolute=True)


def break_long_views(crossings):
    """No road gives a dead-straight view of more than about 400 m. The city was evacuated
    in a hurry, and what breaks the view is what that left behind: buses, lorries and vans
    stalled across the lanes, each group different. They are cover as well. Nothing is moved:
    streets and plots stay where they are."""
    breakers = []
    patterns = (((11.5, 2.6, 3.1, 0.0, -0.22, 16), (7.6, 2.5, 3.3, 9.0, 0.24, -24), (5.2, 2.0, 2.3, -7.5, 0.30, 34)),
                ((7.6, 2.5, 3.3, 0.0, 0.2, -18), (11.5, 2.6, 3.1, 8.5, -0.24, 28), (5.2, 2.0, 2.3, 16.0, 0.05, -40)),
                ((11.5, 2.6, 3.1, 0.0, 0.0, 62), (5.2, 2.0, 2.3, -9.0, -0.3, 12), (7.6, 2.5, 3.3, 10.5, 0.28, -12)))
    count = 0
    for road in PLAN["roads"]:
        if road.get("class") in ("expressway", "bridge", "ramp") or road["name"].startswith("Airport service"):
            continue
        points = road["points"]
        runs, start, heading = [], 0, None
        for i, (a, b) in enumerate(zip(points, points[1:])):
            h = math.atan2(b[1] - a[1], b[0] - a[0])
            if heading is not None and abs((h - heading + math.pi) % math.tau - math.pi) >= math.radians(2.5):
                runs.append((start, i))
                start = i
            heading = h
        runs.append((start, len(points) - 1))
        for i0, i1 in runs:
            a, b = points[i0], points[i1]
            length = math.hypot(b[0] - a[0], b[1] - a[1])
            if length <= 420:
                continue
            pieces = math.ceil(length / 330.0)
            tx, tz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
            angle = -math.degrees(math.atan2(tz, tx))
            for k in range(1, pieces):
                s = length * k / pieces + (14 if k % 2 else -14)
                for _ in range(6):      # never in the middle of a junction
                    x, z = a[0] + tx * s, a[1] + tz * s
                    if all(math.hypot(x - c["x"], z - c["z"]) > 26 for c in crossings):
                        break
                    s += 18
                for long, wide, high, along, across, skew in patterns[count % len(patterns)]:
                    off = across * road["width"]
                    add_box(x + tx * along - tz * off, z + tz * along + tx * off, long, wide, high, rot=angle + skew, kind="vehicle", force=True, stamp=False)
                breakers.append([round(x, 1), round(z, 1), road["name"]])
                count += 1
    return breakers


def posts():
    out = []
    drops = PLAN["drops"]
    for i, drop in enumerate(drops):
        nxt = drops[(i + 1) % len(drops)]
        gap = math.hypot(drop["x"] - nxt["x"], drop["z"] - nxt["z"])
        if gap / 2 <= PLAN["rules"]["gunfire_heard_m"]:
            out.append({"between": drop["id"] + "-" + nxt["id"], "x": round((drop["x"] + nxt["x"]) / 2), "z": round((drop["z"] + nxt["z"]) / 2)})
    # D6-D7 spans the port and the bay: one post each side instead of the midpoint.
    out.append({"between": "D6-D7 (homes)", "x": -60, "z": 700})
    out.append({"between": "D6-D7 (mall)", "x": 700, "z": 250})
    return out


SHADE = {"house": (154, 144, 126), "timber": (146, 126, 100), "shop": (168, 152, 130), "tall": (178, 178, 182), "slab": (188, 186, 180),
         "shed": (150, 146, 140), "hangar": (160, 152, 128), "terminal": (170, 176, 170), "mall": (178, 182, 186),
         "stadium": (176, 180, 170), "rock": (112, 108, 100), "dam": (196, 150, 110), "tower": (210, 150, 150),
         "hall": (190, 192, 196), "tram": (196, 186, 150), "charger": (238, 240, 242), "vehicle": (96, 108, 122), "robot": (44, 48, 56), "charger_light": (120, 210, 250), "office": (170, 184, 198), "apartment": (198, 182, 154), "luxury": (232, 228, 214), "aircraft": (214, 214, 210), "landmark": (214, 206, 180), "small": (150, 148, 144), "carpark": (140, 140, 142)}


def draw_overview(post_list, crossings=()):
    picture = ground.copy()
    draw = ImageDraw.Draw(picture, "RGBA")
    tint = random.Random(SEED + 5)
    for box in boxes:
        if box[8] >= 3.0 or box[7] == "signal":
            continue
        base = SHADE.get(box[7].split("-")[0], (188, 120, 72) if box[7].startswith("container") else (170, 168, 162))
        shift = tint.randint(-9, 9)   # no two roofs quite the same grey
        if "-" in box[7]:
            base = tuple(int(c * 0.55) for c in base)   # shut: drawn dark
        draw.polygon(pts(corners(box[0], box[2], box[3], box[5], box[6])), fill=tuple(max(0, min(255, c + shift)) for c in base), outline=(66, 66, 66))
    for tx, tz, scale in trees:
        r = 1.6 * scale
        draw.ellipse([tx - X0 - r, tz - Z0 - r, tx - X0 + r, tz - Z0 + r], fill=(48, 62, 40))
    for shape in shapes:
        r = shape["size"] / 2
        box = [shape["x"] - r - X0, shape["z"] - r - Z0, shape["x"] + r - X0, shape["z"] + r - Z0]
        if shape["shape"] == "pyramid":
            draw.rectangle(box, fill=(196, 206, 196), outline=(60, 60, 60))
            draw.line([box[0], box[1], box[2], box[3]], fill=(120, 130, 124), width=1)
            draw.line([box[0], box[3], box[2], box[1]], fill=(120, 130, 124), width=1)
        else:
            draw.ellipse(box, fill=(176, 196, 204) if shape["kind"] == "glass" else (176, 172, 160), outline=(60, 60, 60))
    hill = PLAN["city"]["hill"]
    for f in (1.0, 0.75, 0.5, 0.25):   # the hill, as a map shows one
        draw.ellipse([hill["x"] - hill["rx"] * f - X0, hill["z"] - hill["rz"] * f - Z0, hill["x"] + hill["rx"] * f - X0, hill["z"] + hill["rz"] * f - Z0], outline=(120, 96, 70, 120), width=1)
    for road in PLAN["roads"]:
        if road["kind"] == "expressway":
            draw.line(pts(road["points"]), fill=(206, 204, 196, 235), width=road["width"], joint="curve")
            draw.line(pts(road["points"]), fill=(90, 90, 92, 255), width=2)
    for crossing in crossings:
        x, y = px(crossing["x"], crossing["z"])
        if crossing["control"] == "scramble":
            draw.ellipse([x - 6, y - 6, x + 6, y + 6], outline=(250, 226, 120, 255), width=2)
        elif crossing["control"] == "signals":
            draw.ellipse([x - 2.5, y - 2.5, x + 2.5, y + 2.5], fill=(246, 214, 96, 255))
    for zone in PLAN["zones"]:
        colour = TIER[zone["tier"]]
        draw.rectangle(rect_px(zone["rect"]), fill=colour + (40,), outline=colour + (255,), width=4)
    for key in ("loop", "airport_branch", "mountain_line"):
        draw.line(pts(PLAN["rail"][key]), fill=(250, 250, 250, 255), width=5, joint="curve")
    for key in ("drop_off_line", "drop_off_line_east"):
        dashed(draw, pts(PLAN["rail"][key]), (250, 250, 250, 255), 3)
    for post in post_list:
        x, y = px(post["x"], post["z"])
        draw.ellipse([x - 7, y - 7, x + 7, y + 7], fill=(190, 60, 60, 255), outline=(255, 255, 255, 255), width=2)
    for station in PLAN["stations"]:
        x, y = px(station["x"], station["z"])
        draw.ellipse([x - 11, y - 11, x + 11, y + 11], fill=(250, 250, 250, 255), outline=(20, 20, 20, 255), width=3)
        label(draw, (x, y - 24), station["id"], 22)
    for drop in PLAN["drops"]:
        x, y = px(drop["x"], drop["z"])
        draw.polygon([(x, y - 15), (x - 13, y + 10), (x + 13, y + 10)], fill=(250, 250, 250, 255), outline=(20, 20, 20, 255))
        label(draw, (x, y + 26), drop["id"], 22)
    for district in PLAN["districts"]:
        if district["pattern"] == "fringe":
            continue
        rect = max(district["rects"], key=lambda r: (r[2] - r[0]) * (r[3] - r[1]))
        text = district["name"].upper()
        wide = rect[2] - rect[0]
        size = 30 if wide > 420 else 22 if wide > 230 else 17
        colour = TIER[district["loot"]] if district["loot"] in ("yellow", "orange", "red") else (255, 255, 255)
        words = text.split(" ")
        lines = [text] if wide > len(text) * size * 0.62 else [" ".join(words[:max(1, len(words) // 2)]), " ".join(words[max(1, len(words) // 2):])]
        lines = [l for l in lines if l]
        at = district.get("label", [(rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2])
        cx, cy = px(at[0], at[1])
        for i, line in enumerate(lines):
            label(draw, (cx, cy + (i - (len(lines) - 1) / 2) * (size + 4)), line, size, fill=colour)
    for place in PLAN["places"]:
        rect = place["rect"]
        label(draw, px((rect[0] + rect[2]) / 2, rect[3] + 12), place["name"], 14, fill=(226, 236, 214), must=False)
    for mark in PLAN["landmarks"]:
        if mark["kind"] in ("runway", "terminal", "stadium", "hall", "warehouse", "quarry", "helipad", "clock_tower", "signal_box"):
            continue
        label(draw, px(mark["x"], mark["z"] + 26), mark["name"], 15, fill=(236, 230, 206), must=False)
    for road in PLAN["roads"]:
        if road.get("class") == "old" or road["name"] in ("Teramachi street", "Sakae street"):
            mid = road["points"][len(road["points"]) // 2]
            label(draw, px(mid[0], mid[1] - 12), road["name"].replace(", west", "").replace(", east", ""), 13, fill=(232, 222, 196), must=False)
    for village in PLAN["villages"]:
        label(draw, px(village["x"] + 6, village["z"] - 74), village["name"], 15, fill=(236, 230, 206), must=False)
    label(draw, px(PLAN["water"]["stream"]["points"][len(PLAN["water"]["stream"]["points"]) // 2][0], PLAN["water"]["stream"]["points"][len(PLAN["water"]["stream"]["points"]) // 2][1] - 14), "Midori stream", 13, fill=(196, 220, 232), must=False)

    # Legend, scale and north go in a panel beside the map, so nothing on the map is covered.
    panel = 500
    sheet = Image.new("RGB", (W + panel, H), (22, 24, 26))
    sheet.paste(picture.convert("RGB"), (0, 0))
    draw = ImageDraw.Draw(sheet, "RGBA")
    TAKEN.clear()
    left = W + 34
    label(draw, (left, 56), "SHINRAI · MAP 1", 34, anchor="lm")
    label(draw, (left, 100), "Draft %d · 5.0 km² · 2.05 x 2.44 km" % PLAN["draft"], 20, anchor="lm", fill=(210, 210, 204))
    label(draw, (left, 130), "Layout plan, not art. 1 pixel = 1 metre.", 18, anchor="lm", fill=(210, 210, 204))
    draw.polygon([(left + 26, 180), (left + 4, 240), (left + 26, 226), (left + 48, 240)], fill=(250, 250, 250, 255))
    label(draw, (left + 26, 262), "N", 24)
    y = 330
    draw.line([left, y, left + 400, y], fill=(250, 250, 250, 255), width=4)
    for x in (left, left + 200, left + 400):
        draw.line([x, y - 9, x, y + 9], fill=(250, 250, 250, 255), width=3)
    label(draw, (left + 200, y + 24), "400 m  (about 1 min 45 s on foot)", 17)

    def heading(text):
        nonlocal y
        y += 58
        label(draw, (left, y), text, 20, anchor="lm", fill=(210, 210, 204))

    def swatch(colour, text, outline=None):
        nonlocal y
        y += 34
        draw.rectangle([left, y - 11, left + 32, y + 11], fill=colour + (255,), outline=outline)
        label(draw, (left + 48, y), text, 18, anchor="lm")

    y = 372
    heading("LOOT")
    swatch(TIER["yellow"], "Yellow: high value")
    swatch(TIER["orange"], "Orange: second best (the dam)")
    swatch(TIER["red"], "Red: the best (the island)")
    swatch((120, 122, 116), "Everything else: grey and green")
    heading("GETTING IN AND OUT")
    y += 34
    draw.line([left, y, left + 34, y], fill=(250, 250, 250, 255), width=5)
    draw.ellipse([left + 9, y - 9, left + 27, y + 9], fill=(250, 250, 250, 255), outline=(20, 20, 20, 255), width=2)
    label(draw, (left + 48, y), "Tram line and its 10 stations", 18, anchor="lm")
    y += 34
    dashed(draw, [(left, y), (left + 36, y)], (250, 250, 250, 255), 3, 8, 6)
    label(draw, (left + 48, y), "Drop-off line", 18, anchor="lm")
    y += 34
    draw.polygon([(left + 17, y - 12), (left + 5, y + 9), (left + 29, y + 9)], fill=(250, 250, 250, 255))
    label(draw, (left + 48, y), "Drop-off point (12), 400 m apart", 18, anchor="lm")
    y += 34
    draw.ellipse([left + 9, y - 8, left + 25, y + 8], fill=(190, 60, 60, 255), outline=(255, 255, 255, 255), width=2)
    label(draw, (left + 48, y), "Bot post between drop-offs", 18, anchor="lm")
    heading("BETWEEN THE BUILDINGS")
    swatch(PAVING, "Squares and station squares")
    swatch(GREEN, "Parks, gardens, the stream's banks")
    swatch(GRAVEL, "Shrine and temple grounds")
    swatch(city_fabric.PARKING, "Car parks and empty plots")
    swatch(city_fabric.VEG, "Vegetable plots")
    heading("ROADS")
    y += 34
    draw.line([left, y, left + 34, y], fill=(206, 204, 196, 255), width=12)
    label(draw, (left + 48, y), "Elevated expressway", 18, anchor="lm")
    swatch(ASPHALT, "Avenues and the outer ring", outline=(150, 150, 150, 255))
    swatch(city_fabric.STREET_LOCAL, "Side streets", outline=(150, 150, 150, 255))
    swatch(city_fabric.LANE, "Old lanes and steps on the hill")
    y += 34
    draw.ellipse([left + 12, y - 4, left + 20, y + 4], fill=(246, 214, 96, 255))
    label(draw, (left + 48, y), "Traffic signals", 18, anchor="lm")
    y += 34
    draw.ellipse([left + 9, y - 7, left + 23, y + 7], outline=(250, 226, 120, 255), width=2)
    label(draw, (left + 48, y), "All-way pedestrian crossing", 18, anchor="lm")
    heading("RAID")
    for text in ("Up to 43 players, squads of up to 3", "46 minutes; joining until 38 minutes", "Last tram called with 3 minutes left"):
        y += 30
        label(draw, (left, y), text, 17, anchor="lm")
    return sheet


def tram_bed_patch(ground, part, wide):
    """The road's surface past the shop row's east end, out to the painted tram bed (agreed with
    Codex, 2026-11-14): the tram loop comes in across the row's north footway and runs on down the
    middle of the road, so the asphalt's end follows the bed's west edge as painted (what the player
    sees) instead of stopping square across the road; across the lane beside the bed, where nothing
    stands in the way, it stops square, level with the bed's corner. An outline in the world (x, z)
    from the road's north edge round to its south edge, or [] if no bed lies within 15 m."""
    (x0, z0), (x1, z1) = part[-2], part[-1]
    if abs(z1 - z0) > 0.01 or x1 <= x0:
        return []                               # (worked out for a road running due east only)
    north, south = z1 - wide * 0.5, z1 + wide * 0.5
    edge = []                                   # (x where the bed begins, top of the pixel row, bottom of it)
    for row in range(int(math.floor(north)), int(math.ceil(south))):
        for x in range(int(math.floor(x1)), int(math.floor(x1)) + 15):
            if ground.getpixel((x - X0, row - Z0)) == RAIL_BED:
                edge.append((x, row, row + 1))
                break
    if len(edge) < 2:
        return []
    # (The pixels make a staircase: the edge as seen is the straight line through the middle of
    # each step, from the first row the bed is in to the road's far edge.)
    (xf, rf, _), (xl, rl, _) = edge[0], edge[-1]
    slope = (xl - xf) / float(rl - rf)          # metres in x per metre in z
    corner = [xf + slope * (rf - (rf + 0.5)), float(rf)]
    far = [xl + slope * (south - (rl + 0.5)), south]
    outline = [[x1, north], [corner[0], north], corner, far, [x1, south]]
    return [[round(x, 2), round(z, 2)] for x, z in outline]


def fork_south_kerb(street_edges):
    """The tram fork, stage B, south side (agreed with Codex, owner's leave 2026-11-15): where Tram
    street south bends away north-east, lane z 497 carries straight on east out of its south lane,
    and its south kerb lies some 3 m south of the street's. The street's south kerb is carried from
    its built end to the lane's built start on an S of two equal curves, with the footway behind
    it going from the street's width to the lane's, and the road between the rail bed and the new
    kerb surfaced up to the lane.

    Laid as one side of a narrow strip (the game lays a kerb as a side of a street): the strip's
    centre line runs FORK_KERB_HALF inside the kerb's line, and only its south side is built.
    Returns the export entry, or None if either street is missing.
    """
    tram = next((e for e in street_edges if e["name"] == "tram street south"), None)
    lane = next((e for e in street_edges if e["name"] == "homes lane z497 a"), None)
    if tram is None or lane is None:
        return None
    x0, zc0 = tram["points"][-1]
    x1, zc1 = lane["points"][0]
    k0 = zc0 + tram["w"] * 0.5                 # the street's south kerb line
    k1 = zc1 + lane["w"] * 0.5                 # the lane's south kerb line
    # A straight lead at each end, so the first and last cross-sections are square to the street
    # and the lane and meet theirs exactly (the game takes a kerb's direction from the line between
    # two points: a curve running right to an end arrives turned by half a step, 5 cm out at the
    # footway). The west lead also keeps the kerb on the street's line past house 1661 (east wall
    # x 187.3): the curve starts at FORK_CURVE_FROM.
    xa = max(x0 + 0.3, FORK_CURVE_FROM)
    xb = x1 - FORK_LEAD_EAST
    dx, dz = xb - xa, k1 - k0
    if dx < 4.0 or dz <= 0.0:
        return None
    turn = 2.0 * math.atan2(dz, dx)            # each curve turns this much: two equal arcs make the S
    radius = dx / (2.0 * math.sin(turn))
    steps = 10
    kerb = [(x0, k0, 0.0)]                     # (x, z, the way it heads)
    for k in range(steps + 1):
        a = turn * k / steps
        kerb.append((xa + radius * math.sin(a), k0 + radius * (1.0 - math.cos(a)), a))
    for k in range(steps - 1, -1, -1):
        a = turn * k / steps
        kerb.append((xb - radius * math.sin(a), k1 - radius * (1.0 - math.cos(a)), a))
    kerb.append((x1, k1, 0.0))
    # (The street's own kerb and footway run to its end, where this one takes over.)
    tram["joined_end"] = True
    def off(point, by):
        # by metres towards the road (north of the kerb's line), square to the way it heads
        x, z, a = point
        return [round(x + math.sin(a) * by, 4), round(z - math.cos(a) * by, 4)]
    lane_fw = float((lane.get("footway") or [lane["pavement"]] * 2)[0])
    gutter = 0.22
    # The road to surface: from the rail bed's south edge (3 m south of the street's centre line,
    # round its mitre at the bend) and the lane's north kerb line, to the new kerb's gutter.
    bend_x = 191.0
    bed = zc0 + 3.0
    lane_north = zc1 - lane["w"] * 0.5
    tan_half = math.tan(math.radians(22.5))
    outer_x = bend_x + tram["w"] * 0.5 * tan_half       # where the street's south kerb line would turn
    gore_x = outer_x + (k0 - lane_north)                # where the lane's north kerb leaves the diagonal's kerb
    # The patch ends on the lane's own first cross-section, which is square to the lane and not to
    # the map: the lane bears 0.17 degrees off east, so a patch cut square at x1 leaves a sliver of
    # bare ground up to 6.5 mm wide on the north half (Codex measured it from the built triangles).
    lx, lz = lane["points"][1][0] - x1, lane["points"][1][1] - zc1
    ll = math.hypot(lx, lz)
    ux, uz = lx / ll, lz / ll
    def lane_start(t):
        # the point t metres across the lane's first cross-section (south positive)
        return [round(x1 - uz * t, 4), round(zc1 + ux * t, 4)]
    patch = [[x0, bed], [round(bend_x + 3.0 * tan_half, 3), bed], [round(gore_x, 3), round(lane_north, 3)], lane_start(-lane["w"] * 0.5)]
    patch += [lane_start(lane["w"] * 0.5 - gutter)] + [off(point, gutter) for point in list(reversed(kerb))[1:]]
    print("tram fork, south kerb: from (%.2f, %.2f) to (%.2f, %.2f), straight to x %.2f and from x %.2f, between them two curves of %.1f degrees, radius %.1f m; footway %.2f to %.2f m; gore point (%.2f, %.2f)" % (
        x0, k0, x1, k1, xa, xb, math.degrees(turn), radius, tram["pavement"], lane_fw, gore_x, lane_north))
    return {"name": "tram fork south", "cls": lane["cls"], "w": FORK_KERB_HALF * 2.0, "pavement": lane_fw,
            "points": [off(point, FORK_KERB_HALF) for point in kerb], "exact": True, "footway": [lane_fw, 0.14], "ends": ["on", "on"],
            "only_side": 1.0, "footway_from": float(tram["pavement"]), "end_patch": patch}


FORK_NOSE_R = 0.6      # the island's rounded tip, at the kerb's road face
FORK_NOSE_STEPS = 8    # cast pieces round it
FORK_STUB = 3.0        # the diagonal's kerb, laid this far past the tip for now


def fork_island(street_edges, fork):
    """The tram fork, stage B, the island (outline agreed with Codex 2026-11-15): the tip of the
    block between lane z 497 (its north kerb) and Tram street's diagonal (its south-east kerb).
    The two kerb lines meet at 45 degrees; the tip is rounded at FORK_NOSE_R. Laid as two kerbs,
    each one side of a narrow strip as the fork's south kerb is: the lane's north kerb from the
    lane's built start west to the tip, turning round it at its end, and FORK_STUB of the
    diagonal's kerb beyond. Behind them one paved surface (two ordinary footways would lie on top
    of each other behind the tip), and the fork's road patch redrawn as one outline round the tip.
    Returns the two export entries."""
    tram = next((e for e in street_edges if e["name"] == "tram street south"), None)
    lane = next((e for e in street_edges if e["name"] == "homes lane z497 a"), None)
    if tram is None or lane is None or fork is None:
        return []
    kw, gutter = 0.14, 0.22
    x0, zc0 = tram["points"][-1]
    x1, zc1 = lane["points"][0]
    lx, lz = lane["points"][1][0] - x1, lane["points"][1][1] - zc1
    ll = math.hypot(lx, lz)
    ux, uz = lx / ll, lz / ll                          # the lane's heading
    hw = lane["w"] * 0.5
    k0 = zc0 + tram["w"] * 0.5
    tan_half = math.tan(math.radians(22.5))
    outer_x = 191.0 + tram["w"] * 0.5 * tan_half       # where the street's south kerb line turns north-east
    dx, dz = math.sqrt(0.5), -math.sqrt(0.5)           # the diagonal's heading
    p0 = (x1 + uz * hw, zc1 - ux * hw)                 # the lane's north kerb face at its first cross-section
    det = dx * (-uz) - dz * (-ux)
    a = ((p0[0] - outer_x) * (-uz) - (p0[1] - k0) * (-ux)) / det
    g = (outer_x + a * dx, k0 + a * dz)                # where the two kerb lines meet
    angle = math.acos(dx * ux + dz * uz)
    tangent = FORK_NOSE_R / math.tan(angle * 0.5)
    bx, bz = dx + ux, dz + uz
    bl = math.hypot(bx, bz)
    bx, bz = bx / bl, bz / bl
    reach = FORK_NOSE_R / math.sin(angle * 0.5)
    centre = (g[0] + bx * reach, g[1] + bz * reach)
    t_lane = (g[0] + ux * tangent, g[1] + uz * tangent)
    t_diag = (g[0] + dx * tangent, g[1] + dz * tangent)
    n_lane = (uz, -ux)                                 # into the island from the lane's kerb (north)
    n_diag = (-dz, dx)                                 # and from the diagonal's (south-east)
    def go(p, u, s, n, t):
        return (p[0] + u[0] * s + n[0] * t, p[1] + u[1] * s + n[1] * t)
    def r4(p):
        return [round(p[0], 4), round(p[1], 4)]
    lane_len = (p0[0] - t_lane[0]) * ux + (p0[1] - t_lane[1]) * uz
    fw = float((lane.get("footway") or [lane["pavement"]] * 2)[0])
    # Round the tip from the lane's tangent point to the diagonal's: turning by (180 - angle).
    turn = math.pi - angle
    a_lane = math.atan2(t_lane[1] - centre[1], t_lane[0] - centre[0])
    def arc(radius, k):
        # k steps of FORK_NOSE_STEPS from the lane's tangent point round the west to the diagonal's
        at = a_lane + turn * k / FORK_NOSE_STEPS
        return (centre[0] + radius * math.cos(at), centre[1] + radius * math.sin(at))
    # The paved surface, inside the kerbs: A, B (the cut at the lane's start), C, M (where the two
    # footway backs meet), D, E (the stub's end), F, and the tip's back arc home to A.
    m = (g[0] + bx * fw / math.sin(angle * 0.5), g[1] + bz * fw / math.sin(angle * 0.5))
    paving = [go(t_lane, (ux, uz), 0.0, n_lane, kw), go(t_lane, (ux, uz), lane_len, n_lane, kw), go(t_lane, (ux, uz), lane_len, n_lane, fw), m,
              go(t_diag, (dx, dz), FORK_STUB, n_diag, fw), go(t_diag, (dx, dz), FORK_STUB, n_diag, kw)]
    paving += [arc(FORK_NOSE_R - kw, k) for k in range(FORK_NOSE_STEPS, 0, -1)]
    # The road: the fork's patch, redrawn as one outline. From the rail bed's mitre it follows the
    # bed's edge up the diagonal (3 m from the street's centre line) to opposite the stub's end,
    # crosses to the stub's gutter, comes back down it, round the tip and along the lane's north
    # gutter to the lane's first cross-section.
    bed_gap = tram["w"] * 0.5 - 3.0                    # from the diagonal's kerb face to the bed's edge
    stub_end = go(t_diag, (dx, dz), FORK_STUB, n_diag, 0.0)
    chain = [go(stub_end, (dx, dz), 0.0, n_diag, -bed_gap), go(stub_end, (dx, dz), 0.0, n_diag, -gutter)]
    chain += [arc(FORK_NOSE_R + gutter, k) for k in range(FORK_NOSE_STEPS, -1, -1)]
    chain += [go(p0, (ux, uz), 0.0, n_lane, -gutter)]
    old = fork["end_patch"]
    fork["end_patch"] = old[:2] + [r4(p) for p in chain] + old[4:]
    half = FORK_KERB_HALF
    print("tram fork, island: kerb lines meet at %.2f degrees at (%.3f, %.3f); tip radius %.2f about (%.3f, %.3f), tangent points (%.3f, %.3f) and (%.3f, %.3f); lane kerb %.3f m, stub %.1f m; paving %d points, road patch %d points" % (
        math.degrees(angle), g[0], g[1], FORK_NOSE_R, centre[0], centre[1], t_lane[0], t_lane[1], t_diag[0], t_diag[1], lane_len, FORK_STUB, len(paving), len(fork["end_patch"])))
    common = {"cls": lane["cls"], "w": half * 2.0, "pavement": kw, "exact": True, "footway": [kw, kw], "ends": ["on", "on"], "only_side": 1.0}
    lane_kerb = dict(common, name="tram fork island lane",
                     points=[r4(go(p0, (ux, uz), 0.0, n_lane, -half)), r4(go(t_lane, (ux, uz), 0.0, n_lane, -half))],
                     end_fillet=[FORK_NOSE_R, round(math.degrees(turn), 4), FORK_NOSE_STEPS],
                     paving=[[round(p[0], 6), round(p[1], 6)] for p in paving], paving_faces=[2, 3, 4])
    stub = dict(common, name="tram fork island stub",
                points=[r4(go(t_diag, (dx, dz), 0.0, n_diag, -half)), r4(go(t_diag, (dx, dz), FORK_STUB, n_diag, -half))])
    return [lane_kerb, stub]


DIAGONAL_SOUTH_TO = 27.6   # Tram street's diagonal, south-east kerb: laid this far past the island's stub (46 units), short of the mouths of lanes x 224 and z 466
DIAGONAL_WIDEN = 3.0       # its pavement grows from the island's width to the street's over this length


def fork_diagonal_south(street_edges):
    """Tram street's diagonal past the fork, south-east side (agreed with Codex 2026-11-16): the
    kerb carried on from the island's stub along the diagonal's kerb line, DIAGONAL_SOUTH_TO
    metres, stopping short of the compound mouth of lanes x 224 and z 466 (a later stage). Its
    pavement is the street's own width; over the first DIAGONAL_WIDEN metres it grows from the
    island's narrower pavement. The road is surfaced from the rail bed's edge to the gutter.
    Laid as one-sided strips, as the island's kerbs are. Returns the export entries."""
    tram = next((e for e in street_edges if e["name"] == "tram street south"), None)
    stub = next((e for e in street_edges if e["name"] == "tram fork island stub"), None)
    island = next((e for e in street_edges if e["name"] == "tram fork island lane"), None)
    if tram is None or stub is None or island is None:
        return []
    kw, gutter = 0.14, 0.22
    half = FORK_KERB_HALF
    dx, dz = math.sqrt(0.5), -math.sqrt(0.5)           # the diagonal's heading
    nx, nz = -dz, dx                                   # behind its south-east kerb
    sx, sz = stub["points"][1]
    face = (sx + nx * half, sz + nz * half)            # the stub's end, at the kerb's road face
    def go(s, back):
        return [round(face[0] + dx * s + nx * back, 4), round(face[1] + dz * s + nz * back, 4)]
    wide = float(tram["pavement"])
    narrow = float(island.get("paving_footway", 1.5))
    bed_gap = tram["w"] * 0.5 - 3.0
    common = {"cls": tram["cls"], "w": half * 2.0, "exact": True, "ends": ["on", "on"], "only_side": 1.0}
    first = dict(common, name="tram diagonal south a", pavement=narrow, footway=[narrow, kw], footway_to=wide,
                 points=[go(0.0, -half), go(DIAGONAL_WIDEN, -half)])
    rest = dict(common, name="tram diagonal south", pavement=wide, footway=[wide, kw], grate=True,
                points=[go(DIAGONAL_WIDEN, -half), go(DIAGONAL_SOUTH_TO, -half)],
                end_patch=[go(0.0, -bed_gap), go(DIAGONAL_SOUTH_TO, -bed_gap), go(DIAGONAL_SOUTH_TO, -gutter), go(0.0, -gutter)])
    # (The island's paving no longer ends in the open at the stub: the pavement carries on from it.)
    island["paving_faces"] = [f for f in island["paving_faces"] if f != 4]
    end = go(DIAGONAL_SOUTH_TO, 0.0)
    print("tram diagonal, south-east kerb: from the stub's end (%.3f, %.3f) %.1f m to (%.3f, %.3f); pavement %.2f m growing to %.2f m over the first %.1f m" % (
        face[0], face[1], DIAGONAL_SOUTH_TO, end[0], end[1], narrow, wide, DIAGONAL_WIDEN))
    return [first, rest]


MOUTH_TIP_R = 0.839463      # the round tip between the diagonal and lane x 224 (Codex's measured circle)
MOUTH_TIP_CENTRE = (221.12894, 469.54356)
MOUTH_TIP_TANGENT_D = (220.53535, 468.94997)   # on the diagonal's south-east kerb face
MOUTH_TIP_TANGENT_X = (221.96840, 469.54607)   # on lane x 224's west kerb face
MOUTH_TIP_STEPS = 8
MOUTH_Z466_FROM = 228.5686  # lane z 466 laid west to here: the square return's tangent on its south kerb
MOUTH_RETURN_R = 2.0        # that return's radius: the largest that keeps house 4474 out of the pavement
MOUTH_RETURN_STEPS = 5      # cast pieces round it (0.63 m each at the kerb face)
MOUTH_RETURN_TO = 470.7205  # and lane x 224's east kerb starts at the return's other tangent
MOUTH_X224_HOUSE = 4474    # the house that stands within a metre of lane x 224's east kerb
MOUTH_DOOR_WIDE = 1.8       # three low units fit both 1.2 m ramps before the measured doorway
MOUTH_DOOR_Z = 474.2523     # the door's centreline, from Codex's in-game measurement of the built house
MOUTH_X224_TO = 484.0      # lane x 224's west kerb, laid south to the built piece's start


def compound_mouth_tip(street_edges):
    """The compound mouth at the diagonal's far end (agreed with Codex 2026-11-16), first stage:
    the pointed tip of the block between Tram street's diagonal and lane x 224's west side. The
    ideal apex lies inside lane z 466's carriageway, so the tip is the one circle that touches
    all three kerb lines (radius MOUTH_TIP_R, Codex's figures), turning 135.17 degrees. The
    diagonal's ordinary 2 m pavement runs to the cross-section where its back meets lane x 224's
    1.5 m back (the island's inner vertex); from there round the tip and down lane x 224 the
    ground is one traced surface, as at the fork's island. Returns the new export entries."""
    diag = next((e for e in street_edges if e["name"] == "tram diagonal south"), None)
    if diag is None:
        return []
    kw, gutter, half = 0.14, 0.22, FORK_KERB_HALF
    dx, dz = math.sqrt(0.5), -math.sqrt(0.5)       # the diagonal's heading
    nx, nz = -dz, dx                               # behind its south-east kerb
    face = (198.555, 490.931)                      # the diagonal's station zero, at the kerb face
    wide = float(diag["pavement"])
    xw = MOUTH_TIP_TANGENT_X[0]                    # lane x 224's west kerb face here
    # The island's inner vertex: where the diagonal's and lane x 224's pavement backs meet.
    # (A footway's back is `footway_wide` out from the kerb's road face, not from its back edge.)
    back_sum = (face[0] + nx * wide) + (face[1] + nz * wide)
    xb = xw - 1.5
    vertex = (xb, back_sum - xb)
    def st(p):
        return (p[0] - face[0]) * dx + (p[1] - face[1]) * dz
    cut = st((vertex[0] - nx * wide, vertex[1] - nz * wide))   # the diagonal station of that cross-section
    tip_to = st(MOUTH_TIP_TANGENT_D)
    def on_diag(s, back):
        return (face[0] + dx * s + nx * back, face[1] + dz * s + nz * back)
    def arc(radius, k):
        # k steps from the diagonal's tangent round the tip to lane x 224's
        a0 = math.atan2(MOUTH_TIP_TANGENT_D[1] - MOUTH_TIP_CENTRE[1], MOUTH_TIP_TANGENT_D[0] - MOUTH_TIP_CENTRE[0])
        a1 = math.atan2(MOUTH_TIP_TANGENT_X[1] - MOUTH_TIP_CENTRE[1], MOUTH_TIP_TANGENT_X[0] - MOUTH_TIP_CENTRE[0])
        at = a0 + (a1 - a0) * k / MOUTH_TIP_STEPS
        return (MOUTH_TIP_CENTRE[0] + radius * math.cos(at), MOUTH_TIP_CENTRE[1] + radius * math.sin(at))
    turn = math.degrees(math.atan2(MOUTH_TIP_TANGENT_X[1] - MOUTH_TIP_CENTRE[1], MOUTH_TIP_TANGENT_X[0] - MOUTH_TIP_CENTRE[0]) -
                        math.atan2(MOUTH_TIP_TANGENT_D[1] - MOUTH_TIP_CENTRE[1], MOUTH_TIP_TANGENT_D[0] - MOUTH_TIP_CENTRE[0]))
    r4 = lambda p: [round(p[0], 4), round(p[1], 4)]
    # Lane x 224 is not quite true north-south: its west kerb must follow the built lane's own
    # line, or it stands 43 mm off by the time it reaches the built piece (Codex measured it).
    built = next((e for e in street_edges if e["name"] == "homes lane 224 a"), None)
    (bx0, bz0), (bx1, bz1) = built["points"][0], built["points"][1]
    lane_slope = (bx1 - bx0) / (bz1 - bz0)
    lane_hw = built["w"] * 0.5
    def west_face(z):
        return bx0 + lane_slope * (z - bz0) - lane_hw
    # The diagonal's own stretch now stops at that cross-section, its road surfaced to the tip.
    diag["points"][1] = r4(on_diag(cut, -half))
    diag["end_patch"] = [r4(on_diag(0.0, -(3.0 - (half - 1.6) + 1.6 - 1.6))), r4(on_diag(tip_to, -3.0)), r4(on_diag(tip_to, -gutter)), r4(on_diag(0.0, -gutter))]
    diag["end_patch"][0] = r4(on_diag(0.0, -3.0))
    # The tip's kerb: the last of the diagonal, laid as the kerb alone, turning round the tip.
    paving = [on_diag(cut, kw)] + [arc(MOUTH_TIP_R - kw, k) for k in range(MOUTH_TIP_STEPS + 1)]
    paving += [(west_face(vertex[1]) - kw, vertex[1]), vertex]
    tip = {"name": "tram mouth tip", "cls": diag["cls"], "w": half * 2.0, "pavement": kw, "exact": True,
           "footway": [kw, kw], "ends": ["on", "on"], "only_side": 1.0,
           "points": [r4(on_diag(cut, -half)), r4(on_diag(tip_to, -half))],
           "end_fillet": [MOUTH_TIP_R, round(turn, 4), MOUTH_TIP_STEPS], "end_fillet_footway": kw,
           "paving": [[round(p[0], 6), round(p[1], 6)] for p in paving], "paving_faces": [], "paving_side": 1.0}
    # Lane x 224's west kerb from the tip south: the kerb alone until the island is wide enough
    # for the lane's own 1.5 m pavement, then that pavement.
    west_a = {"name": "homes lane 224 west a", "cls": diag["cls"], "w": half * 2.0, "pavement": kw, "exact": True,
              "footway": [kw, kw], "ends": ["on", "on"], "only_side": 1.0,
              "points": [[round(west_face(MOUTH_TIP_TANGENT_X[1]) + half, 4), round(MOUTH_TIP_TANGENT_X[1], 4)], [round(west_face(vertex[1]) + half, 4), round(vertex[1], 4)]]}
    west_b = {"name": "homes lane 224 west b", "cls": diag["cls"], "w": half * 2.0, "pavement": 1.5, "exact": True,
              "footway": [1.5, kw], "ends": ["on", "on"], "only_side": 1.0, "grate": True,
              "points": [[round(west_face(vertex[1]) + half, 4), round(vertex[1], 4)], [round(west_face(MOUTH_X224_TO) + half, 4), MOUTH_X224_TO]]}
    print("compound mouth, tip: diagonal's pavement to station %.4f, kerb alone to %.4f; tip radius %.6f about (%.5f, %.5f), %d pieces, turning %.3f degrees; island vertex (%.4f, %.4f); lane x 224 west kerb from z %.3f to %.1f" % (
        cut, tip_to, MOUTH_TIP_R, MOUTH_TIP_CENTRE[0], MOUTH_TIP_CENTRE[1], MOUTH_TIP_STEPS, turn, vertex[0], vertex[1], MOUTH_TIP_TANGENT_X[1], MOUTH_X224_TO))
    return [tip, west_a, west_b]


def compound_mouth_z466(street_edges):
    """The compound mouth, third stage: lane z 466's unbuilt western length. The built piece is
    cut at the block's edge at x 240; the ground picture paints the lane on west from there to
    the diagonal. This lays it as an ordinary two-sided lane from MOUTH_Z466_FROM (the corner
    where lane x 224's east kerb turns into it) to the built piece, and surfaces its carriageway.
    The two corners at its west end, and the last of its north kerb out to the diagonal's
    south-east kerb at the obtuse corner, are the stage after this. Returns the export entry."""
    built = next((e for e in street_edges if e["name"] == "homes lane z466 a"), None)
    if built is None:
        return []
    (x0, z0), (x1, z1) = built["points"][0], built["points"][-1]
    slope = (z1 - z0) / (x1 - x0)
    centre = lambda x: z0 + slope * (x - x0)
    hw, gutter = built["w"] * 0.5, 0.22
    west = MOUTH_Z466_FROM
    # (The lane's own heading, so the new piece lies on the same line as the built one.)
    # Laid east to west, so that its WEST end is the edge's end and can carry the square return
    # into lane x 224 (the fillet turns a kerb at the end of its run, not at its start).
    lane = {"name": "homes lane z466 west", "cls": built["cls"], "w": built["w"], "pavement": 1.5,
            "exact": True, "footway": [1.5, 1.5], "ends": ["on", "on"],
            "points": [[round(x0, 4), round(z0, 4)], [round(west, 4), round(centre(west), 4)]],
            "end_fillet": [MOUTH_RETURN_R, 90.0008, MOUTH_RETURN_STEPS], "end_fillet_side": -1.0, "end_fillet_footway": 1.5,
            "end_patch": [[round(west, 4), round(centre(west) - hw + gutter, 4)], [round(x0, 4), round(z0 - hw + gutter, 4)],
                          [round(x0, 4), round(z0 + hw - gutter, 4)], [round(west, 4), round(centre(west) + hw - gutter, 4)]]}
    print("compound mouth, lane z 466 west: laid from x %.2f to the built cut at x %.1f (%.2f m), centre z %.4f to %.4f, pavement 1.5 m both sides; its two west corners and the obtuse corner on the diagonal are the next stage" % (
        west, x0, x0 - west, centre(west), z0))
    return [lane]


MOUTH_POINT_R = 0.839463    # the north-east point: the same nose as the tip at the junction's other end
MOUTH_POINT_STEPS = 8
MOUTH_DIAGONAL_ON = 10.8    # and the diagonal's south-east kerb carried this far past it (18 units)


def compound_mouth_point(street_edges):
    """Build the agreed north-east point from the two native street bases.

    The 0.84 m kerb radius matches the opposite tip. Pavement widths include
    the kerb, and the traced fill joins the actual lane and diagonal caps.
    """
    lane = next((entry for entry in street_edges if entry["name"] == "homes lane z466 west"), None)
    diagonal = next((entry for entry in street_edges if entry["name"] == "tram diagonal south"), None)
    if lane is None or diagonal is None:
        return []
    kerb, gutter, half = 0.14, 0.22, FORK_KERB_HALF
    pavement, unit = 1.5, 0.6
    lane_start, lane_end = lane["points"]
    lx, lz = lane_end[0] - lane_start[0], lane_end[1] - lane_start[1]
    length = math.hypot(lx, lz)
    lane_direction = (lx / length, lz / length)
    lane_normal = (-lane_direction[1], lane_direction[0])
    lane_face = tuple(lane_end[i] + lane_normal[i] * lane["w"] * 0.5 for i in (0, 1))
    diagonal_start, diagonal_end = diagonal["points"]
    dx = diagonal_end[0] - diagonal_start[0]
    dz = diagonal_end[1] - diagonal_start[1]
    length = math.hypot(dx, dz)
    diagonal_direction = (dx / length, dz / length)
    diagonal_normal = (-diagonal_direction[1], diagonal_direction[0])
    diagonal_face = tuple(diagonal_start[i] + diagonal_normal[i] * diagonal["w"] * 0.5 for i in (0, 1))

    def intersection(origin_a, direction_a, origin_b, direction_b):
        cross = direction_a[0] * direction_b[1] - direction_a[1] * direction_b[0]
        delta = (origin_b[0] - origin_a[0], origin_b[1] - origin_a[1])
        along = (delta[0] * direction_b[1] - delta[1] * direction_b[0]) / cross
        return tuple(origin_a[i] + direction_a[i] * along for i in (0, 1))

    apex = intersection(lane_face, lane_direction, diagonal_face, diagonal_direction)
    wedge = math.acos(-sum(lane_direction[i] * diagonal_direction[i] for i in (0, 1)))
    turn = math.pi - wedge
    reach = MOUTH_POINT_R / math.tan(wedge * 0.5)
    lane_tangent = tuple(apex[i] - lane_direction[i] * reach for i in (0, 1))
    diagonal_tangent = tuple(apex[i] + diagonal_direction[i] * reach for i in (0, 1))
    bisector = tuple(-lane_direction[i] + diagonal_direction[i] for i in (0, 1))
    length = math.hypot(*bisector)
    centre = tuple(apex[i] + bisector[i] / length * MOUTH_POINT_R / math.sin(wedge * 0.5) for i in (0, 1))

    def arc(radius, index):
        first = math.atan2(lane_tangent[1] - centre[1], lane_tangent[0] - centre[0])
        last = math.atan2(diagonal_tangent[1] - centre[1], diagonal_tangent[0] - centre[0])
        if last - first > math.pi:
            last -= 2.0 * math.pi
        if first - last > math.pi:
            last += 2.0 * math.pi
        angle = first + (last - first) * index / MOUTH_POINT_STEPS
        return (centre[0] + radius * math.cos(angle), centre[1] + radius * math.sin(angle))

    lane_back = tuple(lane_face[i] + lane_normal[i] * pavement for i in (0, 1))
    diagonal_back = tuple(diagonal_face[i] + diagonal_normal[i] * pavement for i in (0, 1))
    vertex = intersection(lane_back, lane_direction, diagonal_back, diagonal_direction)
    # Full-width paving begins past the meeting of the two backs. The kerb
    # continues alone until that cap, in whole 60 cm units.
    needed = sum((vertex[i] - diagonal_tangent[i]) * diagonal_direction[i] for i in (0, 1))
    lead = max(0.0, math.ceil((needed - 0.000001) / unit) * unit)

    def on_diagonal(station, offset):
        return tuple(diagonal_tangent[i] + diagonal_direction[i] * station
                     + diagonal_normal[i] * offset for i in (0, 1))

    def rounded(point):
        return [round(value, 6) for value in point]

    paving = [tuple(lane_face[i] + lane_normal[i] * kerb for i in (0, 1))]
    paving.extend(arc(MOUTH_POINT_R - kerb, index) for index in range(MOUTH_POINT_STEPS + 1))
    paving.extend([on_diagonal(lead, kerb), on_diagonal(lead, pavement), vertex, lane_back])
    point = {
        "name": "tram mouth point", "cls": lane["cls"], "w": half * 2.0,
        "pavement": kerb, "exact": True, "footway": [kerb, kerb],
        "ends": ["on", "on"], "only_side": 1.0,
        "points": [
            rounded(tuple(lane_face[i] - lane_normal[i] * half for i in (0, 1))),
            rounded(tuple(lane_tangent[i] - lane_normal[i] * half for i in (0, 1))),
        ],
        "end_fillet": [MOUTH_POINT_R, round(math.degrees(turn), 6), MOUTH_POINT_STEPS],
        "end_fillet_footway": kerb,
        "paving": [rounded(position) for position in paving],
        "paving_faces": [], "paving_side": 1.0,
    }
    result = [point]
    if lead > 0.0:
        result.append({
            "name": "tram mouth point diagonal", "cls": diagonal["cls"],
            "w": half * 2.0, "pavement": kerb, "exact": True,
            "footway": [kerb, kerb], "ends": ["on", "on"], "only_side": 1.0,
            "points": [rounded(on_diagonal(0.0, -half)), rounded(on_diagonal(lead, -half))],
        })
    result.append({
        "name": "tram diagonal south b", "cls": diagonal["cls"],
        "w": half * 2.0, "pavement": pavement, "exact": True,
        "footway": [pavement, kerb], "ends": ["on", "on"], "only_side": 1.0, "grate": True,
        "points": [rounded(on_diagonal(lead, -half)), rounded(on_diagonal(MOUTH_DIAGONAL_ON, -half))],
        "end_patch": [
            rounded(on_diagonal(0.0, -3.0)), rounded(on_diagonal(MOUTH_DIAGONAL_ON, -3.0)),
            rounded(on_diagonal(MOUTH_DIAGONAL_ON, -gutter)), rounded(on_diagonal(0.0, -gutter)),
        ],
    })
    print("compound north-east point: radius %.6f, turn %.6f, centre %s; kerb alone %.3f m, full footway %.3f m; back vertex %s"
          % (MOUTH_POINT_R, math.degrees(turn), centre, lead, MOUTH_DIAGONAL_ON - lead, vertex))
    return result


def compound_mouth_east(street_edges, boxes):
    """The compound mouth, second stage: lane x 224's east side, where house MOUTH_X224_HOUSE
    stands 0.73 to 0.90 m from the kerb face. Beside the house the lane has the kerb alone (no
    raised footway would fit), and at its front door the kerb is lowered to DROP_HIGH so that its
    top is flush with the house's own 3 cm slab: the player steps off the road onto the kerb and
    straight onto the slab. North and south of the house the lane has its ordinary 1.5 m pavement.
    The lane's carriageway is surfaced between the two gutters. Returns the export entries."""
    west = next((e for e in street_edges if e["name"] == "homes lane 224 west b"), None)
    west_top = next((e for e in street_edges if e["name"] == "homes lane 224 west a"), None)
    built = next((e for e in street_edges if e["name"] == "homes lane 224 a"), None)
    if west is None or west_top is None or built is None or len(boxes) <= MOUTH_X224_HOUSE:
        return []
    kw, gutter, half = 0.14, 0.22, FORK_KERB_HALF
    (bx0, bz0), (bx1, bz1) = built["points"][0], built["points"][1]
    slope = (bx1 - bx0) / (bz1 - bz0)
    hw = built["w"] * 0.5
    centre = lambda z: bx0 + slope * (z - bz0)
    b = boxes[MOUTH_X224_HOUSE]
    a = math.radians(b[6])
    ca, sa = math.cos(a), math.sin(a)
    corners = [(b[0] + lx * b[3] * ca + lz * b[5] * sa, b[2] - lx * b[3] * sa + lz * b[5] * ca) for lx, lz in ((-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5))]
    face = sorted(sorted(corners, key=lambda p: p[0])[:2], key=lambda p: p[1])   # its two west corners, north then south
    from_z = round(face[0][1] - 0.5, 3)      # the kerb runs narrow from half a metre before the house
    to_z = round(face[1][1] + 0.5, 3)
    top = float(west_top["points"][0][1])   # the lane's new length starts at the tip's tangent
    door_z = MOUTH_DOOR_Z if from_z < MOUTH_DOOR_Z < to_z else round((face[0][1] + face[1][1]) * 0.5, 3)
    door_x = face[0][0] + (face[1][0] - face[0][0]) * (door_z - face[0][1]) / (face[1][1] - face[0][1])
    common = {"cls": built["cls"], "w": half * 2.0, "exact": True, "ends": ["on", "on"], "only_side": -1.0}
    def strip(name, z0, z1, pavement, extra=None):
        entry = dict(common, name=name, pavement=pavement, footway=[kw, pavement],
                     points=[[round(centre(z0) + hw - half, 4), round(z0, 4)], [round(centre(z1) + hw - half, 4), round(z1, 4)]])
        if extra: entry.update(extra)
        return entry
    out = [strip("homes lane 224 east a", MOUTH_RETURN_TO, from_z, 1.5),
           strip("homes lane 224 east b", from_z, to_z, kw,
                 {"entrances": [{"x": round(door_x, 4), "z": door_z, "wide": MOUTH_DOOR_WIDE, "what": "door"}]}),
           strip("homes lane 224 east c", to_z, MOUTH_X224_TO, 1.5)]
    # The carriageway, between the two gutters, for the whole new length: one patch, laid with the
    # west kerb so its grain runs down the lane.
    west["end_patch"] = [[round(centre(z) - hw + gutter, 4), round(z, 4)] for z in (top, MOUTH_X224_TO)]
    west["end_patch"] += [[round(centre(z) + hw - gutter, 4), round(z, 4)] for z in (MOUTH_X224_TO, top)]
    print("compound mouth, lane x 224 east: pavement 1.5 m to z %.3f, kerb alone past house %d to z %.3f (kerb face %.3f to %.3f m from its wall), door at z %.3f with a %.1f m lowered kerb, 1.5 m again to z %.1f; carriageway surfaced z %.3f to %.1f" % (
        from_z, MOUTH_X224_HOUSE, to_z, face[0][0] - (centre(face[0][1]) + hw), face[1][0] - (centre(face[1][1]) + hw), door_z, MOUTH_DOOR_WIDE, MOUTH_X224_TO, top, MOUTH_X224_TO))
    return out


FORK_INNER_R = 3.0  # the inside of the bend: the north kerb's curve, at its road face
FORK_INNER_STEPS = 5
FORK_INNER_FOOTWAY = 1.5   # the pavement narrows to this on the curve, and ends there


def fork_inner_corner(street_edges):
    """The tram fork, stage B, the inside of the bend (option (c), agreed with Codex): Tram street's
    north kerb turns 45 degrees north-east with the street, on a curve of FORK_INNER_R from the
    street's built end. A building (the curry shop) stands at the back of the street's pavement
    and its corner stands across the diagonal's kerb line just past the curve, so nothing is laid
    beyond the curve: the pavement narrows on the curve itself from the street's width to
    FORK_INNER_FOOTWAY and stops at the curve's end with a closed end, and the road is surfaced
    between the rail bed and the new gutter up to the curve's last cross-section.
    Marks Tram street's export entry: its north side turns the curve (kerb alone), and it carries
    the traced paving and the road patch. Returns nothing."""
    tram = next((e for e in street_edges if e["name"] == "tram street south"), None)
    if tram is None:
        return
    kw, gutter = 0.14, 0.22
    x0, zc0 = tram["points"][-1]
    hw = tram["w"] * 0.5
    kn = zc0 - hw                                       # the north kerb line
    tan_half = math.tan(math.radians(22.5))
    inner = (191.0 - hw * tan_half, kn)                # where the two north kerb lines meet
    tangent = FORK_INNER_R * tan_half
    centre = (inner[0] - tangent, kn - FORK_INNER_R)
    wide0 = float(tram["pavement"])
    def arc(radius, k):
        # k steps of FORK_INNER_STEPS round the curve, from the street's end to the diagonal's tangent point
        at = math.pi * 0.5 - math.radians(45.0) * k / FORK_INNER_STEPS
        return (centre[0] + radius * math.cos(at), centre[1] + radius * math.sin(at))
    def back(k):
        # the pavement's back: from the street's width to FORK_INNER_FOOTWAY, evenly round the curve
        return arc(FORK_INNER_R - (wide0 + (FORK_INNER_FOOTWAY - wide0) * k / FORK_INNER_STEPS), k)
    # The paved surface: its back from the street's pavement end round to the curve's end, the
    # closed end across, and home along the kerb's back. The two points at the street's end are
    # the existing pavement's own.
    paving = [(x0, kn - wide0)] + [back(k) for k in range(1, FORK_INNER_STEPS + 1)]
    paving += [arc(FORK_INNER_R - kw, k) for k in range(FORK_INNER_STEPS, 0, -1)] + [(x0, kn - kw)]
    faces = list(range(0, FORK_INNER_STEPS + 1))       # its back edges and its end
    # The road: between the rail bed's north edge (3 m north of the street's centre line, round its
    # mitre) and the new gutter, from the street's end to the curve's last cross-section.
    bed = zc0 - 3.0
    mitre = (191.0 - 3.0 * tan_half, bed)
    patch = [(x0, bed), mitre, arc(FORK_INNER_R + hw - 3.0, FORK_INNER_STEPS)]
    patch += [arc(FORK_INNER_R + gutter, k) for k in range(FORK_INNER_STEPS, 0, -1)] + [(x0, kn + gutter)]
    tram["end_fillet"] = [FORK_INNER_R, 45.0, FORK_INNER_STEPS]
    tram["end_fillet_side"] = -1.0
    tram["end_fillet_footway"] = kw
    tram["paving"] = [[round(p[0], 6), round(p[1], 6)] for p in paving]
    tram["paving_faces"] = faces
    tram["paving_side"] = -1.0
    tram["end_patch"] = [[round(p[0], 4), round(p[1], 4)] for p in patch]
    end = arc(FORK_INNER_R, FORK_INNER_STEPS)
    print("tram fork, inner corner: kerb lines meet at (%.3f, %.3f); curve radius %.1f about (%.3f, %.3f), %d pieces, to (%.3f, %.3f); pavement %.2f to %.2f m on the curve, back ends at (%.3f, %.3f); paving %d points, road patch %d points" % (
        inner[0], inner[1], FORK_INNER_R, centre[0], centre[1], FORK_INNER_STEPS, end[0], end[1], wide0, FORK_INNER_FOOTWAY, back(FORK_INNER_STEPS)[0], back(FORK_INNER_STEPS)[1], len(paving), len(patch)))


def compound_mouth_asphalt(street_edges):
    """The compound mouth, last stage: one traced asphalt surface over the junction's carriageway,
    so no painted ground is left inside it.

    Every figure here is read back out of the entries the rest of the generator produced, never
    from a constant: each corner's circle is derived from its own kerb strip's native basis, and
    each cap cross-section is taken from the neighbouring patch itself. (Codex's review, 2026-11-16:
    a hard-coded centre was a millimetre out, and running each arc only as far as the neighbouring
    cap's bearing stopped it short of its own tangent. Each arc now runs tangent to tangent and a
    straight length of gutter edge carries it on to the cap.) Sets the tip strip's patch."""
    by = {e["name"]: e for e in street_edges}
    need = ("tram mouth tip", "tram mouth point", "tram mouth point diagonal", "tram diagonal south",
            "tram diagonal south b", "homes lane z466 west", "homes lane 224 west a", "homes lane 224 east a")
    if any(n not in by for n in need):
        return
    gutter = 0.22
    def basis(name, at_end, side=None):
        """The kerb face at one end of an edge, and the unit normal from the road towards its back."""
        e = by[name]
        p0, p1 = (e["points"][-2], e["points"][-1]) if at_end else (e["points"][1], e["points"][0])
        along = (p1[0] - p0[0], p1[1] - p0[1])
        L = math.hypot(*along); along = (along[0] / L, along[1] / L)
        if not at_end: along = (-along[0], -along[1])        # (the edge's own direction, not the way we read it)
        perp = (-along[1], along[0])
        s = float(side if side is not None else e.get("only_side", 1.0))
        n = (perp[0] * s, perp[1] * s)
        end = p1 if at_end else p1
        return (end[0] + n[0] * e["w"] * 0.5, end[1] + n[1] * e["w"] * 0.5), n, e["w"] * 0.5
    def corner(face_a, n_a, face_b, radius):
        """The circle of a kerb's turn: its centre, from the face and normal where the turn begins."""
        return (face_a[0] + n_a[0] * radius, face_a[1] + n_a[1] * radius)
    def out_to(centre, face, radius):
        """The gutter's outer edge below a point on the kerb face."""
        dx, dz = face[0] - centre[0], face[1] - centre[1]
        L = math.hypot(dx, dz)
        return (centre[0] + dx / L * (radius + gutter), centre[1] + dz / L * (radius + gutter))
    def arc(centre, radius, p_from, p_to, steps):
        a0 = math.atan2(p_from[1] - centre[1], p_from[0] - centre[0])
        a1 = math.atan2(p_to[1] - centre[1], p_to[0] - centre[0])
        if a1 - a0 > math.pi: a1 -= 2.0 * math.pi
        if a0 - a1 > math.pi: a1 += 2.0 * math.pi
        return [(centre[0] + radius * math.cos(a0 + (a1 - a0) * k / steps),
                 centre[1] + radius * math.sin(a0 + (a1 - a0) * k / steps)) for k in range(steps + 1)]
    # The three turns, each from its own strip.
    tip_face_d, tip_n_d, _ = basis("tram mouth tip", True)
    tip_face_x, tip_n_x, _ = basis("homes lane 224 west a", False)
    tip_c = corner(tip_face_d, tip_n_d, tip_face_x, MOUTH_TIP_R)
    pt_face_l, pt_n_l, _ = basis("tram mouth point", True)
    pt_face_d, _, _ = basis("tram mouth point diagonal", False)
    pt_c = corner(pt_face_l, pt_n_l, pt_face_d, MOUTH_POINT_R)
    ret_face_z, ret_n_z, _ = basis("homes lane z466 west", True, side=-1.0)
    ret_face_x, _, _ = basis("homes lane 224 east a", False)
    ret_c = corner(ret_face_z, ret_n_z, ret_face_x, MOUTH_RETURN_R)
    # The four cap cross-sections, taken from the neighbouring patches themselves.
    diag = by["tram diagonal south"]["end_patch"]
    beyond = by["tram diagonal south b"]["end_patch"]
    z466 = by["homes lane z466 west"]["end_patch"]
    x224 = by["homes lane 224 west b"]["end_patch"]
    d_bed, d_gut = tuple(diag[1]), tuple(diag[2])
    p_bed, p_gut = tuple(beyond[0]), tuple(beyond[3])
    z_north, z_south = tuple(z466[0]), tuple(z466[3])
    x_east, x_west = tuple(x224[3]), tuple(x224[0])
    outline = [d_bed, p_bed, p_gut]
    outline += arc(pt_c, MOUTH_POINT_R + gutter, out_to(pt_c, pt_face_d, MOUTH_POINT_R), out_to(pt_c, pt_face_l, MOUTH_POINT_R), MOUTH_POINT_STEPS)
    outline += [z_north, z_south]
    outline += arc(ret_c, MOUTH_RETURN_R + gutter, out_to(ret_c, ret_face_z, MOUTH_RETURN_R), out_to(ret_c, ret_face_x, MOUTH_RETURN_R), MOUTH_RETURN_STEPS)
    outline += [x_east, x_west]
    outline += arc(tip_c, MOUTH_TIP_R + gutter, out_to(tip_c, tip_face_x, MOUTH_TIP_R), out_to(tip_c, tip_face_d, MOUTH_TIP_R), MOUTH_TIP_STEPS)
    if math.hypot(outline[-1][0] - d_gut[0], outline[-1][1] - d_gut[1]) > 0.002: outline.append(d_gut)
    by["tram mouth tip"]["end_patch"] = [[round(q[0], 4), round(q[1], 4)] for q in outline]
    print("compound mouth, asphalt: one outline of %d points; turns about (%.6f, %.6f) tip, (%.6f, %.6f) point, (%.6f, %.6f) return, each from its own strip's basis; caps from the four neighbouring patches" % (
        len(outline), tip_c[0], tip_c[1], pt_c[0], pt_c[1], ret_c[0], ret_c[1]))


HOUSE_CLEAR = 0.3      # how far a trimmed house's face stands behind a built street's footway
SHOP_CLEAR = 0.0       # a shop front belongs AT the footway's back, not set back behind it
TRIM_LEAST = 0.02      # and nothing is trimmed for less than this much overlap


def _to_segment(px, pz, ax, az, bx, bz):
    """How far the point (px, pz) lies from the segment a-b, not from its ends."""
    dx, dz = bx - ax, bz - az
    length = dx * dx + dz * dz
    if length < 1e-12:
        return math.hypot(px - ax, pz - az)
    t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / length))
    return math.hypot(px - (ax + dx * t), pz - (az + dz * t))


def trim_houses_off_streets(boxes, street_edges):
    """A house laid out against the ground picture can stand a little into a built street: the
    picture's road is up to a metre off the true edge, and an older house may predate the street's
    final width. Such a house gives up depth on its street side, so its face stands HOUSE_CLEAR
    behind the footway (or the kerb, where the side has none). Its back stays where it was."""
    for edge in street_edges:
        pts = edge["points"]
        fw = edge.get("footway")
        for index, b in enumerate(boxes):
            if b[3] < 3.0 or b[5] < 3.0: continue
            # A house stands back from the pavement; a shop front stands on it. Both must stay out
            # of it. (Shops were never tested here until 2026-11-16, so a shop could stand any
            # distance inside a footway and nothing would move it.)
            kind = str(b[7])
            if kind.startswith("house"): clear = HOUSE_CLEAR
            elif kind.startswith("shop"): clear = SHOP_CLEAR
            else: continue
            # Near this street at all? Measured to the nearest point ON the line, not to its
            # corners. (Until 2026-11-16 this took the distance to the nearest vertex, so on a
            # long straight street every building near the middle was more than 40 m from both
            # ends and the trim never looked at that street for it. Tram street south is one
            # 146.66 m two-point line, which is how three shops stood in its footway unseen.
            # Codex found it; the game was right and the generator was not.)
            near = min(_to_segment(b[0], b[2], pts[j][0], pts[j][1], pts[j + 1][0], pts[j + 1][1]) for j in range(len(pts) - 1))
            if near > 40.0: continue
            a = math.radians(b[6])
            ca, sa = math.cos(a), math.sin(a)
            axes = ((ca, -sa), (sa, ca))          # the box's own x and z directions on the ground
            worst = None                          # (metres to give up, which axis, toward + or -)
            for lx in (-0.5, 0.0, 0.5):
                for lz in (-0.5, 0.0, 0.5):
                    if lx == 0.0 and lz == 0.0: continue
                    px = b[0] + lx * b[3] * ca + lz * b[5] * sa
                    pz = b[2] - lx * b[3] * sa + lz * b[5] * ca
                    for j in range(len(pts) - 1):
                        (ax, az), (bx, bz) = pts[j], pts[j + 1]
                        length = math.hypot(bx - ax, bz - az)
                        if length < 1e-6: continue
                        ux, uz = (bx - ax) / length, (bz - az) / length
                        t = (px - ax) * ux + (pz - az) * uz
                        # (Beside the edge only: not off past an end, nor in its first or last metre.)
                        if t < 0.0 or t > length or (j == 0 and t < 1.0) or (j == len(pts) - 2 and t > length - 1.0): continue
                        signed = (px - ax) * -uz + (pz - az) * ux
                        wide = float(fw[0] if signed > 0.0 else fw[1]) if fw else float(edge["pavement"])
                        short = edge["w"] * 0.5 + wide + clear - abs(signed)
                        if short <= clear + TRIM_LEAST: continue      # (not into the footway itself)
                        away = (-uz * math.copysign(1.0, signed), ux * math.copysign(1.0, signed))
                        axis = max((0, 1), key=lambda k: abs(axes[k][0] * away[0] + axes[k][1] * away[1]))
                        lean = axes[axis][0] * away[0] + axes[axis][1] * away[1]
                        need = short / max(abs(lean), 0.5)
                        if worst is None or need > worst[0]: worst = (need, axis, 1.0 if lean > 0.0 else -1.0)
            if worst is None: continue
            need, axis, toward = worst
            size = 3 if axis == 0 else 5
            if b[size] - need < 3.0:
                print("  %s box %d stands %.2f m into %s and is too shallow to trim: left as it is" % (kind, index, need, edge["name"]))
                continue
            # The face toward the street moves back by `need`: the box is that much shallower and its
            # middle moves half of it away from the street (toward is the side that stays).
            b[size] = round(b[size] - need, 3)
            b[0] = round(b[0] + axes[axis][0] * toward * need * 0.5, 3)
            b[2] = round(b[2] + axes[axis][1] * toward * need * 0.5, 3)
            print("  %s box %d trimmed %.2f m off its side on %s" % (kind, index, need, edge["name"]))


def main():
    global TERRAIN
    TERRAIN = terrain.Terrain(sys.modules[__name__])
    paint_base()
    paint_roads(first=True)
    crossings = junctions.find(PLAN)
    junctions.paint(sys.modules[__name__], crossings, mark=True)
    by_pattern = {d["pattern"]: d for d in PLAN["districts"]}
    place_rng = random.Random(SEED + 404)
    for place in PLAN["places"]:   # named squares and parks first, so the town is built round them
        make_place(place["rect"], place["kind"], place_rng, place["name"])
    for pattern in SITES:
        GENERATORS[pattern](by_pattern[pattern], random.Random(SEED + by_pattern[pattern]["id"] * 101))
    stats = city_fabric.build(sys.modules[__name__])
    for pattern in COUNTRY:
        GENERATORS[pattern](by_pattern[pattern], random.Random(SEED + by_pattern[pattern]["id"] * 101))
    # The town painted its own streets; the planned roads and rails go back on top, crisp.
    paint_stream(block=False)
    stream_trees(random.Random(SEED + 909))
    paint_roads(first=False)
    junctions.paint(sys.modules[__name__], crossings, mark=False)
    junctions.furnish(sys.modules[__name__], crossings)
    breakers = break_long_views(crossings)
    for road in PLAN["roads"]:
        if road["kind"] == "expressway":
            elevated_road(road)
    add_box(-1150, 42, 14, 26, 11, kind="rock", force=True)   # tunnel mouth in the mountain wall
    for road in PLAN["roads"]:
        if road["kind"] == "bridge":
            bridge_deck(road)
    for shape in shapes:
        shape["y"] = round(shape["y"] + TERRAIN.at(shape["x"], shape["z"]), 2)
    post_list = posts()
    # What a player meets: coves, lived-in houses, robots, birds, and which doors open.
    module = sys.modules[__name__]
    tall_types = name_tall_buildings()
    meet, doors = encounters.build(module)
    shut = 0
    for index, box in enumerate(boxes):       # a town building that stays shut: kind-a or kind-b, its two looks
        if box[7] in encounters.TOWN_KINDS and box[8] == 0.0 and index not in doors:
            box[7] += "-a" if shut % 2 == 0 else "-b"   # taken in turn, so neighbours along a street differ
            shut += 1
    # Which shop-houses are corner shops and restaurants (and a few corner houses that open one).
    trade = businesses.build(module, meet, doors)
    measured = encounters.measure(module, meet, doors)
    measured += trade["measure"]
    measured.append(businesses.fill_row_gaps(module)[1])
    measured.append(businesses.plant_plaza(module, "south side of the shop row road", -448.0, 7.0, 2.0, -438.0, -266.0, 1.0)[1])
    measured.append("  tall buildings by type: %d offices, %d apartment blocks, %d luxury apartment blocks" % (tall_types["office"], tall_types["apartment"], tall_types["luxury"]))
    roof_parts()
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, ".gdignore"), "w", encoding="utf-8") as handle:
        handle.write("")
    ground.save(os.path.join(OUT, "map1_ground.png"))
    TERRAIN.save(os.path.join(OUT, "map1_height.bin"))
    kinds = sorted({b[7] for b in boxes})
    # Streets the game builds a real edge on (kerb, gutter, footway). A first trial: the one
    # homes street nearest STREET_TRIAL. The ground picture alone cannot show a 13 cm kerb.
    street_edges = []
    town = [s for s in getattr(module, "town_streets", []) if s["cls"] == "local"]
    if town:
        def gap(street):
            return min(math.hypot(x - STREET_TRIAL[0], z - STREET_TRIAL[1]) for x, z in street["path"].pts)
        trial = min(town, key=gap)
        street_edges.append({"name": "homes street trial", "cls": trial["cls"], "w": trial["w"], "pavement": city_fabric.PAVEMENT[trial["cls"]],
                             "points": [[round(float(x), 4), round(float(z), 4)] for x, z in trial["path"].pts]})
    # The lane with the police box and the café terrace (Codex's koban lane), under the name
    # the game already looks for, with the street's true width and footway.
    if town:
        def gap_koban(street):
            return min(math.hypot(x - KOBAN_LANE[0], z - KOBAN_LANE[1]) for x, z in street["path"].pts)
        lane = min(town, key=gap_koban)
        print("koban lane: class %s, width %.2f, pavement %.2f, from %s to %s, nearest %.1f m from the chosen spot" % (
            lane["cls"], lane["w"], city_fabric.PAVEMENT[lane["cls"]], lane["path"].pts[0], lane["path"].pts[-1], gap_koban(lane)))
        street_edges.append({"name": "koban lane", "cls": lane["cls"], "w": lane["w"], "pavement": city_fabric.PAVEMENT[lane["cls"]],
                             "points": [[round(float(x), 4), round(float(z), 4)] for x, z in lane["path"].pts]})
    # The first wide road: the stretch in front of the shop row (boxes 171 to 193), chosen
    # with Codex 2026-11-14. Only the part of the road between the two x values is exported.
    wide = [s for s in getattr(module, "town_streets", []) if s["cls"] in ("ring", "grid", "arterial", "collector")]
    if wide:
        def gap_row(street):
            return min(math.hypot(x - SHOP_ROW[0], z - SHOP_ROW[1]) for x, z in street["path"].pts)
        road = min(wide, key=gap_row)
        part = [[round(x, 2), round(z, 2)] for x, z in road["path"].pts if SHOP_ROW_SPAN[0] <= x <= SHOP_ROW_SPAN[1] and abs(z - SHOP_ROW[1]) < 30.0]
        print("shop row road: class %s, width %.2f, pavement %.2f, %d points of %d, nearest %.1f m from the chosen spot" % (
            road["cls"], road["w"], city_fabric.PAVEMENT[road["cls"]], len(part), len(road["path"].pts), gap_row(road)))
        if len(part) >= 2:
            # (Its west end carries on as "shop row west", so its kerb runs to its own first point.)
            street_edges.append({"name": "shop row", "cls": road["cls"], "w": road["w"], "pavement": city_fabric.PAVEMENT[road["cls"]], "points": part,
                                 "joined_start": True, "end_patch": tram_bed_patch(ground, part, road["w"])})
            # The shop row carried on west to the Outer ring (agreed with Codex, 2026-11-14), as its
            # own piece so the shop row's metres along stay as they are. It runs from the shop row's
            # first point to where its corner curve starts, and its far end turns a quarter round
            # into the ring's kerb line on both sides. The ring is 23 m wide here (its turn-lane
            # approach) and painted to x = RING_KERB_X; a curve of SHOP_WEST_CORNER_R stays on the
            # land side of the junction's own 3 m splay, so no footway covers its paint, and keeps the
            # two signal posts at (-466.88, -457.84 / -438.16) on the footway, 0.4 m in from the kerb.
            start = part[0]
            end_x = RING_KERB_X + SHOP_WEST_CORNER_R
            if start[0] > end_x + 1.0:
                street_edges.append({"name": "shop row west", "cls": road["cls"], "w": road["w"], "pavement": city_fabric.PAVEMENT[road["cls"]],
                                     "points": [[start[0], start[1]], [round(end_x, 2), start[1]]], "exact": True,
                                     "footway": [city_fabric.PAVEMENT[road["cls"]]] * 2, "ends": ["on", "corner"],
                                     "end_corner_r": SHOP_WEST_CORNER_R})
    # The homes block (agreed with Codex, 2026-11-14): every lane with a part inside
    # HOMES_BLOCK, laid in pieces between the two through streets (the koban lane and the
    # trial homes street, which are wider and keep their kerb lines). Each through street is
    # told exactly where each lane crosses it. The ground picture is drawn up to half a metre
    # off a street's true edge, so kerbs that must meet take the map's own lines, not the
    # picture's.
    if town and len(street_edges) >= 2:
        def straight(street):
            first, last = street["path"].pts[0], street["path"].pts[-1]
            length = math.hypot(last[0] - first[0], last[1] - first[1])
            along = ((last[0] - first[0]) / length, (last[1] - first[1]) / length)
            return first, along, (-along[1], along[0]), length       # start, direction, the +1 side's direction, length

        def cross2(u, v):
            return u[0] * v[1] - u[1] * v[0]

        through = [(street_edges[1], lane), (street_edges[0], trial)]      # the koban lane, the trial street
        # And the wide street across the south of the block, its stretch inside the block. Where
        # the tram runs down its middle (the rail bed painted there), the road is the two lanes
        # either side of it and the bed is left as it is.
        wide_streets = [s for s in getattr(module, "town_streets", []) if s["cls"] in ("ring", "grid", "arterial", "collector")]
        if wide_streets:
            tram = min(wide_streets, key=lambda s: min(math.hypot(x - TRAM_SOUTH[0], z - TRAM_SOUTH[1]) for x, z in s["path"].pts))
            part = [[round(float(x), 4), round(float(z), 4)] for x, z in tram["path"].pts if HOMES_BLOCK[0] <= x <= TRAM_SOUTH_TO and HOMES_BLOCK[1] <= z <= HOMES_BLOCK[3]]
            # (To the stated end itself, not the last plan point short of it.)
            if len(part) >= 2 and part[-1][0] < TRAM_SOUTH_TO - 0.05:
                part.append([TRAM_SOUTH_TO, part[-1][1]])
            if len(part) >= 2:
                middle = part[len(part) // 2]
                bed = ground.getpixel((int(middle[0] - X0), int(middle[1] - Z0)))[:3] == RAIL_BED
                tram_edge = {"name": "tram street south", "cls": tram["cls"], "w": tram["w"], "pavement": city_fabric.PAVEMENT[tram["cls"]],
                             "median": 3.0 if bed else 0.0, "points": [part[0], part[-1]]}
                street_edges.append(tram_edge)
                # (As a straight line between the stretch's ends, for the crossings below.)
                class _Line:
                    def __init__(self, a, b): self.pts = [tuple(a), tuple(b)]
                through.append((tram_edge, {"path": _Line(part[0], part[-1]), "w": tram["w"], "cls": tram["cls"]}))
                # Its diagonal stretch, from the bend to where it turns north, as a street of its own
                # for now (the bend itself is not built yet).
                diag = [[round(float(x), 4), round(float(z), 4)] for x, z in tram["path"].pts
                        if DIAGONAL_PILOT[0] <= x <= DIAGONAL_PILOT[2] and DIAGONAL_PILOT[1] <= z <= DIAGONAL_PILOT[3]]
                if len(diag) >= 2 and DIAGONAL_PILOT in BLOCKS:
                    middle = diag[len(diag) // 2]
                    bed = ground.getpixel((int(middle[0] - X0), int(middle[1] - Z0)))[:3] == RAIL_BED
                    diag_edge = {"name": "tram street diagonal", "cls": tram["cls"], "w": tram["w"], "pavement": city_fabric.PAVEMENT[tram["cls"]],
                                 "median": 3.0 if bed else 0.0, "points": [diag[0], diag[-1]]}
                    street_edges.append(diag_edge)
                    through.append((diag_edge, {"path": _Line(diag[0], diag[-1]), "w": tram["w"], "cls": tram["cls"]}))
        for entry, _ in through:
            entry["crossings"] = []
        def block_of(street):
            """The block a lane is laid in: the one holding most of its points (None if none)."""
            counts = [sum(1 for x, z in street["path"].pts if box[0] <= x <= box[2] and box[1] <= z <= box[3]) for box in BLOCKS]
            return BLOCKS[counts.index(max(counts))] if max(counts) > 0 else None

        def in_blocks(x, z):
            return any(box[0] <= x <= box[2] and box[1] <= z <= box[3] for box in BLOCKS)

        lanes = [s for s in town if s is not trial and s is not lane and s["cls"] == "local" and block_of(s) is not None]
        # Two lanes the generator laid on one line, overlapping (centre lines within 0.3 m, parallel,
        # at the same level): one route. Laid as one lane over both extents, at the narrower width,
        # so a stretch already built at that width is unchanged; the wider one's extra painted road
        # lies under its footway. (Agreed with Codex, 2026-11-14.)
        class _Merged:
            def __init__(self, a, b): self.pts = [tuple(a), tuple(b)]
        merged_any = True
        while merged_any:
            merged_any = False
            for i in range(len(lanes)):
                for j in range(i + 1, len(lanes)):
                    a_start, a_dir, a_side, a_len = straight(lanes[i])
                    b_start, b_dir, b_side, b_len = straight(lanes[j])
                    if abs(cross2(a_dir, b_dir)) > 0.01:
                        continue
                    if abs((b_start[0] - a_start[0]) * a_side[0] + (b_start[1] - a_start[1]) * a_side[1]) > 0.3:
                        continue
                    ta = [0.0, a_len]
                    tb = sorted(((b_start[0] - a_start[0]) * a_dir[0] + (b_start[1] - a_start[1]) * a_dir[1] + k * b_len * (a_dir[0] * b_dir[0] + a_dir[1] * b_dir[1]) for k in (0.0, 1.0)))
                    if tb[0] >= ta[1] - 0.5 or tb[1] <= ta[0] + 0.5:
                        continue
                    narrow = lanes[i] if lanes[i]["w"] <= lanes[j]["w"] else lanes[j]
                    # (On the narrower lane's own line, out over both extents.)
                    n_start, n_dir, n_side, n_len = straight(narrow)
                    ends = [((p[0] - n_start[0]) * n_dir[0] + (p[1] - n_start[1]) * n_dir[1]) for s in (lanes[i], lanes[j]) for p in (s["path"].pts[0], s["path"].pts[-1])]
                    lo, hi = min(ends), max(ends)
                    joined = dict(narrow)
                    joined["path"] = _Merged((n_start[0] + n_dir[0] * lo, n_start[1] + n_dir[1] * lo), (n_start[0] + n_dir[0] * hi, n_start[1] + n_dir[1] * hi))
                    print("lanes on one line merged: x %.2f z %.2f to x %.2f z %.2f, width %.2f (the other was %.2f)" % (
                        joined["path"].pts[0][0], joined["path"].pts[0][1], joined["path"].pts[1][0], joined["path"].pts[1][1], narrow["w"], (lanes[j] if narrow is lanes[i] else lanes[i])["w"]))
                    lanes = [s for k, s in enumerate(lanes) if k not in (i, j)] + [joined]
                    merged_any = True
                    break
                if merged_any:
                    break
        lanes.sort(key=lambda s: (float(s["path"].pts[0][0]), float(s["path"].pts[0][1])))
        all_streets = getattr(module, "town_streets", [])

        def rank(street):
            """Which of two streets runs through where they cross: the wider; for equal widths the
            longer (as the generator made it, before any block cut it); then the generator's
            own order, so neighbouring blocks always agree."""
            index = next((n for n, s in enumerate(all_streets) if s is street), 0)
            return (round(float(street["w"]), 3), round(float(straight(street)[3]), 3), -index)

        # Pass 1: every lane is cut where a higher-ranked street crosses it. Each crossing is
        # recorded on the street that runs through: a whole street''s export entry, or a lane.
        lane_crossings = {id(one): [] for one in lanes}       # (from, to, side dict, label), metres along the lane
        plans = []
        crossers = [(entry, street) for entry, street in through] + [(None, other) for other in lanes]
        for one in lanes:
            l_start, l_dir, l_side, l_len = straight(one)
            l_half = one["w"] * 0.5
            # The part of the lane inside the blocks, as metres along it: across the seam where two
            # blocks meet, so a lane is laid on continuously from one into the next.
            ranges = []
            for block in BLOCKS:
                r0, r1 = 0.0, l_len
                for axis, low, high in ((0, block[0], block[2]), (1, block[1], block[3])):
                    if abs(l_dir[axis]) > 1e-9:
                        a, b = sorted(((low - l_start[axis]) / l_dir[axis], (high - l_start[axis]) / l_dir[axis]))
                        r0, r1 = max(r0, a), min(r1, b)
                    elif not (low <= l_start[axis] <= high):
                        r0, r1 = 1.0, 0.0
                if r1 > r0:
                    ranges.append([r0, r1])
            ranges.sort()
            joined_ranges = []
            for r in ranges:
                if joined_ranges and r[0] <= joined_ranges[-1][1] + 0.5:
                    joined_ranges[-1][1] = max(joined_ranges[-1][1], r[1])
                else:
                    joined_ranges.append(r)
            t0, t1 = max(joined_ranges, key=lambda r: r[1] - r[0])
            # Each higher-ranked street it crosses: where, and the lane''s metres at that street''s two footway backs.
            marks = []
            for entry, street in crossers:
                if street is one or (entry is None and rank(street) <= rank(one)):
                    continue
                r_start, r_dir, r_side, r_len = straight(street)
                r_half = street["w"] * 0.5
                r_pave = city_fabric.PAVEMENT[street["cls"]]
                turn = cross2(l_dir, r_dir)
                if abs(turn) < 1e-6:
                    continue
                gap_ = (r_start[0] - l_start[0], r_start[1] - l_start[1])
                t_mid = cross2(gap_, r_dir) / turn
                s_mid = cross2(gap_, l_dir) / turn
                # (A lane may begin inside the street it meets, as the generator draws them: its start
                # is within that street's half width, measured along the lane.)
                reach_in = (r_half + r_pave + 1.0) / max(abs(turn), 0.2)
                if not (0.0 <= s_mid <= r_len and t0 - reach_in <= t_mid <= t1 + reach_in):
                    continue
                # (A lane that runs through is crossed only where both lie inside the block.)
                if entry is None:
                    px, pz = r_start[0] + r_dir[0] * s_mid, r_start[1] + r_dir[1] * s_mid
                    if not in_blocks(px, pz):
                        continue
                sides = []
                for sign in (1.0, -1.0):
                    # Does the lane go on past this street''s kerb on this side?
                    reach = max(((p[0] - r_start[0]) * r_side[0] + (p[1] - r_start[1]) * r_side[1]) * sign
                                for p in (l_start, (l_start[0] + l_dir[0] * l_len, l_start[1] + l_dir[1] * l_len)))
                    if reach < r_half + 1.0:
                        continue
                    # The lane''s two edge lines cut this street''s kerb line here (metres along this street).
                    cuts = []
                    for edge in (1.0, -1.0):
                        d = (l_start[0] + l_side[0] * edge * l_half - r_start[0] - r_side[0] * sign * r_half,
                             l_start[1] + l_side[1] * edge * l_half - r_start[1] - r_side[1] * sign * r_half)
                        cuts.append(cross2(d, l_dir) / cross2(r_dir, l_dir))
                    d = (r_start[0] + r_side[0] * sign * (r_half + r_pave) - l_start[0], r_start[1] + r_side[1] * sign * (r_half + r_pave) - l_start[1])
                    back_t = float(cross2(d, r_dir) / turn)
                    # Where each of the lane's two kerb lines meets this street's footway back line,
                    # from where its centre line does (0 where they cross square), and which way the
                    # lane runs from here: where they cross at an angle, the kerbs start at different
                    # places and the corners turn through different angles.
                    offsets = {}
                    for edge in (1.0, -1.0):
                        d2 = (d[0] - l_side[0] * edge * l_half, d[1] - l_side[1] * edge * l_half)
                        offsets[edge] = float(cross2(d2, r_dir) / turn) - back_t
                    away = 1.0 if back_t > t_mid else -1.0
                    sides.append({"side": sign, "from": round(float(min(cuts)), 4), "to": round(float(max(cuts)), 4), "built": False, "_back": back_t,
                                  "lane_dir": [round(float(l_dir[0] * away), 6), round(float(l_dir[1] * away), 6)],
                                  "_offsets": offsets, "_line": [round(float(r_dir[0]), 6), round(float(r_dir[1]), 6)]})
                if sides:
                    marks.append((float(t_mid), entry, sides, street))
            marks.sort(key=lambda mark: mark[0])
            plans.append((one, l_start, l_dir, l_side, l_len, l_half, t0, t1, marks))
            for t_mid, entry, sides, street in marks:
                if entry is None:
                    for side in sides:
                        lane_crossings[id(street)].append((side["from"], side["to"], side, "lane at x %.2f" % float(l_start[0])))

        # Pass 2: each lane''s pieces, with their footways measured, and the crossings of lower lanes
        # that fall inside a piece handed to that piece in its own metres.
        laid = []
        for (one, l_start, l_dir, l_side, l_len, l_half, t0, t1, marks) in plans:
            # The pieces: from the lane''s start (or the block''s edge) to the first street''s footway
            # back, between two streets'' backs, and from the last one''s to the lane''s end.
            at, at_kind, at_side = t0, ("dead" if t0 <= 1e-6 else "cut"), None
            spans = []
            for t_mid, entry, sides, street in marks:
                before = [s for s in sides if s["_back"] < t_mid]
                after = [s for s in sides if s["_back"] > t_mid]
                if before and at is not None:
                    spans.append((at, before[0]["_back"], at_kind, "joined", at_side, before[0]))
                at, at_kind, at_side = (after[0]["_back"], "joined", after[0]) if after else (None, None, None)
            if at is not None:
                spans.append((at, t1, at_kind, ("dead" if t1 >= l_len - 1e-6 else "cut"), at_side, None))
            x_here = float(l_start[0])
            pave = city_fabric.PAVEMENT[one["cls"]]
            mine = lane_crossings[id(one)]

            def room_at(t, sign):
                """How far behind the kerb''s face the nearest building stands on one side, at
                metres `t` along the lane (looked at 25 cm either way along it), up to the
                pavement''s width and a little more."""
                for o10 in range(0, int((pave + 0.1) * 20) + 1):
                    o = o10 * 0.05
                    for dt in (-0.25, 0.0, 0.25):
                        x = l_start[0] + l_dir[0] * (t + dt) + l_side[0] * sign * (l_half + o)
                        z = l_start[1] + l_dir[1] * (t + dt) + l_side[1] * sign * (l_half + o)
                        for q in near_boxes:
                            ang = math.radians(q[6])
                            dx, dz = x - q[0], z - q[2]
                            lx = dx * math.cos(ang) - dz * math.sin(ang)
                            lz = dx * math.sin(ang) + dz * math.cos(ang)
                            if abs(lx) <= q[3] * 0.5 and abs(lz) <= q[5] * 0.5:
                                return o
                return 99.0

            def width_for(room):
                """The footway a side has room for: the full pavement, a narrow one past a house that
                stands close, or the kerb alone. (Three widths only: a real pavement does not step
                in and out by ten centimetres from house to house.)"""
                if room >= pave + 0.05:
                    return pave
                if room >= 0.95:
                    return 0.9
                return 0.14

            pieces = []
            for span_number, (a, b, kind_a, kind_b, side_a, side_b) in enumerate(spans):
                if b - a < 1.2:
                    continue
                lo_x, hi_x = sorted((l_start[0] + l_dir[0] * a, l_start[0] + l_dir[0] * b))
                lo_z, hi_z = sorted((l_start[1] + l_dir[1] * a, l_start[1] + l_dir[1] * b))
                near_boxes = [q for q in boxes if q[3] >= 3.0 and q[5] >= 3.0 and lo_x - 15 <= q[0] <= hi_x + 15 and lo_z - 15 <= q[2] <= hi_z + 15]
                # Each side''s footway, metre by metre; the lane is cut into pieces where it changes,
                # so a footway runs where there is room and stops at a building that stands at the kerb.
                # (Not inside a crossing of a lower lane, where the corners decide.)
                stations = []
                t = a
                while t < b:
                    widths = (width_for(room_at(t + 0.25, 1.0)), width_for(room_at(t + 0.25, -1.0)))
                    if stations and any(c[0] - 1.0 - pave <= t <= c[1] + 1.0 + pave for c in mine):
                        widths = stations[-1][1]
                    stations.append((t, widths))
                    t += 0.5
                # And where a lane running alongside within reach starts or ends: the ground between the
                # two is an island only where both run, so the piece is cut there too.
                forced = []
                for other in lanes:
                    if other is one:
                        continue
                    o_start, o_dir, o_side, o_len = straight(other)
                    if abs(cross2(l_dir, o_dir)) > 0.01:
                        continue
                    apart = abs((o_start[0] - l_start[0]) * l_side[0] + (o_start[1] - l_start[1]) * l_side[1])
                    if apart > (one["w"] + other["w"]) * 0.5 + 2.0 * pave + 0.5 or apart < 0.3:
                        continue
                    for p in (o_start, (o_start[0] + o_dir[0] * o_len, o_start[1] + o_dir[1] * o_len)):
                        f = (p[0] - l_start[0]) * l_dir[0] + (p[1] - l_start[1]) * l_dir[1]
                        if a + 0.6 < f < b - 0.6:
                            forced.append(f)
                forced.sort()
                cuts = [[a, stations[0][1]]]
                previous = a
                for t, widths in stations[1:]:
                    for f in forced:
                        if previous < f <= t and f - cuts[-1][0] >= 0.6:
                            cuts.append([f, widths])
                    if widths != cuts[-1][1]:
                        cuts.append([t, widths])
                    previous = t
                # A piece under 1.2 m long takes the narrower of its own and its neighbour''s.
                merged = []
                for c in cuts:
                    if merged and (c[0] - merged[-1][0] < 1.2) and not any(abs(c[0] - f) < 0.01 for f in forced):
                        merged[-1][1] = (min(merged[-1][1][0], c[1][0]), min(merged[-1][1][1], c[1][1]))
                    else:
                        merged.append([c[0], c[1]])
                if len(merged) > 1 and b - merged[-1][0] < 1.2:
                    last = merged.pop()
                    merged[-1][1] = (min(merged[-1][1][0], last[1][0]), min(merged[-1][1][1], last[1][1]))
                for n, (c0, widths) in enumerate(merged):
                    c1 = merged[n + 1][0] if n + 1 < len(merged) else b
                    pieces.append((c0, c1, kind_a if n == 0 else "on", kind_b if n == len(merged) - 1 else "on",
                                   side_a if n == 0 else None, side_b if n == len(merged) - 1 else None, widths, span_number, n,
                                   kind_a == "joined" and kind_b == "joined"))
            for (a, b, kind_a, kind_b, side_a, side_b, widths, number, sub, between) in pieces:
                link = between
                if b - a < 1.2:
                    continue
                for side in (side_a, side_b):
                    if side is not None:
                        side["built"] = True
                # (Named by where it runs: a lane running north and south by its x, one running east and west by its z.)
                where = ("%d" % round(x_here)) if abs(l_dir[1]) >= abs(l_dir[0]) else ("z%d" % round(float(l_start[1])))
                name = "homes link lane" if (abs(x_here - 90.86) < 0.5 and link) else "homes lane %s %s" % (where, "abcdefgh"[number])
                if sub > 0:
                    name += " %d" % (sub + 1)
                piece = {"name": name, "cls": one["cls"], "w": one["w"], "pavement": city_fabric.PAVEMENT[one["cls"]], "exact": True, "ends": [kind_a, kind_b], "footway": [widths[0], widths[1]],
                         "points": [[round(float(l_start[0] + l_dir[0] * t), 4), round(float(l_start[1] + l_dir[1] * t), 4)] for t in (a, b)]}
                # Where a piece meets a street at an angle: how far each side's kerb starts or ends
                # from the piece's own end, and the direction of that street's footway back line there.
                ends_info = []
                for side in (side_a, side_b):
                    if side is not None and any(abs(v) > 0.02 for v in side["_offsets"].values()):
                        ends_info.append({"offsets": [round(side["_offsets"][1.0], 4), round(side["_offsets"][-1.0], 4)], "line": side["_line"]})
                    else:
                        ends_info.append(None)
                if any(e is not None for e in ends_info):
                    piece["angled_ends"] = ends_info
                # Lower lanes that cross this piece: where, in this piece''s own metres.
                own = [c for c in mine if a + 0.5 <= c[0] and c[1] <= b - 0.5]
                if own:
                    groups = {}
                    for c in own:
                        groups.setdefault(c[3], []).append({"side": c[2]["side"], "from": round(c[0] - a, 4), "to": round(c[1] - a, 4), "built": c[2]})
                    piece["crossings"] = [{"with": label, "sides": sides} for label, sides in groups.items()]
                laid.append(piece)
            for t_mid, entry, sides, street in marks:
                if entry is not None:
                    entry["crossings"].append({"with": "lane at x %.2f" % x_here, "sides": sides})
        # The "built" of a lane''s crossing is the lower lane''s own side record: read it now that every
        # piece is laid, and drop the working values.
        for piece in laid:
            for crossing in piece.get("crossings", []):
                for side in crossing["sides"]:
                    side["built"] = bool(side["built"]["built"])
        for entry, _ in through:
            for crossing in entry["crossings"]:
                for side in crossing["sides"]:
                    side.pop("_back", None)
                    side.pop("_offsets", None)
                    side.pop("_line", None)
        for piece in laid:
            for crossing in piece.get("crossings", []):
                for side in crossing["sides"]:
                    for key in ("_back", "_offsets", "_line"):
                        side.pop(key, None)
        street_edges.extend(laid)
        print("homes block: %d lanes in the block, %d pieces laid: %s" % (len(lanes), len(laid), "; ".join("%s %s to %s (%s)" % (e["name"], e["points"][0], e["points"][1], "/".join(e["ends"])) for e in laid)))
        for entry, _ in through:
            print("  %s is crossed at: %s" % (entry["name"], "; ".join("%s %s" % (c["with"], [(s["side"], s["from"], s["to"], s["built"]) for s in c["sides"]]) for c in entry["crossings"])))
    fork = fork_south_kerb(street_edges)
    if fork is not None:
        street_edges.append(fork)
        street_edges.extend(fork_island(street_edges, fork))
        fork_inner_corner(street_edges)
        street_edges.extend(fork_diagonal_south(street_edges))
        street_edges.extend(compound_mouth_tip(street_edges))
        street_edges.extend(compound_mouth_east(street_edges, boxes))
        street_edges.extend(compound_mouth_z466(street_edges))
        street_edges.extend(compound_mouth_point(street_edges))
        compound_mouth_asphalt(street_edges)
    trim_houses_off_streets(boxes, street_edges)
    data = {
        "about": "Generated by tools/map_plan/build_map1_blockout.py from data/map1/map1_plan.json. Do not edit by hand.",
        "frame": PLAN["frame"], "kinds": kinds,
        "height": {"file": "map1_height.bin", "cell": terrain.CELL, "columns": TERRAIN.columns, "rows": TERRAIN.rows},
        "boxes": [b[:7] + [kinds.index(b[7])] for b in boxes],
        "shapes": shapes, "trees": trees, "posts": post_list, "spaces": spaces, "junctions": junctions.export(crossings), "view_breakers": breakers, "encounters": meet,
        "street_edges": street_edges, "businesses": trade["list"], "fuel_stations": getattr(module, "fuel_stations", []), "deferred_junctions": DEFERRED_JUNCTIONS,
    }
    with open(os.path.join(OUT, "map1_blockout.json"), "w", encoding="utf-8") as handle:
        json.dump(data, handle, separators=(",", ":"))
    sheet = draw_overview(post_list, crossings)
    sheet.save(OVERVIEW)
    encounters.draw(module, sheet, meet, label).save(OVERVIEW.replace("map1_plan_", "map1_encounters_"))
    businesses.draw(module, ground, trade["list"]).save(OVERVIEW.replace("map1_plan_", "map1_businesses_"))
    report = os.path.join(ROOT, "reports", "map1")
    os.makedirs(report, exist_ok=True)
    with open(os.path.join(report, "encounter_measure.txt"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(measured) + "\n")
    print("\n".join(measured))
    controls = {}
    for crossing in crossings:
        controls[crossing["control"]] = controls.get(crossing["control"], 0) + 1
    print("junctions %d:" % len(crossings), ", ".join("%s %d" % (k, controls[k]) for k in sorted(controls)), "; with right-turn lanes %d" % sum(1 for c in crossings if c["turn_lanes"]))
    counts = {}
    for b in boxes:
        counts[b[7]] = counts.get(b[7], 0) + 1
    print("boxes %d, shapes %d, trees %d, bot posts %d" % (len(boxes), len(shapes), len(trees), len(post_list)))
    print("town: %d tracts, %d side streets, %d buildings along streets" % (stats["tracts"], stats["local_streets"], stats["buildings"]))
    print("leftover land:", ", ".join("%s %d" % (k, v) for k, v in sorted(stats["pockets"].items())))
    places = {}
    for space in spaces:
        places[space["kind"]] = places.get(space["kind"], 0) + 1
    print("public places %d:" % len(spaces), ", ".join("%s %d" % (k, places[k]) for k in sorted(places)))
    print("by kind:", ", ".join("%s %d" % (k, counts[k]) for k in sorted(counts)))
    print("wrote", os.path.relpath(OVERVIEW, ROOT))


if __name__ == "__main__":
    main()
