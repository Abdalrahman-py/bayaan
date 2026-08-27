"""Generate the Bayaan launcher icons: an open mushaf on a rehl (book stand).

Single-colour line art — gold ink on flat teal, matching lib/core/theme/app_colors.dart
(gold/tealEnd) and the gold-edged rounded tile from the splash screen. Everything is
drawn at 4x and downsampled for antialiasing.

Run from the flutter/ directory:  python3 tool/gen_icon.py
Needs Pillow only:  sudo apt install python3-pil   (or pip install pillow in a venv)

ponytail: hand-rolled instead of flutter_launcher_icons — that package needs a source
PNG anyway, and this keeps the icon regenerable as code. Switch to it if we ever need
adaptive/monochrome Android icons or macOS/Windows targets.
"""
import os
from PIL import Image, ImageDraw

TEAL_START = (0x0F, 0x76, 0x6E)
TEAL_END = (0x0C, 0x4A, 0x45)
GOLD = (0xC9, 0xA2, 0x27)
CREAM = (0xF0, 0xE4, 0xC3)

INK, BG = GOLD, TEAL_END
SS = 4  # supersample factor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def bez(p0, p1, p2, t):
    u = 1 - t
    return (u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
            u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1])


class Page:
    """One half of the open mushaf. u=0 at the spine, u=1 at the outer edge."""

    def __init__(self, cx, cy, w, h, sign):
        self.top = ((cx, cy - h * 0.40), (cx + sign * w * 0.45, cy - h * 0.55),
                    (cx + sign * w, cy - h * 0.18))
        self.bot = ((cx, cy + h * 0.34), (cx + sign * w * 0.45, cy + h * 0.20),
                    (cx + sign * w, cy + h * 0.52))

    def top_at(self, u):
        return bez(*self.top, u)

    def bot_at(self, u):
        return bez(*self.bot, u)

    def outline(self, steps=60):
        return ([self.top_at(i / steps) for i in range(steps + 1)] +
                [self.bot_at(i / steps) for i in range(steps, -1, -1)])

    def rule(self, frac, u0=0.16, u1=0.84, steps=24):
        """A line of text across the page at vertical fraction `frac`."""
        pts = []
        for i in range(steps + 1):
            u = u0 + (u1 - u0) * i / steps
            (tx, ty), (bx, by) = self.top_at(u), self.bot_at(u)
            pts.append((tx + (bx - tx) * frac, ty + (by - ty) * frac))
        return pts


def draw_icon(size, rounded=True):
    """rounded=False keeps corners square for iOS/maskable icons, which the platform
    masks itself and which must not carry alpha."""
    n = size * SS
    img = Image.new("RGBA", (n, n), BG + (255,))
    if rounded:
        mask = Image.new("L", (n, n), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, n - 1, n - 1],
                                              radius=int(n * 0.22), fill=255)
        img.putalpha(mask)

    d = ImageDraw.Draw(img)
    bw = int(n * 0.035)
    d.rounded_rectangle([bw // 2, bw // 2, n - 1 - bw // 2, n - 1 - bw // 2],
                        radius=int(n * 0.20), outline=INK + (255,), width=bw)

    # rehl: two crossing bars, drawn first so the book knocks them out
    bar = int(n * 0.047)
    for (x0, y0), (x1, y1) in (((0.29, 0.46), (0.665, 0.855)),
                               ((0.71, 0.46), (0.335, 0.855))):
        d.line([(x0 * n, y0 * n), (x1 * n, y1 * n)], fill=INK + (255,), width=bar)
    for x, y in ((0.29, 0.46), (0.71, 0.46), (0.335, 0.855), (0.665, 0.855)):
        d.ellipse([x * n - bar / 2, y * n - bar / 2,
                   x * n + bar / 2, y * n + bar / 2], fill=INK + (255,))

    cx, cy, w, h = n / 2, n * 0.43, n * 0.32, n * 0.37
    stroke = max(2, int(n * 0.022))
    for sign in (-1, 1):
        p = Page(cx, cy, w, h, sign)
        ring = p.outline()
        d.polygon(ring, fill=BG + (255,))  # hide the stand behind the pages
        d.line(ring + [ring[0]], fill=INK + (255,), width=stroke, joint="curve")
        for i in range(3):
            d.line(p.rule(0.30 + i * 0.22), fill=INK + (255,),
                   width=max(2, int(stroke * 0.62)), joint="curve")
    spine = Page(cx, cy, w, h, 1)
    d.line([spine.top_at(0), spine.bot_at(0)], fill=INK + (255,), width=int(stroke * 1.1))

    return img.resize((size, size), Image.LANCZOS)


def maskable(size, inset=0.72):
    """Full-bleed background with the tile shrunk into the maskable safe zone."""
    bg = Image.new("RGBA", (size, size), BG + (255,))
    inner = int(size * inset)
    bg.alpha_composite(draw_icon(inner), ((size - inner) // 2, (size - inner) // 2))
    return bg


def save(img, *path):
    out = os.path.join(ROOT, *path)
    if not os.path.isdir(os.path.dirname(out)):
        return
    img.save(out)
    print("wrote", os.path.relpath(out, ROOT))


def main():
    master = draw_icon(1024)
    ios_master = draw_icon(1024, rounded=False).convert("RGB")  # iOS rejects alpha

    for d, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                  ("xxhdpi", 144), ("xxxhdpi", 192)]:
        save(master.resize((px, px), Image.LANCZOS),
             "android", "app", "src", "main", "res", f"mipmap-{d}", "ic_launcher.png")

    ios = os.path.join("ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    for name in sorted(os.listdir(os.path.join(ROOT, ios))):
        if not name.endswith(".png"):
            continue
        base, mult = name[len("Icon-App-"):-4].split("@")
        px = round(float(base.split("x")[0]) * int(mult.rstrip("x")))
        save(ios_master.resize((px, px), Image.LANCZOS), ios, name)

    for px in (192, 512):
        save(master.resize((px, px), Image.LANCZOS), "web", "icons", f"Icon-{px}.png")
        save(maskable(px), "web", "icons", f"Icon-maskable-{px}.png")
    save(master.resize((16, 16), Image.LANCZOS), "web", "favicon.png")


if __name__ == "__main__":
    main()
