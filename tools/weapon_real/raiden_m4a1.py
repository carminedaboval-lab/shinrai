"""RAIDEN / R-56 rebuilt as its real counterpart: Colt M4A1, SOPMOD Block II
(DD RIS II 12.25, B5 SOPMOD stock, PMAG, KAC flip-up sights), 5.56x45.

blender --background --python tools/weapon_real/raiden_m4a1.py
The side outline is traced from "M4A1 SOPMOD Block II.jpg" (Wikimedia Commons,
7607 px, right side; refs/m4a1_blockii_right.json) at 7.18 px/mm measured from
the 10.0 mm rail slot pitch. The photo's optic, laser, foregrip and suppressor
are replaced by the bare rails and an A2 birdcage. Right-side features
(forward assist, deflector, port, mag release, pins) are placed from the photo;
left-side controls follow AR-15 drawings. Frame: d = mm behind the muzzle,
y = mm above the bore, z = mm to the left.
"""
import sys, math, json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy
import wr
from trace import clean, lathe, grip_loft, clip_convex

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / 'assets/weapons/raiden_r56/raiden_r56_geometry.glb'
REF = json.load(open(REPO / 'tools/weapon_real/refs/m4a1_blockii_right.json'))
S, BYPX = REF['scale_px_per_mm'], REF['bore_y']
CROWN_X = 6010.0
MUZZLE_X = CROWN_X + 44.0 * S  # A2 birdcage stands 44 mm proud of the crown
XM, BY = -0.4585, 0.0568


def N(x, y=0.0):
    return ((MUZZLE_X - x) / S, (BYPX - y) / S)


def D(x):
    return (MUZZLE_X - x) / S


def H(y):
    return (BYPX - y) / S


def P(d, y, z=0.0):
    return (XM + d / 1000.0, BY + y / 1000.0, z / 1000.0)


OUTLINE = [N(x, y) for x, y in REF['outline']]


def side(name, pts, half, m, z=0.0):
    return wr.extrude_xy(name, [P(d, y)[:2] for d, y in clean(pts)], (z - half) / 1000, (z + half) / 1000, m)


def nside(name, native, half, m, z=0.0):
    return side(name, [N(x, y) for x, y in native], half, m, z)


def sec(name, pts_zy, d0, d1, m=None):
    return wr.extrude_zy(name, [(z / 1000, BY + y / 1000) for z, y in pts_zy], P(d0, 0)[0], P(d1, 0)[0], m)


def plan(name, pts_dz, y0, y1, m=None):
    return wr.extrude_xz(name, [(P(d, 0)[0], z / 1000) for d, z in pts_dz], BY + y0 / 1000, BY + y1 / 1000, m)


def cyl(name, d0, d1, r, m, y=0.0, z=0.0, seg=32, r1=None):
    return wr.cylinder(name, P(d0, y, z), P(d1, y, z), r / 1000, m, seg, None if r1 is None else r1 / 1000)


def cyl_z(name, d, y, z0, z1, r, m, seg=24):
    return wr.cylinder(name, P(d, y, z0), P(d, y, z1), r / 1000, m, seg)


def part(name, half, m, native_region):
    o = side(name, OUTLINE, half, m)
    wr.boolean(o, nside('clip', native_region, 90, None), 'INTERSECT')
    return o


def rail_section(top, half_w=10.6, depth=9.5):
    t = top
    return [(-half_w + 1.1, t - depth), (half_w - 1.1, t - depth), (half_w - 1.1, t - 5.6), (half_w, t - 4.5), (half_w, t - 2.4), (half_w - 1.4, t), (-half_w + 1.4, t), (-half_w, t - 2.4), (-half_w, t - 4.5), (-half_w + 1.1, t - 5.6)]


def rail(name, d0, d1, top, m, first=None):
    o = sec(name, rail_section(top), d0, d1, m)
    cuts = []
    c = (d0 + 3.5) if first is None else first
    while c + 5.2 < d1 - 2.5:
        cuts.append(sec('slot', [(-12, top - 3.0), (12, top - 3.0), (12, top + 2), (-12, top + 2)], c, c + 5.23))
        c += 10.0
    if cuts:
        wr.boolean(o, cuts, 'DIFFERENCE')
    wr.bevel(o, 0.0002, 1, 30)
    return o


def rot_x(o, deg, axis_y):
    import mathutils
    pivot = wr.cv(P(0, axis_y))
    o.matrix_world = mathutils.Matrix.Translation(pivot) @ mathutils.Matrix.Rotation(math.radians(deg), 4, 'X') @ mathutils.Matrix.Translation(-pivot) @ o.matrix_world
    wr.apply(o)
    return o


wr.reset()
M = dict(
    anod=wr.mat('M4 hard anodized', (0.05, 0.05, 0.052), 0.35, 0.55),
    rail=wr.mat('M4 rail anodized', (0.05, 0.05, 0.052), 0.35, 0.5),
    cover=wr.mat('M4 rail cover', (0.30, 0.25, 0.17), 0.0, 0.62),
    steel=wr.mat('M4 phosphate steel', (0.05, 0.052, 0.05), 0.6, 0.6),
    bolt=wr.mat('M4 bolt carrier', (0.06, 0.06, 0.06), 0.8, 0.4),
    poly=wr.mat('M4 polymer', (0.04, 0.04, 0.042), 0.0, 0.6),
    grip=wr.mat('M4 grip checkering', (0.04, 0.04, 0.042), 0.0, 0.66),
    mag=wr.mat('M4 PMAG polymer', (0.04, 0.04, 0.042), 0.0, 0.62),
    brass=wr.mat('M4 brass', (0.72, 0.52, 0.24), 1.0, 0.3),
    mark=wr.mat('M4 engraving', (0.35, 0.35, 0.34), 0.5, 0.5),
    paint=wr.mat('M4 selector paint', (0.85, 0.85, 0.82), 0.0, 0.5),
    sight=wr.mat('M4 sight steel', (0.06, 0.06, 0.06), 0.7, 0.45),
    pad=wr.mat('M4 rubber pad', (0.03, 0.03, 0.03), 0.0, 0.88),
)
U_HALF, L_HALF, MW_HALF = 11.6, 11.0, 13.6
RAIL_TOP = H(685)
SEAM = H(REF['seam_y'])
body = []

# ---------------------------------------------------------------- upper ----
upper = part('upper', 14.0, M['anod'], [(2075, 700), (3548, 700), (3548, 1052), (2075, 1052)])
wr.boolean(upper, sec('up_section', [(-11.2, SEAM - 2), (11.2, SEAM - 2), (11.6, -8.0), (11.6, 8.0), (10.6, 14.0), (8.6, 20.6), (-8.6, 20.6), (-10.6, 14.0), (-11.6, 8.0), (-11.6, -8.0)], -10, 900), 'INTERSECT')
wr.boolean(upper, nside('ejection_port', [(2878, 840), (3452, 840), (3452, 975), (2878, 975)], 6.0, None, z=-U_HALF), 'DIFFERENCE')
upper = wr.join('upper', [upper, cyl('upper_front_ring', D(3548), D(3460), 17.6, M['anod'], y=0.6, seg=48)])
wr.bevel(upper, 0.0005, 2, 30)
body.append(upper)
d_u0, d_u1 = D(3545), D(2080)
body.append(rail('upper_rail', d_u0, d_u1, RAIL_TOP, M['anod']))
for i in range(6):
    body.append(wr.text('rail_no', 'T%d' % (7 + 3 * i), P(d_u0 + 8.5 + 30.0 * i, RAIL_TOP - 3.4, 10.62), 0.0022, M['mark'], 1))
# Right side, from the photo: forward assist, brass deflector, open dust cover.
fa_d, fa_y = N(2780, 838)
body.append(wr.cylinder('forward_assist_housing', P(fa_d + 6, fa_y - 6, -9.0), P(fa_d - 2, fa_y - 2, -15.5), 0.0078, M['anod'], 32))
body.append(wr.cylinder('forward_assist_knob', P(fa_d - 2, fa_y - 2, -15.0), P(fa_d - 10, fa_y + 1, -18.6), 0.0083, M['steel'], 40))
body.append(nside('brass_deflector', [(2830, 800), (2880, 800), (2880, 960), (2830, 930)], 3.2, M['anod'], z=-12.6))
body.append(cyl('dust_cover_rod', D(3460), D(2870), 1.3, M['steel'], y=H(985), z=-11.8, seg=12))
body.append(nside('dust_cover', [(2878, 985), (3452, 985), (3452, 1070), (2878, 1070)], 0.6, M['steel'], z=-13.4))
# A2 charging handle and latch.
ch_d0, ch_d1 = D(2120), D(1995)
# Mil-spec T-handle is about 39 mm across; the latch sits on the left only.
ch = plan('charging_handle_T', [(ch_d0, -19.5), (ch_d1 + 2, -19.5), (ch_d1, -16), (ch_d1, 16), (ch_d1 + 2, 19.5), (ch_d0, 19.5), (ch_d0 + 2, 14), (ch_d0 + 2, -14)], 13.5, 20.5, M['anod'])
wr.bevel(ch, 0.0008, 2, 30)
body.append(ch)
latch = plan('charging_latch', [(ch_d0 + 4, 6.0), (ch_d1 + 4, 10.0), (ch_d1 + 4, 23.0), (ch_d0 - 3, 23.0)], 14.0, 20.0, M['anod'])
wr.bevel(latch, 0.0005, 2, 30)
body.append(latch)

# ---------------------------------------------------------------- lower ----
lower = part('lower', MW_HALF, M['anod'], [(2075, 1050), (3550, 1050), (3550, 1468), (2962, 1525), (2505, 1525), (2275, 1300), (2075, 1300)])
wr.boolean(lower, sec('low_section', [(-L_HALF, 40), (L_HALF, 40), (L_HALF, -200), (-L_HALF, -200)], D(2960) - 1, 900), 'DIFFERENCE')
lower_body = part('lower_body', L_HALF, M['anod'], [(2075, 1050), (2962, 1050), (2962, 1525), (2505, 1525), (2275, 1300), (2075, 1300)])
lower = wr.join('lower', [lower, lower_body])
GUARD = [(2583, 1376), (2591, 1348), (2618, 1311), (2662, 1287), (2742, 1285), (2860, 1289), (2892, 1303), (2917, 1326), (2929, 1346), (2935, 1368), (2935, 1398), (2929, 1420), (2919, 1446), (2897, 1478), (2848, 1489), (2648, 1489), (2611, 1458), (2599, 1438), (2583, 1406)]
# The trigger guard is a separate 10 mm bar pinned between the receiver's ears,
# not the full width of the lower.
guard_slim = [nside('guard_slim', [(2606, 1480), (2932, 1480), (2932, 1560), (2606, 1560)], 10.0, None, z=s * 15.0) for s in (1, -1)]
wr.boolean(lower, [nside('guard_hole', GUARD, 40, None), nside('magwell', [(2985, 1000), (3470, 1000), (3470, 1600), (2985, 1600)], 11.0, None)] + guard_slim, 'DIFFERENCE')
wr.bevel(lower, 0.0005, 2, 30)
body.append(lower)
# Flared lip around the bottom of the magwell (forged in on the real lower).
flare = part('magwell_flare', MW_HALF + 0.7, M['anod'], [(2966, 1524.6), (3446, 1478.0), (3446, 1452.0), (2966, 1498.6)])
wr.boolean(flare, nside('flare_hole', [(2985, 1000), (3470, 1000), (3470, 1600), (2985, 1600)], 11.0, None), 'DIFFERENCE')
wr.bevel(flare, 0.0005, 2, 30)
body.append(flare)
TRIG = [(2665, 1292), (2742, 1285), (2705, 1318), (2689, 1358), (2689, 1416), (2713, 1470), (2702, 1475), (2687, 1460), (2657, 1404), (2651, 1374), (2651, 1340)]
body.append(nside('trigger', TRIG, 2.6, M['steel']))
for s in (1, -1):
    for xpin in (2303, 3500):
        body.append(cyl_z('pin', D(xpin), H(1080), s * MW_HALF, s * (MW_HALF + 1.0), 2.6, M['steel']))
    body.append(cyl_z('trigger_pin', D(2740), H(1190), s * L_HALF, s * (L_HALF + 0.8), 1.6, M['steel'], 16))
    body.append(cyl_z('hammer_pin', D(2560), H(1140), s * L_HALF, s * (L_HALF + 0.8), 1.6, M['steel'], 16))
body.append(cyl_z('mag_release', D(2940), H(1200), -MW_HALF, -MW_HALF - 2.4, 4.6, M['steel'], 32))
fence = nside('mag_fence', [(2880, 1135), (3000, 1135), (3000, 1265), (2880, 1265)], 1.0, M['anod'], z=-MW_HALF - 0.8)
wr.boolean(fence, nside('fence_hole', [(2900, 1155), (2980, 1155), (2980, 1245), (2900, 1245)], 3, None, z=-MW_HALF - 0.8), 'DIFFERENCE')
body.append(fence)
# Left side: bolt catch, selector with SAFE / SEMI / AUTO, roll marks.
body.append(nside('bolt_catch', [(2905, 1065), (2990, 1065), (2990, 1170), (2950, 1205), (2905, 1170)], 0.9, M['steel'], z=MW_HALF + 0.6))
sel_d, sel_y = N(2490, 1170)
body.append(cyl_z('selector_drum', sel_d, sel_y, L_HALF, L_HALF + 1.4, 5.2, M['steel'], 32))
# Lever on SAFE: horizontal, thumb paddle to the rear, pointer forward. The
# markings arc over the selector as on an M16/M4 lower: SAFE forward, SEMI
# on top, AUTO to the rear.
body.append(side('selector_lever', [(sel_d - 8, sel_y + 1.6), (sel_d - 9.5, sel_y), (sel_d - 8, sel_y - 1.6), (sel_d + 4, sel_y - 2.6), (sel_d + 12, sel_y - 2.8), (sel_d + 13.8, sel_y - 1.2), (sel_d + 13.8, sel_y + 1.2), (sel_d + 12, sel_y + 2.8), (sel_d + 4, sel_y + 2.6)], 1.0, M['steel'], z=L_HALF + 2.2))
body.append(wr.text('sel_safe', 'SAFE', P(sel_d - 12.5, sel_y + 6.5, L_HALF + 0.03), 0.0024, M['paint'], 1, rotate=math.radians(-35)))
body.append(wr.text('sel_semi', 'SEMI', P(sel_d, sel_y + 11.5, L_HALF + 0.03), 0.0024, M['paint'], 1))
body.append(wr.text('sel_auto', 'AUTO', P(sel_d + 12.5, sel_y + 6.5, L_HALF + 0.03), 0.0024, M['paint'], 1, rotate=math.radians(35)))
mk_d = D(3230)
body.append(wr.text('mk_maker', 'RAIDEN ARMS', P(mk_d, SEAM - 6.0, MW_HALF + 0.03), 0.0030, M['mark'], 1))
body.append(wr.text('mk_model', 'R-56 CARBINE', P(mk_d, SEAM - 11.5, MW_HALF + 0.03), 0.0024, M['mark'], 1))
body.append(wr.text('mk_cal', 'CAL 5.56 MM', P(mk_d, SEAM - 16.0, MW_HALF + 0.03), 0.0024, M['mark'], 1))
grip = part('grip', 16.5, M['poly'], [(2240, 1290), (2610, 1290), (2610, 1515), (2480, 1690), (2330, 2010), (1880, 2010), (1880, 1880), (2240, 1385)])
# A2 grip section: egg-shaped (slim front strap, full backstrap), 28 mm at the
# palm, drawing in toward the heel; built along the grip's own rake.
_gp = [clip_convex(OUTLINE, [N(x, y) for x, y in piece]) for piece in
       ([(2240, 1290), (2610, 1290), (2610, 1515), (2480, 1690), (2330, 2010), (2240, 2010)], [(2240, 1385), (2240, 2010), (1880, 2010), (1880, 1880)])]
wr.boolean(grip, grip_loft('grip_sec', P, _gp, 13.2, 14.3, 12.4), 'INTERSECT')
wr.moulded(grip, voxel=0.0006, smooth_factor=0.6, smooth_iter=8, ratio=0.12)
wr.assign_faces(grip, M['grip'], lambda x, y, z: abs(z) * 1000 > 9.0 and (y - BY) * 1000 < -62)
body.append(grip)

# ------------------------------------------------ buffer tube and SOPMOD stock ----
TUBE_Y = H(924)
body.append(lathe('buffer_tube', P, OUTLINE, D(2045), D(1745), 1.0, M['anod'], axis_y=TUBE_Y, symmetric=False, reach=25.0))
castle = cyl('castle_nut', D(2075), D(2010), 17.0, M['steel'], y=TUBE_Y, seg=48)
notches = []
for k in range(3):
    th = math.radians(90 + 120 * k)
    c, sn = math.cos(th), math.sin(th)
    pts = [(c * r - sn * t, TUBE_Y + sn * r + c * t) for r, t in ((14.0, -2.4), (19.0, -2.4), (19.0, 2.4), (14.0, 2.4))]
    notches.append(sec('castle_notch', pts, D(2010) - 3.8, D(2010) + 1.0))
wr.boolean(castle, notches, 'DIFFERENCE')
body.append(castle)
body.append(cyl('end_plate', D(2085), D(2070), 18.6, M['steel'], y=TUBE_Y - 1.0, seg=48))
stock = part('stock', 27.0, M['poly'], [(320, 790), (1740, 790), (1740, 1740), (320, 1740)])
for hole in ('stock_slot', 'sling_slot'):
    wr.boolean(stock, nside(hole, REF[hole], 60, None), 'DIFFERENCE')
taper = sec('stock_taper', [(-7.5, 14.0), (7.5, 14.0), (12.5, 12.4), (16.2, 9.0), (19.0, 4.0), (25.8, -11.0), (27.4, -19.0), (27.9, -25.0), (27.4, -31.0), (25.8, -39.0), (20.5, -50.0), (19.5, -150.0), (-19.5, -150.0), (-20.5, -50.0), (-25.8, -39.0), (-27.4, -31.0), (-27.9, -25.0), (-27.4, -19.0), (-25.8, -11.0), (-19.0, 4.0), (-16.2, 9.0), (-12.5, 12.4)], D(1745), D(310))
wr.moulded(stock, voxel=0.0008, smooth_factor=0.0, smooth_iter=0, ratio=1.0)
wr.boolean(stock, taper, 'INTERSECT', solver='MANIFOLD')
wr.boolean(stock, cyl('tube_bore', D(1750), D(900), 14.9, None, y=TUBE_Y, seg=40), 'DIFFERENCE', solver='MANIFOLD')
wr.moulded(stock, voxel=0.0008, smooth_factor=0.6, smooth_iter=8, ratio=0.12)
wr.clean_slots(stock, M['poly'])
# Rubber butt pad over the last 14 mm: bisect first so the joint is a clean line.
BUTT_D = D(320)
import bmesh
from mathutils import Vector
_bm = bmesh.new()
_bm.from_mesh(stock.data)
bmesh.ops.bisect_plane(_bm, geom=_bm.verts[:] + _bm.edges[:] + _bm.faces[:], plane_co=wr.cv(P(BUTT_D - 14.0, 0)), plane_no=Vector((1, 0, 0)))
_bm.to_mesh(stock.data)
_bm.free()
wr.assign_faces(stock, M['pad'], lambda x, y, z: (x - XM) * 1000 > BUTT_D - 14.0)
body.append(stock)
for s in (1, -1):
    body.append(cyl('battery_cap', D(1720), D(1680), 8.8, M['poly'], y=TUBE_Y - 21.0, z=s * 16.5, seg=32))
    body.append(cyl_z('qd_socket', D(1100), H(1120), s * 22.0, s * 24.6, 6.4, M['steel']))

# ------------------------------------------------------------- RIS II handguard ----
H_D0, H_D1 = D(5845), D(3545)
HB = H(1100)
HY = (RAIL_TOP + HB) / 2
HR = (RAIL_TOP - HB) / 2 - 3.5
hg_sec = [(23.0 * math.cos(2 * math.pi * (k + 0.5) / 16), HY + HR * math.sin(2 * math.pi * (k + 0.5) / 16)) for k in range(16)]
hg = sec('handguard_body', hg_sec, H_D0 + 3, H_D1 - 1, M['rail'])
wr.boolean(hg, cyl('hg_bore', H_D0 - 5, H_D1 + 5, 15.0, None, seg=32), 'DIFFERENCE')
# The RIS II has no vent holes: it is a two-piece clamshell (the lower rail
# half comes off for the M203) joined by six bolts, three a side, below the
# side rails. The split is a real part line through the wall.
SPLIT_Y = HY - 13.2
wr.boolean(hg, [sec('ris_split', [(s * 15.5, SPLIT_Y - 0.35), (s * 26.0, SPLIT_Y - 0.35), (s * 26.0, SPLIT_Y + 0.35), (s * 15.5, SPLIT_Y + 0.35)], H_D0 - 5, H_D1 + 5) for s in (1, -1)], 'DIFFERENCE')
wr.bevel(hg, 0.0005, 2, 30)
body.append(hg)
# Chamfer face at -45 deg between vertices (k=-1.5, -2.5) of the 16-gon.
a0, a1 = math.radians(-33.75), math.radians(-56.25)
fa = (23.0 * math.cos(a0), HY + HR * math.sin(a0))
fb = (23.0 * math.cos(a1), HY + HR * math.sin(a1))
fc = ((fa[0] + fb[0]) / 2, (fa[1] + fb[1]) / 2)
fn = (fa[1] - fb[1], fa[0] - fb[0])
fl = math.hypot(*fn)
fn = (fn[0] / fl, -fn[1] / fl)
for s in (1, -1):
    for dd in (H_D0 + 22.0, (H_D0 + H_D1) / 2 + 10.0, H_D1 - 22.0):
        cz, cy = s * fc[0], fc[1]
        nz, ny = s * fn[0], fn[1]
        head = wr.cylinder('ris_bolt', P(dd, cy - ny * 0.6, cz - nz * 0.6), P(dd, cy + ny * 1.7, cz + nz * 1.7), 0.0029, M['steel'], 24)
        wr.boolean(head, wr.cylinder('hex', P(dd, cy + ny * 0.6, cz + nz * 0.6), P(dd, cy + ny * 2.5, cz + nz * 2.5), 0.0013, None, 6), 'DIFFERENCE')
        body.append(head)
# Mk12-style low-profile gas block and gas tube, seen through the open front.
GB_D = 222.0
gb = cyl('gas_block', GB_D - 11, GB_D + 11, 12.6, M['steel'], y=1.6, seg=32)
wr.boolean(gb, sec('gb_flat', [(-20, 13.6), (20, 13.6), (20, 30), (-20, 30)], GB_D - 15, GB_D + 15), 'DIFFERENCE')
body.append(gb)
body.append(cyl('gas_tube', GB_D + 8, H_D1 + 6, 2.3, M['steel'], y=11.6, seg=14))
body.append(rail('rail_top', H_D0, H_D1, RAIL_TOP, M['rail'], first=H_D0 + 4.0))
for ang in (90, 180, 270):
    r = rail('rail_%d' % ang, H_D0 + 3, H_D1 - 3, RAIL_TOP, M['rail'], first=H_D0 + 7.0)
    rot_x(r, ang, HY)
    body.append(r)
for s in (1, -1):
    # Full-length moulded panel cover (no ladder slits: at game distance they
    # read as a barcode stripe), domed outward with rounded ends.
    dome = [(s * (24.5 + 5.0 * math.cos(math.pi * (k / 10 - 0.5))), HY + 8.5 * math.sin(math.pi * (k / 10 - 0.5))) for k in range(11)]
    cov = sec('rail_cover', [(s * 24.5, HY - 8.5)] + dome[1:-1] + [(s * 24.5, HY + 8.5)], H_D0 + 60, H_D0 + 170, M['cover'])
    wr.bevel(cov, 0.0012, 3, 30)
    body.append(cov)
body.append(cyl('barrel_nut', H_D1 - 2, H_D1 + 3, 17.4, M['anod'], y=0.6, seg=48))
# The handguard's top rail carries its own slot numbers (left face of the rail).
for i in range(10):
    body.append(wr.text('rail_no', '%d' % (1 + 3 * i), P(H_D0 + 9.0 + 30.0 * i, RAIL_TOP - 3.4, 10.62), 0.0022, M['mark'], 1))

# ------------------------------------------------------ barrel and A2 birdcage ----
# Muzzle end of the M4A1 barrel: 0.75 in (the traced lathe picked up the rail's
# front face here and made a 58 mm disc). Crown sits inside the birdcage.
body.append(cyl('barrel', 45.0, H_D0 + 6.0, 9.3, M['steel'], seg=40))
body.append(cyl('barrel_under_rail', H_D0, H_D1, 9.4, M['steel'], seg=36))
# A2 birdcage: 22 mm body, hollow expansion chamber open at the front, five
# through-slots over the top and sides (bottom closed so it does not kick up
# dust prone), solid rear with the bullet bore, chamfered shoulder.
fh = wr.tube('flash_hider', P(0.0, 0), P(29.0, 0), 0.0111, 0.0064, M['steel'], 48)
slots = []
for k in range(5):
    th = math.radians(-144 + 72 * k)
    c, sn = math.cos(th), math.sin(th)
    w2, r0, r1 = 1.2, 4.0, 13.0
    poly = [(-w2 * c + r0 * sn, r0 * c + w2 * sn), (w2 * c + r0 * sn, r0 * c - w2 * sn), (w2 * c + r1 * sn, r1 * c - w2 * sn), (-w2 * c + r1 * sn, r1 * c + w2 * sn)]
    slots.append(sec('fh_slot', poly, 4.5, 25.5))
wr.boolean(fh, slots, 'DIFFERENCE')
wr.bevel(fh, 0.00025, 2, 40)
body.append(fh)
fh_rear = wr.tube('flash_hider_rear', P(29.0, 0), P(47.0, 0), 0.0111, 0.0031, M['steel'], 48)
body.append(fh_rear)
body.append(cyl('flash_hider_shoulder', 47.0, 56.0, 11.1, M['steel'], seg=48, r1=9.6))
body.append(cyl('crush_washer', 56.0, 57.4, 9.8, M['steel'], seg=40))

# ----------------------------------------------------------------- action ----
act = [cyl('carrier', D(3445), D(2400), 7.4, M['bolt'], y=1.0, seg=40)]
for k in range(9):
    dk = D(2990 - k * 18)
    act.append(side('fa_serration', [(dk, -1.2), (dk + 1.3, -1.2), (dk + 1.3, 6.0), (dk, 6.0)], 0.6, M['steel'], z=-7.4))
act.append(cyl_z('cam_pin', D(3270), 6.0, -1, -8.4, 2.3, M['steel']))
act.append(side('extractor', [(D(3445), 2.0), (D(3280), 2.0), (D(3280), 5.6), (D(3445), 5.6)], 0.5, M['steel'], z=-6.0))
action = wr.join('Action', act)

# --------------------------------------------------------------- magazine ----
# The traced magazine edges carry +-1 mm pixel zigzags that moulded into fake
# horizontal ribs; the PMAG's front and back spines are smooth curves, so the
# silhouette is refit as two quadratic curves through the traced points.
def qbez(p0, c, p2, n=14):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p2[1]) for t in (i / n for i in range(n + 1))]


MAG_FRONT = qbez((3445, 1468), (3489, 1852), (3581, 2172))
MAG_REAR = qbez((3102, 2290), (3011, 1929), (2977, 1594))
MAG_POLY = MAG_FRONT + [(3575, 2195), (3550, 2210), (3140, 2328), (3115, 2318)] + MAG_REAR + [(2955, 1550), (2955, 1468)]
mag = nside('pmag', MAG_POLY, 11.4, M['mag'])
mag = wr.join('pmag', [mag, nside('mag_body_top', [(2990, 1040), (3460, 1040), (3460, 1470), (2990, 1470)], 11.0, M['mag'])])
wr.moulded(mag, voxel=0.0006, smooth_factor=0.5, smooth_iter=6, ratio=0.12)
wr.boolean(mag, [nside('grip_panel', [(3080, 1680), (3330, 1640), (3400, 2000), (3160, 2060)], 0.7, None, z=s * 11.4) for s in (1, -1)], 'DIFFERENCE', solver='MANIFOLD')
wr.clean_slots(mag, M['mag'])
mag_parts = [mag, wr.text('mag_logo', 'R-56  30', P(*N(3280, 1560), -11.6), 0.0034, M['mag'], -1, depth=0.0002)]
# PMAG floorplate: separate slide-on plate, a little wider than the body, with
# a lip standing proud at the front and back.
fa_, fb_ = (3577.0, 2190.0), (3110.0, 2326.0)
ux, uy = fb_[0] - fa_[0], fb_[1] - fa_[1]
ul = math.hypot(ux, uy)
ux, uy = ux / ul, uy / ul
nx, ny = uy, -ux  # points up into the magazine (image y grows downward)
if ny > 0:
    nx, ny = -nx, -ny
fp = [(fa_[0] - ux * 12 - nx * 6, fa_[1] - uy * 12 - ny * 6), (fb_[0] + ux * 10 - nx * 6, fb_[1] + uy * 10 - ny * 6),
      (fb_[0] + ux * 10 + nx * 44, fb_[1] + uy * 10 + ny * 44), (fa_[0] - ux * 12 + nx * 44, fa_[1] - uy * 12 + ny * 44)]
floor = nside('pmag_floorplate', fp, 12.2, M['mag'])
wr.bevel(floor, 0.0006, 2, 30)
mag_parts.append(floor)
mag_parts.append(cyl('round_case', D(3440), D(3120), 4.8, M['brass'], y=SEAM + 6.5, z=-2.2, seg=20))
mag_parts.append(cyl('round_bullet', D(3120), D(3010), 2.85, M['brass'], y=SEAM + 6.5, z=-2.2, seg=20, r1=0.8))
magazine = wr.join('Magazine', mag_parts)

# ------------------------------------------------- KAC flip-up iron sights ----
irons = []
RT = RAIL_TOP


def clamp_base(name, d0, d1, top):
    """Rail clamp: jaws hook under both sides of the 1913 rail, chamfered top."""
    b = sec(name, [(-12.4, RT - 5.6), (-11.0, RT - 6.4), (11.0, RT - 6.4), (12.4, RT - 5.6), (12.4, top - 2.2), (10.2, top), (-10.2, top), (-12.4, top - 2.2)], d0, d1, M['sight'])
    wr.bevel(b, 0.0006, 2, 30)
    return b


def cross_bolt(dd, y):
    """Clamp cross bolt: thumb nut on the left, slotted head on the right."""
    nut = cyl_z('clamp_nut', dd, y, 12.2, 15.6, 4.6, M['sight'], 32)
    head = cyl_z('clamp_bolt', dd, y, -12.2, -13.6, 3.6, M['sight'], 24)
    wr.boolean(head, side('bolt_slot', [(dd - 3.8, y - 0.45), (dd + 3.8, y - 0.45), (dd + 3.8, y + 0.45), (dd - 3.8, y + 0.45)], 0.8, None, z=-13.6), 'DIFFERENCE')
    return [nut, head]


# KAC 600 m rear: clamp base, protective ears, thin dual-aperture leaf with the
# small (1.8 mm) peep in a countersunk boss, windage drum on the right.
RD = D(2180)
irons.append(clamp_base('rear_base', RD - 15, RD + 15, RT + 8.0))
irons += cross_bolt(RD + 7.5, RT - 1.6)
for sgn in (1, -1):
    ear = side('rear_ear', [(RD - 8, RT + 7), (RD + 8, RT + 7), (RD + 6, 66.0), (RD + 3.5, 70.5), (RD, 71.5), (RD - 3.5, 70.5), (RD - 6, 66.0)], 1.0, M['sight'], z=sgn * 7.4)
    wr.bevel(ear, 0.0003, 2, 30)
    irons.append(ear)
ap = side('rear_aperture', [(RD - 1.5, RT + 7), (RD + 1.5, RT + 7), (RD + 1.5, 68.5), (RD + 0.8, 70.4), (RD - 0.8, 70.4), (RD - 1.5, 68.5)], 4.4, M['sight'])
wr.boolean(ap, cyl('peep_boss', RD + 1.0, RD + 2.6, 3.4, M['sight'], y=66.0, seg=40), 'UNION')
wr.boolean(ap, [cyl('peep', RD - 10, RD + 10, 0.9, None, y=66.0, seg=32), cyl('peep_cs', RD + 0.4, RD + 2.7, 0.9, None, y=66.0, seg=40, r1=2.4)], 'DIFFERENCE')
irons.append(ap)
irons.append(cyl_z('windage_drum', RD - 4.0, RT + 13.0, -6.4, -11.8, 4.2, M['sight'], 32))
irons.append(cyl_z('windage_cap', RD - 4.0, RT + 13.0, -11.8, -12.6, 3.4, M['sight'], 24))
# KAC folding front: clamp base, ears joined by a bridge, round post on a
# threaded detent housing (post tip on the 66 mm sight line).
FD = D(5745)
irons.append(clamp_base('front_base', FD - 12, FD + 12, RT + 7.0))
irons += cross_bolt(FD + 5.0, RT - 1.6)
for sgn in (1, -1):
    wing = side('front_wing', [(FD - 6, RT + 6), (FD + 6, RT + 6), (FD + 4.5, 66.0), (FD + 2.6, 69.0), (FD - 2.6, 69.0), (FD - 4.5, 66.0)], 1.1, M['sight'], z=sgn * 6.4)
    wr.bevel(wing, 0.0003, 2, 30)
    irons.append(wing)
irons.append(side('front_bridge', [(FD - 6, RT + 6), (FD + 6, RT + 6), (FD + 5, RT + 12), (FD - 5, RT + 12)], 6.4, M['sight']))
irons.append(wr.cylinder('post_housing', P(FD, RT + 11.0, 0), P(FD, RT + 18.0, 0), 0.0024, M['sight'], 24))
irons.append(wr.cylinder('front_post', P(FD, RT + 12, 0), P(FD, 64.8, 0), 0.0009, M['sight'], 16, 0.0008))
irons.append(side('front_post_tip', [(FD - 0.85, 63.6), (FD + 0.85, 63.6), (FD + 0.75, 66.0), (FD - 0.75, 66.0)], 0.75, M['sight']))
iron_sights = wr.join('IronSights', irons)

for _o in body:
    _dims = _o.dimensions
    if max(_dims.y, _dims.z) > 0.075 and _dims.x < 0.05:
        print('BIGDISC', _o.name, tuple(round(v, 3) for v in _dims))
body_obj = wr.join('Body', body)
objs = [body_obj, action, magazine, iron_sights]
print('M4 verts', {o.name: len(o.data.vertices) for o in objs}, 'total', wr.stats(objs), 'RD', RD, 'FD', FD, 'rail', RAIL_TOP)
wr.export(OUT, objs)
print('EXPORTED', OUT)
