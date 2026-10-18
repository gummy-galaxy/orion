"""GameCube and Wii era pieces: a channel menu for the worlds, and a sheet of WarioWare-style microgames.

Usage: era.py  (writes each piece's HTML next to this file)
"""
from companion import companion, four_point, fmt, page
from worlds import CREAM, INK, SPIRAL_ARM, WORLDS, emblem, mix


def channel_menu():
    """The worlds as channels on a glossy white console menu."""
    width, height = 1600, 900
    defs = """
  <linearGradient id="menu-bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f4f6f8"/><stop offset="1" stop-color="#dfe4ea"/></linearGradient>
  <pattern id="menu-lines" width="8" height="8" patternUnits="userSpaceOnUse"><rect width="8" height="4" fill="#ffffff" opacity="0.5"/></pattern>
  <linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="0.75"/><stop offset="0.48" stop-color="#fff" stop-opacity="0.18"/><stop offset="0.5" stop-color="#fff" stop-opacity="0"/></linearGradient>
  <linearGradient id="bar" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e9edf1"/><stop offset="1" stop-color="#c9d0d8"/></linearGradient>
  <linearGradient id="button" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#d6dce3"/></linearGradient>
  <filter id="lift" x="-10%" y="-10%" width="120%" height="140%"><feDropShadow dx="0" dy="4" stdDeviation="5" flood-color="#5a6a80" flood-opacity="0.3"/></filter>
  <filter id="halo" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="6"/></filter>
"""
    channels = [(world, world["name"]) for world in WORLDS] + [(None, "Focus Music"), (None, "Gummy Shop")]
    tiles = []
    tile_width, tile_height, gap = 330, 180, 26
    left = (width - (4 * tile_width + 3 * gap)) / 2
    for index in range(12):
        column, row = index % 4, index // 4
        x, y = left + column * (tile_width + gap), 70 + row * (tile_height + gap)
        clip = f'<clipPath id="tile-{index}"><rect x="{fmt(x)}" y="{y}" width="{tile_width}" height="{tile_height}" rx="26"/></clipPath>'
        tiles.append(clip)
        if index >= len(channels):
            tiles.append(f'<rect x="{fmt(x)}" y="{y}" width="{tile_width}" height="{tile_height}" rx="26" fill="#eef1f4" stroke="#c9d1da" stroke-width="3"/>')
            tiles.append(f'<rect x="{fmt(x)}" y="{y}" width="{tile_width}" height="{tile_height}" rx="26" fill="url(#menu-lines)"/>')
            continue
        world, label = channels[index]
        center_x, center_y = x + tile_width / 2, y + tile_height / 2 - 10
        art = []
        if world:
            art.append(f'<rect x="{fmt(x)}" y="{y}" width="{tile_width}" height="{tile_height}" fill="{mix(world["color"], "#ffffff", 0.35)}"/>')
            art.append(f'<circle cx="{fmt(center_x + 90)}" cy="{fmt(center_y + 70)}" r="120" fill="{world["color"]}" opacity="0.55"/>')
            art.append(emblem(world["emblem"], x + 70, center_y + 6, 84, CREAM, world["dark"], 4, world["color"]))
            art.append(f'<text x="{fmt(x + 128)}" y="{fmt(center_y + 2)}" font-family="\'M PLUS Rounded 1c\', sans-serif" font-weight="800" font-size="{26 if len(label) < 13 else 19}" fill="{world["dark"]}">{label}</text>')
            art.append(f'<text x="{fmt(x + 128)}" y="{fmt(center_y + 32)}" font-family="\'M PLUS Rounded 1c\', sans-serif" font-weight="700" font-size="17" fill="{world["dark"]}" opacity="0.75">{world["orion"]}</text>')
        elif label == "Focus Music":
            art.append(f'<rect x="{fmt(x)}" y="{y}" width="{tile_width}" height="{tile_height}" fill="#2a2150"/>')
            for bar in range(14):
                bar_height = 20 + (bar * 37 % 70)
                art.append(f'<rect x="{fmt(x + 30 + bar * 20)}" y="{fmt(y + 130 - bar_height)}" width="12" height="{bar_height}" rx="6" fill="{["#ff8fd0", "#8fd0ff", "#ffd84a"][bar % 3]}"/>')
            art.append(f'<text x="{fmt(center_x)}" y="{fmt(y + 162)}" text-anchor="middle" font-family="\'M PLUS Rounded 1c\', sans-serif" font-weight="800" font-size="24" fill="#fff6ea">Focus Music</text>')
        else:
            art.append(f'<rect x="{fmt(x)}" y="{y}" width="{tile_width}" height="{tile_height}" fill="#fff"/>')
            art.append(f'<g transform="translate({fmt(center_x - 80)} {fmt(center_y + 10)})"><path d="M-40 -10 H40 L32 46 H-32 Z" fill="#ffd84a" stroke="{INK}" stroke-width="4"/><path d="M-26 -10 C-26 -46 26 -46 26 -10" fill="none" stroke="{INK}" stroke-width="5"/></g>')
            art.append(companion(center_x + 70, center_y + 6, 46, "wink", outline=INK, outline_width=0.05, pose="wave"))
            art.append(f'<text x="{fmt(center_x)}" y="{fmt(y + 166)}" text-anchor="middle" font-family="\'M PLUS Rounded 1c\', sans-serif" font-weight="800" font-size="22" fill="#2e7dff">Gummy Shop Channel</text>')
        tiles.append(f'<g filter="url(#lift)"><g clip-path="url(#tile-{index})">{"".join(art)}<rect x="{fmt(x)}" y="{y}" width="{tile_width}" height="{tile_height / 2}" fill="url(#gloss)"/></g>'
                     f'<rect x="{fmt(x)}" y="{y}" width="{tile_width}" height="{tile_height}" rx="26" fill="none" stroke="#c4ccd6" stroke-width="3"/></g>')
    selected_x, selected_y = left + 2 * (tile_width + gap), 70
    tiles.append(f'<rect x="{fmt(selected_x - 6)}" y="{selected_y - 6}" width="{tile_width + 12}" height="{tile_height + 12}" rx="32" fill="none" stroke="#34beed" stroke-width="10" opacity="0.8" filter="url(#halo)"/>')
    tiles.append(f'<rect x="{fmt(selected_x - 4)}" y="{selected_y - 4}" width="{tile_width + 8}" height="{tile_height + 8}" rx="30" fill="none" stroke="#34beed" stroke-width="5"/>')
    hand = f'<g transform="translate({fmt(selected_x + 300)} {selected_y + 200}) rotate(-12)"><path d="M0 0 L0 -60 C0 -72 16 -72 16 -60 L16 -18 L18 -30 C18 -40 32 -40 32 -30 L32 -14 L34 -24 C34 -34 48 -34 48 -24 L48 -8 L50 -16 C50 -26 64 -26 64 -16 L64 20 C64 46 46 62 24 62 L10 62 C-6 62 -14 50 -22 36 L-36 10 C-42 0 -30 -8 -22 0 Z" fill="#ffffff" stroke="#34beed" stroke-width="4" stroke-linejoin="round"/><text x="22" y="42" text-anchor="middle" font-family="\'M PLUS Rounded 1c\', sans-serif" font-weight="800" font-size="20" fill="#34beed">1</text></g>'
    bar = f"""
<path d="M0 760 H560 C620 760 640 700 700 700 H900 C960 700 980 760 1040 760 H1600 V900 H0 Z" fill="url(#bar)"/>
<path d="M0 760 H560 C620 760 640 700 700 700 H900 C960 700 980 760 1040 760 H1600" fill="none" stroke="#34beed" stroke-width="4"/>
<g filter="url(#lift)"><circle cx="150" cy="820" r="58" fill="url(#button)" stroke="#9fb0c2" stroke-width="3"/><circle cx="1450" cy="820" r="58" fill="url(#button)" stroke="#9fb0c2" stroke-width="3"/></g>
<g transform="translate(150 820) scale(0.42)">{"".join(f'<path d="{SPIRAL_ARM}" transform="rotate({angle})" fill="#9fb0c2"/>' for angle in (0, 120, 240))}<circle r="30" fill="#9fb0c2"/></g>
<g transform="translate(1450 820)"><rect x="-30" y="-20" width="60" height="40" rx="6" fill="none" stroke="#9fb0c2" stroke-width="5"/><path d="M-30 -20 L0 6 L30 -20" fill="none" stroke="#9fb0c2" stroke-width="5"/><circle cx="34" cy="-24" r="10" fill="#34beed"/></g>
<text x="800" y="782" text-anchor="middle" font-family="'M PLUS Rounded 1c', sans-serif" font-weight="800" font-size="54" fill="#8a96a6">18:42</text>
<text x="800" y="836" text-anchor="middle" font-family="'M PLUS Rounded 1c', sans-serif" font-weight="700" font-size="26" fill="#8a96a6">Fri 16/10</text>
"""
    body = f"""<rect width="{width}" height="{height}" fill="url(#menu-bg)"/>
<rect width="{width}" height="{height}" fill="url(#menu-lines)" opacity="0.6"/>
{"".join(tiles)}
{hand}
{bar}"""
    page("channel-menu", width, height, "#eef1f4", "family=M+PLUS+Rounded+1c:wght@700;800", body, defs)


def burst_path(cx, cy, outer, inner, points, wobble=0.0):
    import math
    coords = []
    for index in range(points * 2):
        radius = (outer if index % 2 == 0 else inner) * (1 + wobble * ((index * 7) % 5 - 2) / 10)
        angle = math.pi * index / points
        coords.append(f"{fmt(cx + radius * math.cos(angle))} {fmt(cy + radius * math.sin(angle))}")
    return "M" + " L".join(coords) + " Z"


def bomb(x, y, seconds, fuse):
    return (f'<g transform="translate({x} {y})"><path d="M30 -20 C70 -40 {30 + fuse} -10 {50 + fuse} -30" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>'
            f'<path d="{burst_path(50 + fuse, -30, 18, 8, 7)}" fill="#ffd84a" stroke="#ff3d6e" stroke-width="3"/>'
            f'<circle r="34" fill="{INK}"/><circle cx="-10" cy="-12" r="9" fill="#fff" opacity="0.5"/>'
            f'<rect x="12" y="-36" width="22" height="16" rx="3" fill="{INK}" transform="rotate(30 23 -28)"/>'
            f'<text x="0" y="13" text-anchor="middle" font-family="\'Bowlby One\', sans-serif" font-size="34" fill="#fff">{seconds}</text></g>')


def command(text, x, y, color, tilt=-6):
    return (f'<g transform="translate({x} {y}) rotate({tilt}) skewX(-10)">'
            f'<text text-anchor="middle" font-family="\'Bowlby One\', sans-serif" font-size="104" fill="{INK}" stroke="{INK}" stroke-width="22" stroke-linejoin="round">{text}</text>'
            f'<text text-anchor="middle" font-family="\'Bowlby One\', sans-serif" font-size="104" fill="{color}" stroke="#fff" stroke-width="6" stroke-linejoin="round" paint-order="stroke">{text}</text></g>')


def glove(x, y, angle=0, scale=1.0):
    return (f'<g transform="translate({x} {y}) rotate({angle}) scale({scale})">'
            f'<path d="M0 0 L0 -70 C0 -84 20 -84 20 -70 L20 -22 L22 -36 C22 -48 40 -48 40 -36 L40 -16 L42 -28 C42 -40 60 -40 60 -28 L60 -10 L62 -20 C62 -32 80 -32 80 -20 L80 24 C80 56 56 76 30 76 L12 76 C-8 76 -18 62 -28 44 L-44 12 C-52 0 -36 -10 -26 0 Z" fill="#fff" stroke="{INK}" stroke-width="7" stroke-linejoin="round"/>'
            f'<path d="M10 76 L10 100 L66 100 L70 70" fill="#ff3d6e" stroke="{INK}" stroke-width="7" stroke-linejoin="round"/></g>')


def card(x, y, color, tilt=0, check=False, scale=1.0):
    tick = f'<path d="M-62 -4 l14 14 l26 -30" fill="none" stroke="#fff" stroke-width="9" stroke-linecap="round"/>' if check else ""
    return (f'<g transform="translate({x} {y}) rotate({tilt}) scale({scale})"><rect x="-110" y="-56" width="220" height="112" rx="18" fill="#fff" stroke="{INK}" stroke-width="7"/>'
            f'<rect x="-90" y="-36" width="60" height="60" rx="14" fill="{color}" stroke="{INK}" stroke-width="5"/>{tick}'
            f'<rect x="-14" y="-28" width="104" height="16" rx="8" fill="{INK}"/><rect x="-14" y="2" width="70" height="16" rx="8" fill="{INK}" opacity="0.4"/></g>')


def microgames():
    """Four microgames, each a few seconds long, each one an Orion action."""
    width, height = 1600, 1330
    screen_width, screen_height = 760, 540
    defs = f"""
  <pattern id="dots-a" width="22" height="22" patternUnits="userSpaceOnUse"><circle cx="11" cy="11" r="5" fill="#fff" opacity="0.35"/></pattern>
  <pattern id="stripes-a" width="40" height="40" patternUnits="userSpaceOnUse" patternTransform="rotate(-20)"><rect width="20" height="40" fill="#fff" opacity="0.18"/></pattern>
  <pattern id="checks-a" width="60" height="60" patternUnits="userSpaceOnUse"><rect width="30" height="30" fill="{INK}" opacity="0.12"/><rect x="30" y="30" width="30" height="30" fill="{INK}" opacity="0.12"/></pattern>
"""
    games = []

    def screen(index, background, pattern, content, caption):
        column, row = index % 2, index // 2
        x, y = 30 + column * (screen_width + 20), 100 + row * (screen_height + 70)
        games.append(f'<clipPath id="screen-{index}"><rect x="{x}" y="{y}" width="{screen_width}" height="{screen_height}" rx="20"/></clipPath>')
        games.append(f'<g clip-path="url(#screen-{index})"><rect x="{x}" y="{y}" width="{screen_width}" height="{screen_height}" fill="{background}"/><rect x="{x}" y="{y}" width="{screen_width}" height="{screen_height}" fill="url(#{pattern})"/>'
                     f'<g transform="translate({x} {y})">{content}</g></g>')
        games.append(f'<rect x="{x}" y="{y}" width="{screen_width}" height="{screen_height}" rx="20" fill="none" stroke="{INK}" stroke-width="8"/>')
        games.append(f'<text x="{x + 8}" y="{y + screen_height + 42}" font-family="\'Martian Mono\', monospace" font-size="17" fill="{INK}">{caption}</text>')

    link = (card(170, 300, "#8b3dff", -8) + card(590, 330, "#5cc93a", 6)
            + f'<path d="M270 300 C360 420 420 420 470 360" fill="none" stroke="{INK}" stroke-width="20" stroke-linecap="round"/><path d="M270 300 C360 420 420 420 470 360" fill="none" stroke="#e24a8a" stroke-width="10" stroke-linecap="round" stroke-dasharray="20 12"/>'
            + glove(470, 360, -30, 0.9) + command("LINK!", 380, 140, "#ffd84a") + bomb(660, 470, 3, 30))
    screen(0, "#8b3dff", "dots-a", link, "Noodle Reach · drag the noodle onto the card it waits on")

    jars = ""
    for jar_index, world in enumerate([WORLDS[2], WORLDS[3], WORLDS[4]]):
        jx = 160 + jar_index * 220
        jars += (f'<g transform="translate({jx} 430)"><path d="M-80 -70 H80 L70 90 H-70 Z" fill="#ffffff" fill-opacity="0.55" stroke="{INK}" stroke-width="7"/>'
                 f'<rect x="-86" y="-90" width="172" height="26" rx="10" fill="{world["color"]}" stroke="{INK}" stroke-width="6"/>'
                 f'{emblem(world["emblem"], 0, 14, 70, world["color"], INK, 4)}</g>')
    candies = "".join(f'<g transform="rotate({angle} {cx} {cy})">{emblem("candy", cx, cy, 70, "#ffd84a", INK, 4, color)}</g>' for cx, cy, angle, color in ((300, 210, 20, "#ff3d6e"), (470, 170, -14, "#2e7dff"), (380, 280, 40, "#7be14a")))
    sort = jars + candies + glove(330, 250, 10, 0.8) + command("SORT!", 380, 140, "#7be14a", 5) + bomb(660, 80, 2, 10)
    screen(1, "#ff3d6e", "stripes-a", sort, "Taffy Belt · drop each wrapped candy into its world")

    finish = (f'<path d="{burst_path(380, 300, 250, 190, 18, 0.6)}" fill="#ffd84a" stroke="{INK}" stroke-width="7"/>'
              + card(380, 310, "#5cc93a", -4, True, 1.5)
              + glove(470, 310, -150, 1.1)
              + command("FINISH!", 380, 140, "#ff8fd0", -4)
              + companion(640, 420, 60, "starry", outline=INK, outline_width=0.06, pose="cheer", tilt=10)
              + bomb(80, 470, 1, 0))
    screen(2, "#2e7dff", "checks-a", finish, "Gumdrop Highlands · press it before the fuse runs out")

    unwrap = (f'<g transform="translate(380 330) rotate(-8)">{emblem("candy", 0, 0, 380, "#ffd84a", INK, 6, "#ff3d6e")}</g>'
              + f'<path d="M150 230 C110 300 120 370 170 420" fill="none" stroke="{INK}" stroke-width="12" stroke-linecap="round"/><path d="M168 430 l-34 -6 l26 -26 Z" fill="{INK}"/>'
              + f'<path d="M610 430 C650 360 640 290 590 240" fill="none" stroke="{INK}" stroke-width="12" stroke-linecap="round"/><path d="M592 230 l34 6 l-26 26 Z" fill="{INK}"/>'
              + command("UNWRAP!", 380, 140, "#8fd0ff", 4)
              + companion(110, 460, 52, "surprised", outline=INK, outline_width=0.06, pose="hug")
              + bomb(660, 470, 2, 18))
    screen(3, "#ff9f45", "dots-a", unwrap, "Inbox · twist both ends to open what just arrived")

    body = f"""<g filter="url(#paper)">
<rect width="{width}" height="{height}" fill="#fff6ea"/>
<text x="34" y="70" font-family="'Bowlby One', sans-serif" font-size="46" fill="{INK}">Microgames</text>
<text x="1566" y="66" text-anchor="end" font-family="'Martian Mono', monospace" font-size="16" letter-spacing="3" fill="#8a6a9a">FOUR SECONDS EACH · EVERY ONE IS AN ORION ACTION</text>
{"".join(games)}
</g>"""
    page("microgames", width, height, "#fff6ea", "family=Bowlby+One&family=Martian+Mono", body, defs)


if __name__ == "__main__":
    channel_menu()
    microgames()
    print("wrote 2 pieces")
