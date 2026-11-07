"""Level a tilted traced outline onto its barrel axis and scale it to mm.

Returns (d, y) with d = mm behind the muzzle along the bore and y = mm above it.
Usage: python tools/weapon_real/refs/level.py refs/m40a3_left.json  -> prints an SVG-ish dump
"""
import json, math, sys


def leveled(ref):
    mx, my = ref['muzzle']
    ux, uy = ref['barrel_dir']
    L = math.hypot(ux, uy)
    ux, uy = ux / L, uy / L
    nx, ny = uy, -ux  # "up" (negative image y)
    pts = ref['outline']
    raw = [((x - mx) * ux + (y - my) * uy, (x - mx) * nx + (y - my) * ny) for x, y in pts]
    span = max(p[0] for p in raw) - min(p[0] for p in raw)
    s = ref['oal_mm'] / span
    d0 = min(p[0] for p in raw)
    return [((a - d0) * s, b * s) for a, b in raw], s


if __name__ == '__main__':
    ref = json.load(open(sys.argv[1]))
    pts, s = leveled(ref)
    print('mm per px', round(s, 3))
    # Coarse silhouette table: top and bottom per 20 mm station.
    for d in range(0, int(ref['oal_mm']) + 1, 20):
        ys = []
        n = len(pts)
        for i in range(n):
            (d0, y0), (d1, y1) = pts[i], pts[(i + 1) % n]
            if (d0 - d) * (d1 - d) <= 0 and d0 != d1:
                ys.append(y0 + (d - d0) / (d1 - d0) * (y1 - y0))
        ys.sort()
        print(d, [round(v) for v in ys])
