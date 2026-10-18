"""The worlds of Gummy Galaxy: an emblem per world, a landscape per world, a galaxy map, and an emblem sheet.

Usage: worlds.py  (writes each piece's HTML next to this file)
"""
import math

from companion import companion, four_point, fmt, page, sparkles

INK = "#1a1240"
CREAM = "#fff6ea"

# Each world is a flavor, a place, and the Orion idea its symbol stands for.
WORLDS = [
    {"id": "swirlheart", "number": 1, "name": "Swirlheart", "flavor": "Lemon · Peach · Cherry", "color": "#ffb02e", "dark": "#c2410c", "orion": "Home", "idea": "Every workspace orbits something. The chewy spiral sun is where every run starts and the hub you come back to.", "emblem": "spiral"},
    {"id": "ringwell", "number": 2, "name": "Ringwell", "flavor": "Blueberry · Sky", "color": "#2e7dff", "dark": "#1a3f9e", "orion": "Groups", "idea": "A jelly ocean under a ring you can walk on. Rings hold things together; a group is a ring around its work.", "emblem": "ring"},
    {"id": "gumdrop", "number": 3, "name": "Gumdrop Highlands", "flavor": "Green Apple", "color": "#5cc93a", "dark": "#2d7a1f", "orion": "Ready work", "idea": "Sugar-dusted hills that are always ripe for picking. Whatever grows here can be started right now.", "emblem": "gumdrop"},
    {"id": "noodle", "number": 4, "name": "Noodle Reach", "flavor": "Grape · Licorice", "color": "#8b3dff", "dark": "#4a1d9e", "orion": "Dependencies", "idea": "Floating islands strung together by sagging licorice bridges. Nothing here goes anywhere without crossing a link.", "emblem": "knot"},
    {"id": "cotton", "number": 5, "name": "Cotton Shoals", "flavor": "Cotton Candy", "color": "#ff7fc4", "dark": "#c23c8a", "orion": "Notes", "idea": "Soft cloud islands where thoughts drift and pile up. Context, decisions, and reminders live in the fluff.", "emblem": "cloud"},
    {"id": "taffy", "number": 6, "name": "Taffy Belt", "flavor": "Six Flavors", "color": "#ff3d6e", "dark": "#a3173f", "orion": "Inbox", "idea": "An asteroid belt of wrapped candy that drifts in from everywhere. Miners unwrap it and sort it into worlds.", "emblem": "candy"},
    {"id": "geode", "number": 7, "name": "Geode Moon", "flavor": "Rock Candy", "color": "#8fd0ff", "dark": "#3b6cff", "orion": "Done", "idea": "A quiet moon where finished things crystallize. Nothing is thrown away; it just turns to rock candy and glows.", "emblem": "crystal"},
]

SPIRAL_ARM = "M0 0 C40 -6 62 -48 42 -84 C28 -106 0 -112 -22 -104 C8 -96 22 -76 14 -56 C8 -34 -14 -20 0 0 Z"


def mix(first, second, amount):
    a = [int(first[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(second[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * amount):02x}" for x, y in zip(a, b))


def emblem(kind, x, y, size, fill=CREAM, ink=INK, stroke=0.0, accent=None):
    """Each world's symbol, centered on (x, y) and about `size` across. One color plus optional ink outline."""
    scale = size / 220
    line = f'stroke="{ink}" stroke-width="{fmt(stroke / scale)}" stroke-linejoin="round" stroke-linecap="round"' if stroke else 'stroke="none"'
    accent = accent or fill
    shapes = []
    if kind == "spiral":
        shapes += [f'<path d="{SPIRAL_ARM}" transform="rotate({angle}) scale(1.05)" fill="{fill}" {line}/>' for angle in (0, 120, 240)]
        shapes.append(f'<circle r="34" fill="{accent}" {line}/>')
    elif kind == "ring":
        shapes.append(f'<path d="M-100 0 A100 30 0 0 1 100 0" fill="none" stroke="{ink if stroke else fill}" stroke-width="{fmt(22 + stroke / scale * 2)}" transform="rotate(-18)" stroke-linecap="round"/>' if stroke else "")
        shapes.append(f'<path d="M-100 0 A100 30 0 0 1 100 0" fill="none" stroke="{fill}" stroke-width="22" transform="rotate(-18)" stroke-linecap="round"/>')
        shapes.append(f'<circle r="56" fill="{accent}" {line}/>')
        if stroke:
            shapes.append(f'<path d="M-100 0 A100 30 0 0 0 100 0" fill="none" stroke="{ink}" stroke-width="{fmt(22 + stroke / scale * 2)}" transform="rotate(-18)" stroke-linecap="round"/>')
        shapes.append(f'<path d="M-100 0 A100 30 0 0 0 100 0" fill="none" stroke="{fill}" stroke-width="22" transform="rotate(-18)" stroke-linecap="round"/>')
    elif kind == "gumdrop":
        shapes.append(f'<path d="M-82 70 C-82 -18 -46 -86 0 -86 C46 -86 82 -18 82 70 Q0 88 -82 70 Z" fill="{fill}" {line}/>')
        dots = [(-40, -20), (8, -50), (36, 0), (-14, 24), (50, 44), (-52, 44), (20, 52), (-20, -62)]
        shapes += [f'<circle cx="{dx}" cy="{dy}" r="7" fill="{accent if accent != fill else ink}" opacity="0.55"/>' for dx, dy in dots]
    elif kind == "knot":
        # Two linked loops: draw both, then lay the first one's lower crossing back over the second.
        loop = "M0 -58 C40 -58 60 -30 60 0 C60 30 40 58 0 58 C-40 58 -60 30 -60 0 C-60 -30 -40 -58 0 -58 Z"
        width = 24
        outline = f'stroke="{ink}" stroke-width="{fmt(width + stroke / scale * 2)}"' if stroke else ""
        for dx in (-34, 34):
            if stroke:
                shapes.append(f'<path d="{loop}" transform="translate({dx} 0)" fill="none" {outline}/>')
            shapes.append(f'<path d="{loop}" transform="translate({dx} 0)" fill="none" stroke="{fill}" stroke-width="{width}"/>')
        over = "M-34 58 C6 58 26 30 26 0"
        if stroke:
            shapes.append(f'<path d="{over}" fill="none" stroke="{ink}" stroke-width="{fmt(width + stroke / scale * 2)}" stroke-linecap="butt"/>')
        shapes.append(f'<path d="{over}" fill="none" stroke="{fill}" stroke-width="{width}" stroke-linecap="round"/>')
    elif kind == "cloud":
        shapes.append(f'<path d="M-96 50 C-124 50 -124 6 -92 4 C-96 -34 -50 -48 -30 -24 C-20 -74 50 -78 58 -26 C92 -40 120 -6 98 22 C122 30 116 56 92 56 Z" fill="{fill}" {line}/>')
        shapes.append(f'<circle cx="-6" cy="14" r="14" fill="{accent if accent != fill else ink}" opacity="0.5"/>')
    elif kind == "candy":
        shapes.append(f'<path d="M-50 -10 L-108 -52 Q-118 0 -108 52 L-50 10 Z" fill="{fill}" {line}/>')
        shapes.append(f'<path d="M50 -10 L108 -52 Q118 0 108 52 L50 10 Z" fill="{fill}" {line}/>')
        shapes.append(f'<ellipse rx="64" ry="48" fill="{accent}" {line}/>')
        shapes.append(f'<path d="M-30 -40 Q0 0 -30 40 M8 -46 Q38 0 8 46" fill="none" stroke="{fill if accent != fill else ink}" stroke-width="10" opacity="0.6" stroke-linecap="round"/>')
    elif kind == "crystal":
        shapes.append(f'<path d="M0 -96 L46 -40 L34 74 L0 96 L-34 74 L-46 -40 Z" fill="{fill}" {line}/>')
        shapes.append(f'<path d="M-46 -40 L0 -20 L46 -40 M0 -20 L0 96" fill="none" stroke="{accent if accent != fill else ink}" stroke-width="6" opacity="0.5"/>')
        shapes.append(f'<path d="M-58 20 L-86 -14 L-96 40 L-74 70 Z" fill="{fill}" {line}/>')
        shapes.append(f'<path d="M58 30 L84 0 L96 50 L72 76 Z" fill="{fill}" {line}/>')
    return f'<g transform="translate({fmt(x)} {fmt(y)}) scale({scale:.3f})">{"".join(shapes)}</g>'


def ridge(width, base, amplitude, seed, step=8, frequencies=(0.004, 0.011, 0.027)):
    """A wavy horizon line from a few sines, closed down to the bottom of the frame."""
    points = []
    for x in range(-20, width + 21, step):
        y = base
        for index, frequency in enumerate(frequencies):
            y += amplitude * (0.62, 0.28, 0.1)[index] * math.sin(x * frequency + seed * (index + 1.7))
        points.append(f"{x} {fmt(y)}")
    return "M" + " L".join(points) + f" L{width + 20} 2000 L-20 2000 Z"


def domes(width, base, seed, count, height, color, sugar=None):
    out = []
    state = seed
    for index in range(count):
        state = (state * 1103515245 + 12345) % 2**31
        x = (index + 0.5) * width / count + (state % 60) - 30
        radius = width / count * (0.62 + (state % 100) / 300)
        peak = base - height * (0.7 + (state % 37) / 120)
        out.append(f'<path d="M{fmt(x - radius)} {base + 400} L{fmt(x - radius)} {base} C{fmt(x - radius)} {fmt(peak)} {fmt(x + radius)} {fmt(peak)} {fmt(x + radius)} {base} L{fmt(x + radius)} {base + 400} Z" fill="{color}"/>')
        if sugar:
            for dot in range(9):
                state = (state * 1103515245 + 12345) % 2**31
                dx = x + ((state % 1000) / 1000 - 0.5) * radius * 1.3
                dy = base - (state % 997) / 997 * (base - peak) * 0.6 - 10
                out.append(f'<circle cx="{fmt(dx)}" cy="{fmt(dy)}" r="{2 + state % 3}" fill="{sugar}" opacity="0.7"/>')
    return "".join(out)


def lollipop(x, y, height, color, swirl=CREAM):
    return (f'<g transform="translate({fmt(x)} {fmt(y)})"><rect x="-4" y="{-height}" width="8" height="{height}" rx="4" fill="{CREAM}"/>'
            f'<circle cy="{-height}" r="{fmt(height * 0.32)}" fill="{color}"/>'
            f'<path d="M0 {-height} m{fmt(-height * 0.18)} 0 a{fmt(height * 0.18)} {fmt(height * 0.18)} 0 1 1 {fmt(height * 0.18)} {fmt(height * 0.18)} a{fmt(height * 0.11)} {fmt(height * 0.11)} 0 1 1 {fmt(-height * 0.11)} {fmt(-height * 0.11)}" fill="none" stroke="{swirl}" stroke-width="{fmt(height * 0.05)}" stroke-linecap="round"/></g>')


def island(x, y, width, top, cliff):
    """A floating island: a rounded top and a dripping underside."""
    half = width / 2
    return (f'<g transform="translate({fmt(x)} {fmt(y)})">'
            f'<path d="M{fmt(-half)} 0 C{fmt(-half * 0.6)} {fmt(width * 0.5)} {fmt(-half * 0.2)} {fmt(width * 0.9)} 0 {fmt(width * 1.05)} C{fmt(half * 0.2)} {fmt(width * 0.9)} {fmt(half * 0.6)} {fmt(width * 0.5)} {fmt(half)} 0 Z" fill="{cliff}"/>'
            f'<ellipse rx="{fmt(half)}" ry="{fmt(width * 0.11)}" fill="{top}"/></g>')


def frame(world, width, height, art, sky, ink=INK, light=CREAM):
    """Wraps a landscape with grain, a world plate, and the emblem."""
    plate = (f'<g transform="translate(56 {height - 56})">'
             f'<rect x="0" y="-104" width="470" height="104" rx="22" fill="{ink}" opacity="0.82"/>'
             f'<circle cx="52" cy="-52" r="38" fill="{world["color"]}"/>'
             f'{emblem(world["emblem"], 52, -52, 52, light)}'
             f'<text x="108" y="-60" font-family="\'Martian Mono\', monospace" font-size="15" letter-spacing="3" fill="{world["color"]}">WORLD {world["number"]} · {world["orion"].upper()}</text>'
             f'<text x="106" y="-22" font-family="\'Bagel Fat One\', sans-serif" font-size="38" fill="{light}">{world["name"]}</text></g>')
    defs = f'<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">{"".join(f"<stop offset=\'{offset}\' stop-color=\'{color}\'/>" for offset, color in sky)}</linearGradient>'
    defs += '<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="30"/></filter>'
    defs += '<filter id="haze" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation="2"/></filter>'
    body = f'<g filter="url(#paper)"><rect width="{width}" height="{height}" fill="url(#sky)"/><g filter="url(#wobble)">{art}</g>{plate}</g>'
    page("world-" + world["id"], width, height, sky[-1][1], "family=Bagel+Fat+One&family=Martian+Mono", body, defs)


W, H = 1600, 900


def swirlheart(world):
    sun = (f'<g transform="translate(1080 300)"><circle r="300" fill="#fff1a8" opacity="0.5" filter="url(#soft)"/>'
           f'<g transform="scale(2.6)">' + "".join(f'<path d="{SPIRAL_ARM}" transform="rotate({angle})" fill="{color}"/>' for angle, color in ((0, "#ff3d6e"), (120, "#ff9f45"), (240, "#ff8fd0"))) +
           '<circle r="36" fill="#ffd84a"/></g></g>')
    temple = (f'<g transform="translate(420 610)"><path d="M-120 0 L-120 -150 Q0 -230 120 -150 L120 0 Z" fill="#fff0cf"/>'
              f'<path d="M-36 0 L-36 -70 Q0 -110 36 -70 L36 0 Z" fill="#7a2c3c"/>'
              f'{emblem("spiral", 0, -170, 70, "#ff3d6e")}'
              f'<rect x="-150" y="-6" width="300" height="20" rx="10" fill="#ffb02e"/></g>')
    art = (sun + sparkles(5, 40, W, 300, CREAM, 3, 8)
           + f'<path d="{ridge(W, 560, 50, 1.2)}" fill="#ffb877"/>'
           + f'<path d="{ridge(W, 640, 40, 2.5)}" fill="#ff9f45"/>'
           + temple
           + "".join(lollipop(x, 700 + (x % 3) * 10, 120 + (x % 5) * 14, c) for x, c in ((180, "#ff3d6e"), (640, "#ff8fd0"), (760, "#ffd84a"), (1360, "#ff3d6e"), (1480, "#ff8fd0")))
           + f'<path d="{ridge(W, 760, 30, 4.1)}" fill="#e8742a"/>'
           + f'<path d="M560 900 C600 820 760 800 800 760" fill="none" stroke="#fff0cf" stroke-width="26" stroke-linecap="round" stroke-dasharray="2 40"/>'
           + companion(860, 700, 46, "happy", outline=INK, outline_width=0.04, pose="wave"))
    frame(world, W, H, art, [(0, "#ff8fa8"), (0.5, "#ffc38a"), (1, "#ffe6a6")])


def ringwell(world):
    ring = ('<g transform="translate(800 980) rotate(-8)"><ellipse rx="1300" ry="760" fill="none" stroke="#bfe6ff" stroke-width="60" opacity="0.85"/>'
            '<ellipse rx="1300" ry="760" fill="none" stroke="#ff8fd0" stroke-width="16" opacity="0.7"/><ellipse rx="1230" ry="700" fill="none" stroke="#e8f6ff" stroke-width="10" opacity="0.6"/></g>')
    waves = "".join(f'<path d="{ridge(W, base, amplitude, seed, 6, (0.012, 0.03, 0.06))}" fill="{color}" opacity="{opacity}"/>' for base, amplitude, seed, color, opacity in ((600, 14, 0.3, "#5aa4ff", 0.9), (660, 18, 1.9, "#3b7dff", 0.9), (740, 22, 3.3, "#2a5fe0", 0.95), (820, 26, 5.1, "#1f47b8", 1)))
    lighthouse = (f'<g transform="translate(1230 640)"><path d="M-110 30 Q0 -30 110 30 Z" fill="#7be1c8"/>'
                  f'<path d="M-34 0 L-24 -230 L24 -230 L34 0 Z" fill="{CREAM}"/>'
                  + "".join(f'<rect x="-30" y="{y}" width="60" height="22" fill="#ff8fd0"/>' for y in (-60, -130, -200))
                  + f'<circle cy="-260" r="36" fill="#ffd84a"/><circle cy="-260" r="110" fill="#ffd84a" opacity="0.25" filter="url(#soft)"/>'
                  + f'{emblem("ring", 0, -312, 70, CREAM, accent="#2e7dff")}</g>')
    jelly = "".join(f'<g transform="translate({x} {y})"><path d="M-30 0 C-30 -40 30 -40 30 0 Z" fill="#c9a6ff" opacity="0.7"/><path d="M-20 0 q4 30 0 40 M0 0 q-4 30 0 46 M20 0 q4 30 0 40" fill="none" stroke="#c9a6ff" stroke-width="5" opacity="0.6"/></g>' for x, y in ((300, 700), (520, 780), (980, 760)))
    art = (sparkles(17, 70, W, 520, CREAM, 3, 9) + ring
           + '<g transform="translate(300 220)"><circle r="70" fill="#ffd84a" opacity="0.9"/><circle cx="20" cy="-8" r="70" fill="#1a3f9e" opacity="0.0"/></g>'
           + waves + lighthouse + jelly
           + f'<g transform="translate(640 650)"><ellipse rx="70" ry="16" fill="#ff9f45"/><path d="M0 -6 L0 -80 L46 -20 Z" fill="{CREAM}"/></g>'
           + companion(640, 590, 34, "pip", outline=INK, outline_width=0.05, pose="float", tilt=-6))
    frame(world, W, H, art, [(0, "#0f1a5a"), (0.55, "#3b6cff"), (1, "#8fd0ff")])


def gumdrop_highlands(world):
    windmill = (f'<g transform="translate(1180 420)"><path d="M-40 160 L-26 0 L26 0 L40 160 Z" fill="{CREAM}"/><path d="M-34 0 Q0 -50 34 0 Z" fill="#ff3d6e"/>'
                + "".join(f'<rect x="-8" y="-120" width="16" height="110" rx="6" fill="#ffd84a" transform="rotate({angle} 0 -10)"/>' for angle in (20, 110, 200, 290))
                + f'<circle cy="-10" r="12" fill="#ff3d6e"/></g>')
    houses = "".join(f'<g transform="translate({x} {y})"><rect x="-26" y="-36" width="52" height="36" fill="{CREAM}"/><path d="M-34 -34 C-34 -70 34 -70 34 -34 Z" fill="{c}"/><rect x="-7" y="-20" width="14" height="20" fill="#2d7a1f"/></g>' for x, y, c in ((380, 640, "#ff3d6e"), (450, 655, "#ffd84a"), (930, 700, "#8b3dff")))
    sign = f'<g transform="translate(240 760)"><rect x="-6" y="-80" width="12" height="80" fill="#8a5a2a"/><rect x="-60" y="-140" width="120" height="70" rx="12" fill="#8a5a2a"/>{emblem("gumdrop", 0, -105, 44, "#7be14a")}</g>'
    art = (sparkles(23, 30, W, 300, CREAM, 3, 8)
           + '<circle cx="380" cy="190" r="80" fill="#fff6c2"/>'
           + domes(W, 520, 3, 7, 160, "#bfe8a4")
           + domes(W, 600, 7, 6, 170, "#8fd66a", "#ffffff")
           + windmill + houses
           + domes(W, 720, 11, 5, 180, "#5cc93a", "#ffffff")
           + f'<path d="M0 860 C300 800 500 840 800 790 C1100 740 1300 790 1600 760 L1600 900 L0 900 Z" fill="#3fa52a"/>'
           + "".join(f'<path d="M{x} 880 C{x} 820 {x + 50} 790 {x + 80} 790 C{x + 110} 790 {x + 160} 820 {x + 160} 880 Z" fill="{c}" stroke="{INK}" stroke-width="4"/>' for x, c in ((560, "#ff3d6e"), (1300, "#ffd84a"), (1420, "#8b3dff")))
           + sign
           + companion(760, 700, 48, "starry", outline=INK, outline_width=0.04, pose="cheer"))
    frame(world, W, H, art, [(0, "#7fd0ff"), (0.6, "#c8f0ff"), (1, "#fff6c2")])


def noodle_reach(world):
    islands = [(260, 420, 220), (720, 300, 260), (1180, 460, 240), (1440, 260, 160), (520, 640, 180)]
    bridges = []
    for (ax, ay, aw), (bx, by, bw) in ((islands[0], islands[1]), (islands[1], islands[2]), (islands[2], islands[3]), (islands[0], islands[4]), (islands[4], islands[2])):
        start = (ax + aw * 0.35, ay)
        end = (bx - bw * 0.35, by)
        sag = max(start[1], end[1]) + 90
        bridges.append(f'<path d="M{fmt(start[0])} {fmt(start[1])} Q{fmt((start[0] + end[0]) / 2)} {fmt(sag)} {fmt(end[0])} {fmt(end[1])}" fill="none" stroke="#1a0a2e" stroke-width="16" stroke-linecap="round"/>')
        bridges.append(f'<path d="M{fmt(start[0])} {fmt(start[1])} Q{fmt((start[0] + end[0]) / 2)} {fmt(sag)} {fmt(end[0])} {fmt(end[1])}" fill="none" stroke="#e24a8a" stroke-width="7" stroke-linecap="round" stroke-dasharray="14 10"/>')
        middle = ((start[0] + end[0]) / 2, (start[1] + end[1]) / 4 + sag / 2)
        bridges.append(f'<circle cx="{fmt(middle[0])}" cy="{fmt(middle[1] - 6)}" r="10" fill="#ffd84a"/><circle cx="{fmt(middle[0])}" cy="{fmt(middle[1] - 6)}" r="30" fill="#ffd84a" opacity="0.25" filter="url(#haze)"/>')
    gate = f'<g transform="translate(720 300)"><path d="M-70 0 L-70 -120 M70 0 L70 -120" stroke="#1a0a2e" stroke-width="18"/><path d="M-96 -120 H96" stroke="#e24a8a" stroke-width="20" stroke-linecap="round"/>{emblem("knot", 0, -170, 80, CREAM, "#1a0a2e", 4)}</g>'
    lanterns = "".join(f'<g transform="translate({x} {y})"><path d="M0 -40 V0" stroke="#1a0a2e" stroke-width="3"/><ellipse rx="14" ry="18" fill="#ffd84a"/><circle r="40" fill="#ffd84a" opacity="0.2"/></g>' for x, y in ((1150, 440), (1210, 440), (300, 400)))
    art = (sparkles(31, 110, W, H, CREAM, 2, 9)
           + '<g transform="translate(1340 140)"><circle r="54" fill="#d9c7ff"/><circle cx="-20" cy="-10" r="54" fill="#2b1060"/></g>'
           + f'<path d="{ridge(W, 820, 40, 2.2)}" fill="#2b1060" opacity="0.8"/>'
           + "".join(bridges)
           + "".join(island(x, y, w, "#a77bff", "#4a1d9e") for x, y, w in islands)
           + gate + lanterns
           + companion(560, 590, 40, "determined", outline=INK, outline_width=0.045, pose="rest"))
    frame(world, W, H, art, [(0, "#0d0626"), (0.6, "#3a1580"), (1, "#7a3dd6")])


def cotton_shoals(world):
    def puff(x, y, size, color, shade):
        bumps = [(-0.6, 0.1, 0.42), (-0.25, -0.18, 0.5), (0.18, -0.25, 0.56), (0.55, 0.0, 0.44), (0.0, 0.12, 0.5)]
        out = [f'<ellipse cx="{fmt(x)}" cy="{fmt(y + size * 0.3)}" rx="{fmt(size * 1.0)}" ry="{fmt(size * 0.22)}" fill="{shade}"/>']
        out += [f'<circle cx="{fmt(x + dx * size)}" cy="{fmt(y + dy * size)}" r="{fmt(r * size)}" fill="{color}"/>' for dx, dy, r in bumps]
        return "".join(out)
    balloons = "".join(f'<g transform="translate({x} {y})"><path d="M-40 0 C-40 -60 40 -60 40 0 C40 30 10 50 0 60 C-10 50 -40 30 -40 0 Z" fill="{c}"/><path d="M-10 60 L-12 90 M10 60 L12 90" stroke="{INK}" stroke-width="2"/><rect x="-14" y="88" width="28" height="18" rx="4" fill="#8a5a2a"/></g>' for x, y, c in ((380, 200, "#ffd84a"), (1240, 160, "#7be14a"), (1420, 330, "#8fd0ff")))
    notes = "".join(f'<g transform="translate({x} {y}) rotate({r})"><rect x="-34" y="-26" width="68" height="52" rx="6" fill="{CREAM}"/><path d="M-22 -10 H22 M-22 4 H14" stroke="#c23c8a" stroke-width="4" stroke-linecap="round"/></g>' for x, y, r in ((560, 330, -12), (700, 250, 8), (980, 300, -6), (1100, 400, 14)))
    art = (sparkles(43, 50, W, 400, CREAM, 3, 8)
           + puff(260, 620, 220, "#ffd1ea", "#e8a6cf")
           + puff(1200, 560, 260, "#ffc0e2", "#e09ac6")
           + puff(760, 700, 300, "#ffe0f0", "#eab0d6")
           + balloons + notes
           + f'<g transform="translate(1200 400)">{emblem("cloud", 0, 0, 120, CREAM, "#c23c8a", 4, "#ff7fc4")}</g>'
           + puff(140, 860, 260, "#fff0f8", "#f2c4e0") + puff(1500, 880, 280, "#fff0f8", "#f2c4e0")
           + companion(760, 520, 52, "sleepy", outline=INK, outline_width=0.04, pose="float", tilt=12)
           + '<text x="812" y="460" font-family="Bagel Fat One, sans-serif" font-size="30" fill="#c23c8a">z</text><text x="836" y="430" font-family="Bagel Fat One, sans-serif" font-size="22" fill="#c23c8a">z</text>')
    frame(world, W, H, art, [(0, "#b48cff"), (0.5, "#ffb0d8"), (1, "#ffe6c8")])


def taffy_belt(world):
    candy_colors = ["#ff3d6e", "#ffd84a", "#7be14a", "#2e7dff", "#ff9f45", "#8b3dff"]
    state = 5
    drifting = []
    for index in range(26):
        state = (state * 1103515245 + 12345) % 2**31
        x = state % W
        state = (state * 1103515245 + 12345) % 2**31
        y = 120 + state % 420
        size = 26 + state % 40
        drifting.append(emblem("candy", x, y, size, CREAM, INK, 0, candy_colors[index % 6]).replace("<g ", f'<g opacity="{0.55 + (state % 40) / 100}" ', 1))
    rocks = "".join(f'<path d="M{x - s} {y} C{x - s} {y - s * 0.9} {x + s * 0.6} {y - s} {x + s} {y - s * 0.3} C{x + s * 1.2} {y + s * 0.4} {x} {y + s * 0.8} {x - s} {y} Z" fill="{c}"/>' for x, y, s, c in ((240, 360, 70, "#6b3a5a"), (1380, 260, 90, "#5a2f4f"), (980, 180, 40, "#6b3a5a")))
    outpost = (f'<g transform="translate(900 640)"><path d="M-260 60 C-260 -40 260 -40 260 60 Z" fill="#7a3d5f"/>'
               f'<path d="M-120 -10 L-120 -150 Q0 -220 120 -150 L120 -10 Z" fill="#ffd2a8"/><rect x="-80" y="-110" width="160" height="40" rx="20" fill="#2a1030"/>'
               f'<path d="M-180 -10 L-180 -200 M180 -10 L180 -170" stroke="#2a1030" stroke-width="10"/>'
               f'<path d="M-180 -200 L-120 -186 L-180 -170 Z" fill="#ff3d6e"/><path d="M180 -170 L240 -156 L180 -140 Z" fill="#ffd84a"/>'
               f'{emblem("candy", 0, -240, 120, CREAM, INK, 4, "#ff3d6e")}'
               f'<path d="M-260 40 Q-500 10 -700 80" fill="none" stroke="#2a1030" stroke-width="14"/>'
               + "".join(f'<g transform="translate({-320 - i * 80} {32 + i * 9})">{emblem("candy", 0, 0, 44, CREAM, INK, 3, candy_colors[i])}</g>' for i in range(5))
               + "</g>")
    art = (sparkles(61, 140, W, H, CREAM, 2, 8)
           + '<g transform="translate(800 980) rotate(-6)"><ellipse rx="1100" ry="420" fill="none" stroke="#ff8fd0" stroke-width="3" opacity="0.4" stroke-dasharray="4 12"/></g>'
           + rocks + "".join(drifting)
           + f'<path d="{ridge(W, 760, 36, 0.8)}" fill="#4a2340"/>'
           + outpost
           + f'<path d="{ridge(W, 830, 26, 2.9)}" fill="#2a1030"/>'
           + companion(1280, 700, 44, "surprised", outline=INK, outline_width=0.045, pose="cheer"))
    frame(world, W, H, art, [(0, "#120a24"), (0.6, "#3a1440"), (1, "#7a2c5a")])


def geode_moon(world):
    def shard(x, y, height, width, color, glow=False, tilt=0):
        out = f'<g transform="translate({x} {y}) rotate({tilt})">'
        if glow:
            out += f'<ellipse cy="{-height * 0.5}" rx="{width * 1.6}" ry="{height * 0.7}" fill="{color}" opacity="0.25" filter="url(#soft)"/>'
        out += f'<path d="M{-width} 0 L{-width} {-height * 0.75} L0 {-height} L{width} {-height * 0.75} L{width} 0 Z" fill="{color}"/>'
        out += f'<path d="M0 {-height} L0 0 L{width} 0 L{width} {-height * 0.75} Z" fill="#ffffff" opacity="0.22"/></g>'
        return out
    tower = (f'<g transform="translate(1160 640)"><path d="M-70 0 L-50 -300 L0 -380 L50 -300 L70 0 Z" fill="#cfe9ff"/>'
             f'<path d="M0 -380 L50 -300 L70 0 L0 0 Z" fill="#9fc8ff"/>'
             + "".join(f'<rect x="-14" y="{y}" width="28" height="36" rx="14" fill="#ffd84a" opacity="0.9"/>' for y in (-120, -200, -270))
             + f'{emblem("crystal", 0, -460, 100, "#e8f6ff", INK, 4, "#8fd0ff")}</g>')
    archive = "".join(f'<g transform="translate({x} {y}) rotate({r})"><rect x="-30" y="-22" width="60" height="44" rx="8" fill="#bfe0ff" opacity="0.85"/><path d="M-14 0 l8 8 l18 -18" fill="none" stroke="#3b6cff" stroke-width="5" stroke-linecap="round"/></g>' for x, y, r in ((440, 720, -8), (520, 760, 6), (600, 730, -3)))
    art = (sparkles(73, 120, W, 600, "#e8f6ff", 2, 9)
           + '<g transform="translate(400 210)"><circle r="120" fill="#ffd2a8" opacity="0.4" filter="url(#soft)"/><g transform="scale(0.9)">' + "".join(f'<path d="{SPIRAL_ARM}" transform="rotate({angle})" fill="{color}" opacity="0.85"/>' for angle, color in ((0, "#ff3d6e"), (120, "#ff9f45"), (240, "#ff8fd0"))) + '<circle r="34" fill="#ffd84a"/></g></g>'
           + f'<path d="{ridge(W, 600, 30, 1.4)}" fill="#3a4a9a"/>'
           + "".join(shard(x, 620, h, w, "#7aa8ff", glow, tilt) for x, h, w, glow, tilt in ((120, 200, 30, False, -10), (230, 280, 40, True, 6), (1430, 260, 36, True, -6), (1530, 180, 26, False, 12)))
           + tower
           + f'<path d="{ridge(W, 720, 24, 3.6)}" fill="#26306e"/>'
           + "".join(shard(x, 820, h, w, c, g, t) for x, h, w, c, g, t in ((80, 260, 46, "#8fd0ff", True, -4), (200, 160, 30, "#c9a6ff", False, 10), (1350, 220, 40, "#c9a6ff", True, 4), (1480, 300, 52, "#8fd0ff", True, -8)))
           + f'<path d="{ridge(W, 830, 18, 5.2)}" fill="#141a44"/>'
           + archive
           + companion(760, 740, 44, "sleepy", outline=INK, outline_width=0.045, pose="hug"))
    frame(world, W, H, art, [(0, "#06081e"), (0.6, "#1a2466"), (1, "#3b4fb0")])


def galaxy_map():
    """The overworld: a spiral galaxy with every world on a dotted route out from the sun."""
    width, height = 1920, 1200
    cx, cy = 960, 610
    arms = []
    for arm in range(3):
        for step in range(220):
            t = step / 220
            angle = arm * 2 * math.pi / 3 + t * 4.2
            radius = 60 + t * 640
            x = cx + radius * math.cos(angle)
            y = cy + radius * math.sin(angle) * 0.62
            color = ["#ff8fd0", "#8fd0ff", "#c9a6ff"][(arm + step) % 3]
            arms.append(f'<circle cx="{fmt(x)}" cy="{fmt(y)}" r="{fmt(2 + (1 - t) * 8)}" fill="{color}" opacity="{fmt(0.18 + (1 - t) * 0.3)}"/>')
    positions = [(cx, cy), (1290, 380), (1440, 760), (1010, 960), (520, 880), (430, 420), (820, 210)]
    route = " ".join(("M" if index == 0 else "L") + f"{x} {y}" for index, (x, y) in enumerate(positions))
    planets = []
    for world, (x, y) in zip(WORLDS, positions):
        radius = 120 if world["id"] == "swirlheart" else 74
        planets.append(f'<circle cx="{x}" cy="{y}" r="{radius * 1.7}" fill="{world["color"]}" opacity="0.22" filter="url(#soft)"/>')
        if world["id"] == "swirlheart":
            planets.append(f'<g transform="translate({x} {y}) scale(1.4)">' + "".join(f'<path d="{SPIRAL_ARM}" transform="rotate({angle})" fill="{color}"/>' for angle, color in ((0, "#ff3d6e"), (120, "#ff9f45"), (240, "#ff8fd0"))) + '<circle r="36" fill="#ffd84a"/></g>')
        else:
            planets.append(f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{world["color"]}"/>')
            planets.append(f'<path d="M{x - radius} {y} A{radius} {radius} 0 0 0 {x + radius} {y} C{x + radius * 0.6} {y + radius * 0.35} {x - radius * 0.6} {y + radius * 0.35} {x - radius} {y} Z" fill="{world["dark"]}" opacity="0.5"/>')
            planets.append(f'<ellipse cx="{x - radius * 0.35}" cy="{y - radius * 0.45}" rx="{radius * 0.28}" ry="{radius * 0.16}" fill="#fff" opacity="0.45" transform="rotate(-30 {x - radius * 0.35} {y - radius * 0.45})"/>')
            planets.append(emblem(world["emblem"], x, y, radius * 1.05, CREAM))
        label_y = y + radius + 54
        planets.append(f'<g transform="translate({x} {label_y})"><rect x="-130" y="-30" width="260" height="62" rx="31" fill="{INK}" opacity="0.85"/>'
                       f'<text y="-4" text-anchor="middle" font-family="\'Martian Mono\', monospace" font-size="12" letter-spacing="3" fill="{world["color"]}">{world["number"]} · {world["orion"].upper()}</text>'
                       f'<text y="22" text-anchor="middle" font-family="\'Bagel Fat One\', sans-serif" font-size="24" fill="{CREAM}">{world["name"]}</text></g>')
    defs = '<radialGradient id="space" cx="0.5" cy="0.5" r="0.7"><stop offset="0" stop-color="#3a1f8f"/><stop offset="0.5" stop-color="#161044"/><stop offset="1" stop-color="#07061a"/></radialGradient>'
    defs += '<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="30"/></filter>'
    body = f"""<g filter="url(#paper)">
<rect width="{width}" height="{height}" fill="url(#space)"/>
{sparkles(99, 260, width, height, CREAM, 2, 9)}
{"".join(arms)}
<path d="{route}" fill="none" stroke="{CREAM}" stroke-width="6" stroke-dasharray="2 18" stroke-linecap="round" opacity="0.8"/>
{"".join(planets)}
{companion(1150, 520, 40, "happy", outline=INK, outline_width=0.05, pose="wave", tilt=-10)}
<text x="70" y="104" font-family="'Bagel Fat One', sans-serif" font-size="64" fill="{CREAM}">Gummy Galaxy</text>
<text x="74" y="146" font-family="'Martian Mono', monospace" font-size="16" letter-spacing="5" fill="#ffd84a">WORLD MAP · SEVEN WORLDS · ONE ORBIT</text>
<g transform="translate(1600 1110)"><rect x="-10" y="-40" width="290" height="70" rx="35" fill="{INK}" opacity="0.85"/><text x="135" y="4" text-anchor="middle" font-family="'Martian Mono', monospace" font-size="16" fill="{CREAM}">★ 212 / 400  ·  ◆ 7</text></g>
</g>"""
    page("galaxy-map", width, height, "#07061a", "family=Bagel+Fat+One&family=Martian+Mono", body, defs)


def emblem_sheet():
    """Every world's symbol as a gummy medal, a flat mark, and a one-line meaning."""
    width, height = 1920, 1240
    defs = "".join(f'<radialGradient id="medal-{w["id"]}" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="{mix(w["color"], "#ffffff", 0.45)}"/><stop offset="0.6" stop-color="{w["color"]}"/><stop offset="1" stop-color="{w["dark"]}"/></radialGradient>' for w in WORLDS)
    cells = []
    for index, world in enumerate(WORLDS):
        column, row = index % 4, index // 4
        x = 270 + column * 460 + (230 if row == 1 else 0)
        y = 400 + row * 520
        cells.append(f'<ellipse cx="{x}" cy="{y + 150}" rx="120" ry="16" fill="{INK}" opacity="0.18"/>')
        cells.append(f'<circle cx="{x}" cy="{y}" r="140" fill="{world["dark"]}"/>')
        cells.append(f'<circle cx="{x}" cy="{y - 8}" r="136" fill="url(#medal-{world["id"]})"/>')
        cells.append(f'<circle cx="{x}" cy="{y - 8}" r="112" fill="none" stroke="{CREAM}" stroke-width="4" stroke-dasharray="3 10" stroke-linecap="round" opacity="0.7"/>')
        cells.append(emblem(world["emblem"], x, y - 8, 150, CREAM, world["dark"], 0))
        cells.append(f'<ellipse cx="{x - 50}" cy="{y - 90}" rx="44" ry="20" fill="#fff" opacity="0.45" transform="rotate(-30 {x - 50} {y - 90})"/>')
        cells.append(f'<g transform="translate({x + 120} {y + 100})"><circle r="34" fill="{CREAM}" stroke="{INK}" stroke-width="3"/>{emblem(world["emblem"], 0, 0, 44, INK)}</g>')
        cells.append(f'<text x="{x}" y="{y + 196}" text-anchor="middle" font-family="\'Bagel Fat One\', sans-serif" font-size="34" fill="{INK}">{world["name"]}</text>')
        cells.append(f'<text x="{x}" y="{y + 228}" text-anchor="middle" font-family="\'Martian Mono\', monospace" font-size="14" letter-spacing="3" fill="{world["dark"]}">{world["flavor"].upper()} → {world["orion"].upper()}</text>')
    body = f"""<g filter="url(#paper)">
<rect width="{width}" height="{height}" fill="#f6efe2"/>
<text x="80" y="110" font-family="'Bagel Fat One', sans-serif" font-size="60" fill="{INK}">World Emblems</text>
<text x="82" y="150" font-family="'Martian Mono', monospace" font-size="16" letter-spacing="4" fill="#8a6a9a">EACH WORLD LEAVES ONE SYMBOL BEHIND · MEDAL AND FLAT MARK</text>
{"".join(cells)}
</g>"""
    page("emblem-sheet", width, height, "#f6efe2", "family=Bagel+Fat+One&family=Martian+Mono", body, defs)


def platformer():
    """A gameplay mock: Gumdrop Highlands as a side-scroller where cards are collectibles and links are bridges."""
    width, height = 1600, 900
    world = WORLDS[2]

    def card(x, y, label, color, done=False):
        check = '<path d="M-38 2 l8 8 l14 -16" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round"/>' if done else ""
        return (f'<g transform="translate({x} {y})"><rect x="-70" y="-30" width="140" height="60" rx="12" fill="{CREAM}" stroke="{INK}" stroke-width="4"/>'
                f'<rect x="-58" y="-18" width="36" height="36" rx="8" fill="{color}"/>{check}'
                f'<rect x="-12" y="-12" width="70" height="9" rx="4.5" fill="{INK}" opacity="0.6"/><rect x="-12" y="4" width="46" height="9" rx="4.5" fill="{INK}" opacity="0.35"/>'
                f'<circle cy="0" r="86" fill="#ffd84a" opacity="0.18"/></g>')
    platforms = [(80, 700, 380), (560, 600, 240), (920, 500, 220), (1230, 640, 330)]
    ground = "".join(f'<g><rect x="{x}" y="{y}" width="{w}" height="{900 - y}" fill="#3fa52a"/><path d="M{x} {y} h{w}" stroke="#bfe8a4" stroke-width="16" stroke-linecap="round"/>'
                     + "".join(f'<circle cx="{x + 20 + i * 36}" cy="{y + 40 + (i % 3) * 30}" r="5" fill="#fff" opacity="0.5"/>' for i in range(w // 36))
                     + "</g>" for x, y, w in platforms)
    bridges = ""
    for (ax, ay, aw), (bx, by, bw) in zip(platforms, platforms[1:]):
        start, end = (ax + aw, ay), (bx, by)
        sag = max(ay, by) + 60
        bridges += f'<path d="M{start[0]} {start[1]} Q{(start[0] + end[0]) / 2} {sag} {end[0]} {end[1]}" fill="none" stroke="#e24a8a" stroke-width="12" stroke-linecap="round"/>'
    hud = (f'<g font-family="\'Martian Mono\', monospace" font-weight="600">'
           f'<g transform="translate(40 40)"><rect width="330" height="74" rx="37" fill="{INK}" opacity="0.85"/><circle cx="37" cy="37" r="26" fill="{world["color"]}"/>{emblem("gumdrop", 37, 37, 34, CREAM)}<text x="80" y="32" font-size="13" letter-spacing="3" fill="{world["color"]}">WORLD 3-2</text><text x="80" y="56" font-family="\'Bagel Fat One\', sans-serif" font-size="22" fill="{CREAM}">Sugar Terraces</text></g>'
           f'<g transform="translate(1250 40)"><rect width="310" height="74" rx="37" fill="{INK}" opacity="0.85"/>{four_point(42, 37, 22, "#ffd84a")}<text x="74" y="46" font-size="24" fill="{CREAM}">12 / 18</text><rect x="196" y="22" width="92" height="30" rx="15" fill="#5cc93a"/><text x="242" y="43" text-anchor="middle" font-size="14" fill="{INK}">READY 4</text></g>'
           f'<g transform="translate(40 820)"><rect width="520" height="46" rx="23" fill="{INK}" opacity="0.7"/><text x="24" y="30" font-size="14" fill="{CREAM}">←→ MOVE   SPACE HOP   E COLLECT   TAB MAP</text></g></g>')
    body = f"""<g filter="url(#paper)">
<rect width="{width}" height="{height}" fill="url(#sky)"/>
<circle cx="1300" cy="200" r="90" fill="#fff6c2"/>
{domes(width, 520, 3, 7, 140, "#d4f0bf")}
{domes(width, 600, 9, 6, 150, "#a6e08a", "#ffffff")}
{bridges}
{ground}
{card(640, 470, "", "#5cc93a")}{card(1030, 370, "", "#ffd84a")}{card(1400, 520, "", "#5cc93a")}
<g opacity="0.55">{card(270, 590, "", "#5cc93a", True)}</g>
{companion(420, 600, 46, "happy", outline=INK, outline_width=0.045, pose="cheer", tilt=-8)}
<g fill="#ffd84a">{four_point(370, 560, 12, "#ffd84a")}{four_point(470, 540, 9, "#ffd84a")}{four_point(440, 650, 7, "#ffd84a")}</g>
<path d="M330 690 q30 -30 60 0 q30 -30 60 0" fill="none" stroke="{CREAM}" stroke-width="4" stroke-linecap="round" opacity="0.7"/>
{hud}
</g>"""
    defs = '<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7fd0ff"/><stop offset="0.7" stop-color="#d8f4ff"/><stop offset="1" stop-color="#fff6c2"/></linearGradient>'
    page("platformer", width, height, "#7fd0ff", "family=Bagel+Fat+One&family=Martian+Mono:wght@600", body, defs)


if __name__ == "__main__":
    for builder, world in zip((swirlheart, ringwell, gumdrop_highlands, noodle_reach, cotton_shoals, taffy_belt, geode_moon), WORLDS):
        builder(world)
    galaxy_map()
    emblem_sheet()
    platformer()
    print("wrote", len(WORLDS) + 3, "pieces")
