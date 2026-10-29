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

A 240x240 dp transparent canvas whose medallion occupies the same FRACTION of the
canvas that the reference splash shows.

The fraction is derived from the platform's own geometry rather than picked by
eye. Android lays the splash icon out at 288 dp when no icon background is drawn
(the reference phone renders exactly 101 dp of medallion that way, measured from
the owner's screenshot: a 203 px medallion on a 2x screen), and every density
bucket below therefore carries `101 / 288 = 35%` of the canvas as artwork:

  * a device that uses the 288 dp box shows the medallion at 101 dp, the size the
    legacy (pre-Android-12) launch screen draws the same artwork at;
  * a device that honours `windowSplashScreenIconBackgroundColor` and uses the
    240 dp box shows it at 84 dp - smaller, never bigger;
  * both are far inside the documented two-thirds safe circle (the mask can only
    reach 2/3 = 67%), so no mask on any device or OEM skin can touch the artwork.

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

# dp of the splash icon canvas, and the medallion size the reference shows when
# the platform lays the icon out in its 288 dp box (see the module docstring).
CANVAS_DP = 240
REFERENCE_ICON_BOX_DP = 288
MEDALLION_DP = 101

# Fraction of the canvas the medallion keeps clear around it.
ART_FRACTION = MEDALLION_DP / REFERENCE_ICON_BOX_DP

# The highest-resolution copy of the medallion, used as the source artwork.
MASTER = RES / "drawable-xxxhdpi/splash.png"


def generate(check_only: bool = False) -> int:
    master = Image.open(MASTER).convert("RGBA")
    changed = 0

    for bucket, density in DENSITIES.items():
        canvas_px = round(CANVAS_DP * density)
        art_px = max(1, round(canvas_px * ART_FRACTION))
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
                f"({ART_FRACTION:.1%} of canvas -> "
                f"{ART_FRACTION * REFERENCE_ICON_BOX_DP:.1f}dp in a "
                f"{REFERENCE_ICON_BOX_DP}dp box, "
                f"{ART_FRACTION * CANVAS_DP:.1f}dp in a {CANVAS_DP}dp box)"
            )
            changed += 1
            if not check_only:
                canvas.save(target, optimize=True)

    return changed


if __name__ == "__main__":
    write = "--check" not in sys.argv
    n = generate(check_only=not write)
    print(f"\n{n} file(s) {'would change' if not write else 'written'}")
