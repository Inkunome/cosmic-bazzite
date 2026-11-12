#!/usr/bin/env python3
"""Draw the Pixel Guild wallpaper, ink-pixel-dusk.png: a night sky over two bands of stepped hills.

The picture is drawn on a 384 x 216 grid and scaled by 10 (3840 x 2160). Colours are the design system's tokens
(eww/_tokens.scss): a `bg` sky, `px-highlight` and `gold` stars, a `gold` moon with two `bg` craters at the upper right,
`surface` hills behind and `sunken` hills in front.

Python standard library only. The PNG is written by this script, deflate included (fixed Huffman codes, matches at a
distance of one pixel or one row), so the output is the same bytes on every run and on every machine: it never depends on
the zlib the system has.

  pixel-wallpaper.py [OUTPUT]   default: the image's file under build_files/system_files/usr/share/backgrounds/ink/
"""
import os
import struct
import sys
import zlib

GRID_W, GRID_H, SCALE = 384, 216, 10
WIDTH, HEIGHT = GRID_W * SCALE, GRID_H * SCALE

# palette index -> colour (tokens)
BG, SURFACE, SUNKEN, HIGHLIGHT, GOLD = range(5)
PALETTE = {
    BG: 0x150F28,
    SURFACE: 0x20173A,
    SUNKEN: 0x0C0818,
    HIGHLIGHT: 0xB8A9F0,
    GOLD: 0xF2B84B,
}

DEFAULT_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "system_files", "usr", "share",
                           "backgrounds", "ink", "ink-pixel-dusk.png")


def scene():
    """The 384 x 216 grid, one palette index per cell, as a list of rows."""
    g = [[BG] * GRID_W for _ in range(GRID_H)]

    def rect(x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                g[yy][xx] = c

    for x, y in ((24, 32), (62, 22), (102, 46), (148, 26), (198, 38), (246, 24), (278, 56), (40, 74), (124, 88),
                 (222, 80), (174, 64), (90, 112), (262, 104), (16, 124), (360, 84)):
        rect(x, y, 1, 1, HIGHLIGHT)
    for x, y in ((78, 42), (168, 60), (232, 34), (354, 118)):
        rect(x, y, 1, 1, GOLD)
    # the moon: a 20 x 20 disc with stepped corners, two craters; low enough that the fill crop of a 21:9 screen (3440 x 1440)
    # keeps it clear of the bar
    mx, my = 314, 44
    rect(mx + 3, my, 14, 20, GOLD)
    rect(mx, my + 3, 20, 14, GOLD)
    rect(mx + 4, my + 6, 3, 3, BG)
    rect(mx + 9, my + 12, 2, 2, BG)
    # hills: (start, end, top) steps; the back band first, the front band over it
    for x0, x1, top in ((0, 26, 166), (26, 56, 160), (56, 92, 154), (92, 138, 150), (138, 170, 154), (170, 206, 160),
                        (206, 252, 166), (252, 294, 174), (294, 340, 168), (340, 384, 162)):
        rect(x0, top, x1 - x0, GRID_H - top, SURFACE)
    for x0, x1, top in ((0, 42, 192), (42, 106, 188), (106, 180, 192), (180, 276, 198), (276, 330, 204),
                        (330, 384, 196)):
        rect(x0, top, x1 - x0, GRID_H - top, SUNKEN)
    return g


def raw_image(g):
    """PNG scanlines: filter byte 0, then one palette index per pixel, each grid cell SCALE x SCALE pixels."""
    out = bytearray()
    for row in g:
        line = bytearray([0])
        for c in row:
            line += bytes([c]) * SCALE
        out += bytes(line) * SCALE
    return bytes(out)


# ── deflate with fixed Huffman codes (RFC 1951, 3.2.6) ──
LEN_BASE = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195,
            227, 258]
LEN_EXTRA = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
DIST_BASE = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073,
             4097, 6145, 8193, 12289, 16385, 24577]
DIST_EXTRA = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]


class Bits:
    def __init__(self):
        self.out = bytearray()
        self.acc = 0
        self.n = 0

    def put(self, value, count):
        """Append `count` bits of `value`, least significant first."""
        self.acc |= value << self.n
        self.n += count
        while self.n >= 8:
            self.out.append(self.acc & 0xFF)
            self.acc >>= 8
            self.n -= 8

    def huff(self, code, length):
        """Append a Huffman code, most significant bit first."""
        self.put(int(format(code, f"0{length}b")[::-1], 2), length)

    def done(self):
        if self.n:
            self.out.append(self.acc & 0xFF)
        return bytes(self.out)


def lit(bits, sym):
    if sym <= 143:
        bits.huff(0x30 + sym, 8)
    elif sym <= 255:
        bits.huff(0x190 + sym - 144, 9)
    elif sym <= 279:
        bits.huff(sym - 256, 7)
    else:
        bits.huff(0xC0 + sym - 280, 8)


def match(bits, length, dist):
    i = max(k for k in range(29) if LEN_BASE[k] <= length)
    lit(bits, 257 + i)
    bits.put(length - LEN_BASE[i], LEN_EXTRA[i])
    j = max(k for k in range(30) if DIST_BASE[k] <= dist)
    bits.huff(j, 5)
    bits.put(dist - DIST_BASE[j], DIST_EXTRA[j])


def match_len(data, i, dist):
    if i < dist:
        return 0
    limit = min(258, len(data) - i)
    if data[i:i + limit] == data[i - dist:i - dist + limit]:
        return limit
    n = 0
    while n < limit and data[i + n] == data[i - dist + n]:
        n += 1
    return n


def deflate(data, row):
    bits = Bits()
    bits.put(1, 1)   # last block
    bits.put(1, 2)   # fixed Huffman codes
    i = 0
    while i < len(data):
        best, dist = 0, 0
        for d in (row, 1):
            n = match_len(data, i, d)
            if n > best:
                best, dist = n, d
        if best >= 3:
            match(bits, best, dist)
            i += best
        else:
            lit(bits, data[i])
            i += 1
    lit(bits, 256)   # end of block
    return bits.done()


def chunk(kind, payload):
    body = kind + payload
    return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def png(g):
    raw = raw_image(g)
    stream = b"\x78\x01" + deflate(raw, WIDTH + 1) + struct.pack(">I", zlib.adler32(raw) & 0xFFFFFFFF)
    plte = b"".join(PALETTE[i].to_bytes(3, "big") for i in range(len(PALETTE)))
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 3, 0, 0, 0))
            + chunk(b"PLTE", plte)
            + chunk(b"IDAT", stream)
            + chunk(b"IEND", b""))


def main(argv):
    out = argv[1] if len(argv) > 1 else DEFAULT_OUT
    data = png(scene())
    with open(out, "wb") as f:
        f.write(data)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
