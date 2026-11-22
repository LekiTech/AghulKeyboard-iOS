#!/usr/bin/env python3
"""Install the app icon from the approved artwork.

Reads the artwork as delivered, kept unmodified in docs/branding/:

    AghulKeyboard_AppIcon_1024.png    if present (the original file), otherwise
    AghulKeyboard_AppIcon_1024.webp   the copy the artwork arrived as

and writes into Assets.xcassets:

    AppIcon.appiconset/AppIcon-1024.png   the same pixels: 1024 × 1024, opaque RGB, square
    AppLogo.imageset/AppLogo.png          512 × 512, the logo on the app's screen

Needs Pillow:

    python3 scripts/make_icon.py

The artwork is not changed: no pixel is repainted, cropped or scaled for the
icon (a WebP source is only re-encoded as PNG, which is lossless). The
script checks what iOS requires of an app icon and stops if a check fails:
exactly 1024 × 1024, no transparency, and a full-bleed square. Full bleed
here means that each corner carries the colour of the field 24 px inside it
(no pre-rounded corners) and that the outer 8 px hold no near-black pixel
and no near-white one, except where a white stripe of the design runs
across the whole icon and so reaches its edge (no margin, outline or
shadow). A stripe is a run of rows or columns that are white for 95 % of
their length, with 4 px on either side for its uneven edge.
"""
import os
import sys

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRANDING = os.path.join(REPO, "docs", "branding")
SOURCES = ["AghulKeyboard_AppIcon_1024.png", "AghulKeyboard_AppIcon_1024.webp"]
ASSETS = os.path.join(REPO, "AghulKeyboard", "AghulKeyboard", "Assets.xcassets")
SIZE = 1024
BORDER = 8        # px from each edge that are checked
REFERENCE = 24    # px inward from a corner where the field colour is sampled
TOLERANCE = 30    # summed RGB difference that counts as another colour
STRIPE = 0.95     # share of a row or column that must be white for it to be a stripe of the design
EDGE = 4           # px around a stripe that count as its edge


def distance(a, b):
    return sum(abs(x - y) for x, y in zip(a, b))


def near_white(c):
    return min(c) > 200


def main():
    path = next((p for p in (os.path.join(BRANDING, n) for n in SOURCES) if os.path.exists(p)), None)
    if path is None:
        sys.exit("error: no artwork in docs/branding/ (expected " + " or ".join(SOURCES) + ")")
    source = Image.open(path)
    if source.size != (SIZE, SIZE):
        sys.exit(f"error: the source is {source.size}, expected {SIZE} × {SIZE}")
    if "A" in source.getbands() and source.getchannel("A").getextrema()[0] < 255:
        sys.exit("error: the source has transparent pixels; an app icon must be opaque")
    img = source.convert("RGB")
    px = img.load()

    last = SIZE - 1
    for (x, y), (ix, iy) in {(0, 0): (REFERENCE, REFERENCE), (last, 0): (last - REFERENCE, REFERENCE),
                             (0, last): (REFERENCE, last - REFERENCE),
                             (last, last): (last - REFERENCE, last - REFERENCE)}.items():
        if distance(px[x, y], px[ix, iy]) > TOLERANCE:
            sys.exit(f"error: the corner at ({x}, {y}) is not the colour of its field "
                     "(pre-rounded corners?); the artwork must be a full-bleed square")
    white_rows = {y for y in range(SIZE) if sum(near_white(px[x, y]) for x in range(SIZE)) >= STRIPE * SIZE}
    white_columns = {x for x in range(SIZE) if sum(near_white(px[x, y]) for y in range(SIZE)) >= STRIPE * SIZE}
    # The edge of a stripe is not perfectly level in the artwork: the rows
    # (columns) within EDGE px of a stripe belong to it.
    stripe_rows = {y + d for y in white_rows for d in range(-EDGE, EDGE + 1)}
    stripe_columns = {x + d for x in white_columns for d in range(-EDGE, EDGE + 1)}
    margin = 0
    for y in range(SIZE):
        for x in range(SIZE):
            if min(x, y, last - x, last - y) < BORDER:
                c = px[x, y]
                if max(c) < 60:
                    margin += 1
                elif near_white(c):
                    on_side = min(x, last - x) < BORDER and y in stripe_rows
                    on_top = min(y, last - y) < BORDER and x in stripe_columns
                    margin += not (on_side or on_top)
    if margin:
        sys.exit(f"error: {margin} near-white or near-black pixels in the outer {BORDER} px that are not part of "
                 "a stripe across the icon (a margin, an outline or a shadow?); the artwork must be full bleed")
    if len(white_rows) == SIZE or len(white_columns) == SIZE:
        sys.exit("error: the artwork is white from edge to edge")

    img.save(os.path.join(ASSETS, "AppIcon.appiconset", "AppIcon-1024.png"), "PNG", optimize=True)
    img.resize((512, 512), Image.LANCZOS).save(os.path.join(ASSETS, "AppLogo.imageset", "AppLogo.png"),
                                               "PNG", optimize=True)
    corners = " ".join("#%02X%02X%02X" % px[x, y] for x, y in ((0, 0), (last, 0), (0, last), (last, last)))
    print(f"icon installed from {os.path.basename(path)}: {SIZE} × {SIZE} RGB PNG, no alpha, full bleed, "
          f"corner colours {corners}, {len(white_rows)} rows of white stripe")


if __name__ == "__main__":
    main()
