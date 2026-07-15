#!/usr/bin/env python3
"""Generate decorative jungle foliage SVGs for Snecko's background.

Pure-math palm fronds (a curved rib with tapered leaflets) — no external art.
Output: assets/decor/frond.svg  (a single dark leaf; QML tints/rotates instances)

    python3 tools/make_leaves.py
"""
import math
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "decor")


def cubic(p0, p1, p2, p3, t):
    u = 1 - t
    x = (u**3 * p0[0] + 3 * u*u*t * p1[0] + 3 * u*t*t * p2[0] + t**3 * p3[0])
    y = (u**3 * p0[1] + 3 * u*u*t * p1[1] + 3 * u*t*t * p2[1] + t**3 * p3[1])
    return x, y


def cubic_tangent(p0, p1, p2, p3, t):
    u = 1 - t
    dx = (3*u*u*(p1[0]-p0[0]) + 6*u*t*(p2[0]-p1[0]) + 3*t*t*(p3[0]-p2[0]))
    dy = (3*u*u*(p1[1]-p0[1]) + 6*u*t*(p2[1]-p1[1]) + 3*t*t*(p3[1]-p2[1]))
    return math.atan2(dy, dx)


def frond(fill="#12301e"):
    W, H = 300, 420
    base = (150, 406)
    p1, p2, tip = (95, 300), (170, 150), (140, 16)

    parts = []
    # Rib.
    rib_pts = [cubic(base, p1, p2, tip, i / 40) for i in range(41)]
    d = "M " + " L ".join(f"{x:.1f},{y:.1f}" for x, y in rib_pts)
    parts.append(f'<path d="{d}" fill="none" stroke="{fill}" '
                 f'stroke-width="7" stroke-linecap="round"/>')

    # Leaflets in pairs along the rib, angled toward the tip.
    n = 15
    for i in range(1, n):
        t = i / n
        px, py = cubic(base, p1, p2, tip, t)
        ang = cubic_tangent(base, p1, p2, tip, t)          # points base→tip
        length = 128 * (0.30 + 0.70 * math.sin(math.pi * (t ** 0.85)))
        width = length * 0.16
        for side in (+1, -1):
            spread = math.radians(48)
            la = ang + side * spread
            tx, ty = px + length * math.cos(la), py + length * math.sin(la)
            mx, my = px + 0.5 * length * math.cos(la), py + 0.5 * length * math.sin(la)
            perp = la + math.pi / 2
            c1 = (mx + width * math.cos(perp), my + width * math.sin(perp))
            c2 = (mx - width * math.cos(perp), my - width * math.sin(perp))
            parts.append(
                f'<path d="M {px:.1f},{py:.1f} Q {c1[0]:.1f},{c1[1]:.1f} {tx:.1f},{ty:.1f} '
                f'Q {c2[0]:.1f},{c2[1]:.1f} {px:.1f},{py:.1f} Z" fill="{fill}"/>')

    body = "\n  ".join(parts)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
            f'viewBox="0 0 {W} {H}">\n  {body}\n</svg>\n')


def monstera(fill="#0e281b"):
    """A split-leaf (monstera) silhouette: a central blade with fat finger-lobes
    radiating up-and-out from the midrib, plus an upward tip finger."""
    W, H = 360, 380
    cx = 180
    baseY, tipY = 362, 20
    length = baseY - tipY
    maxw = 156
    nLobes = 6
    parts = []

    # Central tapered blade along the midrib.
    blade = []
    N = 44
    for i in range(N + 1):
        t = i / N
        y = baseY - length * t
        w = maxw * 0.22 * math.sin(math.pi * (t ** 0.9)) + 7
        blade.append((cx - w, y))
    bpts = blade + [(2 * cx - x, y) for x, y in reversed(blade)]
    parts.append('<path d="M ' + " L ".join(f"{x:.1f},{y:.1f}" for x, y in bpts)
                 + f' Z" fill="{fill}"/>')

    # Finger-lobes (fat round-capped strokes) radiating from the midrib.
    for i in range(1, nLobes + 1):
        t = i / (nLobes + 1)
        oy = baseY - length * t
        flen = maxw * math.sin(math.pi * (t ** 0.82)) * 0.92
        if flen < 12:
            continue
        for side in (-1, 1):
            up = 0.45 + 0.8 * t                    # fingers point more upward near the tip
            dx, dy = side * 0.85, -up
            n = math.hypot(dx, dy); dx /= n; dy /= n
            ox = cx + side * 9
            tx, ty = ox + flen * dx, oy + flen * dy
            fw = max(11, flen * 0.30)
            parts.append(f'<path d="M {ox:.1f},{oy:.1f} L {tx:.1f},{ty:.1f}" '
                         f'stroke="{fill}" stroke-width="{fw:.1f}" '
                         f'stroke-linecap="round" fill="none"/>')

    # Upward tip finger.
    parts.append(f'<path d="M {cx},{baseY - length * 0.70:.0f} L {cx},{tipY}" '
                 f'stroke="{fill}" stroke-width="30" stroke-linecap="round" fill="none"/>')

    body = "\n  ".join(parts)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
            f'viewBox="0 0 {W} {H}">\n  {body}\n</svg>\n')


def fanpalm(fill="#0c1f18"):
    """A spiky fan (palmate) palm: many pointed blades radiating from the base."""
    W, H = 420, 380
    cx, baseY = 210, 366
    R = 330
    nB = 13
    spread = math.radians(158)
    parts = []
    for i in range(nB):
        frac = i / (nB - 1)
        a = -math.pi / 2 + (frac - 0.5) * spread          # centred pointing up
        bl = R * (0.62 + 0.38 * math.cos((frac - 0.5) * math.pi))   # centre blades longest
        tipx, tipy = cx + bl * math.cos(a), baseY + bl * math.sin(a)
        bw = 15
        perp = a + math.pi / 2
        blx, bly = cx + bw * math.cos(perp), baseY + bw * math.sin(perp)
        brx, bry = cx - bw * math.cos(perp), baseY - bw * math.sin(perp)
        # A slightly bulged pointed blade via quadratics through a mid control.
        mx, my = cx + bl * 0.5 * math.cos(a), baseY + bl * 0.5 * math.sin(a)
        c1 = (mx + bw * 1.3 * math.cos(perp), my + bw * 1.3 * math.sin(perp))
        c2 = (mx - bw * 1.3 * math.cos(perp), my - bw * 1.3 * math.sin(perp))
        parts.append(f'<path d="M {blx:.1f},{bly:.1f} Q {c1[0]:.1f},{c1[1]:.1f} '
                     f'{tipx:.1f},{tipy:.1f} Q {c2[0]:.1f},{c2[1]:.1f} {brx:.1f},{bry:.1f} Z" '
                     f'fill="{fill}"/>')
    parts.append(f'<circle cx="{cx}" cy="{baseY}" r="18" fill="{fill}"/>')
    body = "\n  ".join(parts)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
            f'viewBox="0 0 {W} {H}">\n  {body}\n</svg>\n')


def vine(fill="#0c1f18"):
    """A wavy hanging vine with small alternating leaflets."""
    W, H = 220, 440
    N = 44
    pts = []
    for i in range(N + 1):
        t = i / N
        y = 12 + (H - 24) * t
        x = W / 2 + 48 * math.sin(t * math.pi * 2.3)
        pts.append((x, y))
    stem = "M " + " L ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    parts = [f'<path d="{stem}" fill="none" stroke="{fill}" stroke-width="5" '
             f'stroke-linecap="round"/>']
    for k, i in enumerate(range(3, N - 1, 3)):
        x, y = pts[i]
        side = 1 if k % 2 == 0 else -1
        lx, ly = x + side * 24, y
        rot = side * 34
        parts.append(f'<ellipse cx="{lx:.1f}" cy="{ly:.1f}" rx="21" ry="9" '
                     f'transform="rotate({rot} {lx:.1f} {ly:.1f})" fill="{fill}"/>')
    body = "\n  ".join(parts)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
            f'viewBox="0 0 {W} {H}">\n  {body}\n</svg>\n')


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, svg in [("frond.svg", frond()),
                      ("broadleaf.svg", monstera()),
                      ("fanpalm.svg", fanpalm()),
                      ("vine.svg", vine())]:
        path = os.path.join(OUT, name)
        with open(path, "w") as f:
            f.write(svg)
        print("wrote", path)
