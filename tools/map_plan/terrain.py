"""The ground of Map 1: its real heights.

Every rise has a cause that the plan already implies:

*  The city stands on a flat coastal plain, 3 m above the bay.
*  The shrine hill is the one hill in town, which is why the shrine and the mast are on it.
*  The forest belt is a wooded ridge. That is why the city stops there, and why the west
   avenue, the tram and the highway all squeeze through one saddle.
*  West of the river the land climbs to the mountains. The valley lane runs along the foot
   of that slope, so the slope's foot bends where the lane bends. Road and rail leave
   through a side valley, where the tunnel mouth is.
*  The river comes down from the dam through a gorge, so the land beside it rises to the
   dam's crest and the reservoir sits high behind it.
*  Water lies lower than its banks: the bay, the river, the park lake and its stream.

Heights are metres above the bay. Called by build_map1_blockout.py with that module as `m`.
"""
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

CELL = 2.5            # metres between height samples in the blockout
PLAIN = 3.0
RIDGE = 20.0
WEST_SLOPE = 30.0
DAM_RISE = 66.0
DAM_CREST = 78.0
RESERVOIR = 73.0


def smooth(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def line_x_at(points, z):
    """x of a line that runs north-south, at every z."""
    ordered = sorted(points, key=lambda p: p[1])
    return np.interp(z, [p[1] for p in ordered], [p[0] for p in ordered])


def river_level(z):
    return 11.0 * np.clip((950.0 - z) / 2200.0, 0.0, 1.0)


class Terrain:
    def __init__(self, m):
        plan = m.PLAN
        self.X0, self.Z0, self.W, self.H = m.X0, m.Z0, m.W, m.H
        x = self.X0 + np.arange(self.W, dtype=np.float32) + 0.5
        z = self.Z0 + np.arange(self.H, dtype=np.float32) + 0.5
        X, Z = np.meshgrid(x, z)
        roads = {r["name"]: r for r in plan["roads"]}
        water = plan["water"]

        # The plain, and the valley floor west of the ridge, which follows the river down.
        valley = river_level(Z) + 2.0
        west = smooth((-700.0 - X) / 110.0)
        h = PLAIN * (1.0 - west) + valley * west

        # The wooded ridge under the forest belt, with the saddle the roads use.
        cross = np.cos(np.clip(np.abs(X + 790.0) / 95.0, 0.0, 1.0) * (math.pi / 2)) ** 2
        along = smooth((Z + 660.0) / 110.0) * (1.0 - smooth((Z - 800.0) / 110.0))
        saddle = 1.0 - 0.82 * np.exp(-((Z - 30.0) / 70.0) ** 2)
        h += RIDGE * cross * along * saddle

        # The mountain slope west of the valley lane, and the side valley of the tunnel.
        self.foot = line_x_at(roads["Valley lane"]["points"], z) + 10.0
        side_valley = 1.0 - 0.85 * np.exp(-((Z - 42.0) / 75.0) ** 2)
        slope = WEST_SLOPE * smooth((self.foot[:, None] - X) / 115.0) * side_valley

        # The hills the dam is built between, and the gorge the river cut through them.
        rise = DAM_RISE * smooth((-760.0 - Z) / 440.0)
        east_fall = 1.0 - smooth((X + 860.0) / 170.0)
        self.river_x = line_x_at(water["river"]["points"], z)
        downstream = smooth((Z + 1262.0) / 14.0)
        gorge = smooth((np.abs(X - self.river_x[:, None]) - 30.0) / 66.0)
        flank = rise * east_fall * (1.0 - downstream * (1.0 - gorge))
        h += np.maximum(slope, flank)

        # The reservoir behind the dam, level.
        lake = self.mask(lambda d: d.polygon(self.pts(water["reservoir"]), fill=255), 14.0) * (1.0 - downstream)
        h = h * (1.0 - lake) + RESERVOIR * lake

        # The quarry, cut into the slope down to the valley floor.
        quarry = next(l for l in plan["landmarks"] if l["kind"] == "quarry")
        qx, qz, (qw, qd) = quarry["x"], quarry["z"], quarry["size"]
        cut = self.mask(lambda d: d.ellipse([qx - qw / 2 - self.X0, qz - qd / 2 - self.Z0, qx + qw / 2 - self.X0, qz + qd / 2 - self.Z0], fill=255), 4.0)
        h = h * (1.0 - cut) + (valley + 1.0) * cut

        # The shrine hill.
        hill = plan["city"]["hill"]
        r = np.sqrt(((X - hill["x"]) / hill["rx"]) ** 2 + ((Z - hill["z"]) / hill["rz"]) ** 2)
        h += hill["height"] * np.cos(np.clip(r, 0.0, 1.0) * (math.pi / 2)) ** 2

        # Water lies below its banks. Where a road or a railway crosses, the ground stays up.
        def draw_water(d):
            for key in ("bay", "south_water"):
                d.polygon(self.pts(water[key]), fill=int(PLAIN * 60))
            d.line(self.pts(water["river"]["points"]), fill=120, width=water["river"]["width"], joint="curve")
            cx, cz = water["lake"]["center"]
            rx, rz = water["lake"]["radii"]
            d.ellipse([cx - rx - self.X0, cz - rz - self.Z0, cx + rx - self.X0, cz + rz - self.Z0], fill=72)
            d.line(self.pts(water["stream"]["points"]), fill=96, width=water["stream"]["width"] + 2, joint="curve")
            for district in plan["districts"]:
                if district["pattern"] == "island":
                    r0 = district["rects"][0]
                    d.rounded_rectangle([r0[0] - self.X0, r0[1] - self.Z0, r0[2] - self.X0, r0[3] - self.Z0], radius=60, fill=0)
            for road in plan["roads"]:
                if road["kind"] not in ("bridge", "expressway"):
                    d.line(self.pts(road["points"]), fill=0, width=round(road["width"]) + 6, joint="curve")
            for key in ("loop", "airport_branch", "mountain_line"):
                d.line(self.pts(plan["rail"][key]), fill=0, width=12, joint="curve")

        h -= self.mask(draw_water, 2.5) * (255.0 / 60.0)
        self.field = h.astype(np.float32)

        # What the blockout gets: one height every CELL metres.
        self.columns = int(self.W / CELL) + 1
        self.rows = int(self.H / CELL) + 1
        # Sampled exactly at each grid point (between pixels where need be): taking the
        # nearest pixel instead makes the spacing uneven, which shows as bands on a slope.
        fx = np.clip(np.arange(self.columns) * CELL - 0.5, 0.0, self.W - 1.001)
        fz = np.clip(np.arange(self.rows) * CELL - 0.5, 0.0, self.H - 1.001)
        ix, iz = fx.astype(int), fz.astype(int)
        tx, tz = (fx - ix)[None, :], (fz - iz)[:, None]
        f = self.field
        top = f[np.ix_(iz, ix)] * (1 - tx) + f[np.ix_(iz, ix + 1)] * tx
        bottom = f[np.ix_(iz + 1, ix)] * (1 - tx) + f[np.ix_(iz + 1, ix + 1)] * tx
        self.grid = np.ascontiguousarray(top * (1 - tz) + bottom * tz, dtype="<f4")
        gz, gx = np.gradient(self.field)
        self.steep = np.hypot(gx, gz)      # metres of rise per metre

    def pts(self, points):
        return [(x - self.X0, z - self.Z0) for x, z in points]

    def mask(self, painter, blur):
        image = Image.new("L", (self.W, self.H), 0)
        painter(ImageDraw.Draw(image))
        if blur:
            image = image.filter(ImageFilter.GaussianBlur(blur))
        return np.asarray(image, dtype=np.float32) / 255.0

    def at(self, x, z):
        """Height of the blockout's ground at a point: the same triangles Godot draws."""
        fx = min(max((x - self.X0) / CELL, 0.0), self.columns - 1.001)
        fz = min(max((z - self.Z0) / CELL, 0.0), self.rows - 1.001)
        i, j = int(fx), int(fz)
        tx, tz = fx - i, fz - j
        g = self.grid
        top = g[j, i] * (1 - tx) + g[j, i + 1] * tx
        bottom = g[j + 1, i] * (1 - tx) + g[j + 1, i + 1] * tx
        return float(top * (1 - tz) + bottom * tz)

    def slope(self, x, z):
        px = min(max(int(x - self.X0), 0), self.W - 1)
        pz = min(max(int(z - self.Z0), 0), self.H - 1)
        return float(self.steep[pz, px])

    def save(self, path):
        with open(path, "wb") as handle:
            handle.write(self.grid.tobytes())
