#!/usr/bin/env python3
"""0.19 battlemap: Askeri Hukuk Odası — zemin kat, üst kat ve kiler tek haritada.

Prompt tek başına katları birbirine oturtamıyor (merdiven bir katta sağda, ötekinde solda;
üst kata sokak kapısı çiziyor). O yüzden plan burada ızgarada elle çizilir: kare = 5 ft = 80 px,
merdiven / kiler kapağı / iskele her katta aynı karede. Z-Image çizimin üstüne img2img ile
boyar (düşük denoise: düzen kalır, doku gelir). compose üç katı tek görselde birleştirir:
üstte zemin ve üst kat yan yana, altta ortada kiler; geçişler A/B/C rozetleriyle eşlenir.

    python3 aegis_019_battlemap.py refs
    python3 aegis_generate.py --jobs out_bm_019/art_jobs.jsonl --out out_bm_019/out --size 1280 --crop 0 --quality 90
    python3 aegis_019_battlemap.py compose        # → out_bm_019/Askeri-Hukuk-Odası.webp
"""
import json
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

BASE = Path(__file__).resolve().parent
WORK = BASE / "out_bm_019"  # gitignore (tool/**/out*): çizimler ve job'lar her zaman yeniden üretilir
C, N = 80, 16  # kare px, tuval kare sayısı

# Ev: x 3–13, y 1–13 (y aşağı = sokak). Kiler yalnız arka yarının altında: y 1–8.
STAIR = (11.9, 3, 12.9, 7)        # zemin: dipte (güney) başlar, kuzeye çıkar
TRAP = (7.6, 5.9, 8.6, 6.9)       # zemin kat kiler kapağı; kiler merdiveninin üst ucu bunun altı
CELLAR_STAIR = (7.6, 2.9, 8.6, 6.9)
JOISTS = (5, 4.2, 8, 6.8)         # üst katta döşenmemiş kısım (ocak salonunun üstü)
LADDER = (1.45, 12.6, 2.45, 14.4)  # sokaktan iskeleye çıkan merdiven

VOID, NEIGH, MORTAR = (18, 15, 13), (46, 41, 38), (78, 72, 64)
STONE, STONE_HI = (66, 62, 58), (104, 98, 90)
WOOD_OLD, WOOD_NEW, TIMBER, OAK = (150, 108, 66), (198, 160, 112), (122, 86, 50), (78, 50, 28)
FLAG, EARTH, IRON, CLOTH = (112, 104, 92), (36, 30, 24), (40, 40, 44), (176, 158, 120)

rng = random.Random(19)


def p(v: float) -> int:
    return int(round(v * C))


def box(x0, y0, x1, y1):
    return (p(x0), p(y0), p(x1), p(y1))


def jit(col, a=10):
    d = rng.randint(-a, a)
    return tuple(max(0, min(255, c + d)) for c in col)


def dark(col, f=0.6):
    return tuple(int(c * f) for c in col)


# --- dokular ---------------------------------------------------------------

def planks(d, x0, y0, x1, y1, col, w=0.25):
    y = y0
    while y < y1 - 1e-6:
        y2 = min(y + w, y1)
        d.rectangle(box(x0, y, x1, y2), fill=jit(col, 14))
        for _ in range(int((x1 - x0) * 2)):  # damar
            gx, gy = rng.uniform(x0, x1), rng.uniform(y + 0.04, y2 - 0.04)
            d.line([(p(gx), p(gy)), (p(min(gx + rng.uniform(0.4, 1.4), x1)), p(gy))], fill=dark(col, 0.85), width=1)
        d.line([(p(x0), p(y2)), (p(x1), p(y2))], fill=dark(col, 0.45), width=3)
        x = x0 + rng.uniform(0, 2)
        while x < x1:
            d.line([(p(x), p(y)), (p(x), p(y2))], fill=dark(col, 0.5), width=3)
            x += rng.uniform(1.5, 3.2)
        y = y2


def cobbles(d, x0, y0, x1, y1, f=1.0):
    d.rectangle(box(x0, y0, x1, y1), fill=dark(MORTAR, f))
    y = y0
    while y < y1:
        x = x0 + rng.uniform(-0.1, 0.1)
        while x < x1:
            s = rng.uniform(0.17, 0.26)
            d.ellipse(box(x, y, min(x + s, x1), min(y + s * 0.85, y1)), fill=dark(jit((128, 121, 110), 16), f))
            x += s + 0.03
        y += 0.22


def flags(d, x0, y0, x1, y1):
    d.rectangle(box(x0, y0, x1, y1), fill=MORTAR)
    y = y0
    while y < y1:
        h = rng.uniform(0.55, 0.9)
        x = x0
        while x < x1:
            w = rng.uniform(0.6, 1.1)
            d.rectangle(box(x + 0.03, y + 0.03, min(x + w, x1) - 0.03, min(y + h, y1) - 0.03), fill=jit(FLAG, 14))
            x += w
        y += h


def rough(d, x0, y0, x1, y1, col, n=400):
    d.rectangle(box(x0, y0, x1, y1), fill=col)
    for _ in range(n):
        x, y, s = rng.uniform(x0, x1), rng.uniform(y0, y1), rng.uniform(0.1, 0.5)
        d.ellipse(box(x, y, min(x + s, x1), min(y + s * 0.7, y1)), fill=jit(col, 8))


def roofs(d, x0, y0, x1, y1):
    """Komşu evler: yukarıdan kiremit sıraları, koyu."""
    d.rectangle(box(x0, y0, x1, y1), fill=NEIGH)
    y = y0
    while y < y1:
        d.line([(p(x0), p(y)), (p(x1), p(y))], fill=dark(NEIGH, 0.7), width=3)
        y += 0.3


# --- duvarlar / açıklıklar -------------------------------------------------

def stone_wall(d, x0, y0, x1, y1):
    d.rectangle(box(x0, y0, x1, y1), fill=STONE)
    horiz = (x1 - x0) > (y1 - y0)
    t = 0.0
    length = (x1 - x0) if horiz else (y1 - y0)
    while t < length:
        u = rng.uniform(0.35, 0.7)
        if horiz:
            d.rectangle(box(x0 + t + 0.02, y0 + 0.04, min(x0 + t + u, x1) - 0.02, y1 - 0.04), outline=STONE_HI, width=2)
        else:
            d.rectangle(box(x0 + 0.04, y0 + t + 0.02, x1 - 0.04, min(y0 + t + u, y1) - 0.02), outline=STONE_HI, width=2)
        t += u


def timber_wall(d, x0, y0, x1, y1):
    d.rectangle(box(x0, y0, x1, y1), fill=TIMBER, outline=dark(TIMBER, 0.5), width=3)
    horiz = (x1 - x0) > (y1 - y0)
    t = x0 if horiz else y0
    end = x1 if horiz else y1
    while t < end:  # dikmeler
        if horiz:
            d.rectangle(box(t, y0 - 0.03, t + 0.14, y1 + 0.03), fill=dark(TIMBER, 0.75))
        else:
            d.rectangle(box(x0 - 0.03, t, x1 + 0.03, t + 0.14), fill=dark(TIMBER, 0.75))
        t += 0.8


def studs(d, x0, y0, x1, y1):
    """Bitmemiş ara bölme: koyu alt kuşak + aralıklı dikmeler, arası boş (açık zeminde kaybolmasın diye koyu)."""
    horiz = (x1 - x0) > (y1 - y0)
    m = (y0 + y1) / 2 if horiz else (x0 + x1) / 2
    plate = box(x0, m - 0.07, x1, m + 0.07) if horiz else box(m - 0.07, y0, m + 0.07, y1)
    d.rectangle(plate, fill=TIMBER, outline=(40, 26, 14), width=2)
    t, end = (x0, x1) if horiz else (y0, y1)
    while t <= end - 0.18:
        post = box(t, m - 0.13, t + 0.18, m + 0.13) if horiz else box(m - 0.13, t, m + 0.13, t + 0.18)
        d.rectangle(post, fill=dark(TIMBER, 0.8), outline=(30, 20, 10), width=2)
        t += 0.5

def partition(d, x0, y0, x1, y1):
    d.rectangle(box(x0, y0, x1, y1), fill=WOOD_NEW, outline=dark(WOOD_NEW, 0.45), width=2)


def window(d, x0, y0, x1, y1):
    d.rectangle(box(x0, y0, x1, y1), fill=(150, 160, 160), outline=OAK, width=3)
    if (x1 - x0) > (y1 - y0):
        d.line([(p((x0 + x1) / 2), p(y0)), (p((x0 + x1) / 2), p(y1))], fill=OAK, width=3)
    else:
        d.line([(p(x0), p((y0 + y1) / 2)), (p(x1), p((y0 + y1) / 2))], fill=OAK, width=3)


def door(d, hx, hy, dx, dy, w=1.0):
    """Açık kapı kanadı: menteşe (hx,hy), kanat (dx,dy) yönünde, w uzunluğunda."""
    x1, y1 = hx + dx * w, hy + dy * w
    if dx:
        d.rectangle(box(min(hx, x1), hy - 0.07, max(hx, x1), hy + 0.07), fill=OAK, outline=dark(OAK, 0.5))
    else:
        d.rectangle(box(hx - 0.07, min(hy, y1), hx + 0.07, max(hy, y1)), fill=OAK, outline=dark(OAK, 0.5))


def doorframe(d, x0, y0, x1, y1):
    """Kapısı takılmamış boşluk: iki kasa dikmesi."""
    for (a, b) in ((x0, y0), (x1, y1)):
        d.rectangle(box(a - 0.12, b - 0.12, a + 0.12, b + 0.12), fill=TIMBER, outline=dark(TIMBER, 0.5))


# --- eşyalar ---------------------------------------------------------------

def stairs(d, x0, y0, x1, y1, col, down_north=False):
    """Basamaklar kuzey-güney; yukarıdaki uç açık, aşağı indikçe koyulaşır."""
    d.rectangle(box(x0 - 0.1, y0, x1 + 0.1, y1), fill=(24, 16, 10))
    n = round((y1 - y0) / 0.3)
    h = (y1 - y0) / n
    for i in range(n):
        f = (0.5 + 0.5 * i / n) if down_north else (1.05 - 0.5 * i / n)
        ty = y0 + i * h
        d.rectangle(box(x0 + 0.02, ty + 0.05, x1 - 0.02, ty + h - 0.02), fill=dark(col, f))
        d.line([(p(x0 + 0.02), p(ty + 0.06)), (p(x1 - 0.02), p(ty + 0.06))], fill=dark(col, min(1.25, f + 0.25)), width=3)
    for xx in (x0 - 0.1, x1):
        d.rectangle(box(xx, y0, xx + 0.1, y1), fill=TIMBER, outline=dark(TIMBER, 0.5))


def barrel(d, cx, cy, r=0.37):
    d.ellipse(box(cx - r, cy - r, cx + r, cy + r), fill=(112, 76, 44), outline=(40, 30, 22), width=3)
    d.ellipse(box(cx - r * 0.78, cy - r * 0.78, cx + r * 0.78, cy + r * 0.78), outline=IRON, width=3)
    d.line([(p(cx - r * 0.7), p(cy)), (p(cx + r * 0.7), p(cy))], fill=(80, 54, 32), width=2)


def crate(d, x0, y0, x1, y1):
    d.rectangle(box(x0, y0, x1, y1), fill=(170, 130, 82), outline=(70, 48, 28), width=3)
    d.line([(p(x0), p(y0)), (p(x1), p(y1))], fill=(110, 78, 46), width=4)
    d.line([(p(x0), p(y1)), (p(x1), p(y0))], fill=(110, 78, 46), width=4)


def papers(d, x0, y0, x1, y1):
    crate(d, x0, y0, x1, y1)
    for _ in range(5):
        x, y = rng.uniform(x0, x1 - 0.3), rng.uniform(y0, y1 - 0.25)
        d.rectangle(box(x, y, x + 0.28, y + 0.22), fill=(226, 214, 186), outline=(150, 136, 110))


def table(d, x0, y0, x1, y1, col=(124, 84, 50)):
    d.rectangle(box(x0, y0, x1, y1), fill=col, outline=dark(col, 0.45), width=3)
    y = y0 + 0.2
    while y < y1 - 0.1:
        d.line([(p(x0 + 0.05), p(y)), (p(x1 - 0.05), p(y))], fill=dark(col, 0.75), width=2)
        y += 0.2


def chair(d, cx, cy, back="n"):
    d.rectangle(box(cx - 0.22, cy - 0.22, cx + 0.22, cy + 0.22), fill=(120, 82, 48), outline=(50, 34, 20), width=2)
    bx = {"n": (cx - 0.22, cy - 0.28, cx + 0.22, cy - 0.18), "s": (cx - 0.22, cy + 0.18, cx + 0.22, cy + 0.28)}[back]
    d.rectangle(box(*bx), fill=(80, 54, 32))


def shelf(d, x0, y0, x1, y1):
    d.rectangle(box(x0, y0, x1, y1), fill=(140, 100, 62), outline=(60, 40, 24), width=3)
    horiz = (x1 - x0) > (y1 - y0)
    t = (x0 if horiz else y0) + 0.5
    while t < (x1 if horiz else y1):
        if horiz:
            d.line([(p(t), p(y0)), (p(t), p(y1))], fill=(60, 40, 24), width=2)
        else:
            d.line([(p(x0), p(t)), (p(x1), p(t))], fill=(60, 40, 24), width=2)
        t += 0.5


def lumber(d, x0, y0, x1, y1):
    """Kereste istifi: tek tek kalaslar, uçları kaymış, aralarında gölge."""
    horiz = (x1 - x0) > (y1 - y0)
    span = (y1 - y0) if horiz else (x1 - x0)
    k = max(2, int(span / 0.17))
    w = span / k
    d.rectangle(box(x0, y0, x1, y1), fill=(40, 28, 16))
    for i in range(k):
        a, b = rng.uniform(0, 0.25), rng.uniform(0, 0.25)
        c = jit(WOOD_NEW, 16)
        if horiz:
            t = y0 + i * w
            d.rectangle(box(x0 + a, t + 0.02, x1 - b, t + w - 0.02), fill=c, outline=dark(c, 0.55))
            d.rectangle(box(x0 + a, t + 0.02, x0 + a + 0.06, t + w - 0.02), fill=dark(c, 0.75))
        else:
            t = x0 + i * w
            d.rectangle(box(t + 0.02, y0 + a, t + w - 0.02, y1 - b), fill=c, outline=dark(c, 0.55))
            d.rectangle(box(t + 0.02, y0 + a, t + w - 0.02, y0 + a + 0.06), fill=dark(c, 0.75))

def tar(d, cx, cy, r=0.24):
    d.ellipse(box(cx - r, cy - r, cx + r, cy + r), fill=(96, 70, 44), outline=(40, 28, 18), width=3)
    d.ellipse(box(cx - r * 0.75, cy - r * 0.75, cx + r * 0.75, cy + r * 0.75), fill=(14, 12, 10))


def rope(d, cx, cy, r=0.38):
    d.line([(p(cx + r * 0.7), p(cy + r * 0.5)), (p(cx + r * 1.6), p(cy + r * 1.3))], fill=(170, 140, 92), width=10)
    for k in range(3):
        rr = r * (1 - k * 0.3)
        d.ellipse(box(cx - rr, cy - rr, cx + rr, cy + rr), outline=(120, 94, 58), width=12)
        d.ellipse(box(cx - rr, cy - rr, cx + rr, cy + rr), outline=(186, 156, 104), width=6)


def sack(d, cx, cy):
    d.ellipse(box(cx - 0.33, cy - 0.24, cx + 0.33, cy + 0.24), fill=jit(CLOTH, 12), outline=(100, 86, 60), width=3)


def ladder(d, x0, y0, x1, y1):
    for xx in (x0, x1 - 0.15):
        d.rectangle(box(xx, y0, xx + 0.15, y1), fill=OAK, outline=(20, 12, 6), width=2)
    t = y0 + 0.15
    while t < y1:
        d.rectangle(box(x0, t, x1, t + 0.09), fill=OAK, outline=(20, 12, 6))
        t += 0.3


def ladder_h(d, x0, y0, x1, y1):
    d.rectangle(box(x0, y0, x1, y0 + 0.1), fill=TIMBER)
    d.rectangle(box(x0, y1 - 0.1, x1, y1), fill=TIMBER)
    t = x0 + 0.15
    while t < x1:
        d.rectangle(box(t, y0, t + 0.06, y1), fill=TIMBER)
        t += 0.3


def sawhorse(d, cx, cy):
    d.rectangle(box(cx - 0.1, cy - 0.45, cx + 0.1, cy + 0.45), fill=TIMBER, outline=dark(TIMBER, 0.5))
    for sy in (-0.45, 0.45):
        d.line([(p(cx - 0.25), p(cy + sy)), (p(cx + 0.25), p(cy + sy))], fill=dark(TIMBER, 0.6), width=4)


def hearth(d, x0, y0, x1, y1):
    d.rectangle(box(x0, y0, x1, y1), fill=STONE_HI, outline=STONE, width=4)
    d.rectangle(box(x0 + 0.35, y0 + 0.1, x1 - 0.35, y1 - 0.25), fill=(40, 24, 16))
    d.ellipse(box(x0 + 0.7, y0 + 0.25, x1 - 0.7, y1 - 0.35), fill=(220, 120, 40))
    d.ellipse(box(x0 + 0.95, y0 + 0.35, x1 - 0.95, y1 - 0.45), fill=(250, 200, 90))


def trapdoor(d, x0, y0, x1, y1):
    d.rectangle(box(x0, y0, x1, y1), fill=OAK, outline=(30, 20, 12), width=5)
    t = x0 + 0.2
    while t < x1 - 0.05:
        d.line([(p(t), p(y0)), (p(t), p(y1))], fill=(50, 32, 18), width=3)
        t += 0.2
    for yy in (y0 + 0.25, y1 - 0.25):
        d.rectangle(box(x0 + 0.05, yy - 0.04, x1 - 0.05, yy + 0.04), fill=IRON)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    d.ellipse(box(cx - 0.12, cy - 0.12, cx + 0.12, cy + 0.12), outline=(150, 150, 150), width=4)


def chest(d, x0, y0, x1, y1):
    d.rectangle(box(x0, y0, x1, y1), fill=(96, 62, 34), outline=(20, 16, 12), width=4)
    for xx in (x0 + 0.12, x1 - 0.12):
        d.rectangle(box(xx - 0.04, y0, xx + 0.04, y1), fill=IRON)
    d.rectangle(box((x0 + x1) / 2 - 0.06, y1 - 0.14, (x0 + x1) / 2 + 0.06, y1), fill=(180, 160, 90))


def joists(d, x0, y0, x1, y1):
    d.rectangle(box(x0, y0, x1, y1), fill=(30, 18, 10))
    d.ellipse(box(x0 + 0.3, y0 + 0.2, x1 - 0.3, y1 - 0.2), fill=(70, 38, 18))  # alttaki ocağın ışığı
    t = x0 + 0.05
    while t < x1:
        d.rectangle(box(t, y0 - 0.1, t + 0.2, y1 + 0.1), fill=WOOD_NEW, outline=dark(WOOD_NEW, 0.45), width=2)
        t += 0.75
    for yy in (y0, y1):
        d.line([(p(x0), p(yy)), (p(x1), p(yy))], fill=dark(WOOD_NEW, 0.4), width=3)


def railing(d, x0, y0, x1, y1):
    d.rectangle(box(x0, y0, x1, y1), fill=(176, 136, 88), outline=(40, 26, 14), width=3)
    horiz = (x1 - x0) > (y1 - y0)
    t = x0 if horiz else y0
    while t <= (x1 if horiz else y1):
        c = (t, (y0 + y1) / 2) if horiz else ((x0 + x1) / 2, t)
        d.rectangle(box(c[0] - 0.12, c[1] - 0.12, c[0] + 0.12, c[1] + 0.12), fill=(70, 46, 26), outline=(30, 20, 10))
        t += 0.8


def scaffold_posts(d):
    for x in (1.15, 2.7):  # her sırada çapraz bağ
        for y in range(1, 12, 2):
            d.line([(p(x + 0.08), p(y + 0.08)), (p(x + 0.08), p(y + 2.08))], fill=TIMBER, width=6)
            d.line([(p(x + 0.08), p(y + 0.08)), (p(1.95), p(y + 1.08)), (p(x + 0.08), p(y + 2.08))], fill=dark(TIMBER, 0.8), width=4)
    for y in range(1, 14, 2):
        for x in (1.15, 2.7):
            d.rectangle(box(x - 0.04, y - 0.04, x + 0.2, y + 0.2), fill=TIMBER, outline=(30, 20, 10), width=2)


# --- 3D havası: duvar ve eşyalar sağ alta yumuşak gölge düşürür (refs'teki blur yumuşatır) ---------
SHADE, OFF = (30, 22, 15), (0.12, 0.16)


def shadowed(fn, r_default=None):
    def wrap(d, *a, **k):
        ox, oy = OFF
        if r_default is None:  # (x0, y0, x1, y1)
            x0, y0, x1, y1 = a[:4]
            d.rectangle(box(x0 + ox, y0 + oy, x1 + ox, y1 + oy), fill=SHADE)
        else:                  # (cx, cy[, r])
            cx, cy = a[:2]
            r = a[2] if len(a) > 2 else k.get("r", r_default)
            d.ellipse(box(cx - r + ox, cy - r + oy, cx + r + ox, cy + r + oy), fill=SHADE)
        return fn(d, *a, **k)
    return wrap


for _n in ("stone_wall", "timber_wall", "partition", "stairs", "crate", "table", "shelf", "lumber", "chest",
           "hearth", "railing"):
    globals()[_n] = shadowed(globals()[_n])
barrel, tar, sack = shadowed(barrel, 0.37), shadowed(tar, 0.24), shadowed(sack, 0.3)


# --- katlar ----------------------------------------------------------------

def shell_stone(d, t=0.4):
    """Zemin kat ve kilerin taş kabuğu (x 3–13, y 1–13)."""
    h = t / 2
    stone_wall(d, 3 - h, 1 - h, 13 + h, 1 + h)
    stone_wall(d, 3 - h, 13 - h, 13 + h, 13 + h)
    stone_wall(d, 3 - h, 1 - h, 3 + h, 13 + h)
    stone_wall(d, 13 - h, 1 - h, 13 + h, 13 + h)


def ground() -> Image.Image:
    im = Image.new("RGB", (C * N, C * N), VOID)
    d = ImageDraw.Draw(im)
    cobbles(d, 0, 0, N, N)                       # ara sokak (x 1–3) ve teras sokağı (y 13+)
    roofs(d, 0, 0, 1, 12.8)
    roofs(d, 13.2, 0, N, 12.8)
    rough(d, 0, 0, N, 0.8, EARTH)                # arkada üst terasın istinat duvarı
    scaffold_posts(d)
    ladder(d, *LADDER)
    planks(d, 3, 1, 13, 13, WOOD_OLD)
    shell_stone(d)
    # sokak cephesi: kapı, iki yanında pencere, önünde basamaklar ve fıçılar
    d.rectangle(box(6, 12.8, 7, 13.2), fill=WOOD_OLD)
    door(d, 6.05, 12.8, 0, -1, 0.9)
    for x in (4, 8, 11):
        window(d, x, 12.88, x + 1, 13.12)
    window(d, 2.88, 10, 3.12, 11)  # sol duvarda ara sokağa bakan pencereler
    window(d, 2.88, 3.5, 3.12, 4.5)
    d.rectangle(box(5.6, 13.25, 7.4, 13.65), fill=STONE_HI, outline=STONE, width=3)
    d.rectangle(box(5.4, 13.65, 7.6, 14.05), fill=STONE_HI, outline=STONE, width=3)
    for c in ((4.3, 13.75), (8.4, 13.7), (9.15, 13.95)):
        barrel(d, *c, r=0.33)
    lumber(d, 10, 13.25, 12.6, 13.75)
    # ara bölmeler (yeni tahta)
    partition(d, 3.2, 7.92, 6, 8.08)
    partition(d, 8, 7.92, 12.8, 8.08)
    doorframe(d, 6, 8, 8, 8)
    partition(d, 9.92, 1.2, 10.08, 5.6)
    partition(d, 9.92, 6.6, 10.08, 10)
    partition(d, 9.92, 11, 10.08, 12.8)
    door(d, 10, 5.6, 1, 0, 0.9)                  # ocak salonu ↔ merdiven holü
    door(d, 10, 11, 1, 0, 0.9)                   # kâtip odası ↔ defter odası
    # kâtip odası
    table(d, 3.5, 11.4, 5.3, 12.3)
    chair(d, 4.4, 11.0)
    table(d, 7.7, 11.4, 9.5, 12.3)
    chair(d, 8.6, 11.0)
    papers(d, 3.35, 8.35, 4.35, 9.35)
    papers(d, 4.5, 8.35, 5.3, 9.05)
    papers(d, 8.4, 8.4, 9.4, 9.2)
    shelf(d, 3.25, 9.6, 3.65, 11.0)
    # defter odası: boş raflar, raf tahtaları
    shelf(d, 12.35, 8.4, 12.78, 12.6)
    shelf(d, 10.4, 8.25, 12.2, 8.6)
    lumber(d, 10.6, 9.6, 11.8, 11.5)
    sawhorse(d, 11.2, 12.2)
    # ocak salonu
    hearth(d, 5, 1.2, 8, 2.1)
    for i in range(4):
        d.rectangle(box(3.35 + i * 0.28, 1.3, 3.6 + i * 0.28, 2.3), fill=jit((110, 74, 42), 14), outline=(50, 32, 18))
    table(d, 4.5, 3.8, 8.5, 4.8)
    table(d, 4.6, 3.3, 8.4, 3.6, (100, 68, 40))
    table(d, 4.6, 5.0, 8.4, 5.3, (100, 68, 40))
    trapdoor(d, *TRAP)
    for c in ((3.7, 6.9), (4.3, 7.3), (3.7, 7.55)):
        sack(d, *c)
    # merdiven holü
    stairs(d, *STAIR, WOOD_OLD)
    lumber(d, 10.3, 1.3, 11.5, 2.6)
    tar(d, 10.5, 7.3)
    return im


def upper() -> Image.Image:
    im = Image.new("RGB", (C * N, C * N), VOID)
    d = ImageDraw.Draw(im)
    cobbles(d, 0, 0, N, N, 0.45)                 # sokak aşağıda kalıyor: karanlık
    roofs(d, 0, 0, 1, 12.8)
    roofs(d, 13.2, 0, N, 12.8)
    rough(d, 0, 0, N, 0.8, EARTH)
    # iskele: ara sokak boyunca kalas platform, önde sokaktan çıkan merdivenin ucu
    planks(d, 1.1, 1, 2.9, 13, (150, 116, 76), w=0.3)
    scaffold_posts(d)
    ladder(d, *LADDER)
    planks(d, 3, 1, 13, 13, WOOD_NEW)
    joists(d, *JOISTS)
    # kabuk: arka ve sağ duvar eski taş; sol duvar yeni ahşap çatkı; ön duvar yok, korkuluk
    stone_wall(d, 2.8, 0.8, 13.2, 1.2)
    stone_wall(d, 12.8, 0.8, 13.2, 13.2)
    timber_wall(d, 2.85, 1.2, 3.15, 4)
    timber_wall(d, 2.85, 5, 3.15, 10)
    timber_wall(d, 2.85, 11, 3.15, 13)
    for y in (4, 10):  # iskeleden giriş: camı takılmamış pencere boşlukları
        d.rectangle(box(2.85, y, 3.15, y + 1), fill=WOOD_NEW)
        doorframe(d, 3, y, 3, y + 1)
    d.rectangle(box(2.85, 12.85, 12.8, 13.05), fill=STONE)  # eski ön duvarın dibi
    railing(d, 3, 13.05, 12.8, 13.2)
    # merdiven boşluğu: zemin kattaki merdivenin üst ucu, korkuluklu
    stairs(d, *STAIR, WOOD_OLD, down_north=False)
    railing(d, 11.75, 3, 11.9, 7.1)
    railing(d, 11.75, 7, 12.8, 7.15)
    # ara bölmeler: yalnız dikmeler
    studs(d, 3.2, 7.9, 6, 8.1)
    studs(d, 7, 7.9, 10.5, 8.1)
    studs(d, 11.5, 7.9, 12.8, 8.1)
    studs(d, 9.9, 1.2, 10.1, 5)
    studs(d, 9.9, 6, 10.1, 7.9)
    studs(d, 7.9, 8.1, 8.1, 10.5)
    # arka oda: kereste istifi, katran, halat, uyuyan bekçinin yatağı
    lumber(d, 3.4, 1.3, 5.6, 2.3)
    lumber(d, 5.9, 1.3, 7.9, 2.4)
    lumber(d, 8.2, 1.3, 9.7, 2.2)
    for c in ((3.7, 3.0), (4.3, 2.9), (3.9, 3.6)):
        tar(d, *c)
    rope(d, 9.2, 3.2)
    rope(d, 9.3, 4.2, 0.3)
    d.rectangle(box(3.4, 6.1, 4.4, 7.7), fill=(120, 60, 50), outline=(60, 30, 24), width=3)
    d.rectangle(box(3.45, 6.15, 4.35, 6.5), fill=CLOTH)
    # ön oda: tezgâh, yerde el merdiveni, kiremit yığını, talaş
    sawhorse(d, 4.2, 10.4)
    sawhorse(d, 6.2, 10.4)
    d.rectangle(box(3.8, 10.25, 6.6, 10.55), fill=WOOD_NEW, outline=dark(WOOD_NEW, 0.5), width=2)
    ladder_h(d, 8.6, 11.7, 12.4, 12.25)
    for i in range(3):
        for j in range(3):
            d.rectangle(box(8.6 + i * 0.4, 8.4 + j * 0.33, 8.95 + i * 0.4, 8.7 + j * 0.33), fill=(150, 82, 56), outline=(90, 46, 30))
    barrel(d, 9.0, 10.3, 0.25)
    shelf(d, 12.3, 9, 12.75, 11.5)
    # sahanlık
    tar(d, 10.5, 1.6)
    lumber(d, 10.3, 2.1, 11.6, 2.7)
    return im


def cellar() -> Image.Image:
    im = Image.new("RGB", (C * N, C * N), VOID)
    d = ImageDraw.Draw(im)
    rough(d, 0, 0, N, N, EARTH, 2500)
    flags(d, 3, 1, 13, 8)
    t = 0.25
    stone_wall(d, 3 - t, 1 - t, 13 + t, 1 + t)
    stone_wall(d, 3 - t, 8 - t, 13 + t, 8 + t)
    stone_wall(d, 3 - t, 1 - t, 3 + t, 8 + t)
    stone_wall(d, 13 - t, 1 - t, 13 + t, 8 + t)
    stone_wall(d, 9.8, 1, 10.2, 2)        # x=10 iç duvar, iki kemerli geçit
    stone_wall(d, 9.8, 3, 10.2, 6)
    stone_wall(d, 9.8, 7, 10.2, 8)
    stone_wall(d, 10, 4.3, 13, 4.7)
    for y in (2.7, 5.2):  # tonozu taşıyan iki kare direk, gölgeli
        d.rectangle(box(5.3, y + 0.1, 6.3, y + 1.1), fill=(20, 18, 16))
        d.rectangle(box(5.2, y, 6.2, y + 1), fill=STONE_HI, outline=(30, 28, 26), width=6)
        d.rectangle(box(5.4, y + 0.2, 6.0, y + 0.8), fill=(130, 124, 116), outline=STONE, width=3)
    stairs(d, *CELLAR_STAIR, WOOD_OLD, down_north=True)
    for y in (1.6, 2.4, 3.2, 4.0, 4.8, 5.6, 6.4, 7.25):
        barrel(d, 3.65, y)
    barrel(d, 4.45, 1.6)
    barrel(d, 4.45, 2.4)
    for x in (5.4, 6.1, 6.8, 7.5):
        sack(d, x, 1.55)
    sack(d, 7.1, 2.1)
    shelf(d, 4.6, 7.35, 7.8, 7.72)
    for x in (4.85, 5.35, 5.85, 6.35, 6.85, 7.35):
        d.ellipse(box(x - 0.15, 7.38, x + 0.15, 7.68), fill=(160, 90, 56), outline=(80, 44, 26), width=2)
    # arka oda: fıçıların arkasında sandık
    chest(d, 11.95, 1.2, 12.85, 1.8)
    for c in ((11.5, 1.6), (11.5, 2.4), (12.4, 2.45), (12.4, 3.3), (11.5, 3.3)):
        barrel(d, *c)
    # yan oda: odun, kömür, kırık eşya
    lumber(d, 10.4, 7.15, 12.8, 7.75)
    for _ in range(60):  # kömür yığını
        x, y = rng.uniform(11.7, 12.6), rng.uniform(5.1, 6.1)
        d.ellipse(box(x - 0.1, y - 0.08, x + 0.1, y + 0.08), fill=jit((44, 42, 42), 10), outline=(16, 16, 16))
    crate(d, 10.4, 4.95, 11.2, 5.75)
    chair(d, 11.1, 6.4, "s")
    return im


FLOORS = {"Zemin": ground, "Üst": upper, "Kiler": cellar}

STYLE = ("Hand-painted top-down fantasy battle map, camera pointing straight down, no perspective, the roof removed, "
         "semi-realistic painted textures of real wood grain, stone and iron, warm muted browns and greys, "
         "every object seen from directly above, with a gentle 3D look: walls and furniture have clear height and "
         "cast soft shadows to the lower right, gentle ambient occlusion in the corners, rich tactile textures, "
         "no grid, no text, no people")
PROMPTS = {
    "Zemin": "The ground floor of an old narrow stone townhouse being fitted out as a guild office, worn oak floorboards, "
             "thick grey stone outer walls, new pale wooden partition walls, two clerk's writing desks, crates of papers, "
             "empty new shelves, a stone hearth with a fire, a long table with benches, a square wooden trapdoor, "
             "a wooden staircase, sawdust, a cobbled street at the bottom with stone steps and barrels, a narrow cobbled "
             "alley on the left with scaffold posts and a ladder. ",
    "Üst": "The unfinished upper floor of a townhouse under construction, almost everything fresh pale timber: new "
           "floorboards, a timber-framed left wall, bare wooden stud partitions with no boards yet, a section of floor "
           "not yet laid where the joists show over a dark drop, stacks of fresh lumber, tar buckets, coils of rope, "
           "sawhorses, a ladder lying on the floor, wood shavings, a staircase opening with a rough railing, "
           "a temporary wooden railing along the open front edge, wooden scaffolding planks along the outside of the "
           "left wall, the street far below in shadow. ",
    "Kiler": "A stone-vaulted cellar dug into dark earth, worn flagstone floor, thick stone walls with two arched openings "
             "into small side rooms, two square stone pillars, a narrow wooden stair coming down from a trapdoor, "
             "oak barrels along the walls, grain sacks, a shelf of clay jars, a pile of firewood, a heap of coal, "
             "and in the far corner of the back room a small iron-bound chest hidden behind barrels. ",
}
DENOISE = 0.45  # yorum: biraz daha 3B ve gerçekçi; 0.45'te eşyalar başka şeye dönüşüyor (kapak→soba, talaş→ateş), 0.55'te düzen kayıyor


def refs() -> None:
    WORK.mkdir(exist_ok=True)
    jobs = []
    for i, (name, fn) in enumerate(FLOORS.items()):
        path = WORK / f"ref_{name}.png"
        im = fn()
        noise = Image.effect_noise(im.size, 40).convert("RGB")
        Image.blend(im, noise, 0.07).filter(ImageFilter.GaussianBlur(0.8)).save(path)
        jobs.append({"uuid": f"Askeri-Hukuk-Odası-{name}", "category": "battlemap",
                     "name": f"Askeri-Hukuk-Odası-{name}", "prompt": PROMPTS[name] + STYLE,
                     "seed": 1900 + i, "ref": str(path), "denoise": DENOISE})
    (WORK / "art_jobs.jsonl").write_text(
        "".join(json.dumps(j, ensure_ascii=False) + "\n" for j in jobs), encoding="utf-8")
    print("refs:", ", ".join(FLOORS))


# Birleşik harita (kare cinsinden; bütün ofsetler tam kare: uygulamanın ızgarası üç panelde de oturur)
CROP_FLOOR = (0, 0, 14, 16)
CROP_CELLAR = (1, 0, 14, 9)
W_CELLS, H_CELLS = 31, 28
PLACE = {"Zemin": (1, 1), "Üst": (16, 1), "Kiler": (9, 18)}
LABEL = {"Zemin": "ZEMİN KAT", "Üst": "ÜST KAT", "Kiler": "KİLER"}
# geçiş rozetleri: aynı harf = aynı geçit (kat koordinatında)
BADGES = {
    "Zemin": [("A", 11.35, 7.5), ("B", 9.15, 6.4), ("C", 0.5, 13.7)],
    "Üst": [("A", 11.3, 3.4), ("C", 0.5, 13.7)],
    "Kiler": [("B", 9.15, 6.4)],
}


def compose(src: Path, out: Path) -> None:
    font = ImageFont.truetype("/usr/share/fonts/truetype/liberation2/LiberationSerif-Bold.ttf", 46)
    bfont = ImageFont.truetype("/usr/share/fonts/truetype/liberation2/LiberationSerif-Bold.ttf", 34)
    canvas = Image.new("RGB", (W_CELLS * C, H_CELLS * C), (24, 20, 17))
    d = ImageDraw.Draw(canvas)
    for name in FLOORS:
        f = src / f"Askeri-Hukuk-Odası-{name}.webp"
        im = Image.open(f if f.exists() else src / f"ref_{name}.png").convert("RGB")  # önizleme: çizimin kendisi
        if im.size != (C * N, C * N):
            im = im.resize((C * N, C * N), Image.LANCZOS)
        if name == "Üst":  # aşağıdaki sokak: zemin katın boyanmış sokağı, karartılmış — iki kat aynı sokağı görür
            street = box(0, 13.35, N, N)
            im.paste(Image.eval(ground.crop(street), lambda v: int(v * 0.45)), street[:2])
        if name == "Zemin":
            ground = im
        if name == "Kiler":  # model sandığı her seed'de fıçıya çeviriyor; görevin hedefi, çizimden yapıştır
            chest_box = box(11.85, 1.1, 12.95, 1.95)
            im.paste(Image.open(WORK / "ref_Kiler.png").convert("RGB").crop(chest_box), chest_box[:2])
        crop = CROP_CELLAR if name == "Kiler" else CROP_FLOOR
        part = im.crop(box(*crop))
        bd = ImageDraw.Draw(part)
        for letter, bx, by in BADGES[name]:
            cx, cy = p(bx - crop[0]), p(by - crop[1])
            bd.ellipse((cx - 26, cy - 26, cx + 26, cy + 26), fill=(236, 226, 200), outline=(60, 20, 16), width=4)
            bd.text((cx, cy + 1), letter, font=bfont, fill=(110, 24, 18), anchor="mm")
        ox, oy = PLACE[name]
        canvas.paste(part, (p(ox), p(oy)))
        d.rectangle((p(ox) - 3, p(oy) - 3, p(ox) + part.width + 2, p(oy) + part.height + 2), outline=(120, 104, 80), width=3)
        d.text((p(ox) + part.width // 2, p(oy) - C // 2), LABEL[name], font=font, fill=(228, 214, 182), anchor="mm")
    canvas.save(out, "WEBP", quality=86, method=6)
    print(out, canvas.size)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "refs"
    if cmd == "refs":
        refs()
    elif cmd == "compose":
        src = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else WORK / "out"
        compose(src, WORK / ("Askeri-Hukuk-Odası.webp" if src != WORK else "onizleme.webp"))
    else:
        sys.exit(f"bilinmeyen komut: {cmd}")
