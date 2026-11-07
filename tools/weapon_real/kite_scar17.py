"""KITE / K-12 rebuilt as its real counterpart: FN SCAR 17S (SCAR-H), 7.62x51,
FDE upper/lower, side-folding stock, 20-round steel magazine, folding sights.

blender --background --python tools/weapon_real/kite_scar17.py
Proportions traced from "FN SCAR-L and SCAR-H.png" (Wikimedia Commons, lower
rifle, 0.385 px/mm from the 997 mm overall length; height checked against the
published 8.6 in). Frame: d = mm behind the muzzle, y = mm above the bore,
z = mm to the left.
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy
import wr

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / 'assets/weapons/kite/kite_geometry.glb'
XM, BY = -0.5317, 0.080
S = 0.385


def P(d, y, z=0.0):
    return (XM + d / 1000.0, BY + y / 1000.0, z / 1000.0)


def PX(x, yp):
    return ((404 - x) / S, (192.5 - yp) / S)


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


def rail_section(top, half_w=10.6, depth=8.0):
    t = top
    return [(-half_w + 1.1, t - depth), (half_w - 1.1, t - depth), (half_w - 1.1, t - 5.6), (half_w, t - 4.5), (half_w, t - 2.4), (half_w - 1.4, t), (-half_w + 1.4, t), (-half_w, t - 2.4), (-half_w, t - 4.5), (-half_w + 1.1, t - 5.6)]


def pic_rail(name, d0, d1, top, m, pitch=10.0):
    o = sec(name, rail_section(top), d0, d1, m)
    cuts = []
    c = d0 + 4.0
    while c + 5.2 < d1 - 3.0:
        cuts.append(sec('slot', [(-12, top - 3.0), (12, top - 3.0), (12, top + 2), (-12, top + 2)], c, c + 5.23, None))
        c += pitch
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
    upper=wr.mat('SCAR FDE anodised', (0.30, 0.24, 0.16), 0.3, 0.55),
    lower=wr.mat('SCAR FDE polymer', (0.30, 0.24, 0.16), 0.0, 0.62),
    grip=wr.mat('SCAR grip texture', (0.30, 0.24, 0.16), 0.0, 0.74),
    black=wr.mat('SCAR black steel', (0.04, 0.04, 0.042), 0.7, 0.45),
    rubber=wr.mat('SCAR rubber', (0.03, 0.03, 0.03), 0.0, 0.85),
    mag=wr.mat('SCAR magazine steel', (0.05, 0.05, 0.05), 0.6, 0.55),
    brass=wr.mat('SCAR brass', (0.72, 0.52, 0.24), 1.0, 0.3),
    bore=wr.mat('SCAR bore', (0.01, 0.01, 0.01), 0.8, 0.5),
    mark=wr.mat('SCAR marking', (0.18, 0.15, 0.11), 0.2, 0.6),
)
body = []
U0, U1, RT = 245.0, 790.0, 58.5

# ------------------------------------------------- monolithic upper receiver ----
up_sec = [(-17.0, -26.0), (17.0, -26.0), (19.5, -20.0), (19.5, 18.0), (21.5, 22.0), (21.5, 40.0), (17.0, 48.0), (10.0, 50.5), (-10.0, 50.5), (-17.0, 48.0), (-21.5, 40.0), (-21.5, 22.0), (-19.5, 18.0), (-19.5, -20.0)]
upper = sec('upper', up_sec, U0, U1, M['upper'])
cuts = [side('eject_port', [(560.0, 0.0), (640.0, 0.0), (640.0, 24.0), (560.0, 24.0)], 4.0, None, z=-21.5),
        side('ch_slot', [(300.0, 22.0), (640.0, 22.0), (640.0, 32.0), (300.0, 32.0)], 4.0, None, z=21.5),
        cyl('barrel_tunnel', U0 - 5, U0 + 120, 14.0, None, seg=32)]
for k in range(4):
    for sgn in (1, -1):
        cuts.append(side('relief', [(270.0 + k * 40, -16.0), (300.0 + k * 40, -16.0), (300.0 + k * 40, 4.0), (270.0 + k * 40, 4.0)], 2.0, None, z=sgn * 19.5))
wr.boolean(upper, cuts, 'DIFFERENCE')
wr.bevel(upper, 0.0006, 2, 30)
body.append(upper)
body.append(pic_rail('top_rail', U0 + 2, U1 - 4, RT, M['upper']))
for ang, d0, d1 in ((90, 255.0, 420.0), (270, 255.0, 420.0), (180, 255.0, 470.0)):
    r = pic_rail('rail_%d' % ang, d0, d1, 6.0 + 20.0 + 8.0, M['black'])
    rot_x(r, ang, 6.0)
    body.append(r)
body.append(wr.text('mk_upper', 'K-12   7.62x51', P(470.0, 30.0, 21.55), 0.004, M['mark'], 1))
# Left-side reciprocating charging handle.
ch = side('charging_handle', [(318.0, 23.0), (342.0, 23.0), (342.0, 31.0), (318.0, 31.0)], 7.0, M['black'], z=31.0)
wr.bevel(ch, 0.0006, 2, 30)
body.append(ch)
body.append(cyl_z('ch_knob', 330.0, 27.0, 36.0, 44.0, 6.0, M['black'], 24))
body.append(side('bolt_in_port', [(562.0, 2.0), (638.0, 2.0), (638.0, 22.0), (562.0, 22.0)], 1.0, M['black'], z=-18.0))

# ------------------------------------------------------- polymer lower ----
low = [(470.0, -24.0), (875.0, -24.0), PX(68, 174), PX(68, 210), (800.0, -45.0), PX(140, 213), (650.0, -55.0), (588.0, -55.0), (586.0, -70.0), (494.0, -70.0), (490.0, -40.0), (470.0, -36.0)]
lower = side('lower', low, 19.0, M['lower'])
wr.boolean(lower, side('magwell', [(500.0, -80.0), (580.0, -80.0), (580.0, -20.0), (500.0, -20.0)], 13.0, None), 'DIFFERENCE')
wr.bevel(lower, 0.0008, 2, 30)
body.append(lower)
guard = side('trigger_guard', [(588.0, -55.0), (596.0, -55.0), (600.0, -86.0), (640.0, -88.0), (650.0, -60.0), (660.0, -60.0), (650.0, -95.0), (596.0, -95.0), (586.0, -70.0)], 8.0, M['lower'])
wr.bevel(guard, 0.0008, 2, 30)
body.append(guard)
body.append(side('trigger', [(616.0, -52.0), (623.0, -52.0), (622.0, -62.0), (625.0, -72.0), (622.0, -76.0), (617.5, -64.0)], 2.8, M['black']))
GRIP = [PX(x, y) for x, y in [(140, 213), (152, 229), (148, 240), (144, 246), (138, 257), (128, 256), (118, 252), (116, 247), (120, 241), (128, 230), (136, 218)]]
grip = side('grip', GRIP, 15.5, M['lower'])
wr.moulded(grip, voxel=0.0006, smooth_factor=0.6, smooth_iter=8, ratio=0.12)
wr.assign_faces(grip, M['grip'], lambda x, y, z: (y - BY) * 1000 < -70 and abs(z) * 1000 > 9.5)
body.append(grip)
for sgn in (1, -1):
    body.append(cyl_z('safety_hub', 690.0, -36.0, sgn * 22.0, sgn * 23.6, 5.2, M['black']))
    body.append(side('safety_lever', [(688.0, -33.0), (712.0, -28.0), (713.0, -33.0), (690.0, -40.0)], 0.9, M['black'], z=sgn * 24.2))
    body.append(cyl_z('mag_button', 592.0, -42.0, sgn * 22.0, sgn * 24.0, 4.4, M['black']))
body.append(side('bolt_catch', [(586.0, -22.0), (602.0, -22.0), (602.0, -32.0), (586.0, -32.0)], 1.2, M['black'], z=23.0))
for sgn in (1, -1):
    body.append(cyl_z('lower_pin', 485.0, -30.0, sgn * 22.0, sgn * 22.8, 2.6, M['black'], 16))
    body.append(cyl_z('lower_pin', 780.0, -20.0, sgn * 22.0, sgn * 22.8, 2.6, M['black'], 16))

# -------------------------------------------------------------------- stock ----
hinge = side('stock_hinge', [(860.0, 40.0), (882.0, 40.0), (882.0, -42.0), (860.0, -42.0)], 21.0, M['black'])
wr.bevel(hinge, 0.0008, 2, 30)
body.append(hinge)
STK = [(880.0, 30.0), PX(64, 182), PX(28, 183), PX(22, 185), PX(20, 243), PX(28, 242), PX(36, 236), PX(44, 220), PX(48, 213), PX(52, 208), (880.0, -38.0)]
stock = side('stock', STK, 19.0, M['lower'])
for sgn in (1, -1):
    wr.boolean(stock, side('stock_recess', [(905.0, 10.0), (965.0, 10.0), (965.0, -60.0), (930.0, -30.0), (905.0, -25.0)], 3.0, None, z=sgn * 19.5), 'DIFFERENCE')
wr.moulded(stock, voxel=0.0008, smooth_factor=0.55, smooth_iter=8, ratio=0.1)
body.append(stock)
cheek = side('cheek_riser', [(895.0, 24.0), (975.0, 24.0), (975.0, 38.0), (960.0, 42.0), (905.0, 40.0), (895.0, 32.0)], 17.0, M['lower'])
wr.moulded(cheek, voxel=0.0008, smooth_factor=0.5, smooth_iter=6, ratio=0.15)
body.append(cheek)
pad = side('butt_pad', [PX(22, 184), PX(17, 186), PX(16, 200), PX(16, 240), PX(19, 245), PX(23, 244)], 19.5, M['rubber'])
wr.moulded(pad, voxel=0.0008, smooth_factor=0.5, smooth_iter=4, ratio=0.2)
body.append(pad)

# ---------------------------------------------- barrel and flash hider ----
body.append(cyl('barrel', 40.0, U0 + 30, 9.4, M['black'], seg=36))
body.append(cyl('barrel_shoulder', U0 - 25, U0 + 5, 12.0, M['black'], seg=36))
fh = wr.tube('flash_hider', P(-2.0, 0), P(44.0, 0), 0.0125, 0.0055, M['black'], 48)
slots = []
for k in range(3):
    th = math.radians(60 + 120 * k)
    c, sn = math.cos(th), math.sin(th)
    w2, r0, r1 = 1.5, 5.5, 14.0
    poly = [(-w2 * c + r0 * sn, r0 * c + w2 * sn), (w2 * c + r0 * sn, r0 * c - w2 * sn), (w2 * c + r1 * sn, r1 * c - w2 * sn), (-w2 * c + r1 * sn, r1 * c + w2 * sn)]
    slots.append(sec('fh_slot', poly, -3.0, 26.0, None))
wr.boolean(fh, slots, 'DIFFERENCE')
body.append(fh)
body.append(cyl('bore_shadow', 8.0, 14.0, 5.4, M['bore'], seg=24))

# ----------------------------------------------------------------- magazine ----
mag = side('mag', [(500.0, -24.0), (580.0, -24.0), (581.0, -150.0), (576.0, -164.0), (506.0, -168.0), (498.0, -150.0)], 12.0, M['mag'])
ribs = []
for sgn in (1, -1):
    for yy in (-95.0, -125.0):
        ribs.append(side('mag_rib', [(506.0, yy), (576.0, yy), (576.0, yy - 4.0), (506.0, yy - 4.0)], 0.6, M['mag'], z=sgn * 12.3))
mag = wr.join('mag', [mag] + ribs)
wr.bevel(mag, 0.0007, 2, 30)
mag_parts = [mag, side('mag_floor', [(497.0, -164.0), (584.0, -160.0), (584.0, -168.0), (500.0, -172.0)], 13.4, M['mag'])]
mag_parts.append(cyl('top_round', 574.0, 512.0, 5.9, M['brass'], y=-20.0, z=-3.5, seg=20))
magazine = wr.join('Kite_Magazine', mag_parts)

# --------------------------------------------------------- folding sights ----
irons = []
fb = plan('front_base', [(236.0, -10.6), (256.0, -10.6), (256.0, 10.6), (236.0, 10.6)], RT, RT + 8.0, M['black'])
irons.append(fb)
for sgn in (1, -1):
    irons.append(side('front_wing', [(239.0, RT + 7), (253.0, RT + 7), (250.0, 108.0), (242.0, 108.0)], 1.3, M['black'], z=sgn * 7.4))
irons.append(side('front_post', [(244.6, RT + 7), (247.4, RT + 7), (247.0, 95.0), (245.0, 95.0)], 1.0, M['black']))
rb = plan('rear_base', [(698.0, -10.6), (720.0, -10.6), (720.0, 10.6), (698.0, 10.6)], RT, RT + 8.0, M['black'])
irons.append(rb)
for sgn in (1, -1):
    irons.append(side('rear_wing', [(700.0, RT + 7), (718.0, RT + 7), (716.0, 100.0), (702.0, 100.0)], 1.3, M['black'], z=sgn * 8.0))
ap = side('rear_aperture', [(706.0, RT + 7), (712.0, RT + 7), (712.0, 100.0), (706.0, 100.0)], 5.6, M['black'])
wr.boolean(ap, cyl('peep', 700.0, 718.0, 1.0, None, y=95.0, seg=20), 'DIFFERENCE')
irons.append(ap)
iron_sights = wr.join('IronSights', irons)

body_obj = wr.join('Kite_Body', body)
objs = [body_obj, magazine, iron_sights]
print('SCAR verts', {o.name: len(o.data.vertices) for o in objs}, 'total', wr.stats(objs))
wr.export(OUT, objs)
print('EXPORTED', OUT)
