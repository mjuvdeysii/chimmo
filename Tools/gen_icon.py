#!/usr/bin/env python3
"""Generate 1024x1024 Daylight & Night-Lamp AppIcon PNGs for 咩哞 · Chimmo.

Composition follows the 1-3-5 Tonic Triad canon (docs/IP.md):
  - Center foreground: #1 Taono (terracotta resonance bell + asymmetric tuning-fork ears + bronze pearl)
  - Left behind:       #3 Plokko (coral roly-poly with horizontal acoustic paddle wings)
  - Right behind:      #5 Corllo (warm porcelain body with burnt-copper spiral horn ear)

Rendered at 2x supersampling (2048 -> 1024 Lanczos) using proper alpha-composited
matte studio lighting so edges and forms read crisply from 29pt to 1024pt.
"""

from __future__ import annotations

import math
import os
from PIL import Image, ImageDraw, ImageFilter

S = 2048  # 2x supersample


def hex_rgba(h: str, a: int = 255) -> tuple[int, int, int, int]:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def radial_glow(size: int, center: tuple[int, int], radius: int, color: tuple[int, int, int], max_alpha: int) -> Image.Image:
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    steps = 30
    cx, cy = center
    for i in range(steps, 0, -1):
        t = i / steps
        r = int(radius * t)
        a = int(max_alpha * ((1.0 - t) ** 1.9))
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*color, a))
    return layer


def composite_soft_shade(base: Image.Image, bbox: tuple[float, float, float, float], color: tuple[int, int, int, int], blur: float = 34) -> None:
    """Alpha-composite a soft matte studio highlight/shadow masked strictly to base alpha."""
    mask = base.split()[3]
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(overlay).ellipse(bbox, fill=color)
    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=blur))
    blended = Image.alpha_composite(base, overlay)
    base.paste(blended, (0, 0), mask)


def draw_eyes(draw: ImageDraw.ImageDraw, lx: float, rx: float, y: float, r: float) -> None:
    for cx in (lx, rx):
        draw.ellipse((cx - r, y - r, cx + r, y + r), fill=hex_rgba("#1C1D19"))
        hr = r * 0.28
        hx, hy = cx - r * 0.28, y - r * 0.30
        draw.ellipse((hx - hr, hy - hr, hx + hr, hy + hr), fill=(255, 255, 255, 235))


def draw_rounded_rot_rect(base: Image.Image, center: tuple[float, float], size: tuple[float, float], radius: float, angle_deg: float, fill: tuple[int, int, int, int], outline: tuple[int, int, int, int] | None = None, width: int = 0) -> None:
    w, h = int(size[0]), int(size[1])
    pad = int(max(w, h) * 0.6) + 24
    tmp = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    d.rounded_rectangle((pad, pad, pad + w, pad + h), radius=radius, fill=fill, outline=outline, width=width)
    rot = tmp.rotate(angle_deg, resample=Image.Resampling.BICUBIC, expand=True)
    x = int(center[0] - rot.width / 2)
    y = int(center[1] - rot.height / 2)
    base.alpha_composite(rot, (x, y))


def render_icon(night: bool, out_path: str) -> None:
    bg_hex = "#1B2245" if night else "#F7F3EA"
    img = Image.new("RGBA", (S, S), hex_rgba(bg_hex))

    if night:
        img.alpha_composite(radial_glow(S, (1024, 1280), 960, (255, 184, 77), 82))
    else:
        img.alpha_composite(radial_glow(S, (760, 420), 1180, (255, 251, 240), 115))

    # Soft grounded shadow under the 1-3-5 triad
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((280, 1520, 1780, 1715), fill=(18, 14, 24, 85 if night else 38))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=44))
    img.alpha_composite(shadow)

    # Subtle Home Horizon line
    arc_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    arc_col = hex_rgba("#4FD8CB", 75) if night else hex_rgba("#0B7D74", 60)
    ImageDraw.Draw(arc_layer).line((190, 1495, 1858, 1495), fill=arc_col, width=10)
    img.alpha_composite(arc_layer)

    # --- LEFT BEHIND: #3 Plokko (Coral roly-poly balance toy) ---
    plokko = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px, py = 505, 1270
    pd = ImageDraw.Draw(plokko)
    pd.ellipse((px - 165, py + 195, px + 165, py + 280), fill=hex_rgba("#3A2C2A"))
    wing_outline = hex_rgba("#FFC45A") if night else hex_rgba("#D9A438")
    draw_rounded_rot_rect(plokko, (px - 220, py + 12), (200, 114), 56, 12, hex_rgba("#CF5B68"), outline=wing_outline, width=12)
    draw_rounded_rot_rect(plokko, (px + 195, py + 18), (185, 110), 54, -10, hex_rgba("#CF5B68"), outline=wing_outline, width=12)
    pd = ImageDraw.Draw(plokko)
    pd.ellipse((px - 210, py - 210, px + 210, py + 210), fill=hex_rgba("#CF5B68"))
    composite_soft_shade(plokko, (px - 220, py - 230, px + 80, py + 70), hex_rgba("#EA8892", 90), blur=40)
    composite_soft_shade(plokko, (px - 80, py + 40, px + 240, py + 260), hex_rgba("#7A2632", 75), blur=46)
    pd = ImageDraw.Draw(plokko)
    pd.ellipse((px - 26, py - 150, px + 26, py - 98), fill=wing_outline)
    draw_eyes(pd, px - 64, px + 56, py - 10, 29)
    img.alpha_composite(plokko)

    # --- RIGHT BEHIND: #5 Corllo (Warm porcelain teardrop + burnt-copper spiral horn ear) ---
    corllo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cx, cy = 1545, 1215
    cd = ImageDraw.Draw(corllo)
    # Sculptural spiral horn ear
    cd.ellipse((cx + 75, cy - 285, cx + 365, cy + 5), fill=hex_rgba("#B85D3B"))
    cd.ellipse((cx + 122, cy - 238, cx + 318, cy - 42), fill=hex_rgba("#EFE7D8"))
    cd.ellipse((cx + 162, cy - 198, cx + 278, cy - 82), fill=hex_rgba("#B85D3B"))
    if night:
        corllo.alpha_composite(radial_glow(S, (cx + 220, cy - 140), 155, (255, 196, 90), 155))
        cd = ImageDraw.Draw(corllo)
        cd.ellipse((cx + 188, cy - 172, cx + 252, cy - 108), fill=hex_rgba("#FFC45A"))
    else:
        cd.ellipse((cx + 196, cy - 164, cx + 244, cy - 116), fill=hex_rgba("#D49A2A"))
    # Cocoa feet
    cd.ellipse((cx - 118, cy + 250, cx - 10, cy + 322), fill=hex_rgba("#4D2B22"))
    cd.ellipse((cx + 18, cy + 250, cx + 126, cy + 322), fill=hex_rgba("#4D2B22"))
    # Porcelain teardrop body
    cd.ellipse((cx - 205, cy - 230, cx + 205, cy + 285), fill=hex_rgba("#EFE7D8"), outline=hex_rgba("#B85D3B", 68), width=8)
    composite_soft_shade(corllo, (cx - 210, cy - 240, cx + 60, py - 20), hex_rgba("#FFFDF8", 115), blur=40)
    composite_soft_shade(corllo, (cx - 60, cy + 80, cx + 230, cy + 320), hex_rgba("#B59E84", 82), blur=46)
    cd = ImageDraw.Draw(corllo)
    draw_eyes(cd, cx - 72, cx + 42, cy - 12, 29)
    img.alpha_composite(corllo)

    # --- CENTER FOREGROUND: #1 Taono (Terracotta resonance bell — primary 29pt silhouette anchor) ---
    taono = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    tx, ty = 1024, 1140

    # Asymmetric tuning-fork ears
    draw_rounded_rot_rect(taono, (tx - 148, ty - 535), (138, 355), 69, 3, hex_rgba("#C4513A"))
    td = ImageDraw.Draw(taono)
    td.ellipse((tx - 224, ty - 745, tx - 78, ty - 599), fill=hex_rgba("#F2E6D0"))

    draw_rounded_rot_rect(taono, (tx + 162, ty - 505), (138, 340), 69, -13, hex_rgba("#C4513A"))
    td = ImageDraw.Draw(taono)
    td.ellipse((tx + 108, ty - 705, tx + 254, ty - 559), fill=hex_rgba("#F2E6D0"))

    # Roasted-tea feet
    td.ellipse((tx - 235, ty + 395, tx - 55, ty + 505), fill=hex_rgba("#4A261E"))
    td.ellipse((tx + 55, ty + 395, tx + 235, ty + 505), fill=hex_rgba("#4A261E"))

    # Smooth continuous inverted-bell silhouette (superellipse dome + gently flared soft bottom)
    bell = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bell)
    # Build smooth parametric bell contour
    pts = []
    for i in range(180):
        t = (i / 180.0) * 2.0 * math.pi
        # Superellipse with slight downward flare
        c, s = math.cos(t), math.sin(t)
        nx = math.copysign(abs(c) ** 0.86, c)
        ny = math.copysign(abs(s) ** 0.82, s)
        flare = 1.0 + max(0.0, ny) * 0.14
        x = tx + nx * 365 * flare
        y = (ty + 20) + ny * 430
        pts.append((x, y))
    bd.polygon(pts, fill=hex_rgba("#C4513A"))
    composite_soft_shade(bell, (tx - 380, ty - 450, tx + 130, ty + 120), hex_rgba("#E27A62", 96), blur=55)
    composite_soft_shade(bell, (tx - 160, ty + 180, tx + 440, ty + 540), hex_rgba("#762517", 88), blur=60)
    taono.alpha_composite(bell)
    td = ImageDraw.Draw(taono)

    # Glazed calm eyes
    draw_eyes(td, tx - 132, tx + 132, ty - 78, 46)

    # Recessed ceramic acoustic soundhole dimple + antique bronze / glowing pearl
    sx, sy = tx - 68, ty + 185
    # Outer chamfer shadow
    td.ellipse((sx - 108, sy - 108, sx + 108, sy + 108), fill=hex_rgba("#7D2E1E"))
    # Recessed inner kiln-cream cavity offset slightly down-right to read as concave recess
    td.ellipse((sx - 96, sy - 92, sx + 102, sy + 102), fill=hex_rgba("#E9D7BC"))
    # Soft inner top shadow inside soundhole
    cavity = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(cavity).ellipse((sx - 96, sy - 92, sx + 102, sy + 102), fill=hex_rgba("#E9D7BC"))
    composite_soft_shade(cavity, (sx - 120, sy - 125, sx + 70, sy + 35), hex_rgba("#8A4E33", 78), blur=26)
    taono.alpha_composite(cavity)
    td = ImageDraw.Draw(taono)

    if night:
        taono.alpha_composite(radial_glow(S, (sx + 4, sy + 6), 215, (255, 184, 77), 165))
        td = ImageDraw.Draw(taono)
        td.ellipse((sx - 50, sy - 48, sx + 58, sy + 60), fill=hex_rgba("#FFB84D"))
        td.ellipse((sx - 28, sy - 30, sx + 2, sy), fill=(255, 246, 224, 210))
    else:
        td.ellipse((sx - 48, sy - 46, sx + 56, sy + 58), fill=hex_rgba("#B87D24"))
        td.ellipse((sx - 44, sy - 42, sx + 48, sy + 50), fill=hex_rgba("#D99E32"))
        td.ellipse((sx - 26, sy - 28, sx + 2, sy), fill=(255, 245, 218, 175))

    img.alpha_composite(taono)

    final = img.convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    final.save(out_path, "PNG", optimize=True)
    print(f"Wrote {out_path} ({final.size})")


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    icon_dir = os.path.join(root, "Chimmo", "Resources", "Assets.xcassets", "AppIcon.appiconset")
    render_icon(False, os.path.join(icon_dir, "AppIcon-Light.png"))
    render_icon(True, os.path.join(icon_dir, "AppIcon-Dark.png"))
