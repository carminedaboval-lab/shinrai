"""KITE / K-12 rebuilt as its real counterpart: FN SCAR 17S (NRCH), 7.62x51.

blender --background --python tools/weapon_real/kite_scar17.py
Side outlines are traced from FN America's studio left-side photograph
(refs/scar17s_left.json: 2400 px, 2.42 px/mm measured from the 10.0 mm
MIL-STD-1913 slot pitch, levelled on the top rail). Small parts are modelled
from FN's 1800 px rotator photos and published specs: 16.25 in barrel of
0.66 in (16.8 mm), 965 mm OAL, flip-up front post in a round hood on the gas
block, flip-up rear aperture with windage drums, two-position gas regulator,
ambidextrous 45-degree selector, round mag release in a raised fence,
side-folding six-position stock with two-position comb, stamped steel
20-round magazine with a wedge floorplate.
Frame: d = mm behind the muzzle, y = mm above the bore, z = mm to the left.
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy
import wr
from trace import Ref, clean, lathe, shape, span_at, section_half

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / 'assets/weapons/kite/kite_geometry.glb'
XM, BY = -0.4915, 0.0756
ref = Ref(REPO / 'tools/weapon_real/refs/scar17s_left.json', muzzle_x=35, bore_y=504.5, level=(745, 388, 1630, 392))


def P(d, y, z=0.0):
    return (XM + d / 1000.0, BY + y / 1000.0, z / 1000.0)


def N(x, y):
    """Native photo pixel to (d, y) mm."""
    return ref.mm(x, y)


def side(name, pts, half, m, z=0.0):
    return wr.extrude_xy(name, [P(d, y)[:2] for d, y in clean(pts)], (z - half) / 1000, (z + half) / 1000, m)


def sec(name, pts_zy, d0, d1, m=None):
    return wr.extrude_zy(name, [(z / 1000, BY + y / 1000) for z, y in pts_zy], P(d0, 0)[0], P(d1, 0)[0], m)


def region(name, native_pts, half=60):
    return side(name, [N(x, y) for x, y in native_pts], half, None)


def clip(o, native_pts):
    wr.boolean(o, region('clip', native_pts), 'INTERSECT')
    return o


def stadium(d0, d1, yc, h, n=6):
    """Slot outline (d, y) with round ends."""
    r = h / 2.0
    pts = []
    for k in range(n + 1):
        a = -math.pi / 2 + math.pi * k / n
        pts.append((d1 - r + r * math.cos(a), yc + r * math.sin(a)))
    for k in range(n + 1):
        a = math.pi / 2 + math.pi * k / n
        pts.append((d0 + r + r * math.cos(a), yc + r * math.sin(a)))
    return pts


def disc(d, y, r, n=20):
    return [(d + r * math.cos(2 * math.pi * k / n), y + r * math.sin(2 * math.pi * k / n)) for k in range(n)]


def stud(name, d, y, r, z0, z1, m, seg=20, bev=0.00025):
    """Round head standing on a side face (z0 = face, z1 = top)."""
    o = wr.cylinder(name, P(d, y, z0), P(d, y, z1), r / 1000.0, m, seg)
    if bev:
        wr.bevel(o, bev, 2, 30)
    return o


def proud(name, loop, face, height, m, sides=(1, -1), bev=0.00035):
    """A flat part standing proud of a side face at |z| = face."""
    out = []
    for s in sides:
        # 1.5 mm sunk into the face so it stays seated on crowned surfaces.
        o = side(name, loop, (height + 1.5) / 2, m, z=s * (face + (height - 1.5) / 2 - 0.1))
        if bev:
            wr.bevel(o, bev, 2, 30)
        out.append(o)
    return out


def recess(loop, face, depth, sides=(1, -1)):
    return [side('recess', loop, depth, None, z=s * face) for s in sides]


def inside(pt, poly):
    x, y = pt
    c = False
    n = len(poly)
    for i in range(n):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % n]
        if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
            c = not c
    return c


def text(name, body_text, center, size, material, side_sign=1):
    """wr.text with a low curve resolution (engraved letters need few points)."""
    bpy.ops.object.text_add()
    o = bpy.context.object
    o.data.body = body_text
    o.data.size = size
    o.data.extrude = 0.00004
    o.data.resolution_u = 2
    o.data.align_x = 'CENTER'
    o.data.align_y = 'CENTER'
    o.rotation_euler = (math.pi / 2, 0, 0) if side_sign > 0 else (math.pi / 2, 0, math.pi)
    o.location = wr.cv(center)
    bpy.ops.object.convert(target='MESH')
    o = bpy.context.object
    o.name = name
    wr.apply(o)
    o.data.materials.clear()
    o.data.materials.append(material)
    return o


RAIL = [(-8.5, 0.0), (8.5, 0.0), (8.5, 3.2), (10.6, 5.3), (10.6, 7.0), (8.6, 9.4), (-8.6, 9.4), (-10.6, 7.0), (-10.6, 5.3), (-8.5, 3.2)]


def side_rail(name, d0, d1, yc, face, s, m):
    """MIL-STD-1913 rail bolted to a side face, slots facing outward."""
    r = sec(name, [(s * (face + h), yc + w) for w, h in RAIL], d0, d1, m)
    cuts = []
    d = d0 + 4.0
    while d + 5.23 < d1 - 2.0:
        cuts.append(sec('slot', [(s * (face + 6.0), yc - 14), (s * (face + 14), yc - 14), (s * (face + 14), yc + 14), (s * (face + 6.0), yc + 14)], d, d + 5.23))
        d += 10.0
    wr.boolean(r, cuts, 'DIFFERENCE')
    wr.bevel(r, 0.0003, 2, 30)
    return r


def bottom_rail(name, d0, d1, top, m):
    r = sec(name, [(w, top - h) for w, h in RAIL], d0, d1, m)
    cuts = []
    d = d0 + 4.0
    while d + 5.23 < d1 - 2.0:
        cuts.append(sec('slot', [(-14, top - 6.0), (14, top - 6.0), (14, top - 14), (-14, top - 14)], d, d + 5.23))
        d += 10.0
    wr.boolean(r, cuts, 'DIFFERENCE')
    wr.bevel(r, 0.0003, 2, 30)
    return r


wr.reset()
M = dict(
    upper=wr.mat('SCAR FDE anodised', (0.55, 0.45, 0.27), 0.3, 0.5),
    lower=wr.mat('SCAR FDE polymer', (0.27, 0.19, 0.12), 0.0, 0.6),
    grip=wr.mat('SCAR grip texture', (0.26, 0.19, 0.12), 0.0, 0.72),
    stock=wr.mat('SCAR stock polymer', (0.38, 0.28, 0.17), 0.0, 0.6),
    black=wr.mat('SCAR black steel', (0.04, 0.04, 0.042), 0.7, 0.45),
    phos=wr.mat('SCAR phosphate steel', (0.16, 0.16, 0.15), 0.6, 0.55),
    rubber=wr.mat('SCAR rubber', (0.03, 0.03, 0.03), 0.0, 0.85),
    mag=wr.mat('SCAR magazine', (0.28, 0.2, 0.08), 0.3, 0.5),
    brass=wr.mat('SCAR brass', (0.72, 0.52, 0.24), 1.0, 0.3),
    bore=wr.mat('SCAR bore', (0.01, 0.01, 0.01), 0.8, 0.5),
    mark=wr.mat('SCAR marking', (0.42, 0.33, 0.2), 0.3, 0.55),
)
TAN = ref.loop('tan', area=63895)
STOCK = ref.loop('tan', area=27995)
GRIP = ref.loop('tan', area=6485)
BLK = ref.loop('blk', area=18307)
U_HALF, L_HALF, S_HALF = 21.0, 20.0, 19.5
SL = 83.0          # iron sight line above the bore (mm): rear aperture and front post tip
UPPER_TOP = 42.0   # top of the receiver under the rail
body = []

# ---------------------------------------------------------------- upper ----
# Monolithic aluminium upper: traced side outline; at the rear it comes down
# to 13 mm below the bore (the anodised band carrying the pins and the logo).
upper = side('upper', TAN, U_HALF, M['upper'])
clip(upper, [(700, 403), (1760, 403), (1760, 536), (976, 536), (976, 483), (700, 483)])
wr.boolean(upper, sec('upper_section', [(-U_HALF, -40), (U_HALF, -40), (U_HALF, UPPER_TOP - 4.5), (U_HALF - 4.5, UPPER_TOP),
                                        (-U_HALF + 4.5, UPPER_TOP), (-U_HALF, UPPER_TOP - 4.5)], -10, 800), 'INTERSECT')
cuts = []
VENTS = [(315.0, 343.8), (350.4, 379.3), (386.0, 414.0)]
for d0, d1 in VENTS:          # three lightening slots under the rail, both sides
    cuts += recess(stadium(d0, d1, 27.9, 6.6), U_HALF, 3.6)
CH0, CH1, CHY = 417.0, 571.0, 30.4   # charging-handle channel, both sides (handle swappable)
cuts += recess(stadium(CH0, CH1, CHY, 5.8), U_HALF, 3.6)
# Right side: long, low ejection port (no dust cover) measured from FN's
# right-side photo, with the brass deflector / comb hook at its rear end.
PORT = [(483.0, -6.5), (578.0, -6.5), (578.0, 7.5), (487.0, 7.5), (483.0, 3.5)]
cuts.append(side('eject_port', PORT, 6.0, None, z=-U_HALF))
wr.boolean(upper, cuts, 'DIFFERENCE')
wr.bevel(upper, 0.0005, 2, 30)
body.append(upper)
# Dark interiors behind the slots (they open into the receiver).
for s in (1, -1):
    for d0, d1 in VENTS:
        body.append(side('vent_back', stadium(d0 - 1, d1 + 1, 27.9, 8.0), 0.2, M['bore'], z=s * (U_HALF - 3.3)))
    body.append(side('ch_back', stadium(CH0 - 1, CH1 + 1, CHY, 7.6), 0.2, M['bore'], z=s * (U_HALF - 3.3)))
defl = side('deflector', [(575.0, -8.5), (592.0, -8.5), (611.0, -3.0), (613.0, 2.0), (608.0, 8.0), (598.0, 10.0), (575.0, 10.0)], 1.6, M['black'], z=-U_HALF - 1.4)
wr.bevel(defl, 0.0006, 2, 30)
body.append(defl)
# Bolt carrier seen through the port (black nitrided, recessed).
body.append(side('bolt_in_port', [(480, -9), (581, -9), (581, 10), (480, 10)], 1.0, M['black'], z=-U_HALF + 5.0))
# Right sling plate (same as the left) and the blank charging-handle stud.
spr = side('sling_plate_r', stadium(427.3, 481.8, 0.3, 16.0, 8), 1.3, M['black'], z=-U_HALF - 1.1)
wr.boolean(spr, wr.cylinder('qd_r', P(454.5, 0.3, -U_HALF), P(454.5, 0.3, -U_HALF - 5), 0.0042, None, 20), 'DIFFERENCE')
wr.bevel(spr, 0.0005, 2, 30)
body.append(spr)
body.append(wr.cylinder('qd_back_r', P(454.5, 0.3, -U_HALF - 0.5), P(454.5, 0.3, -U_HALF - 0.8), 0.0042, M['bore'], 20))
for d in (438.0, 471.0):
    body.append(stud('sp_screw_r', d, 0.3, 2.6, -(U_HALF + 2.3), -(U_HALF + 3.0), M['black'], 14, 0))
body.append(stud('ch_stud_r', 430.0, CHY, 4.0, -(U_HALF - 2.0), -(U_HALF + 3.2), M['black'], 18))
# Receiver body behind the side rails (front section, hidden mostly by rails).
body.append(side('upper_front_low', [(286, -13.0), (466, -13.0), (466, 10.0), (286, 10.0)], U_HALF - 0.3, M['upper']))
# Black front cap at the receiver's front face.
cap = sec('front_cap', [(-U_HALF - 0.4, -13.5), (U_HALF + 0.4, -13.5), (U_HALF + 0.4, UPPER_TOP - 4.3), (U_HALF - 4.3, UPPER_TOP + 0.4),
                        (-U_HALF + 4.3, UPPER_TOP + 0.4), (-U_HALF - 0.4, UPPER_TOP - 4.3)], 283.2, 286.4, M['black'])
wr.bevel(cap, 0.0004, 2, 30)
body.append(cap)

# Top rail: the traced silhouette carries every slot; MIL-STD-1913 dovetail section.
rail = side('top_rail', TAN, 11.0, M['upper'])
clip(rail, [(715, 370), (1652, 370), (1652, 404), (715, 404)])
t = N(1000, 387)[1]
wr.boolean(rail, sec('rail_dovetail', [(-9.5, t - 9.5), (9.5, t - 9.5), (9.5, t - 5.6), (10.6, t - 4.5), (10.6, t - 2.4), (9.2, t + 2), (-9.2, t + 2), (-10.6, t - 2.4), (-10.6, t - 4.5), (-9.5, t - 5.6)], -10, 800), 'INTERSECT')
body.append(rail)

# Side rails (removable, black) at 3 and 9 o'clock and the bottom rail.
for s in (1, -1):
    body.append(side_rail('side_rail', 287.0, 389.0, -1.5, U_HALF - 0.3, s, M['black']))
    for d in (306.5, 346.5):   # retaining screws seen in the slot bottoms
        body.append(stud('rail_screw', d, -1.5, 2.6, s * (U_HALF + 5.5), s * (U_HALF + 6.4), M['black'], 14, 0))
body.append(side('bottom_rail_base', [(287, -13.0), (462, -13.0), (462, -20.0), (287, -20.0)], 11.5, M['black']))
body.append(bottom_rail('bottom_rail', 287.0, 462.0, -19.9, M['black']))

# Markings (left side), where FN puts them, with the in-game maker and model.
body.append(text('mk1', 'SHINRAI  ARMS   KYOTO  JP', P(620.0, 33.6, U_HALF + 0.03), 0.0034, M['mark'], 1))
body.append(text('mk2', 'K-12  MULTI-CALIBER', P(613.0, 29.2, U_HALF + 0.03), 0.0034, M['mark'], 1))
body.append(text('mk3', 'K1C26101', P(686.0, 29.2, U_HALF + 0.03), 0.0030, M['mark'], 1))
# Maker's oval logo and the laser data-matrix square.
ring = [(637 + 8.5 * math.cos(a), -2.5 + 5.6 * math.sin(a)) for a in [2 * math.pi * k / 28 for k in range(28)]]
inner = [(637 + 7.4 * math.cos(a), -2.5 + 4.6 * math.sin(a)) for a in [2 * math.pi * k / 28 for k in range(28)]]
logo = side('logo_oval', ring, 0.05, M['mark'], z=U_HALF + 0.02)
wr.boolean(logo, side('logo_in', inner, 1.0, None, z=U_HALF), 'DIFFERENCE')
body.append(logo)
body.append(text('mk_logo', 'SA', P(637.0, -2.5, U_HALF + 0.03), 0.0055, M['mark'], 1))
cells = []
seed = 7
for i in range(10):
    for j in range(10):
        seed = (seed * 1103515245 + 12345) & 0x7fffffff
        if i in (0,) or j in (9,) or (seed >> 16) % 2:
            d0, y0 = 608.0 + i * 0.8, -4.6 + j * 0.8
            cells.append(side('dm', [(d0, y0), (d0 + 0.8, y0), (d0 + 0.8, y0 + 0.8), (d0, y0 + 0.8)], 0.04, M['mark'], z=U_HALF + 0.02))
body.append(wr.join('data_matrix', cells))

# Pins and screws on the receiver (round heads, black).
for d, y, r in ((297.5, 31.3, 3.6), (526.5, 3.3, 3.4), (600.4, 3.3, 3.4), (677.7, 3.1, 3.6), (690.9, 0.4, 3.4), (701.6, 0.4, 3.4)):
    for s in ((1,) if 480 < d < 615 else (1, -1)):   # the right side has the port there
        body.append(stud('pin', d, y, r, s * (U_HALF - 0.2), s * (U_HALF + 0.6), M['black'], 14))

# Charging handle (left): stem out of the channel and an angled hollow knob.
stem = side('ch_stem', [(424, 27.0), (436, 27.0), (436, 33.5), (424, 33.5)], 4.0, M['black'], z=U_HALF + 1.0)
wr.bevel(stem, 0.0004, 2, 30)
body.append(stem)
knob = wr.tube('ch_knob', P(430, 29.5, U_HALF + 1.5), P(427, 22.0, U_HALF + 19.0), 0.0058, 0.0034, M['black'], 24)
body.append(knob)
body.append(wr.cylinder('ch_knob_floor', P(429.6, 28.5, U_HALF + 3.5), P(428.0, 25.0, U_HALF + 11.0), 0.0036, M['black'], 20))
# Front sling plate under it: oval plate, two screws, QD socket.
sp = side('sling_plate', stadium(427.3, 481.8, 0.3, 16.0, 8), 1.3, M['black'], z=U_HALF + 1.1)
wr.boolean(sp, wr.cylinder('qd', P(454.5, 0.3, U_HALF), P(454.5, 0.3, U_HALF + 5), 0.0042, None, 20), 'DIFFERENCE')
wr.bevel(sp, 0.0005, 2, 30)
body.append(sp)
body.append(wr.cylinder('qd_back', P(454.5, 0.3, U_HALF + 0.5), P(454.5, 0.3, U_HALF + 0.8), 0.0042, M['bore'], 20))
for d in (438.0, 471.0):
    body.append(stud('sp_screw', d, 0.3, 2.6, U_HALF + 2.3, U_HALF + 3.0, M['black'], 14, 0))

# ---------------------------------------------------------------- lower ----
lower = side('lower', TAN, L_HALF + 0.8, M['lower'])
clip(lower, [(1150, 533), (1410, 533), (1410, 487), (1760, 487), (1760, 730), (1413, 730), (1413, 700), (1213, 700), (1213, 730), (1150, 730)])
# Moulded polymer lower: full width where it mates with the upper, the sides
# draw in and round over toward the trigger guard and grip frame (the top
# of the section is put far above so the mating face stays square).
LOWER_SEC = dict(r=4.5, crown=0.8, top=1.0, bot=0.86)


def lower_span(d):
    sp = span_at(TAN, d, (-100.0, 8.0))
    return (sp[0] if sp else -95.0), 60.0


shape(lower, P, None, L_HALF, d_range=(455.0, 720.0), span_fn=lower_span, step=3.0, **LOWER_SEC)


def lower_face(d, y):
    lo, hi = lower_span(d)
    return section_half(lo, hi, L_HALF, y, **LOWER_SEC)
wr.boolean(lower, side('guard_opening', ref.loop('holes', 'guard_opening'), 40, None), 'DIFFERENCE')
wr.boolean(lower, side('magwell_bore', [N(1222, 600), N(1405, 600), N(1405, 760), N(1222, 760)], 13.6, None), 'DIFFERENCE')
wr.bevel(lower, 0.0008, 2, 30)
body.append(lower)
# Flared magwell lip.
flare = side('magwell_flare', [(482, -71.0), (569, -71.0), (569, -89.0), (488, -89.0), (482, -73.0)], lower_face(525.0, -80.0) + 1.6, M['lower'])
wr.boolean(flare, side('flare_bore', [(486, -60), (566, -60), (566, -95), (486, -95)], 13.8, None), 'DIFFERENCE')
wr.bevel(flare, 0.0008, 2, 30)
body.append(flare)
LF_MR = lower_face(577.0, -41.0)   # side face at the mag release
LF_SEL = lower_face(633.0, -34.0)  # side face at the selector
# Raised polymer fence around the bolt catch and mag release (left) ...
for loop in ([(531, -22.5), (566, -22.5), (566, -27.5), (536, -27.5), (531, -25.5)],
             [(579, -22.5), (588, -22.5), (588, -27.5), (579, -27.5)],
             [(555, -50.5), (588, -50.5), (588, -55.0), (555, -55.0)]):
    body += proud('fence', loop, lower_face(loop[0][0], loop[0][1]), 2.4, M['lower'], sides=(1,), bev=0.0005)
# ... and the square raised frame round the right-hand mag release button.
frame = side('mr_frame_r', wr.rounded_rect(577.0, -39.5, 36.0, 29.0, 4.0, 3), 1.2, M['lower'], z=-(LF_MR + 1.1))
wr.boolean(frame, side('mr_frame_in', wr.rounded_rect(577.0, -39.5, 22.0, 19.0, 3.0, 3), 4.0, None, z=-(LF_MR + 1.1)), 'DIFFERENCE')
wr.bevel(frame, 0.0005, 2, 30)
body.append(frame)
body.append(stud('mr_button_r', 577.0, -39.5, 6.4, -(LF_MR - 0.8), -(LF_MR + 2.6), M['black'], 24, 0.0005))
# Bolt catch (left): paddle with a ribbed thumb pad.
bc = side('bolt_catch', [(568, -27.0), (578, -27.0), (578.5, -3.0), (576, 1.5), (571, 1.5), (568.5, -3.0)], 1.4, M['black'], z=lower_face(573, -12) + 2.6)
wr.boolean(bc, [side('bc_rib', [(566, y), (580, y), (580, y + 0.9), (566, y + 0.9)], 0.6, None, z=lower_face(573, -12) + 3.9) for y in (-6.0, -3.6, -1.2)], 'DIFFERENCE')
wr.bevel(bc, 0.0003, 2, 30)
body.append(bc)
# Magazine release, left: lever, checkered pad and round pivot.
for s in (1,):
    lev = side('mag_release', [(534, -41.0), (584, -41.0), (584, -46.5), (538, -46.5), (534, -44.5)], 1.2, M['black'], z=s * (LF_MR + 1.2))
    wr.bevel(lev, 0.0003, 2, 30)
    body.append(lev)
    pad = side('mr_pad', wr.rounded_rect(569.0, -43.5, 19.0, 13.0, 2.5, 3), 1.4, M['black'], z=s * (LF_MR + 2.0))
    wr.bevel(pad, 0.0004, 2, 30)
    body.append(pad)
    body.append(stud('mr_pivot', 585.0, -43.5, 4.6, s * (LF_MR - 0.5), s * (LF_MR + 3.4), M['black'], 20))
# Selector (ambidextrous, 45-degree throw), on SAFE: hub and tapered lever pointing rearward.
for s in (1, -1):
    body.append(stud('sel_hub', 633.0, -34.0, 5.8, s * (LF_SEL - 0.8), s * (LF_SEL + 3.6), M['black'], 24))
    lv = side('sel_lever', [(633, -31.2), (654, -32.8), (655.5, -34.0), (654, -35.2), (633, -36.8)], 1.1, M['black'], z=s * (LF_SEL + 2.6))
    wr.bevel(lv, 0.0003, 2, 30)
    body.append(lv)
body.append(text('mk_safe', 'S', P(618.5, -35.5, lower_face(618.5, -35.5) + 0.03), 0.0042, M['mark'], 1))
body.append(text('mk_fire', '1', P(623.0, -24.5, lower_face(623.0, -24.5) + 0.03), 0.0042, M['mark'], 1))
# Takedown and fire-control pins.
for d, y, r in ((473.5, -22.5, 3.3), (615.7, -47.5, 3.6), (649.5, -21.0, 4.6)):
    for s in (1, -1):
        body.append(stud('lpin', d, y, r, s * (lower_face(d, y) - 0.8), s * (lower_face(d, y) + 0.7), M['black'], 14))
tr = side('trigger', ref.loop('blk', 'trigger'), 3.0, M['black'])
wr.bevel(tr, 0.0005, 2, 30)
body.append(tr)
grip = side('grip', GRIP, 15.0, M['lower'])
wr.moulded(grip, voxel=0.0006, smooth_factor=0.6, smooth_iter=8, ratio=0.1)
PANEL = [(645, -74), (666, -74), (709, -134), (685, -143)]   # checkered side panel
wr.assign_faces(grip, M['grip'], lambda x, y, z: abs(z) * 1000 > 8.0 and inside(((x - XM) * 1000, (y - BY) * 1000), PANEL))
body.append(grip)

# ------------------------------------------------- front: gas block, sight, barrel ----
# Gas block (phosphated steel): clamp around the barrel, gas cylinder above it.
GY = 23.0
clamp = wr.cylinder('gb_clamp', P(239.5, 0), P(283.5, 0), 0.0128, M['phos'], 36)
wr.bevel(clamp, 0.0005, 2, 40)
body.append(clamp)
web = side('gb_web', [(241, 5), (283.5, 5), (283.5, GY), (241, GY)], 7.5, M['phos'])
wr.bevel(web, 0.0004, 2, 30)
body.append(web)
gcyl = wr.cylinder('gas_cylinder', P(242.0, GY), P(284.0, GY), 0.0082, M['phos'], 32)
wr.bevel(gcyl, 0.0005, 2, 40)
body.append(gcyl)
for s in (1, -1):
    body.append(stud('gb_screw', 262.0, 7.0, 2.4, s * 12.3, s * 13.6, M['black'], 14, 0))
# Two-position gas regulator at the front of the gas cylinder, lever at 12 o'clock.
body.append(wr.cylinder('regulator', P(233.5, GY), P(242.5, GY), 0.0072, M['black'], 28))
reg_lever = side('reg_lever', [(234.0, GY), (239.0, GY), (239.0, GY + 12.5), (236.5, GY + 13.5), (234.0, GY + 12.5)], 3.0, M['black'])
wr.bevel(reg_lever, 0.0004, 2, 30)
body.append(reg_lever)
body.append(wr.cylinder('reg_slot', P(233.3, GY), P(233.8, GY), 0.0032, M['bore'], 16))
# Folding front sight: base on the gas block, leaf, round hood, post.
fsb = side('fs_base', [(255, 30.5), (283.5, 30.5), (283.5, 41.0), (258, 41.0), (255, 38.0)], 8.0, M['phos'])
wr.bevel(fsb, 0.0005, 2, 30)
body.append(fsb)
for s in (1, -1):
    body.append(stud('fs_pivot', 268.0, 35.0, 3.0, s * 7.8, s * 9.2, M['black'], 16, 0))
leaf = side('fs_leaf', [(263.0, 39.0), (276.0, 39.0), (275.5, 60.0), (277.5, SL - 9.0), (261.0, SL - 9.0), (263.5, 60.0)], 4.6, M['black'])
wr.bevel(leaf, 0.0004, 2, 30)
body.append(leaf)
for s in (1, -1):   # elevation detent drum
    body.append(stud('fs_drum', 269.5, 49.0, 3.2, s * 4.4, s * 6.4, M['black'], 16))
hood = wr.tube('fs_hood', P(262.5, SL + 0.6), P(276.0, SL + 0.6), 0.0102, 0.0074, M['black'], 32)
body.append(hood)
body.append(side('front_post', [(268.0, SL - 8.5), (271.0, SL - 8.5), (270.4, SL), (268.6, SL)], 0.95, M['black']))
# Barrel and muzzle: traced compensator (H-port, slot, open prongs), hex jam nut.
comp = lathe('compensator', P, BLK, 0.0, 60.0, 0.8, M['black'])
ports = [side('brake_port', h, 20, None) for h in ref.loops('holes', 'brake_port')]
for a in (0, 90, 180, 270):   # four open prongs at the front
    ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
    w = 1.6
    pts = [(-ca * 0 - sa * w, ca * w), (-sa * w + ca * 20, ca * w + sa * 20), (sa * w + ca * 20, -ca * w + sa * 20), (sa * w, -ca * w)]
    ports.append(wr.extrude_zy('prong_slot', [(p[0] / 1000, BY + p[1] / 1000) for p in pts], P(-2, 0)[0], P(9.0, 0)[0]))
ports.append(wr.cylinder('bore_cut', P(-5.0, 0), P(40.0, 0), 0.0052, None, 32))
wr.boolean(comp, ports, 'DIFFERENCE')
body.append(comp)
nut = wr.cylinder('jam_nut', P(61.0, 0), P(82.0, 0), 0.0124, M['black'], 6)
wr.bevel(nut, 0.0004, 2, 30)
body.append(nut)
body.append(wr.cylinder('barrel', P(81.0, 0), P(300.0, 0), 0.0084, M['black'], 40))
body.append(wr.cylinder('bore_shadow', P(30.0, 0), P(36.0, 0), 0.0053, M['bore'], 24))

# ----------------------------------------------------- rear sight, hinge, stock ----
# Folding rear sight: rail clamp, windage drums each side, range wheel, aperture leaf.
RT = 48.6   # rail top
rs_parts = []
base = sec('rs_base', [(-12.0, RT - 5.0), (12.0, RT - 5.0), (12.0, RT + 5.0), (-12.0, RT + 5.0)], 661.5, 704.5, M['black'])
wr.boolean(base, sec('rs_rail_gap', [(-10.8, RT - 9), (10.8, RT - 9), (10.8, RT + 0.2), (-10.8, RT + 0.2)], 650, 720), 'DIFFERENCE')
wr.bevel(base, 0.0005, 2, 30)
rs_parts.append(base)
rs_parts.append(wr.cylinder('rs_bolt', P(668.5, RT + 0.5, 12.0), P(668.5, RT + 0.5, 14.5), 0.0036, M['black'], 6))
body_rs = side('rs_body', [(680.0, RT + 5.0), (702.0, RT + 5.0), (702.0, RT + 14.0), (684.0, RT + 16.0), (680.0, RT + 12.0)], 6.5, M['black'])
wr.bevel(body_rs, 0.0005, 2, 30)
rs_parts.append(body_rs)
for s in (1, -1):
    dr = wr.cylinder('windage_drum', P(691.5, RT + 7.5, s * 6.0), P(691.5, RT + 7.5, s * 11.5), 0.0098, M['black'], 18)
    wr.bevel(dr, 0.0005, 2, 25)
    rs_parts.append(dr)
rs_parts.append(wr.cylinder('range_wheel', P(691.0, RT + 14.0), P(691.0, RT + 22.5), 0.0062, M['black'], 14))
apb = side('aperture_block', [(686.0, SL - 6.0), (697.0, SL - 6.0), (697.0, SL + 4.5), (693.5, SL + 7.0), (689.5, SL + 7.0), (686.0, SL + 4.5)], 3.4, M['black'])
rs_parts.append(side('rs_leaf', [(688.5, RT + 21.0), (694.0, RT + 21.0), (694.0, SL - 5.0), (688.5, SL - 5.0)], 2.6, M['black']))
wr.boolean(apb, wr.cylinder('aperture', P(680, SL), P(705, SL), 0.0016, None, 20), 'DIFFERENCE')
wr.bevel(apb, 0.0003, 2, 30)
rs_parts.append(apb)
iron_sights = wr.join('IronSights', rs_parts)

HINGE = ref.loop('blk', 'hinge')
hinge = side('hinge', HINGE, 23.0, M['black'])
wr.bevel(hinge, 0.0006, 2, 30)
body.append(hinge)
# Half-moon fold button (textured polymer) on the hinge block.
body += proud('fold_button', ref.loop('blk', 'hinge_button'), S_HALF, 2.8, M['grip'], sides=(1,), bev=0.0008)
def rdp(pts, eps):
    """Douglas-Peucker: drop the photo's pixel jitter, keep real corners and teeth."""
    if len(pts) < 3:
        return pts
    (x0, y0), (x1, y1) = pts[0], pts[-1]
    L = math.hypot(x1 - x0, y1 - y0) or 1e-9
    k, dm = 0, -1.0
    for i in range(1, len(pts) - 1):
        x, y = pts[i]
        dd = abs((x1 - x0) * (y0 - y) - (x0 - x) * (y1 - y0)) / L
        if dd > dm:
            k, dm = i, dd
    if dm <= eps:
        return [pts[0], pts[-1]]
    return rdp(pts[:k + 1], eps)[:-1] + rdp(pts[k:], eps)


# Moulded polymer stock: outline cleaned of pixel jitter, extruded and given
# real rounded moulding edges (no voxel remesh: its decimation left streaks).
far = max(range(len(STOCK)), key=lambda i: STOCK[i][0])
ring_pts = STOCK[far:] + STOCK[:far + 1]
near = min(range(len(ring_pts)), key=lambda i: ring_pts[i][0])
STOCK_S = rdp(ring_pts[:near + 1], 0.9)[:-1] + rdp(ring_pts[near:], 0.9)[:-1]
print('SCAR stock outline', len(STOCK), '->', len(STOCK_S))
stock = side('stock', STOCK_S, S_HALF + 0.8, M['stock'])
# Real cross-section: the moulding narrows to the cheek comb on top, the sides
# crown slightly and every long edge is a generous moulded radius.
STOCK_SEC = dict(r=6.5, crown=1.4, top=0.82, bot=1.0)
shape(stock, P, STOCK_S, S_HALF, step=3.0, **STOCK_SEC)


def stock_face(d, y):
    sp = span_at(STOCK_S, d)
    return section_half(sp[0], sp[1], S_HALF, y, **STOCK_SEC) if sp else S_HALF


st_cuts = [side('stock_slot', ref.loop('holes', 'stock_slot'), 40, None)]
for s in (1, -1):
    # telescoping inner beam, visible between the fixed comb section and the butt
    st_cuts.append(side('beam_step', [(839, -46), (861, 30), (887, 30), (878, -46)], 6.0, None, z=s * (S_HALF + 1.5)))
    # parting line between the two-position comb and the stock body
    st_cuts.append(side('comb_seam', [(740, 4.0), (860, 4.0), (860, 5.6), (740, 5.6)], 1.2, None, z=s * S_HALF))
# vertical sling loops on the left of the hinge block
LOOP_F = stock_face(729.0, 14.0)
for y0 in (7.0, 17.0):
    st_cuts.append(side('sling_loop', [(727.5, y0), (731.0, y0), (731.0, y0 + 5.5), (727.5, y0 + 5.5)], 2.6, None, z=LOOP_F))
st_cuts.append(side('sling_loop_r', [(727.5, 10.0), (731.0, 10.0), (731.0, 17.0), (727.5, 17.0)], 2.6, None, z=-LOOP_F))
wr.boolean(stock, st_cuts, 'DIFFERENCE')
wr.bevel(stock, 0.0011, 3, 30)
body.append(stock)
for y0 in (7.0, 17.0):
    body.append(side('sling_loop_back', [(727.0, y0 - 0.5), (731.5, y0 - 0.5), (731.5, y0 + 6.0), (727.0, y0 + 6.0)], 0.2, M['bore'], z=LOOP_F - 2.2))
body.append(side('sling_loop_back_r', [(727.0, 9.5), (731.5, 9.5), (731.5, 17.5), (727.0, 17.5)], 0.2, M['bore'], z=-LOOP_F + 2.2))
body.append(text('mk_lop', '3  4  5  6', P(866.0, -8.0, S_HALF - 4.5 + 0.05), 0.0036, M['mark'], 1))
# Comb release button (square, black) and length-of-pull latch, seated on the
# crowned moulding rather than on a flat wall.
body += proud('comb_button', wr.rounded_rect(750.0, 29.0, 11.0, 10.5, 2.2, 3), stock_face(750.0, 29.0), 2.2, M['black'], bev=0.0005)
body += proud('stock_latch', wr.rounded_rect(920.0, -25.5, 25.0, 19.0, 2.5, 3), stock_face(920.0, -25.5) + 0.6, 2.6, M['black'], sides=(1,), bev=0.0006)
body += proud('latch_boss', wr.rounded_rect(919.0, -25.5, 30.0, 25.0, 3.5, 3), stock_face(919.0, -25.5), 1.2, M['stock'], sides=(1,), bev=0.0006)
pad = side('butt_pad', ref.loop('blk', area=3645), 20.5, M['rubber'])
wr.moulded(pad, voxel=0.0007, smooth_factor=0.5, smooth_iter=3, ratio=0.11)
body.append(pad)
for s in (1, -1):
    pf = stock_face(930.0, -45.0)
    body.append(stud('pad_pin', 930.0, -45.0, 2.4, s * (pf - 0.8), s * (pf + 0.6), M['black'], 12, 0))

# ---------------------------------------------------------------- magazine ----
# Stamped steel body with two pressed stiffening ribs, wedge floorplate.
LINE_F, LINE_R = (488.0, -147.0), (569.0, -161.0)


def below_line(d):
    return LINE_F[1] + (d - LINE_F[0]) * (LINE_R[1] - LINE_F[1]) / (LINE_R[0] - LINE_F[0])


mag = side('mag', TAN, 13.2, M['mag'])
clip(mag, [(1205, 690), (1420, 690), (1420, 930), (1205, 930)])
wr.boolean(mag, side('mag_top', [(470, -60), (590, -60), (590, below_line(590)), (470, below_line(470))], 30, None), 'INTERSECT')
ribs = []
for d in (505.5, 557.5):
    for s in (1, -1):
        rib = side('mag_rib', [(d + q[1], q[0]) for q in stadium(-145.0, -80.0, 0.0, 3.0, 4)], 0.5, M['mag'], z=s * 13.25)
        ribs.append(rib)
mag = wr.join('mag', [mag] + ribs)
wr.bevel(mag, 0.0006, 2, 30)
floor = side('mag_floor', TAN, 14.0, M['mag'])
clip(floor, [(1205, 690), (1420, 690), (1420, 930), (1205, 930)])
wr.boolean(floor, side('floor_top', [(470, below_line(470) - 1.2), (590, below_line(590) - 1.2), (590, -200), (470, -200)], 30, None), 'INTERSECT')
wr.boolean(floor, [side('floor_window', stadium(d0, d0 + 9.0, below_line(d0 + 4.5) - 6.5, 4.6, 4), 3.0, None, z=s * 14.0)
                   for d0 in (494.0, 508.0) for s in (1, -1)], 'DIFFERENCE')
wr.bevel(floor, 0.0007, 2, 30)
gap = side('mag_gap', [(489, -146.0), (568, -160.0), (568, -161.5), (489, -147.5)], 12.8, M['bore'])
mag_parts = [mag, floor, gap]
mag_parts.append(wr.cylinder('top_round', P(*N(1400, 600)), P(*N(1235, 600)), 0.0059, M['brass'], 20))
magazine = wr.join('Kite_Magazine', mag_parts)

heavy = {}
for o in body:
    heavy[o.name.split('.')[0]] = heavy.get(o.name.split('.')[0], 0) + len(o.data.vertices)
print('SCAR heavy parts', sorted(heavy.items(), key=lambda kv: -kv[1])[:14])
body_obj = wr.join('Kite_Body', body)
objs = [body_obj, magazine, iron_sights]
print('SCAR verts', {o.name: len(o.data.vertices) for o in objs}, 'total', wr.stats(objs))
wr.export(OUT, objs)
print('EXPORTED', OUT)
