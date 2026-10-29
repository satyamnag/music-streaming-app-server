"""Generate the Android 12+ splash icon (`android12splash.png`) for every
density bucket.

## The rule this implements

Android's official splash screen documentation
(https://developer.android.com/develop/ui/views/launch/splash-screen#dimensions)
specifies the splash icon the same way it specifies an adaptive icon:

  * App icon WITH an icon background: 240x240 dp, and it must FIT WITHIN A
    CIRCLE 160 dp IN DIAMETER.
  * App icon WITHOUT an icon background: 288x288 dp, and it must fit within a
    circle 192 dp in diameter.
  * "everything outside the circle turns invisible (masked)", and "one-third of
    the foreground is masked".

So the artwork may occupy at most 2/3 of the canvas in either case, and anything
outside that circle is cut off by the platform's mask. A full-bleed logo (what
shipped in v96, and what the reported screenshot shows) loses its gold ring and
part of the lettering.

## What this script draws

A 240x240 dp transparent canvas with the medallion at 101x101 dp in the centre:

  * 101 dp is exactly the size the legacy (pre-Android-12) launch screen draws
    the same medallion at (`drawable-*/splash.png` is 101x101 dp), so every
    Android version now shows the same splash at the same size;
  * 101/240 = 42% of the canvas, well inside the documented 2/3 (160dp of a
    240dp box) safe circle, so no mask on any device or OEM skin can reach the
    artwork.

Usage:  python tool/generate_android12_splash.py [--check]
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

RES = Path(__file__).resolve().parent.parent / "android/app/src/main/res"

# Density bucket -> px per dp.
DENSITIES = {
    "mdpi": 1.0,
    "hdpi": 1.5,
    "xhdpi": 2.0,
    "xxhdpi": 3.0,
    "xxxhdpi": 4.0,
}

# dp of the splash icon canvas and of the medallion inside it.
CANVAS_DP = 240
ART_DP = 101

# The highest-resolution copy of the medallion, used as the source artwork.
MASTER = RES / "drawable-xxxhdpi/splash.png"


def generate(check_only: bool = False) -> int:
    master = Image.open(MASTER).convert("RGBA")
    changed = 0

    for bucket, density in DENSITIES.items():
        canvas_px = round(CANVAS_DP * density)
        art_px = round(ART_DP * density)
        art = master.resize((art_px, art_px), Image.LANCZOS)

        canvas = Image.new("RGBA", (canvas_px, canvas_px), (0, 0, 0, 0))
        offset = ((canvas_px - art_px) // 2, (canvas_px - art_px) // 2)
        canvas.paste(art, offset, art)

        for directory in (f"drawable-{bucket}", f"drawable-night-{bucket}"):
            target = RES / directory / "android12splash.png"
            if target.exists():
                existing = Image.open(target).convert("RGBA")
                if existing.size == canvas.size and existing.tobytes() == canvas.tobytes():
                    print(f"unchanged  {directory}/android12splash.png")
                    continue
            print(
                f"{'would write' if check_only else 'write':<11} "
                f"{directory}/android12splash.png  "
                f"{canvas_px}x{canvas_px}px  art {art_px}px "
                f"({ART_DP}dp of {CANVAS_DP}dp = {ART_DP / CANVAS_DP:.0%})"
            )
            changed += 1
            if not check_only:
                canvas.save(target, optimize=True)

    return changed


if __name__ == "__main__":
    write = "--check" not in sys.argv
    n = generate(check_only=not write)
    print(f"\n{n} file(s) {'would change' if not write else 'written'}")
