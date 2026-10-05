#!/usr/bin/env python3
"""0.22 dördüncü tur (elymsyr'in out_022r3_secim yorumları).

Ritim: eski seçim alınır, img2img ile hafifçe değiştirilir (kıl yok, mor az, LotR derisi).
Dönüşmüş Ork: seçilen 3a üstüne img2img; deri çok daha bozuk (yara, kabuk, ur, cüzam).
Gemiler: model direk sayısını ve katlar arası hizayı tutturamıyor. Bu yüzden önce PIL ile kaba
bir yerleşim çizilir (aynı gövde, direkler, kapaklar, merdivenler her katta aynı yerde; yelken
yalnız güvertede ve sarılı), model onu img2img ile boyar.

Gemiler iki geçiş: yerleşim -> 0.68 img2img (kaba ama yapı doğru), onun üstüne 0.45 (doku). Her gemiden
SEEDS kadar üretilir, en iyi ikisi elle out_022r4a/b'ye bm-<gemi>-tek.webp adıyla kopyalanır.

    python3 aegis_022_r4.py
    for v in a b; do python3 aegis_generate.py --jobs art_jobs_022r4_$v.jsonl --out out_022r4$v --crop 0; done
    python3 aegis_generate.py --jobs art_jobs_022r4_gemi1.jsonl --out out_022r4_gemi1 --crop 0
    python3 aegis_generate.py --jobs art_jobs_022r4_gemi2.jsonl --out out_022r4_gemi2 --crop 0
    python3 aegis_pick.py --dirs out_022r4_eski,out_022r4a,out_022r4b --outdir out_022r4_secim --key aegis022r4
"""
import json
import math
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aegis_polish as P  # noqa: E402
from aegis_prompts import entity_uuid  # noqa: E402
import aegis_022_kara_yelken as K  # noqa: E402,F401  (FRAMING ve LIGHT'ı doldurur)
import aegis_022_r3 as R3  # noqa: E402

BASE = Path(__file__).resolve().parent
PREV = BASE / "out_022r3_secim"
GUIDES = BASE / "guides_022r4"
VARIANTS = {"a": (7919, 0.0), "b": (104729, 0.1)}  # orklar: seed kayması, denoise artışı
SEEDS = 5

# --- orklar --------------------------------------------------------------------------------------
# LotR (Weta) orklarının derisi: hastalıklı, yanık ve cüzamlı; açık yaralar, kabuklar, urlar, siğiller,
# soyulan lekeler, uyumsuz gözler (Gothmog'un şişmiş urlu yüzü, Grishnákh'ın kabuklu derisi).
ROTTEN = ("diseased ravaged skin like leprosy: covered in open sores, crusted scabs and weeping blisters, "
          "tumorous lumps and warty growths swelling one side of the face, pockmarked and peeling in raw "
          "patches, old burn scars and stitched gashes, mottled ashen grey, sallow yellow and muddy brown, "
          "dark bruising")  # "purple" yazınca deri mora dönüyor; mor yalnız sızan sıvıda
ORCS = {
    "monster|Dönüşmüş Ork": (
        PREV / "c2952226-bfac-5845-8147-aa745998bf26.webp", 0.6,
        "A wiry sinewy transformed orc sailor climbing up out of a square hatch in the wooden deck of a ship, "
        "a grotesque misshapen orc exactly like the Mordor and Moria orcs of Peter Jackson's Lord of the Rings "
        "films: crooked spine, one shoulder hunched higher, a lopsided skull-like face like Gothmog's with "
        "the jaw pulled to one side, one eye swollen half shut, jagged yellow teeth with one broken fang, "
        "long pointed ears, a bald scarred scalp; " + ROTTEN + "; thick dark purple-black ichor seeping from "
        "a few deep cracks in his shoulder and from the corner of his mouth, a black-dyed crew rag knotted "
        "around his neck, a rusted cleaver at his belt",
        "cold grey light from above, black shadow in the hatch below him",
    ),
    "creature-action|Ritim": (
        PREV / "7e2c6a98-5663-532d-af60-8c0b6329dc4f.webp", 0.5,
        "On the deck of a black ship several transformed orcs crowd around a big black war drum and pound it "
        "with heavy drumsticks, all in the same rhythm, mouths open, misshapen orcs like those of Peter "
        "Jackson's Lord of the Rings films, every one different: one hulking and hunched, one thin and "
        "twisted, one with a lopsided skull; hairless, " + ROTTEN + "; thick dark purple-black ichor oozing from their cracks, torn sailors' clothes "
        "and leather straps",
        "dim overcast light, a cold glow on the drum skin",
    ),
}

def ashen(src: Path) -> Path:
    """Mor/pembe tonların doygunluğunu kırar (gri-kahveye çeker); img2img bunu referans alır.
    Yalnız prompt'la mor gitmiyor, referansın rengi baskın çıkıyor."""
    h, s_, v = Image.open(src).convert("HSV").split()
    weak = Image.eval(h, lambda x: 255 if x >= 175 or x <= 16 else 0)  # ~245°-360° ve 0°-22°
    s_ = Image.composite(Image.eval(s_, lambda x: int(x * 0.3)), s_, weak)
    out = GUIDES / f"ashen-{src.stem}.png"
    Image.merge("HSV", (h, s_, v)).convert("RGB").save(out)
    return out


# --- gemiler -------------------------------------------------------------------------------------
SEA = (19, 38, 56)
WOOD = {"black": ((58, 48, 42), (24, 22, 22)), "honey": ((168, 118, 64), (78, 50, 28))}  # (döşeme, küpeşte)
CREAM, IRON, DARK = (214, 200, 168), (70, 70, 74), (30, 20, 14)


def half_beam(t):
    """Gövdenin 0 (pruva) - 1 (kıç) boyunca yarı genişliği, 0..1."""
    if t < 0.32:
        return math.sin(t / 0.32 * math.pi / 2) ** 0.8
    return 1.0 - 0.18 * max(0.0, (t - 0.75) / 0.25) ** 2


def hull_poly(cx, top, L, B, inset=0.0):
    pts = []
    for i in range(61):
        t = i / 60
        pts.append((cx + (B / 2 * half_beam(t) - inset), top + t * L))
    for i in range(60, -1, -1):
        t = i / 60
        pts.append((cx - (B / 2 * half_beam(t) - inset), top + t * L))
    return pts


def ladder(d, x, y0, y1, w=26, col=(150, 110, 70)):
    d.line([(x - w / 2, y0), (x - w / 2, y1)], fill=col, width=4)
    d.line([(x + w / 2, y0), (x + w / 2, y1)], fill=col, width=4)
    for y in range(int(y0) + 6, int(y1), 11):
        d.line([(x - w / 2, y), (x + w / 2, y)], fill=col, width=3)


def _add(a, b):
    return ImageChops.add(a, b)


def draw_ship(spec):
    """spec: {w, h, wood, masts: [t...], hatches: [(t, size)], decks: [callable(d, geo, i)]}"""
    W, H, n = spec["w"], spec["h"], len(spec["decks"])
    img = Image.new("RGB", (W, H), SEA)
    mask = Image.new("L", (W, H), 0)
    pw = W / n
    B, L = pw * spec.get("beam", 0.8), H * spec.get("length", 0.92)
    top = (H - L) / 2
    floor, rim = WOOD[spec["wood"]]
    for i, deck in enumerate(spec["decks"]):
        d = ImageDraw.Draw(img)
        cx = pw * i + pw / 2
        Y = lambda t: top + t * L  # noqa: E731
        d.polygon(hull_poly(cx, top, L, B), fill=rim)
        ImageDraw.Draw(mask).polygon(hull_poly(cx, top, L, B), fill=255)
        inner = hull_poly(cx, top, L, B, inset=B * 0.06)
        if i == 0:
            d.polygon(inner, fill=floor)
            for k in range(-6, 7):  # döşeme çizgileri
                x = cx + k * B / 14
                d.line([(x, Y(0.08)), (x, Y(0.99))], fill=tuple(c - 18 for c in floor), width=2)
            d.polygon(hull_poly(cx, top, L, B), outline=rim, width=int(B * 0.07))
        elif spec.get("ribs"):
            # alt kat yukarıdan kesilmiş: tavan yok, koyu döşeme ve gövde duvarından çıkan kaburgalar
            d.polygon(inner, fill=DARK)
            for k in range(-5, 6):
                x = cx + k * B / 12
                d.line([(x, Y(0.08)), (x, Y(0.99))], fill=(22, 15, 10), width=2)
            for t in [x / 100 for x in range(10, 98, 5)]:
                hb = B / 2 * half_beam(t) - B * 0.06
                for s_ in (-1, 1):
                    d.line([(cx + s_ * hb, Y(t)), (cx + s_ * (hb - B * 0.05), Y(t))], fill=(62, 42, 24), width=9)
        else:
            d.polygon(inner, fill=DARK)
            # tavan kirişleri; direğin üstüne düşen kiriş modelde seren olup çıkıyor, onları atla
            for t in [x / 100 for x in range(10, 98, 7) if all(abs(x / 100 - m) > 0.05 for m in spec["masts"])]:
                hb = B / 2 * half_beam(t) - B * 0.06
                d.line([(cx - hb, Y(t)), (cx + hb, Y(t))], fill=(14, 9, 6), width=10)
        geo = {"cx": cx, "Y": Y, "B": B, "L": L, "hb": lambda t: B / 2 * half_beam(t) - B * 0.07}
        for (t, sz) in spec["hatches"]:  # kapaklar her katta aynı yerde
            s = B * sz
            box = [cx - s / 2, Y(t) - s / 2, cx + s / 2, Y(t) + s / 2]
            if i == 0:
                iron = spec.get("iron", IRON)
                d.rectangle(box, fill=(60, 42, 26), outline=iron, width=5)
                for k in range(1, 4):
                    d.line([(box[0] + k * s / 4, box[1]), (box[0] + k * s / 4, box[3])], fill=iron, width=3)
            else:
                d.rectangle(box, fill=(120, 96, 66), outline=(60, 44, 30), width=4)
                ladder(d, cx, box[1] + 4, box[3] - 4)
        deck(d, geo, i)
        for t in spec["masts"]:  # direk her katta aynı yerde; seren ve sarılı yelken yalnız güvertede
            r = B * 0.045
            if i == 0:
                yw = geo["hb"](t) * 2 + B * 0.08
                d.rectangle([cx - yw / 2, Y(t) - 5, cx + yw / 2, Y(t) + 5], fill=(60, 40, 22))
                d.rounded_rectangle([cx - yw / 2 + 10, Y(t) + 4, cx + yw / 2 - 10, Y(t) + 18],
                                    radius=7, fill=CREAM)
            d.ellipse([cx - r, Y(t) - r, cx + r, Y(t) + r], fill=(92, 60, 32), outline=(40, 26, 14), width=3)
        if i:
            for t in spec.get("lanterns", []):
                img = _add(img, _glow_layer(img.size, cx, Y(t), B * 0.35))
    sea = Image.new("RGB", (W, H), SEA)
    if spec.get("shadow"):  # gövdenin denize düşen gölgesi: modele hacim ipucu
        sh = Image.new("L", (W, H), 0)
        sh.paste(mask, (14, 18))
        sea = Image.composite(Image.new("RGB", (W, H), (6, 14, 22)), sea, sh.filter(ImageFilter.GaussianBlur(16)))
    return Image.composite(img, sea, mask)


def _glow_layer(size, x, y, r):
    g = Image.new("RGB", size, (0, 0, 0))
    ImageDraw.Draw(g).ellipse([x - r, y - r, x + r, y + r], fill=(110, 62, 18))
    return g.filter(ImageFilter.GaussianBlur(r / 2.5))


def crates(d, x, y, cols, rows, s=26, col=(120, 84, 48)):
    for a in range(cols):
        for b in range(rows):
            d.rectangle([x + a * s, y + b * s, x + a * s + s - 3, y + b * s + s - 3], fill=col, outline=(60, 40, 22))


def barrels(d, x, y, cols, rows, s=24, col=(110, 74, 40)):
    for a in range(cols):
        for b in range(rows):
            d.ellipse([x + a * s, y + b * s, x + a * s + s - 3, y + b * s + s - 3], fill=col, outline=(50, 32, 18),
                      width=3)


def sacks(d, x, y, cols, rows, s=28):
    for a in range(cols):
        for b in range(rows):
            d.ellipse([x + a * s, y + b * s * 0.8, x + a * s + s - 2, y + b * s * 0.8 + s * 0.7], fill=(176, 150, 100))


def wall(d, g, t, door=True):
    cx, hb, y = g["cx"], g["hb"](t), g["Y"](t)
    d.line([(cx - hb, y), (cx - 22, y)], fill=(70, 46, 26), width=10)
    d.line([(cx + 22, y), (cx + hb, y)], fill=(70, 46, 26), width=10)
    if not door:
        d.line([(cx - 22, y), (cx + 22, y)], fill=(70, 46, 26), width=10)


def raised(d, g, t0, t1, col):
    """Kıç/pruva kasarası: biraz açık renk, kenarında basamak."""
    cx, Y = g["cx"], g["Y"]
    pts = [(cx + g["hb"](t0 + (t1 - t0) * k / 20), Y(t0 + (t1 - t0) * k / 20)) for k in range(21)]
    pts += [(cx - g["hb"](t0 + (t1 - t0) * k / 20), Y(t0 + (t1 - t0) * k / 20)) for k in range(20, -1, -1)]
    d.polygon(pts, fill=col)
    edge = Y(t0) if t0 > 0.5 else Y(t1)
    d.line([(cx - g["hb"](t0 if t0 > 0.5 else t1), edge), (cx + g["hb"](t0 if t0 > 0.5 else t1), edge)],
           fill=(40, 28, 18), width=8)


# Kara Yelken: pruva yukarıda. Kapak ana direğin dibinde, alt bölmenin (ambarın ön yarısı) tek ağzı.
def ky_top(d, g, i):
    cx, Y, hb = g["cx"], g["Y"], g["hb"]
    raised(d, g, 0.80, 0.99, (74, 62, 54))
    ladder(d, cx - hb(0.8) + 40, Y(0.75), Y(0.80))
    d.ellipse([cx - 52, Y(0.86) - 52, cx + 52, Y(0.86) + 52], fill=(120, 40, 30), outline=(20, 20, 20), width=6)
    d.ellipse([cx - 40, Y(0.86) - 40, cx + 40, Y(0.86) + 40], fill=(200, 180, 140))  # davul
    d.rectangle([cx - 4, Y(0.93), cx + 4, Y(0.99)], fill=(50, 36, 24))  # dümen yekesi
    for t in [x / 100 for x in range(18, 80, 6)]:  # küpeştede kalkanlar
        for s in (-1, 1):
            x = cx + s * (hb(t) + 6)
            d.ellipse([x - 15, Y(t) - 15, x + 15, Y(t) + 15], fill=(90, 82, 70), outline=(30, 30, 30), width=3)
    for s in (-1, 1):  # pruvada sarılı kanca zincirleri
        x = cx + s * g["B"] * 0.15
        d.ellipse([x - 26, Y(0.15) - 26, x + 26, Y(0.15) + 26], outline=IRON, width=8)
    for t in (0.36, 0.62):  # cirit rafları
        d.rectangle([cx + hb(t) - 34, Y(t) - 40, cx + hb(t) - 18, Y(t) + 40], fill=(90, 66, 40))


def ky_low(d, g, i):
    cx, Y, hb = g["cx"], g["Y"], g["hb"]
    wall(d, g, 0.52, door=False)  # alt bölmeyi kapatan kalın tahta perde
    d.line([(cx - hb(0.52), Y(0.52)), (cx + hb(0.52), Y(0.52))], fill=(52, 36, 22), width=18)
    for k in range(9):  # alt bölme: saman, tırnak izleri
        x, y = cx - hb(0.3) * 0.7 + k * hb(0.3) * 0.17, Y(0.2 + (k % 4) * 0.07)
        d.line([(x, y), (x + 14, y + 22)], fill=(150, 130, 70), width=3)
    wall(d, g, 0.80)  # kaptan kamarası
    d.rectangle([cx - 46, Y(0.87) - 26, cx + 46, Y(0.87) + 26], fill=(110, 76, 44))
    for k in range(4):
        d.rectangle([cx - 30 + k * 16, Y(0.87) - 14, cx - 18 + k * 16, Y(0.87) - 2], fill=(220, 210, 180))
    d.rectangle([cx + hb(0.9) - 50, Y(0.9) - 20, cx + hb(0.9) - 8, Y(0.9) + 40], fill=(80, 60, 40))  # ranza
    crates(d, cx - hb(0.6) + 6, Y(0.56), 3, 3)
    barrels(d, cx + hb(0.6) - 80, Y(0.56), 3, 4)
    sacks(d, cx - hb(0.7) + 6, Y(0.70), 3, 2)


# Dürüst Terazi: üç direk (ön direkte gözcü sepeti), iki ambar kapağı ve bir iniş kapağı; kat kat hizalı.
def dt_top(d, g, i):
    cx, Y, hb = g["cx"], g["Y"], g["hb"]
    raised(d, g, 0.02, 0.17, (184, 134, 80))  # baş kasarası
    d.ellipse([cx - 26, Y(0.10) - 26, cx + 26, Y(0.10) + 26], fill=(100, 70, 40), outline=(50, 34, 20), width=5)
    d.rectangle([cx - hb(0.07) + 4, Y(0.07) - 10, cx - hb(0.07) + 40, Y(0.07) + 10], fill=IRON)  # demir
    ladder(d, cx + hb(0.2) - 30, Y(0.17), Y(0.22))
    raised(d, g, 0.78, 0.99, (184, 134, 80))  # kıç kasarası
    ladder(d, cx - hb(0.78) + 30, Y(0.73), Y(0.78))
    d.rectangle([cx - 5, Y(0.93), cx + 5, Y(0.99)], fill=(60, 40, 22))  # dümen
    d.polygon([(cx - 40, Y(0.86)), (cx + 40, Y(0.86)), (cx, Y(0.81))], fill=(90, 64, 40))  # balista
    d.line([(cx - 60, Y(0.85)), (cx + 60, Y(0.85))], fill=(70, 50, 30), width=8)
    d.rounded_rectangle([cx - g["B"] * 0.13, Y(0.44), cx + g["B"] * 0.13, Y(0.56)], radius=30,
                        fill=(140, 96, 52), outline=(70, 46, 24), width=5)  # ters bağlı filika
    for s in (-1, 1):
        x = cx + s * hb(0.62) * 0.65
        d.ellipse([x - 20, Y(0.62) - 20, x + 20, Y(0.62) + 20], outline=(200, 180, 130), width=6)  # halat


def dt_mid(d, g, i):
    cx, Y, hb = g["cx"], g["Y"], g["hb"]
    wall(d, g, 0.78)  # kaptan kamarası: harita masası, ranza, yazı masası
    d.rectangle([cx - 60, Y(0.87) - 34, cx + 60, Y(0.87) + 34], fill=(120, 84, 48))
    d.rectangle([cx - 44, Y(0.87) - 22, cx + 44, Y(0.87) + 22], fill=(220, 206, 170))
    d.rectangle([cx - hb(0.9) + 8, Y(0.84), cx - hb(0.9) + 50, Y(0.95)], fill=(90, 66, 44))
    wall(d, g, 0.64)  # muhafız ranzaları
    for s in (-1, 1):
        for k in range(2):
            x = cx + s * (hb(0.7) - 30)
            d.rectangle([x - 22, Y(0.67) + k * 50, x + 22, Y(0.67) + k * 50 + 40], fill=(90, 66, 44))
    d.rectangle([cx + hb(0.6) - 26, Y(0.58), cx + hb(0.6) - 10, Y(0.63)], fill=(140, 140, 150))  # mızrak rafı
    for t in (0.26, 0.31, 0.36, 0.48, 0.53):  # hamaklar
        for s in (-1, 1):
            x = cx + s * hb(t) * 0.55
            d.ellipse([x - 40, Y(t) - 12, x + 40, Y(t) + 12], fill=(170, 150, 110))
    d.rectangle([cx + hb(0.2) - 70, Y(0.2) - 24, cx + hb(0.2) - 24, Y(0.2) + 24], fill=(40, 40, 44))  # ocak
    wall(d, g, 0.17)


def dt_hold(d, g, i):
    cx, Y, hb = g["cx"], g["Y"], g["hb"]
    sacks(d, cx - hb(0.3) + 6, Y(0.22), 4, 6)
    crates(d, cx + 30, Y(0.22), 4, 5)
    barrels(d, cx - hb(0.55) + 6, Y(0.44), 4, 6)
    barrels(d, cx + 30, Y(0.44), 4, 6)
    sacks(d, cx - hb(0.75) + 6, Y(0.68), 4, 3)
    crates(d, cx + 30, Y(0.68), 4, 3)
    for t in (0.14, 0.9):  # dipte biraz sintine suyu
        d.ellipse([cx - 40, Y(t) - 16, cx + 40, Y(t) + 16], fill=(40, 60, 70))


SHIPS = {
    "Kara-Yelken": {
        "w": 1152, "h": 1536, "wood": "black", "masts": [0.30, 0.56], "hatches": [(0.47, 0.22)],
        "lanterns": [0.62, 0.86], "decks": [ky_top, ky_low],
        "prompt": "A 2-level battle map sheet of a large black-tarred two-masted orc warship, its hull and planks "
                  "tarred almost black, shown as two tall vertical panels side by side, both straight-down "
                  "views with the bow pointing up, same hull. LEFT: the open main deck with two masts, each "
                  "with its yard and the black canvas rolled tight along it, a raised stern deck with a huge "
                  "round war drum before the tiller, round shields hung along both rails, javelin racks, a "
                  "heavy iron-banded hatch at the foot of the mainmast, coiled chains with grappling hooks at "
                  "the bow. RIGHT: the hold one level below, dark and lantern-lit, heavy ceiling beams: the "
                  "forward half sealed off by a thick plank bulkhead, empty inside with dirty straw, scratch "
                  "marks and dark stains, a ladder up to the hatch; behind it stores of crates, barrels and "
                  "sacks; at the stern a cramped captain's cabin with a table covered in papers and a cot. "
                  "Dark sea-blue background. ",
    },
    "Dürüst-Terazi": {
        "w": 1536, "h": 1600, "wood": "honey", "masts": [0.22, 0.40, 0.70],
        "hatches": [(0.31, 0.24), (0.60, 0.20)], "lanterns": [0.3, 0.6, 0.87], "decks": [dt_top, dt_mid, dt_hold],
        "prompt": "A 3-level battle map sheet of a large three-masted merchant carrack with honey-brown oiled "
                  "planks, well kept, shown as three tall vertical panels side by side, all straight-down "
                  "views with the bow pointing up, same hull, masts and hatches in the same places on every "
                  "level. LEFT: the open main deck with three masts, foremast, mainmast and mizzenmast, each "
                  "with its yard and the cream canvas rolled tight along it, a forecastle with the capstan "
                  "and anchor, two cargo hatches, a ship's boat lashed upside down, coiled ropes, a raised "
                  "stern deck with the tiller and a wooden ballista on a swivel mount, stairs up to both "
                  "raised decks. MIDDLE: the deck below, dim and lantern-lit, ceiling beams, the masts "
                  "passing through as round posts, no yards or canvas: at the stern the captain's cabin with "
                  "a table and a bunk; forward of it the guards' bunks and a spear "
                  "rack; amidships crew hammocks; at the bow a small iron galley stove; ladders down through "
                  "the open hatches. RIGHT: the cargo hold at the bottom of the ship, dark and lantern-lit, "
                  "the masts' feet as round posts: sacks of spices, stacked crates and water barrels lashed "
                  "in neat rows between the curved ribs, a little bilge water, ladders under the hatches. "
                  "Dark sea-blue background. ",
    },
}


def main() -> None:
    GUIDES.mkdir(exist_ok=True)
    base = []
    for key, (ref, denoise, subject, light) in ORCS.items():
        cat, name = key.split("|", 1)
        job = {"uuid": entity_uuid(cat, name), "category": cat, "name": name, "ref": str(ashen(ref)),
               "denoise": denoise}
        P.LIGHT[key] = light
        job["prompt"] = P.build(job, subject)
        job["seed"] = int(job["uuid"][:8], 16)
        base.append(job)
    p1, p2 = [], []
    for i, (ship, spec) in enumerate(SHIPS.items()):
        guide = GUIDES / f"{ship}.png"
        draw_ship(spec).save(guide)
        for k in range(SEEDS):
            job = {"uuid": f"bm-{ship}-tek-s{k}", "category": "battlemap", "name": f"{ship} — tek üretim",
                   "prompt": spec["prompt"] + R3.MAP, "seed": 23000 + i * 17 + k * 7919, "ref": str(guide),
                   "denoise": 0.68, "width": spec["w"], "height": spec["h"]}
            p1.append(job)
            p2.append({**job, "seed": job["seed"] + 5, "denoise": 0.45,
                       "ref": str(BASE / "out_022r4_gemi1" / f"{job['uuid']}.webp")})
    for name, jobs in (("gemi1", p1), ("gemi2", p2)):
        (BASE / f"art_jobs_022r4_{name}.jsonl").write_text(
            "".join(json.dumps(j, ensure_ascii=False) + "\n" for j in jobs), encoding="utf-8")
    for v, (off, dd) in VARIANTS.items():
        (BASE / f"art_jobs_022r4_{v}.jsonl").write_text(
            "".join(json.dumps({**j, "seed": (j["seed"] + off) % 2**32, "denoise": round(j["denoise"] + dd, 2)},
                               ensure_ascii=False) + "\n" for j in base), encoding="utf-8")
    old = BASE / "out_022r4_eski"
    old.mkdir(exist_ok=True)
    for j in base + [{"uuid": f"bm-{s}-tek"} for s in SHIPS]:
        src = PREV / f"{j['uuid']}.webp"
        if src.exists():
            shutil.copy2(src, old / src.name)
    print(len(base), "ork job x", len(VARIANTS), "+", len(p1), "gemi job x 2 geçiş")


if __name__ == "__main__":
    main()
