"""SHIGURE / S-9 rebuilt as its real counterpart: CZ Scorpion EVO 3 A1, 9x19.

blender --background --python tools/weapon_real/shigure_evo3.py
The whole side outline is traced from "Scorpion EVO 3 A1 left.jpg" (Wikimedia
Commons, 3807 px; refs/evo3a1_left.json) at 6.1 px/mm, measured from the
10.0 mm Picatinny slot pitch. Seams, panels and controls are placed from the
same photo at native resolution. The photo's Aimpoint is replaced by the bare
rail. Frame: d = mm behind the muzzle, y = mm above the bore, z = mm left.

Third pass (part-by-part check against the photo and CZ's published spec):
- one continuous MIL-STD-1913 top rail with the real dovetail cross-section
  and 5.3 mm cross slots at the photo's slot positions (the upper carries it
  forward to the front sight); flat-topped upper with chamfered shoulders
  instead of the photo's optic-mount and slot-tooth silhouette;
- M-LOK handguard: hollow shell around the barrel, 32 x 7.6 mm through-slots
  at 3, 6 and 9 o'clock (40 mm pitch), charging-handle scoop, integral hand
  stop; side Picatinny strips removed;
- charging handle moved to where the photo has it (front of the upper, in a
  slot that runs along both sides), front takedown pin, ambidextrous bolt
  catch/release paddles, selector pictograms on the lower (safe dot, 1, 3 and
  auto bullets) on both sides;
- flared magwell (the front flare was missing), cylindrical flash hider with a
  flash cone and a bored barrel;
- rotating rear drum (three through-apertures) between the protective ears,
  front post on a threaded base between its ears, sight clamp screws;
- translucent smoked magazine with a staggered double stack of 9x19 FMJ
  rounds and the follower visible through it (separate material names, so
  the imported alpha is kept rather than replaced by the opaque finish);
- rubber (textured) butt pad, hinge lock button.
"""
import sys, os, math, json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy
import wr
from trace import shape, span_at, clean, lathe

REPO = Path(__file__).resolve().parents[2]
OUT = Path(os.environ.get('SHIGURE_OUT', str(REPO / 'assets/weapons/shigure/shigure_geometry.glb')))
REF = json.load(open(REPO / 'tools/weapon_real/refs/evo3a1_left.json'))
S, MX, BYPX = REF['scale_px_per_mm'], 51.0, 662.0
XM, BY = -0.3166, 0.0322


def N(x, y):
    return ((x - MX) / S, (BYPX - y) / S)


def nd(x):
    return (x - MX) / S


def ny(y):
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


def part(name, half, m, native_region, z=0.0):
    o = side(name, OUTLINE, half, m, z)
    wr.boolean(o, nside('clip', native_region, 80, None), 'INTERSECT')
    return o


def raised(name, native, host, m, h=1.6, sides=(1, -1)):
    out = []
    for s in sides:
        o = nside(name, native, h / 2 + 1.0, m, z=s * (host + h / 2 - 1.2))   # sunk 1.2 mm: seats on crowned faces
        wr.bevel(o, min(0.0004, h / 2600.0), 3, 30)
        out.append(o)
    return out


def recess(native, host, depth=1.2, sides=(1, -1)):
    return [nside('recess', native, depth, None, z=s * host) for s in sides]


def circ(cx, cy, r, n=16):
    return [(cx + r * math.cos(2 * math.pi * k / n), cy + r * math.sin(2 * math.pi * k / n)) for k in range(n)]


def stadium(c0, c1, length, height, n=8):
    """Slot outline (rounded ends) centred at (c0, c1), long along the first axis."""
    r = height / 2
    a, b = c0 - (length / 2 - r), c0 + (length / 2 - r)
    pts = [(b + r * math.cos(-math.pi / 2 + math.pi * k / n), c1 + r * math.sin(-math.pi / 2 + math.pi * k / n)) for k in range(n + 1)]
    pts += [(a + r * math.cos(math.pi / 2 + math.pi * k / n), c1 + r * math.sin(math.pi / 2 + math.pi * k / n)) for k in range(n + 1)]
    return pts


def glass(name, color, alpha, rough):
    """Smoked translucent polymer. The name is not in the finish table, so the
    imported (alpha-blended) material is kept in game."""
    m = wr.mat(name, color, 0.0, rough)
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Alpha'].default_value = alpha
    for attr, val in (('surface_render_method', 'BLENDED'), ('blend_method', 'BLEND')):
        try:
            setattr(m, attr, val)
        except Exception:
            pass
    return m


wr.reset()
M = dict(
    alu=wr.mat('EVO anodised upper', (0.04, 0.04, 0.042), 0.35, 0.55),
    poly=wr.mat('EVO polymer', (0.035, 0.035, 0.037), 0.0, 0.6),
    grip=wr.mat('EVO grip texture', (0.035, 0.035, 0.037), 0.0, 0.72),
    steel=wr.mat('EVO steel', (0.05, 0.05, 0.05), 0.7, 0.45),
    smoke=glass('EVO smoke magazine shell', (0.045, 0.042, 0.038), 0.78, 0.2),
    smoke_base=glass('EVO smoke magazine base', (0.035, 0.032, 0.03), 0.9, 0.28),
    brass=wr.mat('EVO cartridge brass', (0.78, 0.58, 0.3), 1.0, 0.28),
    fmj=wr.mat('EVO FMJ bullet', (0.66, 0.38, 0.24), 1.0, 0.3),
    follower=wr.mat('EVO follower', (0.7, 0.7, 0.68), 0.0, 0.55),
    bore=wr.mat('EVO bore', (0.01, 0.01, 0.01), 0.8, 0.5),
    mark=wr.mat('EVO marking', (0.5, 0.5, 0.5), 0.3, 0.5),
    red=wr.mat('EVO selector paint', (0.7, 0.08, 0.05), 0.0, 0.5),
    white=wr.mat('EVO sight white', (0.8, 0.8, 0.75), 0.0, 0.5),
)
HG, UP, LO, ST = 22.0, 17.5, 18.5, 16.0
SL = ny(290)                 # sight line, 61.0 mm above the bore (IronRear/FrontSight sockets)
YT, YB = ny(360), ny(400)    # rail top 49.5 mm, receiver top (rail base) 42.95 mm
body = []

# ------------------------------------------------------------ muzzle/barrel ----
# CZ's standard cylindrical flash hider on the M18x1 thread: traced outside,
# flash cone inside, then the bored barrel.
fh = lathe('flash_hider', P, OUTLINE, 0.0, nd(228), 0.6, M['steel'], reach=14.0)   # reach: ignore the hand stop below
wr.boolean(fh, [wr.cylinder('fh_cone', P(-1.0, 0), P(16.0, 0), 0.0076, None, 32, radius_b=0.0049),
                wr.cylinder('fh_bore', P(15.0, 0), P(31.0, 0), 0.0049, None, 32)], 'DIFFERENCE')
wr.bevel(fh, 0.0003, 2, 40)
body.append(fh)
barrel = wr.cylinder('barrel', P(28.5, 0), P(205.0, 0), 0.0079, M['steel'], 40)
wr.boolean(barrel, wr.cylinder('bore', P(27.0, 0), P(44.0, 0), 0.0045, None, 24), 'DIFFERENCE')
body.append(barrel)
body.append(wr.cylinder('bore_shadow', P(43.0, 0), P(44.5, 0), 0.0046, M['bore'], 20))

# ------------------------------------------------------- M-LOK handguard ----
hg = part('handguard', HG, M['poly'], [(244, 300), (760, 300), (760, 452), (1250, 452), (1250, 845), (244, 845)])
wr.boolean(hg, sec('hg_round', [(z, y) for z, y in wr.superellipse(0.0, ny(581), 2 * HG, 96.0, 3.0, 40)], 20, 210), 'INTERSECT')
cuts = [sec('hg_channel', [(z, y) for z, y in wr.superellipse(0.0, 0.0, 2 * (HG - 3.2), 50.0, 3.0, 36)], nd(430), 210)]
for dc in (92.0, 132.0, 172.0):                       # 3 and 9 o'clock M-LOK slots
    cuts.append(side('mlok_side', stadium(dc, 3.0, 32.0, 7.6), 30.0, None))
for dc in (100.0, 140.0):                             # 6 o'clock M-LOK slots
    cuts.append(wr.extrude_xz('mlok_bottom', [(P(a, 0)[0], b / 1000) for a, b in stadium(dc, 0.0, 32.0, 7.6)], BY - 0.042, BY - 0.018))
cuts += recess([(1140, 515), (1250, 515), (1250, 600), (1140, 600)], HG, 2.0, sides=(1,))   # charging-handle scoop
wr.boolean(hg, cuts, 'DIFFERENCE')
wr.bevel(hg, 0.0007, 2, 30)
body.append(hg)
stop = part('hand_stop', 16.0, M['poly'], [(190, 735), (545, 735), (545, 1070), (190, 1070)])
wr.moulded(stop, voxel=0.0006, smooth_factor=0.5, smooth_iter=5, ratio=0.2)
body.append(stop)

# ----------------------------------------------------------- upper receiver ----
# Flat-topped aluminium upper; it runs forward over the handguard to the front
# sight and carries one continuous top rail.
upper = part('upper', UP, M['alu'], [(760, 400), (2440, 400), (2440, 708), (1250, 708), (1250, 452), (760, 452)])
wr.boolean(upper, sec('up_shoulders', [(-UP, -80), (UP, -80), (UP, YB - 5.0), (UP - 5.0, YB + 0.01), (-(UP - 5.0), YB + 0.01), (-UP, YB - 5.0)], 100, 400), 'INTERSECT')
cuts = recess([(1250, 538), (2050, 538), (2050, 556), (1250, 556)], UP, 3.0)                 # charging-handle slot, both sides
cuts.append(nside('eject_port', [(1450, 565), (1720, 565), (1720, 690), (1450, 690)], 4.0, None, z=-UP))
wr.boolean(upper, cuts, 'DIFFERENCE')
wr.bevel(upper, 0.0006, 2, 30)
body.append(upper)
RAIL = [(-8.4, YT), (8.4, YT), (10.6, YT - 2.2), (10.6, YT - 3.0), (8.0, YT - 5.6), (8.0, YB - 1.0),
        (-8.0, YB - 1.0), (-8.0, YT - 5.6), (-10.6, YT - 3.0), (-10.6, YT - 2.2)]
rail = sec('top_rail', RAIL, nd(765), nd(2428), M['alu'])
slot_d = [nd(1089 + 59.75 * k) for k in range(-1, 18)]
wr.boolean(rail, [sec('rail_slot', [(-12, YT - 2.9), (12, YT - 2.9), (12, YT + 2), (-12, YT + 2)], d - 2.65, d + 2.65) for d in slot_d], 'DIFFERENCE')
wr.bevel(rail, 0.0003, 2, 30)
body.append(rail)
body.append(wr.text('mk_name', 'SHIGURE  S-9  A1', P(*N(1648, 590), UP + 0.01), 0.0052, M['mark'], 1))
body.append(wr.text('mk_serial', 'S9 041872', P(*N(2130, 600), -UP - 0.01), 0.0034, M['mark'], -1))
body.append(wr.text('mk_cal', 'cal. 9x19', P(*N(2130, 640), -UP - 0.01), 0.0034, M['mark'], -1))
bolt = nside('bolt_face', [(1452, 567), (1718, 567), (1718, 688), (1452, 688)], 1.0, M['steel'], z=-UP + 2.5)
body.append(bolt)
body.append(nside('extractor', [(1460, 600), (1520, 600), (1520, 622), (1460, 622)], 0.5, M['steel'], z=-UP + 1.2))
# Non-reciprocating charging handle at the front of its slot (left side).
cx, cy = N(1272, 547)
body.append(side('ch_stem', wr.rounded_rect(cx, cy, 9.0, 2.8, 1.0, 3), 2.2, M['steel'], z=UP))
knob = side('ch_knob', [(x, y) for x, y in wr.superellipse(cx - 1.0, cy + 0.5, 12.5, 9.0, 3.0, 28)], 4.0, M['poly'], z=UP + 6.0)
wr.bevel(knob, 0.0009, 2, 30)
body.append(knob)

# ------------------------------------------------------------------ sights ----
fs = part('front_sight', 12.5, M['poly'], [(740, 230), (1022, 230), (1022, 405), (740, 405)])
wr.boolean(fs, sec('fs_window', [(-4.0, 38), (4.0, 38), (4.0, 80), (-4.0, 80)], 115, 165), 'DIFFERENCE')
wr.bevel(fs, 0.0006, 2, 30)
body.append(fs)
body.append(wr.cylinder('fs_post_base', P(128.3, 38.0), P(128.3, SL - 8.0), 0.0021, M['steel'], 16))
body.append(side('front_post', [(127.5, SL - 9), (129.1, SL - 9), (128.9, SL), (127.7, SL)], 0.8, M['steel']))
for s in (1, -1):
    body.append(wr.cylinder('fs_clamp', P(nd(960), ny(392), s * 12.3), P(nd(960), ny(392), s * 14.0), 0.0026, M['steel'], 16))

DR = 368.7   # rear drum centre (IronRearSight socket)
rs = part('rear_sight', 12.5, M['poly'], [(2160, 230), (2445, 230), (2445, 405), (2160, 405)])
# Open front and back between the protective ears, so the sight line is clear.
wr.boolean(rs, sec('rs_window', [(-7.6, SL - 9.5), (7.6, SL - 9.5), (7.6, 90), (-7.6, 90)], DR - 30.0, DR + 30.0), 'DIFFERENCE')
wr.bevel(rs, 0.0006, 2, 30)
drum = wr.cylinder('rs_drum', P(DR, SL, -7.2), P(DR, SL, 7.2), 0.0072, M['steel'], 36)
c45 = 9.0 * math.cos(math.radians(45))
wr.boolean(drum, [wr.cylinder('ap_main', P(DR - 9, SL), P(DR + 9, SL), 0.0013, None, 20),
                  wr.cylinder('ap_45', P(DR - c45, SL - c45), P(DR + c45, SL + c45), 0.0018, None, 20),
                  wr.cylinder('ap_90', P(DR, SL - 9), P(DR, SL + 9), 0.0024, None, 20)], 'DIFFERENCE')
wr.bevel(drum, 0.0003, 2, 40)
rs_parts = [rs, drum, wr.cylinder('rs_windage', P(DR, ny(388), -12.3), P(DR, ny(388), -14.2), 0.0024, M['steel'], 16)]
rs_parts.append(wr.cylinder('rs_clamp', P(nd(2400), ny(392), -12.3), P(nd(2400), ny(392), -14.0), 0.0026, M['steel'], 16))

# ------------------------------------------------------- lower / fire control ----
LOWER_REGION = [(1250, 706), (2440, 706), (2440, 960), (2290, 960), (2060, 1140), (1640, 1140),
                (1640, 1030), (1290, 1030), (1180, 850), (1250, 850)]
lower = part('lower', LO + 0.8, M['poly'], LOWER_REGION)
# Moulded polymer lower: square where it mates with the upper, the sides draw
# in and round over toward the trigger guard and magwell.
_LR = [N(x, y) for x, y in LOWER_REGION]
shape(lower, P, None, LO, d_range=(min(p[0] for p in _LR), max(p[0] for p in _LR)),
      span_fn=lambda d: (span_at(_LR, d)[0] if span_at(_LR, d) else ny(1140), 80.0), r=4.0, crown=0.5, bot=0.93, step=3.0)
wr.boolean(lower, nside('guard_hole', [(1680, 945), (1965, 925), (2012, 985), (2010, 1005), (1946, 1061), (1836, 1079), (1748, 1087), (1727, 1068), (1675, 978)], 40, None), 'DIFFERENCE')
flare = wr.loft('magwell_flare', [
    [P(nd(1330), ny(975), -12.6), P(nd(1600), ny(975), -12.6), P(nd(1600), ny(975), 12.6), P(nd(1330), ny(975), 12.6)],
    [P(nd(1302), ny(1045), -15.4), P(nd(1626), ny(1045), -15.4), P(nd(1626), ny(1045), 15.4), P(nd(1302), ny(1045), 15.4)]])
wr.boolean(lower, [nside('magwell', [(1335, 760), (1595, 760), (1610, 1100), (1320, 1100)], 12.6, None), flare], 'DIFFERENCE')
wr.bevel(lower, 0.0008, 2, 30)
body.append(lower)
body.append(nside('trigger', [(1880, 943), (1893, 982), (1893, 1026), (1887, 1046), (1887, 1056), (1896, 1059), (1913, 1050), (1925, 1020), (1931, 994), (1931, 942)], 3.0, M['poly']))
# Ambidextrous selector with its pictograms (safe dot; 1, 3 and auto bullets).
HUB = N(1985, 748)
BULLET = [(-0.45, -1.3), (0.45, -1.3), (0.45, 0.45), (0.0, 1.3), (-0.45, 0.45)]
for s in (1, -1):
    body.append(wr.cylinder('selector_hub', P(*HUB, s * (LO - 1.2)), P(*HUB, s * (LO + 2.2)), 0.0052, M['steel'], 28))
    # Thumb lever, shown on SAFE (pointing at the white dot).
    ua = (math.cos(math.radians(200)), math.sin(math.radians(200)))
    na = (-ua[1], ua[0])
    lev = [(HUB[0] + ua[0] * a + na[0] * b, HUB[1] + ua[1] * a + na[1] * b)
           for a, b in ((-3.0, 4.2), (11.0, 2.9), (13.0, 1.4), (13.0, -1.4), (11.0, -2.9), (-3.0, -4.2))]
    lever = side('selector_lever', lev, 1.1, M['steel'], z=s * (LO + 2.8))
    wr.bevel(lever, 0.0004, 2, 30)
    body.append(lever)
    for ang, count in ((200, 0), (235, 1), (270, 3), (305, 5)):
        cxm = HUB[0] + 16.5 * math.cos(math.radians(ang))
        cym = HUB[1] + 16.5 * math.sin(math.radians(ang))
        if count == 0:
            body.append(wr.cylinder('mode_safe', P(cxm, cym, s * (LO - 0.05)), P(cxm, cym, s * (LO + 0.15)), 0.0012, M['white'], 12))
            continue
        for k in range(count):
            ox = (k - (count - 1) / 2) * 1.25
            body.append(side('mode_bullet', [(cxm + ox + a, cym + b) for a, b in BULLET], 0.1, M['red'], z=s * (LO + 0.05)))
body += raised('release_lever', [(1575, 731), (1756, 731), (1756, 790), (1700, 846), (1575, 846)], LO, M['poly'], 3.0)
body += raised('takedown_pin', circ(1336, 717, 16), LO, M['steel'], 1.8, sides=(1,))
body.append(nside('mag_paddle', [(1600, 1040), (1640, 1040), (1650, 1135), (1615, 1140)], 9.0, M['poly']))
# Raked grip with its palm shelf and texture.
grip = part('grip', 15.5, M['poly'], [(2050, 800), (2640, 800), (2640, 1540), (2050, 1540)])
wr.moulded(grip, voxel=0.0006, smooth_factor=0.6, smooth_iter=8, ratio=0.14)
wr.assign_faces(grip, M['grip'], lambda x, y, z: abs(z) * 1000 > 9.0 and (y - BY) * 1000 < -55)
body.append(grip)

# ------------------------------------------------------------------- stock ----
hinge = part('hinge', 18.5, M['alu'], [(2438, 380), (2545, 380), (2545, 800), (2438, 800)])
wr.bevel(hinge, 0.0008, 2, 30)
body.append(hinge)
body.append(wr.cylinder('hinge_button', P(*N(2492, 560), 18.3), P(*N(2492, 560), 20.3), 0.0050, M['poly'], 28))
stock = part('stock', ST + 0.8, M['poly'], [(2540, 380), (3620, 380), (3620, 1320), (2540, 1320)])
# Crowned, rounded-over section before the moulding pass softens it further.
shape(stock, P, OUTLINE, ST, d_range=(nd(2540), nd(3620)), r=4.0, crown=1.3, top=0.86, bot=0.92, step=3.0)
cuts = recess([(2700, 540), (3450, 690), (3450, 760), (2700, 680)], ST, 2.5)
cuts += recess([(3150, 900), (3480, 960), (3480, 1150), (3300, 1080)], ST, 2.5)
wr.boolean(stock, cuts, 'DIFFERENCE')
wr.moulded(stock, voxel=0.0007, smooth_factor=0.55, smooth_iter=7, ratio=0.12)
body.append(stock)
pad = part('butt_plate', 18.0, M['grip'], [(3610, 560), (3790, 560), (3790, 1320), (3610, 1320)])
wr.moulded(pad, voxel=0.0007, smooth_factor=0.5, smooth_iter=5, ratio=0.15)
body.append(pad)

# ---------------------------------------------------------------- magazine ----
MAGP = [(1331, 1022), (1599, 1050), (1577, 1186), (1553, 1304), (1517, 1452), (1491, 1538), (1455, 1654), (1395, 1828), (1368, 1865), (1308, 1845), (1132, 1785), (1115, 1770), (1141, 1700), (1189, 1596), (1237, 1448), (1289, 1250), (1301, 1196), (1317, 1116)]
mag = nside('mag', [(1335, 900), (1595, 900)] + MAGP[1:] + [(1331, 1022)], 11.8, M['smoke'])
wr.bevel(mag, 0.0008, 2, 30)
mag_parts = [mag, nside('mag_floor', [(1110, 1760), (1140, 1755), (1380, 1840), (1372, 1872), (1355, 1876), (1120, 1790)], 13.2, M['smoke_base'])]


def resample(pts, n):
    seg = [math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1)]
    total = sum(seg)
    out = []
    for k in range(n):
        s, i = total * k / (n - 1), 0
        while i < len(seg) - 1 and s > seg[i]:
            s -= seg[i]
            i += 1
        t = min(1.0, s / seg[i]) if seg[i] else 0.0
        a, b = pts[i], pts[i + 1]
        out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


# Staggered double stack of 9x19 FMJ seen through the smoked body: case heads
# against the rear wall, noses forward, 4.97 mm per round along the curve.
FRONT = resample([N(x, y) for x, y in [(1335, 900), (1331, 1022), (1317, 1116), (1301, 1196), (1289, 1250), (1237, 1448), (1189, 1596), (1141, 1700), (1118, 1762)]], 80)
REAR = resample([N(x, y) for x, y in [(1595, 900), (1599, 1050), (1577, 1186), (1553, 1304), (1517, 1452), (1491, 1538), (1455, 1654), (1395, 1828), (1372, 1852)]], 80)
MID = [((f[0] + r[0]) / 2, (f[1] + r[1]) / 2) for f, r in zip(FRONT, REAR)]
ARC = [0.0]
for i in range(1, len(MID)):
    ARC.append(ARC[-1] + math.dist(MID[i - 1], MID[i]))


def at(s):
    i = 1
    while i < len(ARC) - 1 and ARC[i] < s:
        i += 1
    t = (s - ARC[i - 1]) / max(1e-6, ARC[i] - ARC[i - 1])
    lerp = lambda a, b: (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
    return lerp(MID[i - 1], MID[i]), lerp(FRONT[i - 1], FRONT[i]), lerp(REAR[i - 1], REAR[i])


def cartridge(head, u, z):
    """9x19 FMJ: 19.15 mm case, 29.7 mm overall; u = unit vector to the nose."""
    pt = lambda k: (head[0] + u[0] * k, head[1] + u[1] * k)
    out = [wr.cylinder('case', P(*pt(0.0), z), P(*pt(19.15), z), 0.00498, M['brass'], 12, radius_b=0.00483)]
    out.append(wr.cylinder('bullet', P(*pt(19.15), z), P(*pt(22.2), z), 0.00452, M['fmj'], 12))
    out.append(wr.cylinder('ogive', P(*pt(22.2), z), P(*pt(26.2), z), 0.00452, M['fmj'], 12, radius_b=0.0036))
    out.append(wr.cylinder('nose', P(*pt(26.2), z), P(*pt(29.7), z), 0.0036, M['fmj'], 12, radius_b=0.0015))
    return out


s, k = 6.0, 0
while s < ARC[-1] - 16.0:
    c, f, r = at(s)
    L = math.dist(f, r)
    u = ((f[0] - r[0]) / L, (f[1] - r[1]) / L)
    head = (r[0] + u[0] * 2.8, r[1] + u[1] * 2.8)
    mag_parts += cartridge(head, u, 4.3 if k % 2 == 0 else -4.3)
    s += 4.97
    k += 1
c, f, r = at(s + 2.0)
L = math.dist(f, r)
u = ((f[0] - r[0]) / L, (f[1] - r[1]) / L)
nrm = (-u[1], u[0])
mag_parts.append(side('follower', [(c[0] + u[0] * a + nrm[0] * b, c[1] + u[1] * a + nrm[1] * b) for a, b in ((-17, -3), (17, -3), (17, 3), (-17, 3))], 9.0, M['follower']))
print('EVO rounds in magazine', k)
magazine = wr.join('Shigure_Magazine', mag_parts)

iron_sights = wr.join('IronSights', rs_parts)
body_obj = wr.join('Shigure_Body', body)
objs = [body_obj, magazine, iron_sights]
print('EVO verts', {o.name: len(o.data.vertices) for o in objs}, 'total', wr.stats(objs))
wr.export(OUT, objs)
print('EXPORTED', OUT)
