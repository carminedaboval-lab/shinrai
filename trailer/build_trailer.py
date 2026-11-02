"""Assemble the Shinrai showcase trailer from the rendered engine material.

Produces trailer/build/SHINRAI_showcase_assembly.mp4: every ENGINE and STAGED
shot cut to the narration, HUD plates composited, title cards, the transit-map
billboard composite, and a labelled placeholder (seed still, darkened) wherever
the plan calls for an AI-generated shot. Narration is the SAPI placeholder from
make_vo.ps1 until a real VO is recorded; swap the WAVs in build/vo and rerun.

    python trailer/build_trailer.py            # full build
    python trailer/build_trailer.py --gfx      # graphics only (cards, map)
    python trailer/build_trailer.py --no-encode  # graphics + timeline print

Needs Pillow, numpy, imageio_ffmpeg (ffmpeg 7).
"""
from __future__ import annotations

import json
import math
import os
import subprocess
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

import imageio_ffmpeg

ROOT = os.path.dirname(os.path.abspath(__file__))
ENGINE = os.path.join(ROOT, "engine")
CLIPS = os.path.join(ENGINE, "clips")
STILLS = os.path.join(ENGINE, "stills")
PLATES = os.path.join(ENGINE, "plates")
BUILD = os.path.join(ROOT, "build")
GFX = os.path.join(BUILD, "gfx")
SEGS = os.path.join(BUILD, "segments")
VO = os.path.join(BUILD, "vo")
OUTPUT = os.path.join(BUILD, "SHINRAI_showcase_assembly.mp4")
FF = imageio_ffmpeg.get_ffmpeg_exe()
FPS = 30
W, H = 1920, 1080

FONTS = "C:/Windows/Fonts"
INK = (9, 21, 29)
PAPER = (232, 238, 231)
MINT = (133, 223, 196)
GOLD = (229, 188, 127)
DIM = (170, 187, 189)


# ---------------------------------------------------------------- fonts

def font(name: str, size: int, variation: str | None = None) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(os.path.join(FONTS, name), size)
    if variation:
        try:
            f.set_variation_by_name(variation)
        except Exception:
            pass
    return f


def title_font(size: int) -> ImageFont.FreeTypeFont:
    return font("bahnschrift.ttf", size, "Bold Condensed")


def body_font(size: int) -> ImageFont.FreeTypeFont:
    return font("segoeui.ttf", size)


def kanji_font(size: int) -> ImageFont.FreeTypeFont:
    return font("YuGothB.ttc", size)


# ---------------------------------------------------------------- graphics

def card_base() -> Image.Image:
    img = Image.new("RGB", (W, H), (4, 9, 13))
    # faint vignette so black cards do not read as dead video
    v = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(v)
    d.ellipse((-300, -500, W + 300, H + 500), fill=28)
    v = v.filter(ImageFilter.GaussianBlur(220))
    img.paste(Image.new("RGB", (W, H), INK), (0, 0), v)
    return img


def centred(d: ImageDraw.ImageDraw, text: str, f: ImageFont.FreeTypeFont, y: int, fill) -> int:
    box = d.textbbox((0, 0), text, font=f)
    w = box[2] - box[0]
    d.text(((W - w) / 2 - box[0], y), text, font=f, fill=fill)
    return box[3] - box[1]


def make_title_card(path: str, tagline: str | None = None, kanji: bool = True) -> None:
    img = card_base()
    d = ImageDraw.Draw(img)
    f = title_font(300)
    h = centred(d, "SHINRAI", f, 330, MINT)
    y = 330 + h + 60
    if kanji:
        centred(d, "信頼", kanji_font(54), y, PAPER)
        y += 90
    if tagline:
        centred(d, tagline, body_font(46), y + 10, PAPER)
    img.save(path)


def make_platform_card(path: str) -> None:
    img = card_base()
    d = ImageDraw.Draw(img)
    centred(d, "PC   ·   WISHLIST ON STEAM", title_font(72), 470, PAPER)
    d.line((760, 580, 1160, 580), fill=MINT, width=2)
    centred(d, "A SHINRAI GAME", body_font(30), 610, DIM)
    img.save(path)


def make_kinetic_card(path: str, text: str) -> None:
    """A hard typographic beat between sections, E3 style: one line, big, left-set."""
    img = card_base()
    d = ImageDraw.Draw(img)
    f = title_font(170)
    lines = text.split("\n")
    y = H / 2 - 95 * len(lines)
    for line in lines:
        d.text((140, y), line, font=f, fill=PAPER)
        y += 190
    d.rectangle((140, y + 10, 420, y + 16), fill=MINT)
    img.save(path)


KINETIC = {
    "k_relays": "THREE RELAYS.\nONE WAY OUT.",
    "k_move": "MOVE LIKE\nIT MATTERS.",
    "k_contact": "CONTACT.",
    "k_carry": "THEY WANT\nWHAT YOU CARRY.",
    "k_train": "CATCH THE\nLAST TRAIN.",
}


def make_black(path: str) -> None:
    Image.new("RGB", (W, H), (0, 0, 0)).save(path)


def wrap(d: ImageDraw.ImageDraw, text: str, f: ImageFont.FreeTypeFont, width: int) -> list[str]:
    words, lines, line = text.split(), [], ""
    for w_ in words:
        probe = (line + " " + w_).strip()
        if d.textlength(probe, font=f) > width and line:
            lines.append(line)
            line = w_
        else:
            line = probe
    if line:
        lines.append(line)
    return lines


def make_placeholder(path: str, seed: str, index: str, text: str, first_person: bool = False) -> None:
    """Darkened seed still with the shot brief, so the cut reads with the right composition."""
    if os.path.exists(seed):
        img = Image.open(seed).convert("RGB").resize((W, H), Image.LANCZOS)
        img = img.filter(ImageFilter.GaussianBlur(1.2))
        img = Image.blend(img, Image.new("RGB", (W, H), (6, 12, 16)), 0.55)
    else:
        img = card_base()
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle((0, 0, W, 6), fill=MINT + (255,))
    d.text((60, 44), f"AI SHOT {index}", font=title_font(44), fill=MINT)
    tag = "FIRST PERSON · REAL HUD OVER THIS" if first_person else "THIRD PERSON"
    d.text((60, 100), f"PLACEHOLDER  ·  {tag}", font=body_font(22), fill=DIM)
    f = body_font(34)
    lines = wrap(d, text, f, 1160)
    y = H - 90 - 46 * len(lines)
    d.rectangle((40, y - 24, 1260, H - 60), fill=(4, 9, 13, 150))
    for line in lines:
        d.text((60, y), line, font=f, fill=PAPER)
        y += 46
    d.text((W - 60 - d.textlength("generate from the seed still, then replace", font=body_font(22)), H - 92),
           "generate from the seed still, then replace", font=body_font(22), fill=DIM)
    img.save(path)


def make_weapon_card(path: str, name: str, kind: str) -> None:
    img = Image.new("RGB", (W, H), (10, 12, 14))
    d = ImageDraw.Draw(img)
    # a dark bench: horizontal plane with a soft top light
    g = Image.new("L", (W, H), 0)
    ImageDraw.Draw(g).ellipse((300, 380, 1620, 900), fill=70)
    g = g.filter(ImageFilter.GaussianBlur(120))
    img.paste(Image.new("RGB", (W, H), (46, 52, 56)), (0, 0), g)
    d.line((240, 700, 1680, 700), fill=(60, 66, 70), width=2)
    centred(d, name, title_font(150), 400, PAPER)
    centred(d, kind.upper(), body_font(34), 580, MINT)
    d.text((60, H - 80), "AI STILL  ·  product render placeholder", font=body_font(22), fill=DIM)
    img.save(path)


STATIONS = [  # name, romaji, (x, y) on a 1600x760 board
    ("新東京", "Shin-Tokyo", (330, 150)), ("本町", "Honmachi", (520, 110)), ("中央", "Chuo", (760, 100)),
    ("東口", "Higashi-guchi", (1000, 130)), ("港", "Minato", (1230, 210)), ("大橋", "Ohashi", (1340, 380)),
    ("空港", "Kuko", (1250, 560)), ("桜台", "Sakuradai", (1020, 640)), ("緑公園前", "Midori-koen-mae", (760, 620)),
    ("山手", "Yamate", (520, 600)), ("西口", "Nishi-guchi", (320, 500)), ("北口", "Kita-guchi", (200, 330)),
]
PLAYER = (560, 760)
NEAREST = 8


def make_transit_map(path: str, countdown: str, pulse: int) -> Image.Image:
    img = Image.new("RGB", (W, H), (7, 16, 22))
    d = ImageDraw.Draw(img, "RGBA")
    # faint scanlines so it reads as a screen
    for y in range(0, H, 4):
        d.line((0, y, W, y), fill=(0, 0, 0, 40))
    ox, oy = 160, 200
    pts = [(ox + x, oy + y) for _, _, (x, y) in STATIONS]
    loop = pts + [pts[0]]
    d.line(loop, fill=(236, 240, 238), width=12, joint="curve")
    kf, rf = kanji_font(34), body_font(20)
    for i, (name, romaji, _) in enumerate(STATIONS):
        x, y = pts[i]
        r = 16
        d.ellipse((x - r, y - r, x + r, y + r), fill=(236, 240, 238), outline=(7, 16, 22), width=4)
        colour = MINT if i == NEAREST else PAPER
        if i == NEAREST:
            d.ellipse((x - 34, y - 34, x + 34, y + 34), outline=MINT + (255,), width=4)
        above = y < oy + 340
        ty = y - 78 if above else y + 26
        d.text((x - d.textlength(name, font=kf) / 2, ty), name, font=kf, fill=colour)
        d.text((x - d.textlength(romaji, font=rf) / 2, ty + 40), romaji, font=rf, fill=DIM)
    # the player: a pulsing dot with a dashed line to the nearest station
    px, py = ox + PLAYER[0], oy + PLAYER[1]
    nx, ny = pts[NEAREST]
    steps = 24
    for s in range(0, steps, 2):
        a = (px + (nx - px) * s / steps, py + (ny - py) * s / steps)
        b = (px + (nx - px) * (s + 1) / steps, py + (ny - py) * (s + 1) / steps)
        d.line((a, b), fill=MINT + (220,), width=4)
    d.ellipse((px - pulse, py - pulse, px + pulse, py + pulse), outline=MINT + (140,), width=3)
    d.ellipse((px - 11, py - 11, px + 11, py + 11), fill=MINT + (255,))
    d.text((px + 24, py - 16), "あなた  YOU", font=kanji_font(26), fill=MINT)
    d.text((nx + 44, ny - 60), "最寄り  NEAREST", font=kanji_font(24), fill=MINT)
    # header and the countdown
    d.text((80, 60), "新東京都市交通  ·  THE LINE", font=kanji_font(36), fill=PAPER)
    d.text((80, 112), "12 STOPS  ·  ONE DIRECTION  ·  DEPARTS EVERY 10 MIN", font=body_font(22), fill=DIM)
    cf = title_font(190)
    cw = d.textlength(countdown, font=cf)
    d.text((W - 90 - cw, 40), countdown, font=cf, fill=PAPER)
    lab = "次の発車  NEXT DEPARTURE"
    d.text((W - 90 - d.textlength(lab, font=kanji_font(30)), 250), lab, font=kanji_font(30), fill=MINT)
    d.text((80, H - 90), "緑公園前  →  1 STOP  ·  PLATFORM 2", font=kanji_font(32), fill=PAPER)
    img.save(path)
    return img


def perspective_coeffs(src_pts, dst_pts):
    matrix = []
    for (x, y), (u, v) in zip(dst_pts, src_pts):
        matrix.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        matrix.append([0, 0, 0, x, y, 1, -v * x, -v * y])
    a = np.array(matrix, dtype=float)
    b = np.array(src_pts, dtype=float).reshape(8)
    return np.linalg.solve(a, b)


# Billboard corners in n08_billboard_street.png (TL, TR, BR, BL).
BILLBOARD = [(567, 377), (752, 373), (752, 460), (567, 467)]


def make_billboard_composite(path: str, map_img: Image.Image) -> None:
    still = Image.open(os.path.join(STILLS, "n08_billboard_street.png")).convert("RGB")
    board = map_img.resize((960, 540), Image.LANCZOS)
    # darken slightly so it sits in the night plate, keep the glow
    board = Image.blend(board, Image.new("RGB", board.size, (0, 0, 0)), 0.12)
    xs = [p[0] for p in BILLBOARD]
    ys = [p[1] for p in BILLBOARD]
    x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
    coeffs = perspective_coeffs([(0, 0), (960, 0), (960, 540), (0, 540)],
                                [(x - x0, y - y0) for x, y in BILLBOARD])
    warped = board.transform((x1 - x0, y1 - y0), Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    mask = Image.new("L", (960, 540), 255).transform((x1 - x0, y1 - y0), Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    still.paste(warped, (x0, y0), mask)
    # a touch of glow on the street under the screen
    glow = Image.new("RGB", still.size, (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((x0 - 120, y0 - 60, x1 + 120, y1 + 160), fill=(30, 60, 55))
    glow = glow.filter(ImageFilter.GaussianBlur(70))
    still = Image.fromarray(np.clip(np.asarray(still).astype(int) + np.asarray(glow).astype(int), 0, 255).astype(np.uint8))
    still.save(path)


def build_graphics() -> None:
    os.makedirs(GFX, exist_ok=True)
    make_black(os.path.join(GFX, "black.png"))
    make_title_card(os.path.join(GFX, "title.png"))
    make_title_card(os.path.join(GFX, "logo_tagline.png"), tagline="Catch the last train.")
    make_platform_card(os.path.join(GFX, "platforms.png"))
    for name, text in KINETIC.items():
        make_kinetic_card(os.path.join(GFX, name + ".png"), text)
    for name, kind in [("SHIGURE  S-9", "submachine gun · auto"), ("RAIDEN  R-56", "assault rifle · auto"),
                       ("HAYATE  H-7", "sniper rifle · bolt action")]:
        make_weapon_card(os.path.join(GFX, "weapon_%s.png" % name.split()[0].lower()), name, kind)
    maps = []
    for i, (cd, pulse) in enumerate([("02:00", 16), ("01:59", 26), ("01:58", 36)]):
        maps.append(make_transit_map(os.path.join(GFX, f"map_{i}.png"), cd, pulse))
    make_billboard_composite(os.path.join(GFX, "billboard_map.png"), maps[0])
    for index, seed, text, fp in AI_SHOTS:
        make_placeholder(os.path.join(GFX, f"ai_{index}.png"), seed, index, text, fp)


# ---------------------------------------------------------------- shot briefs for the placeholders

QA = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "Shinrai")
AI_SHOTS = [
    ("01", os.path.join(STILLS, "d02_south_gate_push.png"), "Four operators walking through the open south gate in loose file, seen from behind at hip height, lamp bollards either side, daylight.", False),
    ("02", os.path.join(STILLS, "d03_torii_plaza.png"), "One operator kneeling with a gloved hand on a stone path lamp, a holographic ring around its base, two teammates covering outward.", False),
    ("03", os.path.join(QA, "perimeter_qa", "hole_night.png"), "Operator prone, crawling under a cut gap in the green mesh fence, bolt cutters on the chest rig, lamp light, night.", False),
    ("05", os.path.join(QA, "visual_fx_qa", "compare_after_main_street.png"), "Third person: operator throws the anchor at the roof edge of the yakitori shop, the line goes taut, they go up hand over hand.", False),
    ("06", os.path.join(QA, "visual_fx_qa", "compare_after_main_street.png"), "First person, halfway up the wall, one hand on the line, pistol up, firing down at a scav in the street.", True),
    ("07", os.path.join(STILLS, "d03_torii_plaza.png"), "Operator landing from the awning onto plaza paving, knees bent, two teammates running past, neon torii behind.", False),
    ("04c", os.path.join(STILLS, "s06_door_push.png"), "Operator clearing a dim shop interior, counter and shelves, daylight through shoji panels, a teammate silhouetted at the door.", False),
    ("04d", os.path.join(STILLS, "d03_torii_plaza.png"), "Looking down from an upper-floor clubhouse window onto the plaza, two operators crossing below.", False),
    ("08", os.path.join(STILLS, "n02_torii_neon.png"), "Dusk: three scavs around the torii base, one kneeling behind a planter watching the approach, one on a radio, one at the vending machine.", False),
    ("08a", os.path.join(STILLS, "d03_torii_plaza.png"), "Our flanker moving right along the bench line, low, as the scav watcher's head turns toward the sound.", False),
    ("08b", os.path.join(STILLS, "d03_torii_plaza.png"), "The scav watcher fires first; the crew splits, one sprinting to the far torii pillar, one dropping prone behind the planter.", False),
    ("09", os.path.join(STILLS, "s04_corner_lean.png"), "First person suppressing across the plaza ring, tracers, a scav sliding behind the torii pillar.", True),
    ("09b", os.path.join(STILLS, "d06_drone_patrol.png"), "A police drone arrives from the lake path at speed, searchlight on, and engages the scavs first.", False),
    ("09c", os.path.join(STILLS, "d03_torii_plaza.png"), "Wide: drone and scavs trading fire under the torii while one operator's hand is on the path lamp and two cover.", False),
    ("10", os.path.join(STILLS, "d04_lake_edge.png"), "Our squad pulling back west along the lake deck; another squad with different colour tags already on the arched bridge. Both freeze.", False),
    ("11", os.path.join(STILLS, "d04_lake_edge.png"), "First person firing across the lake from the deck, tracers over the water, the arched bridge, sakura.", True),
    ("13", os.path.join(STILLS, "n02_torii_neon.png"), "Night: muzzle flashes under the neon torii, wet paving reflecting pink and cyan, two operators behind planters.", False),
    ("13b", os.path.join(STILLS, "n08_billboard_street.png"), "A rival squad on a wet street two blocks over, looking up at another screen showing the same map.", False),
    ("14", os.path.join(STILLS, "n07_aerial_city_glow.png"), "Night, wide: the elevated rail line beyond the park fence, a train's headlights coming around the curve, the station lit against the city.", False),
    ("14a", os.path.join(STILLS, "n07_aerial_city_glow.png"), "Four operators sprinting up station stairs, one supporting a wounded teammate, muzzle flashes from the street below.", False),
    ("14b", os.path.join(STILLS, "n08_billboard_street.png"), "The platform: a rival squad behind a vending machine and a pillar, a police drone on the far platform turning, the train sliding in with its doors closed.", False),
    ("14c", os.path.join(STILLS, "s08_west_exfil_hud.png"), "First person leaning out from a platform pillar, firing down the platform, train doors in frame.", True),
    ("14d", os.path.join(STILLS, "n08_billboard_street.png"), "Doors open, both squads break for different carriages, one operator dragged in by a backpack strap as the chime sounds.", False),
    ("14e", os.path.join(STILLS, "n05_lake_lamps.png"), "Inside the carriage: our four on the floor and seats catching their breath, the platform sliding past, a searchlight sweeping the glass.", False),
    ("14f", os.path.join(STILLS, "n07_aerial_city_glow.png"), "The elevated train crossing above the neon city, the dark sealed park behind it, rain on the rails.", False),
]


# ---------------------------------------------------------------- timeline

# Row kinds: clip (engine/staged mp4), still (slow push), card (static png), ai (placeholder png).
# "plate" overlays a HUD PNG; "grade" applies an ffmpeg filter; "offset" trims the clip head.
BEATS = [
    ("b0", [
        {"kind": "card", "src": "black", "dur": 2.0},
        {"kind": "clip", "src": "d01_aerial_establish", "dur": 9.0},
        {"kind": "clip", "src": "n07_aerial_city_glow", "dur": 9.0},
        {"kind": "card", "src": "title", "dur": 3.0},
    ]),
    ("b1", [
        {"kind": "clip", "src": "s01_gate_walk_in", "dur": 5.5},
        {"kind": "ai", "src": "01", "dur": 3.0},
        {"kind": "clip", "src": "d03_torii_plaza", "dur": 3.5},
        {"kind": "clip", "src": "d03_torii_plaza", "dur": 3.0, "offset": 3.5, "plate": "p01_start_0of3"},
        {"kind": "ai", "src": "02", "dur": 3.5},
        {"kind": "clip", "src": "d04_lake_edge", "dur": 4.0},
        {"kind": "clip", "src": "s08_west_exfil_hud", "dur": 4.0, "offset": 1.0},
    ]),
    ("b2", [
        {"kind": "card", "src": "k_relays", "dur": 1.6, "kinetic": True},
        {"kind": "clip", "src": "d05_sakura_grove", "dur": 6.0},
        {"kind": "clip", "src": "d08_playground_pan", "dur": 4.0},
        {"kind": "clip", "src": "d09_pavilion_east", "dur": 3.0},
        {"kind": "ai", "src": "03", "dur": 3.0},
        {"kind": "clip", "src": "n01_gate_smashed", "dur": 6.0},
    ]),
    ("b3", [
        {"kind": "card", "src": "k_move", "dur": 1.6, "kinetic": True},
        {"kind": "clip", "src": "s02_sprint_stop", "dur": 5.0},
        {"kind": "clip", "src": "s03_mantle_aim", "dur": 4.2},
        {"kind": "clip", "src": "s04_corner_lean", "dur": 4.5},
        {"kind": "clip", "src": "c04_mag_check", "dur": 3.4, "offset": 0.6, "fallback": None},
        {"kind": "ai", "src": "05", "dur": 4.0},
        {"kind": "ai", "src": "06", "dur": 3.5, "plate": "p01_start_0of3"},
        {"kind": "clip", "src": "s05_jump_ads", "dur": 3.7},
        {"kind": "ai", "src": "07", "dur": 3.0},
    ]),
    ("b3b", [
        {"kind": "clip", "src": "s06_door_push", "dur": 5.6},
        {"kind": "ai", "src": "04c", "dur": 3.5},
        {"kind": "ai", "src": "04d", "dur": 3.0},
        {"kind": "clip", "src": "c05_bench_search", "dur": 4.0, "offset": 0.8,
         "fallback": {"kind": "clip", "src": "s06b_clubhouse_door", "dur": 4.0, "offset": 1.8, "plate": "p06_loot_prompt"}},
    ]),
    ("b4", [
        {"kind": "card", "src": "k_contact", "dur": 1.4, "kinetic": True},
        {"kind": "clip", "src": "d03_torii_plaza", "dur": 3.0, "grade": "dusk"},
        {"kind": "ai", "src": "08", "dur": 3.0},
        {"kind": "clip", "src": "s07_relay_approach", "dur": 3.4, "offset": 1.0},
        {"kind": "ai", "src": "08a", "dur": 2.4},
        {"kind": "clip", "src": "c01_scav_contact", "dur": 4.6, "offset": 0.5, "music": True,
         "fallback": {"kind": "ai", "src": "09", "dur": 2.8, "plate": "p01_start_0of3", "music": True}},
        {"kind": "clip", "src": "c03_reload_under_fire", "dur": 4.0, "offset": 1.4,
         "fallback": {"kind": "ai", "src": "08b", "dur": 2.8}},
        {"kind": "clip", "src": "d06_drone_patrol", "dur": 2.4, "offset": 2.0, "grade": "dusk"},
        {"kind": "clip", "src": "c06_drone_fight", "dur": 4.2, "offset": 0.8,
         "fallback": {"kind": "ai", "src": "09b", "dur": 2.2}},
        {"kind": "ai", "src": "09c", "dur": 2.8},
        {"kind": "clip", "src": "s09_drone_searchlight", "dur": 3.4, "offset": 1.0},
        {"kind": "clip", "src": "c02_hit_and_heal", "dur": 5.6, "offset": 1.4, "fallback": None},
    ]),
    ("b5", [
        {"kind": "card", "src": "k_carry", "dur": 1.6, "kinetic": True},
        {"kind": "ai", "src": "10", "dur": 4.0},
        {"kind": "clip", "src": "c07_drone_stun", "dur": 3.5, "offset": 2.5, "plate": "p02_relay_1of3",
         "fallback": {"kind": "ai", "src": "11", "dur": 3.5, "plate": "p02_relay_1of3"}},
        {"kind": "clip", "src": "n02_torii_neon", "dur": 3.5},
        {"kind": "ai", "src": "13", "dur": 3.5},
        {"kind": "clip", "src": "n05_lake_lamps", "dur": 4.0, "plate": "p04_next_train"},
    ]),
    ("b5b", [
        {"kind": "card", "src": "k_train", "dur": 1.6, "kinetic": True},
        {"kind": "still", "src": os.path.join(STILLS, "n08_billboard_street.png"), "dur": 1.2, "zoom": 1.04},
        {"kind": "still", "src": os.path.join(GFX, "billboard_map.png"), "dur": 3.0, "zoom": 2.3, "focus": (660, 420)},
        {"kind": "cards", "src": ["map_0", "map_1", "map_2"], "dur": 2.4},
        {"kind": "ai", "src": "14", "dur": 3.0},
        {"kind": "ai", "src": "13b", "dur": 2.5},
        {"kind": "ai", "src": "14a", "dur": 3.5},
        {"kind": "ai", "src": "14b", "dur": 4.0},
        {"kind": "ai", "src": "14c", "dur": 3.5, "plate": "p04_next_train"},
        {"kind": "ai", "src": "14d", "dur": 3.5},
        {"kind": "ai", "src": "14e", "dur": 4.0},
        {"kind": "ai", "src": "14f", "dur": 3.5, "music_end": True},
    ]),
    ("b6", [
        {"kind": "still", "src": os.path.join(STILLS, "hq01_field_operations.png"), "dur": 4.0, "zoom": 1.05},
        {"kind": "cards", "src": ["weapon_shigure", "weapon_raiden", "weapon_hayate"], "dur": 4.0},
        {"kind": "clip", "src": "hq02_buy_sequence", "dur": 3.6},
        {"kind": "still", "src": os.path.join(STILLS, "hq03_loadout_inventory.png"), "dur": 4.0, "zoom": 1.05},
    ]),
    ("b7", [
        {"kind": "clip", "src": "n07_aerial_city_glow", "dur": 5.0, "offset": 3.0},
        {"kind": "card", "src": "logo_tagline", "dur": 4.5},
        {"kind": "card", "src": "platforms", "dur": 3.5},
    ]),
]

VO_PAD = 0.7
GRADES = {"dusk": "eq=brightness=-0.10:saturation=0.85,colorbalance=bs=0.10:bm=0.03:rs=-0.04:gs=-0.02"}


def resolve_row(row: dict) -> dict | None:
    """A clip row that has not been rendered yet falls back to its placeholder (or is dropped)."""
    if row["kind"] == "clip" and not os.path.exists(os.path.join(CLIPS, row["src"] + ".mp4")):
        if "fallback" in row:
            print(f"  (no clip {row['src']}: using fallback)")
            return row["fallback"]
        raise SystemExit(f"missing clip {row['src']}")
    return row


def wav_seconds(path: str) -> float:
    with wave.open(path, "rb") as f:
        return f.getnframes() / float(f.getframerate())


def run(args: list[str]) -> None:
    result = subprocess.run([FF, "-y", "-hide_banner", "-loglevel", "error"] + args, capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit("ffmpeg failed:\n" + " ".join(args) + "\n" + result.stderr[-2000:])


def media_seconds(path: str) -> float:
    result = subprocess.run([FF, "-i", path], capture_output=True, text=True)
    import re
    m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", result.stderr)
    return int(m.group(2)) * 60 + float(m.group(3)) if m else 0.0


def encode_args() -> list[str]:
    return ["-r", str(FPS), "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", "-an"]


def render_row(row: dict, dur: float, out: str) -> None:
    kind = row["kind"]
    frames = max(1, int(round(dur * FPS)))
    vf: list[str] = []
    inputs: list[str] = []
    if kind == "clip":
        src = os.path.join(CLIPS, row["src"] + ".mp4")
        length = media_seconds(src)
        offset = float(row.get("offset", 0.0))
        avail = max(0.5, length - offset)
        inputs = ["-ss", f"{offset:.3f}", "-i", src]
        if dur > avail + 0.05:
            # slow the clip down to fill the slot rather than loop a visible cut
            vf.append(f"setpts={dur / avail:.4f}*PTS")
        if row.get("grade"):
            vf.append(GRADES[row["grade"]])
        vf.append(f"scale={W}:{H}")
    elif kind == "still":
        zoom = float(row.get("zoom", 1.06))
        fx, fy = row.get("focus", (W / 2, H / 2))
        # zoompan on a 2x upscale keeps the push smooth
        vf.append("scale=3840:2160")
        z = f"1+({zoom - 1})*on/{frames}"
        x = f"({fx * 2})-(iw/zoom/2)"
        y = f"({fy * 2})-(ih/zoom/2)"
        vf.append(f"zoompan=z='{z}':x='{x}':y='{y}':d={frames}:s={W}x{H}:fps={FPS}")
        inputs = ["-loop", "1", "-i", row["src"]]
    elif kind in ("card", "ai"):
        name = ("ai_" + row["src"]) if kind == "ai" else row["src"]
        inputs = ["-loop", "1", "-i", os.path.join(GFX, name + ".png")]
        if kind == "ai":
            vf.append("scale=3840:2160")
            vf.append(f"zoompan=z='1+0.05*on/{frames}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={frames}:s={W}x{H}:fps={FPS}")
    elif kind == "cards":
        # a short sequence of stills, equal time each
        names = row["src"]
        each = dur / len(names)
        parts = []
        for i, name in enumerate(names):
            part = out.replace(".mp4", f"_{i}.mp4")
            run(["-loop", "1", "-i", os.path.join(GFX, name + ".png"), "-vf",
                 f"scale=3840:2160,zoompan=z='1+0.04*on/{int(each * FPS)}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={int(each * FPS)}:s={W}x{H}:fps={FPS}",
                 "-t", f"{each:.3f}"] + encode_args() + [part])
            parts.append(part)
        concat_list = out.replace(".mp4", "_list.txt")
        with open(concat_list, "w", encoding="utf-8") as f:
            for part in parts:
                f.write("file '%s'\n" % part.replace("\\", "/"))
        run(["-f", "concat", "-safe", "0", "-i", concat_list, "-c", "copy", out])
        return
    else:
        raise ValueError(kind)
    args = inputs
    if row.get("plate"):
        args = args + ["-loop", "1", "-i", os.path.join(PLATES, row["plate"] + ".png")]
        chain = ",".join(vf) if vf else "null"
        args += ["-filter_complex", f"[0:v]{chain}[base];[base][1:v]overlay=0:0:format=auto[v]", "-map", "[v]"]
    elif vf:
        args += ["-vf", ",".join(vf)]
    args += ["-t", f"{dur:.3f}"] + encode_args() + [out]
    run(args)


def build_timeline() -> tuple[list[dict], list[dict]]:
    """Scale each beat's rows so the pictures last at least as long as its narration."""
    rows_out, vo_out = [], []
    t = 0.0
    prev_vo_end = 0.0
    for beat, rows in BEATS:
        rows = [resolve_row(r) for r in rows]
        rows = [r for r in rows if r is not None]
        vo_path = os.path.join(VO, beat + ".wav")
        vo_len = wav_seconds(vo_path) if os.path.exists(vo_path) else 0.0
        planned = sum(r["dur"] for r in rows)
        target = max(planned, vo_len + VO_PAD)
        scale = target / planned
        # Lines never overlap: a beat's narration waits for the previous one to finish,
        # and a kinetic card at the head of a beat plays clean before the line starts.
        lead = 2.0 if beat == "b0" else (rows[0]["dur"] * scale + 0.2 if rows[0].get("kinetic") else 0.4)
        vo_start = max(t + lead, prev_vo_end + 0.6)
        prev_vo_end = vo_start + vo_len
        vo_out.append({"beat": beat, "start": vo_start, "path": vo_path, "seconds": vo_len})
        for i, r in enumerate(rows):
            d = r["dur"] * scale
            rows_out.append({**r, "beat": beat, "index": i, "start": t, "seconds": d})
            t += d
    return rows_out, vo_out


def build_audio(vo: list[dict], total: float, out: str, music_start: float, music_end: float) -> None:
    inputs, chains, mixes = [], [], []
    # a rain-like bed: brown noise, low-passed, quiet, with a lift for the cold open and the train
    inputs += ["-f", "lavfi", "-t", f"{total:.3f}", "-i", "anoisesrc=color=brown:amplitude=0.6:seed=7:sample_rate=48000"]
    chains.append("[0:a]lowpass=f=700,highpass=f=60,volume=0.10,afade=t=in:d=2,afade=t=out:st=%.2f:d=3[bed]" % (total - 3))
    mixes.append("[bed]")
    # temp score: a low pulse that opens with the first shots and cuts dead as the train clears
    inputs += ["-f", "lavfi", "-t", f"{total:.3f}", "-i", "sine=f=55:r=48000"]
    inputs += ["-f", "lavfi", "-t", f"{total:.3f}", "-i", "sine=f=110:r=48000"]
    pulse_len = max(0.1, music_end - music_start)
    chains.append(f"[1:a]tremolo=f=1.75:d=0.85,volume=0.22,afade=t=in:st={music_start:.2f}:d=4,"
                  f"atrim=0:{music_end:.2f},apad,volume='if(lt(t,{music_start:.2f}),0,1)':eval=frame[p1]")
    chains.append(f"[2:a]tremolo=f=3.5:d=0.9,volume=0.07,afade=t=in:st={music_start + 8:.2f}:d=6,"
                  f"atrim=0:{music_end:.2f},apad,volume='if(lt(t,{music_start:.2f}),0,1)':eval=frame[p2]")
    mixes += ["[p1]", "[p2]"]
    for i, v in enumerate(vo, start=3):
        inputs += ["-i", v["path"]]
        chains.append(f"[{i}:a]aformat=sample_rates=48000:channel_layouts=mono,volume=1.6,adelay={int(v['start'] * 1000)}|{int(v['start'] * 1000)},apad[vo{i}]")
        mixes.append(f"[vo{i}]")
    graph = ";".join(chains) + ";" + "".join(mixes) + f"amix=inputs={len(mixes)}:normalize=0:duration=first,alimiter=limit=0.95[a]"
    run(inputs + ["-filter_complex", graph, "-map", "[a]", "-t", f"{total:.3f}", "-c:a", "aac", "-b:a", "192k", out])


def build_video(rows: list[dict]) -> str:
    os.makedirs(SEGS, exist_ok=True)
    paths = []
    for r in rows:
        out = os.path.join(SEGS, f"{r['beat']}_{r['index']:02d}.mp4")
        print(f"  {r['start']:7.2f}s  {r['seconds']:5.2f}s  {r['kind']:5s} {str(r['src'])[:48]}")
        # Segments are keyed by beat and row; delete build/segments to force a re-render.
        if not (os.path.exists(out) and os.path.getsize(out) > 1024 and "--reuse" in sys.argv):
            render_row(r, r["seconds"], out)
        paths.append(out)
    concat_list = os.path.join(BUILD, "segments.txt")
    with open(concat_list, "w", encoding="utf-8") as f:
        for p in paths:
            f.write("file '%s'\n" % p.replace("\\", "/"))
    video = os.path.join(BUILD, "video_only.mp4")
    run(["-f", "concat", "-safe", "0", "-i", concat_list, "-c", "copy", video])
    return video


def main(argv: list[str]) -> int:
    os.makedirs(BUILD, exist_ok=True)
    print("graphics...")
    build_graphics()
    if "--gfx" in argv:
        return 0
    rows, vo = build_timeline()
    total = rows[-1]["start"] + rows[-1]["seconds"]
    print(f"timeline: {len(rows)} rows, {total:.1f} s ({int(total // 60)}:{int(total % 60):02d})")
    with open(os.path.join(BUILD, "timeline.json"), "w", encoding="utf-8") as f:
        json.dump({"total": total, "rows": rows, "vo": vo}, f, indent=1)
    if "--no-encode" in argv:
        for r in rows:
            print(f"  {r['start']:7.2f}s  {r['seconds']:5.2f}s  {r['kind']:5s} {str(r['src'])[:48]}")
        return 0
    print("video segments...")
    video = build_video(rows)
    print("audio...")
    audio = os.path.join(BUILD, "audio.m4a")
    music_start = next(r["start"] for r in rows if r.get("music"))
    music_end = next(r["start"] + r["seconds"] for r in rows if r.get("music_end"))
    build_audio(vo, total, audio, music_start, music_end)
    print("mux + look...")
    # One grade over everything so engine, stills and placeholders read as a single capture:
    # soft bloom on the highlights, a touch more contrast, cool shadows / warm highlights,
    # a vignette and fine grain.
    look = ("[0:v]split[base][hi];"
            "[hi]lutyuv=y='clip((val-150)*2.2,0,255)',gblur=sigma=24[glow];"
            "[base][glow]blend=c0_mode=screen:c0_opacity=0.24:c1_mode=normal:c1_opacity=1:c2_mode=normal:c2_opacity=1,"
            "eq=contrast=1.06:saturation=1.14,"
            "colorbalance=rs=-0.03:bs=0.05:rh=0.05:bh=-0.04,"
            "vignette=angle=PI/5.6,"
            "noise=alls=5:allf=t+u,"
            f"fade=t=in:d=1.0,fade=t=out:st={total - 1.2:.2f}:d=1.2[v]")
    run(["-i", video, "-i", audio, "-filter_complex", look, "-map", "[v]", "-map", "1:a",
         "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-pix_fmt", "yuv420p", "-c:a", "copy",
         "-movflags", "+faststart", "-shortest", OUTPUT])
    print("->", OUTPUT, f"{os.path.getsize(OUTPUT) / 1e6:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
