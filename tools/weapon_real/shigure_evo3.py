"""SHIGURE / S-9 rebuilt as its real counterpart: CZ Scorpion EVO 3 A1, 9x19.

blender --background --python tools/weapon_real/shigure_evo3.py
Proportions traced from the left-side photograph "Scorpion EVO 3 A1 left.jpg"
(Wikimedia Commons; quarter scale 1.556 px/mm from the 241 mm height).
Frame: d = mm behind the muzzle, y = mm above the bore, z = mm to the left.
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy
import wr

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / 'assets/weapons/shigure/shigure_geometry.glb'
XM, BY = -0.3087, 0.0365
S = 1.556


def P(d, y, z=0.0):
    return (XM + d / 1000.0, BY + y / 1000.0, z / 1000.0)


def PX(x, yp):
    return ((x - 13) / S, (166 - yp) / S)


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


wr.reset()
M = dict(
    alu=wr.mat('EVO anodised upper', (0.04, 0.04, 0.042), 0.35, 0.55),
    poly=wr.mat('EVO polymer', (0.035, 0.035, 0.037), 0.0, 0.6),
    grip=wr.mat('EVO grip texture', (0.035, 0.035, 0.037), 0.0, 0.72),
    steel=wr.mat('EVO steel', (0.05, 0.05, 0.05), 0.7, 0.45),
    mag=wr.mat('EVO smoke magazine', (0.06, 0.058, 0.055), 0.0, 0.32),
    brass=wr.mat('EVO brass', (0.72, 0.52, 0.24), 1.0, 0.3),
    bore=wr.mat('EVO bore', (0.01, 0.01, 0.01), 0.8, 0.5),
    mark=wr.mat('EVO marking', (0.5, 0.5, 0.5), 0.3, 0.5),
    white=wr.mat('EVO sight white', (0.8, 0.8, 0.75), 0.0, 0.5),
)
body = []

# ---------------------------------------------------------- upper receiver ----
upper = side('upper', [(112.0, -8.0), (405.0, -8.0), (413.0, 0.0), (413.0, 30.0), (365.0, 40.0), (114.0, 40.0), (110.0, 34.0)], 14.0, M['alu'])
wr.boolean(upper, side('eject_port', [(208.0, -2.0), (254.0, -2.0), (254.0, 22.0), (208.0, 22.0)], 4.0, None, z=-14.0), 'DIFFERENCE')
wr.bevel(upper, 0.0006, 2, 30)
body.append(upper)
body.append(pic_rail('top_rail', 116.0, 404.0, 48.0, M['alu']))
body.append(wr.text('mk_name', 'SHIGURE  S-9', P(270.0, 18.0, 14.05), 0.0050, M['mark'], 1))
body.append(wr.text('mk_cal', '9x19   S-9 A1', P(265.0, 6.0, 14.05), 0.0028, M['mark'], 1))
# Left-side non-reciprocating charging handle (folded forward).
ch = side('charging_handle', [(112.0, 14.0), (142.0, 14.0), (146.0, 22.0), (142.0, 28.0), (112.0, 28.0)], 3.0, M['poly'], z=16.5)
wr.bevel(ch, 0.0006, 2, 30)
body.append(ch)
body.append(side('ch_slot', [(140.0, 18.0), (330.0, 18.0), (330.0, 24.0), (140.0, 24.0)], 0.5, M['bore'], z=14.05))
# Bolt visible in the right-side port.
body.append(side('bolt_face', [(210.0, 0.0), (252.0, 0.0), (252.0, 20.0), (210.0, 20.0)], 1.0, M['steel'], z=-11.5))

# ----------------------------------------------------------- lower / grip ----
lower = side('lower', [(112.0, -8.0), (413.0, -8.0), (413.0, -18.0), PX(560, 212), PX(505, 245), (300.0, -48.0), (247.0, -48.0), (247.0, -57.0), (172.0, -57.0), (172.0, -30.0), (112.0, -30.0)], 16.5, M['poly'])
wr.boolean(lower, side('magwell', [(176.0, -70.0), (243.0, -70.0), (243.0, -20.0), (176.0, -20.0)], 12.0, None), 'DIFFERENCE')
wr.bevel(lower, 0.0008, 2, 30)
body.append(lower)
guard = side('trigger_guard', [PX(397, 241), PX(400, 278), PX(410, 284), PX(475, 284), PX(487, 272), PX(493, 262), PX(482, 262), PX(472, 276), PX(414, 277), PX(406, 270), PX(405, 241)], 6.0, M['poly'])
wr.bevel(guard, 0.0008, 2, 30)
body.append(guard)
trig = side('trigger', [PX(437, 245), PX(446, 245), PX(446, 262), PX(443, 276), PX(438, 279), PX(436, 262)], 3.0, M['poly'])
body.append(trig)
GRIP = [PX(505, 240), PX(505, 262), PX(523, 281), PX(541, 311), PX(559, 341), PX(571, 379), PX(589, 384), PX(607, 378), PX(631, 360), PX(649, 346), PX(652, 330), PX(637, 320), PX(613, 295), PX(589, 263), PX(571, 238), PX(560, 225)]
grip = side('grip', GRIP, 15.0, M['poly'])
wr.moulded(grip, voxel=0.0006, smooth_factor=0.6, smooth_iter=8, ratio=0.12)
wr.assign_faces(grip, M['grip'], lambda x, y, z: (y - BY) * 1000 < -62 and abs(z) * 1000 > 9.0)
body.append(grip)
# Ambidextrous selector, bolt catch, mag release paddle and button.
for sgn in (1, -1):
    body.append(cyl_z('selector_hub', 318.0, -18.0, sgn * 16.5, sgn * 18.2, 5.0, M['steel']))
    body.append(side('selector_lever', [(316.0, -16.0), (338.0, -10.0), (339.0, -14.0), (318.0, -21.0)], 0.9, M['steel'], z=sgn * 18.6))
body.append(side('bolt_catch', [(250.0, -14.0), (266.0, -14.0), (266.0, -24.0), (250.0, -24.0)], 1.2, M['steel'], z=17.2))
body.append(side('mag_paddle', [(244.0, -50.0), (252.0, -50.0), (256.0, -68.0), (248.0, -70.0)], 9.0, M['poly']))
body.append(cyl_z('mag_button', 256.0, -32.0, 16.5, 18.6, 4.2, M['poly']))

# --------------------------------------------------------------- handguard ----
hg = side('handguard', [(22.0, -31.0), PX(73, 134)[0:1] + (20.6,), (114.0, 47.0), (114.0, -31.0)], 21.0, M['poly'])
wr.boolean(hg, cyl('hg_bore', 10.0, 120.0, 10.5, None, seg=32), 'DIFFERENCE')
slots = []
for k in range(2):
    for sgn in (1, -1):
        slots.append(side('mlok', [(48.0 + k * 34, -14.0), (76.0 + k * 34, -14.0), (76.0 + k * 34, -6.0), (48.0 + k * 34, -6.0)], 3.0, None, z=sgn * 21.0))
wr.boolean(hg, slots, 'DIFFERENCE')
# Real A1 handguard: narrower, round-shouldered section, not a slab.
hg_round = sec('hg_round', [(z, y) for z, y in wr.superellipse(0.0, 8.0, 36.0, 80.0, 2.4, 40)], 0.0, 130.0, None)
wr.boolean(hg, hg_round, 'INTERSECT')
wr.moulded(hg, voxel=0.0006, smooth_factor=0.5, smooth_iter=4, ratio=0.15)
body.append(hg)
stop = side('hand_stop', [(23.0, -28.0), (40.0, -28.0), (38.0, -48.0), (31.0, -63.0), (26.0, -63.0)], 14.0, M['poly'])
wr.moulded(stop, voxel=0.0006, smooth_factor=0.5, smooth_iter=4, ratio=0.2)
body.append(stop)
body.append(sec('hg_rail', rail_section(-31.0 + 0.0 - 0.0)[::1] if False else [(-8.0, -31.0), (8.0, -31.0), (8.0, -36.0), (-8.0, -36.0)], 46.0, 108.0, M['poly']))

# ------------------------------------------------- barrel and thread cap ----
body.append(cyl('barrel', 6.0, 120.0, 8.0, M['steel'], seg=32))
cap = wr.tube('thread_protector', P(-0.5, 0), P(8.5, 0), 0.0095, 0.0047, M['steel'], 40)
body.append(cap)
body.append(cyl('bore_shadow', 3.0, 7.0, 4.6, M['bore'], seg=20))

# ------------------------------------------------------------------- stock ----
stock = side('stock', [(413.0, 30.0), (440.0, 26.0), (478.0, 14.5), (598.0, 14.0), (598.0, -103.0), (586.0, -103.0), (470.0, -22.0), (413.0, -17.0)], 15.0, M['poly'])
for sgn in (1, -1):
    wr.boolean(stock, side('stock_recess', [(470.0, 6.0), (566.0, 6.0), (566.0, -60.0)], 3.0, None, z=sgn * 15.5), 'DIFFERENCE')
wr.moulded(stock, voxel=0.0007, smooth_factor=0.5, smooth_iter=6, ratio=0.12)
body.append(stock)
hinge = side('stock_hinge', [(404.0, -16.0), (422.0, -16.0), (422.0, 30.0), (404.0, 30.0)], 16.0, M['alu'])
wr.bevel(hinge, 0.0008, 2, 30)
body.append(hinge)
body.append(cyl('hinge_pin', 413.0, 413.0, 0.0, None) if False else wr.cylinder('hinge_pin', P(413.0, 31.0), P(413.0, -17.0), 0.0032, M['steel'], 20))
pad = side('butt_pad', [(590.0, 15.0), (602.0, 14.0), (603.0, -100.0), (592.0, -104.0)], 15.5, M['poly'])
wr.moulded(pad, voxel=0.0007, smooth_factor=0.5, smooth_iter=4, ratio=0.2)
body.append(pad)

# ---------------------------------------------------------------- magazine ----
MAG = [PX(x, y) for x, y in [(332, 250), (400, 250), (397, 278), (391, 310), (385, 338), (373, 383), (361, 421), (353, 446), (343, 465), (289, 448), (283, 437), (289, 414), (301, 386), (313, 347), (325, 298), (331, 266)]]
mag = side('mag', MAG, 11.0, M['mag'])
wr.moulded(mag, voxel=0.0006, smooth_factor=0.5, smooth_iter=4, ratio=0.15)
mag_parts = [mag]
mag_parts.append(side('mag_floor', [PX(x, y) for x, y in [(281, 440), (289, 451), (343, 469), (357, 448), (352, 445), (341, 461), (289, 446), (284, 436)]], 13.0, M['mag']))
mag_parts.append(cyl('round', PX(398, 0)[0] - 4, PX(335, 0)[0] + 2, 4.9, M['brass'], y=-48.0, z=-2.4, seg=18))
magazine = wr.join('Shigure_Magazine', mag_parts)

# ------------------------------------------------------------- iron sights ----
irons = []
fb = plan('front_base', [(114.0, -10.6), (130.0, -10.6), (130.0, 10.6), (114.0, 10.6)], 48.0, 54.0, M['poly'])
irons.append(fb)
for sgn in (1, -1):
    irons.append(side('front_ear', [(116.0, 53.0), (128.0, 53.0), (126.0, 67.5), (118.0, 67.5)], 1.4, M['poly'], z=sgn * 7.0))
irons.append(side('front_post', [(120.6, 53.0), (123.4, 53.0), (123.0, 62.0), (121.0, 62.0)], 1.0, M['steel']))
irons.append(cyl('front_dot', 120.4, 120.6, 0.7, M['white'], y=60.5, seg=12))
rb = plan('rear_base', [(342.0, -10.6), (364.0, -10.6), (364.0, 10.6), (342.0, 10.6)], 48.0, 54.0, M['poly'])
irons.append(rb)
for sgn in (1, -1):
    irons.append(side('rear_ear', [(344.0, 53.0), (362.0, 53.0), (360.0, 67.5), (346.0, 67.5)], 1.4, M['poly'], z=sgn * 9.0))
drum = cyl_z('rear_drum', 352.0, 62.0, -7.4, 7.4, 7.0, M['poly'], 32)
wr.boolean(drum, cyl('aperture', 340.0, 364.0, 1.2, None, y=62.0, seg=20), 'DIFFERENCE')
irons.append(drum)
iron_sights = wr.join('IronSights', irons)

body_obj = wr.join('Shigure_Body', body)
objs = [body_obj, magazine, iron_sights]
print('EVO verts', {o.name: len(o.data.vertices) for o in objs}, 'total', wr.stats(objs))
wr.export(OUT, objs)
print('EXPORTED', OUT)
