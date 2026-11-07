"""Build parts straight from traced side-photo outlines (tools/weapon_real/refs/*.json).

A reference JSON holds closed outlines in photo pixels (muzzle to the left or
right), the photo scale, a levelling line and the bore centre. `Ref` maps them
to the weapon frame (d = mm behind the muzzle, y = mm above the bore) and to
Godot metres through the gun's own P(d, y, z).
"""
import json, math
import wr


class Ref:
    def __init__(self, path, muzzle_x, bore_y, level=None, muzzle_left=True, scale=None):
        self.data = json.load(open(path, encoding='utf-8'))
        self.s = scale or self.data['scale_px_per_mm']
        self.mx, self.by = muzzle_x, bore_y
        self.left = muzzle_left
        self.level = level  # (x0, y0, x1, y1) of a line that should be horizontal
        self.cx = muzzle_x

    def dy(self, x, y):
        if not self.level:
            return y
        x0, y0, x1, y1 = self.level
        return y - (x - x0) * (y1 - y0) / (x1 - x0)

    def mm(self, x, y):
        d = (x - self.mx) / self.s if self.left else (self.mx - x) / self.s
        return d, (self.by - self.dy(x, y)) / self.s

    def loop(self, group, name=None, index=None, area=None):
        items = self.data[group]
        if name is not None:
            items = [i for i in items if i.get('n') == name]
        if area is not None:
            items = [i for i in items if i['a'] == area]
        it = items[index or 0]
        return [self.mm(x, y) for x, y in it['p']]

    def loops(self, group, name):
        return [[self.mm(x, y) for x, y in i['p']] for i in self.data[group] if i.get('n') == name]


def clean(pts, min_step=0.25):
    """Drop near-duplicate and collinear points so bmesh faces stay valid."""
    out = []
    for p in pts:
        if not out or math.hypot(p[0] - out[-1][0], p[1] - out[-1][1]) > min_step:
            out.append(p)
    if len(out) > 2 and math.hypot(out[0][0] - out[-1][0], out[0][1] - out[-1][1]) <= min_step:
        out.pop()
    return out


def span_at(poly, d, window=None):
    """Vertical extent (ymin, ymax) of a closed outline at station d."""
    ys = []
    n = len(poly)
    for i in range(n):
        (d0, y0), (d1, y1) = poly[i], poly[(i + 1) % n]
        if (d0 - d) * (d1 - d) <= 0 and d0 != d1:
            t = (d - d0) / (d1 - d0)
            yy = y0 + t * (y1 - y0)
            if window is None or window[0] <= yy <= window[1]:
                ys.append(yy)
    return (min(ys), max(ys)) if ys else None


def _section(P, d, lo, hi, half, r, crown, top, bot, zc, n_arc=4, n_side=6):
    """One cross-section ring of a moulded part: rounded corners of radius r,
    sides that bulge by `crown` at mid-height and taper to `top`/`bot` times
    the half width. Returns Godot points, ring order consistent per call."""
    H = hi - lo

    def w(y):
        t = min(max((y - lo) / H, 0.0), 1.0)
        return half * (bot + (top - bot) * t) - crown * (1.0 - math.sin(math.pi * t))

    r = max(0.05, min(r, H / 2 - 0.05, min(w(lo), w(hi)) - 0.05))
    prof = []
    yb, yt = lo + r, hi - r
    cb, ct = w(yb) - r, w(yt) - r
    for k in range(n_arc + 1):
        a = -math.pi / 2 + math.pi / 2 * k / n_arc
        prof.append((yb + r * math.sin(a), cb + r * math.cos(a)))
    for k in range(1, n_side):
        y = yb + (yt - yb) * k / n_side
        prof.append((y, w(y)))
    for k in range(n_arc + 1):
        a = math.pi / 2 * k / n_arc
        prof.append((yt + r * math.sin(a), ct + r * math.cos(a)))
    right = [P(d, y, zc - z) for y, z in prof]
    left = [P(d, y, zc + z) for y, z in reversed(prof)]
    return right + left


def crown_loft(name, P, poly, half, r=4.0, crown=1.0, top=1.0, bot=1.0, step=2.0, margin=0.5,
               window=None, zc=0.0, d_range=None, span_fn=None):
    """Cutter that turns a flat extruded side outline into a moulded/machined
    solid: intersect the part (extruded a little wider than `half`) with it.
    The part keeps its traced silhouette; the loft gives every station a
    real cross-section (rounded edges, crowned and tapered sides) instead of
    two parallel flat walls. span_fn(d) -> (lo, hi) overrides the outline's
    own extent (e.g. to leave a mating face square by putting hi far above)."""
    poly = poly or []
    ds = [p[0] for p in poly]
    a, b = (min(ds), max(ds)) if d_range is None else d_range
    stations = set()
    d = a - 1.0
    while d <= b + 1.0:
        stations.add(round(d, 3))
        d += step
    for p in poly:
        if a <= p[0] <= b:
            stations.add(round(p[0], 3))
    # Keep stations at least 0.8 mm apart: sliver faces make the later edge
    # bevel collapse into spikes.
    kept = []
    for s in sorted(stations):
        if not kept or s - kept[-1] >= 0.8:
            kept.append(s)
    stations = kept
    spans = [span_fn(s) if span_fn else span_at(poly, s, window) for s in stations]
    # Stations just outside the outline copy the nearest real section so the
    # loft runs past the part's end faces (the slab's own ends trim it).
    valid = [i for i, sp in enumerate(spans) if sp]
    for i in range(len(spans)):
        if spans[i] is None:
            j = min(valid, key=lambda v: abs(v - i))
            spans[i] = spans[j]
    rings = []
    for s, (lo, hi) in zip(stations, spans):
        if hi - lo < 0.3:
            lo, hi = lo - 0.2, hi + 0.2
        rings.append(_section(P, s, lo - margin, hi + margin, half, r, crown, top, bot, zc))
    return wr.loft(name, rings, None)


def section_half(lo, hi, half, y, r=4.0, crown=1.0, top=1.0, bot=1.0, margin=0.5):
    """|z| of a crown_loft side at height y (for seating parts on the surface)."""
    lo, hi = lo - margin, hi + margin
    t = min(max((y - lo) / (hi - lo), 0.0), 1.0)
    return half * (bot + (top - bot) * t) - crown * (1.0 - math.sin(math.pi * t))


def shape(o, P, poly, half, **kw):
    """Intersect an extruded part with its crown_loft (see there)."""
    wr.boolean(o, crown_loft('crown', P, poly, half, **kw), 'INTERSECT')
    return o


def lathe(name, P, poly, d0, d1, step, material, axis_y=0.0, seg=40, min_r=0.5, symmetric=True, reach=40.0):
    """Revolve a round part (barrel, brake, nut) from its traced silhouette.
    The radius at each station is the larger of the outline's distances above
    and below the axis (or their average when symmetric=False)."""
    rings = []
    d = d0
    stations = []
    while d <= d1 + 1e-6:
        stations.append(d)
        d += step
    for d in stations:
        sp = span_at(poly, d, (axis_y - reach, axis_y + reach))
        if sp is None:
            continue
        lo, hi = sp
        r = max(hi - axis_y, axis_y - lo) if symmetric else (hi - lo) / 2
        r = max(r, min_r)
        rings.append([P(d, axis_y + r * math.cos(2 * math.pi * k / seg), r * math.sin(2 * math.pi * k / seg)) for k in range(seg)])
    o = wr.loft(name, rings, material)
    wr.smooth(o, 40)
    return o
