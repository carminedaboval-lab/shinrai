"""YUZURU / YZ-10 rebuilt as its real counterpart: Accuracy International
Arctic Warfare (AW), 7.62x51, 10-round magazine, black thumbhole stock on the
aluminium chassis, muzzle brake and AW-pattern iron sights.

blender --background --python tools/weapon_real/yuzuru_aiaw.py
Built from published dimensions: overall 1180 mm (+ brake), barrel 660 mm,
mass about 6.5 kg. Frame: d = mm behind the barrel crown, y = mm above the
bore, z = mm to the left. Action origin on the bore axis (bolt-lift pivot).
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy, mathutils
import wr

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / 'assets/weapons/yuzuru/yuzuru_geometry.glb'
XM, BY = -0.760, 0.065
KEY = 'AW'


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


def rail_section(top, half_w=10.6, depth=9.5):
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


wr.reset()
M = dict(
    steel=wr.mat(KEY + ' black steel', (0.04, 0.04, 0.042), 0.72, 0.42),
    action=wr.mat(KEY + ' action finish', (0.05, 0.05, 0.05), 0.55, 0.55),
    alu=wr.mat(KEY + ' chassis alloy', (0.05, 0.05, 0.05), 0.4, 0.5),
    stock=wr.mat(KEY + ' stock polymer', (0.03, 0.03, 0.032), 0.0, 0.62),
    grip=wr.mat(KEY + ' grip texture', (0.03, 0.03, 0.032), 0.0, 0.72),
    rubber=wr.mat(KEY + ' butt pad', (0.03, 0.03, 0.03), 0.0, 0.85),
    bolt=wr.mat(KEY + ' bolt', (0.5, 0.5, 0.5), 1.0, 0.3),
    brass=wr.mat(KEY + ' brass', (0.72, 0.52, 0.24), 1.0, 0.3),
    bore=wr.mat(KEY + ' bore', (0.01, 0.01, 0.01), 0.8, 0.5),
    mark=wr.mat(KEY + ' engraving', (0.35, 0.35, 0.34), 0.6, 0.5),
)
body = []
RF, RR, RRAD = 655.0, 862.0, 17.0

# ------------------------------------------------------ barrel and brake ----
barrel = wr.loft('barrel', [[P(d, r * math.sin(2 * math.pi * k / 40), r * math.cos(2 * math.pi * k / 40)) for k in range(40)] for d, r in ((0.0, 11.3), (320.0, 11.6), (560.0, 14.2), (RF + 4, 15.2))], M['steel'])
wr.smooth(barrel, 40)
body.append(barrel)
brake = wr.tube('muzzle_brake', P(-52.0, 0), P(6.0, 0), 0.0132, 0.0055, M['steel'], 48)
ports = []
for k in range(2):
    for sgn in (1, -1):
        ports.append(side('brake_port', [(-44.0 + k * 20, -6.0), (-32.0 + k * 20, -6.0), (-32.0 + k * 20, 6.0), (-44.0 + k * 20, 6.0)], 6.0, None, z=sgn * 10.0))
wr.boolean(brake, ports, 'DIFFERENCE')
body.append(brake)
body.append(cyl('bore_shadow', -46.0, -40.0, 5.4, M['bore'], seg=24))

# ------------------------------------------------------------- receiver ----
rec = sec('receiver', [(z, y) for z, y in wr.superellipse(0.0, 0.0, 2 * RRAD + 1.0, 2 * RRAD, 3.4, 40)], RF, RR, M['action'])
wr.boolean(rec, [side('ejection_port', [(700.0, 2.0), (780.0, 2.0), (780.0, 30.0), (700.0, 30.0)], 9.0, None, z=-8.0),
                 side('handle_slot', [(780.0, -6.0), (RR + 2, -6.0), (RR + 2, 2.0), (780.0, 2.0)], 6.0, None, z=-15.0),
                 plan('mag_opening', [(706.0, -11.0), (788.0, -11.0), (788.0, 11.0), (706.0, 11.0)], -30.0, -8.0, None)], 'DIFFERENCE')
wr.bevel(rec, 0.0004, 2, 30)
body.append(rec)
body.append(pic_rail('rail', RF - 2, RR + 6, 27.0, M['action']))
body.append(sec('rail_base', [(-10.0, 14.0), (10.0, 14.0), (10.0, 18.6), (-10.0, 18.6)], RF - 2, RR + 6, M['action']))
body.append(wr.text('rec_mark', 'YZ-10   7.62 NATO', P(745.0, 7.0, 17.6), 0.0027, M['mark'], 1))
body.append(side('bolt_release', [(842.0, -3.0), (858.0, -3.0), (858.0, 5.0), (842.0, 5.0)], 1.3, M['steel'], z=18.2))

# --------------------------------------------------------------- chassis ----
# Aluminium bedding chassis visible between the stock halves.
ch = side('chassis', [(560.0, -16.0), (900.0, -16.0), (900.0, -34.0), (560.0, -30.0)], 24.0, M['alu'])
wr.boolean(ch, [cyl('chan', 540.0, RR + 10, 17.6, None, seg=40), plan('ch_well', [(704.0, -12.0), (790.0, -12.0), (790.0, 12.0), (704.0, 12.0)], -60.0, -10.0, None)], 'DIFFERENCE')
wr.bevel(ch, 0.0005, 2, 30)
body.append(ch)
for dd in (600.0, 680.0, 820.0, 885.0):
    for sgn in (1, -1):
        body.append(cyl_z('stock_bolt', dd, -24.0, sgn * 24.0, sgn * 25.6, 4.2, M['steel'], 6))

# ------------------------------------------------------------------ stock ----
STK = [(380.0, -18.0), (560.0, -14.0), (560.0, -16.0), (900.0, -10.0), (930.0, -2.0), (1000.0, 8.0), (1160.0, 8.0), (1160.0, -138.0), (1140.0, -142.0), (1100.0, -126.0), (1080.0, -128.0), (1060.0, -140.0), (1030.0, -130.0), (960.0, -104.0), (930.0, -150.0), (902.0, -156.0), (884.0, -150.0), (880.0, -112.0), (872.0, -62.0), (850.0, -60.0), (640.0, -58.0), (420.0, -54.0), (384.0, -44.0)]
stock = side('stock', STK, 27.0, M['stock'])
hole = side('thumbhole', [(918.0, -48.0), (972.0, -40.0), (995.0, -52.0), (985.0, -96.0), (958.0, -98.0), (930.0, -104.0), (916.0, -80.0)], 40, None)
wr.boolean(stock, hole, 'DIFFERENCE')
shape = wr.join('stock_shape', [
    sec('fore_section', [(-26.0, -60.0), (26.0, -60.0), (26.0, -18.0), (20.0, -6.0), (-20.0, -6.0), (-26.0, -18.0)], 370.0, 900.0, None),
    sec('butt_section', [(-21.0, -170.0), (21.0, -170.0), (22.0, -4.0), (16.0, 12.0), (-16.0, 12.0), (-22.0, -4.0)], 880.0, 1180.0, None),
    sec('grip_section', [(-16.0, -170.0), (16.0, -170.0), (17.0, -50.0), (-17.0, -50.0)], 860.0, 940.0, None)])
wr.moulded(shape, voxel=0.001, smooth_factor=0.0, smooth_iter=0, ratio=1.0)
wr.moulded(stock, voxel=0.001, smooth_factor=0.0, smooth_iter=0, ratio=1.0)
wr.boolean(stock, shape, 'INTERSECT', solver='MANIFOLD')
# Fore-end slots (AW stock), barrel channel and chassis inletting.
cuts = [cyl('barrel_channel', 360.0, RF + 4, 17.0, None, seg=32), side('chassis_inlet', [(555.0, -12.0), (905.0, -6.0), (905.0, -36.0), (555.0, -34.0)], 24.6, None)]
for k in range(4):
    for sgn in (1, -1):
        cuts.append(side('fore_slot', [(430.0 + k * 34, -28.0), (452.0 + k * 34, -28.0), (452.0 + k * 34, -42.0), (430.0 + k * 34, -42.0)], 3.0, None, z=sgn * 26.0))
wr.boolean(stock, cuts, 'DIFFERENCE', solver='MANIFOLD')
wr.moulded(stock, voxel=0.0006, smooth_factor=0.6, smooth_iter=14, ratio=0.07)
wr.assign_faces(stock, M['grip'], lambda x, y, z: 860 < (x - XM) * 1000 < 930 and (y - BY) * 1000 < -55)
body.append(stock)
body.append(side('lop_spacer', [(1160.0, 8.0), (1168.0, 8.0), (1168.0, -138.0), (1160.0, -138.0)], 20.5, M['alu']))
pad = side('butt_pad', [(1168.0, 9.0), (1178.0, 6.0), (1180.0, -20.0), (1180.0, -136.0), (1174.0, -142.0), (1168.0, -140.0)], 21.0, M['rubber'])
wr.moulded(pad, voxel=0.0009, smooth_factor=0.5, smooth_iter=4, ratio=0.15)
body.append(pad)
# Trigger guard (moulded into the stock on the AW) and trigger.
tg = side('trigger_guard', [(818.0, -58.0), (826.0, -58.0), (830.0, -78.0), (868.0, -78.0), (872.0, -60.0), (880.0, -60.0), (874.0, -86.0), (826.0, -86.0), (818.0, -72.0)], 7.5, M['stock'])
wr.bevel(tg, 0.0008, 2, 30)
body.append(tg)
trig = side('trigger', [(842.0, -54.0), (849.0, -54.0), (848.0, -62.0), (851.0, -71.0), (849.0, -74.0), (843.5, -64.0)], 2.8, M['steel'])
wr.bevel(trig, 0.0003, 2, 30)
body.append(trig)
body.append(side('mag_catch', [(792.0, -58.0), (804.0, -58.0), (806.0, -72.0), (794.0, -72.0)], 6.0, M['steel']))
body.append(side('safety', [(872.0, -8.0), (884.0, -8.0), (884.0, -2.0), (872.0, -2.0)], 2.0, M['steel'], z=-18.0))
# Sling swivels and bipod stud.
body.append(wr.cylinder('bipod_stud', P(410.0, -54.0), P(410.0, -64.0), 0.0035, M['steel'], 16))
for dd in (1040.0,):
    body.append(cyl_z('flush_cup', dd, -60.0, 21.0, 22.6, 7.0, M['steel'], 28))
    body.append(cyl_z('flush_cup', dd, -60.0, -21.0, -22.6, 7.0, M['steel'], 28))

# ------------------------------------------------------------------ action ----
act = []
act.append(cyl('bolt_body', 690.0, RR + 6, 9.4, M['bolt'], seg=36))
for k in range(3):
    a = math.radians(90 + 120 * k)
    act.append(wr.box('bolt_lug', P(694.0, 9.6 * math.sin(a), 9.6 * math.cos(a)), (0.012, 0.004, 0.004), M['bolt']))
act.append(cyl('bolt_shroud', RR + 6, RR + 30, 10.2, M['steel'], seg=36, r1=9.0))
act.append(wr.cylinder('handle_root', P(850.0, 0.0, -8.0), P(850.0, -1.0, -24.0), 0.0058, M['steel'], 24))
act.append(wr.cylinder('handle_stem', P(850.0, -1.0, -24.0), P(856.0, -14.0, -44.0), 0.0045, M['steel'], 20))
act.append(wr.cylinder('bolt_knob', P(855.0, -12.0, -42.0), P(858.0, -18.0, -52.0), 0.0105, M['steel'], 32))
action = wr.join('Action', act)
bpy.context.scene.cursor.location = wr.cv(P(850.0, 0.0, 0.0))
bpy.ops.object.select_all(action='DESELECT')
action.select_set(True)
bpy.context.view_layer.objects.active = action
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.context.scene.cursor.location = (0, 0, 0)

# ---------------------------------------------------------------- magazine ----
mag = side('magazine', [(708.0, -20.0), (786.0, -20.0), (786.0, -92.0), (780.0, -98.0), (714.0, -98.0), (708.0, -92.0)], 11.0, M['steel'])
wr.bevel(mag, 0.0006, 2, 30)
mag_parts = [mag]
for sgn in (1, -1):
    mag_parts.append(side('mag_rib', [(716.0, -40.0), (778.0, -40.0), (778.0, -84.0), (716.0, -84.0)], 0.6, M['steel'], z=sgn * 11.2))
mag_parts.append(side('mag_floor', [(704.0, -96.0), (790.0, -96.0), (790.0, -102.0), (704.0, -102.0)], 12.0, M['steel']))
mag_parts.append(cyl('top_round', 776.0, 716.0, 5.9, M['brass'], y=-14.0, z=3.5, seg=20))
mag_parts.append(cyl('top_bullet', 716.0, 694.0, 3.9, M['bore'], y=-14.0, z=3.5, seg=20, r1=1.4))
magazine = wr.join('Magazine', mag_parts)

# ---------------------------------------------------------- iron sights ----
irons = []
fb = wr.tube('front_sight_clamp', P(30.0, 0), P(58.0, 0), 0.0142, 0.0112, M['steel'], 40)
irons.append(fb)
irons.append(side('front_ramp', [(32.0, 10.0), (56.0, 10.0), (54.0, 38.0), (36.0, 38.0)], 4.0, M['steel']))
hood = wr.tube('front_hood', P(32.0, 44.0), P(56.0, 44.0), 0.0105, 0.0092, M['steel'], 32)
irons.append(hood)
irons.append(side('front_post', [(43.0, 34.0), (46.0, 34.0), (45.6, 50.0), (43.4, 50.0)], 0.9, M['steel']))
rb = plan('rear_base', [(832.0, -10.6), (856.0, -10.6), (856.0, 10.6), (832.0, 10.6)], 27.0, 34.0, M['steel'])
wr.bevel(rb, 0.0006, 2, 30)
irons.append(rb)
ap = side('rear_aperture', [(842.0, 33.0), (846.0, 33.0), (846.0, 56.0), (842.0, 56.0)], 6.0, M['steel'])
wr.boolean(ap, cyl('peep', 836.0, 852.0, 0.9, None, y=50.0, seg=20), 'DIFFERENCE')
irons.append(ap)
irons.append(cyl_z('rear_drum', 844.0, 40.0, -6.0, -12.0, 5.0, M['steel'], 24))
iron_sights = wr.join('IronSights', irons)

body_obj = wr.join('BodyMesh', body)
objs = [body_obj, action, magazine, iron_sights]
print('AW verts', {o.name: len(o.data.vertices) for o in objs}, 'total', wr.stats(objs))
wr.export(OUT, objs)
print('EXPORTED', OUT)
