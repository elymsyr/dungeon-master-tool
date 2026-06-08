#!/usr/bin/env python3
"""Interactive banner cropper — pick the crop yourself, ratio stays locked.

Opens each first-party banner in turn and shows a fixed-aspect (5:2) crop box
over it. You position/size the box; the ratio never changes. On save the box
is cropped from the ORIGINAL pixels, downscaled to <=1400px wide, and written
back in place as JPEG q88 (same output contract as optimize_banners.py).

    python3 tool/crop_banners_gui.py            # from flutter_app/, all banners
    python3 tool/crop_banners_gui.py open5e-vom.jpg open5e-toh.jpg

Controls (also shown on screen):
    drag            move the crop box
    wheel / +,-     zoom the box (ratio locked)
    arrow keys      nudge the box (Shift = bigger step)
    f               box = full largest 2:1 fit, centered
    s / Enter       save this crop, go to next
    n               skip without saving, go to next
    q / Esc         quit (current image unsaved)
"""
import glob
import os
import sys
import tkinter as tk

from PIL import Image, ImageTk

TARGET_RATIO = 5 / 2          # width / height (matches kBannerCoverAspect)
MAX_W = 1400
QUALITY = 100
VIEW_MAX = (1100, 760)        # max on-screen image size

BANNER_DIR = os.path.join(os.path.dirname(__file__), "..",
                          "assets", "first_party", "banners")


class Cropper:
    def __init__(self, root, paths):
        self.root = root
        self.paths = paths
        self.idx = 0

        self.canvas = tk.Canvas(root, highlightthickness=0, bg="#101014")
        self.canvas.pack(fill="both", expand=True)
        self.info = tk.Label(root, anchor="w", bg="#101014", fg="#cfcfd6",
                             font=("monospace", 11), padx=8, pady=4)
        self.info.pack(fill="x")

        self.canvas.bind("<ButtonPress-1>", self._press)
        self.canvas.bind("<B1-Motion>", self._drag)
        self.canvas.bind("<MouseWheel>", self._wheel)        # win/mac
        self.canvas.bind("<Button-4>", lambda e: self._zoom(1 / 1.05))  # x11
        self.canvas.bind("<Button-5>", lambda e: self._zoom(1.05))
        root.bind("<Key>", self._key)

        self._load()

    # ---- per-image state -------------------------------------------------
    def _load(self):
        if self.idx >= len(self.paths):
            self.root.destroy()
            return
        self.path = self.paths[self.idx]
        im = Image.open(self.path)
        self.orig = im.convert("RGB") if im.mode != "RGB" else im
        self.W, self.H = self.orig.size

        # display scale (fit within VIEW_MAX, never upscale past 1x)
        self.scale = min(VIEW_MAX[0] / self.W, VIEW_MAX[1] / self.H, 1.0)
        self.dw, self.dh = round(self.W * self.scale), round(self.H * self.scale)
        self.tkimg = ImageTk.PhotoImage(
            self.orig.resize((self.dw, self.dh), Image.LANCZOS))
        self.canvas.config(width=self.dw, height=self.dh)

        self._reset_box()
        self._drag_anchor = None
        self._redraw()

    def _reset_box(self):
        # largest TARGET_RATIO box that fits, centered (in ORIGINAL px)
        bw = min(self.W, self.H * TARGET_RATIO)
        bh = bw / TARGET_RATIO
        self.bx = (self.W - bw) / 2
        self.by = (self.H - bh) / 2
        self.bw, self.bh = bw, bh

    # ---- geometry helpers ------------------------------------------------
    def _clamp(self):
        self.bw = max(40, min(self.bw, self.W, self.H * TARGET_RATIO))
        self.bh = self.bw / TARGET_RATIO
        self.bx = max(0, min(self.bx, self.W - self.bw))
        self.by = max(0, min(self.by, self.H - self.bh))

    def _zoom(self, factor):
        cx, cy = self.bx + self.bw / 2, self.by + self.bh / 2
        self.bw *= factor
        self._clamp()
        self.bx, self.by = cx - self.bw / 2, cy - self.bh / 2
        self._clamp()
        self._redraw()

    # ---- events ----------------------------------------------------------
    def _press(self, e):
        self._drag_anchor = (e.x, e.y, self.bx, self.by)

    def _drag(self, e):
        if not self._drag_anchor:
            return
        ax, ay, bx0, by0 = self._drag_anchor
        self.bx = bx0 + (e.x - ax) / self.scale
        self.by = by0 + (e.y - ay) / self.scale
        self._clamp()
        self._redraw()

    def _wheel(self, e):
        self._zoom(1 / 1.05 if e.delta > 0 else 1.05)

    def _key(self, e):
        k = e.keysym
        step = 40 if e.state & 0x1 else 10   # Shift = bigger
        if k in ("s", "Return"):
            self._save()
            self.idx += 1
            self._load()
        elif k == "n":
            self.idx += 1
            self._load()
        elif k in ("q", "Escape"):
            self.root.destroy()
        elif k == "f":
            self._reset_box()
            self._redraw()
        elif k in ("plus", "equal"):
            self._zoom(1 / 1.05)
        elif k == "minus":
            self._zoom(1.05)
        elif k == "Left":
            self.bx -= step; self._clamp(); self._redraw()
        elif k == "Right":
            self.bx += step; self._clamp(); self._redraw()
        elif k == "Up":
            self.by -= step; self._clamp(); self._redraw()
        elif k == "Down":
            self.by += step; self._clamp(); self._redraw()

    # ---- render ----------------------------------------------------------
    def _redraw(self):
        c = self.canvas
        c.delete("all")
        c.create_image(0, 0, anchor="nw", image=self.tkimg)
        x0, y0 = self.bx * self.scale, self.by * self.scale
        x1 = (self.bx + self.bw) * self.scale
        y1 = (self.by + self.bh) * self.scale
        # dim outside the box
        for rx0, ry0, rx1, ry1 in (
            (0, 0, self.dw, y0), (0, y1, self.dw, self.dh),
            (0, y0, x0, y1), (x1, y0, self.dw, y1),
        ):
            c.create_rectangle(rx0, ry0, rx1, ry1, fill="#000000",
                               stipple="gray50", outline="")
        c.create_rectangle(x0, y0, x1, y1, outline="#5ad6ff", width=2)
        name = os.path.basename(self.path)
        out_w = round(min(self.bw, MAX_W))
        self.info.config(
            text=f"[{self.idx + 1}/{len(self.paths)}] {name}   "
                 f"src {self.W}x{self.H}  crop {round(self.bw)}x{round(self.bh)}"
                 f" -> out {out_w}x{round(out_w / TARGET_RATIO)}   "
                 f"| drag=move  wheel/+,-=zoom  arrows=nudge  f=fit  "
                 f"s=save  n=skip  q=quit")

    # ---- save ------------------------------------------------------------
    def _save(self):
        left, top = round(self.bx), round(self.by)
        right, bottom = round(self.bx + self.bw), round(self.by + self.bh)
        im = self.orig.crop((left, top, right, bottom))
        if im.width > MAX_W:
            im = im.resize((MAX_W, round(MAX_W / TARGET_RATIO)), Image.LANCZOS)
        im.save(self.path, "JPEG", quality=QUALITY, optimize=True,
                progressive=True)
        print(f"saved {os.path.basename(self.path)}  {im.width}x{im.height}")


def main():
    args = sys.argv[1:]
    if args:
        paths = [a if os.path.isabs(a) else os.path.join(BANNER_DIR, a)
                 for a in args]
    else:
        paths = sorted(glob.glob(os.path.join(BANNER_DIR, "*.jpg")))
    paths = [p for p in paths if os.path.exists(p)]
    if not paths:
        print("no banners found", file=sys.stderr)
        sys.exit(1)
    root = tk.Tk()
    root.title("banner cropper (5:2 locked)")
    Cropper(root, paths)
    root.mainloop()


if __name__ == "__main__":
    main()
