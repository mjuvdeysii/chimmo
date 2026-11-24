#!/usr/bin/env python3
"""Deterministic flat-cartoon Kids' Book Design 1-3-5 AppIcon generator for 咩哞 · Chimmo.

Generates Light, Dark, and Tinted 1024x1024 opaque PNGs following docs/IP.md:
- 1 Taono (center-front coral bell with asymmetrical ears & chest pearl)
- 3 Plokko (left-back berry-pink winged tumbler)
- 5 Corllo (right-back sky-blue teardrop with right spiral shell ear)
- Flat cutout hills, paper sun/moon motifs, crisp comic ink strokes, ZERO gradients/blurry shadows.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile

CHROME_BIN = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def build_svg(variant: str) -> str:
    if variant == "light":
        bg = "#F4EDE0"
        outline = "#231B15"
        hill_back = "#CBE8D9"
        hill_front = "#B2DCC8"
        hill_ridge = "#231B15"
        sun_fill = "#FFE49E"
        ray_col = "#FFB94E"
        cloud_fill = "#FFFDF7"
        plokko_fill = "#E64980"
        plokko_foot = "#861942"
        corllo_fill = "#228BE6"
        corllo_ear = "#0F4C8A"
        corllo_core = "#FFE49E"
        taono_fill = "#F25563"
        taono_foot = "#8F1D28"
        cream = "#FFFDF7"
        pearl = "#FFB94E"
        eye = "#231B15"
        eye_hl = "#FFFDF7"
        ground_shadow = "rgba(35, 27, 21, 0.18)"
        sky_svg = f"""
          <g id="sun">
            <line x1="785" y1="88" x2="785" y2="56" stroke="{ray_col}" stroke-width="14" stroke-linecap="round"/>
            <line x1="852" y1="112" x2="875" y2="89" stroke="{ray_col}" stroke-width="14" stroke-linecap="round"/>
            <line x1="882" y1="178" x2="914" y2="178" stroke="{ray_col}" stroke-width="14" stroke-linecap="round"/>
            <line x1="718" y1="112" x2="695" y2="89" stroke="{ray_col}" stroke-width="14" stroke-linecap="round"/>
            <circle cx="785" cy="178" r="62" fill="{sun_fill}" stroke="{outline}" stroke-width="12"/>
          </g>
          <path d="M135 235 L292 235 Q324 235 324 202 Q324 172 292 170 Q276 122 222 126 Q170 130 158 172 Q122 176 122 206 Q122 235 135 235 Z"
                fill="{cloud_fill}" stroke="{outline}" stroke-width="11" stroke-linejoin="round"/>
        """
    elif variant == "dark":
        bg = "#131B3D"
        outline = "#070B1A"
        hill_back = "#1A2756"
        hill_front = "#233570"
        hill_ridge = "#FFB94E"
        plokko_fill = "#F25A90"
        plokko_foot = "#861942"
        corllo_fill = "#3899EE"
        corllo_ear = "#0F4C8A"
        corllo_core = "#FFB94E"
        taono_fill = "#F55D6B"
        taono_foot = "#8F1D28"
        cream = "#FFFDF7"
        pearl = "#FFB94E"
        eye = "#090C1C"
        eye_hl = "#FFFDF7"
        ground_shadow = "rgba(5, 8, 22, 0.55)"
        sky_svg = """
          <path d="M812 110 C735 128 735 236 812 252 C776 226 776 138 812 110 Z"
                fill="#FFB94E" stroke="#FFE49E" stroke-width="8" stroke-linejoin="round"/>
          <path d="M210 132 L222 162 L252 174 L222 186 L210 216 L198 186 L168 174 L198 162 Z"
                fill="#FFE49E"/>
          <circle cx="315" cy="142" r="10" fill="#FFB94E"/>
          <circle cx="670" cy="158" r="9" fill="#5CB3FF"/>
        """
    else:  # tinted monochrome high-contrast iOS template
        bg = "#0C0C0E"
        outline = "#0C0C0E"
        hill_back = "#2A2A30"
        hill_front = "#3E3E46"
        hill_ridge = "#9E9EA8"
        plokko_fill = "#8E8E98"
        plokko_foot = "#5A5A62"
        corllo_fill = "#AEAEB8"
        corllo_ear = "#64646E"
        corllo_core = "#F2F2F7"
        taono_fill = "#F5F5F7"
        taono_foot = "#707078"
        cream = "#D8D8E0"
        pearl = "#3A3A42"
        eye = "#0C0C0E"
        eye_hl = "#F5F5F7"
        ground_shadow = "rgba(0, 0, 0, 0.42)"
        sky_svg = """
          <path d="M812 110 C735 128 735 236 812 252 C776 226 776 138 812 110 Z"
                fill="#D4D4DC"/>
          <path d="M210 132 L222 162 L252 174 L222 186 L210 216 L198 186 L168 174 L198 162 Z"
                fill="#D4D4DC"/>
          <circle cx="315" cy="142" r="9" fill="#9E9EA8"/>
        """

    outline_ring = "" if variant != "dark" else '<circle cx="512" cy="596" r="326" fill="#1C2858" stroke="#FFB94E" stroke-opacity="0.28" stroke-width="6"/>'
    taono_halo = "" if variant != "dark" else '<circle cx="484" cy="686" r="56" fill="#FFB94E" fill-opacity="0.30"/>'

    return f"""<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8" />
<style>
  html, body {{ margin: 0; padding: 0; width: 1024px; height: 1024px; overflow: hidden; background: {bg}; }}
  svg {{ display: block; width: 1024px; height: 1024px; }}
</style>
</head>
<body>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <rect width="1024" height="1024" fill="{bg}"/>
  {outline_ring}

  {sky_svg}

  <!-- Double flat cartoon rolling meadow hills -->
  <path d="M0 735 Q250 675 512 730 T1024 718 L1024 1024 L0 1024 Z" fill="{hill_back}"/>
  <path d="M0 735 Q250 675 512 730 T1024 718" fill="none" stroke="{hill_ridge}" stroke-opacity="0.45" stroke-width="10" stroke-linecap="round"/>

  <path d="M0 792 Q290 832 548 776 T1024 798 L1024 1024 L0 1024 Z" fill="{hill_front}"/>
  <path d="M0 792 Q290 832 548 776 T1024 798" fill="none" stroke="{hill_ridge}" stroke-width="12" stroke-linecap="round"/>

  <!-- Trio Member 3: Plokko (left-back wing tumbler) -->
  <g id="plokko">
    <ellipse cx="246" cy="792" rx="94" ry="22" fill="{ground_shadow}"/>
    <ellipse cx="246" cy="774" rx="84" ry="26" fill="{plokko_foot}" stroke="{outline}" stroke-width="12"/>
    <!-- Left wing paddle -->
    <rect x="70" y="590" width="96" height="52" rx="26" transform="rotate(-18 118 616)"
          fill="{plokko_fill}" stroke="{outline}" stroke-width="12"/>
    <!-- Body -->
    <circle cx="246" cy="616" r="140" fill="{plokko_fill}" stroke="{outline}" stroke-width="13"/>
    <!-- Forehead jewel -->
    <circle cx="246" cy="499" r="21" fill="{pearl}" stroke="{outline}" stroke-width="10"/>
    <!-- Eyes looking cheerfully inward -->
    <circle cx="212" cy="604" r="18" fill="{eye}"/>
    <circle cx="207" cy="598" r="6" fill="{eye_hl}"/>
    <circle cx="280" cy="604" r="18" fill="{eye}"/>
    <circle cx="275" cy="598" r="6" fill="{eye_hl}"/>
  </g>

  <!-- Trio Member 5: Corllo (right-back teardrop with right spiral shell) -->
  <g id="corllo">
    <ellipse cx="772" cy="792" rx="94" ry="22" fill="{ground_shadow}"/>
    <!-- Signature logarithmic spiral listening ear -->
    <circle cx="872" cy="552" r="84" fill="{corllo_ear}" stroke="{outline}" stroke-width="13"/>
    <circle cx="872" cy="552" r="50" fill="{corllo_fill}"/>
    <circle cx="872" cy="552" r="23" fill="{corllo_core}"/>
    <!-- Feet -->
    <rect x="708" y="742" width="52" height="36" rx="18" fill="{corllo_ear}" stroke="{outline}" stroke-width="11"/>
    <rect x="780" y="742" width="52" height="36" rx="18" fill="{corllo_ear}" stroke="{outline}" stroke-width="11"/>
    <!-- Body -->
    <ellipse cx="772" cy="606" rx="120" ry="154" fill="{corllo_fill}" stroke="{outline}" stroke-width="13"/>
    <!-- Eyes looking inward cleanly separated from Taono edge -->
    <circle cx="744" cy="590" r="18" fill="{eye}"/>
    <circle cx="739" cy="584" r="6" fill="{eye_hl}"/>
    <circle cx="812" cy="590" r="18" fill="{eye}"/>
    <circle cx="807" cy="584" r="6" fill="{eye_hl}"/>
  </g>

  <!-- Trio Member 1: Taono (center-front coral resonance bell) -->
  <g id="taono">
    <ellipse cx="512" cy="826" rx="142" ry="26" fill="{ground_shadow}"/>
    <!-- Asymmetrical tuning-fork ears -->
    <g id="ear-left">
      <rect x="424" y="294" width="60" height="148" rx="30" fill="{taono_fill}" stroke="{outline}" stroke-width="13"/>
      <circle cx="454" cy="272" r="36" fill="{cream}" stroke="{outline}" stroke-width="12"/>
    </g>
    <g id="ear-right" transform="rotate(-11 572 372)">
      <rect x="542" y="302" width="60" height="140" rx="30" fill="{taono_fill}" stroke="{outline}" stroke-width="13"/>
      <circle cx="572" cy="280" r="36" fill="{cream}" stroke="{outline}" stroke-width="12"/>
    </g>
    <!-- Feet -->
    <rect x="406" y="772" width="84" height="46" rx="23" fill="{taono_foot}" stroke="{outline}" stroke-width="12"/>
    <rect x="534" y="772" width="84" height="46" rx="23" fill="{taono_foot}" stroke="{outline}" stroke-width="12"/>
    <!-- Rounded bell body -->
    <rect x="336" y="424" width="352" height="364" rx="164" fill="{taono_fill}" stroke="{outline}" stroke-width="15"/>
    <!-- Glazed expressive eyes -->
    <circle cx="448" cy="558" r="24" fill="{eye}"/>
    <circle cx="441" cy="549" r="8.5" fill="{eye_hl}"/>
    <circle cx="576" cy="558" r="24" fill="{eye}"/>
    <circle cx="569" cy="549" r="8.5" fill="{eye_hl}"/>
    <!-- Off-center cream chest resonance aperture & chime pearl -->
    {taono_halo}
    <circle cx="484" cy="686" r="52" fill="{cream}" stroke="{outline}" stroke-width="12"/>
    <circle cx="484" cy="686" r="26" fill="{pearl}"/>
  </g>
</svg>
</body>
</html>
"""


def render_variant(variant: str, out_path: str, tmp_dir: str) -> None:
    html_path = os.path.join(tmp_dir, f"{variant}.html")
    raw_png = os.path.join(tmp_dir, f"{variant}_raw.png")
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(build_svg(variant))

    subprocess.run(
        [
            CHROME_BIN,
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            "--hide-scrollbars",
            "--force-device-scale-factor=1",
            "--window-size=1024,1024",
            f"--screenshot={raw_png}",
            f"file://{html_path}",
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    # Flatten to opaque 24-bit sRGB PNG via Swift CoreGraphics/ImageIO (required by App Store / Xcode AppIcon)
    swift_code = f"""
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let inURL = URL(fileURLWithPath: "{raw_png}")
let outURL = URL(fileURLWithPath: "{out_path}")
guard let src = CGImageSourceCreateWithURL(inURL as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {{
    fatalError("Failed to read rasterized PNG")
}}
let w = 1024, h = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(
    data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {{
    fatalError("Failed to allocate opaque sRGB context")
}}
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
guard let opaque = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {{
    fatalError("Failed to encode destination PNG")
}}
CGImageDestinationAddImage(dest, opaque, nil)
if !CGImageDestinationFinalize(dest) {{
    fatalError("CGImageDestinationFinalize failed")
}}
"""
    subprocess.run(["swift", "-"], input=swift_code, text=True, check=True)


def main() -> int:
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "Chimmo/Resources/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(out_dir, exist_ok=True)
    mapping = {
        "light": os.path.join(out_dir, "AppIcon-Light.png"),
        "dark": os.path.join(out_dir, "AppIcon-Dark.png"),
        "tinted": os.path.join(out_dir, "AppIcon-Tinted.png"),
    }
    with tempfile.TemporaryDirectory() as tmp_dir:
        for variant, dest in mapping.items():
            render_variant(variant, dest, tmp_dir)
            print(f"Rendered {variant} -> {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
