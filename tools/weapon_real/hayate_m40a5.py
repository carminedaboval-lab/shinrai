"""HAYATE / H-7 rebuilt as its real counterpart: USMC M40A5 (Remington 700
short action, 25 in Schneider heavy barrel, McMillan A4 stock, Badger
Ordnance M5 detachable bottom metal and 30 MOA base, embedded front rail for
the clip-on night sight, SureFire suppressor-adapter brake), 7.62x51.

blender --background --python tools/weapon_real/hayate_m40a5.py
Published figures used: barrel 25 in installed (24 in / 610 mm ahead of the
recoil lug), muzzle 0.925 in before the brake; Remington 700 short-action
receiver 1.360 in diameter, ~6.6 in long, 2.94 in ejection port; recoil lug
0.312 in; McMillan A4 (USMC): 31 in long, fore-end 1.97 in wide, grip 1.9 in,
butt 1.6 in, saddle cheek piece with two knobs, spacer system, butt hook,
6 flush cups, one bipod stud, textured fore-end and grip, OD green moulded-in
colour; EFR: 3 in top and 3 in side Picatinny, 1.25 in bore, natural hard
anodised. Frame: d = mm behind the barrel crown datum, y = mm above the bore,
z = mm to the left. The Action origin is on the bore axis so the viewmodel's
bolt-lift rotation pivots correctly.
"""
import sys, os, math, bisect
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy
import mathutils
import wr

REPO = Path(__file__).resolve().parents[2]
# HAYATE_PREVIEW_OUT lets a Blender-only preview build write elsewhere, so it
# never touches the asset while a locked Godot import may be reading it.
OUT = Path(os.environ['HAYATE_PREVIEW_OUT']) if os.environ.get('HAYATE_PREVIEW_OUT') else REPO / 'assets/weapons/hayate/hayate_geometry.glb'
XM, BY = -0.754, 0.075
KEY = 'M40'


def P(d, y, z=0.0):
    return (XM + d / 1000.0, BY + y / 1000.0, z / 1000.0)


def side(name, pts, half, m, z=0.0):
    return wr.extrude_xy(name, [P(d, y)[:2] for d, y in pts], (z - half) / 1000, (z + half) / 1000, m)


def sec(name, pts_zy, d0, d1, m):
    return wr.extrude_zy(name, [(z / 1000, BY + y / 1000) for z, y in pts_zy], P(d0, 0)[0], P(d1, 0)[0], m)


def plan(name, pts_dz, y0, y1, m):
    return wr.extrude_xz(name, [(P(d, 0)[0], z / 1000) for d, z in pts_dz], BY + y0 / 1000, BY + y1 / 1000, m)


def cyl(name, d0, d1, r, m, y=0.0, z=0.0, seg=32, r1=None):
    return wr.cylinder(name, P(d0, y, z), P(d1, y, z), r / 1000, m, seg, None if r1 is None else r1 / 1000)


def cyl_z(name, d, y, z0, z1, r, m, seg=24):
    return wr.cylinder(name, P(d, y, z0), P(d, y, z1), r / 1000, m, seg)


def cyl_y(name, d, z, y0, y1, r, m, seg=24):
    return wr.cylinder(name, P(d, y0, z), P(d, y1, z), r / 1000, m, seg)


def lathe(name, prof, m, seg=48):
    """Closed (d, r) profile revolved about the bore: true-round turned part."""
    rings = [[P(d, r * math.sin(2 * math.pi * k / seg), r * math.cos(2 * math.pi * k / seg)) for k in range(seg)] for d, r in prof]
    import bmesh
    bm = bmesh.new()
    vs = [[bm.verts.new(wr.cv(p)) for p in ring] for ring in rings]
    n = len(rings)
    for i in range(n):
        a, b = vs[i], vs[(i + 1) % n]
        for k in range(seg):
            j = (k + 1) % seg
            bm.faces.new((a[k], a[j], b[j], b[k]))
    o = wr._obj(name, bm, m)
    wr._fix_normals(o)
    wr.smooth(o, 40)
    return o


def pchip(table):
    """Monotone cubic through (x, y) keys: smooth moulded lines without overshoot."""
    xs = [p[0] for p in table]
    ys = [p[1] for p in table]
    n = len(xs)
    h = [xs[i + 1] - xs[i] for i in range(n - 1)]
    dl = [(ys[i + 1] - ys[i]) / h[i] for i in range(n - 1)]
    m = [0.0] * n
    m[0], m[-1] = dl[0], dl[-1]
    for i in range(1, n - 1):
        if dl[i - 1] * dl[i] <= 0:
            m[i] = 0.0
        else:
            w1, w2 = 2 * h[i] + h[i - 1], h[i] + 2 * h[i - 1]
            m[i] = (w1 + w2) / (w1 / dl[i - 1] + w2 / dl[i])

    def f(x):
        if x <= xs[0]:
            return ys[0]
        if x >= xs[-1]:
            return ys[-1]
        i = bisect.bisect_right(xs, x) - 1
        hh = h[i]
        t = (x - xs[i]) / hh
        return ((2 * t ** 3 - 3 * t ** 2 + 1) * ys[i] + (t ** 3 - 2 * t ** 2 + t) * hh * m[i]
                + (-2 * t ** 3 + 3 * t ** 2) * ys[i + 1] + (t ** 3 - t ** 2) * hh * m[i + 1])
    return f


class Section:
    """Moulded cross-section family: rounded superellipse whose half-width varies
    from top to bottom (A4 fore-end is flat and square, grip has a palm swell)."""

    def __init__(self, top, bot, wt, wm, wb, nx):
        self.T, self.B, self.WT, self.WM, self.WB, self.NX = (pchip(t) for t in (top, bot, wt, wm, wb, nx))

    def _hw(self, d, v):
        wt, wm, wb = self.WT(d), self.WM(d), self.WB(d)
        return wm + (wt - wb) / 2 * v + ((wt + wb) / 2 - wm) * v * v

    def ring(self, d, chan_r=None, scale=1.0, at=None, n_out=52, k_top=20, a_flat=62.0):
        """One closed cross-section. With chan_r the top carries the barrel
        channel / action inlet as part of the ring itself (clean topology, so
        the rim shades as one smooth edge instead of boolean sawtooth)."""
        top, bot, n = self.T(d), self.B(d), self.NX(d)
        cy, h = (top + bot) / 2, (top - bot) / 2 * scale

        def pt(a_deg):
            a = math.radians(a_deg)
            c, s = math.cos(a), math.sin(a)
            u = math.copysign(abs(c) ** (2 / n), c)
            v = math.copysign(abs(s) ** (2 / n), s)
            return cy + v * h, u * self._hw(d, v) * scale

        if chan_r:
            lo, hi = 0.0, 90.0
            for _ in range(40):
                mid = (lo + hi) / 2
                y, z = pt(mid)
                if math.hypot(y, z) >= chan_r:
                    lo = mid
                else:
                    hi = mid
            ar = lo
        else:
            ar = a_flat
        span = 180.0 + 2 * ar
        yz = [pt(ar - i * span / (n_out - 1)) for i in range(n_out)]
        if chan_r:
            yl, zl = yz[0]
            yr, zr = yz[-1]
            fl, fr = math.atan2(yl, zl), math.atan2(yr, zr)
            if fr > fl:
                fr -= 2 * math.pi
            for j in range(1, k_top + 1):
                f = fr + j * (fl - fr) / (k_top + 1)
                yz.append((chan_r * math.sin(f), chan_r * math.cos(f)))
        else:
            for j in range(1, k_top + 1):
                yz.append(pt((180.0 - ar) - j * (180.0 - 2 * ar) / (k_top + 1)))
        return [P(d if at is None else at, y, z) for y, z in yz]

    def surface_z(self, d, y):
        top, bot, n = self.T(d), self.B(d), self.NX(d)
        cy, h = (top + bot) / 2, (top - bot) / 2
        v = max(-0.999, min(0.999, (y - cy) / h))
        return (1 - abs(v) ** n) ** (1 / n) * self._hw(d, v)


def rail_section(top, half_w=10.6, depth=9.5):
    t = top
    return [(-half_w + 1.1, t - depth), (half_w - 1.1, t - depth), (half_w - 1.1, t - 5.6), (half_w, t - 4.5), (half_w, t - 2.4), (half_w - 1.4, t), (-half_w + 1.4, t), (-half_w, t - 2.4), (-half_w, t - 4.5), (-half_w + 1.1, t - 5.6)]


def pic_rail(name, d0, d1, top, m, xf=None, pitch=10.0, extra=()):
    """MIL-STD-1913 rail: 5.23 mm cross-slots at 10 mm pitch, 3 mm deep."""
    T = (lambda pts: [xf(z, y) for z, y in pts]) if xf else (lambda pts: pts)
    o = sec(name, T(rail_section(top)), d0, d1, m)
    cuts = []
    c = d0 + 4.0
    centres = []
    while c + 5.2 < d1 - 3.0:
        cuts.append(sec('slot', T([(-12, top - 3.0), (12, top - 3.0), (12, top + 2), (-12, top + 2)]), c, c + 5.23, None))
        centres.append(c + 2.615)
        c += pitch
    wr.boolean(o, cuts, 'DIFFERENCE')
    wr.bevel(o, 0.0002, 1, 30)
    return o, centres


def mark(name, body, d, r, alpha_deg, size, m, side_sign=1):
    """Engraved-style text laid tangent to a round part (receiver, barrel)."""
    o = wr.text(name, body, P(d, 0.0, side_sign * (r + 0.06)), size, m, side_sign)
    a = math.radians(alpha_deg)
    piv = mathutils.Vector((0.0, 0.0, BY))
    beta = -a if side_sign > 0 else a
    o.matrix_world = mathutils.Matrix.Translation(piv) @ mathutils.Matrix.Rotation(beta, 4, 'X') @ mathutils.Matrix.Translation(-piv) @ o.matrix_world
    wr.apply(o)
    return o


wr.reset()
M = dict(
    steel=wr.mat(KEY + ' parkerised steel', (0.05, 0.05, 0.05), 0.55, 0.62),
    blued=wr.mat(KEY + ' black steel', (0.04, 0.04, 0.042), 0.75, 0.4),
    bright=wr.mat(KEY + ' polished bolt', (0.6, 0.6, 0.6), 1.0, 0.25),
    stock=wr.mat(KEY + ' McMillan olive', (0.12, 0.13, 0.08), 0.0, 0.55),
    grip=wr.mat(KEY + ' McMillan texture', (0.12, 0.13, 0.08), 0.0, 0.7),
    rubber=wr.mat(KEY + ' recoil pad', (0.03, 0.03, 0.03), 0.0, 0.85),
    alu=wr.mat(KEY + ' anodised alloy', (0.05, 0.05, 0.05), 0.4, 0.5),
    brass=wr.mat(KEY + ' brass', (0.72, 0.52, 0.24), 1.0, 0.3),
    copper=wr.mat(KEY + ' copper jacket', (0.70, 0.36, 0.20), 1.0, 0.32),
    bore=wr.mat(KEY + ' bore', (0.01, 0.01, 0.01), 0.8, 0.5),
    mark=wr.mat(KEY + ' engraving', (0.35, 0.35, 0.34), 0.6, 0.5),
)
body = []
# Remington 700 short action: receiver rear (bridge end) stays where the bolt,
# trigger and hands were fitted; the front ring is 168 mm ahead of it.
RR, RRAD = 826.0, 17.27
RF = RR - 168.0
LUG = 7.9                       # 0.312 in recoil lug
CROWN = RF - LUG - 610.0        # 24 in of barrel ahead of the lug
MUZ = CROWN - 52.0              # brake protrudes 52 mm past the crown

# ---------------------------------------------------- barrel and muzzle ----
SEG = 48
contour = ((CROWN, 11.75), (CROWN + 260.0, 13.5), (RF - LUG - 89.0, 15.24), (RF - LUG + 1.0, 15.24))
barrel = wr.loft('barrel', [[P(d, r * math.sin(2 * math.pi * k / SEG), r * math.cos(2 * math.pi * k / SEG)) for k in range(SEG)] for d, r in contour], M['blued'])
wr.smooth(barrel, 40)
body.append(barrel)
body.append(cyl('crown_bore', CROWN - 0.15, CROWN + 0.6, 3.9, M['bore'], seg=24))
# SureFire suppressor-adapter brake: ratchet ring at the rear for the
# Fast-Attach latch, three round ports per side, tapered seat at the front.
C = CROWN
brake = lathe('muzzle_brake', [(C, 11.4), (C - 0.6, 12.05), (C - 8.6, 12.05), (C - 9.4, 11.3), (MUZ + 7.5, 11.3),
                               (MUZ + 3.2, 10.1), (MUZ + 0.6, 9.7), (MUZ, 9.2), (MUZ, 5.3), (MUZ + 0.7, 4.7), (C, 4.7)], M['blued'])
cuts = []
for k in range(3):
    cuts.append(cyl_z('brake_port', C - 15.0 - k * 12.0, 0.0, -15.0, 15.0, 3.0, None, 28))
for k in range(18):
    a = 2 * math.pi * (k + 0.5) / 18
    ca, sa = math.cos(a), math.sin(a)
    q = [(-1.0, 11.0), (1.0, 11.0), (1.0, 13.0), (-1.0, 13.0)]
    cuts.append(sec('ratchet', [(x * ca - y * sa, x * sa + y * ca) for x, y in q], C - 4.0, C + 1.0, None))
wr.boolean(brake, cuts, 'DIFFERENCE')
body.append(brake)
body.append(mark('barrel_mark', 'HAYATE ARMS  7.62 NATO  1-12', RF - LUG - 52.0, 15.24, 28.0, 0.0024, M['mark'], 1))
# Recoil lug: flat plate between barrel and receiver, round on top.
lug_pts = [(17.32 * math.cos(math.pi * k / 56), 17.32 * math.sin(math.pi * k / 56)) for k in range(57)] + [(-17.32, -30.0), (17.32, -30.0)]
body.append(sec('recoil_lug', lug_pts, RF - LUG, RF, M['steel']))

# -------------------------------------------------------------- receiver ----
rec = cyl('receiver', RF, RR, RRAD, M['steel'], seg=56)
PORT0, PORT1 = RF + 30.0, RF + 105.0          # 2.94 in port, right side, open over the top
cuts = [side('ejection_port', [(PORT0, 1.0), (PORT1, 1.0), (PORT1, 30.0), (PORT0, 30.0)], 10.0, None, z=-8.0),
        side('handle_notch', [(RR - 16.0, -12.0), (RR + 2.0, -12.0), (RR + 2.0, 6.5), (RR - 16.0, 6.5)], 6.0, None, z=-15.0),
        plan('mag_opening', [(PORT0 + 2, -11.0), (PORT1 + 1, -11.0), (PORT1 + 1, 11.0), (PORT0 + 2, 11.0)], -30.0, -8.0, None),
        cyl_z('gas_vent', RF + 14.0, 3.5, -12.0, -20.0, 1.6, None, 16)]
wr.boolean(rec, cuts, 'DIFFERENCE')
wr.bevel(rec, 0.0004, 2, 30)
body.append(rec)
# Receiver tang under the bolt shroud, with the M24 trigger's safety lever.
tang = side('tang', [(RR - 2.0, -10.5), (RR + 28.0, -11.5), (RR + 32.0, -14.5), (RR + 28.0, -17.5), (RR - 2.0, -17.5)], 7.5, M['steel'])
wr.bevel(tang, 0.0004, 2, 30)
body.append(tang)
saf = side('safety', [(RR + 12.0, -15.5), (RR + 21.0, -15.5), (RR + 23.0, -7.5), (RR + 18.0, -5.5), (RR + 12.5, -9.0)], 1.1, M['steel'], z=-9.0)
wr.bevel(saf, 0.0003, 2, 30)
body.append(saf)
body.append(mark('rec_mark', 'HAYATE ARMS    H-7    7.62MM', RF + 66.0, RRAD, 30.0, 0.0029, M['mark'], 1))
body.append(mark('rec_serial', 'U.S. RIFLE    SN 004173', RF + 66.0, RRAD, 12.0, 0.0024, M['mark'], 1))

# Badger 30 MOA one-piece base, two screws in the front ring and two in the
# bridge, sitting in a saddle that follows the receiver; 0.5 deg down at the front.
RAIL0, RAIL1, RTOP = RF + 4.0, RR + 12.0, 27.0
rail, slots = pic_rail('rail', RAIL0, RAIL1, RTOP, M['alu'])
scr = []
for c in (slots[0], slots[1], slots[-5], slots[-4]):
    scr.append(cyl_y('rail_screw', c, 0.0, RTOP - 3.05, RTOP - 2.55, 2.45, M['steel'], 20))
    scr.append(cyl_y('screw_socket', c, 0.0, RTOP - 2.6, RTOP - 2.5, 1.25, M['bore'], 6))
rail = wr.join('rail', [rail] + scr)
pivot = wr.cv(P(RAIL1, RTOP))
rail.matrix_world = mathutils.Matrix.Translation(pivot) @ mathutils.Matrix.Rotation(math.radians(0.5), 4, 'Y') @ mathutils.Matrix.Translation(-pivot) @ rail.matrix_world
wr.apply(rail)
body.append(rail)
saddle = [(9.3, 19.0), (-9.3, 19.0)] + [(17.35 * math.cos(math.radians(a)), 17.35 * math.sin(math.radians(a))) for a in range(123, 56, -6)]
body.append(sec('rail_base', saddle, RAIL0 + 1.0, RAIL1 - 1.0, M['alu']))

# ------------------------------------------------------- McMillan A4 stock ----
# Side lines follow refs/m40a3_left.json (levelled on the bore): square, flat
# fore-end with the barrel half sunk in its channel, stock top at the receiver
# centreline, vertical grip with thumb notch behind the tang, high comb, the
# A4 butt hook and a flat toe.
STOCK = Section(
    top=[(340, -14), (343, -8.5), (348, -5.5), (356, -4.0), (372, -3.0), (640, -3.0), (652, -1.5), (RR + 2, -1.5), (RR + 7, -5.0),
         (RR + 12, -11.0), (850, -14.0), (865, -18.0), (880, -25.0), (892, -35.0), (900, -38.0), (908, -34.0), (915, -22.0), (921, -12.0),
         (928, -6.0), (940, -4.0), (1100, -3.0)],
    bot=[(340, -30), (343, -42), (348, -51), (356, -57), (370, -61), (400, -63.5), (560, -66.0), (640, -63.0), (700, -57.0), (760, -59.0),
         (834, -62.0), (838, -66.0), (841, -80.0), (844, -100.0), (847, -122.0), (850, -142.0), (854, -153.0), (860, -160.0), (868, -163.5),
         (882, -164.0), (895, -161.0), (905, -155.0), (915, -146.0), (928, -136.0), (945, -131.0), (962, -132.0), (976, -138.0),
         (988, -148.0), (998, -155.0), (1010, -157.5), (1050, -158.0), (1088, -157.0), (1100, -154.0)],
    wt=[(340, 10), (348, 18), (360, 23.5), (640, 24.0), (830, 24.5), (840, 19.0), (860, 16.0), (900, 15.0), (925, 14.5), (945, 15.0), (1100, 15.5)],
    wm=[(340, 12), (348, 20), (360, 24.5), (640, 25.0), (830, 25.0), (842, 23.0), (860, 23.5), (900, 23.5), (925, 21.0), (945, 20.5), (1100, 20.5)],
    wb=[(340, 10), (348, 18), (360, 23.0), (640, 23.5), (830, 22.0), (842, 19.0), (860, 20.0), (900, 20.5), (930, 18.5), (1100, 18.5)],
    nx=[(340, 3.0), (360, 5.0), (640, 5.0), (830, 4.5), (845, 3.2), (925, 3.2), (945, 4.0), (1100, 4.0)],
)
ds = sorted(set([340, 341, 342.5, 344, 346, 348, 351, 355, 360, 366, 373] + list(range(380, 834, 6)) + [RR, RR + 0.8]
                + list(range(834, 870, 2)) + list(range(870, 1010, 3)) + list(range(1010, 1100, 6)) + [1100]))


def channel(d):
    # Free-floated barrel channel (2 mm clear of the 1.2 in shank), then the
    # receiver inlet; the lug and the bottom of the action sit in solid stock.
    if d < 646.0:
        return 17.2
    if d <= RR + 0.4:
        return RRAD + 0.35
    return None


stock = wr.loft('stock', [STOCK.ring(d, channel(d)) for d in ds], M['stock'])
# Remaining inletting: tang and shroud, bolt-handle relief, Badger M5 bottom
# metal pocket, magazine well, EFR pocket.
inlet = [sec('tang_inlet', [(-8.0, -18.0), (8.0, -18.0), (8.0, 4.0), (-8.0, 4.0)], RR - 2.0, RR + 32.5, None),
         cyl('shroud_clear', RR, RR + 44.0, 10.6, None, seg=32),
         wr.cylinder('handle_relief', P(RR - 12.0, 1.0, -8.0), P(RR + 32.0, -26.0, -44.0), 0.0075, None, 28),
         sec('bm_pocket', [(-12.4, -95.0), (12.4, -95.0), (12.4, -44.0), (-12.4, -44.0)], RF + 16.0, 836.4, None),
         sec('mag_well', [(-11.8, -95.0), (11.8, -95.0), (11.8, -10.0), (-11.8, -10.0)], PORT0 + 1.0, PORT1 + 4.0, None),
         sec('efr_pocket', [(-17.0, -24.0), (17.0, -24.0), (17.0, 6.0), (-17.0, 6.0)], 477.0, 563.0, None)]
wr.boolean(stock, inlet, 'DIFFERENCE')
wr.smooth(stock, 40)
wr.assign_faces(stock, M['grip'], lambda x, y, z: 376 < (x - XM) * 1000 < 640 and (y - BY) * 1000 < -9.0)
wr.assign_faces(stock, M['grip'], lambda x, y, z: 840 < (x - XM) * 1000 < 912 and (y - BY) * 1000 < -48.0)
body.append(stock)
# Saddle cheek piece: wraps over the comb, raised on its posts; two knobs.
CHEEK = Section(
    top=[(932, -2.0), (936, 4.0), (942, 8.5), (955, 11.0), (1000, 12.0), (1080, 12.5), (1087, 11.0), (1091, 6.0)],
    bot=[(932, -12.0), (1091, -12.0)],
    wt=[(932, 11.0), (945, 14.0), (1091, 14.0)],
    wm=[(932, 14.5), (945, 17.6), (1080, 17.6), (1091, 16.5)],
    wb=[(932, 15.5), (945, 18.0), (1091, 18.0)],
    nx=[(932, 3.2), (1091, 3.2)],
)
cds = [932, 933, 934.5, 936.5, 939, 942, 946, 951] + list(range(957, 1080, 6)) + [1080, 1083, 1085.5, 1087.5, 1089, 1090.2, 1091]
cheek = wr.loft('cheek_piece', [CHEEK.ring(d, n_out=36, k_top=12) for d in cds], M['stock'])
wr.smooth(cheek, 40)
body.append(cheek)
for dd in (972.0, 1048.0):
    zs = STOCK.surface_z(dd, -24.0)
    body.append(cyl_z('cheek_knob', dd, -24.0, zs - 1.0, zs + 7.0, 7.5, M['alu'], 32))
    body.append(cyl_z('cheek_knob_cap', dd, -24.0, zs + 7.0, zs + 7.6, 6.6, M['alu'], 32))
# Two length-of-pull spacer plates and the recoil pad on the 1100 face.
for a, b in ((1100.0, 1105.8), (1106.2, 1111.8)):
    body.append(wr.loft('lop_spacer', [STOCK.ring(1100.0, None, 0.995, at=a), STOCK.ring(1100.0, None, 0.995, at=b)], M['alu']))
pad = wr.loft('recoil_pad', [STOCK.ring(1100.0, None, s, at=at) for at, s in ((1112.0, 1.0), (1113.5, 1.012), (1121.0, 1.01), (1124.0, 0.985), (1125.6, 0.95), (1126.2, 0.9))], M['rubber'])
wr.smooth(pad, 40)
body.append(pad)
# Bipod stud under the fore-end tip and the six QD flush cups.
yb = STOCK.B(386.0)
body.append(cyl_y('stud_escutcheon', 386.0, 0.0, yb + 0.6, yb - 0.7, 6.4, M['steel'], 28))
body.append(cyl_y('bipod_stud', 386.0, 0.0, yb, yb - 9.5, 3.6, M['steel'], 20))
for dd, yy in ((392.0, -36.0), (1062.0, -42.0), (1062.0, -128.0)):
    zs = STOCK.surface_z(dd, yy)
    for sgn in (1, -1):
        body.append(cyl_z('flush_cup', dd, yy, sgn * (zs - 3.0), sgn * (zs + 0.25), 8.2, M['steel'], 32))
        body.append(cyl_z('flush_cup_hole', dd, yy, sgn * (zs + 0.2), sgn * (zs + 0.3), 4.7, M['bore'], 24))

# ---------------------------------- Badger M5 bottom metal and trigger ----
BM0, BM1 = RF + 16.0, 836.0
bm_pts = [(BM0, -46.0), (BM1, -46.0)] + [(d, STOCK.B(d) - 0.8) for d in [BM1] + list(range(int(BM1) - 6, int(BM0) + 4, -6)) + [BM0 + 3.0]] + [(BM0, STOCK.B(BM0) - 0.2)]
bm = side('bottom_metal', bm_pts, 12.0, M['alu'])
wr.boolean(bm, sec('bm_well', [(-11.6, -95.0), (11.6, -95.0), (11.6, -20.0), (-11.6, -20.0)], PORT0 + 1.5, PORT1 + 3.5, None), 'DIFFERENCE')
wr.bevel(bm, 0.0005, 2, 30)
body.append(bm)
for dd in (BM0 + 6.0,):
    body.append(cyl_y('action_screw', dd, 0.0, STOCK.B(dd) - 0.6, STOCK.B(dd) - 1.4, 3.6, M['steel'], 20))
tg = side('trigger_guard', [(768.0, -52.0), (775.0, -52.0), (778.0, -70.0), (785.0, -84.0), (793.0, -88.5), (826.0, -88.5), (834.0, -85.0),
                            (840.0, -74.0), (843.0, -60.0), (843.0, -52.0)], 6.5, M['alu'])
wr.boolean(tg, side('guard_hole', [(779.5, -58.0), (784.0, -74.0), (791.0, -82.0), (825.0, -82.0), (831.0, -78.0), (835.5, -68.0), (836.5, -58.0)], 9.0, None), 'DIFFERENCE')
wr.bevel(tg, 0.0006, 2, 30)
body.append(tg)
rel = side('mag_release', [(782.0, -58.0), (788.0, -58.0), (791.0, -71.0), (788.5, -73.5), (784.5, -67.0)], 4.0, M['alu'])
wr.bevel(rel, 0.0003, 2, 30)
body.append(rel)
trig = side('trigger', [(797.0, -56.0), (803.0, -56.0), (803.5, -65.0), (805.5, -73.0), (804.0, -78.5), (801.5, -77.5), (800.0, -69.0), (797.5, -61.0)], 3.2, M['blued'])
wr.bevel(trig, 0.0003, 2, 30)
body.append(trig)

# ------------------------------------- EFR (embedded front rail, PVS-22) ----
E0, E1 = 478.0, 562.0
efr = sec('efr_body', [(-16.5, -22.0), (16.5, -22.0), (16.5, 15.5), (14.0, 18.0), (-14.0, 18.0), (-16.5, 15.5)], E0, E1, M['alu'])
wr.boolean(efr, cyl('efr_bore', E0 - 5.0, E1 + 5.0, 15.9, None, seg=48), 'DIFFERENCE')
wr.bevel(efr, 0.0005, 2, 30)
body.append(efr)
efr_top, _ = pic_rail('efr_rail', E0 + 4.0, E1 - 4.0, 27.5, M['alu'])
body.append(efr_top)
efr_side, _ = pic_rail('efr_side_rail', E0 + 4.0, E1 - 4.0, 26.0, M['alu'], xf=lambda z, y: (y, 7.4 - z))
body.append(efr_side)
for dd in (E0 + 16.0, E1 - 16.0):
    body.append(cyl_z('efr_screw', dd, 6.0, -16.3, -17.1, 2.5, M['steel'], 20))
    body.append(cyl_z('efr_screw_socket', dd, 6.0, -17.0, -17.15, 1.25, M['bore'], 6))

# --------------------------------------------------------------- action ----
act = []
BOLT0 = RF + 18.0
act.append(cyl('bolt_body', BOLT0 + 7.0, RR + 8, 8.9, M['bright'], seg=36))
act.append(cyl('bolt_head', BOLT0, BOLT0 + 7.0, 8.6, M['bright'], seg=36))
act.append(side('locking_lug', [(BOLT0, 7.0), (BOLT0 + 14.0, 7.0), (BOLT0 + 14.0, 12.6), (BOLT0, 12.6)], 3.2, M['bright']))
act.append(side('locking_lug', [(BOLT0, -12.6), (BOLT0 + 14.0, -12.6), (BOLT0 + 14.0, -7.0), (BOLT0, -7.0)], 3.2, M['bright']))
act.append(side('extractor', [(BOLT0 - 0.5, -3.0), (BOLT0 + 9.0, -3.0), (BOLT0 + 9.0, 3.0), (BOLT0 - 0.5, 3.0)], 0.9, M['bright'], z=-8.4))
shroud = cyl('bolt_shroud', RR + 8, RR + 34, 9.6, M['blued'], seg=36, r1=8.4)
act.append(shroud)
act.append(cyl('cocking_piece', RR + 34, RR + 40, 4.0, M['blued'], y=-3.0, seg=20))
# Bolt handle: root at the rear of the bolt (in the bridge notch), swept back
# and down to the tactical knob.
HR = RR - 8.0
act.append(wr.cylinder('handle_root', P(HR, 0.0, -6.0), P(HR, -2.0, -20.0), 0.0058, M['blued'], 24))
act.append(wr.cylinder('handle_stem', P(HR, -2.0, -20.0), P(HR + 36.0, -24.0, -40.0), 0.0042, M['blued'], 20, radius_b=0.0048))
act.append(wr.cylinder('tactical_knob', P(HR + 30.0, -20.0, -36.0), P(HR + 46.0, -29.5, -47.0), 0.0112, M['blued'], 40, radius_b=0.0104))
act.append(wr.cylinder('knob_cap', P(HR + 45.0, -29.0, -46.4), P(HR + 47.0, -30.2, -47.8), 0.0098, M['blued'], 40))
action = wr.join('Action', act)
# Put the action's origin on the bore axis: the viewmodel lifts the bolt by
# rotating the node about its own origin around the bore direction.
bpy.context.scene.cursor.location = wr.cv(P(820.0, 0.0, 0.0))
bpy.ops.object.select_all(action='DESELECT')
action.select_set(True)
bpy.context.view_layer.objects.active = action
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.context.scene.cursor.location = (0, 0, 0)

# ------------------------------------------------------------- magazine ----
MG0, MG1 = PORT0 + 2.0, PORT1 + 3.0
mag = side('magazine', [(MG0, -14.0), (MG1, -14.0), (MG1, -68.0), (MG1 - 4, -72.0), (MG0 + 4, -72.0), (MG0, -68.0)], 11.2, M['steel'])
wr.bevel(mag, 0.0006, 2, 30)
mag_parts = [mag]
fp = side('mag_floor', [(MG0 - 1.5, -70.0), (MG1 + 1.5, -70.0), (MG1 + 1.5, -73.5), (MG1 - 1.0, -75.5), (MG0 + 1.0, -75.5), (MG0 - 1.5, -73.5)], 12.0, M['steel'])
wr.bevel(fp, 0.0005, 2, 30)
mag_parts.append(fp)
mag_parts.append(cyl('top_round', MG1 - 3.0, MG1 - 54.0, 5.95, M['brass'], y=-15.0, z=-3.5, seg=24))
mag_parts.append(cyl('top_bullet', MG1 - 54.0, MG1 - 73.0, 3.9, M['copper'], y=-15.0, z=-3.5, seg=24, r1=1.2))
magazine = wr.join('Magazine', mag_parts)

# ------------------------------------------- backup folding iron sights ----
# Not on a real M40A5 (it has none); kept so iron ADS works. Built as a real
# folding BUIS pair: Picatinny clamp, cross-bolt, hinge, protective ears,
# 4.8 mm aperture at the rear, square post at the front, both at y = 57.
irons = []


def buis_base(d0, d1, rail_top, top):
    base = sec('buis_base', [(-12.4, rail_top - 6.0), (12.4, rail_top - 6.0), (12.4, top - 1.5), (11.0, top), (-11.0, top), (-12.4, top - 1.5)], d0, d1, M['alu'])
    wr.boolean(base, sec('rail_seat', rail_section(rail_top + 0.01), d0 - 1, d1 + 1, None), 'DIFFERENCE')
    wr.bevel(base, 0.0005, 2, 30)
    irons.append(base)
    mid = (d0 + d1) / 2
    irons.append(cyl_z('clamp_knob', mid, rail_top - 3.0, 12.2, 16.5, 4.2, M['alu'], 28))
    irons.append(cyl_z('clamp_nut', mid, rail_top - 3.0, -12.2, -14.2, 3.6, M['steel'], 6))
    irons.append(cyl_z('hinge_pin', mid, top + 1.6, -8.5, 8.5, 1.9, M['steel'], 20))
    return mid


def ears(mid, y0, z_in, z_out, tip, t=1.5):
    for sgn in (1, -1):
        e = sec('buis_ear', [(sgn * z_in, y0), (sgn * z_out, y0), (sgn * z_out, tip - 2.0), (sgn * (z_out - 1.2), tip), (sgn * (z_in + 0.6), tip), (sgn * z_in, tip - 1.5)], mid - t, mid + t, M['alu'])
        wr.bevel(e, 0.0003, 2, 30)
        irons.append(e)
    br = sec('buis_bridge', [(-z_out, y0 - 0.5), (z_out, y0 - 0.5), (z_out, y0 + 5.0), (-z_out, y0 + 5.0)], mid - t - 0.15, mid + t + 0.15, M['alu'])
    wr.bevel(br, 0.0003, 2, 30)
    irons.append(br)


# Rear on the base's rear, sight point (marker) at d 816.
REAR_D, SIGHT_Y = 816.0, 57.0
rear_rail_top = RTOP - (RAIL1 - REAR_D) * math.tan(math.radians(0.5))
mid = buis_base(REAR_D - 10.0, REAR_D + 10.0, rear_rail_top, rear_rail_top + 6.0)
y0 = rear_rail_top + 6.5
ears(REAR_D, y0, 7.2, 10.4, SIGHT_Y + 5.5)
a0 = math.degrees(math.acos(-4.5 / 6.6))   # stem meets the aperture ring here
a_start, a_end = 360.0 - a0, a0 - 180.0    # lower-left, over the top, lower-right
disc = [(-4.5, y0)] + [(6.6 * math.cos(math.radians(a)), SIGHT_Y + 6.6 * math.sin(math.radians(a)))
                       for a in [a_start + k * (a_end - a_start) / 30 for k in range(31)]] + [(4.5, y0)]
leaf = sec('rear_leaf', disc, REAR_D - 1.4, REAR_D + 1.4, M['alu'])
wr.boolean(leaf, cyl('aperture', REAR_D - 4.0, REAR_D + 4.0, 2.4, None, y=SIGHT_Y, seg=32), 'DIFFERENCE')
wr.bevel(leaf, 0.0003, 2, 30)
irons.append(leaf)
# Front on the EFR top rail, post tip (marker) at d 505.
FRONT_D = 505.0
buis_base(FRONT_D - 9.0, FRONT_D + 9.0, 27.5, 33.5)
fy0 = 34.0
ears(FRONT_D, fy0, 6.2, 9.0, SIGHT_Y + 3.0)
irons.append(cyl_y('post_base', FRONT_D, 0.0, fy0 + 4.0, fy0 + 9.0, 2.3, M['alu'], 24))
post = side('front_post', [(FRONT_D - 0.9, fy0 + 8.0), (FRONT_D + 0.9, fy0 + 8.0), (FRONT_D + 0.9, SIGHT_Y), (FRONT_D - 0.9, SIGHT_Y)], 0.9, M['alu'])
irons.append(post)
iron_sights = wr.join('IronSights', irons)

body_obj = wr.join('BodyMesh', body)
objs = [body_obj, action, magazine, iron_sights]
print('M40 verts', {o.name: len(o.data.vertices) for o in objs}, 'total', wr.stats(objs))
print('M40 frame RF', RF, 'CROWN', CROWN, 'MUZ', MUZ, 'muzzle x', XM + MUZ / 1000, 'port centre x', XM + (PORT0 + PORT1) / 2000,
      'mag centre x', XM + (MG0 + MG1) / 2000, 'front sight x', XM + FRONT_D / 1000)
wr.export(OUT, objs)
print('EXPORTED', OUT)
