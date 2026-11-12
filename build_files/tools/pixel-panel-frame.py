#!/usr/bin/env python3
"""Draw the frame of the floating panels, eww/icons/panel-frame.svg: a nine-slice image for GTK's border-image.

The panel's outline is a rectangle with an 8 x 8 px square cut out of each corner (the notched pixel corner of the
design). A 3 px frame in `fg` follows that outline, steps included; a hard shadow in `line`, the same outline moved
4 px right and 4 px down, shows where the panel does not cover it; inside the frame, the band between the frame and
the panel's padding box is the panel's fill, `surface` at `$widget-alpha` (translucent, like every widget background).
The cut corners are transparent. The padding box itself is filled by eww.scss (background-color, clipped to the padding
box) with the same colour: the image and the background meet edge to edge and never overlap, so nothing doubles.

The image is 28 x 28: a 24 x 24 panel at (0, 0) and its shadow to (27, 27). eww.scss slices it 12 / 15 / 15 / 12 px
(top, right, bottom, left), the border widths of the panel: each corner holds a whole notch, its steps and the shadow's
own notch, and the one-pixel middle row and column repeat along the edges (the middle pixel is not drawn). Colours are
the token values of eww/_tokens.scss, and the fill's opacity is its $widget-alpha: this script reads both, so after a
change of either, run it again (check-look compares the committed file with its output).

  pixel-panel-frame.py [OUTPUT]   default: build_files/system_files/etc/skel/.config/eww/icons/panel-frame.svg
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EWW = os.path.join(HERE, "..", "system_files", "etc", "skel", ".config", "eww")
SIZE, PANEL, NOTCH, FRAME, SHADOW = 28, 24, 8, 3, 4
CENTRE = 12   # the middle row and column of the nine slices


def tokens():
    text = open(os.path.join(EWW, "_tokens.scss"), encoding="utf-8").read()
    t = dict(re.findall(r"^\$([a-z-]+):\s*(#[0-9A-Fa-f]{6});", text, flags=re.M))
    t["widget-alpha"] = re.search(r"^\$widget-alpha:\s*([0-9.]+);", text, flags=re.M).group(1)
    return t


def inside(x, y, w=PANEL, h=PANEL, n=NOTCH):
    """(x, y) is inside a w x h notched rectangle at the origin."""
    if not (0 <= x < w and 0 <= y < h):
        return False
    left, right, top, bottom = x < n, x >= w - n, y < n, y >= h - n
    return not ((left or right) and (top or bottom))


def frame(x, y):
    """On the 3 px frame: inside the panel, outside the panel moved in by 3 px on every side."""
    return inside(x, y) and not inside(x - FRAME, y - FRAME, PANEL - 2 * FRAME, PANEL - 2 * FRAME, NOTCH)


def shadow(x, y):
    return inside(x - SHADOW, y - SHADOW) and not inside(x, y)


def runs(cells):
    d = []
    for y in sorted({c[1] for c in cells}):
        xs = sorted(x for x, yy in cells if yy == y)
        start = prev = xs[0]
        for x in xs[1:] + [None]:
            if x is not None and x == prev + 1:
                prev = x
                continue
            w = prev - start + 1
            d.append(f"M{start} {y}h{w}v1h-{w}z")
            if x is not None:
                start = prev = x
    return "".join(d)


def band(x, y):
    """Inside the frame (the panel's fill) but outside the centre pixel, which the image never draws."""
    return inside(x, y) and not frame(x, y) and (x, y) != (CENTRE, CENTRE)


def svg():
    t = tokens()
    grid = [(x, y) for y in range(SIZE) for x in range(SIZE)]
    paths = [(t["line"], "", {c for c in grid if shadow(*c)}), (t["fg"], "", {c for c in grid if frame(*c)}),
             (t["surface"], f' fill-opacity="{t["widget-alpha"]}"', {c for c in grid if band(*c)})]
    body = "".join(f'<path fill="{fill}"{opacity} d="{runs(cells)}"/>' for fill, opacity, cells in paths)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}" '
            f'shape-rendering="crispEdges">{body}</svg>\n')


def main(argv):
    out = argv[1] if len(argv) > 1 else os.path.join(EWW, "icons", "panel-frame.svg")
    with open(out, "w", encoding="utf-8") as f:
        f.write(svg())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
