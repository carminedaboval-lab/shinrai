"""HAYATE / H-7 rebuilt as its real counterpart: USMC M40A5 (Remington 700
short action, 25 in Schneider heavy barrel, McMillan A4 stock, Badger
Ordnance detachable 5-round bottom metal and 30 MOA rail), 7.62x51.

blender --background --python tools/weapon_real/hayate_m40a5.py
Built from published dimensions: overall 1124 mm, barrel 635 mm, receiver
216 mm x 34.5 mm (1.360 in), bolt body 17.8 mm. Frame: d = mm behind the
barrel crown, y = mm above the bore, z = mm to the left. The Action origin is
on the bore axis so the viewmodel's bolt-lift rotation pivots correctly.
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy
import wr

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / 'assets/weapons/hayate/hayate_geometry.glb'
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
    steel=wr.mat(KEY + ' parkerised steel', (0.05, 0.05, 0.05), 0.55, 0.62),
    blued=wr.mat(KEY + ' black steel', (0.04, 0.04, 0.042), 0.75, 0.4),
    bright=wr.mat(KEY + ' polished bolt', (0.6, 0.6, 0.6), 1.0, 0.25),
    stock=wr.mat(KEY + ' McMillan olive', (0.12, 0.13, 0.08), 0.0, 0.55),
    grip=wr.mat(KEY + ' McMillan texture', (0.12, 0.13, 0.08), 0.0, 0.7),
    rubber=wr.mat(KEY + ' recoil pad', (0.03, 0.03, 0.03), 0.0, 0.85),
    alu=wr.mat(KEY + ' anodised alloy', (0.05, 0.05, 0.05), 0.4, 0.5),
    brass=wr.mat(KEY + ' brass', (0.72, 0.52, 0.24), 1.0, 0.3),
    bore=wr.mat(KEY + ' bore', (0.01, 0.01, 0.01), 0.8, 0.5),
    mark=wr.mat(KEY + ' engraving', (0.35, 0.35, 0.34), 0.6, 0.5),
)
body = []
RF, RR, RRAD = 610.0, 826.0, 17.25

# ---------------------------------------------------- barrel and muzzle ----
barrel = wr.loft('barrel', [[P(d, r * math.sin(2 * math.pi * k / 40), r * math.cos(2 * math.pi * k / 40)) for k in range(40)] for d, r in ((0.0, 11.5), (300.0, 11.9), (520.0, 14.6), (RF + 4, 15.3))], M['blued'])
wr.smooth(barrel, 40)
body.append(barrel)
brake = wr.tube('muzzle_brake', P(-51.0, 0), P(4.0, 0), 0.0122, 0.0052, M['blued'], 48)
ports = []
for k in range(3):
    for sgn in (1, -1):
        ports.append(cyl_z('brake_port', -14.0 - k * 11.0, 0.0, sgn * 3.0, sgn * 16.0, 3.4, None, 20))
wr.boolean(brake, ports, 'DIFFERENCE')
body.append(brake)
body.append(cyl('bore_shadow', -42.0, -36.0, 5.15, M['bore'], seg=24))
body.append(wr.text('barrel_mark', 'SCHNEIDER 7.62 NATO', P(560.0, 0.0, 15.05), 0.0028, M['mark'], 1))
# Recoil lug sandwiched between barrel and receiver.
lug = sec('recoil_lug', [(z, y) for z, y in wr.superellipse(0.0, -3.0, 36.6, 41.0, 6.0, 32)], RF - 6, RF, M['steel'])
body.append(lug)

# -------------------------------------------------------------- receiver ----
rec = cyl('receiver', RF, RR, RRAD, M['steel'], seg=48)
cuts = [side('ejection_port', [(652.0, 2.0), (722.0, 2.0), (722.0, 30.0), (652.0, 30.0)], 9.0, None, z=-8.0),
        side('bolt_slot', [(722.0, -4.0), (RR + 2, -4.0), (RR + 2, 2.0), (722.0, 2.0)], 6.0, None, z=-15.0),
        side('handle_notch', [(792.0, -12.0), (812.0, -12.0), (812.0, 2.0), (792.0, 2.0)], 6.0, None, z=-15.0),
        plan('mag_opening', [(660.0, -11.0), (735.0, -11.0), (735.0, 11.0), (660.0, 11.0)], -30.0, -8.0, None)]
wr.boolean(rec, cuts, 'DIFFERENCE')
wr.bevel(rec, 0.0004, 2, 30)
body.append(rec)
# Badger 30 MOA rail, screwed to the receiver (front lower than rear).
rail = pic_rail('rail', RF - 12, RR + 14, 27.0, M['alu'])
import mathutils
pivot = wr.cv(P(RR, 27.0))
rail.matrix_world = mathutils.Matrix.Translation(pivot) @ mathutils.Matrix.Rotation(math.radians(0.5), 4, 'Y') @ mathutils.Matrix.Translation(-pivot) @ rail.matrix_world
wr.apply(rail)
body.append(rail)
body.append(sec('rail_base', [(-10.0, 15.0), (10.0, 15.0), (10.0, 18.6), (-10.0, 18.6)], RF - 12, RR + 14, M['alu']))
for dd in (RF + 10, 690.0, 760.0, RR - 6):
    body.append(cyl('rail_screw', dd, dd, 0.0, None) if False else wr.cylinder('rail_screw', P(dd, 27.2), P(dd, 25.5), 0.0024, M['steel'], 16))
# Bolt stop (left rear) and receiver marking.
body.append(side('bolt_stop', [(796.0, -2.0), (812.0, -2.0), (812.0, 6.0), (796.0, 6.0)], 1.2, M['steel'], z=17.6))
body.append(wr.text('rec_mark', 'H-7  HAYATE   USMC', P(705.0, 6.0, 17.3), 0.0026, M['mark'], 1))
# Bottom metal: Badger detachable magazine well, release paddle, trigger guard.
bm = side('bottom_metal', [(640.0, -34.0), (845.0, -34.0), (845.0, -44.0), (836.0, -48.0), (650.0, -48.0)], 14.0, M['alu'])
wr.boolean(bm, plan('bm_well', [(660.0, -12.0), (735.0, -12.0), (735.0, 12.0), (660.0, 12.0)], -60.0, -20.0, None), 'DIFFERENCE')
wr.bevel(bm, 0.0006, 2, 30)
body.append(bm)
tg = side('trigger_guard', [(770.0, -46.0), (778.0, -46.0), (782.0, -66.0), (826.0, -66.0), (836.0, -48.0), (842.0, -48.0), (832.0, -72.0), (778.0, -72.0), (770.0, -60.0)], 6.0, M['alu'])
wr.bevel(tg, 0.0006, 2, 30)
body.append(tg)
body.append(side('mag_release', [(741.0, -46.0), (750.0, -46.0), (762.0, -60.0), (756.0, -64.0), (742.0, -54.0)], 6.0, M['steel']))
trig = side('trigger', [(796.0, -44.0), (803.0, -44.0), (802.0, -52.0), (805.0, -60.0), (803.0, -63.0), (797.5, -54.0)], 2.6, M['blued'])
wr.bevel(trig, 0.0003, 2, 30)
body.append(trig)
body.append(side('safety', [(826.0, -8.0), (836.0, -8.0), (836.0, -3.0), (826.0, -3.0)], 2.0, M['steel'], z=-16.6))

# ---------------------------------------------------------------- stock ----
# McMillan A4: wide flat fore-end, near-vertical grip with palm swell, high
# adjustable cheek piece, hooked toe, length-of-pull spacers and pad.
STK = [(320.0, -14.0), (RF - 30, -8.0), (RF, -4.0), (RR + 14, -4.0), (848.0, -14.0), (870.0, -20.0), (905.0, -8.0), (960.0, 2.0), (1100.0, 6.0), (1100.0, -128.0), (1080.0, -132.0), (1052.0, -114.0), (1038.0, -112.0), (1022.0, -120.0), (1000.0, -110.0), (938.0, -84.0), (918.0, -96.0), (912.0, -150.0), (890.0, -158.0), (866.0, -152.0), (856.0, -114.0), (850.0, -68.0), (840.0, -56.0), (630.0, -50.0), (330.0, -46.0), (320.0, -40.0)]
stock = side('stock', STK, 30.0, M['stock'])
taper = sec('stock_section', [(-29.0, -50.0), (29.0, -50.0), (29.0, 6.0), (19.0, 16.0), (-19.0, 16.0), (-29.0, 6.0)], 300.0, 860.0, None)
butt = sec('butt_section', [(-22.0, -170.0), (22.0, -170.0), (23.0, 0.0), (17.0, 10.0), (-17.0, 10.0), (-23.0, 0.0)], 848.0, 1120.0, None)
grip_sec = sec('grip_section', [(-16.5, -170.0), (16.5, -170.0), (17.5, -60.0), (-17.5, -60.0)], 840.0, 940.0, None)
shape = wr.join('stock_shape', [taper, butt, grip_sec])
wr.moulded(shape, voxel=0.001, smooth_factor=0.0, smooth_iter=0, ratio=1.0)
wr.moulded(stock, voxel=0.001, smooth_factor=0.0, smooth_iter=0, ratio=1.0)
wr.boolean(stock, shape, 'INTERSECT', solver='MANIFOLD')
# Barrel channel (free-floated) and action inletting.
wr.boolean(stock, [cyl('barrel_channel', 300.0, RF + 2, 17.0, None, seg=32), cyl('action_inlet', RF - 8, RR + 12, RRAD + 0.6, None, seg=40)], 'DIFFERENCE', solver='MANIFOLD')
wr.moulded(stock, voxel=0.0006, smooth_factor=0.6, smooth_iter=14, ratio=0.07)
wr.assign_faces(stock, M['grip'], lambda x, y, z: (x - XM) * 1000 > 846 and (x - XM) * 1000 < 925 and (y - BY) * 1000 < -60)
body.append(stock)
# Adjustable cheek piece on two posts with the side lock knob.
cheek = side('cheek_piece', [(955.0, 6.0), (1085.0, 8.0), (1085.0, 26.0), (1060.0, 30.0), (975.0, 28.0), (955.0, 20.0)], 16.0, M['stock'])
wr.moulded(cheek, voxel=0.0009, smooth_factor=0.6, smooth_iter=6, ratio=0.15)
body.append(cheek)
for dd in (985.0, 1055.0):
    body.append(cyl('cheek_post', dd, dd, 0.0, None) if False else wr.cylinder('cheek_post', P(dd, 9.0), P(dd, 4.0), 0.0045, M['steel'], 20))
    body.append(cyl_z('cheek_knob', dd, -8.0, 22.0, 30.0, 8.0, M['alu'], 28))
# Length-of-pull spacers and the recoil pad.
body.append(side('lop_spacers', [(1100.0, 6.0), (1112.0, 6.0), (1112.0, -128.0), (1100.0, -128.0)], 21.0, M['alu']))
pad = side('recoil_pad', [(1112.0, 7.0), (1124.0, 4.0), (1126.0, -20.0), (1126.0, -126.0), (1120.0, -132.0), (1112.0, -130.0)], 22.0, M['rubber'])
wr.moulded(pad, voxel=0.0009, smooth_factor=0.5, smooth_iter=4, ratio=0.15)
body.append(pad)
# Front sling stud on a short accessory rail, and the rear flush cup.
body.append(sec('fore_rail', [(-8.0, -46.0), (8.0, -46.0), (8.0, -52.0), (-8.0, -52.0)], 360.0, 430.0, M['alu']))
body.append(cyl('sling_stud', 340.0, 340.0, 0.0, None) if False else wr.cylinder('sling_stud', P(340.0, -45.0), P(340.0, -55.0), 0.0035, M['steel'], 16))
for sgn in (1, -1):
    body.append(cyl_z('flush_cup', 1050.0, -60.0, sgn * 22.0, sgn * 23.4, 7.0, M['steel'], 28))

# --------------------------------------------------------------- action ----
act = []
act.append(cyl('bolt_body', 645.0, RR + 8, 8.9, M['bright'], seg=36))
act.append(cyl('bolt_head', 638.0, 645.0, 8.6, M['bright'], seg=36))
for sgn in (1, -1):
    act.append(side('locking_lug', [(638.0, 7.0), (652.0, 7.0), (652.0, 12.6), (638.0, 12.6)], 3.2, M['bright'], z=0.0) if sgn > 0 else side('locking_lug', [(638.0, -12.6), (652.0, -12.6), (652.0, -7.0), (638.0, -7.0)], 3.2, M['bright']))
shroud = cyl('bolt_shroud', RR + 8, RR + 34, 9.6, M['blued'], seg=36, r1=8.4)
act.append(shroud)
act.append(cyl('cocking_piece', RR + 34, RR + 40, 4.0, M['blued'], y=-3.0, seg=20))
# Bolt handle: root at the rear, swept back and down to a tactical knob.
act.append(wr.cylinder('handle_root', P(806.0, 0.0, -6.0), P(806.0, -2.0, -20.0), 0.0058, M['blued'], 24))
act.append(wr.cylinder('handle_stem', P(806.0, -2.0, -20.0), P(842.0, -24.0, -40.0), 0.0042, M['blued'], 20, radius_b=0.0048))
knob = wr.cylinder('tactical_knob', P(836.0, -20.0, -36.0), P(852.0, -29.5, -47.0), 0.0112, M['blued'], 40, radius_b=0.0104)
act.append(wr.cylinder('knob_cap', P(851.0, -29.0, -46.4), P(853.0, -30.2, -47.8), 0.0098, M['blued'], 40))
act.append(knob)
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
mag = side('magazine', [(662.0, -20.0), (733.0, -20.0), (733.0, -70.0), (728.0, -76.0), (667.0, -76.0), (662.0, -70.0)], 11.2, M['steel'])
wr.bevel(mag, 0.0006, 2, 30)
mag_parts = [mag]
mag_parts.append(side('mag_floor', [(660.0, -74.0), (737.0, -74.0), (737.0, -80.0), (660.0, -80.0)], 12.2, M['steel']))
mag_parts.append(cyl('top_round', 722.0, 664.0, 5.9, M['brass'], y=-14.0, z=-3.5, seg=20))
mag_parts.append(cyl('top_bullet', 664.0, 642.0, 3.9, M['bore'], y=-14.0, z=-3.5, seg=20, r1=1.4))
magazine = wr.join('Magazine', mag_parts)

# ------------------------------------------- backup folding iron sights ----
irons = []
for d0, d1, top in ((806.0, 826.0, 59.0), (596.0, 614.0, 59.0)):
    base = plan('buis_base', [(d0, -10.6), (d1, -10.6), (d1, 10.6), (d0, 10.6)], 27.0, 34.0, M['alu'])
    wr.bevel(base, 0.0006, 2, 30)
    irons.append(base)
    for sgn in (1, -1):
        irons.append(side('buis_ear', [(d0 + 3, 33.0), (d1 - 3, 33.0), (d1 - 5, top + 3), (d0 + 5, top + 3)], 1.0, M['alu'], z=sgn * 7.0))
ap = side('rear_aperture', [(814.0, 33.0), (818.0, 33.0), (818.0, 62.0), (814.0, 62.0)], 4.6, M['alu'])
wr.boolean(ap, cyl('peep', 806.0, 826.0, 0.9, None, y=57.0, seg=20), 'DIFFERENCE')
irons.append(ap)
irons.append(side('front_post', [(603.8, 33.0), (606.2, 33.0), (605.8, 57.0), (604.2, 57.0)], 0.9, M['alu']))
iron_sights = wr.join('IronSights', irons)

body_obj = wr.join('BodyMesh', body)
objs = [body_obj, action, magazine, iron_sights]
print('M40 verts', {o.name: len(o.data.vertices) for o in objs}, 'total', wr.stats(objs))
wr.export(OUT, objs)
print('EXPORTED', OUT)
