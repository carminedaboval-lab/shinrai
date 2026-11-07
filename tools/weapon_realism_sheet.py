"""Contact sheets for the weapon realism review.

python tools/weapon_realism_sheet.py grid <weapon> <tag>        -> 5 views in one image
python tools/weapon_realism_sheet.py compare <weapon> [ref.jpg] -> before | after per view (+ reference)
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1] / "docs" / "weapon_realism_20261107"
RENDERS = ROOT / "renders"
SHEETS = ROOT / "sheets"
VIEWS = ["left", "right", "top", "fp34", "muzzle"]


def font(size):
    for name in ("segoeuib.ttf", "arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def label(img, text, size=34):
    d = ImageDraw.Draw(img)
    f = font(size)
    box = d.textbbox((0, 0), text, font=f)
    d.rectangle((0, 0, box[2] + 24, box[3] + 18), fill=(0, 0, 0))
    d.text((12, 6), text, fill=(255, 255, 255), font=f)
    return img


def grid(weapon, tag):
    tiles = [Image.open(RENDERS / f"{weapon}_{v}_{tag}.png").convert("RGB") for v in VIEWS]
    w, h = tiles[0].size
    sheet = Image.new("RGB", (w * 2, h * 3), (20, 20, 20))
    for i, (v, t) in enumerate(zip(VIEWS, tiles)):
        sheet.paste(label(t, f"{weapon} {v} [{tag}]"), ((i % 2) * w, (i // 2) * h))
    SHEETS.mkdir(parents=True, exist_ok=True)
    out = SHEETS / f"{weapon}_grid_{tag}.jpg"
    sheet.resize((w, int(h * 1.5))).save(out, quality=88)
    print(out)


TITLES = {
    "akane": "AKANE / A-9  ->  Glock 17 Gen 5 MOS (9x19)",
    "raiden_r56": "RAIDEN / R-56  ->  Colt M4A1, SOPMOD Block II layout (5.56x45)",
    "tobikage": "TOBIKAGE / T-65  ->  Dragunov SVD, laminated furniture",
    "hayate": "HAYATE / H-7  ->  USMC M40A5 (Remington 700, McMillan A4)",
    "yuzuru": "YUZURU / YZ-10  ->  Accuracy International AW (7.62x51)",
    "shigure": "SHIGURE / S-9  ->  CZ Scorpion EVO 3 A1 (9x19)",
    "kite": "KITE / K-12  ->  FN SCAR 17S / SCAR-H (7.62x51)",
}


def banner(width, text, sub):
    img = Image.new("RGB", (width, 150), (14, 14, 14))
    d = ImageDraw.Draw(img)
    d.text((24, 18), text, fill=(255, 255, 255), font=font(54))
    d.text((24, 92), sub, fill=(190, 190, 190), font=font(30))
    return img


def compare(weapon, ref=None):
    rows = []
    rows.append(None)
    for v in VIEWS:
        a = label(Image.open(RENDERS / f"{weapon}_{v}_before.png").convert("RGB"), f"BEFORE  {v}")
        b = label(Image.open(RENDERS / f"{weapon}_{v}_after.png").convert("RGB"), f"AFTER  {v}")
        w, h = a.size
        row = Image.new("RGB", (w * 2, h))
        row.paste(a, (0, 0))
        row.paste(b, (w, 0))
        rows.append(row)
    w, h = rows[1].size
    rows[0] = banner(w, TITLES.get(weapon, weapon), "Same cameras, same light. Left: previous model. Right: rebuilt to the real counterpart.")
    extra = 0
    refimg = None
    if ref:
        refimg = Image.open(ref).convert("RGB")
        refimg = label(refimg.resize((w, int(refimg.height * w / refimg.width))), "REAL REFERENCE")
        extra = refimg.height
    sheet = Image.new("RGB", (w, sum(r.height for r in rows) + extra), (20, 20, 20))
    y = 0
    if refimg:
        sheet.paste(refimg, (0, 0))
        y = extra
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    SHEETS.mkdir(parents=True, exist_ok=True)
    out = SHEETS / f"{weapon}_before_after.jpg"
    sheet.resize((w // 2, sheet.height // 2)).save(out, quality=88)
    print(out)


if __name__ == "__main__":
    if sys.argv[1] == "grid":
        grid(sys.argv[2], sys.argv[3])
    else:
        compare(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
