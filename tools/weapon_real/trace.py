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


def clip_convex(poly, clip):
    """Sutherland-Hodgman: the part of a (d, y) outline inside a convex region."""
    area = sum(clip[i][0] * clip[(i + 1) % len(clip)][1] - clip[(i + 1) % len(clip)][0] * clip[i][1] for i in range(len(clip)))
    sgn = 1.0 if area > 0 else -1.0
    out = list(poly)
    for i in range(len(clip)):
        a, b = clip[i], clip[(i + 1) % len(clip)]

        def ins(p):
            return sgn * ((b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])) >= 0

        def cut(p, q):
            x1, y1, x2, y2 = p[0], p[1], q[0], q[1]
            dx, dy = b[0] - a[0], b[1] - a[1]
            den = (x2 - x1) * dy - (y2 - y1) * dx
            t = ((a[0] - x1) * dy - (a[1] - y1) * dx) / den if den else 0.0
            return (x1 + (x2 - x1) * t, y1 + (y2 - y1) * t)

        src, out = out, []
        for j in range(len(src)):
            p, q = src[j], src[(j + 1) % len(src)]
            if ins(q):
                if not ins(p):
                    out.append(cut(p, q))
                out.append(q)
            elif ins(p):
                out.append(cut(p, q))
        if not out:
            break
    return out


def _axis(poly):
    """Centroid and principal (long) direction of an outline, pointing down."""
    pts = []
    n = len(poly)
    for i in range(n):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % n]
        k = max(1, int(math.hypot(x1 - x0, y1 - y0)))
        pts += [(x0 + (x1 - x0) * t / k, y0 + (y1 - y0) * t / k) for t in range(k)]
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    sxx = sum((p[0] - cx) ** 2 for p in pts)
    syy = sum((p[1] - cy) ** 2 for p in pts)
    sxy = sum((p[0] - cx) * (p[1] - cy) for p in pts)
    ang = 0.5 * math.atan2(2 * sxy, sxx - syy)
    e = (math.cos(ang), math.sin(ang))
    if e[1] > 0:
        e = (-e[0], -e[1])
    return (cx, cy), e


def grip_loft(name, P, poly, half_top, half_palm, half_bottom, palm_t=0.42, n=2.3, front=0.8,
              step=2.0, margin=0.6, extend_top=30.0, axis=None):
    """Cutter giving a pistol grip a real hand-filling section: stations run
    along the grip's own raked axis; each section is an egg (narrower at the
    front strap, fuller at the backstrap) and the width swells at the palm and
    draws in toward the heel. Intersect the grip (extruded wider than any of
    the halves) with it, or subtract (region - loft) from a one-piece stock."""
    polys = poly if isinstance(poly[0][0], (tuple, list)) else [poly]
    polys = [p for p in polys if len(p) > 2]
    (cx, cy), e = axis or _axis([q for p in polys for q in p])
    nv = (-e[1], e[0]) if -e[1] > 0 else (e[1], -e[0])    # perpendicular, pointing rearward (+d)
    rots = [[((p[0] - cx) * e[0] + (p[1] - cy) * e[1], (p[0] - cx) * nv[0] + (p[1] - cy) * nv[1]) for p in pl] for pl in polys]
    a0, a1 = min(r[0] for rot in rots for r in rot), max(r[0] for rot in rots for r in rot)
    stations = []
    a = a0 - extend_top
    while a <= a1 + 1.0:
        stations.append(a)
        a += step
    spans = []
    for s in stations:
        got = [sp for sp in (span_at(rot, s) for rot in rots) if sp]
        spans.append((min(g[0] for g in got), max(g[1] for g in got)) if got else None)
    valid = [i for i, sp in enumerate(spans) if sp]
    for i in range(len(spans)):
        if spans[i] is None:
            spans[i] = spans[min(valid, key=lambda v: abs(v - i))]

    def width(t):
        t = min(max(t, 0.0), 1.0)
        if t < palm_t:
            u = t / palm_t
            return half_top + (half_palm - half_top) * u * u * (3 - 2 * u)
        u = (t - palm_t) / (1 - palm_t)
        return half_palm + (half_bottom - half_palm) * u * u * (3 - 2 * u)

    def prof(s):
        return (max(0.0, 1 - abs(2 * s - 1) ** n)) ** (1 / n) * (front + (1 - front) * s)

    norm = max(prof(k / 200) for k in range(201))
    N = 16
    rings = []
    for s_a, (lo, hi) in zip(stations, spans):
        lo, hi = lo - margin, hi + margin
        W = width((s_a - a0) / (a1 - a0))
        side_pts = []
        for k in range(N + 1):
            s = k / N
            b = lo + (hi - lo) * s
            side_pts.append((cx + e[0] * s_a + nv[0] * b, cy + e[1] * s_a + nv[1] * b, W * prof(s) / norm))
        ring = [P(d, y, -z) for d, y, z in side_pts] + [P(d, y, z) for d, y, z in reversed(side_pts[1:-1])]
        rings.append(ring)
    return wr.loft(name, rings, None)


def smoothstep(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def squeeze(o, XM, BY, factor):
    """Scale a dense (moulded) part's width by factor(d, y): a stepless way to
    slim one region of a one-piece stock, e.g. the wrist of a thumbhole stock."""
    for v in o.data.vertices:
        c = o.matrix_world @ v.co          # Blender (x, -z, y)
        d, y = (c.x - XM) * 1000.0, (c.z - BY) * 1000.0
        f = factor(d, y)
        if f != 1.0:
            v.co.y *= f
    o.data.update()
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
