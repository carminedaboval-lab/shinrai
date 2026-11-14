"""The countryside of Map 1, and the big sites that are laid out by hand.

The town (city_fabric.py) grows by rule. These places do not: a valley is farmed the way
its river and slope allow, an airport is drawn by engineers, a tram depot fans out from one
set of points, a government precinct is formal on purpose. So each is laid out here from
its causes, piece by piece, never scattered.

Every function takes the build module as `m` (ground picture, occupancy mask, boxes, trees,
terrain), the district from the plan file, and its own random source.
"""
import math

import numpy as np
from PIL import Image

from city_fabric import Path, chaikin, dense
import terrain

WATER = (60, 86, 100)
LEVEE = (88, 100, 70)
FOREST_FLOOR = (64, 76, 52)
TRACK = (112, 104, 88)
PAVED = (134, 134, 130)
TAXIWAY = (92, 92, 92)
RUNWAY = (70, 70, 72)
RAIL = (72, 68, 62)
YARD = (118, 114, 106)
PADDY = [(126, 128, 84), (118, 122, 76), (134, 131, 94), (112, 118, 70), (140, 136, 100), (122, 130, 92)]
DRY = [(132, 126, 92), (120, 122, 82), (140, 132, 100), (112, 116, 78), (128, 118, 88)]


# ---- small tools ----------------------------------------------------------------------------

def line(m, points, width, colour, block=False):
    m.paint_line(points, width, colour, block=block)


def patch(m, x, z, w, d, colour, rot=0.0, stamp=0):
    poly = m.pts(m.corners(x, z, w, d, rot))
    m.gd.polygon(poly, fill=colour)
    if stamp:
        m.od.polygon(poly, fill=stamp)


def rect(m, box, colour, stamp=0):
    m.gd.rectangle(m.rect_px(box), fill=colour)
    if stamp:
        m.od.rectangle(m.rect_px(box), fill=stamp)


def tree(m, x, z, scale):
    """A tree anywhere but on a road, on water or in a building: lawns and yards may have them."""
    if not (m.X0 + 3 <= x < m.X1 - 3 and m.Z0 + 3 <= z < m.Z1 - 3):
        return
    if m.occupied.getpixel((int(x - m.X0), int(z - m.Z0))) >= 200:
        return
    m.trees.append([round(x, 1), round(z, 1), round(scale, 2)])


def grove(m, rng, x, z, rx, rz, count, scale=(0.7, 1.2)):
    """Trees in a clump, thicker in the middle, as they grow."""
    for _ in range(count):
        a, r = rng.uniform(0, math.tau), rng.uniform(0, 1) ** 0.7
        tree(m, x + math.cos(a) * rx * r, z + math.sin(a) * rz * r, rng.uniform(*scale))


def pick_other(rng, palette, *avoid):
    choices = [c for c in palette if c not in avoid]
    return rng.choice(choices or palette)


def houses_along(m, rng, path, s0, s1, sides=(1.0, -1.0), plot=(13.0, 21.0), kind="timber", skip=0.2, road_w=5.0):
    """Farmhouses along a lane: each on its own plot, set back behind a yard, some with a shed."""
    made = 0
    for side in sides:
        s = s0 + rng.uniform(0, 6)
        while s < s1 - 6:
            size = rng.uniform(*plot)
            if rng.random() >= skip:
                x, z, tx, tz = path.at(s + size / 2)
                nx, nz = -tz * side, tx * side
                w, d = rng.uniform(7.5, 10.5), rng.uniform(5.5, 7.5)
                back = road_w / 2 + rng.uniform(3.0, 7.0) + d / 2
                turn = -math.degrees(math.atan2(tz, tx)) + rng.uniform(-7, 7)
                if m.add_box(x + nx * back, z + nz * back, w, d, rng.choice([4.6, 5.2, 6.4]), rot=turn, kind=kind, margin=1.0):
                    made += 1
                    if rng.random() < 0.45:   # a shed or a store behind the house
                        off = back + d / 2 + rng.uniform(3.5, 6.0)
                        along = rng.uniform(-size * 0.25, size * 0.25)
                        m.add_box(x + nx * off + tx * along, z + nz * off + tz * along, rng.uniform(3.5, 5.5), rng.uniform(3.0, 4.5), 2.8, rot=turn + rng.choice([0, 90]), kind="small", margin=0.6)
                    if rng.random() < 0.5:
                        tree(m, x + nx * (back + rng.uniform(-3, 8)) + tx * size * 0.4, z + nz * (back + rng.uniform(-3, 8)) + tz * size * 0.4, rng.uniform(0.7, 1.1))
            s += size
    return made


def reach(path, test):
    """The stretch of a path (s0, s1) where test(x, z) holds."""
    hits = [s for s in np.arange(0.0, path.length, 3.0) if test(*path.at(s)[:2])]
    return (min(hits), max(hits)) if hits else (0.0, 0.0)


def plane(m, x, z, length, turn):
    """A parked aircraft: a body and a wing. Each one stands where a stand or a job put it."""
    m.add_box(x, z, length, length * 0.105, length * 0.105, rot=turn, y=2.0, kind="aircraft", force=True, stamp=False)
    m.add_box(x + math.cos(math.radians(turn)) * length * 0.04, z - math.sin(math.radians(turn)) * length * 0.04, length * 0.14, length * 0.9, 0.7, rot=turn, y=2.6, kind="aircraft", force=True, stamp=False)
    m.add_box(x - math.cos(math.radians(turn)) * length * 0.45, z + math.sin(math.radians(turn)) * length * 0.45, length * 0.06, 0.6, length * 0.13, rot=turn, y=2.0 + length * 0.105, kind="aircraft", force=True, stamp=False)


# ---- the river valley -----------------------------------------------------------------------

def gen_valley(m, d, rng):
    T, plan = m.TERRAIN, m.PLAN
    roads = {r["name"]: r for r in plan["roads"]}
    lane_pts = roads["Valley lane"]["points"]
    lane = Path(dense(lane_pts, 3.0))
    highway = roads["West highway"]["points"]
    lane_z = [p[1] for p in lane_pts]
    lane_xs = [p[0] for p in lane_pts]
    hw = sorted((p for p in highway if -700 <= p[1] <= -40), key=lambda p: p[1])

    def lane_x(z):
        return float(np.interp(z, lane_z, lane_xs))

    def river_x(z):
        return float(T.river_x[min(max(int(z - m.Z0), 0), m.H - 1)])

    def east_x(z):   # the valley floor ends at the highway, or at the foot of the ridge
        if hw and hw[0][1] <= z <= hw[-1][1]:
            return float(np.interp(z, [p[1] for p in hw], [p[0] for p in hw])) - 13.0
        return -888.0

    banks = {"west": (lambda z: lane_x(z) + 5.0, lambda z: river_x(z) - 15.0),
             "east": (lambda z: river_x(z) + 15.0, east_x)}

    # Paddies: the floor is cut into strips by farm tracks that run from the lane (or the
    # highway) to the river bank. No two tracks are parallel, and the two banks do not match.
    farm_gates = []
    for bank, (left, right) in banks.items():
        cuts = []
        z = -690.0 + rng.uniform(0, 30)
        while z < 925.0:
            cuts.append((z, rng.uniform(-0.13, 0.13)))
            z += rng.uniform(52.0, 108.0)

        def edge(cut, f):
            zc, tilt = cut
            xl, xr = left(zc), right(zc)
            x = xl + (xr - xl) * f
            return (x, zc + tilt * (x - (xl + xr) / 2))

        last_row = []
        for a, b in zip(cuts, cuts[1:]):
            width = right((a[0] + b[0]) / 2) - left((a[0] + b[0]) / 2)
            if width < 24:
                last_row = []
                continue
            if width < 52:
                splits = [0.0, 1.0]
            elif width < 92:
                splits = [0.0, rng.uniform(0.38, 0.62), 1.0]
            else:
                first = rng.uniform(0.26, 0.4)
                splits = [0.0, first, first + rng.uniform(0.26, 0.36), 1.0]
            row = []
            for i, (fa, fb) in enumerate(zip(splits, splits[1:])):
                poly = [edge(a, fa + (fb - fa) * t / 4) for t in range(5)]
                za, zb = edge(a, fb)[1], edge(b, fb)[1]
                poly += [(left(zz) + (right(zz) - left(zz)) * fb, zz) for zz in np.linspace(za, zb, 8)[1:-1]]
                poly += [edge(b, fb - (fb - fa) * t / 4) for t in range(5)]
                za, zb = edge(b, fa)[1], edge(a, fa)[1]
                poly += [(left(zz) + (right(zz) - left(zz)) * fa, zz) for zz in np.linspace(za, zb, 8)[1:-1]]
                colour = pick_other(rng, PADDY, row[-1] if row else None, last_row[i] if i < len(last_row) else None)
                m.gd.polygon(m.pts(poly), fill=colour)
                row.append(colour)
            last_row = row
        for cut in cuts:
            line(m, [edge(cut, 0.0), edge(cut, 1.0)], 2, TRACK)
            if bank == "west":
                farm_gates.append(edge(cut, 0.0))

    # Rice terraces climb the slope behind two of the villages, following its contours.
    floor = terrain.river_level(np.arange(m.Z0, m.Z0 + m.H) + 0.5) + 2.0
    terrace_rng = np.random.default_rng(m.SEED + 71)
    for village in plan["villages"][:2]:
        z0, z1 = int(village["z"] - 170), int(village["z"] + 170)
        x0, x1 = m.X0, int(lane_x(village["z"]) + 40)
        rise = T.field[z0 - m.Z0:z1 - m.Z0, x0 - m.X0:x1 - m.X0] - floor[z0 - m.Z0:z1 - m.Z0, None]
        zz = np.arange(z0, z1)[:, None] + 0.5
        xx = np.arange(x0, x1)[None, :] + 0.5
        step = np.floor(rise / 1.5).astype(int)
        reach_z = 150.0 - 11.0 * step            # each terrace is shorter than the one below
        west_of_lane = xx < np.interp(zz[:, 0], lane_z, lane_xs)[:, None] - 5.0
        on = (rise > 0.5) & (step < 9) & (np.abs(zz - village["z"]) < reach_z) & west_of_lane
        lengths = terrace_rng.integers(34, 78, size=12)
        offsets = terrace_rng.integers(0, 60, size=12)
        cell = (zz + offsets[np.clip(step, 0, 11)]) // lengths[np.clip(step, 0, 11)]
        tone = (cell.astype(int) * 3 + step * 2) % len(PADDY)
        region = np.asarray(m.ground.crop((x0 - m.X0, z0 - m.Z0, x1 - m.X0, z1 - m.Z0))).copy()
        palette = np.array(PADDY, dtype=np.uint8)
        region[on] = palette[tone[on]]
        m.ground.paste(Image.fromarray(region), (x0 - m.X0, z0 - m.Z0))
        village["_terrace"] = (z0, z1)

    # The river between its flood banks, with trees where nobody cut them.
    river = plan["water"]["river"]
    line(m, river["points"], river["width"] + 16, LEVEE)
    line(m, river["points"], river["width"], WATER)
    walk = Path(dense(river["points"], 4.0))
    s = 20.0
    while s < walk.length:
        x, z, tx, tz = walk.at(s)
        side = rng.choice([-1, 1])
        if z > -700:
            grove(m, rng, x - tz * side * 13, z + tx * side * 13, 5, 9, rng.randint(1, 4), (0.7, 1.15))
        s += rng.uniform(16, 58)
    # Roads and the railway again, over the fields.
    for road in plan["roads"]:
        if road["kind"] in ("country", "highway") or road["name"] in ("Coast road", "West avenue"):
            m.paint_line(road["points"], road["width"], m.ROAD_COLOUR[road["kind"]])
    m.paint_line(plan["rail"]["mountain_line"], 6, m.RAIL_BED)

    # North village: houses on the lane and up the first of the mountain road, a mill on the
    # river and a footbridge to the highway side.
    mountain = Path(dense(roads["Mountain road"]["points"], 3.0))
    houses_along(m, rng, lane, *reach(lane, lambda x, z: -442 < z < -330))
    houses_along(m, rng, mountain, 4.0, 105.0, road_w=6.0)
    mill_lane = [(-1046, -446), (-1028, -452), (river_x(-454) - 14, -454)]
    line(m, mill_lane, 3, TRACK, block=True)
    m.add_box(river_x(-454) - 15, -464, 13, 8, 7, rot=12, kind="landmark", margin=0.5)
    bank = T.at(river_x(-454) - 13, -454)
    m.add_box(river_x(-454), -454, 30, 2.6, 0.5, y=bank - 0.3, kind="deck", force=True, stamp=False, absolute=True)
    line(m, [(river_x(-454) + 13, -454), (east_x(-450) + 2, -448)], 2, TRACK)

    # Hill village: houses along the lane, a shrine up its own steps above the terraces.
    houses_along(m, rng, lane, *reach(lane, lambda x, z: -118 < z < 22))
    steps = chaikin([(lane_x(-46) - 3, -46), (lane_x(-46) - 20, -58), (lane_x(-46) - 44, -62)], 2)
    line(m, steps, 2, m.PATH, block=True)
    sx, sz = steps[-1][0] - 6, steps[-1][1] - 1
    m.add_box(sx, sz, 7, 5.5, 5, rot=10, kind="landmark", force=True)
    for dz in (-1.6, 1.6):
        m.add_box(steps[-1][0] + 2, steps[-1][1] + dz, 0.4, 0.4, 3.6, kind="mast", force=True, stamp=False)
    grove(m, rng, sx, sz, 16, 14, 18, (0.9, 1.4))

    # Crossroads village: where the lane meets the coast road.
    coast = Path(dense(roads["Coast road"]["points"], 3.0))
    houses_along(m, rng, lane, *reach(lane, lambda x, z: 585 < z < 668))
    houses_along(m, rng, coast, coast.length - 120.0, coast.length - 22.0, road_w=14.0, skip=0.3)
    end = lane_pts[-1]
    patch(m, end[0] + 24, end[1] - 12, 22, 16, YARD, rot=-20, stamp=170)       # petrol station forecourt
    m.add_box(end[0] + 24, end[1] - 12, 14, 8, 5, rot=-20, kind="shed", force=True)
    patch(m, end[0] - 30, end[1] + 24, 40, 26, YARD, rot=10, stamp=170)        # farm co-op yard
    m.add_box(end[0] - 34, end[1] + 26, 26, 14, 6, rot=10, kind="shed", force=True)
    m.add_box(end[0] + 8, end[1] + 16, 4, 2, 2.6, rot=-30, kind="small", margin=0.3)   # bus shelter

    # A farmstead at the lane end of some tracks, outside the villages.
    for i, (gx, gz) in enumerate(farm_gates):
        if i % 3 != 1 or any(abs(gz - v["z"]) < 130 for v in plan["villages"]) or abs(gz - 290) < 70 or abs(gz - 40) < 60:
            continue
        hx = lane_x(gz) - 13
        if m.add_box(hx, gz + 9, 10, 7, 5.2, rot=rng.uniform(-10, 10), kind="timber", margin=1.0):
            m.add_box(hx - 2, gz - 7, 12, 8, 4.5, rot=rng.uniform(80, 100), kind="timber", margin=0.6)
            grove(m, rng, hx - 12, gz, 5, 10, 4, (0.8, 1.2))

    # The river warehouse: between the lane and the river, with its own jetty.
    mark = next(l for l in plan["landmarks"] if l["kind"] == "warehouse")
    wx, wz = mark["x"], mark["z"]
    patch(m, wx + 2, wz, 54, 62, YARD, stamp=0)
    m.add_box(wx, wz - 4, 38, 40, 10, kind="shed", force=True)
    m.add_box(wx + 14, wz + 24, 8, 6, 3.4, kind="small", force=True)
    line(m, [(wx + 22, wz + 8), (river_x(wz + 10) - 7, wz + 10)], 3, TRACK)
    m.add_box(river_x(wz + 10) - 8, wz + 10, 12, 3, 0.5, y=T.at(river_x(wz + 10) - 15, wz + 10) - 0.2, kind="deck", force=True, stamp=False, absolute=True)

    # The quarry: a floor cut into the slope, a crusher, spoil by the lane.
    q = next(l for l in plan["landmarks"] if l["kind"] == "quarry")
    m.gd.ellipse([q["x"] - q["size"][0] / 2 - m.X0, q["z"] - q["size"][1] / 2 - m.Z0, q["x"] + q["size"][0] / 2 - m.X0, q["z"] + q["size"][1] / 2 - m.Z0], fill=(124, 120, 112))
    m.add_box(q["x"] + 12, q["z"] - 6, 14, 9, 8, rot=15, kind="shed", force=True)
    m.add_box(q["x"] + 4, q["z"] + 22, 6, 5, 3, rot=-10, kind="small", force=True)
    for bx, bz, size in ((q["x"] - 14, q["z"] - 30, 9), (q["x"] - 6, q["z"] + 38, 7), (q["x"] + 16, q["z"] + 12, 5)):
        m.add_box(bx, bz, size, size * 0.8, size * 0.5, rot=rng.uniform(0, 90), kind="rock", force=True)

    # Woods on the slope wherever it was never terraced.
    z = d["rects"][0][1] + 6.0
    while z < d["rects"][0][3] - 4:
        x = m.X0 + 6.0 + rng.uniform(0, 8)
        limit = lane_x(z) - 8
        terraced = any(v.get("_terrace") and v["_terrace"][0] < z < v["_terrace"][1] and abs(z - v["z"]) < 150 for v in plan["villages"])
        while x < limit:
            height = T.at(x, z) - (terrain.river_level(z) + 2.0)
            if height > (15.0 if terraced else 2.5) and rng.random() < 0.6:
                tree(m, x + rng.uniform(-3, 3), z + rng.uniform(-3, 3), rng.uniform(0.85, 1.4))
            x += rng.uniform(7, 12)
        z += rng.uniform(7, 11)


# ---- the forest ridge -----------------------------------------------------------------------

def gen_forest(m, d, rng):
    T = m.TERRAIN
    box = d["rects"][0]
    crest = [(-784, -590), (-796, -430), (-780, -260), (-798, -110), (-786, -40)]
    south = [(-792, 104), (-776, 260), (-800, 430), (-784, 610), (-798, 780), (-770, 880)]
    across = [[(-884, -478), (-830, -452), (-790, -432), (-745, -400), (-706, -372)],
              [(-884, 428), (-840, 448), (-800, 432), (-752, 500), (-706, 548)],
              [(-884, -150), (-842, -128), (-798, -112)]]
    for trail in [crest, south] + across:
        line(m, chaikin(trail, 3), 2, m.PATH)
    clearings = []
    # The top of the ridge: a lookout over the valley and the city, kept clear.
    top = (-790, -300)
    clearings.append((top[0], top[1], 15))
    m.gd.ellipse([top[0] - 13 - m.X0, top[1] - 11 - m.Z0, top[0] + 13 - m.X0, top[1] + 11 - m.Z0], fill=(110, 112, 86))
    m.add_box(top[0] + 3, top[1] - 2, 5, 5, 6.5, rot=20, kind="timber", force=True)
    # A forestry yard where the crossing trail reaches the highway side.
    yard = (-858, -462)
    clearings.append((yard[0], yard[1], 22))
    patch(m, yard[0], yard[1], 34, 24, (112, 106, 90), rot=-18)
    m.add_box(yard[0] + 9, yard[1] - 5, 7, 5, 3.4, rot=-18, kind="timber", force=True)
    for i, (dx, dz) in enumerate(((-9, -3), (-7, 5), (2, 7))):
        m.add_box(yard[0] + dx, yard[1] + dz, 7.5, 2.2, 1.3 + 0.4 * i, rot=-18 + (0, 6, -4)[i], kind="small", force=True)
    # An old charcoal burners' clearing on the south trail, gone to grass.
    clearings.append((-788, 520, 17))
    m.gd.ellipse([-803 - m.X0, 508 - m.Z0, -773 - m.X0, 532 - m.Z0], fill=(104, 110, 80))
    m.scatter_trees(box, rng, 7.4, 0.8, scale=(0.9, 1.5), holes=clearings)


# ---- the foothills --------------------------------------------------------------------------

def gen_foothills(m, d, rng):
    T = m.TERRAIN
    for box in d["rects"]:
        # Rock shows where the ground is too steep to hold soil, and nowhere else.
        z = box[1] + 10.0
        while z < box[3] - 8:
            x = box[0] + 10.0 + rng.uniform(0, 12)
            while x < box[2] - 8:
                steep = T.slope(x, z)
                if steep > 0.42 and rng.random() < 0.5:
                    size = rng.uniform(5, 13)
                    m.add_box(x, z, size, size * rng.uniform(0.6, 1.1), size * rng.uniform(0.35, 0.7), rot=rng.uniform(0, 180), kind="rock", force=True, stamp=False)
                x += rng.uniform(20, 34)
            z += rng.uniform(20, 32)
        m.scatter_trees(box, rng, 10.5, 0.55, scale=(0.8, 1.4))


# ---- the dam --------------------------------------------------------------------------------

def gen_dam(m, d, rng):
    T = m.TERRAIN
    mark = next(l for l in m.PLAN["landmarks"] if l["kind"] == "dam")
    x, z = mark["x"], mark["z"]
    bed = T.at(x, z + 14)
    m.add_box(x, z, mark["size"][0] + 2, 16, terrain.DAM_CREST - bed + 1.0, y=bed - 1.0, kind="dam", force=True, absolute=True)
    m.add_box(x, z + 20, 58, 22, 14, kind="building", force=True)              # power house at the dam's foot
    m.add_box(x + 38, z + 34, 16, 10, 6, kind="small", force=True)             # switch yard hut
    m.shapes.append({"shape": "cylinder", "x": x + 24, "z": z - 28, "y": -6, "size": 9, "height": 18, "kind": "landmark"})  # intake tower
    # The research station on the east shoulder, where the works road arrives.
    for bx, bz, w, dep, h, turn, kind in ((-846, -1212, 34, 14, 9, 22, "building"), (-826, -1238, 22, 10, 6.5, -68, "building"),
                                           (-868, -1196, 16, 12, 5, 22, "shed"), (-838, -1186, 2, 2, 26, 0, "mast"),
                                           (-834, -1150, 5, 4, 3, 20, "small")):
        m.add_box(bx, bz, w, dep, h, rot=turn, kind=kind, force=True)
    m.add_box(-1106, -1248, 8, 6, 4, rot=-30, kind="small", force=True)        # winch house, west end
    box = d["rects"][0]
    zz = box[1] + 8.0
    while zz < box[3] - 6:
        xx = box[0] + 8.0 + rng.uniform(0, 8)
        while xx < box[2] - 6:
            if rng.random() < (0.22 if T.slope(xx, zz) > 0.6 else 0.5):
                tree(m, xx + rng.uniform(-4, 4), zz + rng.uniform(-4, 4), rng.uniform(0.8, 1.3))
            xx += rng.uniform(10, 15)
        zz += rng.uniform(10, 15)


# ---- the land between the city and the airport ------------------------------------------------

def gen_approach(m, d, rng):
    plan = m.PLAN
    roads = {r["name"]: r for r in plan["roads"]}
    link = sorted(roads["North link"]["points"], key=lambda p: p[0])

    def link_z(x):
        return float(np.interp(x, [p[0] for p in link], [p[1] for p in link]))

    # Market gardens between the outer ring and the highway. Farm lanes run north from the
    # ring road at whatever spacing the old holdings had; each has one kink where two
    # holdings met. The fields between them are cut across at heights that never line up.
    lanes = [(-612, 8), (-468, -10), (-262, 12), (-122, -7), (126, 9), (402, -12), (552, 10), (668, -8)]
    lines = []
    for x, kink in lanes:
        top = min(link_z(x + kink), -760 - max(0.0, (x - 480) * 0.42)) + 13
        points = [(x, -712), (x + kink * 0.2, -770), (x + kink, -812), (x + kink, top)]
        lines.append((x, kink, top, points))
    edges = [(-690, 0, -800)] + [(x, k, t) for x, k, t, _ in lines] + [(770, 0, -770)]
    blocked = [(-14, 14), (272, 300)]     # the north avenue, the airport tram
    for (xa, ka, ta), (xb, kb, tb) in zip(edges, edges[1:]):
        north = max(ta, tb)
        z = -714.0
        last = None
        while z > north + 14:
            depth = rng.uniform(34, 74)
            z2 = max(z - depth, north)
            parts = [(xa + 4, xb - 4)]
            for lo, hi in blocked:
                parts = [seg for a, b in parts for seg in ((a, min(b, lo)), (max(a, hi), b)) if seg[1] - seg[0] > 12]
            for a, b in parts:
                shift_a = ka * min(1.0, max(0.0, (-770 - z) / 42)) if a == xa + 4 else 0
                shift_b = kb * min(1.0, max(0.0, (-770 - z) / 42)) if b == xb - 4 else 0
                last = pick_other(rng, DRY, last)
                m.gd.polygon(m.pts([(a + shift_a, z), (b + shift_b, z), (b + shift_b, z2 + 1.5), (a + shift_a, z2 + 1.5)]), fill=last)
            z = z2
    for x, kink, top, points in lines:
        line(m, points, 3, TRACK)
    # A farmhouse where some of the lanes leave the ring road.
    for i, (x, kink, top, points) in enumerate(lines):
        if i % 2 == 0:
            side = 1 if kink > 0 else -1
            if m.add_box(x + side * 12, -730, 10, 7, 5.5, rot=rng.uniform(-6, 6), kind="timber", margin=1.0):
                m.add_box(x + side * 14, -746, 11, 7, 4.5, rot=90 + rng.uniform(-6, 6), kind="timber", margin=0.5)
                grove(m, rng, x + side * 24, -736, 6, 9, 5, (0.8, 1.2))
    # Glasshouses on two holdings: long, side by side, as they are built.
    for gx, gz, count, turn in ((-380, -798, 5, 4), (480, -780, 4, 96)):
        for i in range(count):
            off = (i - (count - 1) / 2) * 8.4
            m.add_box(gx + off * math.cos(math.radians(turn + 90)), gz - off * math.sin(math.radians(turn + 90)), 30 - (i % 3) * 4, 6.6, 3.2, rot=turn, kind="small", margin=0.2)
    # The substation that feeds the city, in its fenced gravel compound.
    patch(m, -534, -806, 56, 42, (146, 142, 132), stamp=170)
    m.add_box(-552, -814, 12, 9, 5, kind="building", force=True)
    for i, (dx, dz) in enumerate(((-6, 8), (8, 8), (20, 6), (8, -8))):
        m.add_box(-534 + dx, -806 + dz, 5, 4, 4.2 + 0.5 * (i % 2), kind="small", force=True)
    for px_, pz_ in ((-510, -822), (-470, -872), (-430, -924)):   # pylons marching off to the hills
        m.add_box(px_, pz_, 3.2, 3.2, 30, rot=40, kind="mast", force=True, stamp=False)
    # The cemetery beside the north avenue, with its hall.
    patch(m, -44, -836, 44, 68, (138, 136, 130), stamp=170)
    m.add_box(-52, -812, 12, 9, 6, kind="timber", force=True)
    grave_rng = np.random.default_rng(m.SEED + 5)
    for gx, gz in zip(grave_rng.uniform(-62, -26, 90), grave_rng.uniform(-866, -826, 90)):
        m.gd.point((gx - m.X0, gz - m.Z0), fill=(96, 96, 94))
    grove(m, rng, -30, -806, 8, 6, 6, (0.8, 1.2))
    # The water works: two tanks and a pump house.
    patch(m, 604, -790, 66, 44, (140, 140, 134), stamp=170)
    for tx, size in ((590, 22), (618, 17)):
        m.shapes.append({"shape": "cylinder", "x": tx, "z": -792, "y": 0, "size": size, "height": 8 + size * 0.15, "kind": "tank"})
    m.add_box(628, -776, 12, 8, 5, kind="building", force=True)

    # The east farm, by the last drop-off: a lane off the highway, a farmhouse, a second
    # house, a barn and a tractor shed round one yard. Somewhere to search within a minute
    # of landing at D10, which had nothing for 330 m.
    farm = chaikin([(700, -850), (742, -905), (800, -948), (838, -962)], 2)
    line(m, farm, 3, TRACK, block=True)
    patch(m, 812, -972, 46, 30, YARD, rot=-14)
    for bx, bz, w, dep, h, turn, kind in ((796, -984, 10.5, 7.5, 6.4, -14, "timber"), (822, -990, 9.0, 7.0, 5.2, 76, "timber"),
                                           (832, -972, 14.0, 9.0, 5.5, -14, "timber"), (800, -962, 8.0, 5.0, 3.6, -14, "small")):
        m.add_box(bx, bz, w, dep, h, rot=turn, kind=kind, force=True)
    grove(m, rng, 780, -990, 7, 10, 6, (0.8, 1.2))

    # The highway service area.
    rect(m, [-432, -1042, -258, -986], (100, 100, 102), stamp=170)
    line(m, [(-470, -962), (-432, -990)], 6, m.ASPHALT)
    line(m, [(-258, -992), (-214, -966)], 6, m.ASPHALT)
    m.add_box(-372, -1028, 58, 16, 7, kind="building", force=True)
    m.add_box(-292, -1000, 28, 14, 6, kind="shed", force=True)
    m.add_box(-412, -998, 16, 3, 3.6, rot=90, kind="aircraft", force=True)      # a lorry left at the pumps
    grove(m, rng, -346, -1050, 60, 6, 14, (0.7, 1.1))

    # The freight yard: a spur off the airport tram, three sidings, sheds between the
    # sidings and the yard road, and the container stack beyond.
    spur = chaikin([(286, -958), (296, -1000), (334, -1026), (392, -1034), (604, -1034)], 3)
    line(m, spur, 3, RAIL, block=True)
    for z, x0, x1 in ((-1042, 384, 590), (-1050, 392, 566)):
        line(m, [(x0 - 26, -1034), (x0, z), (x1, z)], 3, RAIL, block=True)
    rect(m, [376, -1026, 606, -962], YARD)
    line(m, [(400, -934), (408, -972), (606, -972)], 8, m.ASPHALT, block=True)
    for sx, w, dep, h in ((432, 70, 22, 9), (506, 46, 24, 8), (566, 54, 20, 10)):
        m.add_box(sx, -1002, w, dep, h, kind="shed", margin=0.5)
    m.add_box(398, -952, 7, 5, 3.4, kind="small", force=True)                   # gatehouse
    rect(m, [380, -1102, 604, -1060], (128, 126, 120))
    block_rng = np.random.default_rng(m.SEED + 9)
    for bx, rows, cols in ((392, 4, 5), (470, 5, 4), (540, 3, 4)):
        for r in range(rows):
            for c in range(cols):
                high = int(block_rng.integers(0, 4))
                if high:
                    m.add_box(bx + c * 12.8 + 6, -1066 - r * 3.0 - 1.3, 12.2, 2.44, 2.59 * high, kind="container%d" % int(block_rng.integers(0, 4)), force=True, stamp=False)

    # Airport fringe: long-stay parking, the hotel, car hire.
    rect(m, [-150, -1146, 20, -1064], (108, 108, 110), stamp=170)
    m.add_box(-164, -1100, 8, 5, 3.2, kind="small", force=True)
    rect(m, [-232, -1054, -172, -1004], (108, 108, 110), stamp=170)
    m.add_box(-202, -996, 16, 8, 4, kind="small", force=True)
    m.add_box(70, -1044, 44, 16, 29, rot=-18, kind="slab", margin=1.0)
    m.add_box(34, -960, 16, 10, 5, kind="shed", margin=1.0)                     # petrol station on the avenue
    m.scatter_trees([-700, -1150, 900, -940], rng, 19.0, 0.3, scale=(0.5, 0.95))
    m.scatter_trees([620, -940, 900, -720], rng, 21.0, 0.3, scale=(0.5, 0.95))


# ---- the strip east of the expressway --------------------------------------------------------

def gen_fringe(m, d, rng):
    plan = m.PLAN
    express = next(r for r in plan["roads"] if r["kind"] == "expressway")["points"]
    side = sorted((p for p in express if -700 <= p[1] <= 300), key=lambda p: p[1])
    lane_pts = [(float(np.interp(z, [p[1] for p in side], [p[0] for p in side])) + 17.0, z) for z in range(-690, 291, 35)]
    line(m, lane_pts, 4, TRACK, block=True)
    lane = Path(dense(lane_pts, 3.0))
    drops = [(p["x"], p["z"]) for p in plan["drops"]]
    s = 6.0
    previous = None
    while s < lane.length - 12:
        size = rng.uniform(16, 36)
        x, z, tx, tz = lane.at(s + size / 2)
        nx, nz = tz, -tx
        if nx < 0:
            nx, nz = -nx, -nz           # always the side away from the expressway
        turn = -math.degrees(math.atan2(tz, tx))
        if any(math.hypot(x - dx, z - dz) < 34 for dx, dz in drops):
            s += size
            continue
        kind = pick_other(rng, ["shed", "scrap", "plot", "wood", "shed"], previous)
        previous = kind
        cx, cz = x + nx * 15, z + nz * 15
        if kind == "shed" and m.is_free(cx, cz, size - 3, 22, turn, 0):
            patch(m, cx, cz, size - 3, 22, YARD, rot=turn, stamp=0)
            m.add_box(cx + nx * 3, cz + nz * 3, min(size - 6, rng.uniform(11, 20)), rng.uniform(9, 13), rng.uniform(5, 7), rot=turn, kind="shed", force=True)
        elif kind == "scrap" and m.is_free(cx, cz, size - 3, 22, turn, 0):
            patch(m, cx, cz, size - 3, 22, (132, 124, 110), rot=turn, stamp=0)
            for _ in range(rng.randint(2, 4)):
                m.add_box(cx + tx * rng.uniform(-size * 0.3, size * 0.3) + nx * rng.uniform(-6, 7), cz + tz * rng.uniform(-size * 0.3, size * 0.3) + nz * rng.uniform(-6, 7),
                          rng.uniform(3, 6), rng.uniform(2, 3), rng.uniform(1.4, 2.8), rot=turn + rng.uniform(-30, 30), kind="small", margin=0.2)
        elif kind == "plot":
            patch(m, cx, cz, size - 3, 20, (122, 116, 84), rot=turn, stamp=170)
            m.add_box(cx - tx * (size / 2 - 3), cz - tz * (size / 2 - 3), 2.6, 2.2, 2.2, rot=turn, kind="small", margin=0.0)
        else:
            grove(m, rng, cx, cz, size * 0.4, 9, int(size / 4), (0.7, 1.2))
        s += size
    m.scatter_trees([868, -700, 900, 300], rng, 13.0, 0.4, scale=(0.6, 1.1))


# ---- the airport ----------------------------------------------------------------------------

def gen_airport(m, d, rng):
    rect(m, [-640, -1455, 860, -1405], RUNWAY)
    rect(m, [-600, -1392, 820, -1376], TAXIWAY)
    for x in (-590, -250, 110, 470, 800):                 # links between runway and taxiway
        rect(m, [x - 11, -1406, x + 11, -1391], TAXIWAY)
    m.od.rectangle(m.rect_px([-640, -1455, 860, -1376]), fill=255)
    # Three aprons, one for each job, with grass between them.
    rect(m, [-200, -1377, 336, -1274], PAVED)             # passengers
    rect(m, [336, -1377, 546, -1296], PAVED)              # freight
    rect(m, [-664, -1377, -384, -1296], PAVED)            # maintenance
    # The terminal: the hall, two piers of different lengths, the tower over its head house.
    m.add_box(70, -1225, 380, 100, 18, kind="terminal", force=True)
    m.add_box(60, -1291, 52, 34, 24, kind="terminal", force=True)
    m.add_box(-92, -1318, 18, 88, 10, kind="terminal", force=True)
    m.add_box(216, -1308, 18, 68, 10, kind="terminal", force=True)
    m.shapes.append({"shape": "cylinder", "x": 60, "z": -1300, "y": 24, "size": 9, "height": 22, "kind": "landmark"})
    m.shapes.append({"shape": "cylinder", "x": 60, "z": -1300, "y": 46, "size": 16, "height": 9, "kind": "glass"})
    m.add_box(70, -1170, 300, 9, 0.6, y=7.5, kind="deck", force=True, stamp=False)   # canopy over the set-down lane
    rect(m, [-126, -1176, 266, -1152], (112, 112, 114))
    m.add_box(-44, -1126, 88, 42, 15, kind="carpark", force=True)
    m.add_box(238, -1120, 46, 17, 30, kind="slab", force=True)                       # airport hotel
    m.add_box(150, -1136, 30, 9, 4, kind="small", force=True)                        # bus bays
    # Aircraft: at the stands they were on, plus one abandoned on the taxiway.
    for x, z, length, turn in ((-128, -1332, 38, 0), (-52, -1344, 30, 180), (256, -1322, 44, 180), (172, -1340, 34, 0),
                               (432, -1340, 36, 90), (-470, -1334, 22, 35), (640, -1384, 34, 8)):
        plane(m, x, z, length, turn)
    # Maintenance: three hangars that open onto their apron, the workshops behind.
    for x, z, w, dep, h in ((-590, -1262, 82, 62, 18), (-492, -1268, 62, 50, 15), (-430, -1272, 44, 42, 12)):
        m.add_box(x, z, w, dep, h, kind="hangar", force=True)
    m.add_box(-640, -1212, 30, 20, 7, kind="shed", force=True)
    m.add_box(-412, -1228, 24, 14, 5, kind="shed", force=True)
    m.add_box(-300, -1354, 34, 18, 8, kind="building", force=True)                   # fire station, facing the taxiway
    rect(m, [-322, -1372, -278, -1364], PAVED)
    # Freight: the transit shed on the apron, the bonded store and customs on the road side.
    m.add_box(408, -1276, 132, 30, 11, kind="shed", force=True)
    m.add_box(382, -1230, 86, 30, 10, kind="shed", force=True)
    m.add_box(482, -1226, 40, 22, 13, kind="building", force=True)
    for r in range(3):
        for c in range(4):
            if (r + c) % 4 != 3:
                m.add_box(338 + c * 3.4, -1212 + r * 3.6, 3.0, 3.2, 1.6 + 1.6 * ((r * 3 + c) % 2), kind="container%d" % ((r + c) % 4), force=True, stamp=False)
    # The fuel farm: tanks in a bund, as fuel farms are laid out, the day tanks smaller.
    rect(m, [566, -1322, 698, -1226], (140, 138, 130))
    m.gd.rectangle(m.rect_px([566, -1322, 698, -1226]), outline=(118, 116, 108), width=2)
    for x, z, size, h in ((592, -1296, 22, 13), (630, -1296, 22, 13), (666, -1298, 18, 12),
                          (586, -1252, 18, 11), (618, -1252, 18, 11), (648, -1250, 14, 9), (674, -1250, 14, 9)):
        m.shapes.append({"shape": "cylinder", "x": x, "z": z, "y": 0, "size": size, "height": h, "kind": "tank"})
        m.od.ellipse([x - size / 2 - m.X0, z - size / 2 - m.Z0, x + size / 2 - m.X0, z + size / 2 - m.Z0], fill=200)
    m.add_box(690, -1212, 12, 8, 4, kind="small", force=True)
    m.add_box(596, -1210, 26, 8, 6, kind="shed", force=True)                         # tanker loading gantry


# ---- the government precinct ------------------------------------------------------------------

def gen_plaza(m, d, rng):
    box = d["rects"][0]
    rect(m, [-102, -642, 102, -488], (166, 164, 156))
    m.od.rectangle(m.rect_px([-56, -621, 56, -509]), fill=255)
    m.shapes.append({"shape": "pyramid", "x": 0, "z": -565, "y": 0, "size": 100, "height": 62, "kind": "glass"})
    for sx in (-1, 1):                                    # the formal part: pools and tree beds, mirrored
        rect(m, [sx * 34 - 15, -506, sx * 34 + 15, -496], WATER)
        rect(m, [min(sx * 62, sx * 96), -628, max(sx * 62, sx * 96), -502], (100, 108, 78), stamp=180)
        for _ in range(26):
            tree(m, sx * rng.uniform(64, 94), rng.uniform(-626, -504), rng.uniform(0.7, 1.1))
    # North lawn and the gate on the avenue.
    rect(m, [-116, -687, 116, -664], (100, 108, 78), stamp=180)
    for _ in range(22):
        tree(m, rng.uniform(-112, 112), rng.uniform(-685, -666), rng.uniform(0.8, 1.2))
    for sx in (-1, 1):
        m.add_box(sx * 17, -674, 5, 5, 3.6, kind="small", force=True)

    # East of the square: the working quarter. One back lane, two cross lanes, and every
    # block a different job, so people come here for other things than the ministries.
    line(m, [(200, -470), (200, -689)], 7, m.STREET, block=True)
    line(m, [(124, -540), (268, -540)], 6, m.STREET, block=True)
    line(m, [(200, -622), (268, -622)], 5, m.STREET, block=True)
    for x, z, w, dep, h, kind in (
            (160, -529, 62, 13, 28, "slab"), (160, -481, 62, 13, 24, "slab"), (189, -505, 11, 34, 32, "slab"),      # a ministry round its court
            (236, -485, 40, 18, 46, "tall"), (236, -515, 56, 26, 9, "building"),                                    # hotel on its podium
            (160, -582, 56, 38, 20, "building"), (160, -652, 60, 22, 16, "slab"),                                   # courthouse, archive
            (236, -567, 44, 30, 24, "building"), (252, -584, 3, 3, 22, "mast"), (236, -604, 56, 20, 15, "carpark")):  # police, their mast, car park
        m.add_box(x, z, w, dep, h, kind=kind, force=True)
    rect(m, [132, -520, 180, -490], (100, 108, 78), stamp=180)                       # the ministry's court garden
    for _ in range(9):
        tree(m, rng.uniform(135, 178), rng.uniform(-518, -492), rng.uniform(0.6, 1.0))
    rect(m, [132, -628, 190, -606], (100, 108, 78), stamp=180)                       # the garden between court and archive
    for _ in range(10):
        tree(m, rng.uniform(134, 188), rng.uniform(-626, -608), rng.uniform(0.7, 1.1))
    rect(m, [206, -688, 266, -628], (100, 108, 78), stamp=180)                       # the civic garden and its pond
    m.gd.ellipse([224 - m.X0, -664 - m.Z0, 250 - m.X0, -648 - m.Z0], fill=WATER)
    m.add_box(256, -642, 7, 5, 3.6, rot=20, kind="timber", force=True)
    for _ in range(30):
        tx, tz = rng.uniform(208, 264), rng.uniform(-686, -630)
        if not (222 < tx < 252 and -666 < tz < -646):
            tree(m, tx, tz, rng.uniform(0.7, 1.25))
    m.spaces.append({"kind": "park", "x": 236, "z": -658, "w": 60, "d": 60, "name": "Kasumi garden"})

    # West of the square: the post office, a row of lunch places, the press building, bus bays.
    m.add_box(-146, -488, 36, 24, 12, kind="building", force=True)
    z = -508.0
    while z > -566:
        w = rng.uniform(5.5, 9.5)
        m.add_box(-131, z - w / 2, 10, w - 0.4, rng.choice([6.3, 6.9, 9.4, 9.9]), kind="shop", force=True)
        z -= w
    rect(m, [-166, -566, -138, -508], (112, 112, 114), stamp=180)                    # their yard and deliveries
    m.add_box(-146, -600, 30, 44, 22, kind="slab", force=True)
    rect(m, [-166, -686, -126, -632], (108, 108, 110), stamp=180)
    m.add_box(-146, -640, 22, 4, 3.2, kind="small", force=True)
    for x, z in ((-140, -470), (140, -466), (0, -690)):
        m.add_box(x, z, 7, 4, 3.2, kind="small", margin=0.5)


# ---- the tram depot ---------------------------------------------------------------------------

def gen_rail_depot(m, d, rng):
    # One lead comes off the loop on the tram street. Everything fans from it: the car barn's
    # four roads, the workshop's two, the open stabling roads, the wash road, the test road.
    lead = chaikin([(-222, -448), (-234, -460), (-240, -478), (-243, -560), (-246, -628)], 2)
    line(m, lead, 2, RAIL)
    ladder_z = [p[1] for p in reversed(lead)]
    ladder_x = [p[0] for p in reversed(lead)]

    def road(z, end):
        x = float(np.interp(z + 12, ladder_z, ladder_x))
        line(m, chaikin([(x, z + 12), (x - 9, z + 3), (x - 26, z), (end, z)], 2), 2, RAIL)

    groups = (((-486, -440), (-492, -440), (-498, -440), (-504, -440)),   # car barn
              ((-524, -404), (-531, -404)),                               # workshop
              ((-552, -452), (-560, -446), (-568, -430), (-576, -452)),   # stabling
              ((-600, -384),), ((-618, -456),))                           # wash road, test road
    for group in groups:
        for z, end in group:
            road(z, end)
    m.add_box(-386, -495, 108, 30, 9, kind="shed", force=True)            # car barn
    m.add_box(-372, -527.5, 64, 21, 11, kind="shed", force=True)          # workshop
    m.add_box(-332, -600, 18, 7, 6, kind="small", force=True)             # wash plant
    for x, z in ((-300, -552), (-420, -560), (-296, -568), (-388, -576), (-300, -618), (-282, -600)):
        m.add_box(x, z, 26, 2.6, 3.4, kind="tram", force=True, stamp=False)   # trams left where they stood
    # The power side: the rectifier house and its yard, east of the lead.
    patch(m, -200, -566, 40, 34, (146, 142, 132), stamp=170)
    m.add_box(-206, -570, 18, 14, 7, kind="building", force=True)
    for dx, dz in ((10, -8), (10, 2), (-2, 10)):
        m.add_box(-200 + dx, -566 + dz, 4.5, 3.5, 4, kind="small", force=True)
    # The gate on the tram street: offices, the crew canteen, the signal box over the junction.
    m.add_box(-198, -474, 40, 12, 12, kind="building", force=True)
    m.add_box(-196, -500, 22, 12, 5, kind="building", force=True)
    m.add_box(-226, -470, 5, 5, 14, kind="landmark", force=True)
    # The edges belong to the town. North: the railwaymen's terrace and the bathhouse.
    x = -452.0
    while x < -262:
        w = rng.uniform(8.5, 12.5)
        if not -372 < x < -352:                                           # the lane through to the yard
            m.add_box(x + w / 2, -680, w - 0.5, 8, rng.choice([5.8, 6.2, 6.6]), kind="house", force=True)
        x += w
    m.add_box(-238, -676, 16, 14, 7, kind="building", force=True)
    m.add_box(-230, -668, 1.6, 1.6, 18, kind="mast", force=True, stamp=False)
    # West: the union hall and the staff car park on the outer ring.
    m.add_box(-454, -588, 22, 16, 8, kind="building", force=True)
    rect(m, [-466, -664, -440, -606], (108, 108, 110), stamp=180)
    # South: lock-up shops and eating places along the tram street, backs to the car barn.
    x = -442.0
    while x < -266:
        w = rng.uniform(5.0, 9.5)
        if not -318 < x < -306:
            m.add_box(x + w / 2, -464, w - 0.4, 9, rng.choice([3.8, 4.4, 6.6, 7.0]), kind="shop", force=True)
        x += w


# ---- the park's paths ---------------------------------------------------------------------------

def gen_park(m, d, rng):
    water = m.PLAN["water"]["lake"]
    cx, cz = water["center"]
    rx, rz = water["radii"]
    shore = [(cx + math.cos(a) * (rx + 13 + 5 * math.sin(a * 2 + 0.6)), cz + math.sin(a) * (rz + 12 + 4 * math.cos(a * 3))) for a in np.linspace(0, math.tau, 49)]
    line(m, shore, 3, m.PATH, block=True)
    for gate in ([(0, -184), (6, -120), (28, -72), shore[36]], [(-224, 0), (-150, 8), (-100, 26), shore[24]],
                 [(224, 24), (180, 30), shore[0]], [(0, 184), (10, 130), shore[12]],
                 [(-216, -112), (-158, -64), (-128, 8), (-166, 100), (-92, 168)], [(150, -176), (166, -110), (140, -52)]):
        line(m, chaikin(gate, 3), 3, m.PATH, block=True)
    m.scatter_trees(d["rects"][0], rng, 9.0, 0.62, holes=[(cx, cz, 108), (-150, 100, 34), (150, -110, 30)])


GENERATORS = {"valley": gen_valley, "forest": gen_forest, "foothills": gen_foothills, "dam": gen_dam, "approach": gen_approach,
              "fringe": gen_fringe, "airport": gen_airport, "plaza": gen_plaza, "rail_depot": gen_rail_depot, "park": gen_park}
