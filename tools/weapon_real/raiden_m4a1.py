"""RAIDEN / R-56 rebuilt as its real counterpart: Colt M4A1 carbine (SOPMOD
Block II layout: Daniel Defense RIS II 12.25 rail, KAC flip-up sights, B5
SOPMOD stock, PMAG 30 GEN M3, A2 grip, A2 birdcage), 5.56x45.

blender --background --python tools/weapon_real/raiden_m4a1.py
Proportions traced from the calibrated right-side photo "M4A1 SOPMOD Block
II.jpg" (Wikimedia Commons, 1.85 px/mm at quarter scale, RIS II = 311 mm),
completed with standard AR-15 dimensions (14.5 in barrel, MIL-STD-1913 rail,
1.148 in receiver extension). Frame: d = mm behind the barrel crown,
y = mm above the bore axis, z = mm to the left.
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy
import wr

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / 'assets/weapons/raiden_r56/raiden_r56_geometry.glb'
XM, BY = -0.411, 0.0665  # barrel crown X and bore height in the Godot assembly


def P(d, y, z=0.0):
    return (XM + d / 1000.0, BY + y / 1000.0, z / 1000.0)


def PX(x, yp):
    """Photo pixel (quarter scale) to (d, y) mm."""
    return ((1520 - x) / 1.85, (226 - yp) / 1.85)


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


def rail_section(top, half_w=10.6, depth=9.5):
    """MIL-STD-1913 cross-section (z, y) with its 45-degree dovetail flanks."""
    t = top
    return [(-half_w + 1.1, t - depth), (half_w - 1.1, t - depth), (half_w - 1.1, t - 5.6), (half_w, t - 4.5), (half_w, t - 2.4), (half_w - 1.4, t - 0.0), (-half_w + 1.4, t - 0.0), (-half_w, t - 2.4), (-half_w, t - 4.5), (-half_w + 1.1, t - 5.6)]


def rail(name, d0, d1, top, m, slots=True, pitch=10.0, first=None):
    o = sec(name, rail_section(top), d0, d1, m)
    if slots:
        cuts = []
        start = d0 + 3.5 if first is None else first
        k = 0
        while start + k * pitch + 5.2 < d1 - 2.5:
            c = start + k * pitch
            cuts.append(sec('slot', [(-12, top - 3.0), (12, top - 3.0), (12, top + 2), (-12, top + 2)], c, c + 5.23, None))
            k += 1
        if cuts:
            wr.boolean(o, cuts, 'DIFFERENCE')
    wr.bevel(o, 0.0002, 1, 30)
    return o


def rotate_rail(o, angle_deg, axis_y):
    """Rotate a rail about the bore-parallel axis at height axis_y (mm)."""
    import mathutils
    pivot = wr.cv(P(0, axis_y))
    rot = mathutils.Matrix.Rotation(math.radians(angle_deg), 4, 'X')
    o.matrix_world = mathutils.Matrix.Translation(pivot) @ rot @ mathutils.Matrix.Translation(-pivot) @ o.matrix_world
    wr.apply(o)
    return o


wr.reset()
M = dict(
    anod=wr.mat('M4 hard anodized', (0.05, 0.05, 0.052), 0.35, 0.55),
    rail=wr.mat('M4 rail anodized', (0.05, 0.05, 0.052), 0.35, 0.5),
    steel=wr.mat('M4 phosphate steel', (0.05, 0.052, 0.05), 0.6, 0.6),
    bolt=wr.mat('M4 bolt carrier', (0.06, 0.06, 0.06), 0.8, 0.4),
    poly=wr.mat('M4 polymer', (0.04, 0.04, 0.042), 0.0, 0.6),
    grip=wr.mat('M4 grip checkering', (0.04, 0.04, 0.042), 0.0, 0.66),
    mag=wr.mat('M4 PMAG polymer', (0.04, 0.04, 0.042), 0.0, 0.62),
    rubber=wr.mat('M4 rubber pad', (0.03, 0.03, 0.03), 0.0, 0.85),
    brass=wr.mat('M4 brass', (0.72, 0.52, 0.24), 1.0, 0.3),
    mark=wr.mat('M4 engraving', (0.35, 0.35, 0.34), 0.5, 0.5),
    paint=wr.mat('M4 selector paint', (0.85, 0.85, 0.82), 0.0, 0.5),
    dark=wr.mat('M4 recess', (0.01, 0.01, 0.01), 0.0, 0.8),
    sight=wr.mat('M4 sight steel', (0.06, 0.06, 0.06), 0.7, 0.45),
)
body = []

# -------------------------------------------------------- upper receiver ----
U0, U1, RAIL_TOP = 346.0, 516.0, 30.5
up_sec = [(-11.2, -19.0), (11.2, -19.0), (11.6, -8.0), (11.6, 8.0), (10.6, 14.0), (8.6, 20.6), (-8.6, 20.6), (-10.6, 14.0), (-11.6, 8.0), (-11.6, -8.0)]
upper = sec('upper', up_sec, U0 + 4, U1, M['anod'])
# Barrel-extension housing at the front of the upper (round, 1.37 in).
upper_front = cyl('upper_front_ring', U0, U0 + 14, 17.6, M['anod'], y=0.6, seg=48)
cuts = []
# Ejection port, right side, with the forward-assist notches visible behind.
cuts.append(side('ejection_port', [(398, -8.5), (452, -8.5), (452, 9.5), (398, 9.5)], 6, None, z=-11.6))
upper = wr.join('upper', [upper, upper_front])
wr.boolean(upper, cuts, 'DIFFERENCE')
wr.bevel(upper, 0.0005, 2, 30)
body.append(upper)
body.append(rail('upper_rail', U0 + 2, U1, RAIL_TOP, M['anod'], first=U0 + 6.0))
# Rail-slot index numbers are engraved on the left flank of the flat-top.
for i, n in enumerate(range(1, 17, 3)):
    body.append(wr.text('rail_no', 'T%d' % (n + 6), P(U0 + 8.5 + n * 10.0, RAIL_TOP - 3.4, 10.62), 0.0022, M['mark'], 1))
# Forward assist housing and plunger (right rear of the upper).
fa_axis_a, fa_axis_b = P(466, 8.0, -11.0), P(500, 10.0, -19.5)
body.append(wr.cylinder('forward_assist_housing', P(458, 7.5, -9.0), P(486, 9.0, -15.5), 0.0078, M['anod'], 32))
fa = wr.cylinder('forward_assist_knob', P(484, 9.0, -15.0), P(497, 9.8, -18.6), 0.0083, M['steel'], 40)
body.append(fa)
for k in range(10):
    a = 2 * math.pi * k / 10
    body.append(wr.box('fa_rib', P(490.5, 9.4 + 7.2 * math.cos(a), -16.8 + 7.2 * math.sin(a) * 0.3), (0.010, 0.0012, 0.0012), M['steel']))
# Brass deflector behind the port.
body.append(side('brass_deflector', [(452, 6.0), (468, 6.0), (468, 17.5), (460, 19.5), (452, 17.5)], 3.2, M['anod'], z=-12.6))
# Open dust cover hanging below the port, with its hinge rod.
body.append(cyl('dust_cover_rod', 392, 458, 1.3, M['steel'], y=-10.5, z=-11.8, seg=12))
dc = side('dust_cover', [(398, -10.0), (452, -10.0), (452, -22.0), (398, -22.0)], 0.6, M['steel'], z=-13.6)
body.append(dc)
# Charging handle (A2 style) and latch.
body.append(sec('charging_handle_shaft', [(-4.5, 14.0), (4.5, 14.0), (4.5, 20.0), (-4.5, 20.0)], U1 - 6, U1 + 18, M['anod']))
ch = plan('charging_handle_T', [(U1 + 14, -22.0), (U1 + 24, -22.0), (U1 + 26, -18), (U1 + 26, 18), (U1 + 24, 22.0), (U1 + 14, 22.0), (U1 + 12, 16), (U1 + 12, -16)], 13.5, 20.5, M['anod'])
wr.bevel(ch, 0.0008, 2, 30)
body.append(ch)
body.append(plan('charging_latch', [(U1 + 8, 6.0), (U1 + 22, 10.0), (U1 + 22, 26.0), (U1 + 14, 26.0)], 14.0, 20.0, M['anod']))

# -------------------------------------------------------- lower receiver ----
L_HALF = 11.0
low = [(340.0, -19.0), (536.0, -19.0), (536.0, -10.0), (528.0, -12.0), (528.0, -48.0), (500.0, -52.0), (476.0, -52.0), (424.0, -52.0), (424.0, -62.0), (418.0, -46.0), (350.0, -38.5), (346.0, -33.0), (340.0, -33.0)]
lower = side('lower', low, L_HALF, M['anod'])
# Magazine well (straight section) and its flared bottom.
magwell_cut = side('magwell_cut', [(353.0, -16.0), (419.5, -16.0), (419.5, -70.0), (353.0, -70.0)], 11.0, None)
wr.boolean(lower, magwell_cut, 'DIFFERENCE')
flare = sec('magwell_flare', [(-13.4, -19.2), (13.4, -19.2), (13.6, -41.0), (-13.6, -41.0)], 348, 421, M['anod'])
wr.boolean(flare, side('flare_cut', [(352, -15), (420, -15), (420, -50), (352, -50)], 10.9, None), 'DIFFERENCE')
wr.boolean(flare, side('flare_slope', [(330, -38.6), (430, -46.5), (430, -60), (330, -60)], 20, None), 'DIFFERENCE')
lower = wr.join('lower', [lower, flare])
boss = side('bolt_catch_boss', [(417.0, -12.0), (436.0, -12.0), (436.0, -38.0), (428.0, -44.0), (417.0, -38.0)], 1.4, M['anod'], z=10.4)
fence_r = side('mag_fence_rim', [(418.0, -22.0), (440.0, -22.0), (440.0, -44.0), (418.0, -44.0)], 1.0, M['anod'], z=-10.6)
wr.boolean(fence_r, side('fence_hole', [(421.0, -25.0), (437.0, -25.0), (437.0, -41.0), (421.0, -41.0)], 3, None, z=-10.6), 'DIFFERENCE')
lower = wr.join('lower', [lower, boss, fence_r])
wr.bevel(lower, 0.0005, 2, 30)
body.append(lower)
# Front pivot lug and pins.
for s in (1, -1):
    body.append(cyl_z('pivot_pin', 343.0, -26.0, s * 10.6, s * 11.8, 2.6, M['steel']))
    body.append(cyl_z('takedown_pin', 522.0, -26.0, s * 10.6, s * 11.8, 2.6, M['steel']))
    body.append(cyl_z('trigger_pin', 471.0, -37.0, s * 10.6, s * 11.3, 1.6, M['steel'], 16))
    body.append(cyl_z('hammer_pin', 491.0, -29.0, s * 10.6, s * 11.3, 1.6, M['steel'], 16))
# Magazine release button + fence (right) and bolt catch (left).
body.append(cyl_z('mag_release', 428.0, -33.0, -11.0, -13.4, 4.6, M['steel'], 32))
for dz in ():
    body.append(side('mag_fence', [(419.0 + (0 if dz < 0 else 14.0), -26.0), (423.0 + (0 if dz < 0 else 14.0), -26.0), (423.0 + (0 if dz < 0 else 14.0), -40.0), (419.0 + (0 if dz < 0 else 14.0), -40.0)], 1.2, M['anod'], z=-12.0))
catch = side('bolt_catch', [(420.0, -13.0), (432.0, -13.0), (432.0, -33.0), (426.0, -38.0), (420.0, -33.0)], 0.9, M['steel'], z=12.0)
wr.boolean(catch, [side('catch_rib', [(419, yy), (433, yy), (433, yy + 0.7), (419, yy + 0.7)], 0.5, None, z=12.9) for yy in (-34.5, -32.5)], 'DIFFERENCE')
body.append(catch)
# Selector (left) pointing at SAFE, with engraved positions.
body.append(cyl_z('selector_drum', 494.0, -27.0, 11.0, 12.4, 5.2, M['steel'], 32))
body.append(side('selector_lever', [(486.0, -24.6), (506.0, -26.0), (507.5, -27.5), (506.0, -29.0), (486.0, -29.4)], 1.0, M['steel'], z=13.2))
body.append(wr.text('sel_safe', 'SAFE', P(493.0, -14.8, 11.06), 0.0026, M['paint'], 1))
body.append(wr.text('sel_semi', 'SEMI', P(478.0, -21.5, 11.06), 0.0026, M['paint'], 1, rotate=math.radians(-35)))
body.append(wr.text('sel_auto', 'AUTO', P(479.5, -35.0, 11.06), 0.0026, M['paint'], 1, rotate=math.radians(35)))
# Left-side lower markings (maker, model, calibre, serial).
L = L_HALF + 0.03
body.append(wr.text('mk_maker', 'RAIDEN ARMS', P(392.0, -24.5, L), 0.0030, M['mark'], 1))
body.append(wr.text('mk_model', 'R-56 CARBINE', P(392.0, -30.0, L), 0.0024, M['mark'], 1))
body.append(wr.text('mk_cal', 'CAL 5.56 MM', P(392.0, -34.6, L), 0.0024, M['mark'], 1))
body.append(wr.text('mk_serial', 'R5 0473', P(456.0, -45.0, L), 0.0024, M['mark'], 1))
# Receiver-extension tower, castle nut, QD end plate and buffer tube.
body.append(cyl('buffer_tower', 520, 536, 15.6, M['anod'], y=-3.0, seg=48))
nut = cyl('castle_nut', 536, 546, 17.0, M['steel'], y=-3.0, seg=48)
wr.boolean(nut, [wr.box('nut_notch', P(536.5 + 0.0, -3.0 + 15.8 * math.cos(a), 16.0 * math.sin(a)), (0.008, 0.004, 0.004), None) for a in [k * math.pi / 4 for k in range(8)]], 'DIFFERENCE')
body.append(nut)
body.append(cyl('end_plate', 535.5, 538.0, 18.6, M['steel'], y=-4.0, seg=48))
body.append(cyl('buffer_tube', 536, 728, 14.6, M['anod'], y=-3.0, seg=48))
# Trigger guard (A2, separate part) and its roll pin.
tg = side('trigger_guard', [(420.0, -52.0), (424.0, -52.0), (424.0, -62.0), (428.0, -77.5), (472.0, -78.2), (480.0, -74.0), (480.0, -52.0), (484.0, -52.0), (484.0, -78.0), (476.0, -82.0), (428.0, -82.0), (420.0, -64.0)], 4.8, M['anod'])
wr.bevel(tg, 0.0006, 2, 30)
body.append(tg)
# Trigger (curved, steel).
trig = side('trigger', [(463.0, -51.0), (469.5, -51.0), (469.0, -58.0), (467.0, -64.0), (463.5, -69.5), (461.0, -71.5), (459.6, -70.2), (462.6, -64.0), (464.2, -58.0)], 2.6, M['steel'])
wr.bevel(trig, 0.0003, 2, 30)
body.append(trig)
# A2 pistol grip with finger swell and checkered panels (rounded by moulding).
gp = [PX(642, 338), PX(628, 360), PX(620, 391), PX(612, 402), PX(606, 414), PX(602, 428), PX(596, 440), PX(590, 452), PX(582, 476), PX(577, 497), PX(560, 500), PX(530, 493), PX(497, 482), PX(482, 476), PX(488, 458), PX(500, 441), PX(520, 411), PX(540, 381), PX(556, 356), PX(566, 338)]
grip = side('grip', gp, 13.6, M['poly'])
wr.moulded(grip, voxel=0.0006, smooth_factor=0.6, smooth_iter=8, ratio=0.25)


def checkered(x, y, z):
    d = (x - XM) * 1000
    yy = (y - BY) * 1000
    return abs(z) * 1000 > 9.0 and yy < -62 and yy > -142


wr.assign_faces(grip, M['grip'], checkered)
body.append(grip)

# ------------------------------------------------------------ handguard ----
H0, H1, HY = 32.0, 346.0, 3.2
hg_sec = []
for k in range(16):
    a = 2 * math.pi * (k + 0.5) / 16
    r = 26.8 / max(abs(math.cos(a)), abs(math.sin(a))) ** 0.18 if True else 26.8
    hg_sec.append((r * math.cos(a) * 0.86, HY + r * math.sin(a) * 0.86))
hg = sec('handguard_body', hg_sec, H0 + 3, H1 - 1, M['rail'])
wr.boolean(hg, cyl('hg_bore', H0 - 5, H1 + 5, 15.0, None, y=0.0, seg=32), 'DIFFERENCE')
# Ventilation between the rails along the bevelled corners.
vents = []
for k in range(9):
    dd = 70 + k * 30
    for s in (1, -1):
        for yv in (17.0, -11.0):
            vents.append(wr.cylinder('vent', P(dd, HY + (yv - HY) * 1.05, s * 30), P(dd, HY + (yv - HY) * 0.55, s * 12), 0.0034, None, 16))
wr.boolean(hg, vents, 'DIFFERENCE')
wr.bevel(hg, 0.0005, 2, 30)
body.append(hg)
top_rail = rail('rail_top', H0, H1, RAIL_TOP, M['rail'], first=H0 + 4.0)
body.append(top_rail)
for ang in (90, 180, 270):
    r = rail('rail_%d' % ang, H0 + 3, H1 - 3, RAIL_TOP, M['rail'], first=H0 + 7.0)
    rotate_rail(r, ang, HY)
    body.append(r)
# Barrel nut collar and RIS II front cap.
body.append(cyl('barrel_nut', H1 - 2, U0 + 1, 17.4, M['anod'], y=0.6, seg=48))
cap = cyl('front_cap', H0 - 1, H0 + 4, 24.0, M['rail'], y=HY, seg=48)
wr.boolean(cap, cyl('cap_bore', H0 - 3, H0 + 6, 9.0, None, seg=32), 'DIFFERENCE')
body.append(cap)

# ------------------------------------------------- barrel and flash hider ----
body.append(cyl('barrel', 10, H0 + 6, 7.35, M['steel'], seg=40))
fh = wr.tube('flash_hider', P(-44.5, 0), P(13.0, 0), 0.0111, 0.0042, M['steel'], 48)
slots = []
for k in range(5):
    th = math.radians(-144 + 72 * k)  # 0 = top; the 180-degree bottom stays closed
    c, sn = math.cos(th), math.sin(th)
    w2, r0, r1 = 1.35, 5.0, 13.0
    poly = [(-w2 * c + r0 * sn, r0 * c + w2 * sn), (w2 * c + r0 * sn, r0 * c - w2 * sn), (w2 * c + r1 * sn, r1 * c - w2 * sn), (-w2 * c + r1 * sn, r1 * c + w2 * sn)]
    slots.append(sec('fh_slot', poly, -38.0, -9.0, None))
wr.boolean(fh, slots, 'DIFFERENCE')
body.append(fh)
body.append(cyl('crush_washer', 12.0, 14.0, 8.6, M['steel'], seg=24))

# -------------------------------------------------------------- stock ----
STOCK = [PX(420, 202), PX(130, 204), PX(108, 205), PX(94, 210), PX(90, 240), PX(90, 420), PX(98, 430), PX(118, 430), PX(150, 403), PX(200, 367), PX(232, 345), PX(250, 350), PX(300, 330), PX(340, 327), PX(400, 300), PX(420, 284)]
stock = side('stock_body', STOCK, 21.0, M['poly'])
# Tube channel and the B5 SOPMOD battery tubes along both flanks.
for s in (1, -1):
    stock = wr.join('stock_body', [stock, cyl('battery_tube', 600, 745, 9.6, M['poly'], y=-24.0, z=s * 16.5, seg=32)])
taper = sec('stock_taper', [(-15.5, 14.0), (15.5, 14.0), (19.0, 4.0), (27.5, -14.0), (27.5, -36.0), (20.5, -50.0), (19.5, -112.0), (-19.5, -112.0), (-20.5, -50.0), (-27.5, -36.0), (-27.5, -14.0), (-19.0, 4.0)], 560, 790, None)
wr.moulded(stock, voxel=0.0008, smooth_factor=0.0, smooth_iter=0, ratio=1.0)
wr.boolean(stock, taper, 'INTERSECT', solver='MANIFOLD')
wr.moulded(stock, voxel=0.0008, smooth_factor=0.6, smooth_iter=6, ratio=0.25)
wr.boolean(stock, cyl('stock_tube_bore', 590, 760, 14.9, None, y=-3.0, seg=40), 'DIFFERENCE', solver='MANIFOLD')
wr.clean_slots(stock, M['poly'])
body.append(stock)
for s in (1, -1):
    body.append(cyl('battery_cap', 594, 601, 8.8, M['poly'], y=-24.0, z=s * 16.5, seg=32))
pad = side('butt_pad', [PX(90, 212), PX(84, 214), PX(80, 240), PX(80, 420), PX(86, 432), PX(92, 430), PX(92, 214)], 20.6, M['rubber'])
wr.moulded(pad, voxel=0.0007, smooth_factor=0.6, smooth_iter=5, ratio=0.3)
body.append(pad)
body.append(side('stock_latch', [PX(345, 328), PX(310, 328), PX(305, 344), PX(330, 346)], 4.0, M['poly']))
for s in (1, -1):
    body.append(cyl_z('qd_socket', 668.0, -30.0, s * 20.0, s * 23.2, 6.4, M['steel']))

# --------------------------------------------------------------- action ----
# Bolt carrier visible through the open port: phosphate carrier with the
# forward-assist serrations and the bolt face/extractor behind the chamber.
act = []
act.append(cyl('carrier', 404, 540, 7.4, M['bolt'], y=1.0, seg=40))
for k in range(9):
    act.append(side('fa_serration', [(464.0 + k * 2.6, -1.2), (465.3 + k * 2.6, -1.2), (465.3 + k * 2.6, 6.0), (464.0 + k * 2.6, 6.0)], 0.6, M['steel'], z=-7.4))
act.append(cyl('bolt_head', 396, 406, 6.2, M['steel'], y=0.0, seg=32))
act.append(cyl_z('cam_pin', 432.0, 6.0, -1, -8.4, 2.3, M['steel']))
act.append(side('extractor', [(396.0, 2.0), (420.0, 2.0), (420.0, 5.6), (396.0, 5.6)], 0.5, M['steel'], z=-6.0))
action = wr.join('Action', act)

# ------------------------------------------------------------- magazine ----
MAG = [(353.5, -20.0), (419.0, -20.0), (419.0, -42.0), PX(750, 452), PX(760, 495), PX(770, 539), PX(780, 581), PX(893, 551), PX(890, 525), PX(880, 490), PX(870, 441), PX(862, 380), (354.0, -42.0)]
mag = side('pmag', MAG, 10.4, M['mag'])
for s in (1, -1):
    # PMAG side texture panels and the window-less ribbed body.
    ribs = [side('mag_rib', [PX(808 - 14 * k, 340), PX(806 - 14 * k, 340), PX(818 - 14 * k, 470), PX(820 - 14 * k, 470)], 0.6, None, z=s * 11.0) for k in range(0)]
wr.moulded(mag, voxel=0.0006, smooth_factor=0.5, smooth_iter=4, ratio=0.12)
mag_parts = [mag]
bp = side('mag_floorplate', [PX(778, 572), PX(782, 585), PX(896, 556), PX(894, 545)], 12.4, M['mag'])
wr.bevel(bp, 0.0008, 2, 30)
mag_parts.append(bp)
mag_parts.append(wr.text('mag_logo', 'R-56  30', P(392.0, -95.0, 11.4), 0.0034, M['mag'], 1, depth=0.0002))
# Top cartridges in the feed lips.
mag_parts.append(cyl('round_case', 408, 363, 4.8, M['brass'], y=-15.5, z=-2.2, seg=20))
mag_parts.append(cyl('round_neck', 363, 352, 3.1, M['brass'], y=-15.5, z=-2.2, seg=20, r1=2.85))
mag_parts.append(cyl('round_bullet', 352, 339, 2.85, M['brass'], y=-15.5, z=-2.2, seg=20, r1=0.8))
magazine = wr.join('Magazine', mag_parts)

# ------------------------------------------------------- iron sights ----
irons = []
# KAC 600 m flip-up rear on the back of the flat-top.
rb = plan('rear_base', [(498, -11), (523, -11), (523, 11), (498, 11)], RAIL_TOP, RAIL_TOP + 8.0, M['sight'])
wr.bevel(rb, 0.0006, 2, 30)
irons.append(rb)
for sgn in (1, -1):
    irons.append(side('rear_ear', [(503, RAIL_TOP + 7), (517, RAIL_TOP + 7), (515, 69.0), (510, 72.0), (505, 69.0)], 1.0, M['sight'], z=sgn * 7.6))
ap = side('rear_aperture', [(508.0, RAIL_TOP + 7), (512.0, RAIL_TOP + 7), (512.0, 70.0), (508.0, 70.0)], 5.2, M['sight'])
wr.boolean(ap, wr.cylinder('peep', P(500, 66.0), P(520, 66.0), 0.0009, None, 20), 'DIFFERENCE')
irons.append(ap)
irons.append(cyl_z('rear_knob', 510.0, RAIL_TOP + 3.0, -11.0, -14.5, 4.2, M['sight'], 24))
# KAC folding front sight on the front of the top rail.
fb = plan('front_base', [(38, -11), (60, -11), (60, 11), (38, 11)], RAIL_TOP, RAIL_TOP + 7.0, M['sight'])
wr.bevel(fb, 0.0006, 2, 30)
irons.append(fb)
for s in (1, -1):
    irons.append(side('front_wing', [(44, RAIL_TOP + 5), (54, RAIL_TOP + 5), (52, 68.0), (46, 68.0)], 1.1, M['sight'], z=s * 6.2))
irons.append(side('front_post', [(47.6, RAIL_TOP + 5), (50.4, RAIL_TOP + 5), (50.0, 66.0), (48.0, 66.0)], 0.9, M['sight']))
iron_sights = wr.join('IronSights', irons)

body_obj = wr.join('Body', body)
objs = [body_obj, action, magazine, iron_sights]
print('M4 verts', {o.name: len(o.data.vertices) for o in objs}, 'total', wr.stats(objs))
wr.export(OUT, objs)
print('EXPORTED', OUT)
