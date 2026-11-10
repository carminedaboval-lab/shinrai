"""YUZURU / YZ-10 rebuilt as its real counterpart: Accuracy International
Arctic Warfare (AW), 7.62x51, 10-round steel magazine, black thumbhole stock
halves on the aluminium chassis, muzzle brake, butt monopod and AW-pattern
detachable iron sights.

blender --background --python tools/weapon_real/yuzuru_aiaw.py

Side profile traced from the IMFDB studio photo "Accuracy International Arctic
Warfare - Psg 90.jpg" (1500 x 337 px, right side, read in the browser, not
downloaded). Scale 0.84 mm/px from the butt-pad heel to the brake face
(1232 mm), cross-checked against the 10-round magazine (88 mm) and the butt
pad (136 mm). Published: overall 1180 mm without brake, barrel 660 mm,
6.5 kg, bolt 19.05 mm with six lugs in two rows of three, 60 degree throw,
three-position safety on the bolt shroud, flat-bottomed receiver.

Frame: d = mm behind the barrel datum (brake face = -52), y = mm above the
bore, z = mm to the left. Photo pixel (x, Y) -> d = (1422 - x) * 0.84,
y = (149.5 - Y) * 0.84. Action origin on the bore axis (bolt-lift pivot).
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy, bmesh, mathutils
import wr

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / 'assets/weapons/yuzuru/yuzuru_geometry.glb'
XM, BY = -0.760, 0.065
KEY = 'AW'
S_PX = 0.84


def P(d, y, z=0.0):
    return (XM + d / 1000.0, BY + y / 1000.0, z / 1000.0)


def IMG(x, Y):
    """Photo pixel -> (d, y) in mm."""
    return ((1422.0 - x) * S_PX, (149.5 - Y) * S_PX)


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


def cyl_y(name, d, y0, y1, r, m, z=0.0, seg=32):
    return wr.cylinder(name, P(d, y0, z), P(d, y1, z), r / 1000, m, seg)


def sphere(name, d, y, z, r, m, seg=24, rings=14):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r / 1000)
    o = wr._obj(name, bm, m)
    o.location = wr.cv(P(d, y, z))
    wr.apply(o)
    wr.smooth(o, 80)
    return o


def torus_side(name, d, y, z, R, r, m, seg=24, rs=8):
    """Ring lying in the side (d, y) plane."""
    bm = bmesh.new()
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ring = []
        for j in range(rs):
            b = 2 * math.pi * j / rs
            rr = R + r * math.cos(b)
            ring.append(bm.verts.new(wr.cv(P(d + rr * math.cos(a), y + rr * math.sin(a), z + r * math.sin(b)))))
        rings.append(ring)
    for i in range(seg):
        for j in range(rs):
            a, b = rings[i], rings[(i + 1) % seg]
            bm.faces.new((a[j], a[(j + 1) % rs], b[(j + 1) % rs], b[j]))
    o = wr._obj(name, bm, m)
    wr._fix_normals(o)
    wr.smooth(o, 80)
    return o


def stadium(d0, d1, yc, h, seg=8):
    """Slot outline in the side plane: straight run d0..d1, round ends of radius h."""
    pts = []
    for k in range(seg + 1):
        a = -math.pi / 2 + math.pi * k / seg
        pts.append((d0 - h * math.cos(a), yc + h * math.sin(a)))
    for k in range(seg + 1):
        a = math.pi / 2 + math.pi * k / seg
        pts.append((d1 - h * math.cos(a), yc + h * math.sin(a)))
    return pts


def ellipse(dc, yc, rx, ry, n=24):
    return [(dc + rx * math.cos(2 * math.pi * k / n), yc + ry * math.sin(2 * math.pi * k / n)) for k in range(n)]


def rsec(hw, yb, yt, rb, rt, n=4):
    """Rounded cross-section (z, y): bottom corner radius rb, top radius rt."""
    pts = []
    for cz, cy, r, a0 in ((hw - rb, yb + rb, rb, -90), (hw - rt, yt - rt, rt, 0), (-hw + rt, yt - rt, rt, 90), (-hw + rb, yb + rb, rb, 180)):
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n)
            pts.append((cz + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def sec_loft(name, rings, m=None):
    """rings: [(d, [(z, y), ...]), ...] with equal point counts."""
    return wr.loft(name, [[P(d, y, z) for z, y in pts] for d, pts in rings], m)


def round_poly(pts, r, seg=4):
    """Round every corner of a closed 2D polygon (quadratic Bezier, cut <= 45% of each edge)."""
    out = []
    n = len(pts)
    for i in range(n):
        a, v, b = pts[i - 1], pts[i], pts[(i + 1) % n]
        la = math.hypot(a[0] - v[0], a[1] - v[1])
        lb = math.hypot(b[0] - v[0], b[1] - v[1])
        t = min(r, 0.45 * la, 0.45 * lb)
        p1 = (v[0] + (a[0] - v[0]) * t / la, v[1] + (a[1] - v[1]) * t / la)
        p2 = (v[0] + (b[0] - v[0]) * t / lb, v[1] + (b[1] - v[1]) * t / lb)
        for k in range(seg + 1):
            s = k / seg
            out.append(((1 - s) ** 2 * p1[0] + 2 * (1 - s) * s * v[0] + s * s * p2[0], (1 - s) ** 2 * p1[1] + 2 * (1 - s) * s * v[1] + s * s * p2[1]))
    return out


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
    bullet=wr.mat(KEY + ' bullet jacket', (0.62, 0.36, 0.22), 1.0, 0.32),
    bore=wr.mat(KEY + ' bore', (0.01, 0.01, 0.01), 0.8, 0.5),
    mark=wr.mat(KEY + ' engraving', (0.35, 0.35, 0.34), 0.6, 0.5),
)
body = []
RF, RR = 600.0, 795.0          # receiver ring face, receiver rear (photo x 707 / 476)
SHROUD = (795.0, 832.0)        # bolt shroud (moves with the bolt)

# ------------------------------------------------------ barrel and brake ----
# Heavy free-floating barrel: 14.4 mm-radius shank, taper, ~20 mm at the muzzle.
PROFILE = ((-20.0, 10.2), (300.0, 10.5), (480.0, 11.0), (530.0, 11.8), (548.0, 13.8), (556.0, 14.4), (RF + 8, 14.4))
barrel = wr.loft('barrel', [[P(d, r * math.sin(2 * math.pi * k / 40), r * math.cos(2 * math.pi * k / 40)) for k in range(40)] for d, r in PROFILE], M['steel'])
wr.smooth(barrel, 40)
body.append(barrel)
body.append(cyl('crown_bore', -20.4, -19.8, 3.9, M['bore'], seg=20))
# Brake clamp collar (photo x 1419-1450): square-shouldered block, cross clamp screw below.
collar = sec('brake_collar', wr.rounded_rect(0.0, -2.1, 30.0, 35.2, 5.0, 3), 2.5, -23.5, M['steel'])
wr.boolean(collar, cyl('collar_bore', -24.5, -19.0, 4.8, None, seg=24), 'DIFFERENCE')
wr.bevel(collar, 0.0004, 2, 30)
body.append(collar)
body.append(cyl_z('collar_screw', -10.0, -14.0, -14.6, -16.4, 3.4, M['steel'], 20))
body.append(cyl_z('collar_screw_hex', -10.0, -14.0, -16.3, -16.45, 1.5, M['bore'], 6))
# Brake (photo x 1450-1484): rear wall, expansion chamber with one large side
# window each side, front baffle.
br = [wr.tube('brake_rear', P(-23.5, 0), P(-31.0, 0), 0.0140, 0.0046, M['steel'], 40),
      wr.tube('brake_chamber', P(-31.0, 0), P(-43.0, 0), 0.0140, 0.0095, M['steel'], 40),
      wr.tube('brake_front', P(-43.0, 0), P(-52.0, 0), 0.0140, 0.0046, M['steel'], 40)]
ports = []
for sgn in (1, -1):
    ports.append(side('brake_port', wr.rounded_rect(-37.0, 0.0, 9.5, 14.0, 2.6, 3), 7.0, None, z=sgn * 10.0))
wr.boolean(br[1], ports, 'DIFFERENCE')
brake = wr.join('muzzle_brake', br)
wr.bevel(brake, 0.0005, 2, 30)
body.append(brake)

# ------------------------------------------------------------- receiver ----
# Flat-bottomed, flat-sided receiver with a round top (photo top +16.5 mm).
rec_sec = [(-17.5, -19.6), (17.5, -19.6)] + [(17.5 * math.cos(math.pi * k / 16), -1.0 + 17.5 * math.sin(math.pi * k / 16)) for k in range(17)]
rec = sec('receiver', rec_sec, RF, RR, M['action'])
wr.boolean(rec, [side('ejection_port', wr.rounded_rect(706.0, 5.5, 72.0, 17.0, 3.0, 3), 9.0, None, z=-9.0),
                 side('handle_notch', [(772.0, -7.0), (RR + 2, -7.0), (RR + 2, 6.0), (772.0, 6.0)], 8.0, None, z=-14.0),
                 plan('mag_opening', [(676.0, -10.5), (750.0, -10.5), (750.0, 10.5), (676.0, 10.5)], -30.0, -9.0, None)], 'DIFFERENCE')
wr.bevel(rec, 0.0004, 2, 30)
body.append(rec)
body.append(pic_rail('rail', 581.0, RR, 23.5, M['action']))
# Markings: model/serial on the right receiver flat, calibre on the barrel shank
# (where the real rifle carries "AW" + serial and "7.62 x 51mm").
body.append(wr.text('rec_mark', 'YZ-10  No 98412', P(632.0, 3.2, -17.56), 0.0024, M['mark'], -1))
body.append(wr.text('bbl_mark', '7.62 x 51mm', P(578.0, 0.0, -14.46), 0.0021, M['mark'], -1))
body.append(side('bolt_release', [(768.0, -2.0), (784.0, -2.0), (786.0, 3.0), (784.0, 6.0), (768.0, 6.0)], 1.2, M['steel'], z=18.6))

# ------------------------------------------------------------------ stock ----
# Traced outline (photo px). Fore-end tip x 995, comb Y 165, butt bottom Y 269,
# grip toe Y 326, guard bar Y 264, magazine-well line Y 233.
OUTLINE_PX = [(988, 154.5), (993, 156.5), (995.5, 160), (996, 205), (994, 210), (990, 211.5), (724, 211), (712, 215), (700, 218),
              (676, 224), (652, 231), (628, 233), (560, 232), (540, 236), (530, 240), (520, 247), (512, 256), (504, 262), (495, 264),
              (440, 264), (428, 263), (418, 270), (410, 288), (402, 310), (396, 322), (388, 326), (372, 326.5), (352, 322), (330, 313),
              (305, 309), (290, 307), (276, 301), (262, 291), (248, 279), (238, 271), (228, 269), (98, 269), (98, 165), (420, 165),
              (428, 160), (432, 159), (500, 159), (506, 155), (512, 154), (980, 154)]
THUMB_PX = [(308, 240), (312, 226), (322, 215), (338, 209), (358, 207), (374, 207), (384, 214), (387, 228), (380, 244), (368, 258),
            (350, 267), (330, 268), (315, 260)]
GUARD_PX = [(445, 217), (512, 217), (515, 222), (515, 248), (510, 255), (447, 255), (438, 250), (433, 240), (434, 228), (438, 221)]
stock = side('stock', round_poly([IMG(*p) for p in OUTLINE_PX], 4.0), 28.0, M['stock'])
wr.boolean(stock, [side('thumbhole', round_poly([IMG(*p) for p in THUMB_PX], 14.0, 5), 40.0, None),
                   side('guard_opening', round_poly([IMG(*p) for p in GUARD_PX], 8.0, 4), 40.0, None)], 'DIFFERENCE')
# Rounded cross-sections lofted along the stock so widths blend (fore-end 55 mm,
# wrist 46 mm, butt 42 mm, grip 33 mm, guard 19 mm) and the long edges are
# radiused like the real moulding. Section bottoms ride 0.8 mm inside the traced
# outline so the rounded edge, not the cut, forms the underside.
FORE = [(357.0, 21.0, -46.0), (361.0, 25.5, -51.0), (367.0, 27.2, -51.0), (374.0, 27.5, -51.0), (590.0, 27.5, -51.0), (600.0, 27.5, -54.5),
        (612.0, 27.5, -58.2), (626.0, 27.5, -61.8), (647.0, 27.5, -67.7), (667.0, 27.5, -69.3), (724.0, 27.5, -68.5), (741.0, 27.5, -71.9), (752.0, 27.5, -76.0)]
WRIST = [(748.0, 27.5, -4.4), (770.0, 26.0, -4.4), (777.0, 25.4, -8.6), (830.0, 23.0, -8.6), (846.0, 22.4, -13.6), (884.0, 21.4, -13.6)]
# Grip about 31-34 mm through the palm, widening only where it runs into the butt.
GRIPS = [(830.0, 14.5), (850.0, 15.5), (872.0, 16.6), (884.0, 18.2), (896.0, 20.0)]
BUTT = [(878.0, -148.0, 18.6), (884.0, -147.0, 20.4), (899.0, -144.1), (917.0, -136.5), (938.0, -133.2), (951.0, -131.5), (963.0, -126.5), (974.0, -118.1), (986.0, -108.0),
        (995.0, -101.2), (1003.0, -99.6), (1116.0, -99.6)]
shape = wr.join('stock_shape', [
    sec_loft('fore_section', [(d, rsec(hw, yb, -5.2, 11.0, 6.0)) for d, hw, yb in FORE]),
    sec_loft('wrist_section', [(d, rsec(hw, -62.0, yt, 4.0, 6.0)) for d, hw, yt in WRIST]),
    sec_loft('guard_section', [(d, rsec(9.5, -95.4, -50.0, 4.5, 2.0)) for d in (751.0, 843.0)]),
    sec_loft('grip_section', [(d, rsec(hw, -175.0, -50.0, 8.0, 2.0)) for d, hw in GRIPS]),
    sec_loft('butt_section', [(b[0], rsec(b[2] if len(b) > 2 else 21.0, b[1], -13.8, 8.0, 7.0)) for b in BUTT])])
wr.moulded(shape, voxel=0.001, smooth_factor=0.0, smooth_iter=0, ratio=1.0)
wr.moulded(stock, voxel=0.001, smooth_factor=0.0, smooth_iter=0, ratio=1.0)
wr.boolean(stock, shape, 'INTERSECT', solver='MANIFOLD')
# Inletting (free-floated barrel channel, flat-bottomed action bed, magazine
# well, trigger slot) and the real side features: fore-end flute ending in the
# swivel cup, rear QD cup recess, stock-bolt counterbores.
cuts = [cyl('barrel_channel', 330.0, 548.0, 13.4, None, seg=40), cyl('shank_channel', 540.0, RF + 6, 15.2, None, seg=40),
        sec('action_bed', [(-17.9, -20.0), (17.9, -20.0), (17.9, 30.0), (-17.9, 30.0)], RF - 4, RR + 1, None),
        plan('mag_well', [(671.0, -12.3), (755.0, -12.3), (755.0, 12.3), (671.0, 12.3)], -110.0, -15.0, None),
        plan('trigger_slot', [(791.0, -3.6), (813.0, -3.6), (813.0, 3.6), (791.0, 3.6)], -66.0, -30.0, None)]
SCREWS = [(638.0, -43.0, 27.5), (522.0, -36.0, 27.5), (409.0, -36.0, 27.5), (746.0, -40.0, 27.5), (872.0, -37.0, 23.0),
          (1052.0, -32.0, 21.0), (1038.0, -32.0, 21.0), (989.0, -32.0, 21.0), (1089.0, -88.0, 21.0), (863.0, -128.0, 16.5)]
for sgn in (1, -1):
    cuts.append(side('fore_flute', stadium(404.0, 592.0, -18.0, 5.0), 3.0, None, z=sgn * 29.2))
    cuts.append(side('swivel_cup', ellipse(379.0, -24.5, 13.0, 9.0), 4.0, None, z=sgn * 26.8))
    cuts.append(side('qd_cup', wr.rounded_rect(1094.0, -31.0, 24.0, 26.0, 6.0, 3), 3.5, None, z=sgn * 22.3))
    for d, y, hw in SCREWS:
        cuts.append(cyl_z('counterbore', d, y, sgn * (hw - 1.1), sgn * (hw + 4.0), 5.0, None, 20))
wr.boolean(stock, cuts, 'DIFFERENCE', solver='MANIFOLD')
wr.moulded(stock, voxel=0.0006, smooth_factor=0.6, smooth_iter=14, ratio=0.062)
wr.assign_faces(stock, M['grip'], lambda x, y, z: 835 < (x - XM) * 1000 < 880 and (y - BY) * 1000 < -50)
body.append(stock)
# Stock bolts: socket-head cap screws seated in the counterbores, both sides.
for sgn in (1, -1):
    for d, y, hw in SCREWS:
        body.append(cyl_z('stock_bolt', d, y, sgn * (hw - 1.2), sgn * (hw - 0.3), 3.8, M['steel'], 18))
        body.append(cyl_z('stock_bolt_socket', d, y, sgn * (hw - 0.32), sgn * (hw - 0.26), 1.55, M['bore'], 6))
# Fore-end swivel cup loop and pivot, both sides.
for sgn in (1, -1):
    body.append(torus_side('swivel_loop', 381.0, -24.5, sgn * 24.6, 6.4, 1.4, M['steel']))
    body.append(cyl_z('swivel_pivot', 386.0, -24.5, sgn * 23.0, sgn * 25.6, 2.2, M['steel'], 14))
    body.append(cyl_z('qd_button', 1094.0, -31.0, sgn * 18.6, sgn * 20.6, 6.0, M['steel'], 24))
    body.append(cyl_z('qd_plunger', 1094.0, -31.0, sgn * 20.5, sgn * 21.2, 2.4, M['steel'], 14))
# Fore-end bottom studs (bipod stud and sling stud, photo x 930 / 975).
for d in (413.0, 375.0):
    body.append(cyl_y('fore_stud_base', d, -50.6, -52.4, 5.0, M['steel'], seg=20))
    body.append(cyl_y('fore_stud', d, -52.0, -58.5, 3.0, M['steel'], seg=16))

# Cheek piece (separate black moulding on the comb, photo x 100-284).
def rounded_block(name, outline, hw, yb, yt, rb, rt, d0, d1, m, ratio=0.12):
    """Side outline intersected with a rounded section, then softened."""
    o = side(name, round_poly(outline, 5.0), hw + 4.0, m)
    s = sec(name + '_sec', rsec(hw, yb, yt, rb, rt, 5), d0, d1, None)
    wr.moulded(o, voxel=0.0008, smooth_factor=0.0, smooth_iter=0, ratio=1.0)
    wr.moulded(s, voxel=0.0008, smooth_factor=0.0, smooth_iter=0, ratio=1.0)
    wr.boolean(o, s, 'INTERSECT', solver='MANIFOLD')
    wr.moulded(o, voxel=0.0007, smooth_factor=0.5, smooth_iter=6, ratio=ratio)
    return o


body.append(rounded_block('cheek_piece', [(957.0, -16.0), (1108.0, -16.0), (1108.0, 3.8), (972.0, 3.8), (962.0, 1.0), (957.5, -7.0)],
                          18.5, -16.5, 3.8, 2.0, 7.5, 950.0, 1112.0, M['stock']))
# Butt: spacer/butt-plate block and the rubber pad with its toe hook.
body.append(rounded_block('butt_spacers', [(1107.0, -0.6), (1158.0, -0.6), (1158.0, -140.0), (1107.0, -140.0)],
                          21.5, -140.0, -0.6, 6.0, 7.0, 1100.0, 1165.0, M['stock']))
body.append(rounded_block('butt_pad', [(1157.0, -1.5), (1171.0, -2.2), (1177.0, -7.0), (1179.5, -40.0), (1181.0, -110.0), (1183.5, -133.0), (1182.0, -140.0), (1172.0, -141.0), (1157.0, -140.0)],
                          23.0, -141.5, -1.5, 8.0, 9.0, 1150.0, 1190.0, M['rubber']))
# Butt monopod (anodised): base plate, post, height wheel, lock collar, foot.
mono = [plan('monopod_base', [(1050.0, -12.0), (1086.0, -12.0), (1086.0, 12.0), (1050.0, 12.0)], -102.5, -99.0, M['alu']),
        cyl_y('monopod_post', 1068.0, -100.0, -136.0, 5.0, M['alu'], seg=20),
        cyl_y('monopod_wheel', 1068.0, -107.0, -117.0, 19.0, M['alu'], seg=40),
        cyl_y('monopod_collar', 1068.0, -123.0, -128.5, 11.0, M['alu'], seg=32),
        cyl_y('monopod_foot', 1068.0, -133.0, -141.0, 15.0, M['alu'], seg=36)]
for o in mono:
    wr.bevel(o, 0.0004, 2, 30)
body += mono
# Trigger (curved steel blade) and magazine release lever ahead of the guard.
trig = side('trigger', [IMG(475, 210), IMG(479, 210), IMG(468, 224), IMG(464, 234), IMG(465, 243), IMG(470, 250.5), IMG(467, 252.5),
                         IMG(461, 245), IMG(459, 234), IMG(463, 222)], 2.6, M['steel'])
wr.bevel(trig, 0.0003, 2, 30)
body.append(trig)
mrel = side('mag_release', [(755.5, -74.0), (760.5, -74.0), (760.5, -88.0), (759.0, -92.0), (755.5, -92.0)], 5.0, M['steel'])
wr.bevel(mrel, 0.0003, 2, 30)
body.append(mrel)

# ------------------------------------------------------------------ action ----
act = []
act.append(cyl('bolt_body', 640.0, RR + 2, 9.5, M['bolt'], seg=36))
# Six locking lugs, two rows of three at the bolt head (60 degree throw).
for d0 in (641.0, 654.0):
    for k in range(3):
        a0 = math.radians(90 + 120 * k)
        arc = [(r * math.cos(a0 + t), r * math.sin(a0 + t)) for r, ts in ((9.2, (-0.42, -0.21, 0.0, 0.21, 0.42)), (12.1, (0.40, 0.2, 0.0, -0.2, -0.40))) for t in ts]
        act.append(sec('bolt_lug', arc, d0, d0 + 10.0, M['bolt']))
shroud = sec('bolt_shroud', wr.superellipse(0.0, 3.3, 26.0, 22.6, 3.4, 36), SHROUD[0], SHROUD[1], M['steel'])
wr.bevel(shroud, 0.0005, 2, 30)
act.append(shroud)
act.append(cyl('cocking_indicator', SHROUD[1] - 1, SHROUD[1] + 5.0, 2.4, M['steel'], y=3.0, seg=16))
# Three-position safety lever on the left of the shroud.
act.append(cyl_z('safety_pivot', 812.0, 6.0, 12.8, 15.0, 3.2, M['steel'], 16))
saf = side('safety', [(806.0, 4.0), (816.0, 4.0), (826.0, 11.0), (823.0, 14.0), (810.0, 9.0)], 1.0, M['steel'], z=15.2)
wr.bevel(saf, 0.0002, 2, 30)
act.append(saf)
# Handle: root at the bolt rear, swept down and back to a 20 mm round knob
# sitting just above the trigger guard (photo knob centre x 469, Y 190).
act.append(wr.cylinder('handle_root', P(780.0, 0.0, -6.0), P(780.0, -1.0, -20.0), 0.0062, M['steel'], 24))
act.append(sphere('handle_bend', 780.0, -1.0, -20.0, 5.6, M['steel'], 16, 10))
act.append(wr.cylinder('handle_stem', P(780.0, -1.0, -20.0), P(787.0, -13.0, -36.0), 0.0043, M['steel'], 18))
act.append(sphere('handle_elbow', 787.0, -13.0, -36.0, 4.3, M['steel'], 16, 10))
act.append(wr.cylinder('handle_stem2', P(787.0, -13.0, -36.0), P(797.0, -31.0, -47.5), 0.0041, M['steel'], 18))
act.append(sphere('bolt_knob', 798.0, -34.0, -50.0, 10.0, M['steel'], 32, 18))
action = wr.join('Action', act)
bpy.context.scene.cursor.location = wr.cv(P(780.0, 0.0, 0.0))
bpy.ops.object.select_all(action='DESELECT')
action.select_set(True)
bpy.context.view_layer.objects.active = action
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.context.scene.cursor.location = (0, 0, 0)

# ---------------------------------------------------------------- magazine ----
# Double-stack steel 10-round box (photo x 526-621, floor Y 266) with the
# AW floorplate grasping tabs front and rear.
mag = side('magazine', [(673.0, -14.0), (753.0, -14.0), (753.0, -93.0), (673.0, -93.0)], 12.0, M['steel'])
wr.bevel(mag, 0.0006, 2, 30)
mag_parts = [mag]
floor = side('mag_floor', [(667.0, -96.5), (669.5, -93.0), (756.5, -93.0), (759.0, -96.5), (759.0, -99.0), (667.0, -99.0)], 13.0, M['steel'])
wr.bevel(floor, 0.0005, 2, 30)
mag_parts.append(floor)
mag_parts.append(cyl('top_round', 751.0, 700.0, 5.9, M['brass'], y=-14.0, z=3.5, seg=20))
mag_parts.append(cyl('top_bullet', 700.0, 680.0, 3.9, M['bullet'], y=-14.0, z=3.5, seg=20, r1=1.4))
magazine = wr.join('Magazine', mag_parts)

# ---------------------------------------------------------- iron sights ----
# AW detachable irons: hooded post on the brake collar, aperture on the rail.
irons = []
irons.append(side('front_blade', [(-19.0, 14.0), (-1.0, 14.0), (-4.0, 38.0), (-16.0, 38.0)], 3.0, M['steel']))
irons.append(wr.tube('front_hood', P(-22.0, 44.0), P(2.0, 44.0), 0.0105, 0.0092, M['steel'], 32))
irons.append(side('front_post', [(-11.5, 34.0), (-8.5, 34.0), (-8.9, 50.0), (-11.1, 50.0)], 0.9, M['steel']))
rb = plan('rear_base', [(776.0, -10.6), (796.0, -10.6), (796.0, 10.6), (776.0, 10.6)], 23.0, 30.5, M['steel'])
wr.bevel(rb, 0.0006, 2, 30)
irons.append(rb)
ap = side('rear_aperture', [(784.0, 30.0), (788.0, 30.0), (788.0, 56.0), (784.0, 56.0)], 6.0, M['steel'])
wr.boolean(ap, cyl('peep', 778.0, 794.0, 1.1, None, y=50.0, seg=20), 'DIFFERENCE')
irons.append(ap)
irons.append(cyl_z('rear_drum', 786.0, 40.0, 6.0, 12.0, 5.0, M['steel'], 24))
iron_sights = wr.join('IronSights', irons)

body_obj = wr.join('BodyMesh', body)
objs = [body_obj, action, magazine, iron_sights]
print('AW verts', {o.name: len(o.data.vertices) for o in objs}, 'total', wr.stats(objs))
wr.export(OUT, objs)
print('EXPORTED', OUT)
