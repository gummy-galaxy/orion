"""Draws the Orion companion as SVG and writes the 2D concept pieces that star it.

Usage: companion.py  (writes every piece's HTML next to this file)
"""
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))

# Proportions from CompanionStar.tsx, as fractions of the body star's half height.
HORIZONTAL = 104 / 182
WAIST = 30 / 182
CORE = 66 / 182
SIDE_SIZE = 0.45
SIDE_CORE = 46 / 182

SIDE_POSES = {
    "rest": [(-0.94, 0.375), (0.94, 0.375)],
    "wave": [(-0.94, 0.375), (1.0, -0.42)],
    "cheer": [(-0.92, -0.46), (0.92, -0.46)],
    "hug": [(-0.62, 0.62), (0.62, 0.62)],
    "float": [(-1.02, 0.1), (1.0, 0.24)],
    "none": [],
}


def fmt(value):
    return f"{value:.1f}".rstrip("0").rstrip(".")


def star_path(cx, cy, size, waist=WAIST):
    horizontal, pinch = size * HORIZONTAL, size * waist
    points = [(0, -size), (pinch, -pinch), (horizontal, 0), (pinch, pinch), (0, size), (-pinch, pinch), (-horizontal, 0), (-pinch, -pinch)]
    return "M" + " L".join(f"{fmt(cx + x)} {fmt(cy + y)}" for x, y in points) + " Z"


def four_point(cx, cy, size, fill, extra=""):
    """A plain sparkle, used for stars in the sky and for star-shaped eyes."""
    return f'<path d="{star_path(cx, cy, size, 0.22)}" fill="{fill}" {extra}/>'


def face(s, mood, ink, cheek, cheeks):
    eye_x, eye_y, eye_r = 0.128 * s, -0.04 * s, 0.054 * s
    parts = []
    stroke = f'fill="none" stroke="{ink}" stroke-width="{fmt(0.034 * s)}" stroke-linecap="round" stroke-linejoin="round"'

    def dots(radius=eye_r, glint=True):
        out = []
        for side in (-1, 1):
            out.append(f'<circle cx="{fmt(side * eye_x)}" cy="{fmt(eye_y)}" r="{fmt(radius)}" fill="{ink}"/>')
            if glint:
                out.append(f'<circle cx="{fmt(side * eye_x + radius * 0.38)}" cy="{fmt(eye_y - radius * 0.4)}" r="{fmt(radius * 0.36)}" fill="#fff"/>')
        return out

    def arc(side, up=True):
        x0, x1 = side * eye_x - eye_r * 1.2, side * eye_x + eye_r * 1.2
        lift = -eye_r * 1.5 if up else eye_r * 1.5
        return f'<path d="M{fmt(x0)} {fmt(eye_y + eye_r * 0.4)} Q{fmt(side * eye_x)} {fmt(eye_y + eye_r * 0.4 + lift)} {fmt(x1)} {fmt(eye_y + eye_r * 0.4)}" {stroke}/>'

    mouth_y = 0.07 * s
    smile = f'<path d="M{fmt(-0.045 * s)} {fmt(mouth_y)} Q0 {fmt(mouth_y + 0.05 * s)} {fmt(0.045 * s)} {fmt(mouth_y)}" {stroke}/>'
    open_smile = f'<path d="M{fmt(-0.06 * s)} {fmt(mouth_y - 0.006 * s)} Q0 {fmt(mouth_y + 0.09 * s)} {fmt(0.06 * s)} {fmt(mouth_y - 0.006 * s)} Z" fill="{ink}"/>'

    if mood == "pip":
        parts += dots() + [smile]
    elif mood == "happy":
        parts += [arc(-1), arc(1), open_smile]
    elif mood == "surprised":
        parts += dots(eye_r * 1.3) + [f'<ellipse cx="0" cy="{fmt(mouth_y + 0.02 * s)}" rx="{fmt(0.03 * s)}" ry="{fmt(0.04 * s)}" fill="{ink}"/>']
    elif mood == "sleepy":
        parts += [arc(-1, False), arc(1, False), f'<path d="M{fmt(-0.03 * s)} {fmt(mouth_y + 0.01 * s)} L{fmt(0.03 * s)} {fmt(mouth_y + 0.01 * s)}" {stroke}/>']
    elif mood == "determined":
        parts += dots()
        for side in (-1, 1):
            parts.append(f'<path d="M{fmt(side * (eye_x + eye_r * 1.3))} {fmt(eye_y - eye_r * 2.6)} L{fmt(side * (eye_x - eye_r * 1.1))} {fmt(eye_y - eye_r * 1.7)}" {stroke}/>')
        parts.append(f'<path d="M{fmt(-0.04 * s)} {fmt(mouth_y + 0.01 * s)} L{fmt(0.04 * s)} {fmt(mouth_y + 0.01 * s)}" {stroke}/>')
    elif mood == "sad":
        parts += dots()
        parts.append(f'<path d="M{fmt(-0.04 * s)} {fmt(mouth_y + 0.035 * s)} Q0 {fmt(mouth_y - 0.01 * s)} {fmt(0.04 * s)} {fmt(mouth_y + 0.035 * s)}" {stroke}/>')
        parts.append(f'<path d="M{fmt(eye_x + eye_r * 0.4)} {fmt(eye_y + eye_r * 1.4)} q{fmt(-eye_r * 0.7)} {fmt(eye_r * 1.4)} 0 {fmt(eye_r * 2)} q{fmt(eye_r * 0.7)} {fmt(-eye_r * 0.6)} 0 {fmt(-eye_r * 2)} Z" fill="#7cc8ff"/>')
    elif mood == "love":
        for side in (-1, 1):
            x, y, r = side * eye_x, eye_y, eye_r * 1.25
            parts.append(f'<path d="M{fmt(x)} {fmt(y + r * 0.9)} C{fmt(x - r * 1.6)} {fmt(y - r * 0.2)} {fmt(x - r * 0.7)} {fmt(y - r * 1.4)} {fmt(x)} {fmt(y - r * 0.5)} C{fmt(x + r * 0.7)} {fmt(y - r * 1.4)} {fmt(x + r * 1.6)} {fmt(y - r * 0.2)} {fmt(x)} {fmt(y + r * 0.9)} Z" fill="#ff3d6e"/>')
        parts.append(open_smile)
    elif mood == "wink":
        parts.append(f'<circle cx="{fmt(-eye_x)}" cy="{fmt(eye_y)}" r="{fmt(eye_r)}" fill="{ink}"/><circle cx="{fmt(-eye_x + eye_r * 0.38)}" cy="{fmt(eye_y - eye_r * 0.4)}" r="{fmt(eye_r * 0.36)}" fill="#fff"/>')
        parts += [arc(1), smile]
    elif mood == "starry":
        for side in (-1, 1):
            parts.append(four_point(side * eye_x, eye_y, eye_r * 1.9, "#ffd84a", f'stroke="{ink}" stroke-width="{fmt(0.012 * s)}" stroke-linejoin="round"'))
        parts.append(open_smile)
    if cheeks and mood not in ("determined",):
        for side in (-1, 1):
            parts.append(f'<ellipse cx="{fmt(side * 0.235 * s)}" cy="{fmt(0.06 * s)}" rx="{fmt(0.066 * s)}" ry="{fmt(0.04 * s)}" fill="{cheek}" opacity="0.9"/>')
    return "".join(parts)


def companion(x, y, s, mood="pip", body="#fff6ea", ink="#1a1240", cheek="#ff8fd0", outline=None, outline_width=0.0, pose="rest", tilt=0, cheeks=True, show_face=True, tether=None, backing=None):
    """One companion: a body star with a round core, two side stars on noodle tethers, and a face.

    With an outline color, the whole silhouette is stroked once as a union so overlaps stay clean.
    """
    sides = SIDE_POSES[pose]
    tether_color = tether or body
    tether_width = 0.04 * s
    shapes, noodles = [], []
    for sx, sy in sides:
        side = 1 if sx > 0 else -1
        start = (side * 0.22 * s, 0.18 * s)
        end = (sx * s, sy * s)
        control = (side * 0.58 * s, max(start[1], end[1]) + 0.34 * s)
        noodles.append(f"M{fmt(start[0])} {fmt(start[1])} Q{fmt(control[0])} {fmt(control[1])} {fmt(end[0])} {fmt(end[1])}")
        side_size = SIDE_SIZE * s
        shapes.append(star_path(end[0], end[1], side_size))
        shapes.append(f"M{fmt(end[0] - side_size * SIDE_CORE)} {fmt(end[1])} a{fmt(side_size * SIDE_CORE)} {fmt(side_size * SIDE_CORE)} 0 1 0 {fmt(side_size * SIDE_CORE * 2)} 0 a{fmt(side_size * SIDE_CORE)} {fmt(side_size * SIDE_CORE)} 0 1 0 {fmt(-side_size * SIDE_CORE * 2)} 0")
    shapes.append(star_path(0, 0, s))
    shapes.append(f"M{fmt(-CORE * s)} 0 a{fmt(CORE * s)} {fmt(CORE * s)} 0 1 0 {fmt(CORE * s * 2)} 0 a{fmt(CORE * s)} {fmt(CORE * s)} 0 1 0 {fmt(-CORE * s * 2)} 0")
    out = [f'<g transform="translate({fmt(x)} {fmt(y)}) rotate({tilt})">']
    if outline:
        width = outline_width * s
        for noodle in noodles:
            out.append(f'<path d="{noodle}" fill="none" stroke="{outline}" stroke-width="{fmt(tether_width + width * 2)}" stroke-linecap="round"/>')
        out.append(f'<path d="{" ".join(shapes)}" fill="{outline}" stroke="{outline}" stroke-width="{fmt(width * 2)}" stroke-linejoin="round"/>')
    for noodle in noodles:
        out.append(f'<path d="{noodle}" fill="none" stroke="{tether_color}" stroke-width="{fmt(tether_width)}" stroke-linecap="round"/>')
    for shape in shapes:
        out.append(f'<path d="{shape}" fill="{backing or body}"/>')
    if show_face:
        out.append(face(s, mood, ink, cheek, cheeks))
    out.append("</g>")
    return "".join(out)


def page(name, width, height, background, fonts, body, defs=""):
    font_link = f'<link rel="stylesheet" href="https://fonts.googleapis.com/css2?{fonts}&display=swap">' if fonts else ""
    html = f"""<!doctype html>
<meta charset="utf-8">
{font_link}
<style>html, body {{ margin: 0; background: {background}; }} svg {{ display: block; }}</style>
<svg id="art" width="{width}" height="{height}" viewBox="0 0 {width} {height}" xmlns="http://www.w3.org/2000/svg">
<defs>
  <filter id="paper" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="3" seed="3" result="grain"/>
    <feColorMatrix in="grain" type="matrix" values="0 0 0 0 0.42  0 0 0 0 0.38  0 0 0 0 0.34  0 0 0 0.22 0" result="tint"/>
    <feComposite in="tint" in2="SourceGraphic" operator="in" result="speck"/>
    <feBlend in="SourceGraphic" in2="speck" mode="multiply"/>
  </filter>
  <filter id="wobble" x="-5%" y="-5%" width="110%" height="110%">
    <feTurbulence type="fractalNoise" baseFrequency="0.03" numOctaves="2" seed="6" result="warp"/>
    <feDisplacementMap in="SourceGraphic" in2="warp" scale="5"/>
  </filter>
  {defs}
</defs>
{body}
</svg>
"""
    with open(os.path.join(HERE, name + ".html"), "w") as handle:
        handle.write(html)


def sparkles(seed, count, width, height, fill, low=4, high=12, avoid=None):
    """Deterministic scatter of sparkles and dots."""
    state = seed
    out = []
    for _ in range(count):
        state = (state * 1103515245 + 12345) % 2**31
        x = state % width
        state = (state * 1103515245 + 12345) % 2**31
        y = state % height
        state = (state * 1103515245 + 12345) % 2**31
        size = low + (state % 1000) / 1000 * (high - low)
        if avoid and avoid(x, y):
            continue
        if state % 3 == 0:
            out.append(four_point(x, y, size, fill))
        else:
            out.append(f'<circle cx="{x}" cy="{y}" r="{fmt(size * 0.28)}" fill="{fill}"/>')
    return "".join(out)


def model_sheet():
    """A character model sheet: construction, proportions, and an expression grid."""
    ink, paper, pencil = "#1a1240", "#f6f0e4", "#4f7bd9"
    width, height = 1800, 1100
    hero_x, hero_y, hero_s = 400, 560, 250
    guides = [
        f'<g stroke="{pencil}" stroke-width="2" fill="none" opacity="0.55" filter="url(#wobble)">',
        f'<circle cx="{hero_x}" cy="{hero_y}" r="{fmt(hero_s * CORE)}" stroke-dasharray="8 6"/>',
        f'<line x1="{hero_x}" y1="{hero_y - hero_s - 50}" x2="{hero_x}" y2="{hero_y + hero_s + 60}"/>',
        f'<line x1="{hero_x - 330}" y1="{hero_y}" x2="{hero_x + 330}" y2="{hero_y}"/>',
        f'<ellipse cx="{hero_x}" cy="{hero_y}" rx="{fmt(hero_s * HORIZONTAL)}" ry="{hero_s}"/>',
        f'<line x1="{hero_x - 330}" y1="{fmt(hero_y + 0.375 * hero_s)}" x2="{hero_x + 330}" y2="{fmt(hero_y + 0.375 * hero_s)}" stroke-dasharray="4 8"/>',
        "</g>",
    ]
    dims = [
        f'<g stroke="{pencil}" stroke-width="2.5" fill="{pencil}" font-family="\'Caveat\', cursive" font-size="30">',
        f'<path d="M{hero_x + 150} {hero_y - hero_s} L{hero_x + 150} {hero_y + hero_s}" marker-start="url(#tick)" marker-end="url(#tick)"/>',
        f'<text x="{hero_x + 162}" y="{hero_y - 120}" stroke="none">182</text>',
        f'<text x="{hero_x - 300}" y="{hero_y - 230}" stroke="none">core r 66, eyes sit just above the waist</text>',
        f'<text x="{hero_x - 310}" y="{fmt(hero_y + 0.375 * hero_s + 120)}" stroke="none">side stars ride low, ~0.45 scale,</text>',
        f'<text x="{hero_x - 310}" y="{fmt(hero_y + 0.375 * hero_s + 152)}" stroke="none">tethers always sag (they\'re noodles)</text>',
        "</g>",
    ]
    moods = [("pip", "Pip (default)"), ("happy", "Happy"), ("starry", "Starstruck"), ("surprised", "Surprised"), ("wink", "Wink"), ("love", "Smitten"), ("determined", "Focused"), ("sleepy", "Idle / sleepy"), ("sad", "Blocked")]
    poses = ["rest", "wave", "cheer", "rest", "wave", "hug", "float", "rest", "hug"]
    grid = []
    for index, ((mood, label), pose) in enumerate(zip(moods, poses)):
        column, row = index % 3, index // 3
        cx, cy = 980 + column * 270, 260 + row * 290
        grid.append(f'<rect x="{cx - 120}" y="{cy - 140}" width="240" height="250" rx="18" fill="#fff" opacity="0.55"/>')
        grid.append(companion(cx, cy - 10, 92, mood, body="#fffaf2", ink=ink, outline=ink, outline_width=0.03, pose=pose, tilt=[-6, 4, 0, 8, -4, 0, 6, -8, 0][index]))
        if mood == "sleepy":
            grid.append(f'<text x="{cx + 54}" y="{cy - 80}" font-family="Caveat, cursive" font-size="34" fill="{pencil}">z z</text>')
        grid.append(f'<text x="{cx}" y="{cy + 96}" text-anchor="middle" font-family="\'Caveat\', cursive" font-size="30" fill="{ink}">{label}</text>')
    swatches = []
    for index, (color, name) in enumerate([("#fffaf2", "body"), (ink, "ink"), ("#ff8fd0", "cheek"), ("#ffd84a", "glow")]):
        x = 1820 - 0 - 4 * 110 + index * 110 - 150
        swatches.append(f'<rect x="{x}" y="1010" width="90" height="44" rx="10" fill="{color}" stroke="{ink}" stroke-width="2"/><text x="{x + 45}" y="1000" text-anchor="middle" font-family="Caveat, cursive" font-size="24" fill="{ink}">{name}</text>')
    body = f"""<g filter="url(#paper)">
<rect width="{width}" height="{height}" fill="{paper}"/>
<g stroke="#d9cfbd" stroke-width="1">{"".join(f'<line x1="0" y1="{y}" x2="{width}" y2="{y}"/>' for y in range(40, height, 40))}</g>
<text x="60" y="96" font-family="'Fraunces', serif" font-weight="700" font-size="56" fill="{ink}">The Companion</text>
<text x="62" y="138" font-family="'Martian Mono', monospace" font-size="18" letter-spacing="3" fill="{pencil}">MODEL SHEET · ORION · REV C</text>
{"".join(guides)}
{companion(hero_x, hero_y, hero_s, "pip", body="#fffaf2", ink=ink, outline=ink, outline_width=0.022)}
{"".join(dims)}
{"".join(grid)}
{"".join(swatches)}
<text x="60" y="1050" font-family="Caveat, cursive" font-size="30" fill="{pencil}">never fully symmetrical in motion · eyes stay dots unless something big happens</text>
</g>"""
    defs = f'<marker id="tick" viewBox="-6 -6 12 12" markerWidth="12" markerHeight="12" orient="auto"><path d="M-6 0 L6 0" stroke="{pencil}" stroke-width="2.5"/></marker>'
    page("model-sheet", width, height, paper, "family=Fraunces:wght@700&family=Caveat:wght@500&family=Martian+Mono", body, defs)


def trading_card():
    """A holographic trading card for the companion."""
    width, height = 750, 1050
    defs = """
  <linearGradient id="foil" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#ff8fd0"/><stop offset="0.2" stop-color="#ffd84a"/><stop offset="0.4" stop-color="#7be14a"/>
    <stop offset="0.6" stop-color="#8fd0ff"/><stop offset="0.8" stop-color="#8b3dff"/><stop offset="1" stop-color="#ff8fd0"/>
  </linearGradient>
  <filter id="holo" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.006 0.03" numOctaves="2" seed="12" result="swirl"/>
    <feDisplacementMap in="SourceGraphic" in2="swirl" scale="120" xChannelSelector="R" yChannelSelector="G"/>
  </filter>
  <radialGradient id="sky" cx="0.5" cy="0.45" r="0.75">
    <stop offset="0" stop-color="#6a8cff"/><stop offset="0.45" stop-color="#3346c8"/><stop offset="0.8" stop-color="#1a1660"/><stop offset="1" stop-color="#0b0f2a"/>
  </radialGradient>
  <pattern id="sheen" width="18" height="18" patternUnits="userSpaceOnUse" patternTransform="rotate(30)"><rect width="2" height="18" fill="#fff" opacity="0.18"/></pattern>
  <clipPath id="window"><rect x="64" y="150" width="622" height="470" rx="14"/></clipPath>
  <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="24"/></filter>
"""
    art = [
        '<g clip-path="url(#window)">',
        '<rect x="64" y="150" width="622" height="470" fill="url(#sky)"/>',
        sparkles(41, 70, 750, 620, "#fff6ea", 3, 11),
        '<circle cx="375" cy="390" r="170" fill="#ff8fd0" opacity="0.35" filter="url(#glow)"/>',
        '<g transform="translate(560 230) rotate(-18)"><ellipse rx="92" ry="20" fill="none" stroke="#ff8fd0" stroke-width="12"/><circle r="48" fill="#2e7dff"/><path d="M-92 0 A92 20 0 0 0 92 0" fill="none" stroke="#ff8fd0" stroke-width="12"/></g>',
        '<path d="M64 560 C200 520 300 590 420 560 C540 530 620 570 686 550 L686 620 L64 620 Z" fill="#8b3dff" opacity="0.8"/>',
        companion(375, 390, 160, "starry", body="#fff6ea", ink="#1a1240", outline="#1a1240", outline_width=0.025, pose="cheer"),
        "</g>",
    ]
    body = f"""
<rect width="{width}" height="{height}" rx="36" fill="#1a1240"/>
<rect x="18" y="18" width="714" height="1014" rx="26" fill="url(#foil)" filter="url(#holo)"/>
<rect x="18" y="18" width="714" height="1014" rx="26" fill="url(#sheen)"/>
<rect x="44" y="44" width="662" height="962" rx="20" fill="#fff6ea"/>
<text x="70" y="114" font-family="'Bagel Fat One', sans-serif" font-size="54" fill="#1a1240">Orion Star</text>
<text x="680" y="112" text-anchor="end" font-family="'Martian Mono', monospace" font-weight="700" font-size="30" fill="#ff3d6e">FOCUS 120</text>
<rect x="60" y="146" width="630" height="478" rx="16" fill="url(#foil)" filter="url(#holo)"/>
{"".join(art)}
<rect x="64" y="636" width="622" height="38" rx="19" fill="#1a1240"/>
<text x="375" y="662" text-anchor="middle" font-family="'Martian Mono', monospace" font-size="15" letter-spacing="3" fill="#ffd84a">COMPANION · CELESTIAL · GUMMY TYPE</text>
<g font-family="'Bricolage Grotesque', sans-serif" fill="#1a1240">
  <g transform="translate(70 720)">{four_point(18, 0, 18, "#ffd84a", 'stroke="#1a1240" stroke-width="3"')}<text x="52" y="10" font-weight="800" font-size="34">Hop</text><text x="620" y="10" text-anchor="end" font-weight="800" font-size="34">+1</text></g>
  <text x="70" y="770" font-size="22">When the last card in a group is done, celebrate.</text>
  <text x="70" y="800" font-size="22">Everyone nearby gets a little confetti.</text>
  <line x1="70" x2="680" y1="836" y2="836" stroke="#1a1240" stroke-opacity="0.2" stroke-width="2"/>
  <g transform="translate(70 884)">{four_point(18, 0, 18, "#8fd0ff", 'stroke="#1a1240" stroke-width="3"')}{four_point(50, 0, 18, "#8fd0ff", 'stroke="#1a1240" stroke-width="3"')}<text x="84" y="10" font-weight="800" font-size="34">Keep Watch</text><text x="620" y="10" text-anchor="end" font-weight="800" font-size="34">∞</text></g>
  <text x="70" y="934" font-size="22">Sits quietly while you work. Never interrupts.</text>
</g>
<text x="70" y="990" font-family="'Martian Mono', monospace" font-size="14" fill="#1a1240" opacity="0.6">GUMMY GALAXY · ILLUS. ORION STUDIO</text>
<text x="680" y="990" text-anchor="end" font-family="'Martian Mono', monospace" font-size="14" fill="#1a1240" opacity="0.6">001/150 ★</text>
"""
    page("trading-card", width, height, "#0c0b12", "family=Bagel+Fat+One&family=Bricolage+Grotesque:wght@400;800&family=Martian+Mono:wght@400;700", body, defs)


def blueprint():
    """A technical drawing of the companion: front and side elevations with dimensions."""
    width, height = 1600, 1000
    paper, line = "#1d4fa8", "#e8f1ff"
    defs = f"""
  <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse"><path d="M40 0 H0 V40" fill="none" stroke="{line}" stroke-opacity="0.12" stroke-width="1"/></pattern>
  <pattern id="grid-major" width="200" height="200" patternUnits="userSpaceOnUse"><path d="M200 0 H0 V200" fill="none" stroke="{line}" stroke-opacity="0.22" stroke-width="1.5"/></pattern>
  <marker id="arrow" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="10" markerHeight="10" orient="auto-start-reverse"><path d="M0 1 L9 5 L0 9" fill="none" stroke="{line}" stroke-width="1.6"/></marker>
  <filter id="chalk" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="1.2" numOctaves="2" seed="4" result="noise"/>
    <feColorMatrix in="noise" type="matrix" values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 -0.9 0.75" result="mask"/>
    <feComposite in="SourceGraphic" in2="mask" operator="in"/>
  </filter>
"""
    front_x, front_y, size = 520, 500, 300
    dims = f"""
<g stroke="{line}" stroke-width="1.6" fill="none">
  <path d="M{front_x - 420} {front_y - size} H{front_x - 20}" stroke-dasharray="6 6" stroke-opacity="0.5"/>
  <path d="M{front_x - 420} {front_y + size} H{front_x - 20}" stroke-dasharray="6 6" stroke-opacity="0.5"/>
  <path d="M{front_x - 400} {front_y - size + 6} V{front_y + size - 6}" marker-start="url(#arrow)" marker-end="url(#arrow)"/>
  <path d="M{fmt(front_x - size * HORIZONTAL)} {front_y + size + 60} H{fmt(front_x + size * HORIZONTAL)}" marker-start="url(#arrow)" marker-end="url(#arrow)"/>
  <path d="M{fmt(front_x - size * HORIZONTAL)} {front_y + 20} V{front_y + size + 80}" stroke-dasharray="6 6" stroke-opacity="0.5"/>
  <path d="M{fmt(front_x + size * HORIZONTAL)} {front_y + 20} V{front_y + size + 80}" stroke-dasharray="6 6" stroke-opacity="0.5"/>
  <path d="M{front_x} {front_y} L{fmt(front_x + size * CORE * 0.707)} {fmt(front_y - size * CORE * 0.707)} L{front_x + 210} {front_y - 230} H{front_x + 300}"/>
  <path d="M{fmt(front_x + 0.94 * size)} {fmt(front_y + 0.375 * size)} L{front_x + 380} {front_y + 300} H{front_x + 480}"/>
</g>
<g fill="{line}" font-family="'Martian Mono', monospace" font-size="20">
  <text x="{front_x - 392}" y="{front_y - 8}" transform="rotate(-90 {front_x - 410} {front_y})">182</text>
  <text x="{front_x - 22}" y="{front_y + size + 50}">104</text>
  <text x="{front_x + 216}" y="{front_y - 240}">R 66 CORE</text>
  <text x="{front_x + 386}" y="{front_y + 290}">SIDE ⌀ 0.45×</text>
</g>"""
    side_x = 1250
    side_view = f"""
<g stroke="{line}" stroke-width="2.4" fill="{paper}">
  <path d="M{side_x} {front_y - size} C{side_x + 40} {front_y - 120} {side_x + 70} {front_y - 70} {side_x + 70} {front_y} C{side_x + 70} {front_y + 70} {side_x + 40} {front_y + 120} {side_x} {front_y + size} C{side_x - 40} {front_y + 120} {side_x - 70} {front_y + 70} {side_x - 70} {front_y} C{side_x - 70} {front_y - 70} {side_x - 40} {front_y - 120} {side_x} {front_y - size} Z"/>
  <ellipse cx="{side_x}" cy="{front_y}" rx="70" ry="{fmt(size * CORE)}"/>
  <path d="M{side_x - 70} {front_y} H{side_x + 70}" stroke-dasharray="10 6"/>
</g>
<g stroke="{line}" stroke-width="1.6" fill="none">
  <path d="M{side_x - 70} {front_y + size + 60} H{side_x + 70}" marker-start="url(#arrow)" marker-end="url(#arrow)"/>
</g>
<text x="{side_x}" y="{front_y + size + 50}" text-anchor="middle" fill="{line}" font-family="'Martian Mono', monospace" font-size="20">PUFF 40</text>"""
    title_block = f"""
<g stroke="{line}" stroke-width="2" fill="none"><rect x="1060" y="860" width="500" height="110"/><path d="M1060 900 H1560 M1310 900 V970"/></g>
<g fill="{line}" font-family="'Martian Mono', monospace">
  <text x="1076" y="888" font-size="20" font-weight="600">ORN-001  COMPANION, STANDARD</text>
  <text x="1076" y="930" font-size="14">MATERIAL: GUMMY, TRANSLUCENT</text>
  <text x="1076" y="956" font-size="14">FINISH: HAND-PUFFED</text>
  <text x="1326" y="930" font-size="14">SCALE 1:1 @ 64PX</text>
  <text x="1326" y="956" font-size="14">SHEET 1 OF 1  REV C</text>
</g>
<g fill="{line}" font-family="'Martian Mono', monospace" font-size="16" letter-spacing="4">
  <text x="{front_x}" y="140" text-anchor="middle">FRONT ELEVATION</text>
  <text x="{side_x}" y="140" text-anchor="middle">SIDE ELEVATION</text>
</g>
<text x="60" y="960" fill="{line}" font-family="'Caveat', cursive" font-size="30">note: tethers are noodles, not rigid. allow 15° sag at rest.</text>"""
    body = f"""
<rect width="{width}" height="{height}" fill="{paper}"/>
<rect width="{width}" height="{height}" fill="url(#grid)"/>
<rect width="{width}" height="{height}" fill="url(#grid-major)"/>
<g filter="url(#chalk)">
{companion(front_x, front_y, size, "pip", body=paper, ink=line, cheek=paper, outline=line, outline_width=0.008, backing=paper, cheeks=False)}
{dims}
{side_view}
{title_block}
</g>"""
    page("blueprint", width, height, paper, "family=Martian+Mono:wght@400;600&family=Caveat:wght@500", body, defs)


def neon():
    """A neon sign of the companion on a brick wall, with a script logotype."""
    width, height = 1200, 1200
    defs = """
  <pattern id="bricks" width="120" height="60" patternUnits="userSpaceOnUse">
    <rect width="120" height="60" fill="#2a1420"/>
    <rect x="3" y="3" width="114" height="24" rx="3" fill="#3a1c2a"/><rect x="-57" y="33" width="114" height="24" rx="3" fill="#361a28"/><rect x="63" y="33" width="114" height="24" rx="3" fill="#3c1e2c"/>
  </pattern>
  <radialGradient id="spill" cx="0.5" cy="0.42" r="0.6"><stop offset="0" stop-color="#ff4fb0" stop-opacity="0.55"/><stop offset="0.6" stop-color="#7a2cff" stop-opacity="0.18"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>
  <radialGradient id="vignette" cx="0.5" cy="0.5" r="0.75"><stop offset="0.5" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.75"/></radialGradient>
  <filter id="neon-pink" x="-30%" y="-30%" width="160%" height="160%">
    <feGaussianBlur in="SourceGraphic" stdDeviation="3" result="near"/>
    <feGaussianBlur in="SourceGraphic" stdDeviation="14" result="mid"/>
    <feGaussianBlur in="SourceGraphic" stdDeviation="40" result="far"/>
    <feMerge><feMergeNode in="far"/><feMergeNode in="mid"/><feMergeNode in="near"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
"""
    sign = companion(600, 470, 260, "happy", body="none", ink="#fff2fb", cheek="#ff8fd0", outline="#ff4fb0", outline_width=0.025, backing="#1a0b14", tether="#1a0b14", cheeks=True)
    body = f"""
<rect width="{width}" height="{height}" fill="url(#bricks)"/>
<rect width="{width}" height="{height}" fill="url(#spill)"/>
<g stroke="#120810" stroke-width="5" opacity="0.8"><path d="M360 160 L340 0 M840 160 L860 0"/></g>
<rect x="250" y="150" width="700" height="700" rx="40" fill="#120810" opacity="0.45"/>
<g filter="url(#neon-pink)">{sign}</g>
<g filter="url(#neon-pink)">
  <text x="600" y="980" text-anchor="middle" font-family="'Yellowtail', cursive" font-size="150" fill="none" stroke="#8fd0ff" stroke-width="7" stroke-linejoin="round">Gummy Galaxy</text>
  <text x="600" y="1060" text-anchor="middle" font-family="'Monoton', sans-serif" font-size="46" letter-spacing="10" fill="#ffd84a">OPEN LATE</text>
</g>
<rect width="{width}" height="{height}" fill="url(#vignette)"/>
"""
    page("neon", width, height, "#120810", "family=Yellowtail&family=Monoton", body, defs)


def stickers():
    """A die-cut sticker sheet."""
    width, height = 1600, 1100
    defs = """
  <filter id="diecut" x="-20%" y="-20%" width="140%" height="140%">
    <feMorphology in="SourceAlpha" operator="dilate" radius="14" result="grown"/>
    <feFlood flood-color="#ffffff"/><feComposite in2="grown" operator="in" result="border"/>
    <feGaussianBlur in="grown" stdDeviation="8" result="soft"/>
    <feOffset in="soft" dy="10" result="drop"/>
    <feFlood flood-color="#3a2a5a" flood-opacity="0.35"/><feComposite in2="drop" operator="in" result="shadow"/>
    <feMerge><feMergeNode in="shadow"/><feMergeNode in="border"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <linearGradient id="sheet" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#d9d1f2"/><stop offset="1" stop-color="#c3b8e8"/></linearGradient>
"""
    ink = "#1a1240"
    items = [
        companion(260, 300, 170, "happy", ink=ink, outline=ink, outline_width=0.03, pose="cheer", tilt=-8),
        companion(1340, 760, 150, "love", ink=ink, outline=ink, outline_width=0.03, pose="hug", tilt=10),
        companion(720, 820, 120, "sleepy", ink=ink, outline=ink, outline_width=0.035, pose="float", tilt=-14),
        # Burst: DONE!
        f'<g transform="translate(700 270) rotate(-8)"><path d="{burst(0, 0, 150, 108, 14)}" fill="#ffd84a" stroke="{ink}" stroke-width="7" stroke-linejoin="round"/><text y="22" text-anchor="middle" font-family="\'Bagel Fat One\', sans-serif" font-size="74" fill="{ink}">DONE!</text></g>',
        # Banner: ship it
        f'<g transform="translate(1180 250) rotate(6)"><path d="M-200 -50 H200 L170 0 L200 50 H-200 L-170 0 Z" fill="#ff5a86" stroke="{ink}" stroke-width="7" stroke-linejoin="round"/><text y="20" text-anchor="middle" font-family="\'Bagel Fat One\', sans-serif" font-size="58" fill="#fff6ea">ship it</text></g>',
        # Ringed planet
        f'<g transform="translate(330 760) rotate(-20)"><ellipse rx="150" ry="36" fill="none" stroke="{ink}" stroke-width="30"/><ellipse rx="150" ry="36" fill="none" stroke="#ff8fd0" stroke-width="16"/><circle r="84" fill="#2e7dff" stroke="{ink}" stroke-width="7"/><path d="M-80 -18 Q0 6 80 -18" fill="none" stroke="#8fd0ff" stroke-width="16" stroke-linecap="round"/><path d="M-150 0 A150 36 0 0 0 150 0" fill="none" stroke="{ink}" stroke-width="30"/><path d="M-150 0 A150 36 0 0 0 150 0" fill="none" stroke="#ff8fd0" stroke-width="16"/></g>',
        # Gumdrop
        f'<g transform="translate(1000 560) rotate(8)"><path d="M-80 60 C-80 -20 -46 -80 0 -80 C46 -80 80 -20 80 60 Q0 78 -80 60 Z" fill="#7be14a" stroke="{ink}" stroke-width="7"/><ellipse cx="-26" cy="-30" rx="14" ry="22" fill="#fff" opacity="0.7"/></g>',
        # Little stars
        f'<g transform="translate(1000 900) rotate(12)">{four_point(0, 0, 60, "#8fd0ff", f"stroke=\'{ink}\' stroke-width=\'6\' stroke-linejoin=\'round\'")}</g>',
        f'<g transform="translate(560 560) rotate(-12)">{four_point(0, 0, 48, "#ff8fd0", f"stroke=\'{ink}\' stroke-width=\'6\' stroke-linejoin=\'round\'")}</g>',
        # Wordmark pill
        f'<g transform="translate(1380 480) rotate(-4)"><rect x="-150" y="-46" width="300" height="92" rx="46" fill="{ink}"/><text y="16" text-anchor="middle" font-family="\'Bagel Fat One\', sans-serif" font-size="42" fill="#ffd84a">gummy galaxy</text></g>',
    ]
    body = f"""
<rect width="{width}" height="{height}" fill="url(#sheet)"/>
<rect x="40" y="40" width="{width - 80}" height="{height - 80}" rx="30" fill="#f4f0fb"/>
{"".join(f'<g filter="url(#diecut)">{item}</g>' for item in items)}
<text x="80" y="1040" font-family="'Martian Mono', monospace" font-size="16" letter-spacing="3" fill="#8a80a8">SHEET 01 · VINYL · KISS CUT</text>
"""
    page("stickers", width, height, "#c3b8e8", "family=Bagel+Fat+One&family=Martian+Mono", body, defs)


def burst(cx, cy, outer, inner, points):
    coords = []
    for index in range(points * 2):
        radius = outer if index % 2 == 0 else inner
        angle = math.pi * index / points - math.pi / 2
        coords.append(f"{fmt(cx + radius * math.cos(angle))} {fmt(cy + radius * math.sin(angle))}")
    return "M" + " L".join(coords) + " Z"


def deco_poster():
    """An art deco travel poster for the gummy belt, with the companion as guide."""
    width, height = 1080, 1500
    gold, navy, cream = "#e8c36a", "#14123a", "#f6ead2"
    defs = f"""
  <linearGradient id="dusk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#14123a"/><stop offset="0.55" stop-color="#5a2fd0"/><stop offset="0.8" stop-color="#ff7fb0"/><stop offset="1" stop-color="#ffc18a"/></linearGradient>
  <clipPath id="frame"><path d="M90 180 H990 V1180 H90 Z"/></clipPath>
"""
    rays = "".join(f'<path d="M540 760 L{fmt(540 + 1400 * math.cos(math.radians(a)))} {fmt(760 + 1400 * math.sin(math.radians(a)))} L{fmt(540 + 1400 * math.cos(math.radians(a + 5)))} {fmt(760 + 1400 * math.sin(math.radians(a + 5)))} Z" fill="{gold}" opacity="0.14"/>' for a in range(180, 361, 10))
    belt = []
    for index in range(26):
        angle = math.radians(index * (360 / 26))
        x = 540 + 430 * math.cos(angle)
        y = 760 + 90 * math.sin(angle)
        if math.sin(angle) < 0:
            continue
        color = ["#ff3d6e", "#ffd84a", "#7be14a", "#2e7dff", "#ff9f45", "#8b3dff"][index % 6]
        belt.append(f'<ellipse cx="{fmt(x)}" cy="{fmt(y)}" rx="22" ry="15" fill="{color}" stroke="{navy}" stroke-width="3"/>')
    back_belt = []
    for index in range(26):
        angle = math.radians(index * (360 / 26))
        if math.sin(angle) >= 0:
            continue
        x = 540 + 430 * math.cos(angle)
        y = 760 + 90 * math.sin(angle)
        back_belt.append(f'<ellipse cx="{fmt(x)}" cy="{fmt(y)}" rx="16" ry="11" fill="{gold}" opacity="0.7"/>')
    body = f"""
<g filter="url(#paper)">
<rect width="{width}" height="{height}" fill="{cream}"/>
<g clip-path="url(#frame)">
  <rect x="90" y="180" width="900" height="1000" fill="url(#dusk)"/>
  {rays}
  {sparkles(77, 60, 1080, 600, cream, 3, 10)}
  {"".join(back_belt)}
  <circle cx="540" cy="760" r="250" fill="#ff9f45"/>
  <circle cx="540" cy="760" r="250" fill="none" stroke="{navy}" stroke-width="6"/>
  <g stroke="{navy}" stroke-width="5" fill="none" opacity="0.5"><path d="M300 700 H780 M296 760 H784 M300 820 H780 M318 880 H762"/></g>
  {"".join(belt)}
  <path d="M90 1060 L300 940 L460 1020 L640 900 L820 1010 L990 930 V1180 H90 Z" fill="{navy}"/>
  <path d="M90 1110 L260 1040 L420 1100 L600 1020 L800 1100 L990 1050 V1180 H90 Z" fill="#2b2470"/>
  {companion(780, 470, 110, "wink", body=cream, ink=navy, outline=navy, outline_width=0.04, pose="wave", tilt=8)}
</g>
<path d="M90 180 H990 V1180 H90 Z" fill="none" stroke="{navy}" stroke-width="10"/>
<path d="M110 200 H970 V1160 H110 Z" fill="none" stroke="{gold}" stroke-width="3"/>
<text x="540" y="120" text-anchor="middle" font-family="'Poiret One', sans-serif" font-size="40" letter-spacing="18" fill="{navy}">GUMMY GALAXY LINES</text>
<text x="540" y="1300" text-anchor="middle" font-family="'Limelight', serif" font-size="104" fill="{navy}">THE BELT</text>
<text x="540" y="1370" text-anchor="middle" font-family="'Poiret One', sans-serif" font-size="34" letter-spacing="12" fill="{navy}">SIX FLAVORS · ONE ORBIT</text>
<text x="540" y="1440" text-anchor="middle" font-family="'Poiret One', sans-serif" font-size="22" letter-spacing="8" fill="#8a6a2a">DEPARTURES NIGHTLY FROM ORION</text>
</g>"""
    page("deco-poster", width, height, cream, "family=Limelight&family=Poiret+One", body, defs)


def woodblock():
    """A woodblock print: seigaiha sea, cloud bands, a spiral sun, and the companion riding the swell."""
    width, height = 1100, 1500
    blue, deep, paper, red = "#2b4c8c", "#16264f", "#efe3c8", "#d2483c"
    defs = f"""
  <pattern id="seigaiha" width="80" height="40" patternUnits="userSpaceOnUse">
    <rect width="80" height="40" fill="{blue}"/>
    <g fill="none" stroke="{paper}" stroke-width="3">
      <circle cx="40" cy="40" r="36"/><circle cx="40" cy="40" r="26"/><circle cx="40" cy="40" r="16"/>
      <circle cx="0" cy="20" r="36"/><circle cx="0" cy="20" r="26"/><circle cx="0" cy="20" r="16"/>
      <circle cx="80" cy="20" r="36"/><circle cx="80" cy="20" r="26"/><circle cx="80" cy="20" r="16"/>
    </g>
  </pattern>
  <pattern id="seigaiha-fill" width="80" height="40" patternUnits="userSpaceOnUse">
    <rect width="80" height="40" fill="{blue}"/>
    <g fill="{blue}" stroke="{paper}" stroke-width="3">
      <g><circle cx="0" cy="20" r="36"/><circle cx="0" cy="20" r="26"/><circle cx="0" cy="20" r="16"/></g>
      <g><circle cx="80" cy="20" r="36"/><circle cx="80" cy="20" r="26"/><circle cx="80" cy="20" r="16"/></g>
      <g><circle cx="40" cy="40" r="36"/><circle cx="40" cy="40" r="26"/><circle cx="40" cy="40" r="16"/></g>
    </g>
  </pattern>
  <linearGradient id="bokashi" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{deep}"/><stop offset="0.35" stop-color="{blue}" stop-opacity="0.6"/><stop offset="0.6" stop-color="{paper}" stop-opacity="0"/></linearGradient>
  <filter id="woodgrain" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.004 0.09" numOctaves="3" seed="21" result="grain"/>
    <feColorMatrix in="grain" type="matrix" values="0 0 0 0 0.3  0 0 0 0 0.25  0 0 0 0 0.2  0 0 0 0.35 -0.05" result="tint"/>
    <feComposite in="tint" in2="SourceGraphic" operator="in" result="speck"/>
    <feBlend in="SourceGraphic" in2="speck" mode="multiply"/>
  </filter>
"""
    cloud = lambda x, y, w: f'<path d="M{x} {y} h{w} a18 18 0 0 0 0 -36 h-{w * 0.3:.0f} a22 22 0 0 0 -40 -10 a26 26 0 0 0 -48 6 h-{w * 0.7 - 88:.0f} a18 18 0 0 0 0 40 Z" fill="{paper}" stroke="{deep}" stroke-width="4"/>'
    spiral_arm = "M0 0 C40 -6 62 -48 42 -84 C28 -106 0 -112 -22 -104 C8 -96 22 -76 14 -56 C8 -34 -14 -20 0 0 Z"
    sun = f'<g transform="translate(300 360)"><circle r="130" fill="{red}"/><g fill="#f08a5a" stroke="{deep}" stroke-width="3">' + "".join(f'<path d="{spiral_arm}" transform="rotate({a}) scale(1.1)"/>' for a in (0, 120, 240)) + f'</g><circle r="38" fill="#f6c84a" stroke="{deep}" stroke-width="3"/></g>'
    swell = f'<path d="M0 960 C140 900 220 860 330 880 C460 904 520 800 640 760 C760 720 860 760 920 840 C960 890 1040 900 1100 880 L1100 1500 L0 1500 Z" fill="url(#seigaiha-fill)" stroke="{deep}" stroke-width="6"/>'
    crest = f'<path d="M640 760 C700 700 800 690 860 730 C820 728 790 748 800 770 C830 750 870 760 880 790 C850 790 840 810 850 830 C880 820 905 830 920 840" fill="{paper}" stroke="{deep}" stroke-width="5" stroke-linejoin="round"/>'
    near = f'<path d="M0 1180 C120 1120 260 1150 380 1110 C520 1064 640 1140 780 1120 C900 1102 1000 1060 1100 1080 L1100 1500 L0 1500 Z" fill="url(#seigaiha)" stroke="{deep}" stroke-width="6"/>'
    body = f"""
<g filter="url(#woodgrain)">
<rect width="{width}" height="{height}" fill="{paper}"/>
<rect width="{width}" height="700" fill="url(#bokashi)"/>
{sun}
{cloud(560, 300, 340)}{cloud(120, 620, 260)}{cloud(700, 560, 220)}
{sparkles(9, 30, 1100, 520, paper, 3, 9)}
{swell}
{crest}
{companion(760, 640, 130, "pip", body=paper, ink=deep, cheek="#e98aa0", outline=deep, outline_width=0.035, pose="float", tilt=-10)}
{near}
<rect x="40" y="40" width="{width - 80}" height="{height - 80}" fill="none" stroke="{deep}" stroke-width="10"/>
<g transform="translate(960 110)">
  <rect x="-44" y="-30" width="88" height="420" fill="#f3e9cf" stroke="{deep}" stroke-width="4"/>
  <text x="0" y="0" text-anchor="middle" font-family="'Dela Gothic One', sans-serif" font-size="56" fill="{deep}" writing-mode="vertical-rl">グミ銀河</text>
</g>
<g transform="translate(990 1390)"><rect x="-56" y="-56" width="112" height="112" rx="10" fill="{red}"/><text y="18" text-anchor="middle" font-family="'Dela Gothic One', sans-serif" font-size="46" fill="{paper}">星</text></g>
</g>"""
    page("woodblock", width, height, paper, "family=Dela+Gothic+One", body, defs)


if __name__ == "__main__":
    model_sheet()
    trading_card()
    blueprint()
    neon()
    stickers()
    deco_poster()
    woodblock()
    print("wrote 7 pieces")
