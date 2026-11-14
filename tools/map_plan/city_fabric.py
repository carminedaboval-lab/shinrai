"""The lived-in city of Map 1: how the land between the planned roads fills in.

A real town plan is a patchwork with causes, and this module follows the causes:

1.  The roads in the plan file cut the city into TRACTS. A tract is one piece of land with
    roads all round it.
2.  Each tract lays its own streets square to the most important road beside it (the ring
    road at the park, the old highway, an avenue), so neighbouring tracts sit at different
    angles and meet at seams, exactly where the older road runs.
3.  Streets are narrow and blocks are long and thin (two house plots deep), with cross
    streets that do not line up from one row to the next, and the odd dead end.
4.  Buildings stand on plots along a street and face it. What they are depends on the
    street: tall along avenues, shop-houses along the old highway, houses on back streets.
5.  The shrine hill has no grid at all: lanes follow the slope in broken rings, steps climb
    it, the approach runs up from the torii, temples sit at its foot.
6.  Whatever land is left over becomes what it becomes in a real town: a car park, a
    vegetable plot, a clump of trees, a tiny shrine, a children's park.

Called by build_map1_blockout.py with that module as `m` (it owns the ground picture, the
occupancy mask and the lists of boxes and trees).
"""
import bisect
import math
import random

import numpy as np
from PIL import Image, ImageDraw

STREET_LOCAL = (88, 88, 90)
ALLEY = (96, 94, 92)
LANE = (108, 102, 90)
PARKING = (112, 112, 114)
VEG = (122, 116, 84)
GARDEN = (100, 110, 78)
GREEN = (98, 108, 76)
PAVING = (164, 160, 150)
GRAVEL = (152, 146, 130)
CEMETERY = (138, 136, 130)
ROOF_ROOM = 1.0    # metres added to a low house's box so its roof can be a tiled pitch, not a flat sheet

PRIORITY = {"ring": 0, "arterial": 1, "old": 2, "grid": 3, "collector": 4, "local": 5, "alley": 6, "lane": 7}
ORIENT_WEIGHT = {"ring": 3.0, "grid": 2.2, "old": 1.7, "arterial": 1.2, "collector": 1.0}
PAVEMENT = {"ring": 3.0, "grid": 3.0, "arterial": 3.2, "collector": 2.0, "old": 1.5, "local": 1.5, "alley": 1.3, "lane": 1.3}

# Per neighbourhood type: how far apart its streets are, how long its blocks, how wide its streets.
TRACT = {
    "homes": dict(depth=(29.0, 35.0), block=(62.0, 108.0), street=(4.6, 5.4), cross=(4.2, 5.0)),
    "old_res": dict(depth=(25.0, 30.0), block=(48.0, 82.0), street=(4.0, 4.6), cross=(3.4, 4.2)),
    "shops": dict(depth=(33.0, 39.0), block=(44.0, 72.0), street=(6.0, 7.0), cross=(5.0, 6.0)),
    "nightlife": dict(depth=(23.0, 27.5), block=(30.0, 48.0), street=(4.6, 5.4), cross=(2.6, 3.4)),
}


def dense(points, step):
    out = [tuple(points[0])]
    for a, b in zip(points, points[1:]):
        count = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / step))
        for i in range(1, count + 1):
            out.append((a[0] + (b[0] - a[0]) * i / count, a[1] + (b[1] - a[1]) * i / count))
    return out


def chaikin(points, rounds=3):
    """Rounds the corners of a hand-drawn line, keeping its ends."""
    pts = [tuple(p) for p in points]
    for _ in range(rounds):
        out = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            out.append((a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25))
            out.append((a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75))
        out.append(pts[-1])
        pts = out
    return pts


class Path:
    def __init__(self, points):
        self.pts = [tuple(p) for p in points]
        self.cum = [0.0]
        for a, b in zip(self.pts, self.pts[1:]):
            self.cum.append(self.cum[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
        self.length = self.cum[-1]

    def at(self, s):
        s = min(max(s, 0.0), self.length)
        i = min(max(bisect.bisect_right(self.cum, s) - 1, 0), len(self.pts) - 2)
        a, b = self.pts[i], self.pts[i + 1]
        seg = (self.cum[i + 1] - self.cum[i]) or 1e-6
        t = (s - self.cum[i]) / seg
        return a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, (b[0] - a[0]) / seg, (b[1] - a[1]) / seg


class City:
    def __init__(self, m):
        self.m = m
        self.plan = m.PLAN
        self.city = m.PLAN["city"]
        self.X0, self.Z0, self.W, self.H = m.X0, m.Z0, m.W, m.H
        self.rng = random.Random(m.SEED + 4040)
        self.streets = []   # {"path", "w", "cls", "type", "mod"}
        self.stats = {"tracts": 0, "local_streets": 0, "buildings": 0, "pockets": {}}
        self.mid_rise = {5: 0, 6: 0, 7: 0}
        self.chargers = []    # robot recharge stations placed so far, kept apart

    # ---- small helpers ------------------------------------------------------------------
    def pix(self, x, z):
        return int(x - self.X0), int(z - self.Z0)

    def inside(self, x, z):
        return self.X0 + 1 <= x < self.X0 + self.W - 1 and self.Z0 + 1 <= z < self.Z0 + self.H - 1

    def area_type(self, x, z):
        for area in self.city["areas"]:
            for r in area["rects"]:
                if r[0] <= x < r[2] and r[1] <= z < r[3]:
                    return area["type"]
        return "homes"

    def on_hill(self, x, z, scale=1.0):
        hill = self.city["hill"]
        return ((x - hill["x"]) / (hill["rx"] * scale)) ** 2 + ((z - hill["z"]) / (hill["rz"] * scale)) ** 2 <= 1.0

    def poly(self, cx, cz, w, d, rot):
        return [(x - self.X0, z - self.Z0) for x, z in self.m.corners(cx, cz, w, d, rot)]

    def patch(self, cx, cz, w, d, rot, colour, stamp=170):
        poly = self.poly(cx, cz, w, d, rot)
        self.m.gd.polygon(poly, fill=colour)
        if stamp:
            self.m.od.polygon(poly, fill=stamp)

    def tree(self, x, z, scale):
        if self.inside(x, z):
            self.m.trees.append([round(x, 1), round(z, 1), round(scale, 2)])

    def space(self, kind, x, z, w, d):
        self.m.spaces.append({"kind": kind, "x": round(x, 1), "z": round(z, 1), "w": round(w, 1), "d": round(d, 1)})
        self.stats["pockets"][kind] = self.stats["pockets"].get(kind, 0) + 1

    # ---- land ---------------------------------------------------------------------------
    def reserve_sites(self):
        """Marks the land that is not ordinary town: the park, the big sites, the hill."""
        site = Image.new("L", (self.W, self.H), 255)
        draw = ImageDraw.Draw(site)
        core = self.city["core"]
        draw.rectangle([core[0] - self.X0, core[1] - self.Z0, core[2] - self.X0, core[3] - self.Z0], fill=0)
        for district in self.plan["districts"]:
            if not district.get("site"):
                continue
            if district["pattern"] == "park":
                draw.rectangle([-236 - self.X0, -196 - self.Z0, 236 - self.X0, 196 - self.Z0], fill=255)
            elif "site_poly" in district:
                draw.polygon([(x - self.X0, z - self.Z0) for x, z in district["site_poly"]], fill=255)
            else:
                for r in district["rects"]:
                    draw.rectangle([r[0] - self.X0, r[1] - self.Z0, r[2] - self.X0, r[3] - self.Z0], fill=255)
        hill = self.city["hill"]
        draw.ellipse([hill["x"] - hill["rx"] - self.X0, hill["z"] - hill["rz"] - self.Z0, hill["x"] + hill["rx"] - self.X0, hill["z"] + hill["rz"] - self.Z0], fill=255)
        bay = self.plan["water"]["bay"]
        draw.polygon([(x - self.X0, z - self.Z0) for x, z in bay], fill=255)
        self.site = np.asarray(site) > 0
        self.fabric = ~self.site

    def occupied_now(self):
        return np.asarray(self.m.occupied)

    def label_tracts(self):
        free = self.fabric & (self.occupied_now() == 0)
        labels = np.zeros(free.shape, dtype=np.int32)
        parent = [0]

        def find(a):
            while parent[a] != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a

        runs = []
        prev = []
        for y in range(free.shape[0]):
            row = free[y]
            if not row.any():
                prev = []
                continue
            edges = np.diff(np.concatenate(([0], row.view(np.int8), [0])))
            starts = np.flatnonzero(edges == 1)
            ends = np.flatnonzero(edges == -1)
            cur = []
            j = 0
            for s, e in zip(starts.tolist(), ends.tolist()):
                rid = len(parent)
                parent.append(rid)
                while j < len(prev) and prev[j][1] <= s:
                    j += 1
                k = j
                while k < len(prev) and prev[k][0] < e:
                    ra, rb = find(prev[k][2]), find(rid)
                    if ra != rb:
                        parent[rb] = ra
                    k += 1
                cur.append((s, e, rid))
                runs.append((y, s, e, rid))
            prev = cur
        ids = {}
        info = {}
        for y, s, e, rid in runs:
            root = find(rid)
            if root not in ids:
                ids[root] = len(ids) + 1
                info[ids[root]] = [0, s, y, e, y]
            tid = ids[root]
            labels[y, s:e] = tid
            entry = info[tid]
            entry[0] += e - s
            entry[1] = min(entry[1], s)
            entry[2] = min(entry[2], y)
            entry[3] = max(entry[3], e)
            entry[4] = max(entry[4], y + 1)
        self.labels = labels
        self.tracts = {tid: {"area": v[0], "box": (v[1], v[2], v[3], v[4])} for tid, v in info.items()}

    # ---- the roads of the plan ------------------------------------------------------------
    def register_plan_roads(self):
        for road in self.plan["roads"]:
            cls = road.get("class", "")
            if cls not in ORIENT_WEIGHT:
                continue
            self.streets.append({"path": Path(dense(road["points"], 3.0)), "w": float(road["width"]), "cls": cls, "type": None,
                                 "mod": self.rng.uniform(0.9, 1.15), "name": road["name"]})

    def orient_tracts(self):
        """Every tract squares itself to the most important road along its edge."""
        credit = {}
        for street in self.streets:
            if street["cls"] not in ORIENT_WEIGHT:
                continue   # the hill's lanes orient nothing: they follow the slope
            path, half, weight = street["path"], street["w"] / 2 + 6.0, ORIENT_WEIGHT[street["cls"]]
            s = 2.0
            while s < path.length:
                x, z, tx, tz = path.at(s)
                angle = math.atan2(tz, tx) % math.pi
                for side in (1.0, -1.0):
                    qx, qz = x - tz * side * half, z + tx * side * half
                    if not self.inside(qx, qz):
                        continue
                    px, py = self.pix(qx, qz)
                    tid = int(self.labels[py, px])
                    if tid:
                        bins = credit.setdefault(tid, {})
                        key = int(math.degrees(angle) // 4)
                        entry = bins.setdefault(key, [0.0, 0.0, 0.0])
                        entry[0] += 4.0 * weight
                        entry[1] += math.cos(2 * angle) * weight
                        entry[2] += math.sin(2 * angle) * weight
                s += 4.0
        for tid, tract in self.tracts.items():
            bins = credit.get(tid)
            if not bins:
                tract["theta"] = 0.0
                continue
            best = max(bins.values(), key=lambda e: e[0])
            tract["theta"] = 0.5 * math.atan2(best[2], best[1])

    # ---- streets inside a tract -----------------------------------------------------------
    def clip_to_tract(self, a, b, tid, occupied):
        """The stretches of the line a-b that lie in the tract, each reaching just into the
        road at its ends so the junction joins up."""
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        count = max(2, int(length))
        inside = []
        points = []
        for i in range(count + 1):
            x = a[0] + (b[0] - a[0]) * i / count
            z = a[1] + (b[1] - a[1]) * i / count
            points.append((x, z))
            if self.inside(x, z):
                px, py = self.pix(x, z)
                inside.append(1 if self.labels[py, px] == tid else (2 if occupied[py, px] == 255 else 0))
            else:
                inside.append(0)
        runs = []
        i = 0
        while i <= count:
            if inside[i] != 1:
                i += 1
                continue
            j = i
            while j + 1 <= count and inside[j + 1] == 1:
                j += 1
            if j - i >= 9:
                lo, hi = i, j
                for _ in range(9):   # reach into the bounding road
                    if lo - 1 >= 0 and inside[lo - 1] == 2:
                        lo -= 1
                    if hi + 1 <= count and inside[hi + 1] == 2:
                        hi += 1
                runs.append((points[lo], points[hi], inside[max(i - 1, 0)] == 2 or i == 0, inside[min(j + 1, count)] == 2 or j == count))
            i = j + 1
        return runs

    def lay_tract_streets(self, tid, occupied):
        tract = self.tracts[tid]
        x0, y0, x1, y1 = tract["box"]
        ys, xs = np.nonzero(self.labels[y0:y1, x0:x1] == tid)
        if len(xs) < 200:
            return
        wx = xs + x0 + self.X0 + 0.5
        wz = ys + y0 + self.Z0 + 0.5
        cx, cz = float(wx.mean()), float(wz.mean())
        ttype = self.area_type(cx, cz)
        tract["type"] = ttype
        tract["centre"] = (cx, cz)
        if self.grid_block(tid):
            self.stats["tracts"] += 1
            return
        rule = TRACT[ttype]
        theta = tract["theta"]
        ca, sa = math.cos(theta), math.sin(theta)
        u = (wx - cx) * ca + (wz - cz) * sa
        v = -(wx - cx) * sa + (wz - cz) * ca
        umin, umax = np.percentile(u, [0.5, 99.5])
        vmin, vmax = np.percentile(v, [0.5, 99.5])
        tract["uv"] = (float(umin), float(umax), float(vmin), float(vmax))
        rng = random.Random(self.m.SEED * 31 + int(cx) * 7919 + int(cz) * 104729)
        depth = rng.uniform(*rule["depth"])
        span_u, span_v = umax - umin, vmax - vmin
        if tract["area"] < 3600 or span_v < depth * 1.55:
            # One block deep: the plots along its edge roads fill it. A long one still gets
            # a lane or two across, so nobody walks 200 m round a block.
            rows = 1
        else:
            rows = max(2, int(round(span_v / depth)))
        band = span_v / rows

        def world(uu, vv):
            return (cx + uu * ca - vv * sa, cz + uu * sa + vv * ca)

        def lay(a, b, width, cls, dead=None):
            runs = self.clip_to_tract(a, b, tid, occupied)
            for index, (p, q, open_a, open_b) in enumerate(runs):
                length = math.hypot(q[0] - p[0], q[1] - p[1])
                if length < 14.0:
                    continue
                line = [(p[0] - self.X0, p[1] - self.Z0), (q[0] - self.X0, q[1] - self.Z0)]
                self.m.gd.line(line, fill=ALLEY if cls == "alley" else STREET_LOCAL, width=max(2, round(width)))
                self.m.od.line(line, fill=255, width=max(2, round(width)))
                self.streets.append({"path": Path(dense([p, q], 3.0)), "w": width, "cls": cls, "type": ttype, "mod": rng.uniform(0.86, 1.2)})
                self.stats["local_streets"] += 1
                # A planned dead end among houses ends in a turning circle (turning_circle).
                if dead == "a" and index == 0 and math.hypot(p[0] - a[0], p[1] - a[1]) < 3.0:
                    self.turning_circle(p, (p[0] - q[0], p[1] - q[1]))
                elif dead == "b" and index == len(runs) - 1 and math.hypot(q[0] - b[0], q[1] - b[1]) < 3.0:
                    self.turning_circle(q, (q[0] - p[0], q[1] - p[1]))

        # The long streets, parallel to the road the tract grew from.
        street_w = rng.uniform(*rule["street"])
        for k in range(1, rows):
            if rows >= 4 and 1 < k < rows - 1 and rng.random() < 0.08:
                continue   # two blocks never divided: a school yard, a temple, a factory once stood here
            vv = vmin + band * k + rng.uniform(-1.2, 1.2)
            a, b = world(umin - 12, vv), world(umax + 12, vv)
            dead = None
            if ttype == "homes" and span_u > 150 and rng.random() < 0.16:
                # A street that stops short: a dead end with houses round it.
                cut = rng.uniform(0.2, 0.34) * span_u
                if rng.random() < 0.5:
                    a, dead = world(umin + cut, vv), "a"
                else:
                    b, dead = world(umax - cut, vv), "b"
            lay(a, b, street_w, "local", dead)
        # The cross streets, which do not line up from one row of blocks to the next.
        cross_cls = "alley" if ttype == "nightlife" else "local"
        for k in range(rows):
            v_lo, v_hi = vmin + band * k, vmin + band * (k + 1)
            if rows == 1 and (span_u < rule["block"][1] * 1.5 or span_v < 26):
                break
            uu = umin + rng.uniform(0.45, 1.0) * rng.uniform(*rule["block"])
            while uu < umax - rule["block"][0] * 0.45:
                width = rng.uniform(*rule["cross"])
                if ttype == "homes" and rows > 1 and rng.random() < 0.13:
                    # A lane that only goes halfway in.
                    stop = v_lo + (v_hi - v_lo) * rng.uniform(0.45, 0.62)
                    lay(world(uu, v_lo - 10), world(uu, stop), width, cross_cls)
                else:
                    lay(world(uu, v_lo - 10), world(uu, v_hi + 10), width, cross_cls)
                uu += rng.uniform(*rule["block"])
        self.stats["tracts"] += 1

    # ---- the turning circle at the end of a dead-end street -------------------------------
    def turning_circle(self, end, direction):
        """Owner (2026-11-13): where a road ends among homes, it widens into a round and the
        houses stand round it. This is the cul-de-sac of planned housing estates everywhere
        (British closes and groves, American courts, the new-town estates outside Tokyo):
        a circle about 18 m across, so a fire engine or a refuse lorry can turn without
        reversing, five houses fanned round it on wedge-shaped plots, and on some a planted
        island in the middle. It only happens where the estate was planned that way: an old
        lane that simply stops stays a plain dead end."""
        m = self.m
        length = math.hypot(direction[0], direction[1]) or 1.0
        tx, tz = direction[0] / length, direction[1] / length
        cx, cz = end
        radius = 9.0
        occupied = np.asarray(m.occupied)

        def turned(angle):
            c, s = math.cos(math.radians(angle)), math.sin(math.radians(angle))
            return tx * c - tz * s, tx * s + tz * c

        # Is there land for the houses all the way round? Otherwise it stays a plain dead end.
        for angle in (-120, -90, -60, -30, 0, 30, 60, 90, 120):
            rx, rz = turned(angle)
            for reach in (radius + 5.0, radius + 11.0):
                x, z = cx + rx * reach, cz + rz * reach
                if not self.land_at(x, z) or occupied[self.pix(x, z)[1], self.pix(x, z)[0]] > 0:
                    return
        box = [cx - radius - self.X0, cz - radius - self.Z0, cx + radius - self.X0, cz + radius - self.Z0]
        m.gd.ellipse(box, fill=STREET_LOCAL)
        m.od.ellipse(box, fill=255)
        count = self.stats["pockets"].get("turning circle", 0)
        if count % 2 == 0:      # every other one has a planted island
            m.gd.ellipse([cx - 2.6 - self.X0, cz - 2.6 - self.Z0, cx + 2.6 - self.X0, cz + 2.6 - self.Z0], fill=GREEN)
            self.tree(cx, cz, 0.9)
        widths = (8.6, 9.4, 8.2, 9.0, 8.8)
        floors = (2, 2, 1, 2, 2)
        for k, angle in enumerate((-112, -56, 0, 56, 112)):
            rx, rz = turned(angle)
            depth = 7.6
            off = radius + 2.4 + depth / 2
            pick = (k + count) % 5
            if m.add_box(cx + rx * off, cz + rz * off, widths[pick], depth, floors[pick] * 2.9 + 0.6 + ROOF_ROOM, rot=math.degrees(math.atan2(rx, rz)), kind="house", margin=0.2):
                self.stats["buildings"] += 1
        for angle in (-84, -28, 28, 84):    # a tree in each wedge of garden between the houses
            rx, rz = turned(angle)
            self.tree(cx + rx * (radius + 8.5), cz + rz * (radius + 8.5), 0.7 + 0.1 * ((count + angle) % 3))
        # No later street may cut through the circle or its houses.
        px, py = self.pix(cx, cz)
        keep = int(radius + 15)
        yy, xx = np.ogrid[max(py - keep, 0):py + keep + 1, max(px - keep, 0):px + keep + 1]
        self.labels[max(py - keep, 0):py + keep + 1, max(px - keep, 0):px + keep + 1][(xx - px) ** 2 + (yy - py) ** 2 <= keep * keep] = 0
        self.space("turning circle", cx, cz, radius * 2, radius * 2)

    # ---- fewer mid-rise buildings ---------------------------------------------------------
    # Owner's rule (2026-11-13): buildings of 5, 6 and 7 floors were about as common as each
    # other, which made too many big interiors. Now the taller, the rarer: of every ten that
    # would have had 5 floors six keep them, of 6 floors four, of 7 floors three. The rest are
    # not built at all: the plot is left open, which gives the town room to breathe.
    # Nothing else changes: same plots, same streets, every other height as it was. No dice
    # are thrown here, so the rest of the town comes out as before.
    KEEP_MID_RISE = {5: (0, 2, 3, 5, 7, 8), 6: (1, 4, 6, 9), 7: (0, 4, 7)}

    def thin_mid_rise(self, floors):
        if floors not in self.KEEP_MID_RISE:
            return floors
        n = self.mid_rise[floors]
        self.mid_rise[floors] = n + 1
        if n % 10 in self.KEEP_MID_RISE[floors]:
            return floors
        return 0        # not built: the plot is left open (open_plot)

    # What a plot becomes when its building is not built. Taken in turn, never at random, so
    # the same kind never comes twice running. On a busy street: the coin car park every
    # Tokyo street has where a building came down, a paved corner with a tree, a pocket park,
    # a bicycle park. On a quiet street: a pocket park, a garden, a few parking spaces.
    BUSY_USES = ("pocket square", "charging station", "corner shop", "coin car park", "pocket park", "police box",
                 "cafe terrace", "empty lot", "market stalls", "billboard", "street shrine", "vending corner",
                 "pocket park", "charging station", "bicycle park", "public toilet", "workshop", "playground")
    QUIET_USES = ("pocket park", "garden", "corner shop", "coin car park", "empty lot", "street shrine", "playground", "vending corner")
    CHARGER_SPACING = 150.0

    def charger(self, cx, cz, w, d, turn, n, why):
        """A robot recharge station: upright bays on a white plinth, softly lit, with a tall
        marker post so it is seen from far off. `turn` points its back away from the public."""
        m = self.m
        a = math.radians(turn)
        ca, sa = math.cos(a), math.sin(a)

        def at(lx, lz):
            return cx + lx * ca + lz * sa, cz - lx * sa + lz * ca

        self.patch(cx, cz, w, d, turn, (214, 216, 218), stamp=180)
        bays = 2 + n % 4
        robots = 0
        m.add_box(*at(0.0, d * 0.22), bays * 1.7 + 0.8, 2.4, 0.22, rot=turn, kind="charger", force=True, stamp=False)
        for k in range(bays):
            lx = (k - (bays - 1) / 2) * 1.7
            m.add_box(*at(lx, d * 0.3), 1.15, 0.34, 2.7, rot=turn, y=0.22, kind="charger", force=True, stamp=False)
            m.add_box(*at(lx, d * 0.3 - 0.2), 0.95, 0.07, 0.09, rot=turn, y=2.72, kind="charger_light", force=True, stamp=False)
            if (n + k) % 3 != 0:      # a bay is not always in use
                m.add_box(*at(lx, d * 0.3 - 0.5), 0.56, 0.4, 1.85, rot=turn, y=0.22, kind="robot", force=True, stamp=False)
                robots += 1
        m.add_box(*at(-w * 0.4, -d * 0.36), 0.4, 0.4, 5.4, rot=turn, kind="charger", force=True, stamp=False)
        m.add_box(*at(-w * 0.4, -d * 0.36), 0.55, 0.55, 0.5, rot=turn, y=5.4, kind="charger_light", force=True, stamp=False)
        self.chargers.append((cx, cz))
        m.spaces.append({"kind": "charging station", "x": round(cx, 1), "z": round(cz, 1), "w": round(w, 1), "d": round(d, 1), "bays": bays, "robots": robots, "why": why})
        self.stats["pockets"]["charging station"] = self.stats["pockets"].get("charging station", 0) + 1

    def off_road(self, cx, cz, w, d):
        """True when no part of a w x d patch round the point is on a road, a railway or water,
        and no player lands within 150 m of it."""
        if any(math.hypot(cx - drop["x"], cz - drop["z"]) < 150.0 for drop in self.plan["drops"]):
            return False
        occupied = self.m.occupied
        half = max(w, d) / 2
        for dx in (-half, -half / 2, 0.0, half / 2, half):
            for dz in (-half, -half / 2, 0.0, half / 2, half):
                if not self.inside(cx + dx, cz + dz) or occupied.getpixel(self.pix(cx + dx, cz + dz)) == 255:
                    return False
        return True

    def place_chargers(self):
        """Where a city would really put robot recharge stations (owner, 2026-11-13): safe and
        easy for the public to reach, and no nuisance to anyone.

        *  Where the public already gathers and there is power and light: the tram stops.
        *  On ground nobody else wants: under the expressway, in public car parks.
        *  At the gates of the big public sites the robots serve.
        *  On a main street only where a plot is free and the pavement is wide (open_plot).
        *  Never on a quiet house street (the hum at night), never by a school, a playground
           or a shrine, never blocking a pavement or a shop front, never closer than 150 m
           to another one.
        """
        m = self.m
        n = 0
        for station in self.plan["stations"][:9]:
            sx, sz = station["x"], station["z"]
            cx, cz = m.station_square(station)
            ox, oz = (cx - sx), (cz - sz)
            length = math.hypot(ox, oz) or 1.0
            ox, oz = ox / length, oz / length
            # Never on a carriageway: the far side of the square first, then either end of it,
            # then further back. A stop with no safe spot gets no station.
            for bx, bz in ((ox * 8.0, oz * 8.0), (-oz * 12.0 + ox * 3.0, ox * 12.0 + oz * 3.0), (oz * 12.0 + ox * 3.0, -ox * 12.0 + oz * 3.0), (ox * 19.0, oz * 19.0)):
                if self.off_road(cx + bx, cz + bz, 12.0, 7.0):
                    self.charger(cx + bx, cz + bz, 12.0, 7.0, math.degrees(math.atan2(ox, oz)), n,
                                 "At tram stop %s, at the edge of its square: where the public is, lit, and fed from the tram's power" % station["id"])
                    n += 1
                    break
        express = next(r for r in self.plan["roads"] if r["kind"] == "expressway")["points"]
        side = sorted((p for p in express if -700 <= p[1] <= 300), key=lambda p: p[1])
        for z in (-400.0, 0.0):      # between the east drop-offs, never beside one
            x = float(np.interp(z, [p[1] for p in side], [p[0] for p in side]))
            if not any(math.hypot(x - drop["x"], z - drop["z"]) < 150.0 for drop in self.plan["drops"]) and all(math.hypot(x - a, z - b) >= self.CHARGER_SPACING for a, b in self.chargers):
                self.charger(x, z, 12.0, 7.0, 90.0, n, "Under the expressway: dead ground with shelter, where the hum disturbs nobody")
                n += 1
        for x, z, turn, why in ((-146, -657, -90, "The government quarter's bus bays"), (-545, 98, 90, "The hospital car park, beside the ambulance road"),
                                (360, 150, 0, "The mall's open car park"), (-296, 612, 90, "The stadium gates, on the concourse"),
                                (72, 744, 90, "The port gate, beside the gate road"), (-140, -1152, 180, "The airport forecourt, by the long-stay car park")
                                ):
            if self.off_road(x, z, 12.0, 7.0) and all(math.hypot(x - a, z - b) >= self.CHARGER_SPACING for a, b in self.chargers):
                self.charger(x, z, 12.0, 7.0, turn, n, why)
                n += 1

    FUEL_PLOT = (28.0, 22.0)      # along the road, back from it
    FUEL_APART = 700.0
    FUEL_MOST = 6
    FORECOURT = (150, 150, 146)

    def place_fuel(self):
        """Petrol stations (owner, 2026-11-14: the homes had none). Where a town puts them:

        *  Only on the big roads (the ring and the avenues), where cars pass and a tanker can
           turn in. Never on a homes lane, never in the shopping or nightlife streets.
        *  On a corner plot where one big road meets another street, for the two ways in.
        *  Few and far apart (FUEL_APART), so each is a landmark to steer by.
        *  On level ground, 150 m or more from where players land, and 80 m or more from a
           robot recharge station (fuel and high-voltage chargers are kept apart).

        The plot is kept free before the streets are filled, and handed to the game as
        m.fuel_stations: id, x, z, yaw (the station's own +Z faces the road), w, d, road, why."""
        m = self.m
        w, d = self.FUEL_PLOT
        found = []
        for street in self.streets:
            if street["cls"] not in ("ring", "arterial"):
                continue
            path = street["path"]
            s = 20.0
            while s < path.length - 20.0:
                x, z, tx, tz = path.at(s)
                for side in (1.0, -1.0):
                    nx, nz = -tz * side, tx * side
                    off = street["w"] / 2 + 1.0 + d / 2
                    cx, cz = x + nx * off, z + nz * off
                    turn = -math.degrees(math.atan2(tz, tx))
                    corners = [(cx + tx * a * w / 2 + nx * b * d / 2, cz + tz * a * w / 2 + nz * b * d / 2) for a in (-1, 1) for b in (-1, 1)]
                    if not all(self.land_at(px, pz) for px, pz in corners + [(cx, cz)]):
                        continue
                    if self.area_type(cx, cz) in ("shops", "nightlife") or self.on_hill(cx, cz, 1.1):
                        continue
                    if any(math.hypot(cx - drop["x"], cz - drop["z"]) < 150.0 for drop in self.plan["drops"]):
                        continue
                    if not m.is_free(cx, cz, w - 1.0, d - 1.0, turn, 0.5):
                        continue
                    if any(math.hypot(cx - a, cz - b) < 80.0 for a, b in self.chargers):
                        continue
                    heights = [m.TERRAIN.at(px, pz) for px, pz in corners]
                    if max(heights) - min(heights) > 0.35:
                        continue
                    # A corner plot: another street meets this one within 45 m along it.
                    crossing = min((abs(s - other) for other in self.crossings_on(street)), default=1e9)
                    found.append({"x": cx, "z": cz, "turn": turn, "yaw": math.degrees(math.atan2(-nx, -nz)), "road": street.get("name", street["cls"]),
                                  "corner": crossing <= 45.0, "homes": self.area_type(cx, cz) in ("homes", "old_res"), "s": s})
                s += 6.0
        chosen = []
        for apart in (self.FUEL_APART, 560.0, 450.0):      # as far apart as the land allows, till there are five
            for want_corner in (True, False):
                for plot in found:
                    if len(chosen) >= self.FUEL_MOST:
                        break
                    if plot["corner"] != want_corner or not plot["homes"]:
                        continue
                    if any(math.hypot(plot["x"] - c["x"], plot["z"] - c["z"]) < apart for c in chosen):
                        continue
                    if not m.is_free(plot["x"], plot["z"], w - 1.0, d - 1.0, plot["turn"], 0.5):
                        continue
                    self.patch(plot["x"], plot["z"], w, d, plot["turn"], self.FORECOURT, stamp=180)
                    self.space("petrol station", plot["x"], plot["z"], w, d)
                    chosen.append(plot)
            if len(chosen) >= 5:
                break
        m.fuel_stations = [{"id": "Fuel %d" % (i + 1), "x": round(c["x"], 2), "z": round(c["z"], 2), "yaw": round(c["yaw"], 1), "w": w, "d": d, "road": c["road"],
                            "why": "on %s, %s, among homes; %d m or more from the next station" % (c["road"], "a corner plot" if c["corner"] else "a plot along the road", round(min((math.hypot(c["x"] - o["x"], c["z"] - o["z"]) for o in chosen if o is not c), default=0)))}
                           for i, c in enumerate(chosen)]
        self.stats["fuel"] = {"candidates": len(found), "corner": sum(1 for f in found if f["corner"]), "homes": sum(1 for f in found if f["homes"]), "placed": len(chosen)}
        print("petrol stations: %s" % self.stats["fuel"])

    def crossings_on(self, street):
        """How far along a street each other plan road meets it (found once a street)."""
        if "_crossings" not in street:
            path = street["path"]
            marks = []
            for other in self.streets:
                if other is street:
                    continue
                for ox, oz in other["path"].pts[::2]:
                    s = 0.0
                    while s <= path.length:
                        x, z = path.at(s)[:2]
                        if math.hypot(x - ox, z - oz) < 8.0:
                            marks.append(s)
                            break
                        s += 6.0
            street["_crossings"] = marks
        return street["_crossings"]

    def open_plot(self, cx, cz, w, d, turn, busy, wide=False):
        """What stands on a plot whose tall building was not built. It need not be open ground
        (owner, 2026-11-13): anything that gives the street character, never the same twice
        running. Some are small buildings, some are places, a few are robot recharge stations."""
        uses = self.BUSY_USES if busy else self.QUIET_USES
        n = self.stats["pockets"].get("opened plot", 0)
        self.stats["pockets"]["opened plot"] = n + 1
        use = uses[n % len(uses)]
        if use == "charging station":
            school = next(d_["rects"][0] for d_ in self.plan["districts"] if d_["pattern"] == "school")
            near_school = school[0] - 70 < cx < school[2] + 70 and school[1] - 70 < cz < school[3] + 70
            near_drop = any(math.hypot(cx - drop["x"], cz - drop["z"]) < 150.0 for drop in self.plan["drops"])
            if not wide or near_school or near_drop or self.on_hill(cx, cz, 1.1) or any(math.hypot(cx - sx, cz - sz) < self.CHARGER_SPACING for sx, sz in self.chargers):
                # No station here (too near another, a narrow street, a school, the shrine
                # hill): something else, taken in turn.
                spare = ("pocket park", "corner shop", "empty lot", "pocket square", "workshop", "garden")
                self.spare_turn = getattr(self, "spare_turn", -1) + 1
                use = spare[self.spare_turn % len(spare)]
        a = math.radians(turn)
        ca, sa = math.cos(a), math.sin(a)
        m = self.m

        def at(lx, lz):
            return cx + lx * ca + lz * sa, cz - lx * sa + lz * ca

        if use == "charging station":
            self.charger(cx, cz, w, d, turn, n, "A free plot on a main street the robots patrol: wide pavement, set back from the road, no homes facing it")
            return
        if use == "corner shop":          # one floor, a shop like any other, lower than its neighbours
            self.patch(cx, cz, w, d, turn, PAVING, stamp=0)
            if m.add_box(*at(0.0, d * 0.1), w * 0.86, d * 0.72, 3.7, rot=turn, kind="shop", force=True):
                self.stats["buildings"] += 1
            return
        if use == "police box":           # a koban: two small floors behind a paved forecourt
            self.patch(cx, cz, w, d, turn, PAVING, stamp=180)
            if m.add_box(*at(-w * 0.12, d * 0.16), min(w * 0.55, 7.0), min(d * 0.5, 6.0), 6.3, rot=turn, kind="building", force=True):
                self.stats["buildings"] += 1
            m.add_box(*at(w * 0.34, -d * 0.3), 0.25, 0.25, 4.2, rot=turn, kind="mast", force=True, stamp=False)
            self.space(use, cx, cz, w, d)
            return
        if use == "workshop":             # a one-floor garage with its yard in front
            self.patch(cx, cz, w, d, turn, PARKING, stamp=0)
            m.add_box(*at(0.0, d * 0.18), w * 0.9, d * 0.56, 4.4, rot=turn, kind="shed", force=True)
            return
        if use == "billboard":            # a sign tower over a bare plot: something to steer by
            self.patch(cx, cz, w, d, turn, (132, 128, 108), stamp=170)
            for lx in (-w * 0.3, w * 0.3):
                m.add_box(*at(lx, d * 0.25), 0.5, 0.5, 9.0, rot=turn, kind="mast", force=True, stamp=False)
            m.add_box(*at(0.0, d * 0.25), w * 0.86, 0.5, 5.2 + n % 3, rot=turn, y=9.0, kind="landmark", force=True, stamp=False)
            self.space(use, cx, cz, w, d)
            return
        if use == "vending corner":       # a row of machines under a roof, lit all night
            self.patch(cx, cz, w, d, turn, PAVING, stamp=180)
            count = 3 + n % 3
            for k in range(count):
                m.add_box(*at((k - (count - 1) / 2) * 1.15, d * 0.3), 1.0, 0.8, 1.9, rot=turn, kind="small", force=True, stamp=False)
            m.add_box(*at(0.0, d * 0.27), count * 1.15 + 0.8, 1.6, 0.2, rot=turn, y=2.4, kind="small", force=True, stamp=False)
            self.space(use, cx, cz, w, d)
            return
        if use == "public toilet":        # the small public block with phone booths beside it
            self.patch(cx, cz, w, d, turn, PAVING, stamp=180)
            m.add_box(*at(-w * 0.15, d * 0.2), min(w * 0.5, 6.0), min(d * 0.4, 4.0), 3.1, rot=turn, kind="small", force=True, stamp=False)
            for k in range(2 + n % 2):
                m.add_box(*at(w * 0.3, -d * 0.3 + k * 1.3), 0.9, 0.9, 2.2, rot=turn, kind="small", force=True, stamp=False)
            self.space(use, cx, cz, w, d)
            return
        if use == "playground":           # sand, a slide, swings, a bench under a tree
            self.patch(cx, cz, w, d, turn, (176, 164, 132), stamp=180)
            m.add_box(*at(-w * 0.2, -d * 0.15), 3.2, 1.0, 2.2, rot=turn + 30, kind="small", force=True, stamp=False)
            m.add_box(*at(w * 0.22, d * 0.1), 2.6, 0.3, 2.3, rot=turn, kind="small", force=True, stamp=False)
            m.add_box(*at(w * 0.1, -d * 0.34), 1.8, 0.5, 0.5, rot=turn, kind="small", force=True, stamp=False)
            self.tree(*at(-w * 0.34, d * 0.3), 0.8)
            self.tree(*at(w * 0.36, -d * 0.3), 0.65)
            self.space(use, cx, cz, w, d)
            return
        if use == "pocket square":
            self.patch(cx, cz, w, d, turn, PAVING, stamp=180)
            for lx, lz in ((-w * 0.26, d * 0.2), (w * 0.24, -d * 0.18)):
                self.tree(*at(lx, lz), 0.7 + 0.15 * (n % 3))
            self.m.add_box(*at(w * 0.1, d * 0.3), 2.2, 0.6, 0.5, rot=turn, kind="small", force=True, stamp=False)    # a bench
        elif use == "pocket park":
            self.patch(cx, cz, w, d, turn, GREEN, stamp=180)
            for k, (lx, lz) in enumerate(((-w * 0.3, -d * 0.25), (w * 0.1, d * 0.28), (w * 0.3, -d * 0.1), (-w * 0.1, d * 0.05))):
                self.tree(*at(lx, lz), 0.65 + 0.12 * ((n + k) % 4))
            self.m.add_box(*at(-w * 0.12, -d * 0.3), 1.8, 1.8, 1.6, rot=turn + 20, kind="small", force=True, stamp=False)   # a climbing frame
        elif use == "garden":
            self.patch(cx, cz, w, d, turn, GARDEN, stamp=170)
            for k, (lx, lz) in enumerate(((-w * 0.25, d * 0.2), (w * 0.22, -d * 0.2), (0.0, 0.0))):
                self.tree(*at(lx, lz), 0.6 + 0.15 * ((n + k) % 3))
        elif use == "empty lot":          # the building came down and nothing came after: weeds and rubble
            self.patch(cx, cz, w, d, turn, (132, 128, 108), stamp=170)
            self.m.add_box(*at(w * 0.2, -d * 0.25), 2.6, 1.8, 0.7, rot=turn + 25, kind="small", force=True, stamp=False)
            self.tree(*at(-w * 0.28, d * 0.3), 0.55)
        elif use == "cafe terrace":       # tables under an awning, belonging to the shop next door
            self.patch(cx, cz, w, d, turn, PAVING, stamp=180)
            self.m.add_box(*at(0.0, d * 0.3), w * 0.8, 2.6, 0.25, rot=turn, y=2.6, kind="small", force=True, stamp=False)
            for lx, lz in ((-w * 0.25, -d * 0.1), (w * 0.05, -d * 0.25), (w * 0.28, 0.05 * d)):
                self.m.add_box(*at(lx, lz), 0.9, 0.9, 0.75, rot=turn, kind="small", force=True, stamp=False)
        elif use == "market stalls":      # three stalls of different lengths round a paved yard
            self.patch(cx, cz, w, d, turn, PAVING, stamp=180)
            for lx, lz, long, spin in ((-w * 0.28, -d * 0.2, 3.4, 90), (w * 0.2, -d * 0.3, 2.6, 0), (w * 0.26, d * 0.22, 4.0, 90)):
                self.m.add_box(*at(lx, lz), long, 1.8, 2.5, rot=turn + spin, kind="small", force=True, stamp=False)
        elif use == "street shrine":      # a small shrine in its own trees
            self.patch(cx, cz, w, d, turn, GRAVEL, stamp=180)
            self.m.add_box(*at(0.0, -d * 0.2), 2.8, 2.2, 3.2, rot=turn, kind="landmark", force=True, stamp=False)
            for lx in (-1.3, 1.3):
                self.m.add_box(*at(lx, d * 0.3), 0.3, 0.3, 3.0, rot=turn, kind="mast", force=True, stamp=False)
            for k, (lx, lz) in enumerate(((-w * 0.32, -d * 0.2), (w * 0.32, -d * 0.1), (-w * 0.25, d * 0.2))):
                self.tree(*at(lx, lz), 0.7 + 0.15 * ((n + k) % 3))
        elif use == "bicycle park":
            self.patch(cx, cz, w, d, turn, GRAVEL, stamp=170)
            self.m.add_box(*at(0.0, d * 0.25), w * 0.7, 1.4, 2.2, rot=turn, kind="small", force=True, stamp=False)       # the shelter
        else:
            self.patch(cx, cz, w, d, turn, PARKING, stamp=170)
            self.m.add_box(*at(-w * 0.38, -d * 0.36), 0.8, 0.8, 2.4, rot=turn, kind="small", force=True, stamp=False)    # the pay machine
        self.space(use, cx, cz, w, d)

    # ---- the built grid north of the park ---------------------------------------------------
    def grid_block(self, tid):
        """Kitamachi's blocks are all the same size (the grid is built), so what stands on
        each one must differ: a block ringed with buildings, one cut by a passage, one taken
        by a department store, a school, a car park, a little park."""
        tract = self.tracts[tid]
        x0, y0, x1, y1 = tract["box"]
        if not (1700 <= tract["area"] <= 3400 and x1 - x0 < 62 and y1 - y0 < 62):
            return False
        cx, cz = (x0 + x1) / 2 + self.X0, (y0 + y1) / 2 + self.Z0
        if not (-256 < cx < 256 and -448 < cz < -196):
            return False
        m = self.m
        rng = random.Random(self.m.SEED + int(cx) * 131 + int(cz) * 977)
        half = min(x1 - x0, y1 - y0) / 2 - 3.2    # behind the pavement
        roll = rng.random()
        corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]

        def corner_building(sx, sz):
            w, d = rng.uniform(11, 16), rng.uniform(11, 16)
            floors = self.thin_mid_rise(rng.randint(4, 8))
            top = rng.choice([0.4, 0.9])
            bx, bz = cx + sx * (half - w / 2), cz + sz * (half - d / 2)
            if floors == 0:      # the corner is left open
                if m.is_free(bx, bz, w, d, 0.0, -0.4):
                    self.open_plot(bx, bz, w, d, 0.0, True, wide=True)
                return
            m.add_box(bx, bz, w, d, floors * 3.3 + top, kind="tall" if floors >= 6 else "building", margin=-0.4)

        if roll < 0.34:      # ringed with buildings, the corners first
            for sx, sz in corners:
                corner_building(sx, sz)
        elif roll < 0.54:    # a passage through the middle, lined with small shops
            along_x = rng.random() < 0.5
            off = rng.uniform(-7, 7)
            a, b = ((cx - half - 6, cz + off), (cx + half + 6, cz + off)) if along_x else ((cx + off, cz - half - 6), (cx + off, cz + half + 6))
            line = [(a[0] - self.X0, a[1] - self.Z0), (b[0] - self.X0, b[1] - self.Z0)]
            m.gd.line(line, fill=ALLEY, width=3)
            m.od.line(line, fill=255, width=3)
            self.streets.append({"path": Path(dense([a, b], 3.0)), "w": 3.0, "cls": "alley", "type": "shops", "mod": rng.uniform(0.8, 1.0)})
            for sx, sz in rng.sample(corners, 2):
                corner_building(sx, sz)
        elif roll < 0.64:    # one big building: a department store, an office
            w, d = rng.uniform(36, 2 * half), rng.uniform(28, 2 * half - 6)
            side = rng.choice([-1, 1])
            w = min(w, 2 * half - 1.0)
            if m.add_box(cx, cz + side * (half - d / 2), w, d, rng.randint(6, 9) * 3.6, kind="slab", margin=-0.6):
                self.patch(cx, cz - side * (half - (2 * half - d) / 2 + 0.5), 2 * half, max(3.0, 2 * half - d - 1), 0, PAVING, stamp=0)
                for _ in range(3):
                    self.tree(cx + rng.uniform(-half + 3, half - 3), cz - side * (half - 2.5), rng.uniform(0.55, 0.8))
                m.od.rectangle([cx - half - self.X0, cz - half - self.Z0, cx + half - self.X0, cz + half - self.Z0], fill=170)
        elif roll < 0.72:    # a school or a post office in its yard
            side = rng.choice(corners)
            self.patch(cx, cz, 2 * half, 2 * half, 0, (140, 134, 112), stamp=0)
            m.add_box(cx, cz + side[1] * (half - 8), 2 * half - 8, 13, 3 * 3.4, kind="building", force=True)
            m.add_box(cx + side[0] * (half - 9), cz - side[1] * (half - 14), 14, 22, 9, kind="building", force=True)
            for _ in range(7):
                self.tree(cx + rng.uniform(-half + 2, half - 2), cz - side[1] * rng.uniform(half - 6, half - 1), rng.uniform(0.6, 0.95))
            m.od.rectangle([cx - half - self.X0, cz - half - self.Z0, cx + half - self.X0, cz + half - self.Z0], fill=170)
        elif roll < 0.80:    # a multi-storey car park behind the street front
            sx, sz = rng.choice(corners)
            m.add_box(cx + sx * (half - 15), cz + sz * (half - 13), 30, 26, 15, kind="carpark", margin=-0.3)
        elif roll < 0.87:    # half the block is a small park
            side = rng.choice([-1, 1])
            self.patch(cx, cz + side * half / 2, 2 * half, half, 0, GREEN, stamp=0)
            for _ in range(14):
                self.tree(cx + rng.uniform(-half + 2, half - 2), cz + side * rng.uniform(2, half - 2), rng.uniform(0.6, 1.05))
            m.od.rectangle([cx - half - self.X0, min(cz, cz + side * half) - self.Z0, cx + half - self.X0, max(cz, cz + side * half) - self.Z0], fill=180)
            self.space("park", cx, cz + side * half / 2, 2 * half, half)
        return True

    # ---- the shrine hill ------------------------------------------------------------------
    def build_hill(self):
        m, rng = self.m, random.Random(self.m.SEED + 77)
        hill = self.city["hill"]
        hx, hz, rx, rz = hill["x"], hill["z"], hill["rx"], hill["rz"]
        lanes = []

        def ring_point(a, f, wobble):
            r = f * (1.0 + wobble[0] * math.sin(3 * a + wobble[1]) + wobble[2] * math.sin(5 * a + wobble[3]))
            return (hx + math.cos(a) * rx * r, hz + math.sin(a) * rz * r)

        # The shrine at the top, in its grove.
        shrine = next(l for l in self.plan["landmarks"] if l["kind"] == "shrine")
        sx, sz = shrine["x"], shrine["z"]
        grove = [sx - 40 - self.X0, sz - 34 - self.Z0, sx + 40 - self.X0, sz + 34 - self.Z0]
        m.gd.ellipse(grove, fill=(84, 98, 66))
        m.gd.ellipse([sx - 15 - self.X0, sz - 13 - self.Z0, sx + 15 - self.X0, sz + 13 - self.Z0], fill=GRAVEL)
        m.add_box(sx, sz - 3, 14, 10, 9.5, kind="timber", force=True)        # main hall
        m.add_box(sx, sz + 9, 9, 6, 6.0, kind="timber", force=True)          # worship hall
        for dx in (-3.2, 3.2):                                               # torii at the top of the steps
            m.add_box(sx - 12 + dx * 0.0, sz + 22 + dx, 0.5, 0.5, 5.2, kind="mast", force=True, stamp=False)
        for _ in range(170):
            a, r = rng.uniform(0, math.tau), rng.uniform(0.42, 1.0)
            self.tree(sx + math.cos(a) * 40 * r, sz + math.sin(a) * 34 * r, rng.uniform(0.9, 1.5))
        m.od.ellipse(grove, fill=180)
        self.space("shrine", sx, sz, 80, 68)
        mast = next(l for l in self.plan["landmarks"] if l["kind"] == "mast")
        m.add_box(mast["x"], mast["z"], 5, 5, mast["height"], kind="mast", force=True)
        m.add_box(mast["x"] + 9, mast["z"] + 4, 10, 7, 4, kind="small", force=True)

        # Lanes that follow the slope: broken rings round the hill.
        for f, gap_count in ((0.40, 1), (0.64, 2), (0.87, 2)):
            wobble = (rng.uniform(0.03, 0.06), rng.uniform(0, 6.28), rng.uniform(0.02, 0.04), rng.uniform(0, 6.28))
            gaps = [(rng.uniform(0, math.tau), math.radians(rng.uniform(16, 30))) for _ in range(gap_count)]
            piece = []
            for i in range(145):
                a = math.tau * i / 144
                if any(abs((a - g + math.pi) % math.tau - math.pi) < half for g, half in gaps):
                    if len(piece) > 6:
                        lanes.append(piece)
                    piece = []
                    continue
                piece.append(ring_point(a, f, wobble))
            if len(piece) > 6:
                lanes.append(piece)
        # Steps and lanes that climb it, none of them straight for long.
        angles = []
        while len(angles) < 9:
            a = rng.uniform(0, math.tau)
            if all(abs((a - b + math.pi) % math.tau - math.pi) > math.radians(27) for b in angles):
                angles.append(a)
        for a in angles:
            start = rng.choice([0.40, 0.40, 0.64])
            sway, phase = rng.uniform(0.05, 0.12), rng.uniform(0, 6.28)
            piece = []
            for i in range(13):
                f = start + (1.04 - start) * i / 12
                bend = a + sway * math.sin(phase + i * 0.55)
                piece.append((hx + math.cos(bend) * rx * f, hz + math.sin(bend) * rz * f))
            lanes.append(piece)
        # The last climb of the approach, from where the plan's road ends to the shrine gate.
        approach = next(r for r in self.plan["roads"] if r["name"] == "Shrine approach")
        end = approach["points"][-1]
        steps = [(end[0], end[1]), (end[0] + 6, end[1] - 14), (sx - 12, sz + 24)]
        m.gd.line([(x - self.X0, z - self.Z0) for x, z in steps], fill=PAVING, width=6, joint="curve")
        m.od.line([(x - self.X0, z - self.Z0) for x, z in steps], fill=255, width=6, joint="curve")

        # Temples at the foot of the hill, each with its graveyard.
        for a in (math.radians(rng.uniform(150, 175)), math.radians(rng.uniform(205, 235)), math.radians(rng.uniform(20, 55)), math.radians(rng.uniform(290, 330))):
            tx, tz = hx + math.cos(a) * rx * 0.76, hz + math.sin(a) * rz * 0.76
            turn = -math.degrees(a) + 90
            if not m.is_free(tx, tz, 44, 36, turn, 2):
                continue
            self.patch(tx, tz, 44, 36, turn, GRAVEL, stamp=0)
            ca, sa = math.cos(math.radians(turn)), math.sin(math.radians(turn))

            def local(lx, lz):
                return (tx + lx * ca + lz * sa, tz - lx * sa + lz * ca)

            hall = local(-6, -4)
            m.add_box(hall[0], hall[1], 15, 11, 9, rot=turn, kind="timber", force=True)
            gate = local(-6, 15)
            m.add_box(gate[0], gate[1], 6, 2.4, 5, rot=turn, kind="timber", force=True)
            yard = local(13, -5)
            self.patch(yard[0], yard[1], 15, 22, turn, CEMETERY, stamp=0)
            for _ in range(26):   # gravestones, scattered as they are
                g = local(13 + rng.uniform(-6.5, 6.5), -5 + rng.uniform(-10, 10))
                m.gd.point((g[0] - self.X0, g[1] - self.Z0), fill=(96, 96, 94))
            for _ in range(9):
                t = local(rng.uniform(-20, 4), rng.uniform(-16, 16))
                self.tree(t[0], t[1], rng.uniform(0.7, 1.2))
            m.od.polygon(self.poly(tx, tz, 44, 36, turn), fill=180)
            self.space("temple", tx, tz, 44, 36)

        for piece in lanes:
            line = [(x - self.X0, z - self.Z0) for x, z in piece]
            m.gd.line(line, fill=LANE, width=4, joint="curve")
            m.od.line(line, fill=255, width=4, joint="curve")
            self.streets.append({"path": Path(dense(piece, 2.5)), "w": 3.8, "cls": "lane", "type": "hill", "mod": rng.uniform(0.9, 1.15)})
        self.hill_rng = rng

    def plant_hill(self):
        """Trees, bamboo and gardens in what the houses left."""
        rng = self.hill_rng
        hill = self.city["hill"]
        for _ in range(2600):
            a, r = rng.uniform(0, math.tau), math.sqrt(rng.uniform(0.02, 1.0))
            x, z = hill["x"] + math.cos(a) * hill["rx"] * r, hill["z"] + math.sin(a) * hill["rz"] * r
            if rng.random() < 0.42:
                self.m.add_tree(x, z, rng.uniform(0.6, 1.25))

    # ---- buildings along streets ----------------------------------------------------------
    def style(self, cls, ttype, rng, centre, mod):
        """What stands on the next plot of this street: (plot, width, depth, setback, floors,
        floor height, kind, turn jitter) or (plot, None) for an empty plot."""
        if cls == "ring":
            plot = rng.uniform(7, 16) * mod
            floors = int(3 + centre * 3 + rng.uniform(0, 2.5))
            return plot, plot - rng.uniform(0.3, 0.9), rng.uniform(13, 18), 0.0, floors, 3.3, "tall" if floors >= 6 else "building", 0.0
        if cls == "grid":
            plot = rng.uniform(6, 13) * mod
            floors = rng.randint(3, 6) + (1 if rng.random() < 0.2 else 0)
            return plot, plot - rng.uniform(0.3, 0.8), rng.uniform(14, 19), 0.0, floors, 3.3, "tall" if floors >= 6 else "building", 0.0
        if cls == "arterial":
            if rng.random() < 0.05:
                return rng.uniform(12, 22), None
            if rng.random() < 0.07:
                plot = rng.uniform(26, 40)
                return plot, plot - 1.5, rng.uniform(18, 26), 1.0, int(5 + centre * 4 + rng.uniform(0, 3)), 3.5, "slab", 0.0
            plot = rng.uniform(9, 20) * mod
            floors = int(3 + centre * 4 + rng.uniform(0, 3))
            return plot, plot - rng.uniform(0.4, 1.2), rng.uniform(13, 19), rng.choice([0.0, 0.0, 1.0]), floors, 3.3, "tall" if floors >= 6 else "building", 0.0
        if cls == "old":
            if rng.random() < 0.03:
                return rng.uniform(5, 9), None
            plot = rng.uniform(4.0, 7.5) * mod
            floors = rng.choice([2, 2, 2, 3, 3, 4]) + (rng.choice([0, 1, 2]) if ttype == "nightlife" else 0)
            kind = "timber" if (ttype in ("old_res", "hill") and rng.random() < 0.55) else "shop"
            return plot, plot - rng.uniform(0.15, 0.5), rng.uniform(9, 14), 0.0, floors, 3.0, kind, 1.0
        if cls == "collector":
            if ttype == "nightlife":
                plot = rng.uniform(5, 9) * mod
                floors = rng.randint(3, 7)
                return plot, plot - rng.uniform(0.2, 0.6), rng.uniform(10, 14), 0.0, floors, 3.2, "tall" if floors >= 5 else "building", 0.0
            if ttype == "shops":
                plot = rng.uniform(5.5, 10) * mod
                return plot, plot - rng.uniform(0.3, 0.8), rng.uniform(11, 15), 0.0, rng.randint(2, 5), 3.2, "building", 0.0
            if rng.random() < 0.5:
                plot = rng.uniform(5, 8) * mod
                return plot, plot - rng.uniform(0.2, 0.6), rng.uniform(9, 12), 0.0, rng.choice([2, 2, 3]), 3.0, "shop", 1.0
            plot = rng.uniform(9, 14) * mod
            return plot, plot - rng.uniform(1.2, 2.6), rng.uniform(8, 10), rng.uniform(1.0, 2.2), rng.choice([2, 2, 3]), 2.9, "house", 2.0
        if cls == "lane" or ttype == "old_res":
            if rng.random() < 0.07:
                return rng.uniform(6, 9), None
            plot = rng.uniform(6.5, 9.5) * mod
            return plot, plot - rng.uniform(0.8, 2.0), rng.uniform(6.0, 8.5), rng.uniform(0.4, 1.8), rng.choice([1, 2, 2]), 2.9, "timber", 5.0
        if ttype == "nightlife":
            plot = rng.uniform(4.0, 7.0) * mod
            floors = rng.choice([2, 3, 3, 4, 4, 5, 6, 7])
            return plot, plot - rng.uniform(0.15, 0.5), rng.uniform(8.0, 11.5), 0.0, floors, 3.1, "tall" if floors >= 5 else "building", 0.0
        if ttype == "shops":
            plot = rng.uniform(5.0, 9.0) * mod
            return plot, plot - rng.uniform(0.3, 0.8), rng.uniform(10, 14), 0.0, rng.randint(2, 4), 3.1, "building", 0.0
        # A house street.
        roll = rng.random()
        if roll < 0.07:
            return rng.uniform(8, 12), None
        if roll < 0.13:
            plot = rng.uniform(14, 19)   # a two-storey block of flats
            return plot, plot - 1.4, rng.uniform(7.0, 8.5), rng.uniform(1.5, 3.0), 2, 2.9, "house", 1.5
        plot = rng.uniform(8.5, 12.5) * mod
        return plot, plot - rng.uniform(1.6, 3.4), rng.uniform(7.0, 10.0), rng.uniform(1.5, 3.5), rng.choice([1, 2, 2, 2, 3]), 2.9, "house", 2.5

    def build_along(self, street):
        m, path, cls = self.m, street["path"], street["cls"]
        rng = random.Random(self.m.SEED + int(path.pts[0][0] * 13 + path.pts[0][1] * 17 + path.length * 3))
        pavement = PAVEMENT[cls]
        for side in (1.0, -1.0):
            s = rng.uniform(1.0, 4.0)
            while s < path.length - 2.5:
                x, z, tx, tz = path.at(s)
                ttype = street["type"] or ("hill" if self.on_hill(x, z) else self.area_type(x, z))
                centre = max(0.0, 1.0 - math.hypot(x, z) / 900.0)
                made = self.style(cls, "old_res" if ttype == "hill" and cls != "old" else ttype, rng, centre, street["mod"])
                plot = made[0]
                x, z, tx, tz = path.at(s + plot / 2)
                nx, nz = -tz * side, tx * side
                if made[1] is None:
                    # An empty plot: somebody parks on it, or grows vegetables.
                    depth = rng.uniform(8, 13)
                    cx, cz = x + nx * (street["w"] / 2 + pavement + depth / 2), z + nz * (street["w"] / 2 + pavement + depth / 2)
                    if self.land_at(cx, cz) and m.is_free(cx, cz, plot - 0.8, depth, -math.degrees(math.atan2(tz, tx)), -0.4):
                        self.patch(cx, cz, plot - 0.8, depth, -math.degrees(math.atan2(tz, tx)), PARKING if (rng.random() < 0.6 or cls == "arterial") else VEG)
                        self.stats["pockets"]["empty plot"] = self.stats["pockets"].get("empty plot", 0) + 1
                    s += plot
                    continue
                _, width, depth, setback, floors, floor_h, kind, jitter = made
                opened = self.thin_mid_rise(floors) == 0
                turn = -math.degrees(math.atan2(tz, tx)) + rng.uniform(-jitter, jitter)
                for shrink in (1.0, 0.72):
                    d = depth * shrink
                    off = street["w"] / 2 + pavement + setback + d / 2
                    cx, cz = x + nx * off, z + nz * off
                    if not self.land_at(cx, cz):
                        break
                    height = floors * floor_h + rng.choice([0.3, 0.6, 1.0, 1.3])
                    if kind in ("house", "timber", "shop"):
                        height += ROOF_ROOM      # room above the top floor for a real tiled pitch
                    if opened:
                        if m.is_free(cx, cz, max(2.6, width), d, turn, -0.5):
                            self.open_plot(cx, cz, max(2.6, width), d, turn, cls in ("ring", "grid", "arterial") or ttype in ("shops", "nightlife"), wide=cls in ("ring", "grid", "arterial"))
                            break
                        continue
                    # Neighbours share a wall or stand a hand's breadth apart: test the inside of
                    # the footprint, or every second plot is refused for touching the first.
                    if m.add_box(cx, cz, max(2.6, width), d, height, rot=turn, kind=kind, margin=-0.5):
                        self.stats["buildings"] += 1
                        break
                s += plot

    def land_at(self, x, z):
        if not self.inside(x, z):
            return False
        px, py = self.pix(x, z)
        return bool(self.town[py, px])

    # ---- what the leftover land becomes ---------------------------------------------------
    def deepest(self, free):
        cur = free
        depth = 0
        last = cur
        while depth < 34 and cur.any():
            last = cur
            nxt = cur.copy()
            nxt[1:, :] &= cur[:-1, :]
            nxt[:-1, :] &= cur[1:, :]
            nxt[:, 1:] &= cur[:, :-1]
            nxt[:, :-1] &= cur[:, 1:]
            nxt[0, :] = nxt[-1, :] = False
            nxt[:, 0] = nxt[:, -1] = False
            cur = nxt
            depth += 1
        ys, xs = np.nonzero(last)
        if len(xs) == 0:
            return None
        i = len(xs) // 2
        return int(xs[i]), int(ys[i]), depth

    def fill_pockets(self, tid):
        tract = self.tracts[tid]
        if "type" not in tract:
            return
        m = self.m
        x0, y0, x1, y1 = tract["box"]
        rng = random.Random(self.m.SEED + tid * 613)
        ttype = tract["type"]
        theta_deg = -math.degrees(tract["theta"])
        has_park = False
        tries = max(1, min(14, tract["area"] // 1300))
        for _ in range(int(tries)):
            occupied = np.asarray(m.occupied.crop((x0, y0, x1, y1)))
            free = (self.labels[y0:y1, x0:x1] == tid) & (occupied == 0)
            found = self.deepest(free)
            if found is None:
                break
            px, py, depth = found
            if depth < 5:
                break
            cx, cz = px + x0 + self.X0 + 0.5, py + y0 + self.Z0 + 0.5
            half = min(depth - 1.2, 17.0)
            w, d = 2 * half * rng.uniform(0.78, 1.0), 2 * half * rng.uniform(0.6, 0.92)
            roll = rng.random()
            commercial = ttype in ("shops", "nightlife")
            if not commercial and depth >= 9 and not has_park and tract["area"] > 9000 and roll < 0.8:
                # The children's park every neighbourhood has.
                self.patch(cx, cz, w, d, theta_deg, GREEN, stamp=0)
                for _ in range(int(w * d / 60) + 3):
                    a, r = rng.uniform(0, math.tau), rng.uniform(0.2, 0.95)
                    self.tree(cx + math.cos(a) * w * 0.45 * r, cz + math.sin(a) * d * 0.45 * r, rng.uniform(0.6, 1.05))
                for _ in range(rng.randint(2, 3)):
                    m.add_box(cx + rng.uniform(-w * 0.25, w * 0.25), cz + rng.uniform(-d * 0.25, d * 0.25), rng.uniform(1.4, 2.6), rng.uniform(1.4, 2.6), rng.uniform(1.2, 2.3),
                              rot=rng.uniform(0, 90), kind="small", force=True, stamp=False)
                m.od.polygon(self.poly(cx, cz, w, d, theta_deg), fill=180)
                self.space("park", cx, cz, w, d)
                has_park = True
            elif commercial and roll < 0.36 and depth >= 6:
                # A building at the back of the block, reached through a gap.
                if not m.add_box(cx, cz, w * 0.8, d * 0.8, rng.randint(2, 5) * 3.1, rot=theta_deg, kind="building", margin=0.3):
                    self.patch(cx, cz, w, d, theta_deg, PARKING)
            elif roll < (0.62 if commercial else 0.42):
                self.patch(cx, cz, w, d, theta_deg, PARKING)
                self.stats["pockets"]["car park"] = self.stats["pockets"].get("car park", 0) + 1
            elif roll < 0.58 and not commercial:
                self.patch(cx, cz, w, d, theta_deg + rng.uniform(-8, 8), VEG)
                self.stats["pockets"]["vegetable plot"] = self.stats["pockets"].get("vegetable plot", 0) + 1
            elif roll < 0.68 and depth >= 7:
                # A small shrine in its trees.
                self.patch(cx, cz, w * 0.8, d * 0.8, theta_deg, GRAVEL, stamp=0)
                m.add_box(cx, cz - d * 0.12, 3.2, 2.6, 3.4, rot=theta_deg, kind="landmark", force=True, stamp=False)
                for dx in (-1.4, 1.4):
                    m.add_box(cx + dx, cz + d * 0.3, 0.3, 0.3, 3.2, kind="mast", force=True, stamp=False)
                for _ in range(rng.randint(4, 8)):
                    self.tree(cx + rng.uniform(-w * 0.36, w * 0.36), cz + rng.uniform(-d * 0.36, d * 0.2), rng.uniform(0.7, 1.2))
                m.od.polygon(self.poly(cx, cz, w * 0.8, d * 0.8, theta_deg), fill=180)
                self.space("shrine", cx, cz, w * 0.8, d * 0.8)
            else:
                # A garden or a clump of trees nobody built on.
                self.patch(cx, cz, w, d, theta_deg + rng.uniform(-10, 10), GARDEN, stamp=0)
                for _ in range(int(w * d / 34) + 2):
                    self.tree(cx + rng.uniform(-w * 0.42, w * 0.42), cz + rng.uniform(-d * 0.42, d * 0.42), rng.uniform(0.55, 1.1))
                m.od.polygon(self.poly(cx, cz, w, d, theta_deg), fill=170)
                self.stats["pockets"]["garden"] = self.stats["pockets"].get("garden", 0) + 1

    # ---- all of it ------------------------------------------------------------------------
    def build(self):
        self.reserve_sites()
        self.town = self.fabric.copy()
        hill = self.city["hill"]
        yy, xx = np.ogrid[0:self.H, 0:self.W]
        on_hill = ((xx + self.X0 - hill["x"]) / hill["rx"]) ** 2 + ((yy + self.Z0 - hill["z"]) / hill["rz"]) ** 2 <= 1.0
        self.town |= on_hill       # houses may stand on the hill, though it is not laid out in tracts
        self.register_plan_roads()
        self.place_chargers()
        self.place_fuel()
        self.build_hill()
        self.label_tracts()
        self.orient_tracts()
        occupied = self.occupied_now().copy()
        for tid in sorted(self.tracts):
            if self.tracts[tid]["area"] >= 500:
                self.lay_tract_streets(tid, occupied)
        self.streets.sort(key=lambda s: PRIORITY[s["cls"]])
        for street in self.streets:
            self.build_along(street)
        for tid in sorted(self.tracts):
            if self.tracts[tid]["area"] >= 500:
                self.fill_pockets(tid)
        self.plant_hill()
        self.m.town_streets = self.streets     # the encounter layer walks these
        self.m.town_mask = self.fabric
        return self.stats


def build(m):
    return City(m).build()
