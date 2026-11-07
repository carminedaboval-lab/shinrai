"""AKANE / A-9 rebuilt as its real counterpart: Glock 17 Gen 5 (MOS), 9x19.

Blender 5.2:  blender --background --python tools/weapon_real/akane_glock17.py
Dimensions traced in millimetres from a calibrated left-side photograph
(Wikimedia Commons "Glock 17 Gen 5 Gun white bg crop.png") and checked against
factory figures: length 202 mm, slide 186 mm, height 139 mm, width 34 mm,
barrel 114 mm. Reference frame: x = mm behind the muzzle crown, y = mm below
the top of the sights, z = mm to the gun's left. Trademarked logos are
replaced with AKANE markings in the same places and styles.
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy
import wr

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / 'assets/weapons/akane/akane_geometry.glb'
X0, BORE_Y, BORE_MM = -0.113, 0.020, 15.0


def P(x, y, z=0.0):
    return (X0 + x / 1000.0, BORE_Y - (y - BORE_MM) / 1000.0, z / 1000.0)


def XY(pts):
    return [P(x, y)[:2] for x, y in pts]


def arc(cx, cy, r, a0, a1, n=8):
    # Angles in degrees in the (x right, y down) photo frame.
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def side(name, pts, half, m, z=0.0):
    return wr.extrude_xy(name, XY(pts), (z - half) / 1000, (z + half) / 1000, m)


def section(name, pts_zy, x0, x1, m):
    return wr.extrude_zy(name, [(z / 1000, P(0, y)[1]) for z, y in pts_zy], P(x0, 0)[0], P(x1, 0)[0], m)


def top(name, pts_xz, y0, y1, m):
    return wr.extrude_xz(name, [(P(x, 0)[0], z / 1000) for x, z in pts_xz], P(0, y1)[1], P(0, y0)[1], m)


wr.reset()
M = dict(
    slide=wr.mat('A9 nDLC slide', (0.032, 0.034, 0.036), 0.72, 0.40),
    frame=wr.mat('A9 frame polymer', (0.030, 0.031, 0.032), 0.0, 0.62),
    grip=wr.mat('A9 grip texture', (0.030, 0.031, 0.032), 0.0, 0.74),
    small=wr.mat('A9 blackened steel', (0.055, 0.058, 0.060), 0.85, 0.36),
    bright=wr.mat('A9 bright steel', (0.50, 0.50, 0.49), 1.0, 0.28),
    barrel=wr.mat('A9 nDLC barrel', (0.040, 0.042, 0.044), 0.80, 0.30),
    bore=wr.mat('A9 bore', (0.010, 0.010, 0.010), 0.9, 0.45),
    white=wr.mat('A9 sight white', (0.82, 0.82, 0.78), 0.0, 0.45),
    sight=wr.mat('A9 sight polymer', (0.025, 0.026, 0.027), 0.0, 0.55),
    mag=wr.mat('A9 magazine polymer', (0.028, 0.029, 0.030), 0.0, 0.52),
    brass=wr.mat('A9 brass', (0.72, 0.52, 0.24), 1.0, 0.28),
    copper=wr.mat('A9 copper jacket', (0.70, 0.36, 0.20), 1.0, 0.30),
    follower=wr.mat('A9 orange follower', (0.85, 0.30, 0.05), 0.0, 0.5),
    mark=wr.mat('A9 laser marking', (0.20, 0.205, 0.21), 0.35, 0.55),
)

# ---------------------------------------------------------------- slide ----
SLIDE_TOP, SLIDE_BOT, SLIDE_HALF = 4.2, 27.6, 12.75
FRONT, REAR = 1.6, 184.0
prof = arc(5.8, 8.4, 4.2, 180, 270, 8) + [(REAR - 0.6, SLIDE_TOP), (REAR, SLIDE_TOP + 0.6), (REAR, SLIDE_BOT), (FRONT + 1.6, SLIDE_BOT), (FRONT, SLIDE_BOT - 1.8)]
slide = side('Slide', prof, SLIDE_HALF, M['slide'])
# Gen 5 slide section: flat sides, flat top, broad 45-degree top chamfers.
sec = [(-SLIDE_HALF, SLIDE_BOT + 1), (SLIDE_HALF, SLIDE_BOT + 1), (SLIDE_HALF, 8.6), (SLIDE_HALF - 0.6, 7.7), (8.9, SLIDE_TOP), (-8.9, SLIDE_TOP), (-SLIDE_HALF + 0.6, 7.7), (-SLIDE_HALF, 8.6)]
wr.boolean(slide, section('slide_section', sec, -2, 190, None), 'INTERSECT')
# Gen 5 nose is radiused in plan view as well.
R_NOSE = 3.6
right = [(FRONT - 0.3 + R_NOSE - R_NOSE * math.cos(math.radians(a)), -(SLIDE_HALF - R_NOSE) - R_NOSE * math.sin(math.radians(a))) for a in range(0, 91, 15)]
plan = right + [(FRONT + 8, -SLIDE_HALF - 1), (REAR + 2, -SLIDE_HALF - 1), (REAR + 2, SLIDE_HALF + 1), (FRONT + 8, SLIDE_HALF + 1)] + [(x, -z) for x, z in reversed(right)]
plan_cut = top('slide_plan', plan, -2, 40, None)
wr.boolean(slide, plan_cut, 'INTERSECT')

cuts = []
PITCH = 5.08
for k in range(7):
    for cx in (144.5 + PITCH * k, 10.6 + PITCH * k):
        for s in (1, -1):
            # Square-bottomed slide serrations, open through the top chamfer
            # and the bottom edge, 1.0 mm deep.
            c = side('serration', [(cx - 1.0, 2.0), (cx + 1.0, 2.0), (cx + 1.0, 29), (cx - 1.0, 29)], 1.6, None, z=s * (SLIDE_HALF + 0.6))
            cuts.append(c)
# Ejection port: right side, opening across the top to just past centreline.
port = [(78.0, -1), (117.0, -1), (117.0, 12.5)] + arc(115.0, 12.5, 2.0, 0, 90, 4)[1:] + arc(80.0, 12.5, 2.0, 90, 180, 4)
cuts.append(side('ejection_port', port, 7.85, None, z=-6.9))
# Muzzle: barrel bore and recoil-spring tunnel.
# MOS cut and rear-sight dovetail recess on the top flat.
cuts.append(top('mos_cut', wr.rounded_rect(149.0, 0, 31.0, 17.0, 2.5, 4), SLIDE_TOP - 1, SLIDE_TOP + 1.35, None))
cuts.append(top('rear_dovetail', [(168.4, -8.6), (176.4, -8.6), (176.4, 8.6), (168.4, 8.6)], SLIDE_TOP - 1, SLIDE_TOP + 1.2, None))
cuts.append(top('front_dovetail', [(9.2, -1.7), (13.0, -1.7), (13.0, 1.7), (9.2, 1.7)], SLIDE_TOP - 1, SLIDE_TOP + 0.6, None))
# Slide cover plate seam on the rear face.
wr.boolean(slide, cuts, 'DIFFERENCE')
seam = section('cover_plate_seam', [(z, y) for z, y in wr.rounded_rect(0, 16.2, 15.6, 20.2, 1.6, 3)], REAR - 0.25, REAR + 1, None)
inner = section('cover_plate_inner', [(z, y) for z, y in wr.rounded_rect(0, 16.2, 15.0, 19.6, 1.3, 3)], REAR - 1, REAR + 1, None)
wr.boolean(seam, inner, 'DIFFERENCE')
wr.boolean(slide, seam, 'DIFFERENCE')
wr.bevel(slide, 0.00035, 2, 30)
# Keyhole muzzle opening (barrel over recoil-spring tunnel), cut after the
# edge bevel so the round openings stay clean.
wr.boolean(slide, [wr.cylinder('barrel_hole', P(-3, BORE_MM), P(14, BORE_MM), 0.0069, None, 56), wr.cylinder('spring_hole', P(-3, 23.0), P(10, 23.0), 0.0037, None, 40)], 'DIFFERENCE')
wr.clean_slots(slide, M['slide'])
wr.smooth(slide, 30)

slide_parts = [slide]
# MOS cover plate with its two screws.
plate = top('mos_plate', wr.rounded_rect(149.0, 0, 30.6, 16.6, 2.3, 4), SLIDE_TOP, SLIDE_TOP + 1.3, M['slide'])
wr.bevel(plate, 0.0003, 2, 30)
slide_parts.append(plate)
for sx in (137.5, 160.5):
    slide_parts.append(wr.cylinder('mos_screw', P(sx, SLIDE_TOP + 0.05), P(sx, SLIDE_TOP - 0.22), 0.0021, M['small'], 20))
    slide_parts.append(wr.cylinder('mos_screw_socket', P(sx, SLIDE_TOP - 0.2), P(sx, SLIDE_TOP - 0.24), 0.0011, M['bore'], 6))
# Rear sight: polymer, sloped face, U notch with white outline.
NOTCH_R, NOTCH_C = 1.75, 1.6


def notch_poly(r, top_y=0.6, c=NOTCH_C):
    return [(r, top_y), (r, c)] + [(r * math.cos(math.radians(a)), c + r * math.sin(math.radians(a))) for a in range(15, 180, 15)] + [(-r, c), (-r, top_y)]


rs_sec = [(-8.3, SLIDE_TOP + 1.2), (8.3, SLIDE_TOP + 1.2), (8.0, SLIDE_TOP - 0.4), (6.4, 1.0)] + notch_poly(NOTCH_R, 1.0) + [(-6.4, 1.0), (-8.0, SLIDE_TOP - 0.4)]
rear_sight = section('rear_sight', rs_sec, 168.6, 176.2, M['sight'])
slope = side('rear_sight_slope', [(166, -3), (171.5, -3), (167.5, 3.6), (166, 3.6)], 12, None)
wr.boolean(rear_sight, slope, 'DIFFERENCE')
wr.bevel(rear_sight, 0.0003, 2, 30)
slide_parts.append(rear_sight)
u_white = section('rear_sight_u', [(z, y) for z, y in [(3.35, 1.0)] + notch_poly(NOTCH_R + 0.85, 1.0) + [(-3.35, 1.0)]], 176.15, 176.3, M['white'])
wr.boolean(u_white, section('u_inner', notch_poly(NOTCH_R, -1.0), 175, 177, None), 'DIFFERENCE')
slide_parts.append(u_white)
# Front sight: polymer post with white dot facing the shooter.
fs = section('front_sight', [(-1.65, SLIDE_TOP + 0.6), (1.65, SLIDE_TOP + 0.6), (1.5, 1.4), (1.1, 1.0), (-1.1, 1.0), (-1.5, 1.4)], 9.3, 13.0, M['sight'])
fs_slope = side('fs_slope', [(7.0, 6), (7.0, -2), (11.2, -2), (9.0, 4.6)], 5, None)
wr.boolean(fs, fs_slope, 'DIFFERENCE')
wr.bevel(fs, 0.00025, 2, 30)
slide_parts.append(fs)
slide_parts.append(wr.cylinder('front_dot', P(12.95, 2.25), P(13.1, 2.25), 0.0009, M['white'], 18))
# Extractor plate and loaded-chamber bump behind the port (right side).
ext = side('extractor', [(117.4, 9.6), (133.5, 9.6), (134.5, 10.8), (134.5, 14.0), (117.4, 14.0)], 0.35, M['small'], z=-(SLIDE_HALF - 0.1))
wr.bevel(ext, 0.00012, 1, 30)
slide_parts.append(ext)
slide_parts.append(side('extractor_bump', [(118.5, 10.8), (121.5, 10.8), (121.5, 13.0), (118.5, 13.0)], 0.25, M['small'], z=-(SLIDE_HALF + 0.35)))
# Markings (left: logo box, model, origin, calibre; right: serial).
L = SLIDE_HALF + 0.02
slide_parts.append(wr.text('mark_logo', 'AKANE', P(63.5, 15.2, L), 0.0032, M['mark'], 1))
box_o = side('logo_box', [(55.2, 11.7), (71.8, 11.7), (71.8, 18.7), (55.2, 18.7)], 0.03, M['mark'], z=L)
box_i = side('logo_box_i', [(55.7, 12.2), (71.3, 12.2), (71.3, 18.2), (55.7, 18.2)], 0.2, None, z=L)
wr.boolean(box_o, box_i, 'DIFFERENCE')
slide_parts.append(box_o)
slide_parts.append(wr.text('mark_model', 'A9  Gen5', P(84.0, 15.2, L), 0.0027, M['mark'], 1))
slide_parts.append(wr.text('mark_origin', 'JAPAN', P(104.0, 15.2, L), 0.0024, M['mark'], 1))
slide_parts.append(wr.text('mark_cal', '9x19', P(126.5, 15.2, L), 0.0027, M['mark'], 1))
slide_parts.append(wr.text('mark_serial', 'AKN 207', P(57.0, 21.5, -L), 0.0021, M['mark'], -1))
slide_obj = wr.join('Slide', slide_parts)

# --------------------------------------------------------------- barrel ----
barrel_parts = [wr.tube('barrel_tube', P(FRONT - 0.1, BORE_MM), P(80, BORE_MM), 0.0068, 0.0045, M['barrel'], 40)]
crown = wr.cylinder('bore_shadow', P(FRONT + 3.0, BORE_MM), P(FRONT + 6.0, BORE_MM), 0.00452, M['bore'], 32)
barrel_parts.append(crown)
hood = section('barrel_hood', wr.rounded_rect(0, 13.4, 16.6, 18.4, 1.2, 3), 78.0, 116.5, M['barrel'])
wr.bevel(hood, 0.0003, 2, 30)
barrel_parts.append(hood)
barrel_parts.append(wr.cylinder('chamber_mouth', P(115.0, BORE_MM), P(116.6, BORE_MM), 0.0049, M['bore'], 24))
barrel_parts.append(wr.text_top('mark_hood', '9x19', P(97.0, SLIDE_TOP - 0.02), 0.0028, M['mark']))
barrel_obj = wr.join('Barrel', barrel_parts)

# ---------------------------------------------------------------- frame ----
F_HALF = 11.9
frame_parts = []
upper = [(4.0, 27.0), (186.0, 27.0), (188.0, 28.4), (188.0, 31.2), (185.5, 33.6), (183.0, 34.3), (180.0, 35.0), (177.0, 36.6), (174.0, 39.4), (171.0, 44.6), (169.6, 48.5), (160.0, 60.0), (118.0, 60.0), (113.0, 42.0), (64.0, 42.0), (8.0, 38.8)] + arc(6.6, 35.2, 3.0, 90, 180, 4)
frame_parts.append(side('frame_upper', upper, F_HALF, M['frame']))
# Squared Gen 5 trigger guard with the small hook at its lower front corner.
guard = [(62.0, 40.0), (118.0, 40.0), (121.0, 66.0), (120.0, 67.6), (118.0, 67.5), (116.0, 67.8), (114.0, 68.8), (112.0, 69.9), (110.0, 70.6), (74.0, 70.5), (70.5, 70.3), (68.4, 69.9), (67.4, 68.6), (68.0, 67.2), (69.4, 66.0), (69.2, 47.0), (68.0, 45.2), (66.0, 43.3), (64.0, 42.2)]
frame_parts.append(side('trigger_guard', guard, 5.6, M['frame']))


def fstrap(y):
    if y < 60:
        return 110.0
    if y < 66:
        return 110.0 + (y - 60) / 6 * 6.5
    return 116.5 + (y - 66) * (30.5 / 65.0)


BACK = [(48.5, 169.6), (52, 171.0), (57, 172.4), (62.8, 174.0), (71.4, 177.0), (77.6, 180.0), (83.3, 183.0), (88.5, 186.0), (92.8, 189.0), (98.5, 192.0), (104.4, 195.0), (112.4, 198.0), (118.0, 199.1), (123.0, 199.0), (126.5, 198.0), (129.4, 196.0), (131.5, 193.4)]


def bstrap(y):
    for (y0, x0), (y1, x1) in zip(BACK, BACK[1:]):
        if y0 <= y <= y1:
            return x0 + (x1 - x0) * (y - y0) / (y1 - y0)
    return BACK[-1][1]


rings = []
levels = [48.5 + i * 2.75 for i in range(31)]
levels[-1] = 132.0
for y in levels:
    xf, xr = fstrap(y), bstrap(y)
    depth = xr - xf
    width = 29.6 + max(0.0, (y - 120) / 11.5) * 1.6  # Gen 5 flared magwell
    r = min(10.5, depth / 2 - 0.3, width / 2 - 0.3)
    pts = wr.rounded_rect((xf + xr) / 2, 0.0, depth, width, r, 5)
    rings.append([P(x, y, z) for x, z in pts])
frame_parts.append(wr.loft('grip', rings, M['frame']))
frame = wr.join('Receiver', frame_parts)
wr.moulded(frame, voxel=0.00042, smooth_factor=0.55, smooth_iter=5, ratio=0.22)

fcuts = []
opening = [(75.0, 52.0)] + arc(80.0, 47.2, 5.0, 180, 270, 5)[1:] + [(106.0, 42.2), (110.5, 43.5), (113.5, 46.5), (116.0, 51.0), (117.2, 55.0), (116.6, 58.6), (114.2, 62.4), (111.6, 64.6), (108.0, 66.1), (80.0, 66.4), (76.5, 64.5), (75.0, 60.0)]
fcuts.append(side('trigger_opening', opening, 20, None))
# Magazine well, along the 22-degree magazine axis, and the Gen 5 front cutout.
ang = math.radians(22.0)
ax = (-math.sin(ang), -math.cos(ang))  # photo frame: up the grip


def mag_ring(t, depth, width, rr=3.0, cx=166.4, cy=132.2):
    # t = mm up the magazine axis from the base-plate top.
    ox, oy = cx + ax[0] * t, cy + ax[1] * t
    pts = wr.rounded_rect(0, 0, depth, width, rr, 3)
    # Section plane is perpendicular to the axis: local u along the grip
    # front-back direction (perpendicular to axis in the side plane).
    ux, uy = math.cos(ang), -math.sin(ang)
    return [P(ox + ux * u, oy + uy * u, z) for u, z in pts]


fcuts.append(wr.loft('magwell', [mag_ring(-4, 34.4, 24.6, 3.4), mag_ring(12, 33.2, 23.4, 3.2), mag_ring(96, 33.2, 23.4, 3.2)], None))
fcuts.append(wr.cylinder('mag_cutout', P(150.0, 134.0, -20), P(150.0, 134.0, 20), 0.0061, None, 32))
# Takedown and slide-stop recesses on both sides.
for s in (1, -1):
    fcuts.append(side('takedown_recess', [(87.6, 27.6), (92.8, 27.6), (92.8, 38.4), (87.6, 38.4)], 1.0, None, z=s * F_HALF))
    fcuts.append(side('stop_recess', [(124.8, 26.5), (136.4, 26.5), (136.4, 33.6), (124.8, 33.6)], 0.8, None, z=s * F_HALF))
# Gen 5 rail with its single cross slot.
wr.boolean(frame, fcuts, 'DIFFERENCE', solver='MANIFOLD')
wr.clean_slots(frame, M['frame'])
rail = section('rail', [(-11.2, 37.8), (11.2, 37.8), (11.2, 38.9), (9.6, 39.8), (10.4, 40.8), (10.0, 41.6), (-10.0, 41.6), (-10.4, 40.8), (-9.6, 39.8), (-11.2, 38.9)], 6.0, 47.5, M['frame'])
wr.boolean(rail, side('rail_slot', [(20.4, 39.4), (23.9, 39.4), (23.9, 43), (20.4, 43)], 14, None), 'DIFFERENCE')
wr.bevel(rail, 0.0003, 2, 30)
# Textured grip: Gen 5 texture on both sides, front strap and backstrap,
# bounded above by the thumb-rest line.


def textured(x, y, z):
    xm = (x - X0) * 1000
    ym = BORE_MM - (y - BORE_Y) * 1000
    if ym > 131.0:
        return False
    if xm < 118:
        return False
    edge = 58.5 + (45.6 - 58.5) * (min(max(xm, 126), 169) - 126) / 43.0
    return ym > edge + 2.0


wr.assign_faces(frame, M['grip'], textured)
frame_parts = [frame, rail]
# Molded frame marking (raised) on the left dust cover.
frame_parts.append(wr.text('frame_logo', 'AKANE', P(27.0, 33.4, F_HALF - 0.05), 0.0026, M['frame'], 1, depth=0.00018))
frame_parts.append(wr.text('frame_cal', '9x19', P(40.0, 33.4, -(F_HALF - 0.05)), 0.0024, M['frame'], -1, depth=0.00018))
for s in (1, -1):
    z = s * (F_HALF - 0.55)
    # Takedown lever: serrated steel tab.
    lever = side('takedown_lever', [(88.3, 28.3), (92.1, 28.3), (92.1, 37.6), (88.3, 37.6)], 0.7, M['small'], z=z + s * 0.25)
    wr.boolean(lever, [side('lever_groove', [(88.0, yy), (92.4, yy), (92.4, yy + 0.55), (88.0, yy + 0.55)], 0.5, None, z=z + s * 0.95) for yy in (29.8, 31.6, 33.4)], 'DIFFERENCE')
    wr.bevel(lever, 0.0002, 1, 30)
    frame_parts.append(lever)
    # Ambidextrous slide stop with gripping ridges.
    stop = side('slide_stop', [(125.6, 27.4), (135.4, 27.4), (135.4, 31.0), (133.6, 32.8), (125.6, 32.8)], 1.1, M['small'], z=s * (F_HALF + 0.5))
    wr.boolean(stop, [side('stop_ridge', [(xx, 26), (xx + 0.6, 26), (xx + 0.6, 34), (xx, 34)], 0.5, None, z=s * (F_HALF + 1.6)) for xx in (127.4, 129.2, 131.0, 132.8)], 'DIFFERENCE')
    wr.bevel(stop, 0.0002, 1, 30)
    frame_parts.append(stop)
    for px, py in ((102.0, 36.6), (166.0, 52.8)):
        frame_parts.append(wr.cylinder('pin', P(px, py, s * (F_HALF - 0.6)), P(px, py, s * (F_HALF + 0.08)), 0.00145, M['bright'], 18))
# Magazine catch (left side), with vertical ridges.
catch = side('mag_catch', [(122.8, 54.6), (135.6, 54.6), (135.8, 64.6), (123.6, 64.6)], 1.6, M['frame'], z=14.2)
wr.boolean(catch, [side('catch_ridge', [(xx, 53), (xx + 0.7, 53), (xx + 0.7, 66), (xx, 66)], 0.5, None, z=15.8) for xx in (125.0, 127.6, 130.2, 132.8)], 'DIFFERENCE')
wr.bevel(catch, 0.0003, 2, 30)
frame_parts.append(catch)
# Captive recoil-spring guide rod end, seen in the lower muzzle opening.
frame_parts.append(wr.cylinder('guide_rod', P(3.4, 23.0), P(40.0, 23.0), 0.0021, M['small'], 24))
frame_parts.append(wr.cylinder('guide_rod_cap', P(3.2, 23.0), P(4.4, 23.0), 0.0029, M['small'], 24))
frame_parts.append(wr.box('serial_plate', P(57.0, 41.75, 0), (0.0115, 0.0003, 0.0072), M['bright']))
frame_obj = wr.join('Receiver', frame_parts)

# -------------------------------------------------------------- trigger ----
tf = [(101.2, 43.0), (100.6, 48.0), (99.4, 52.6), (97.4, 56.0), (95.2, 59.2), (93.8, 62.2)]
tr = [(108.6, 43.0), (108.2, 52.0), (106.4, 57.6), (103.6, 61.2), (100.4, 63.4), (97.2, 65.0)]
shoe = side('trigger_shoe', [(101.6, 40.0)] + tf + arc(95.4, 63.2, 1.8, 160, 75, 4) + list(reversed(tr)) + [(109.0, 40.0)], 3.3, M['small'])
wr.boolean(shoe, side('safety_slot', [(x - 1.2, y) for x, y in tf[1:-1]] + [(x + 1.6, y) for x, y in reversed(tf[1:-1])], 1.25, None), 'DIFFERENCE')
wr.bevel(shoe, 0.0004, 2, 30)
blade = side('trigger_safety', [(x - 0.9, y) for x, y in tf[1:-1]] + [(x + 1.8, y) for x, y in reversed(tf[1:-1])], 1.1, M['small'])
wr.bevel(blade, 0.0002, 1, 30)
trigger_obj = wr.join('Trigger', [shoe, blade])

# ------------------------------------------------------------- magazine ----
mag_parts = [wr.loft('mag_body', [mag_ring(0, 31.6, 22.4, 2.6), mag_ring(78, 31.6, 22.4, 2.6), mag_ring(92, 30.4, 19.6, 2.6), mag_ring(99, 29.0, 14.6, 2.4)], M['mag'])]
for i, t in enumerate((20, 33, 46, 59, 72)):
    # Rear witness holes along the spine.
    cx, cy = 166.4 + ax[0] * t + math.cos(ang) * 15.9, 132.2 + ax[1] * t - math.sin(ang) * 15.9
    hole = wr.cylinder('witness', P(cx - math.cos(ang) * 2, cy + math.sin(ang) * 2), P(cx + math.cos(ang) * 1, cy - math.sin(ang) * 1), 0.0016, M['bore'], 16)
    mag_parts.append(hole)
base = [(146.8, 133.2), (147.6, 132.0), (186.4, 132.0), (187.4, 133.4), (187.0, 139.6), (185.6, 140.8), (150.4, 140.8), (147.4, 139.4)]
bp = side('base_plate', base, 13.4, M['mag'])
wr.bevel(bp, 0.0009, 3, 30)
mag_parts.append(bp)
top_t = 99.0
tx, ty = 166.4 + ax[0] * top_t, 132.2 + ax[1] * top_t
mag_parts.append(wr.cylinder('top_case', P(tx + 9.0, ty - 3.0, -2.6), P(tx - 10.4, ty - 3.0, -2.6), 0.00495, M['brass'], 24))
mag_parts.append(wr.cylinder('top_bullet', P(tx - 10.4, ty - 3.0, -2.6), P(tx - 17.0, ty - 3.0, -2.6), 0.00451, M['copper'], 24, radius_b=0.0022))
mag_parts.append(wr.loft('follower_edge', [mag_ring(97.6, 27.0, 12.6, 2.0), mag_ring(98.6, 27.0, 12.6, 2.0)], M['follower']))
mag_obj = wr.join('Magazine', mag_parts)

objs = [slide_obj, barrel_obj, frame_obj, trigger_obj, mag_obj]
for o in objs:
    bpy.context.view_layer.objects.active = o
print('A9 verts', {o.name: len(o.data.vertices) for o in objs}, 'total', wr.stats(objs))
if '--blend' in sys.argv:
    bpy.ops.wm.save_as_mainfile(filepath=str(REPO / 'tools/weapon_real/akane_glock17.blend'))
wr.export(OUT, objs)
print('EXPORTED', OUT)
