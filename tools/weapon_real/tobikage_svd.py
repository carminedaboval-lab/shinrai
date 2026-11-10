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
import bpy, json
import wr
from trace import clean, squeeze, smoothstep

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / 'assets/weapons/tobikage/tobikage_geometry.glb'
XM, BY = -0.7716, 0.043


def P(d, y, z=0.0):
    return (XM + d / 1000.0, BY + y / 1000.0, z / 1000.0)


def PX(x, yp):
    return ((1309 - x) / 0.978, (211 - yp) / 0.978)


def side(name, pts, half, m, z=0.0):
    return wr.extrude_xy(name, [P(d, y)[:2] for d, y in clean(pts)], (z - half) / 1000, (z + half) / 1000, m)


REF = json.load(open(REPO / 'tools/weapon_real/refs/svd_right.json'))
OUTLINE = [PX(x, y) for x, y in REF['outline']]


def smooth_loop(pts, step=1.5, iters=10):
    """Resample a closed traced loop evenly, then Laplacian-smooth it: removes
    the ~1 px/mm stair-stepping so the wood reads as a shaped, sanded part."""
    out = []
    n = len(pts)
    for i in range(n):
        (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % n]
        L = math.hypot(x1 - x0, y1 - y0)
        k = max(1, int(L / step))
        out += [(x0 + (x1 - x0) * t / k, y0 + (y1 - y0) * t / k) for t in range(k)]
    for _ in range(iters):
        m = len(out)
        out = [(0.25 * out[i - 1][0] + 0.5 * out[i][0] + 0.25 * out[(i + 1) % m][0],
                0.25 * out[i - 1][1] + 0.5 * out[i][1] + 0.25 * out[(i + 1) % m][1]) for i in range(m)]
    return out[::2]


OUTLINE_SMOOTH = smooth_loop(OUTLINE)


def traced(name, half, m, region, mm=False, smooth=False):
    """The traced side outline, clipped to one part's region (photo pixels,
    or (d, y) mm when mm=True)."""
    o = side(name, OUTLINE_SMOOTH if smooth else OUTLINE, half, m)
    wr.boolean(o, side('clip', region if mm else [PX(x, y) for x, y in region], 80, None), 'INTERSECT')
    return o


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
# Receiver from the trace: the front block (trunnion + rear-sight base) starts
# at 577 with its bottom flush with the handguard (-25.5); the main body
# steps down to -31.5 at 635 and runs back to 950, where the cover (top ~38)
# ends over the front of the thumbhole. Behind the magazine the separate
# trigger housing hangs to -47 and carries the guard.
R_FRONT, R_REAR = 577.0, 950.0
R_STEP, R_BOT, R_BOT_F = 635.0, -31.5, -25.5
COVER_TOP = 37.5

# -------------------------------------------------------------- receiver ----
rec = side('receiver', [(R_FRONT, R_BOT_F), (R_STEP - 6, R_BOT_F), (R_STEP, R_BOT), (R_REAR - 6, R_BOT), (R_REAR, R_BOT + 5),
                        (R_REAR, 16.0), (R_REAR - 4, 20.0), (R_FRONT, 20.0)], 15.0, M['steel'])
# Early (laminated-furniture) SVD dust cover: stamped, round-topped, sloping
# down at the rear to the recoil-spring guide button, three pressed
# transverse ribs at the rear (late covers are smooth).
cov_sec = [(-15.0, 18.0), (15.0, 18.0), (14.8, 25.0), (13.6, 30.5), (11.0, 34.6), (7.0, 36.9), (0.0, COVER_TOP), (-7.0, 36.9), (-11.0, 34.6), (-13.6, 30.5), (-14.8, 25.0)]
top = sec('top_cover', cov_sec, R_FRONT + 52, R_REAR - 2, M['steel'])
wr.boolean(top, side('cover_slope', [(R_FRONT, 0.0), (R_FRONT, 45.0), (R_REAR - 26, 45.0), (R_REAR - 2, 27.0), (R_REAR - 2, 0.0)], 30, None), 'INTERSECT')
for _dd in (852.0, 872.0, 892.0):
    rib = sec('cover_rib', [(z * 1.055, 26.0 + (y - 26.0) * 1.075) for z, y in cov_sec], _dd, _dd + 7, M['steel'])
    wr.boolean(rib, side('rib_keep', [(_dd - 2, 23.5), (_dd + 9, 23.5), (_dd + 9, 50), (_dd - 2, 50)], 30, None), 'INTERSECT')
    top = wr.join('top_cover', [top, rib])
# Recoil-spring guide button through the rear of the cover.
body.append(sec('spring_button', [(-4.5, 21.0), (4.5, 21.0), (4.5, 29.0), (-4.5, 29.0)], R_REAR - 6, R_REAR + 3, M['steel']))
# Ejection port behind the charging handle, the handle slot on the right.
cuts = [side('eject_port', [(670.0, -1.0), (750.0, -1.0), (750.0, 17.0), (670.0, 17.0)], 6, None, z=-15.0),
        side('handle_slot', [(650.0, 6.0), (790.0, 6.0), (790.0, 12.0), (650.0, 12.0)], 4, None, z=-15.0)]
rec = wr.join('receiver', [rec, top])
# Shallow milled lightening panel on each side of the machined receiver.
for sgn in (1, -1):
    cuts.append(side('side_recess', [(R_STEP + 12, R_BOT + 6), (R_REAR - 30, R_BOT + 6), (R_REAR - 30, -6.0), (R_STEP + 12, -6.0)], 0.8, None, z=sgn * 15.0))
wr.boolean(rec, cuts, 'DIFFERENCE')
# Magazine well opening in the bottom.
wr.boolean(rec, side('magwell', [(666.0, -60.0), (777.0, -60.0), (777.0, -20.0), (666.0, -20.0)], 13.6, None), 'DIFFERENCE')
wr.bevel(rec, 0.0006, 2, 30)
body.append(rec)
# Front trunnion block with the tangent rear-sight base on it.
tr = sec('trunnion', [(-16.0, R_BOT_F), (16.0, R_BOT_F), (16.0, 22.0), (12.0, 30.0), (-12.0, 30.0), (-16.0, 22.0)], R_FRONT - 4, R_FRONT + 40, M['steel'])
wr.bevel(tr, 0.0006, 2, 30)
body.append(tr)
rs = sec('rear_sight_block', [(-12.5, 28.0), (12.5, 28.0), (12.5, 38.0), (9.0, 42.0), (-9.0, 42.0), (-12.5, 38.0)], R_FRONT + 4, R_FRONT + 50, M['steel'])
wr.bevel(rs, 0.0005, 2, 30)
body.append(rs)
# Leaf-spring housing at the back of the sight base.
body.append(sec('sight_spring', [(-7.0, 28.0), (7.0, 28.0), (7.0, 36.0), (-7.0, 36.0)], R_FRONT + 50, R_FRONT + 58, M['steel']))
# Left-side Warsaw-pact dovetail rail (PSO mount) with its recoil slot, screwed
# to the receiver behind the magazine well.
rail = side('side_rail', [(712.0, -5.0), (872.0, -5.0), (872.0, 13.0), (712.0, 13.0)], 2.4, M['steel'], z=17.2)
wr.boolean(rail, [side('rail_groove', [(705.0, 2.0), (880.0, 2.0), (880.0, 6.0), (705.0, 6.0)], 1.1, None, z=19.6),
                  side('rail_stop', [(786.0, -8.0), (796.0, -8.0), (796.0, 16.0), (786.0, 16.0)], 1.6, None, z=19.6)], 'DIFFERENCE')
wr.bevel(rail, 0.0004, 2, 30)
body.append(rail)
for dd in (725.0, 859.0):
    body.append(cyl_z('rail_screw', dd, 4.0, 19.4, 20.3, 2.6, M['steel']))
# Cross pins: front trunnion, trigger-housing axes.
for s in (1, -1):
    body.append(cyl_z('pin', 600.0, -14.0, s * 15.4, s * 16.6, 2.8, M['steel'], 16))
    for dd in (812.0, 884.0):
        body.append(cyl_z('pin', dd, -39.5, s * 12.4, s * 13.6, 2.4, M['steel'], 16))
# AK-type safety lever on the right, shown on SAFE closing the handle slot;
# pivot at the rear over the trigger.
sl = side('safety_lever', [(700.0, 5.0), (868.0, 7.5), (880.0, 4.5), (880.0, 15.0), (868.0, 16.0), (700.0, 13.5), (694.0, 9.0)], 0.9, M['steel'], z=-16.2)
wr.bevel(sl, 0.0003, 2, 30)
body.append(sl)
body.append(side('safety_tab', [(700.0, 13.5), (712.0, 13.5), (712.0, 20.0), (700.0, 20.0)], 2.2, M['steel'], z=-17.0))
body.append(cyl_z('safety_pivot', 874.0, 9.0, -15.0, -17.6, 5.0, M['steel']))
# Receiver-cover catch lever, the small lever behind the safety.
cl = side('cover_catch', [(900.0, 4.0), (924.0, 5.5), (926.0, 10.0), (912.0, 13.0), (900.0, 11.0)], 0.9, M['steel'], z=-16.2)
wr.bevel(cl, 0.0003, 2, 30)
body.append(cl)
body.append(cyl_z('catch_pivot', 905.0, 8.0, -15.0, -17.4, 3.4, M['steel']))
# Magazine release paddle behind the magazine.
mr = side('mag_release', [(778.0, R_BOT), (792.0, R_BOT), (793.0, -66.0), (787.0, -70.0), (780.0, -60.0)], 7.0, M['steel'])
wr.bevel(mr, 0.0004, 2, 30)
body.append(mr)
# Removable trigger housing (carries the guard) under the rear of the receiver.
th = side('trigger_housing', [(792.0, R_BOT + 1), (902.0, R_BOT + 1), (902.0, -47.0), (796.0, -47.0), (792.0, -44.0)], 13.0, M['steel'])
wr.bevel(th, 0.0006, 2, 30)
body.append(th)
tg = side('trigger_guard', [(836.0, -46.0), (902.0, -46.0), (904.0, -62.0), (898.0, -75.5), (852.0, -76.0), (840.0, -70.0)], 5.0, M['steel'])
wr.boolean(tg, side('guard_hole', [(845.0, -40.0), (893.0, -40.0), (894.0, -63.0), (889.0, -70.5), (856.0, -71.0), (847.0, -63.0)], 20, None), 'DIFFERENCE')
wr.bevel(tg, 0.0005, 2, 30)
body.append(tg)
trig = side('trigger', [(856.0, -46.0), (863.0, -46.0), (864.0, -54.0), (869.0, -63.0), (866.0, -65.5), (860.0, -57.0)], 2.6, M['steel'])
wr.bevel(trig, 0.0003, 2, 30)
body.append(trig)
# Markings: model and serial on the left behind the rail, serial on the cover.
body.append(wr.text('mk_model', 'T-65', P(912.0, 6.0, 15.04), 0.0045, M['mark'], 1))
body.append(wr.text('mk_serial', '1987  TK 4402', P(905.0, -14.0, 15.04), 0.0026, M['mark'], 1))

# --------------------------------------------------------- barrel group ----
body.append(cyl('barrel', 60.0, 240.0, 11.0, M['steel'], seg=40, r1=11.6))
body.append(cyl('barrel_shank', 240.0, R_FRONT + 30, 12.0, M['steel'], seg=40, r1=13.0))
# Gas block clamped on the barrel; the two-position regulator sleeve sticks
# out of the front of the gas chamber (turned with a cartridge rim, hence the
# slot across its face, "1"/"2" stamped beside it). Gas tube above the barrel.
gb = side('gas_block', [(227.0, -16.0), (262.0, -16.0), (262.0, 38.0), (242.0, 38.0), (236.0, 33.0), (236.0, 18.0), (229.0, 13.0), (227.0, 6.0)], 13.0, M['steel'])
wr.bevel(gb, 0.0008, 2, 30)
body.append(gb)
reg = cyl('gas_regulator', 222.0, 237.0, 8.2, M['steel'], y=26.5, seg=32)
wr.boolean(reg, sec('reg_slot', [(-6.0, 25.5), (6.0, 25.5), (6.0, 27.5), (-6.0, 27.5)], 220.0, 224.5, None), 'DIFFERENCE')
wr.bevel(reg, 0.0003, 2, 30)
body.append(reg)
body.append(wr.text('mk_reg1', '1', P(239.0, 33.5, -13.04), 0.0032, M['mark'], -1))
body.append(wr.text('mk_reg2', '2', P(239.0, 19.5, -13.04), 0.0032, M['mark'], -1))
body.append(cyl('gas_tube', 255.0, 345.0, 10.2, M['steel'], y=26.5, seg=32))
# Front sling swivel on the left of the gas block (SVD slings hang left).
body.append(side('swivel_lug_f', [(238.0, -6.0), (252.0, -6.0), (252.0, 4.0), (238.0, 4.0)], 2.0, M['steel'], z=14.5))
body.append(wr.tube('sling_swivel_f', P(245.0, -13.0, 15.6), P(245.0, -13.0, 18.2), 0.0092, 0.0071, M['steel'], 24))
# Front sight block: closed ring hood over the post, bayonet lug below.
fsb = side('front_sight_block', [(99.0, -14.5), (126.0, -14.5), (126.0, 10.0), (120.0, 22.0), (104.0, 22.0), (99.0, 12.0)], 11.0, M['steel'])
wr.bevel(fsb, 0.0006, 2, 30)
body.append(fsb)
hood = wr.tube('front_sight_hood', P(102.0, 41.5), P(122.0, 41.5), 0.0135, 0.0116, M['steel'], 40)
body.append(hood)
for sgn in (1, -1):
    body.append(side('hood_leg', [(104.0, 20.0), (120.0, 20.0), (119.0, 33.0), (105.0, 33.0)], 1.6, M['steel'], z=sgn * 10.4))
lug = side('bayonet_lug', [(110.0, -14.0), (130.0, -14.0), (130.0, -22.5), (114.0, -22.5), (110.0, -19.0)], 3.5, M['steel'])
wr.bevel(lug, 0.0004, 2, 30)
body.append(lug)
# Five-slot flash hider, chamfered nose.
fh = wr.tube('flash_hider', P(-1.0, 0), P(99.0, 0), 0.0138, 0.0062, M['steel'], 48)
wr.boolean(fh, cyl('fh_chamfer', -2.0, 99.5, 10.6, None, seg=48, r1=10.6 + 101.5), 'INTERSECT')
wr.smooth(fh, 30)
slots = []
for k in range(5):
    th = math.radians(72 * k)
    c, sn = math.cos(th), math.sin(th)
    w2, r0, r1 = 2.1, 6.0, 16.0
    poly = [(-w2 * c + r0 * sn, r0 * c + w2 * sn), (w2 * c + r0 * sn, r0 * c - w2 * sn), (w2 * c + r1 * sn, r1 * c - w2 * sn), (-w2 * c + r1 * sn, r1 * c + w2 * sn)]
    slots.append(sec('fh_slot', poly, 12.0, 74.0, None))
wr.boolean(fh, slots, 'DIFFERENCE')
body.append(fh)
body.append(cyl('bore_shadow', 8.0, 14.0, 6.15, M['bore'], seg=24))

# ------------------------------------------------------------ handguard ----
HG0, HG1 = 336.0, 579.0
hg_sec = [(z, y) for z, y in wr.superellipse(0.0, 10.0, 50.0, 71.0, 2.6, 36)]
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
    ring = sec('hg_ring', [(z, y) for z, y in wr.superellipse(0.0, 10.0, 52.0, 73.0, 2.6, 36)], dd0, dd1, M['steel'])
    wr.boolean(ring, cyl('ring_core', dd0 - 2, dd1 + 2, 14.0, None, y=6.0), 'DIFFERENCE')
    body.append(ring)
body.append(cyl_z('hg_latch', HG0 + 3, 8.0, -26.0, -29.0, 3.8, M['steel']))

# ---------------------------------------------------------------- stock ----
# Stock outline (cheek rest, comb, skeleton, grip) straight from the trace.
# The photo's receiver runs back to d~950 (cover top ~39 mm), so the stock
# starts behind it: the comb tang meets the receiver's rear face, the grip
# starts behind the trigger guard under the receiver.
stock = traced('stock', 18.5, M['wood'], [(1000.0, 60.0), (1240.0, 60.0), (1240.0, -160.0), (900.0, -160.0), (899.0, -47.0),
                                          (903.0, R_BOT + 1.0), (R_REAR - 4, R_BOT + 1.0), (R_REAR - 4, 12.0), (1000.0, 12.0)], mm=True, smooth=True)
wr.boolean(stock, side('thumbhole', smooth_loop([PX(x, y) for x, y in REF['thumbhole']], 1.5, 8), 30, None), 'DIFFERENCE')
# The detachable cheek rest is domed on top (it narrows from 37 mm to a
# rounded crown); the comb and butt are well-radiused sanded laminate, and the
# sides swell slightly through the wrist instead of being two flat boards.
taper = sec('stock_taper', [(-9.0, 31.0), (9.0, 31.0), (13.5, 28.5), (16.8, 24.0), (17.7, 17.0), (18.3, -8.0), (18.5, -40.0), (18.2, -90.0), (17.3, -150.0), (-17.3, -150.0), (-18.2, -90.0), (-18.5, -40.0), (-18.3, -8.0),
                            (-17.7, 17.0), (-16.8, 24.0), (-13.5, 28.5)], 520.0, 1260.0, None)
wr.boolean(stock, taper, 'INTERSECT')
# Voxelise first so the squeeze below has vertices to move, then soften and
# decimate (squeezing the decimated mesh streaked its long triangles).
wr.moulded(stock, voxel=0.0007, smooth_factor=0.0, smooth_iter=0, ratio=1.0)
# The pistol grip of the thumbhole stock is a 37 mm board in the trace; the
# real wrist is about 31 mm. Squeeze it smoothly (no steps) below the receiver
# and ahead of the thumbhole, fading back to full width into the butt bar.
squeeze(stock, XM, BY, lambda d, y: 1.0 - 0.16 * smoothstep(-38.0, -68.0, y) * (1.0 - smoothstep(962.0, 1045.0, d)) * smoothstep(870.0, 885.0, d))
wr.moulded(stock, voxel=0.0007, smooth_factor=0.55, smooth_iter=22, ratio=0.08)
# Detachable cheek rest: it sits on the comb (comb top ~4-9 mm above the
# bore), so its parting line is a real gap low on both sides, not a painted
# stripe.
wr.boolean(stock, [side('cheek_gap', [(1007.0, 6.0), (1139.0, 4.6), (1139.0, 5.8), (1007.0, 7.2)], 1.7, None, z=sgn * 18.4) for sgn in (1, -1)], 'DIFFERENCE')
# The groove walls must shade sharp, or smooth normals blur the gap away.
for _p in stock.data.polygons:
    _c = _p.center  # Blender (x, -z, y)
    _d, _y, _z = (_c.x - XM) * 1000, (_c.z - BY) * 1000, -_c.y * 1000
    if 1004 < _d < 1142 and 3.5 < _y < 8.2 and 16.0 < abs(_z) < 17.95:
        _p.use_smooth = False
wr.clean_slots(stock, M['wood'])
body.append(stock)
body.append(cyl_z('cheek_latch', PX(300, 190)[0], PX(300, 190)[1], -18.2, -20.2, 4.0, M['steel']))
pad = side('butt_pad', [PX(119, 210), PX(110, 212), PX(108, 230), PX(108, 336), PX(114, 342), PX(121, 340), PX(121, 212)], 18.0, M['rubber'])
wr.moulded(pad, voxel=0.0008, smooth_factor=0.5, smooth_iter=4, ratio=0.12)
body.append(pad)
# Rear sling swivel: screwed plate on the left of the butt, ring hanging down.
body.append(side('swivel_plate_r', wr.rounded_rect(1158.0, -108.0, 26.0, 11.0, 4.0, 3), 0.8, M['steel'], z=18.4))
for dd in (1149.0, 1167.0):
    body.append(cyl_z('swivel_screw', dd, -108.0, 19.0, 19.5, 2.2, M['steel'], 16))
body.append(wr.tube('sling_swivel_r', P(1158.0, -112.0, 19.6), P(1158.0, -112.0, 22.2), 0.0092, 0.0071, M['steel'], 24))

# ---------------------------------------------------------------- action ----
# Bolt face at the chamber (~d 668, over the front of the magazine); the
# carrier carries the handle at its front right, ahead of the ejection port.
act = [sec('carrier', [(-11.0, 2.0), (11.0, 2.0), (11.0, 16.0), (-11.0, 16.0)], 645.0, 860.0, M['dark'])]
act.append(cyl('bolt', 668.0, 712.0, 7.0, M['steel'], y=1.0, seg=28))
act.append(side('extractor', [(668.0, -1.0), (690.0, -1.0), (690.0, 3.5), (668.0, 3.5)], 1.0, M['steel'], z=-7.0))
act.append(side('handle_stem', [(650.0, 6.5), (662.0, 6.5), (662.0, 11.5), (650.0, 11.5)], 10.0, M['steel'], z=-21.0))
knob = cyl_z('handle_knob', 656.0, 9.0, -27.0, -37.0, 6.6, M['steel'], 28)
act.append(knob)
action = wr.join('Action', act)

# -------------------------------------------------------------- magazine ----
# Traced magazine with the real stamping: two 'H' rib groups above, three
# full-width ribs near the base.
# Top of the clip reaches into the receiver's magwell (receiver bottom -31.5).
mag = traced('mag', 13.2, M['mag'], [(548, 239), (656, 239), (656, 352), (548, 352)])
ribs = []
for sgn in (1, -1):
    for x0 in (575, 615):
        for xv in (x0, x0 + 18):
            ribs.append(side('mag_rib_v', [PX(xv, 262), PX(xv + 4, 262), PX(xv + 4, 316), PX(xv, 316)], 0.8, M['mag'], z=sgn * 13.4))
        ribs.append(side('mag_rib_x', [PX(x0, 287), PX(x0 + 22, 287), PX(x0 + 22, 291), PX(x0, 291)], 0.8, M['mag'], z=sgn * 13.4))
    for yb, xa, xb in ((321, 566, 646), (327, 568, 643), (333, 571, 636)):
        ribs.append(side('mag_rib_b', [PX(xa, yb), PX(xb, yb - 3), PX(xb, yb), PX(xa, yb + 3)], 0.8, M['mag'], z=sgn * 13.4))
mag = wr.join('mag', [mag] + ribs)
wr.bevel(mag, 0.0006, 2, 30)
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
for _o in objs:
    if _o.data.validate(verbose=False, clean_customdata=False):
        print('validated (fixed)', _o.name)
print('SVD verts', {o.name: len(o.data.vertices) for o in objs}, 'total', wr.stats(objs))
wr.export(OUT, objs)
print('EXPORTED', OUT)
