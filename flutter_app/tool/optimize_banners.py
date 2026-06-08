#!/usr/bin/env python3
"""Normalize first-party catalog banners (one-off maintenance tool).

Banners render at 220px tall, BoxFit.cover, in ~500-720px wide cards
(cacheWidth 1200). They should be wide ("banner shaped"), not huge, and not
carry stray EXIF rotation or alpha. This script, in place:

  * honors then strips EXIF orientation (some are phone screenshots),
  * flattens any alpha onto black (one .jpg is actually a PNG with RGBA),
  * center-crops to EXACTLY TARGET_RATIO (3:2) whenever the aspect deviates
    by more than 0.005 (so every banner ends up the same shape; cards display
    them at one fixed height with BoxFit.cover and no edge-crop),
  * downscales to <=1400px wide (never upscales),
  * re-encodes JPEG q88 progressive+optimized when anything changed or the
    file is oversized (>300KB); otherwise leaves the file byte-for-byte.

Quality is preserved: q88 is visually near-lossless and we never upscale.

    python3 tool/optimize_banners.py            # from flutter_app/
"""
import glob
import os
import sys

from PIL import Image, ImageOps

TARGET_RATIO = 1.5   # 3:2 banner shape
RATIO_EPS = 0.005    # crop to exact ratio when |ratio - TARGET_RATIO| exceeds this
MAX_W = 1400
QUALITY = 88
OVERSIZED = 300 * 1024

BANNER_DIR = os.path.join(os.path.dirname(__file__), "..",
                          "assets", "first_party", "banners")


def has_exif_orientation(im):
    try:
        exif = im.getexif()
        return exif.get(0x0112, 1) not in (1, None)
    except Exception:
        return False


def process(path):
    name = os.path.basename(path)
    before = os.path.getsize(path)
    with Image.open(path) as im:
        orient = has_exif_orientation(im)
        im = ImageOps.exif_transpose(im)          # apply rotation, drops tag
        w, h = im.size
        mode = im.mode
        ratio = w / h

        need_mode = mode != "RGB"
        # crop to exactly 2:1 whenever the aspect deviates past the epsilon
        cw, ch = w, h
        if abs(ratio - TARGET_RATIO) > RATIO_EPS:
            if ratio < TARGET_RATIO:               # too tall -> trim top/bottom
                ch = round(w / TARGET_RATIO)
            else:                                  # too wide -> trim sides
                cw = round(h * TARGET_RATIO)
        need_crop = (cw, ch) != (w, h)
        # downscale after crop (never upscale)
        scale = MAX_W / cw if cw > MAX_W else 1.0
        need_scale = scale < 1.0
        oversized = before > OVERSIZED

        if not (need_mode or need_crop or need_scale or oversized or orient):
            return name, before, before, "skip"

        if need_mode:
            if im.mode in ("RGBA", "LA", "P"):
                bg = Image.new("RGB", im.size, (0, 0, 0))
                im = im.convert("RGBA")
                bg.paste(im, mask=im.split()[-1])
                im = bg
            else:
                im = im.convert("RGB")

        if need_crop:
            left = (w - cw) // 2
            top = (h - ch) // 2
            im = im.crop((left, top, left + cw, top + ch))

        if need_scale:
            im = im.resize((MAX_W, round(ch * scale)), Image.LANCZOS)

        actions = []
        if orient:
            actions.append("rot-strip")
        if need_mode:
            actions.append(f"{mode}->RGB")
        if need_crop:
            actions.append(f"crop->{im.size[0]}x{im.size[1]}")
        if need_scale:
            actions.append(f"scale w{MAX_W}")
        if oversized and not (need_crop or need_scale):
            actions.append("re-encode")
        im.save(path, "JPEG", quality=QUALITY, optimize=True,
                progressive=True)

    after = os.path.getsize(path)
    return name, before, after, ",".join(actions)


def main():
    files = sorted(glob.glob(os.path.join(BANNER_DIR, "*.jpg")))
    if not files:
        print("no banners found", file=sys.stderr)
        sys.exit(1)
    print(f"{'file':<34}{'KB before':>10}{'KB after':>10}  action")
    tb = ta = 0
    for f in files:
        name, b, a, act = process(f)
        tb += b
        ta += a
        print(f"{name:<34}{b // 1024:>10}{a // 1024:>10}  {act}")
    print(f"{'TOTAL':<34}{tb // 1024:>10}{ta // 1024:>10}  "
          f"saved {(tb - ta) // 1024} KB")


if __name__ == "__main__":
    main()
