"""TOBIKAGE / T-65 rebuilt as its real counterpart: Dragunov SVD (classic
laminated birch skeleton stock and vented laminated handguard), 7.62x54R.

blender --background --python tools/weapon_real/tobikage_svd.py
Proportions traced from the right-side photograph "Dragunovs rt noBG.jpg"
(Wikimedia Commons; upper rifle; 0.978 px/mm from the 1225 mm overall length).
Frame: d = mm behind the muzzle, y = mm above the bore, z = mm to the left.
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy
import wr

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / 'assets/weapons/tobikage/tobikage_geometry.glb'
XM, BY = -0.7716, 0.043


def P(d, y, z=0.0):
    return (XM + d / 1000.0, BY + y / 1000.0, z / 1000.0)


def PX(x, yp):
    return ((1309 - x) / 0.978, (211 - yp) / 0.978)


def side(name, pts, half, m, z=0.0):
    return wr.extrude_xy(name, [P(d, y)[:2] for d, y in pts], (z - half) / 1000, (z + half) / 1000, m)


def sec(name, pts_zy, d0, d1, m):
    return wr.extrude_zy(name, [(z / 1000, BY + y / 1000) for z, y in pts_zy], P(d0, 0)[0], P(d1, 0)[0], m)


def cyl(name, d0, d1, r, m, y=0.0, z=0.0, seg=32, r1=None):
    return wr.cylinder(name, P(d0, y, z), P(d1, y, z), r / 1000, m, seg, None if r1 is None else r1 / 1000)


def cyl_z(name, d, y, z0, z1, r, m, seg=24):
    return wr.cylinder(name, P(d, y, z0), P(d, y, z1), r / 1000, m, seg)


wr.reset()
M = dict(
    steel=wr.mat('SVD blued steel', (0.04, 0.042, 0.045), 0.75, 0.4),
    dark=wr.mat('SVD black oxide', (0.035, 0.035, 0.036), 0.65, 0.5),
    wood=wr.mat('SVD laminated birch', (0.30, 0.10, 0.05), 0.0, 0.45),
    rubber=wr.mat('SVD rubber butt pad', (0.03, 0.03, 0.03), 0.0, 0.85),
    mag=wr.mat('SVD magazine steel', (0.05, 0.05, 0.052), 0.6, 0.55),
    brass=wr.mat('SVD lacquered steel case', (0.33, 0.30, 0.22), 0.8, 0.45),
    mark=wr.mat('SVD stamping', (0.25, 0.25, 0.25), 0.7, 0.45),
    bore=wr.mat('SVD bore', (0.01, 0.01, 0.01), 0.8, 0.5),
    white=wr.mat('SVD sight paint', (0.8, 0.8, 0.75), 0.0, 0.5),
)
body = []
R_FRONT, R_REAR = 577.0, 883.0

# -------------------------------------------------------------- receiver ----
rec = side('receiver', [(R_FRONT, -47.0), (R_REAR - 8, -47.0), (R_REAR, -40.0), (R_REAR, 14.0), (R_REAR - 6, 20.0), (R_FRONT, 20.0)], 15.0, M['steel'])
top = sec('top_cover', [(-15.0, 18.0), (15.0, 18.0), (14.6, 26.0), (12.0, 31.5), (7.0, 34.0), (-7.0, 34.0), (-12.0, 31.5), (-14.6, 26.0)], R_FRONT + 48, R_REAR - 4, M['steel'])
# AK-pattern dust cover: slopes down to the rear latch, with stiffening ribs.
wr.boolean(top, side('cover_slope', [(R_FRONT, 0.0), (R_FRONT, 40.0), (R_REAR - 70, 40.0), (R_REAR - 4, 25.0), (R_REAR - 4, 0.0)], 30, None), 'INTERSECT')
for _dd in (700.0, 760.0):
    top = wr.join('top_cover', [top, sec('cover_rib', [(-6.0, 33.0), (6.0, 33.0), (5.0, 35.0), (-5.0, 35.0)], _dd, _dd + 30, M['steel'])])
# Ejection port and the charging-handle slot on the right.
cuts = [side('eject_port', [(625.0, -2.0), (700.0, -2.0), (700.0, 17.0), (625.0, 17.0)], 6, None, z=-15.0),
        side('handle_slot', [(640.0, 6.0), (820.0, 6.0), (820.0, 12.0), (640.0, 12.0)], 4, None, z=-15.0)]
rec = wr.join('receiver', [rec, top])
wr.boolean(rec, cuts, 'DIFFERENCE')
# Magazine well opening in the bottom.
wr.boolean(rec, side('magwell', [(666.0, -60.0), (767.0, -60.0), (767.0, -20.0), (666.0, -20.0)], 13.6, None), 'DIFFERENCE')
wr.bevel(rec, 0.0006, 2, 30)
body.append(rec)
# Trunnion (front) and the tangent rear sight block on it.
tr = sec('trunnion', [(-16.0, -40.0), (16.0, -40.0), (16.0, 22.0), (12.0, 30.0), (-12.0, 30.0), (-16.0, 22.0)], R_FRONT - 4, R_FRONT + 28, M['steel'])
wr.boolean(tr, side('trunnion_mag_cut', [(630, -60), (700, -60), (700, -30), (630, -30)], 20, None), 'DIFFERENCE')
wr.bevel(tr, 0.0006, 2, 30)
body.append(tr)
rs = sec('rear_sight_block', [(-12.5, 28.0), (12.5, 28.0), (12.5, 38.0), (9.0, 42.0), (-9.0, 42.0), (-12.5, 38.0)], R_FRONT + 4, R_FRONT + 46, M['steel'])
wr.bevel(rs, 0.0005, 2, 30)
body.append(rs)
# Left-side optic dovetail rail (PSO mount), riveted to the receiver.
rail = side('side_rail', [(650.0, -6.0), (800.0, -6.0), (800.0, 12.0), (650.0, 12.0)], 2.2, M['steel'], z=17.0)
wr.boolean(rail, side('rail_groove', [(645.0, 1.0), (805.0, 1.0), (805.0, 5.0), (645.0, 5.0)], 1.0, None, z=19.2), 'DIFFERENCE')
wr.bevel(rail, 0.0004, 2, 30)
body.append(rail)
for dd in (665.0, 785.0):
    body.append(cyl_z('rail_rivet', dd, 3.0, 19.1, 19.8, 2.4, M['steel']))
for s in (1, -1):
    for dd, yy in ((612.0, -30.0), (850.0, -32.0), (860.0, 8.0), (594.0, 8.0)):
        body.append(cyl_z('rivet', dd, yy, s * 15.0, s * 15.7, 2.6, M['steel'], 16))
# AK-type safety lever on the right, shown on SAFE closing the handle slot.
sl = side('safety_lever', [(640.0, 5.0), (800.0, 7.5), (812.0, 4.5), (812.0, 15.0), (800.0, 16.0), (640.0, 13.5), (634.0, 9.0)], 0.9, M['steel'], z=-16.2)
wr.bevel(sl, 0.0003, 2, 30)
body.append(sl)
body.append(side('safety_tab', [(640.0, 13.5), (652.0, 13.5), (652.0, 20.0), (640.0, 20.0)], 2.2, M['steel'], z=-17.0))
body.append(cyl_z('safety_pivot', 806.0, 9.0, -15.0, -17.6, 5.0, M['steel']))
# Magazine release paddle behind the magazine.
body.append(side('mag_release', [(768.0, -47.0), (782.0, -47.0), (784.0, -64.0), (778.0, -66.0), (770.0, -58.0)], 7.0, M['steel']))
# Trigger guard and trigger.
tg = side('trigger_guard', [(832.0, -47.0), (840.0, -47.0), (842.0, -66.0), (872.0, -68.0), (880.0, -58.0), (884.0, -58.0), (878.0, -73.0), (840.0, -73.0), (834.0, -66.0)], 5.0, M['steel'])
wr.bevel(tg, 0.0005, 2, 30)
body.append(tg)
trig = side('trigger', [(850.0, -46.0), (856.0, -46.0), (857.0, -54.0), (861.0, -62.0), (859.0, -64.0), (853.0, -56.0)], 2.5, M['steel'])
wr.bevel(trig, 0.0003, 2, 30)
body.append(trig)
# Markings on the receiver's left side.
body.append(wr.text('mk_model', 'T-65', P(720.0, -30.0, 15.04), 0.0045, M['mark'], 1))
body.append(wr.text('mk_serial', '1987  TK 4402', P(720.0, -38.5, 15.04), 0.0026, M['mark'], 1))

# --------------------------------------------------------- barrel group ----
body.append(cyl('barrel', 60.0, R_FRONT + 6, 10.0, M['steel'], seg=40))
body.append(cyl('barrel_shank', 300.0, R_FRONT + 6, 12.0, M['steel'], seg=40))
# Gas block with its regulator, and the gas tube above the barrel.
gb = side('gas_block', [(227.0, -15.0), (262.0, -15.0), (262.0, 38.0), (240.0, 38.0), (233.0, 28.0), (227.0, 18.0)], 13.0, M['steel'])
wr.bevel(gb, 0.0008, 2, 30)
body.append(gb)
body.append(cyl_z('gas_regulator', 236.0, 26.0, -12.0, -15.6, 5.2, M['steel']))
body.append(cyl('gas_tube', 255.0, 345.0, 10.2, M['steel'], y=26.5, seg=32))
# Front sight block: hooded post on top, bayonet lug below.
fsb = side('front_sight_block', [(99.0, -14.0), (126.0, -14.0), (126.0, 10.0), (120.0, 20.0), (104.0, 20.0), (99.0, 12.0)], 11.0, M['steel'])
wr.bevel(fsb, 0.0006, 2, 30)
body.append(fsb)
hood = wr.tube('front_sight_hood', P(100.0, 39.0), P(124.0, 39.0), 0.0135, 0.0118, M['steel'], 40)
wr.boolean(hood, side('hood_bottom', [(95, 30), (130, 30), (130, 24), (95, 24)], 20, None), 'DIFFERENCE')
body.append(hood)
for sgn in (1, -1):
    body.append(side('hood_leg', [(104.0, 18.0), (120.0, 18.0), (118.0, 31.0), (106.0, 31.0)], 1.5, M['steel'], z=sgn * 10.5))
lug = side('bayonet_lug', [(112.0, -14.0), (128.0, -14.0), (128.0, -22.5), (112.0, -22.5)], 3.5, M['steel'])
body.append(lug)
# Five-slot flash hider.
fh = wr.tube('flash_hider', P(-1.0, 0), P(99.0, 0), 0.0138, 0.0062, M['steel'], 48)
slots = []
for k in range(5):
    th = math.radians(72 * k)
    c, sn = math.cos(th), math.sin(th)
    w2, r0, r1 = 1.6, 6.0, 16.0
    poly = [(-w2 * c + r0 * sn, r0 * c + w2 * sn), (w2 * c + r0 * sn, r0 * c - w2 * sn), (w2 * c + r1 * sn, r1 * c - w2 * sn), (-w2 * c + r1 * sn, r1 * c + w2 * sn)]
    slots.append(sec('fh_slot', poly, 12.0, 74.0, None))
wr.boolean(fh, slots, 'DIFFERENCE')
body.append(fh)
body.append(cyl('bore_shadow', 8.0, 14.0, 6.15, M['bore'], seg=24))

# ------------------------------------------------------------ handguard ----
HG0, HG1 = 336.0, 579.0
hg_sec = [(z, y) for z, y in wr.superellipse(0.0, 9.0, 50.0, 73.0, 2.6, 36)]
hg = sec('handguard', hg_sec, HG0 + 6, HG1 - 4, M['wood'])
wr.boolean(hg, cyl('hg_core', HG0 - 5, HG1 + 5, 15.0, None, y=6.0, seg=32), 'DIFFERENCE')
vents = []
for k in range(6):
    dd = HG0 + 40 + k * 32.0
    for sgn in (1, -1):
        vents.append(wr.extrude_xy('vent', [P(x, y)[:2] for x, y in wr.superellipse(dd, 6.0, 20.0, 9.0, 2.0, 20)], sgn * 0.010, sgn * 0.030, None))
wr.boolean(hg, vents, 'DIFFERENCE')
wr.moulded(hg, voxel=0.0007, smooth_factor=0.5, smooth_iter=3, ratio=0.12)
body.append(hg)
for dd0, dd1 in ((HG0 - 2, HG0 + 8), (HG1 - 8, HG1 + 2)):
    ring = sec('hg_ring', [(z, y) for z, y in wr.superellipse(0.0, 9.0, 52.0, 75.0, 2.6, 36)], dd0, dd1, M['steel'])
    wr.boolean(ring, cyl('ring_core', dd0 - 2, dd1 + 2, 14.0, None, y=6.0), 'DIFFERENCE')
    body.append(ring)
body.append(cyl_z('hg_latch', HG0 + 3, 8.0, -26.0, -29.0, 3.8, M['steel']))

# ---------------------------------------------------------------- stock ----
STOCK = [PX(447, 205), PX(330, 200), PX(319, 193), PX(311, 183), PX(199, 182), PX(195, 205), PX(125, 207), PX(119, 214), PX(119, 334), PX(127, 340), PX(191, 333), PX(247, 324), PX(295, 316), PX(343, 323), PX(367, 335), PX(399, 336), PX(407, 322), PX(415, 287), PX(431, 277), PX(447, 258)]
stock = side('stock', STOCK, 18.5, M['wood'])
hole = side('thumbhole', [PX(x, y) for x, y in [(250, 262), (255, 251), (271, 246), (295, 238), (343, 237), (355, 240), (362, 247), (355, 262), (343, 277), (311, 284), (279, 288), (255, 291), (250, 280)]], 30, None)
wr.boolean(stock, hole, 'DIFFERENCE')
taper = sec('stock_taper', [(-14.0, 40.0), (14.0, 40.0), (18.5, 20.0), (18.5, -150.0), (-18.5, -150.0), (-18.5, 20.0)], 520.0, 1260.0, None)
wr.boolean(stock, taper, 'INTERSECT')
wr.moulded(stock, voxel=0.0007, smooth_factor=0.55, smooth_iter=12, ratio=0.08)
body.append(stock)
# Detachable cheek rest seam and its latch.
seam = side('cheek_seam', [PX(311, 194), PX(199, 194), PX(199, 195.5), PX(311, 195.5)], 18.8, M['bore'])
body.append(seam)
body.append(cyl_z('cheek_latch', PX(300, 190)[0], PX(300, 190)[1], -18.2, -20.2, 4.0, M['steel']))
pad = side('butt_pad', [PX(119, 210), PX(110, 212), PX(108, 230), PX(108, 336), PX(114, 342), PX(121, 340), PX(121, 212)], 18.0, M['rubber'])
wr.moulded(pad, voxel=0.0008, smooth_factor=0.5, smooth_iter=4, ratio=0.12)
body.append(pad)
for dd, yy in ((PX(150, 330)[0], -122.0), (430.0, -26.0)):
    sw = wr.tube('sling_swivel', P(dd - 7, yy - 6, 0), P(dd + 7, yy - 6, 0), 0.006, 0.0045, M['steel'], 24)
    body.append(sw)

# ---------------------------------------------------------------- action ----
act = [sec('carrier', [(-11.0, 2.0), (11.0, 2.0), (11.0, 16.0), (-11.0, 16.0)], 610.0, 760.0, M['dark'])]
act.append(cyl('bolt', 600.0, 640.0, 7.0, M['steel'], y=1.0, seg=28))
act.append(side('handle_stem', [(650.0, 6.5), (662.0, 6.5), (662.0, 11.5), (650.0, 11.5)], 10.0, M['steel'], z=-21.0))
knob = cyl_z('handle_knob', 656.0, 9.0, -27.0, -37.0, 6.6, M['steel'], 28)
act.append(knob)
action = wr.join('Action', act)

# -------------------------------------------------------------- magazine ----
MAG = [PX(x, y) for x, y in [(560, 252), (655, 252), (653, 300), (648, 330), (583, 345), (572, 332), (563, 300)]]
mag = side('mag', MAG, 13.2, M['mag'])
ribs = []
for sgn in (1, -1):
    ribs.append(side('mag_rib_h', [PX(x, y) for x, y in [(575, 288), (640, 288), (638, 296), (577, 296)]], 0.8, M['mag'], z=sgn * 13.5))
    ribs.append(side('mag_rib_h2', [PX(x, y) for x, y in [(580, 312), (636, 312), (634, 319), (582, 319)]], 0.8, M['mag'], z=sgn * 13.5))
    ribs.append(side('mag_rib_v', [PX(x, y) for x, y in [(604, 262), (612, 262), (612, 334), (604, 336)]], 0.8, M['mag'], z=sgn * 13.5))
mag = wr.join('mag', [mag] + ribs)
wr.bevel(mag, 0.0007, 2, 30)
mag_parts = [mag]
mag_parts.append(side('mag_floor', [PX(x, y) for x, y in [(581, 343), (650, 327), (652, 332), (584, 349)]], 14.0, M['mag']))
mag_parts.append(cyl('round', PX(650, 0)[0] + 2, PX(570, 0)[0] - 4, 6.2, M['brass'], y=-44.0, z=-3.0, seg=20))
magazine = wr.join('Magazine', mag_parts)

# ---------------------------------------------------------- iron sights ----
irons = []
leaf = side('rear_leaf', [(R_FRONT + 8, 40.0), (R_FRONT + 44, 42.0), (R_FRONT + 44, 46.5), (R_FRONT + 8, 44.0)], 9.0, M['steel'])
wr.boolean(leaf, sec('notch', [(-1.2, 49.0), (1.2, 49.0), (1.2, 45.0), (0.0, 43.6), (-1.2, 45.0)], R_FRONT + 36, R_FRONT + 50, None), 'DIFFERENCE')
irons.append(leaf)
irons.append(side('range_slider', [(R_FRONT + 20, 41.0), (R_FRONT + 30, 41.6), (R_FRONT + 30, 47.5), (R_FRONT + 20, 47.0)], 10.5, M['steel']))
irons.append(side('front_post', [(110.0, 20.0), (114.0, 20.0), (113.4, 46.5), (110.6, 46.5)], 1.0, M['steel']))
iron_sights = wr.join('IronSights', irons)

body_obj = wr.join('Body', body)
objs = [body_obj, action, magazine, iron_sights]
print('SVD verts', {o.name: len(o.data.vertices) for o in objs}, 'total', wr.stats(objs))
wr.export(OUT, objs)
print('EXPORTED', OUT)
