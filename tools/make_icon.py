#!/usr/bin/env python3
"""Draws the LiquidCinema app icon with nothing but the standard library.

The icon is generated rather than committed as a binary so the repository
stays plain text and the artwork stays editable: every colour, rotation and
corner radius below is a design token. Pure stdlib also means CI needs no
image packages, and the same file works on macOS, Linux and Windows.

Usage:  python3 tools/make_icon.py
Output: LiquidCinema/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
"""

import math
import os
import struct
import zlib

SIZE = 1024
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(
    HERE, "..", "LiquidCinema", "Resources", "Assets.xcassets",
    "AppIcon.appiconset", "AppIcon.png"))

# ---------------------------------------------------------------- palette
INK_TOP = (0x15, 0x15, 0x1D)
INK_BOTTOM = (0x04, 0x04, 0x08)
WARM = (0xFF, 0x6E, 0x4E)        # coral bloom / card light end
AMBER = (0xFF, 0xC7, 0x76)       # amber bloom / card dark end
COOL = (0x7C, 0x74, 0xFF)        # violet counter-light

BACK_LIGHT = (0xD8, 0x5F, 0x46)
BACK_DARK = (0x6C, 0x2D, 0x33)
FRONT_LIGHT = (0xFF, 0xA2, 0x72)
FRONT_DARK = (0xD9, 0x59, 0x41)


def clamp(value, low=0.0, high=1.0):
    return low if value < low else high if value > high else value


def mix(a, b, t):
    t = clamp(t)
    return (a[0] + (b[0] - a[0]) * t,
            a[1] + (b[1] - a[1]) * t,
            a[2] + (b[2] - a[2]) * t)


def add(color, glow, strength):
    """Additive light, kept in sRGB for a soft bloom look."""
    return (color[0] + glow[0] * strength,
            color[1] + glow[1] * strength,
            color[2] + glow[2] * strength)


def rounded_rect_sdf(px, py, cx, cy, half_w, half_h, radius, angle):
    """Signed distance to a rotated rounded rectangle, in pixels."""
    ca, sa = math.cos(-angle), math.sin(-angle)
    dx, dy = px - cx, py - cy
    lx = dx * ca - dy * sa
    ly = dx * sa + dy * ca
    qx = abs(lx) - (half_w - radius)
    qy = abs(ly) - (half_h - radius)
    ax = qx if qx > 0.0 else 0.0
    ay = qy if qy > 0.0 else 0.0
    return math.hypot(ax, ay) + min(max(qx, qy), 0.0) - radius


def local_point(px, py, cx, cy, angle):
    ca, sa = math.cos(-angle), math.sin(-angle)
    dx, dy = px - cx, py - cy
    return dx * ca - dy * sa, dx * sa + dy * ca


def star_field(px, py, cx, cy, radius, pinch=0.42):
    """Concave four-point sparkle: superellipse with an exponent below one."""
    u = (px - cx) / radius
    v = (py - cy) / radius
    return (abs(u) ** pinch + abs(v) ** pinch) ** (1.0 / pinch) - 1.0


def coverage(distance):
    """Analytic edge coverage from a signed distance in pixels."""
    return clamp(0.5 - distance)


def composite(dst, color, alpha):
    if alpha <= 0.0:
        return dst
    if alpha >= 1.0:
        return color
    return (dst[0] + (color[0] - dst[0]) * alpha,
            dst[1] + (color[1] - dst[1]) * alpha,
            dst[2] + (color[2] - dst[2]) * alpha)


# ---------------------------------------------------------------- geometry
BACK_C = (0.418 * SIZE, 0.392 * SIZE)
BACK_HW, BACK_HH = 0.225 * SIZE, 0.292 * SIZE
BACK_R, BACK_A = 0.068 * SIZE, math.radians(-13.0)

FRONT_C = (0.575 * SIZE, 0.598 * SIZE)
FRONT_HW, FRONT_HH = 0.222 * SIZE, 0.283 * SIZE
FRONT_R, FRONT_A = 0.064 * SIZE, math.radians(7.5)

SPARK_C = (0.795 * SIZE, 0.195 * SIZE)
SPARK_R = 0.078 * SIZE
MICRO_C = (0.672 * SIZE, 0.322 * SIZE)
MICRO_R = 0.026 * SIZE
DUST_C = (0.898 * SIZE, 0.372 * SIZE)
DUST_R = 0.019 * SIZE

GLOW_WARM = (0.74 * SIZE, 0.86 * SIZE)
GLOW_COOL = (0.16 * SIZE, 0.10 * SIZE)


def background(px, py):
    base = mix(INK_TOP, INK_BOTTOM, (py / SIZE) ** 0.85)
    # warm bloom rising from the lower right, cool counter-light upper left
    dw = math.hypot(px - GLOW_WARM[0], py - GLOW_WARM[1]) / (0.62 * SIZE)
    dc = math.hypot(px - GLOW_COOL[0], py - GLOW_COOL[1]) / (0.55 * SIZE)
    base = add(base, WARM, 0.13 * math.exp(-dw * dw * 2.2))
    base = add(base, COOL, 0.085 * math.exp(-dc * dc * 2.4))
    return base


def back_card(px, py):
    d = rounded_rect_sdf(px, py, BACK_C[0], BACK_C[1], BACK_HW, BACK_HH, BACK_R, BACK_A)
    if d > 2.0:
        return None
    lx, ly = local_point(px, py, BACK_C[0], BACK_C[1], BACK_A)
    t = (ly + BACK_HH) / (2.0 * BACK_HH)
    color = mix(BACK_LIGHT, BACK_DARK, t)
    # rim light along the top-left edge
    rim = clamp(0.5 - (d + 1.6)) - clamp(0.5 - d)
    color = mix(color, (255, 232, 214), 0.55 * max(rim, 0.0))
    return coverage(d), color


def front_card(px, py):
    # a wide, soft contact shadow so the cards read as objects, not stickers
    shadow = rounded_rect_sdf(px, py - 0.020 * SIZE, FRONT_C[0], FRONT_C[1],
                              FRONT_HW * 1.02, FRONT_HH * 1.02, FRONT_R, FRONT_A)
    halo = 0.30 * clamp(1.0 - shadow / (0.060 * SIZE))
    d = rounded_rect_sdf(px, py, FRONT_C[0], FRONT_C[1], FRONT_HW, FRONT_HH, FRONT_R, FRONT_A)
    if d > 2.0:
        return None, None, (halo if halo > 0.0 else None)
    lx, ly = local_point(px, py, FRONT_C[0], FRONT_C[1], FRONT_A)
    t = (ly + FRONT_HH) / (2.0 * FRONT_HH)
    color = mix(FRONT_LIGHT, FRONT_DARK, clamp(t) ** 1.05)
    # diagonal specular sweep across the upper face
    sweep = (lx + FRONT_HW) / (2.0 * FRONT_HW) - (ly + FRONT_HH) / (2.0 * FRONT_HH)
    gloss = 0.20 * clamp(sweep + 0.55)
    color = mix(color, (255, 246, 236), gloss * 0.55)
    rim = clamp(0.5 - (d + 1.4)) - clamp(0.5 - d)
    color = mix(color, (255, 250, 244), 0.7 * max(rim, 0.0))
    return coverage(d), color, halo


def sparkle(px, py):
    """A four-point star with a round halo, plus two small dust sparkles."""
    dx = (px - SPARK_C[0]) / (0.150 * SIZE)
    dy = (py - SPARK_C[1]) / (0.150 * SIZE)
    halo = 0.10 * math.exp(-(dx * dx + dy * dy) * 2.8)
    star = clamp(1.0 - star_field(px, py, SPARK_C[0], SPARK_C[1], SPARK_R) / 1.4)
    micro = clamp(1.0 - star_field(px, py, MICRO_C[0], MICRO_C[1], MICRO_R) / 1.5)
    dust = clamp(1.0 - star_field(px, py, DUST_C[0], DUST_C[1], DUST_R) / 1.5)
    return max(halo, star, 0.80 * micro, 0.55 * dust)


def render():
    rows = []
    for y in range(SIZE):
        row = bytearray()
        for x in range(SIZE):
            color = background(x, y)

            card = back_card(x, y)
            if card is not None:
                color = composite(color, card[1], 0.94 * card[0] * 0.86)

            front = front_card(x, y)
            if front[0] is not None:
                halo = front[2] or 0.0
                if halo > 0.0:
                    color = composite(color, (0, 0, 0), min(halo, 0.45))
                color = composite(color, front[1], front[0])
            elif front[1] is not None:
                color = composite(color, (0, 0, 0), min(front[1], 0.45))

            s = sparkle(x, y)
            if s > 0.0:
                color = add(color, (255, 252, 240), s)

            row.append(int(clamp(color[0], 0, 255)))
            row.append(int(clamp(color[1], 0, 255)))
            row.append(int(clamp(color[2], 0, 255)))
        rows.append(bytes(row))
    return rows


def write_png(rows, path):
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag, payload):
        return (struct.pack(">I", len(payload)) + tag + payload
                + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF))

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    data = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(data)


if __name__ == "__main__":
    write_png(render(), OUT)
    print("wrote %s (%d bytes)" % (OUT, os.path.getsize(OUT)))
